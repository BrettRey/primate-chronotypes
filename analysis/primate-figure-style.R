render_primate_figure <- function(stem, draw, width, height) {
  family <- "EB Garamond"
  for (format in c("png", "pdf")) {
    path <- paste(stem, format, sep = ".")
    if (format == "png") {
      png(path, width = width, height = height, units = "in", res = 300,
          type = "cairo", pointsize = 10, bg = "white")
    } else {
      cairo_pdf(path, width = width, height = height, family = family, pointsize = 10)
    }
    tryCatch(draw(family), finally = dev.off())
  }
}

primate_figure_text <- function(family) {
  par(family = family, cex = 1, cex.axis = 0.9, cex.main = 1.1, font.main = 1,
      mgp = c(2.2, 0.52, 0), tcl = -0.25)
}

primate_median_ticks <- function(x, y, col) {
  half_height <- grconvertY(0.036, from = "inches") - grconvertY(0, from = "inches")
  segments(x, y - half_height, x, y + half_height, col = col, lwd = 1.8, lend = "butt")
}
