source("analysis/fit-baboon-sleep.R")
source("analysis/primate-figure-style.R")

results <- "analysis/results"
titi <- read_schedule(include_onsets = TRUE)
baboons <- read_baboon_nights(file.path(results, "baboon-sleep-pairs.csv"))
simulations <- read.csv(file.path(results, "titi-multiverse-simulations.csv"))
recovery <- subset(simulations, spec %in% c("M01", "M03") & cohort == "common" &
                     persistent_sd == 0 & temporary_sd == 20 & residual_sd == 20)
recovery <- recovery[match(c("M01", "M03"), recovery$spec), ]
stopifnot(nrow(baboons) == 354L, !anyNA(recovery$spec),
          all(recovery$fitted == 100L), all(recovery$attempted == recovery$fitted))

ink <- "#2D2D2D"
blue <- "#2E5077"
rust <- "#A34A13"
observation_size <- 0.72
observation_outline_width <- 0.50
median_line_width <- 1.1

clock_labels <- function(minutes_from_noon) {
  hour <- ((minutes_from_noon / 60) + 12) %% 24
  sprintf("%02d:00", as.integer(hour))
}

draw_timing_marks <- function(day, timing) {
  points(day, timing, pch = 21, cex = observation_size, col = "black", bg = "white",
         lwd = observation_outline_width)
  daily <- aggregate(timing ~ day, FUN = median)
  half_width <- diff(grconvertX(c(0, 0.024), from = "inches"))
  segments(daily$day - half_width, daily$timing, daily$day + half_width, daily$timing,
           col = rust, lwd = median_line_width, lend = "butt")
}

draw_titi_panel <- function() {
  periods <- lapply(split(titi$day, titi$cohort), range)
  stopifnot(length(periods) == 2L, all(is.finite(titi$onset)),
            all(titi$onset >= -120 & titi$onset <= 180))
  # Shift the later cohort as a unit to leave room for the axis break.
  gap <- as.numeric(periods[[2L]][1L] - periods[[1L]][2L])
  offsets <- setNames(c(0, gap - 8), names(periods))
  display_day <- as.numeric(titi$day) - offsets[as.character(titi$cohort)]
  display_periods <- Map(`-`, lapply(periods, as.numeric), offsets)

  par(mai = c(0.55, 0.78, 0.52, 0.17))
  plot(display_day, titi$onset, type = "n", axes = FALSE, xlab = "Date",
       ylab = "Minutes from lights-on", ylim = c(-120, 180), yaxs = "i")
  axis(2, at = seq(-120, 180, 60), las = 1, col = ink, col.axis = ink)
  for (cohort in names(periods)) {
    period <- periods[[cohort]]
    displayed <- display_periods[[cohort]]
    earlier <- cohort == names(periods)[1L]
    n_ticks <- if (earlier) 3L else 5L
    ticks <- seq(period[1L], period[2L], length.out = n_ticks)
    tick_positions <- as.numeric(ticks) - offsets[[cohort]]
    tick_labels <- format(ticks, "%d %b")
    break_tick <- if (earlier) n_ticks else 1L
    axis(1, at = tick_positions, labels = replace(tick_labels, break_tick, ""),
         col = ink, col.axis = ink)
    axis(1, at = tick_positions[break_tick], labels = tick_labels[break_tick],
         hadj = as.integer(earlier), lwd = 0, col.axis = ink)
    mtext(cohort, side = 3, at = mean(displayed), line = 0.12, col = ink)
    segments(displayed[1L], 0, displayed[2L], 0, lty = 2, col = "#9A9A9A")
  }
  break_at <- mean(c(display_periods[[1L]][2L], display_periods[[2L]][1L]))
  mtext("//", side = 1, at = break_at, line = -0.30, col = ink)
  draw_timing_marks(display_day, titi$onset)
  title(main = "Titi activity onset", adj = 0, line = 1.42, col.main = ink)
}

draw_baboon_panel <- function(day, timing, title, ticks) {
  limits <- range(ticks)
  stopifnot(all(is.finite(timing)), all(timing >= limits[1L] & timing <= limits[2L]))
  par(mai = c(0.55, 0.78, 0.34, 0.17))
  plot(day, timing, type = "n", axes = FALSE, xlab = "Date", ylab = "Local clock time",
       ylim = limits, yaxs = "i")
  date_ticks <- seq(min(day), max(day), length.out = 5L)
  axis(1, at = date_ticks, labels = format(date_ticks, "%d %b"), col = ink, col.axis = ink)
  axis(2, at = ticks, labels = clock_labels(ticks), las = 1, col = ink, col.axis = ink)
  draw_timing_marks(day, timing)
  title(main = title, adj = 0, line = 0.8, col.main = ink)
}

draw_observations <- function(family) {
  layout(rbind(c(1, 1), c(2, 2), c(3, 4)), heights = c(0.32, 2.65, 2.65))
  primate_figure_text(family)
  par(mai = rep(0, 4))
  plot.new()
  keys <- c("Individual observation", "Daily median")
  legend("center", legend = keys, text.width = strwidth(keys) + c(strwidth("M"), 0),
         pch = c(21, NA), lty = c(0, 1), col = c("black", rust), pt.bg = "white",
         pt.cex = observation_size, pt.lwd = observation_outline_width,
         lwd = median_line_width, seg.len = 0.65, merge = TRUE,
         bty = "n", horiz = TRUE, text.col = ink)
  draw_titi_panel()
  draw_baboon_panel(baboons$day, baboons$onset, "Baboon sleep onset", seq(240, 720, by = 120))
  draw_baboon_panel(baboons$day, baboons$waking, "Baboon final waking", seq(780, 1260, by = 120))
}

draw_recovery <- function(family) {
  primate_figure_text(family)
  par(mai = c(0.60, 1.82, 0.39, 0.22))
  plot(NA_real_, axes = FALSE, xlab = "Estimated persistent between-animal SD (minutes)",
       ylab = "", xlim = c(-0.25, 15), ylim = c(0.42, 3.05), xaxs = "i", yaxs = "i")
  axis(1, at = seq(0, 15, 3), col = ink, col.axis = ink)
  axis(2, at = 2:1, labels = c("Temporary shifts omitted", "Temporary shifts included"),
       tick = FALSE, las = 1, col.axis = ink)
  abline(v = 0, lty = 2, col = "#777777")
  segments(recovery$persistent_q10, 2:1, recovery$persistent_q90, 2:1, col = blue, lwd = 2)
  primate_median_ticks(recovery$persistent_median, 2:1, col = rust)
  title(main = "Titi simulation with zero persistent spread", adj = 0, line = 0.8, col.main = ink)
  legend("topright", legend = c("10th–90th percentile", "Median", "True spread"),
         lty = c(1, NA, 2), lwd = c(2, NA, 1), pch = c(NA, 124, NA),
         col = c(blue, rust, "#777777"), pt.cex = 0.60, cex = 0.92,
         bty = "n", horiz = TRUE, text.col = ink)
}

render_primate_figure(file.path(results, "primate-timing-observations"), draw_observations,
                      width = 7.3, height = 5.62)
render_primate_figure(file.path(results, "titi-simulation-recovery"), draw_recovery,
                      width = 7.3, height = 2.45)
