suppressPackageStartupMessages(library(lme4))

archive_revision <- "a499224e6972c277cfd889e614e39e94e85d8276"
archive_sha256 <- "eb296bb9735e96f41233c772968202c29cb4b2f38dd6d77eaf38989cb8e22513"
archive_url <- paste0(
  "https://raw.githubusercontent.com/guadarf/Lunar-gravity-sleep/",
  archive_revision, "/data/Data_S3_all_onsetData_titi.csv"
)
seed_base <- 20261121L
replicates <- 100L
date_sd <- 15

read_schedule <- function(include_onsets = FALSE) {
  source_file <- tempfile(fileext = ".csv")
  on.exit(unlink(source_file))
  download.file(archive_url, source_file, mode = "wb", quiet = TRUE)
  stopifnot(unname(tools::sha256sum(source_file)) == archive_sha256)
  source <- read.csv(source_file, colClasses = c(
    night = "character", id2 = "character", Year = "character",
    time = if (include_onsets) "numeric" else "NULL",
    DayinCycle = "NULL", mean_Total_C = "NULL"
  ))
  schedule <- data.frame(
    day = as.Date(source$night),
    cohort = factor(source$Year),
    animal = interaction(source$Year, source$id2, drop = TRUE)
  )
  stopifnot(!anyNA(schedule), nrow(schedule) == 1007L,
            nlevels(schedule$animal) == 20L,
            !anyDuplicated(schedule[c("animal", "day")]))
  if (include_onsets) {
    stopifnot(all(is.finite(source$time)))
    schedule$onset <- 60 * (source$time - 6)
  }
  schedule <- schedule[order(schedule$cohort, schedule$day, schedule$animal), ]
  schedule$date <- interaction(schedule$cohort, schedule$day, drop = TRUE)
  fortnight <- ave(as.integer(schedule$day), schedule$cohort,
                   FUN = function(day) (day - min(day)) %/% 14L)
  schedule$animal_fortnight <- interaction(schedule$animal, fortnight, drop = TRUE)
  schedule
}

forecast_split <- function(schedule) {
  cohort_cutoffs <- vapply(split(as.integer(schedule$day), schedule$cohort), function(days) {
    days <- sort(unique(days))
    days[(length(days) * 2L) %/% 3L + 1L]
  }, integer(1))
  train <- as.integer(schedule$day) < cohort_cutoffs[as.character(schedule$cohort)]
  test <- !train & schedule$animal %in% schedule$animal[train]
  stopifnot(!any(schedule$date[test] %in% schedule$date[train]),
            sum(train) == 629L, sum(test) == 325L,
            length(unique(schedule$animal[test])) == 15L)
  list(train = train, test = test)
}

group_shifts <- function(group, sd) {
  rnorm(nlevels(group), sd = sd)[as.integer(group)]
}

simulate_onsets <- function(schedule, persistent_sd, temporary_sd, residual_sd) {
  cohort_means <- c(0, 15)
  cohort_means[as.integer(schedule$cohort)] +
    group_shifts(schedule$date, date_sd) +
    group_shifts(schedule$animal, persistent_sd) +
    group_shifts(schedule$animal_fortnight, temporary_sd) +
    rnorm(nrow(schedule), sd = residual_sd)
}

