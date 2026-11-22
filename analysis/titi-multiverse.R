source("analysis/simulate-titi-onset.R")

specifications <- expand.grid(
  spread = c("common", "separate"),
  temporary = c("none", "fortnight"),
  calendar = c("date", "date_and_trend"),
  stringsAsFactors = FALSE
)
specifications$spec <- sprintf("M%02d", seq_len(nrow(specifications)))
specifications <- specifications[c("spec", "spread", "temporary", "calendar")]
output_dir <- "analysis/results"

model_formula <- function(spec, include_animals = TRUE) {
  terms <- "cohort"
  if (spec$calendar == "date_and_trend") terms <- c(terms, "cohort:elapsed_weeks")
  terms <- c(terms, "(1 | date)")
  if (include_animals) {
    persistent <- if (spec$spread == "common") "(1 | animal)" else "diag(0 + cohort | animal)"
    terms <- c(terms, persistent)
    if (spec$temporary == "fortnight") terms <- c(terms, "(1 | animal_fortnight)")
  }
  reformulate(terms, response = "onset")
}

read_multiverse_schedule <- function(include_onsets = FALSE) {
  schedule <- read_schedule(include_onsets)
  schedule$elapsed_weeks <- ave(as.numeric(schedule$day), schedule$cohort,
                                FUN = function(day) (day - min(day)) / 7)
  schedule
}

effect_scales <- function(fit) {
  effects <- as.data.frame(VarCorr(fit))
  effects <- effects[is.na(effects$var2), ]
  animal <- effects[effects$grp == "animal", ]
  cohorts <- ifelse(animal$var1 == "(Intercept)", "common", sub("^cohort", "", animal$var1))
  temporary <- effects$sdcor[effects$grp == "animal_fortnight"]
  list(persistent = setNames(animal$sdcor, cohorts),
       profile_names = paste0("sd_", animal$var1, "|animal"),
       temporary = if (length(temporary)) temporary else 0,
       date = effects$sdcor[effects$grp == "date"],
       residual = sigma(fit), zero_variance = any(effects$sdcor == 0))
}

