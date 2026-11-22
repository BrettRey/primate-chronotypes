source("analysis/primate-figure-style.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: Rscript analysis/plot-laikipia-waking-traces.R TRACE_CSV OUTPUT_PNG")
}
traces <- read.csv(args[1L])
zone <- "Africa/Nairobi"
traces$time <- as.POSIXct(traces$local_time, tz = zone)
day <- min(as.Date(traces$time, tz = zone))
noon <- as.POSIXct(paste(day, "12:00:00"), tz = zone)
traces$hour <- as.numeric(difftime(traces$time, noon, units = "hours"))
stopifnot(!anyNA(traces$hour), all(traces$hour >= 0 & traces$hour < 24))
limits <- range(traces$log_vedba[is.finite(traces$log_vedba)])
tags <- unique(traces$tag)

png(args[2L], width = 8.1, height = 4.5, units = "in", res = 250, type = "cairo", bg = "white")
primate_figure_text("EB Garamond")
par(mfrow = c(length(tags), 1), mar = c(1.75, 3.5, 1.55, 0.42), oma = c(1.25, 0, 1.55, 0))
for (tag in tags) {
  rows <- traces[traces$tag == tag, ]
  wake <- max(rows$time[rows$classified_period == "selected"])
  label <- paste(sub("^Pa ", "", tag), " · Selected period ends", format(wake, "%H:%M", tz = zone))
  plot(c(0, 24), limits, type = "n", xlab = "", ylab = "Log VeDBA",
       xaxt = "n", bty = "l")
  mtext(label, side = 3, line = 0.36, adj = 0)
  for (kind in c("selected", "later")) {
    runs <- rle(rows$classified_period == kind)
    ends <- cumsum(runs$lengths)
    starts <- ends - runs$lengths + 1L
    rect(rows$hour[starts[runs$values]], limits[1L], rows$hour[ends[runs$values]], limits[2L],
         col = if (kind == "selected") "#F0DBD0" else "#D8E7EE", border = NA)
  }
  grid <- merge(data.frame(hour = (0:1439) / 60), rows, by = "hour", all.x = TRUE)
  lines(grid$hour, grid$log_vedba, col = adjustcolor("#282421", alpha.f = 0.55), lwd = 0.55)
  ticks <- seq(0, 24, by = 3)
  axis(1, at = ticks, labels = sprintf("%02d:00", (ticks + 12L) %% 24L))
  if (tag == tags[1L]) {
    legend(par("usr")[2L], par("usr")[4L] + strheight("A") * 1.4,
           legend = c("Selected interval", "Later intervals"), fill = c("#F0DBD0", "#D8E7EE"),
           xjust = 1, yjust = 0.5, xpd = NA, horiz = TRUE, border = NA, bty = "n", cex = 0.86)
  }
}
mtext(paste("Laikipia acceleration traces", format(day, "%d %B %Y"), sep = " · "),
      side = 3, outer = TRUE, line = 0.20)
mtext("East Africa Time", side = 1, outer = TRUE, line = 0.28, cex = 0.95)
invisible(dev.off())
