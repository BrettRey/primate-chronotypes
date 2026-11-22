source("analysis/fit-baboon-sleep.R")
source("analysis/primate-figure-style.R")

results <- "analysis/results"
windows <- read.csv(file.path(results, "titi-ten-day-windows.csv"))
windows <- windows[windows$note == "", ]
schedule <- read_baboon_nights(file.path(results, "baboon-sleep-pairs.csv"))
first_test <- baboon_late_start(sort(unique(schedule$day)))
train <- schedule[schedule$day < first_test, ]
test <- schedule[schedule$day >= first_test & schedule$animal %in% train$animal, ]

endpoints <- c("onset", "waking")
fits <- setNames(lapply(endpoints, function(endpoint) {
  fit_model(baboon_formula(endpoint, trend = FALSE, temporary = FALSE), train)
}), endpoints)
errors <- setNames(lapply(endpoints, function(endpoint) {
  data.frame(day = test$day, animal_error = test[[endpoint]] -
               predict(fits[[endpoint]], test, allow.new.levels = TRUE))
}), endpoints)
stopifnot(nrow(windows) == 123L, nrow(test) == 85L, all(is.finite(windows$spread_change)))

gaussian_error_check <- function(fit, observed) {
  date_index <- as.integer(factor(test$day))
  n_dates <- max(date_index)
  night_sd <- as.numeric(attr(VarCorr(fit)$date, "stddev"))
  set.seed(73695)
  maxima <- replicate(2000L, {
    night_errors <- rnorm(n_dates, sd = night_sd)[date_index]
    max(abs(night_errors + rnorm(nrow(test), sd = sigma(fit))))
  })
  baboon_simulated_maximum_summary(observed, maxima)
}

draw_diagnostics <- function(family) {
  layout(matrix(1:2, ncol = 1), heights = c(0.98, 1.18))
  ink <- "#17232D"
  muted <- "#52616E"
  grid <- "#DFE5E9"
  colours <- c("#1A638D", "#A34A13")
  window_blue <- adjustcolor(colours[1L], alpha.f = 0.5)
  primate_figure_text(family)

  par(mai = c(0.61, 0.78, 0.40, 0.14))
  plot(NA_real_, xlim = extendrange(windows$spread_change, f = 0.06), ylim = c(0.6, 2.95),
       xlab = "Ten-day minus longer-record spread (minutes)", ylab = "", axes = FALSE)
  abline(h = 1:2, col = grid)
  segments(0, 0.6, 0, 2.23, lty = 2, col = muted)
  axis(1, col = muted, col.axis = ink)
  axis(2, at = 2:1, labels = c("2023 (45)", "2024 (78)"), las = 1, tick = FALSE, col.axis = ink)
  title(main = "Titi activity onset across matched recording windows", adj = 0, col.main = ink)
  cohorts <- c(2023L, 2024L)
  for (i in seq_along(cohorts)) {
    delta <- windows$spread_change[windows$cohort == cohorts[i]]
    row <- 3L - i
    set.seed(829L + i)
    points(delta, row + runif(length(delta), -0.13, 0.13), pch = 16,
           cex = 0.75, col = window_blue)
    interval <- quantile(delta, c(0.1, 0.5, 0.9))
    segments(interval[1L], row - 0.24, interval[3L], row - 0.24, col = colours[1L], lwd = 2)
    primate_median_ticks(interval[2L], row - 0.24, col = colours[2L])
  }
  legend("topright", legend = c("Matched window", "Median", "10th–90th percentile"),
         pch = c(16, 124, NA), lty = c(NA, NA, 1), lwd = c(NA, NA, 2),
         col = c(window_blue, colours[2L], colours[1L]), pt.cex = c(0.75, 0.60, 1),
         horiz = TRUE, bty = "n", text.col = ink, cex = 0.92)

  par(mai = c(0.61, 0.78, 0.40, 0.14))
  dates <- sort(unique(test$day))
  ndates <- length(dates)
  y_range <- extendrange(unlist(lapply(errors, `[[`, "animal_error")), f = 0.1)
  plot(NA_real_, xlim = c(0.5, ndates + 0.5), ylim = y_range, xlab = "Forecast night, 2012",
       ylab = "Observed minus forecast (minutes)", axes = FALSE)
  abline(v = seq_len(ndates), col = grid)
  abline(h = 0, lty = 2, col = muted)
  axis(1, at = seq_len(ndates), labels = format(dates, "%b %d"), col = muted, col.axis = ink)
  axis(2, las = 1, col = muted, col.axis = ink)
  title(main = "Baboon timing errors on the fixed late block", adj = 0, col.main = ink)
  for (i in seq_along(errors)) {
    point_x <- match(errors[[i]]$day, dates) + c(-0.15, 0.15)[i]
    points(point_x, errors[[i]]$animal_error, pch = c(17, 15)[i],
           col = adjustcolor(colours[i], alpha.f = 0.65))
  }
  legend("bottomright", legend = c("Selected-period onset", "Selected-period end"), col = colours,
         pch = c(17, 15), horiz = TRUE, bty = "n", text.col = ink, cex = 0.9)
}

render_primate_figure(file.path(results, "primate-timing-diagnostics"), draw_diagnostics,
                      width = 7.3, height = 4.86)
maxima <- do.call(rbind, lapply(endpoints, function(endpoint) {
  data.frame(endpoint, gaussian_error_check(fits[[endpoint]], errors[[endpoint]]$animal_error))
}))
write.csv(maxima, file.path(results, "baboon-gaussian-error-maxima.csv"), row.names = FALSE)
print(maxima)

waking_by_date <- split(errors$waking$animal_error, errors$waking$day)
total_sq_error <- sum(errors$waking$animal_error^2)
concentration <- do.call(rbind, lapply(names(waking_by_date), function(day) {
  e <- waking_by_date[[day]]
  largest <- e[which.max(abs(e))]
  nightly_sq_error <- sum(e^2)
  data.frame(day, n_records = length(e), largest_signed_error = largest,
             night_share_of_total_sq_error = nightly_sq_error / total_sq_error,
             largest_share_of_night_sq_error = largest^2 / nightly_sq_error)
}))
write.csv(concentration, file.path(results, "baboon-fixed-waking-error-concentration.csv"),
          row.names = FALSE)