observed_intervals <- function(fit, parameters) {
  notes <- character()
  intervals <- tryCatch(
    withCallingHandlers(
      confint(fit, parm = parameters, method = "profile", signames = FALSE, quiet = TRUE),
      warning = function(warning) {
        notes <<- c(notes, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(err) {
      notes <<- c(notes, conditionMessage(err))
      matrix(NA_real_, nrow = length(parameters), ncol = 2L,
             dimnames = list(parameters, NULL))
    }
  )
  list(intervals = intervals[parameters, , drop = FALSE], notes = paste(notes, collapse = " | "))
}

observed_estimates <- function(schedule, spec) {
  fit <- fit_model(model_formula(spec), schedule)
  scales <- effect_scales(fit)
  intervals <- observed_intervals(fit, scales$profile_names)
  residual_rms <- tapply(residuals(fit)^2, schedule$cohort, function(x) sqrt(mean(x)))
  data.frame(spec, cohort = names(scales$persistent), persistent_sd = unname(scales$persistent),
             lower_95 = intervals$intervals[, 1L], upper_95 = intervals$intervals[, 2L],
             fortnight_sd = scales$temporary, date_sd = scales$date, residual_sd = scales$residual,
             residual_rms_2023 = unname(residual_rms["2023"]),
             residual_rms_2024 = unname(residual_rms["2024"]),
             zero_variance = scales$zero_variance, optimizer = fit@optinfo$optimizer,
             interval_note = intervals$notes, row.names = NULL)
}

forecast_summary <- function(spec, training, test, baseline_errors) {
  model <- fit_model(model_formula(spec), training)
  prediction <- predict(model, test, allow.new.levels = TRUE)
  errors <- data.frame(cohort = test$cohort, animal = test$animal, baseline = baseline_errors,
                       with_animal = test$onset - prediction)
  choices <- c(list(pooled = errors), split(errors, errors$cohort))
  do.call(rbind, lapply(names(choices), function(cohort) {
    sample <- choices[[cohort]]
    data.frame(spec, cohort = cohort, n_animals = length(unique(sample$animal)),
               n_records = nrow(sample),
               rmse_stats(data.frame(baseline = sample$baseline^2, with_animal = sample$with_animal^2)),
               baseline_mae = mean(abs(sample$baseline)), animal_mae = mean(abs(sample$with_animal)),
               zero_variance = effect_scales(model)$zero_variance, row.names = NULL)
  }))
}

paired_contrasts <- function(estimates, forecasts) {
  axes <- c("spread", "temporary", "calendar")
  contrasts <- lapply(axes, function(axis) {
    choices <- unique(specifications[[axis]])
    first <- specifications[specifications[[axis]] == choices[1L], ]
    second <- specifications[specifications[[axis]] == choices[2L], ]
    pairs <- merge(first, second, by = setdiff(axes, axis), suffixes = c("_from", "_to"))
    estimate_for <- function(spec, cohort) {
      row <- estimates[estimates$spec == spec & estimates$cohort %in% c(cohort, "common"), ]
      stopifnot(nrow(row) == 1L)
      row$persistent_sd
    }
    do.call(rbind, lapply(seq_len(nrow(pairs)), function(i) {
      from <- pairs$spec_from[i]
      to <- pairs$spec_to[i]
      a <- forecasts[forecasts$spec == from, ]
      b <- forecasts[forecasts$spec == to, ]
      stopifnot(identical(a$cohort, b$cohort))
      stable_change <- vapply(a$cohort, function(cohort) {
        if (cohort == "pooled") return(NA_real_)
        estimate_for(to, cohort) - estimate_for(from, cohort)
      }, numeric(1))
      data.frame(choice = axis, from = from, to = to, cohort = a$cohort,
                 persistent_sd_change = stable_change,
                 forecast_rmse_change = b$animal_rmse - a$animal_rmse,
                 matched_baseline_gain_change = b$rmse_gain - a$rmse_gain)
    }))
  })
  do.call(rbind, contrasts)
}

run_observed <- function() {
  schedule <- read_multiverse_schedule(include_onsets = TRUE)
  fold <- forecast_split(schedule)
  train <- schedule[fold$train, ]
  test <- schedule[fold$test, ]
  calendars <- unique(specifications$calendar)
  baselines <- setNames(lapply(calendars, function(calendar) {
    base <- fit_model(model_formula(list(calendar = calendar), include_animals = FALSE), train)
    test$onset - predict(base, test, allow.new.levels = TRUE)
  }), calendars)

  observed <- lapply(seq_len(nrow(specifications)), function(i) {
    spec <- specifications[i, ]
    list(estimates = observed_estimates(schedule, spec),
         forecasts = forecast_summary(spec, train, test, baselines[[spec$calendar]]))
  })
  estimates <- do.call(rbind, lapply(observed, `[[`, "estimates"))
  forecasts <- do.call(rbind, lapply(observed, `[[`, "forecasts"))
  contrasts <- paired_contrasts(estimates, forecasts)
  stopifnot(nrow(estimates) == 12L, nrow(forecasts) == 24L, nrow(contrasts) == 36L,
            all(forecasts$n_records[forecasts$cohort == "pooled"] == 325L))
  write.csv(estimates, file.path(output_dir, "titi-multiverse-estimates.csv"), row.names = FALSE)
  write.csv(forecasts, file.path(output_dir, "titi-multiverse-forecasts.csv"), row.names = FALSE)
  write.csv(contrasts, file.path(output_dir, "titi-multiverse-contrasts.csv"), row.names = FALSE)
  message("Wrote estimates, forecasts, and paired contrasts for eight specifications.")
}

plot_observed <- function() {
  source("analysis/primate-figure-style.R")
  forecasts <- read.csv(file.path(output_dir, "titi-multiverse-forecasts.csv"))
  forecasts <- subset(forecasts, cohort == "pooled")
  forecasts <- forecasts[match(specifications$spec, forecasts$spec), ]
  stopifnot(nrow(forecasts) == 8L, all(forecasts$n_records == 325L))
  labels <- with(forecasts, paste0(ifelse(spread == "common", "Common", "By cohort"),
    ", date", ifelse(calendar == "date_and_trend", " + trend", ""),
    ifelse(temporary == "fortnight", " + fortnight", "")))
  rows <- rev(seq_len(nrow(forecasts)))
  ink <- "#2D2D2D"
  blue <- "#2E5077"
  muted <- "#737373"

  draw <- function(family) {
    primate_figure_text(family)
    par(mai = c(0.59, 1.96, 0.38, 0.22))
    ticks <- pretty(c(forecasts$baseline_rmse, forecasts$animal_rmse), n = 6)
    plot(NA_real_, xlim = range(ticks), ylim = c(0.45, 9.25), xaxs = "i", yaxs = "i",
         xlab = "Fixed-holdout RMSE (minutes)", ylab = "", axes = FALSE)
    abline(h = rows, col = "#E8E8E8")
    axis(1, at = ticks, col = ink, col.axis = ink)
    axis(2, at = rows, labels = labels, las = 1, tick = FALSE, col.axis = ink)
    segments(forecasts$baseline_rmse, rows, forecasts$animal_rmse, rows, col = muted, lwd = 1.3)
    points(forecasts$baseline_rmse, rows, pch = 22, cex = 1.15, bg = "white", col = ink)
    points(forecasts$animal_rmse, rows, pch = 16, cex = 1.1, col = blue)
    title("Titi activity-onset forecasts", adj = 0, line = 0.8, col.main = ink)
    legend("topright", legend = c("Matched baseline", "Animal model"),
           pch = c(22, 16), pt.bg = c("white", blue), pt.cex = c(1.15, 1.1),
           col = c(ink, blue), horiz = TRUE, bty = "n", cex = 0.88)
  }
  render_primate_figure(file.path(output_dir, "titi-multiverse"), draw, width = 7.3, height = 4.0)
}

simulation_attempt <- function(spec, formula, schedule, seed) {
  tryCatch({
    scales <- effect_scales(fit_model(formula, schedule))
    data.frame(spec, seed = seed, cohort = names(scales$persistent),
               persistent_estimate = unname(scales$persistent),
               fortnight_estimate = scales$temporary, zero_variance = scales$zero_variance,
               problem = "", row.names = NULL)
  }, error = function(err) {
    cohorts <- if (spec$spread == "common") "common" else levels(schedule$cohort)
    data.frame(spec, seed = seed, cohort = cohorts, persistent_estimate = NA_real_,
               fortnight_estimate = NA_real_, zero_variance = NA,
               problem = conditionMessage(err), row.names = NULL)
  })
}

simulation_summary <- function(draws, condition) {
  summarize <- function(values) {
    if (all(is.na(values))) return(rep(NA_real_, 3L))
    unname(quantile(values, c(0.1, 0.5, 0.9), na.rm = TRUE))
  }
  do.call(rbind, lapply(split(draws, list(draws$spec, draws$cohort), drop = TRUE), function(x) {
    stable <- summarize(x$persistent_estimate)
    fortnight <- summarize(x$fortnight_estimate)
    data.frame(x[1L, c(names(specifications), "cohort")], condition,
               attempted = nrow(x), fitted = sum(x$problem == ""),
               zero_variance_fits = sum(x$zero_variance, na.rm = TRUE),
               persistent_q10 = stable[1L], persistent_median = stable[2L], persistent_q90 = stable[3L],
               fortnight_q10 = fortnight[1L], fortnight_median = fortnight[2L],
               fortnight_q90 = fortnight[3L])
  }))
}

run_replay <- function() {
  schedule <- read_multiverse_schedule()
  stopifnot(!"onset" %in% names(schedule))
  seed_table <- read.csv(file.path(output_dir, "titi-simulation-runs.csv"))
  stopifnot(nrow(seed_table) == 1000L, !anyDuplicated(seed_table$seed))
  condition_fields <- c("persistent_sd", "temporary_sd", "residual_sd")
  conditions <- unique(seed_table[condition_fields])
  formulas <- lapply(seq_len(nrow(specifications)), function(i) model_formula(specifications[i, ]))
  problems <- list()
  summaries <- lapply(seq_len(nrow(conditions)), function(i) {
    condition <- conditions[i, ]
    seeds <- seed_table$seed[seed_table$persistent_sd == condition$persistent_sd &
                             seed_table$temporary_sd == condition$temporary_sd &
                             seed_table$residual_sd == condition$residual_sd]
    stopifnot(length(seeds) == 100L)
    draws <- do.call(rbind, lapply(seeds, function(seed) {
      set.seed(seed)
      schedule$onset <- simulate_onsets(schedule, condition$persistent_sd,
                                        condition$temporary_sd, condition$residual_sd)
      do.call(rbind, lapply(seq_len(nrow(specifications)), function(j) {
        simulation_attempt(specifications[j, ], formulas[[j]], schedule, seed)
      }))
    }))
    problems[[i]] <<- draws[draws$problem != "", c("spec", "seed", "cohort", "problem")]
    message(sprintf("Replayed condition %d/%d (persistent %g, temporary %g, residual %g minutes)",
                    i, nrow(conditions), condition$persistent_sd, condition$temporary_sd,
                    condition$residual_sd))
    simulation_summary(draws, condition)
  })
  summaries <- do.call(rbind, summaries)
  stopifnot(nrow(summaries) == 120L, all(summaries$attempted == 100L))
  write.csv(summaries, file.path(output_dir, "titi-multiverse-simulations.csv"), row.names = FALSE)
  problems <- do.call(rbind, problems)
  problems_file <- file.path(output_dir, "titi-multiverse-simulation-problems.csv")
  if (nrow(problems)) write.csv(problems, problems_file, row.names = FALSE)
  else if (file.exists(problems_file)) unlink(problems_file)
  message(sprintf("Finished 8,000 fits. %d failed specification-seed pairs.",
                  nrow(unique(problems[c("spec", "seed")]))))
}

if (sys.nframe() == 0L) {
  mode <- commandArgs(trailingOnly = TRUE)
  if (!length(mode)) mode <- "all"
  if (length(mode) != 1L || !mode %in% c("all", "observed", "replay", "plot")) {
    stop("Usage: Rscript analysis/titi-multiverse.R [all|observed|replay|plot]")
  }
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  if (mode %in% c("all", "observed")) run_observed()
  if (mode %in% c("all", "observed", "plot")) plot_observed()
  if (mode %in% c("all", "replay")) run_replay()
}
