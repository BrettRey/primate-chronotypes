source("analysis/simulate-titi-onset.R")

window_days <- 10L
window_formula <- onset ~ 1 + (1 | date) + (1 | animal)
output_dir <- "analysis/results"

window_statistics <- function(train, test) {
  fit <- fit_model(window_formula, train)
  prediction <- predict(fit, newdata = test, allow.new.levels = TRUE)
  c(spread = unname(attr(VarCorr(fit)$animal, "stddev")),
    rmse = sqrt(mean((test$onset - prediction)^2)))
}

compare_window <- function(train, test, start) {
  end <- start + window_days - 1L
  within_window <- train$day >= start & train$day <= end
  animals <- intersect(as.character(train$animal[within_window]), as.character(test$animal))
  earlier <- droplevels(train[train$animal %in% animals & train$day <= end, ])
  short <- droplevels(earlier[earlier$day >= start, ])
  later <- test[test$animal %in% animals, ]
  stopifnot(identical(sort(unique(as.character(short$animal))), sort(unique(as.character(later$animal)))),
            identical(sort(unique(as.character(short$animal))), sort(unique(as.character(earlier$animal)))),
            all(earlier$day < min(test$day)))
  row <- data.frame(
    cohort = as.character(train$cohort[1L]), start = start, end = end,
    n_animals = length(animals), n_short = nrow(short), n_long = nrow(earlier),
    n_later = nrow(later), short_dates = nlevels(short$date), long_dates = nlevels(earlier$date),
    short_spread = NA_real_, long_spread = NA_real_, spread_change = NA_real_,
    short_rmse = NA_real_, long_rmse = NA_real_, rmse_change = NA_real_, note = ""
  )
  if (nrow(earlier) == nrow(short)) {
    row$note <- "No additional earlier observations for the matched animals"
    return(row)
  }
  groups <- c(nlevels(short$animal), nlevels(short$date))
  if (any(groups < 2L) || nrow(short) <= max(groups)) {
    row$note <- "Insufficient replication to fit both animal and date variances"
    return(row)
  }
  tryCatch({
    short_fit <- window_statistics(short, later)
    long_fit <- window_statistics(earlier, later)
    row$short_spread <- short_fit[["spread"]]
    row$long_spread <- long_fit[["spread"]]
    row$spread_change <- row$short_spread - row$long_spread
    row$short_rmse <- short_fit[["rmse"]]
    row$long_rmse <- long_fit[["rmse"]]
    row$rmse_change <- row$short_rmse - row$long_rmse
    row
  }, error = function(err) {
    row$note <- conditionMessage(err)
    row
  })
}

summarize_cohort <- function(rows) {
  comparable <- rows[rows$note == "", ]
  qs <- function(x) unname(quantile(x, c(0.1, 0.5, 0.9)))
  spread <- qs(comparable$spread_change)
  rmse <- qs(comparable$rmse_change)
  data.frame(
    cohort = rows$cohort[1L], windows = nrow(rows), matched = nrow(comparable),
    min_animals = min(comparable$n_animals), max_animals = max(comparable$n_animals),
    median_short_spread = median(comparable$short_spread), median_long_spread = median(comparable$long_spread),
    spread_change_q10 = spread[1L], spread_change_median = spread[2L], spread_change_q90 = spread[3L],
    median_short_rmse = median(comparable$short_rmse), median_long_rmse = median(comparable$long_rmse),
    rmse_change_q10 = rmse[1L], rmse_change_median = rmse[2L], rmse_change_q90 = rmse[3L]
  )
}

main <- function() {
  schedule <- read_schedule(include_onsets = TRUE)
  fold <- forecast_split(schedule)
  by_cohort <- lapply(levels(schedule$cohort), function(cohort) {
    train <- schedule[fold$train & schedule$cohort == cohort, ]
    test <- schedule[fold$test & schedule$cohort == cohort, ]
    starts <- seq(min(train$day), max(train$day) - window_days + 1L, by = "day")
    do.call(rbind, lapply(starts, function(start) compare_window(train, test, start)))
  })
  windows <- do.call(rbind, by_cohort)
  summary <- do.call(rbind, lapply(by_cohort, summarize_cohort))
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  write.csv(windows, file.path(output_dir, "titi-ten-day-windows.csv"), row.names = FALSE)
  write.csv(summary, file.path(output_dir, "titi-ten-day-summary.csv"), row.names = FALSE)
  print(summary, row.names = FALSE, digits = 4)
  if (any(windows$note != "")) print(table(windows$note[windows$note != ""]))
}

main()
