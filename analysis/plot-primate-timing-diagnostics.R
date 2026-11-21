source("analysis/fit-baboon-sleep.R")

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
  c(observed_maximum = max(abs(observed)), simulated_median_maximum = median(maxima))
}

draw_diagnostics <- function(path) {
  png(path, width = 2020, height = 1270, res = 170, type = "cairo", bg = "white")
  on.exit(dev.off())
  layout(matrix(1:2, ncol = 1), heights = c(0.82, 1.18))
  ink <- "#17232D"
  muted <- "#52616E"
  grid <- "#DFE5E9"
  colours <- c("#1A638D", "#A34A13")
  par(family = "sans", cex = 0.9, mgp = c(2.2, 0.55, 0), tcl = -0.3)

  par(mar = c(4.0, 6.3, 3.3, 1.2))
  plot(NA_real_, xlim = extendrange(windows$spread_change, f = 0.06), ylim = c(0.6, 2.55),
       xlab = "Ten-day minus longer-record spread (minutes)", ylab = "", axes = FALSE)
  abline(h = 1:2, col = grid)
  abline(v = 0, lty = 2, col = muted)
  axis(1, col = muted, col.axis = ink)
  axis(2, at = 2:1, labels = c("2023 (45)", "2024 (78)"), las = 1, tick = FALSE, col.axis = ink)
  title(main = "Titi activity onset across matched recording windows", adj = 0, col.main = ink)
  for (i in seq_along(colours)) {
    delta <- windows$spread_change[windows$cohort == c(2023L, 2024L)[i]]
    row <- 3L - i
    set.seed(829L + i)
    points(delta, row + runif(length(delta), -0.13, 0.13),
           pch = 16, cex = 0.75, col = adjustcolor(colours[i], alpha.f = 0.5))
    interval <- quantile(delta, c(0.1, 0.5, 0.9))
    segments(interval[1L], row - 0.24, interval[3L], row - 0.24, col = colours[i], lwd = 2)
    points(interval[2L], row - 0.24, pch = 18, col = colours[i], cex = 1.22)
  }

  par(mar = c(4.0, 6.3, 3.3, 1.2))
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
  legend("bottomright", legend = c("Sleep onset", "Final waking"), col = colours,
         pch = c(17, 15), horiz = TRUE, bty = "n", text.col = ink)
}

draw_diagnostics(file.path(results, "primate-timing-diagnostics.png"))
print(t(vapply(endpoints, function(endpoint) {
  gaussian_error_check(fits[[endpoint]], errors[[endpoint]]$animal_error)
}, numeric(2L))))
