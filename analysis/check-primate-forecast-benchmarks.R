source("analysis/check-baboon-rolling-forecasts.R")

historical_errors <- function(train, test, endpoint, by_cohort = FALSE) {
  if (by_cohort) {
    mean_time <- tapply(train[[endpoint]], train$cohort, mean)[as.character(test$cohort)]
    median_time <- tapply(train[[endpoint]], train$cohort, median)[as.character(test$cohort)]
  } else {
    mean_time <- mean(train[[endpoint]])
    median_time <- median(train[[endpoint]])
  }
  data.frame(day = test$day, animal = test$animal,
             mean_error = test[[endpoint]] - mean_time,
             median_error = test[[endpoint]] - median_time, row.names = NULL)
}

benchmark_scores <- function(errors, dataset, endpoint, evaluation) {
  data.frame(dataset, endpoint, evaluation, n_records = nrow(errors),
             n_dates = length(unique(errors$day)),
             mean_rmse = sqrt(mean(errors$mean_error^2)), mean_mae = mean(abs(errors$mean_error)),
             median_rmse = sqrt(mean(errors$median_error^2)), median_mae = mean(abs(errors$median_error)))
}

run_primate_benchmarks <- function(output_dir = "analysis/results") {
  titi <- read_schedule(include_onsets = TRUE)
  split <- forecast_split(titi)
  titi_errors <- historical_errors(titi[split$train, ], titi[split$test, ], "onset", by_cohort = TRUE)

  baboons <- read_baboon_nights(file.path(output_dir, "baboon-sleep-pairs.csv"))
  late_start <- baboon_late_start(sort(unique(baboons$day)))
  train <- baboons[baboons$day < late_start, ]
  test <- baboons[baboons$day >= late_start & baboons$animal %in% train$animal, ]
  origins <- baboon_rolling_origins(baboons)
  baboon_rows <- lapply(c("onset", "waking"), function(endpoint) {
    fixed <- historical_errors(train, test, endpoint)
    rolling <- do.call(rbind, lapply(origins, function(origin) {
      historical_errors(origin$train, origin$test, endpoint)
    }))
    late <- rolling[rolling$day >= late_start, ]
    stopifnot(nrow(fixed) == 85L, nrow(rolling) == 156L,
              identical(paste(fixed$day, fixed$animal), paste(late$day, late$animal)))
    rbind(benchmark_scores(fixed, "baboon", endpoint, "fixed"),
          benchmark_scores(rolling, "baboon", endpoint, "rolling"),
          benchmark_scores(late, "baboon", endpoint, "rolling_late"))
  })
  scores <- rbind(benchmark_scores(titi_errors, "titi", "onset", "fixed"),
                  do.call(rbind, baboon_rows))
  stopifnot(all(is.finite(scores[c("mean_rmse", "mean_mae", "median_rmse", "median_mae")] |> as.matrix())))
  write.csv(scores, file.path(output_dir, "primate-forecast-benchmarks.csv"), row.names = FALSE)
}

if (sys.nframe() == 0L) run_primate_benchmarks()
