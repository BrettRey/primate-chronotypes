source("analysis/simulate-titi-onset.R")

estimate_spread <- function(data, formula, cohort) {
  fit <- fit_model(formula, data)
  effects <- VarCorr(fit)
  interval <- confint(fit, parm = "sd_(Intercept)|animal", method = "profile",
                      signames = FALSE, quiet = TRUE)
  stopifnot(nrow(interval) == 1L, all(is.finite(interval)))
  data.frame(
    cohort = cohort, n_animals = length(unique(data$animal)), n_records = nrow(data),
    animal_sd = unname(attr(effects$animal, "stddev")),
    animal_sd_lower_95 = interval[1L, 1L], animal_sd_upper_95 = interval[1L, 2L],
    date_sd = unname(attr(effects$date, "stddev")), residual_sd = sigma(fit),
    optimizer = fit@optinfo$optimizer
  )
}

main <- function() {
  output_dir <- "analysis/results"
  # The source plotting code labels `time` as hours from midnight.
  # The animal methods section reports lights-on at 06:00 during the study.
  schedule <- read_schedule(include_onsets = TRUE)
  fit_by_cohort <- lapply(levels(schedule$cohort), function(cohort) {
    data <- droplevels(schedule[schedule$cohort == cohort, ])
    estimate_spread(data, onset ~ 1 + (1 | date) + (1 | animal), cohort)
  })
  fits <- do.call(rbind, c(list(estimate_spread(schedule, animal_formula, "pooled")),
                         fit_by_cohort))

  errors <- forecast_errors(schedule, forecast_split(schedule))$errors
  summarize_forecast <- function(part, cohort) {
    data.frame(cohort = cohort, n_animals = length(unique(part$animal)),
               n_records = nrow(part), rmse_stats(part))
  }
  cohort_forecasts <- lapply(split(errors, errors$cohort), function(part) {
    summarize_forecast(part, as.character(part$cohort[1L]))
  })
  forecasts <- do.call(rbind, c(list(summarize_forecast(errors, "pooled")), cohort_forecasts))

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  write.csv(fits, file.path(output_dir, "titi-observed-fit.csv"), row.names = FALSE)
  write.csv(forecasts, file.path(output_dir, "titi-observed-forecast.csv"), row.names = FALSE)
  cat("Activity onset range (minutes relative to lights-on):", range(schedule$onset), "\n")
  print(fits, row.names = FALSE, digits = 4)
  print(forecasts, row.names = FALSE, digits = 4)
}

main()
