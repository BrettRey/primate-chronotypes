source("analysis/fit-baboon-sleep.R")

baboon_paired_mse_scores <- function(errors) {
  # Compare the scoring targets on exactly the dates with two or more animals.
  errors <- errors[ave(seq_len(nrow(errors)), errors$day, FUN = length) > 1L, ]
  if (!nrow(errors)) {
    return(data.frame(paired_clock_mse_gain = NA_real_, paired_centered_mse_gain = NA_real_,
                      paired_dates = 0L, dates_clock_improved = 0L, dates_centered_improved = 0L))
  }
  center <- function(x) x - ave(x, errors$day)
  clock_gain <- errors$baseline_error^2 - errors$animal_error^2
  centered_gain <- center(errors$baseline_error)^2 - center(errors$animal_error)^2
  data.frame(paired_clock_mse_gain = mean(clock_gain), paired_centered_mse_gain = mean(centered_gain),
             paired_dates = length(unique(errors$day)),
             dates_clock_improved = sum(tapply(clock_gain, errors$day, mean) > 0),
             dates_centered_improved = sum(tapply(centered_gain, errors$day, mean) > 0))
}

rolling_baboon_spec <- function(spec, origins, late_start) {
  formula <- with(spec, baboon_formula(endpoint, trend, temporary))
  baseline <- with(spec, baboon_formula(endpoint, trend, temporary, persistent = FALSE))
  errors <- lapply(origins, function(origin) {
    baboon_forecast_errors(formula, baseline, spec$endpoint, origin$train, origin$test)
  })
  daily <- lapply(seq_along(origins), function(i) {
    data.frame(spec, day = origins[[i]]$day, n_train_pairs = nrow(origins[[i]]$train),
               baboon_forecast_scores(errors[[i]]), baboon_paired_mse_scores(errors[[i]]))
  })

  pooled <- do.call(rbind, errors)
  samples <- list(all_dates = pooled, earlier_dates = pooled[pooled$day < late_start, ],
                  original_late_dates = pooled[pooled$day >= late_start, ])
  summaries <- lapply(names(samples), function(sample) {
    records <- samples[[sample]]
    daily_squared <- tapply(records$animal_error^2, records$day, sum)
    largest_two_share <- sum(head(sort(daily_squared, decreasing = TRUE), 2L)) / sum(daily_squared)
    data.frame(spec, sample, first_date = min(records$day), last_date = max(records$day),
               baboon_forecast_scores(records), baboon_paired_mse_scores(records),
               animal_sq_error_share_top_two_dates = largest_two_share)
  })
  list(daily = do.call(rbind, daily), summary = do.call(rbind, summaries))
}

baboon_rolling_origins <- function(schedule) {
  dates <- sort(unique(schedule$day))
  # Training must cross a fortnight boundary to distinguish the two animal effects.
  origins <- lapply(dates[-seq_len(15L)], function(day) {
    train <- schedule[schedule$day < day, ]
    test <- schedule[schedule$day == day & schedule$animal %in% train$animal, ]
    list(day = day, train = train, test = test)
  })
  Filter(function(origin) nrow(origin$test) > 0L, origins)
}

run_baboon_rolling <- function(input = "analysis/results/baboon-sleep-pairs.csv",
                               output_dir = "analysis/results") {
  schedule <- read_baboon_nights(input)
  late_start <- baboon_late_start(sort(unique(schedule$day)))
  origins <- baboon_rolling_origins(schedule)
  results <- lapply(seq_len(nrow(baboon_specs)), function(i) {
    rolling_baboon_spec(baboon_specs[i, ], origins, late_start)
  })

  daily <- do.call(rbind, lapply(results, `[[`, "daily"))
  daily <- daily[order(daily$day, daily$endpoint, daily$trend, daily$temporary), ]
  summary <- do.call(rbind, lapply(results, `[[`, "summary"))
  write.csv(daily, file.path(output_dir, "baboon-rolling-by-night.csv"), row.names = FALSE)
  write.csv(summary, file.path(output_dir, "baboon-rolling-summary.csv"), row.names = FALSE)
}

if (sys.nframe() == 0L) run_baboon_rolling()
