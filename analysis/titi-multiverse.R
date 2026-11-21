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
                       with_animal = (test$onset - prediction)^2)
  choices <- c(list(pooled = errors), split(errors, errors$cohort))
  do.call(rbind, lapply(names(choices), function(cohort) {
    sample <- choices[[cohort]]
    data.frame(spec, cohort = cohort, n_animals = length(unique(sample$animal)),
               n_records = nrow(sample), rmse_stats(sample),
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
    (test$onset - predict(base, test, allow.new.levels = TRUE))^2
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
  estimates <- read.csv(file.path(output_dir, "titi-multiverse-estimates.csv"))
  forecasts <- read.csv(file.path(output_dir, "titi-multiverse-forecasts.csv"))
  forecasts <- forecasts[forecasts$cohort == "pooled", ]
  labels <- with(specifications, paste(spec,
    paste(ifelse(spread == "common", "Common", "Separate"),
          ifelse(temporary == "none", "stable", "fortnight"),
          ifelse(calendar == "date", "dates", "trend"), sep = " / ")))
  rows <- setNames(rev(seq_len(nrow(specifications))), specifications$spec)
  cohorts <- c("common", "2023", "2024")
  palette <- setNames(c("#313841", "#245C9E", "#AB481F"), cohorts)
  symbols <- setNames(c(16, 17, 15), cohorts)
  offsets <- setNames(c(0, 0.15, -0.15), cohorts)

  png(file.path(output_dir, "titi-multiverse.png"), width = 1800, height = 1000,
      res = 160, type = "cairo", bg = "white")
  on.exit(dev.off())
  layout(matrix(1:2, nrow = 1L), widths = c(1.65, 1))
  par(oma = c(2, 0, 3, 0))

  par(mar = c(4, 14, 2, 1))
  upper <- max(estimates$persistent_sd, estimates$upper_95, na.rm = TRUE)
  plot(NA, xlim = c(0, upper * 1.06), ylim = c(0.12, 8.6), xlab = "Minutes",
       ylab = "", yaxt = "n", bty = "n")
  abline(h = rows, col = "#E4E8ED")
  axis(2, at = rows, labels = labels, las = 1, tick = FALSE, cex.axis = 0.79)
  y <- unname(rows[estimates$spec] + offsets[estimates$cohort])
  segments(estimates$lower_95, y, estimates$upper_95, y,
           lwd = 2, col = palette[estimates$cohort])
  points(estimates$persistent_sd, y, pch = symbols[estimates$cohort],
         col = palette[estimates$cohort], cex = 1.15)
  title("Estimated persistent spread", adj = 0)
  legend("bottomright", legend = c("Common", "2023", "2024"), horiz = TRUE,
         pch = symbols, col = palette, bty = "n", cex = 0.73)

  par(mar = c(4, 1.1, 2, 1.3))
  x_range <- extendrange(c(forecasts$baseline_rmse, forecasts$animal_rmse), f = 0.12)
  plot(NA, xlim = x_range, ylim = c(0.12, 8.6), xlab = "RMSE in minutes",
       ylab = "", yaxt = "n", bty = "n")
  abline(h = rows, col = "#E4E8ED")
  y <- unname(rows[forecasts$spec])
  segments(forecasts$baseline_rmse, y - 0.12, forecasts$animal_rmse, y + 0.12,
           col = "#86939D", lwd = 1.5)
  points(forecasts$baseline_rmse, y - 0.12, pch = 1, col = "#54616C", cex = 1.15)
  points(forecasts$animal_rmse, y + 0.12, pch = 16, col = "#1D7370", cex = 1.15)
  title("Forecasts on later dates", adj = 0)
  legend("bottomright", legend = c("Matched baseline", "Animal model"), horiz = TRUE,
         pch = c(1, 16), col = c("#54616C", "#1D7370"), bty = "n", cex = 0.73)
  mtext("Titi monkey activity onset across eight specifications", side = 3, outer = TRUE,
        line = 1, adj = 0.04, font = 2, cex = 1.15)
  mtext("Left: 95% profile likelihood intervals. Right: same 325 held-out observations in every specification.",
        side = 1, outer = TRUE, line = 0.5, adj = 0.04, cex = 0.75)
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

mode <- commandArgs(trailingOnly = TRUE)
if (!length(mode)) mode <- "all"
if (length(mode) != 1L || !mode %in% c("all", "observed", "replay", "plot")) {
  stop("Usage: Rscript analysis/titi-multiverse.R [all|observed|replay|plot]")
}
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
if (mode %in% c("all", "observed")) run_observed()
if (mode %in% c("all", "observed", "plot")) plot_observed()
if (mode %in% c("all", "replay")) run_replay()