fit_model <- function(formula, data) {
  optimizers <- list(
    nloptwrap = list(ftol_abs = 1e-8, xtol_abs = 1e-8),
    bobyqa = list(rhoend = 1e-9, maxfun = 20000),
    nlminbwrap = list()
  )
  diagnostics <- character()
  for (optimizer in names(optimizers)) {
    control <- lmerControl(optimizer = optimizer, optCtrl = optimizers[[optimizer]],
                           check.conv.singular = "ignore")
    fit_warnings <- character()
    result <- withCallingHandlers(
      lmer(formula, data = data, REML = TRUE, control = control),
      warning = function(warning) {
        fit_warnings <<- c(fit_warnings, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    )
    convergence <- result@optinfo$conv
    if (isTRUE(convergence$opt == 0) && !length(convergence$lme4$messages) &&
        !length(fit_warnings)) return(result)
    diagnostics <- c(diagnostics, paste0(optimizer, " status ", convergence$opt, " ",
                                        paste(fit_warnings, collapse = " | ")))
  }
  stop("Mixed model did not converge: ", paste(diagnostics, collapse = "; "))
}

animal_formula <- onset ~ cohort + (1 | date) + (1 | animal)

forecast_errors <- function(schedule, split) {
  train <- schedule[split$train, ]
  test <- schedule[split$test, ]
  animal_model <- fit_model(animal_formula, train)
  baseline_model <- fit_model(onset ~ cohort + (1 | date), train)
  squared_error <- function(model) {
    predictions <- predict(model, newdata = test, allow.new.levels = TRUE)
    (test$onset - predictions)^2
  }
  list(errors = data.frame(cohort = test$cohort, animal = test$animal,
                           baseline = squared_error(baseline_model),
                           with_animal = squared_error(animal_model)),
       animal_optimizer = animal_model@optinfo$optimizer,
       baseline_optimizer = baseline_model@optinfo$optimizer)
}

rmse_stats <- function(errors) {
  baseline <- sqrt(mean(errors$baseline))
  with_animal <- sqrt(mean(errors$with_animal))
  data.frame(baseline_rmse = baseline, animal_rmse = with_animal,
             rmse_gain = baseline - with_animal)
}

fit_replicate <- function(schedule, split, persistent_sd, temporary_sd, residual_sd, seed) {
  set.seed(seed)
  schedule$onset <- simulate_onsets(schedule, persistent_sd, temporary_sd, residual_sd)
  full_fit <- fit_model(animal_formula, schedule)
  forecasts <- forecast_errors(schedule, split)
  data.frame(
    estimated_animal_sd = unname(attr(VarCorr(full_fit)$animal, "stddev")),
    rmse_stats(forecasts$errors),
    recovery_optimizer = full_fit@optinfo$optimizer,
    animal_optimizer = forecasts$animal_optimizer,
    baseline_optimizer = forecasts$baseline_optimizer
  )
}

summarize_condition <- function(runs) {
  spread <- runs$estimated_animal_sd
  gain <- runs$rmse_gain
  data.frame(
    runs[1L, c("residual_sd", "persistent_sd", "temporary_sd")],
    replicates = nrow(runs),
    spread_q10 = unname(quantile(spread, 0.1)), spread_median = median(spread),
    spread_q90 = unname(quantile(spread, 0.9)),
    gain_q10 = unname(quantile(gain, 0.1)), gain_median = median(gain),
    gain_q90 = unname(quantile(gain, 0.9))
  )
}

main <- function() {
  output_dir <- "analysis/results"
  schedule <- read_schedule()
  split <- forecast_split(schedule)
  design <- rbind(
    expand.grid(persistent_sd = c(0, 10, 20, 40), temporary_sd = 0,
                residual_sd = c(20, 40)),
    expand.grid(persistent_sd = 0, temporary_sd = 20, residual_sd = c(20, 40))
  )
  conditions <- lapply(seq_len(nrow(design)), function(i) {
    condition <- design[i, ]
    seeds <- seed_base + 1000L * i + seq_len(replicates)
    results <- lapply(seeds, function(seed) {
      tryCatch(
        fit_replicate(schedule, split, condition$persistent_sd, condition$temporary_sd,
                      condition$residual_sd, seed),
        error = function(err) stop(sprintf("Condition %d, seed %d: %s", i, seed,
                                            conditionMessage(err)), call. = FALSE)
      )
    })
    message(sprintf("Completed %d/%d conditions (persistent %g, temporary %g, residual %g minutes)",
                    i, nrow(design), condition$persistent_sd, condition$temporary_sd,
                    condition$residual_sd))
    data.frame(condition[rep(1L, replicates), ], seed = seeds,
               do.call(rbind, results))
  })
  runs <- do.call(rbind, conditions)
  summary <- do.call(rbind, lapply(conditions, summarize_condition))
  stopifnot(nrow(runs) == nrow(design) * replicates, all(is.finite(runs$rmse_gain)))
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  write.csv(runs, file.path(output_dir, "titi-simulation-runs.csv"), row.names = FALSE)
  write.csv(summary, file.path(output_dir, "titi-simulation-summary.csv"), row.names = FALSE)
  print(summary, row.names = FALSE, digits = 3)
}

if (sys.nframe() == 0L) main()
