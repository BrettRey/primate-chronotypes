source("analysis/primate-figure-style.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Usage: Rscript plot-figure1.R PAIRS_CSV OUTPUT_PDF_OR_PNG")
pairs <- read.csv(args[1L])
earlier <- pairs$minutes_earlier[!is.na(pairs$minutes_earlier)]
stopifnot(nrow(pairs) == 288L, length(earlier) == 287L,
          sum(earlier == 0) == 30L, median(earlier) == 253, max(earlier) == 640)
width <- 174 / 25.4
height <- width * 3.5 / 6.4
if (grepl("[.]pdf$", args[2L])) {
  cairo_pdf(args[2L], width = width, height = height,
            family = "EB Garamond", pointsize = 11.5, bg = "white")
} else {
  png(args[2L], width = width, height = height, units = "in", res = 600,
      type = "cairo", pointsize = 11.5, bg = "white")
}
primate_figure_text("EB Garamond")
par(mar = c(3.4, 3.5, 1.55, 0.55))
plot(ecdf(earlier), verticals = TRUE, do.points = FALSE, col = "#963E27",
     col.01line = NA, lwd = 1.05, xlim = c(-12, max(earlier) + 15),
     ylim = c(0, 1), yaxt = "n",
     xlab = "Minutes from longest-period end to last observed awakening",
     ylab = "Share of paired animal-nights", bty = "l", main = "")
axis(2, at = seq(0, 1, 0.25), labels = sprintf("%d%%", seq(0, 100, 25)), las = 1)
points(0, mean(earlier == 0), pch = 21, bg = "white", col = "#282421", cex = 0.85)
invisible(dev.off())
