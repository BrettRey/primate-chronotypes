source("analysis/primate-figure-style.R")

results <- "analysis/results"
titi <- read.csv(file.path(results, "titi-multiverse-estimates.csv"))
titi_forecasts <- subset(read.csv(file.path(results, "titi-multiverse-forecasts.csv")), cohort == "pooled")
baboon <- subset(read.csv(file.path(results, "baboon-sleep-estimates.csv")), sample == "full")
baboon_forecasts <- read.csv(file.path(results, "baboon-sleep-forecasts.csv"))

stopifnot(nrow(titi) == 12L, nrow(titi_forecasts) == 8L,
          nrow(baboon) == 8L, nrow(baboon_forecasts) == 8L,
          all(titi_forecasts$n_records == 325L), all(baboon_forecasts$n_test_pairs == 85L))

ink <- "#17232D"
muted <- "#52616E"
grid <- "#DFE5E9"
blue <- "#1A638D"
amber <- "#A34A13"

plot_labels <- function(trend, temporary) {
  paste0("Date", ifelse(trend, " + trend", ""), ifelse(temporary, " + fortnight", ""))
}

panel <- function(labels, xlim, ticks, xlab, title = "", reference = FALSE) {
  rows <- rev(seq_along(labels))
  plot(NA_real_, xlim = xlim, ylim = c(0.45, length(labels) + 1.45),
       xaxs = "i", yaxs = "i", axes = FALSE, xlab = "", ylab = "")
  segments(xlim[1L], rows, xlim[2L], rows, col = grid, lwd = 0.8)
  if (reference) abline(v = 0, lty = 2, lwd = 1, col = muted)
  axis(1, at = ticks, col = muted, col.axis = ink, lwd = 0, lwd.ticks = 0.8)
  if (any(nzchar(labels))) {
    axis(2, at = rows, labels = labels, las = 1, tick = FALSE, col.axis = ink)
  }
  mtext(xlab, side = 1, line = 2.1, col = ink)
  if (nzchar(title)) title(main = title, adj = 0, line = 1.15, col.main = ink)
}

draw_summary <- function(family) {
  layout(matrix(1:4, byrow = TRUE, nrow = 2), widths = c(1.5, 1), heights = c(1.55, 1))
  primate_figure_text(family)
  spread_xlim <- c(-0.4, 27)
  gain_xlim <- c(-2.15, 1.25)
  spread_ticks <- seq(0, 25, by = 5)
  gain_ticks <- c(-2, -1, 0, 1)

  # Group the titi models by whether they share an animal variance across cohorts.
  ti <- titi_forecasts[order(titi_forecasts$spread, titi_forecasts$temporary == "fortnight",
                             titi_forecasts$calendar), ]
  ti$label <- paste(ifelse(ti$spread == "common", "Common", "By cohort"),
                    plot_labels(ti$calendar == "date_and_trend", ti$temporary == "fortnight"),
                    sep = ", ")
  ti_y <- setNames(rev(seq_len(nrow(ti))), ti$spec)
  cohorts <- c("common", "2023", "2024")
  ci <- match(titi$cohort, cohorts)
  ty <- unname(ti_y[titi$spec]) + c(0, 0.18, -0.18)[ci]
  titi_col <- c(ink, blue, amber)
  titi_pch <- c(16, 17, 15)

  left_margin <- max(1.96, max(strwidth(ti$label, units = "inches", cex = par("cex.axis"))) + 0.25)
  par(mai = c(0.61, left_margin, 0.43, 0.12))
  panel(ti$label, spread_xlim, spread_ticks, "Between-animal SD (minutes)", "Titi activity onset")
  segments(titi$lower_95, ty, titi$upper_95, ty, col = titi_col[ci], lwd = 1.6)
  points(titi$persistent_sd, ty, pch = titi_pch[ci], col = titi_col[ci], cex = 0.9)
  legend("topright", legend = c("Common", "2023", "2024"),
         pch = titi_pch, col = titi_col, horiz = TRUE, bty = "n", text.col = ink, cex = 0.9)

  par(mai = c(0.61, 0.16, 0.43, 0.18))
  panel(rep("", nrow(ti)), gain_xlim, gain_ticks, "Forecast RMSE gain (minutes)",
        "Later dates, 325 observations", reference = TRUE)
  mtext("Baseline omits all animal effects", side = 3, line = 0, adj = 0, col = ink)
  points(ti$rmse_gain, ti_y[ti$spec], col = ink, pch = 16)

  ba <- subset(baboon_forecasts, endpoint == "onset")
  ba <- ba[order(ba$temporary, ba$trend), ]
  ba$label <- plot_labels(ba$trend, ba$temporary)
  ba_y <- setNames(rev(seq_len(nrow(ba))), ba$label)
  endpoint_index <- function(endpoint) match(endpoint, c("onset", "waking"))
  endpoint_col <- c(blue, amber)
  endpoint_pch <- c(17, 15)
  baboon_positions <- function(data) {
    unname(ba_y[plot_labels(data$trend, data$temporary)]) +
      c(0.15, -0.15)[endpoint_index(data$endpoint)]
  }

  par(mai = c(0.61, left_margin, 0.43, 0.12))
  panel(ba$label, spread_xlim, spread_ticks, "Between-animal SD (minutes)", "Baboon sleep timing")
  bi <- endpoint_index(baboon$endpoint)
  by <- baboon_positions(baboon)
  segments(baboon$animal_lower_95, by, baboon$animal_upper_95, by, col = endpoint_col[bi], lwd = 1.6)
  points(baboon$animal_sd, by, pch = endpoint_pch[bi], col = endpoint_col[bi], cex = 0.9)
  legend("topright", legend = c("Period onset", "Period end"),
         pch = endpoint_pch, col = endpoint_col, horiz = TRUE, bty = "n", text.col = ink, cex = 0.9)

  par(mai = c(0.61, 0.16, 0.43, 0.18))
  panel(rep("", nrow(ba)), gain_xlim, gain_ticks, "Forecast RMSE gain (minutes)",
        "Later dates, 85 baboon-nights", reference = TRUE)
  mtext("Baseline omits persistent animal effect", side = 3, line = 0, adj = 0, col = ink)
  fi <- endpoint_index(baboon_forecasts$endpoint)
  points(baboon_forecasts$rmse_gain, baboon_positions(baboon_forecasts),
         pch = endpoint_pch[fi], col = endpoint_col[fi], cex = 0.9)
}

render_primate_figure(file.path(results, "primate-timing-summary"), draw_summary,
                      width = 7.3, height = 5.0)
