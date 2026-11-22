source("analysis/fit-comparative-waking-bayes.R")
source("analysis/primate-figure-style.R")

plot_endpoint_differences <- function(pairs, output) {
  earlier <- pairs$minutes_earlier[!is.na(pairs$minutes_earlier)]
  draw <- function(family) {
    primate_figure_text(family)
    par(mar = c(3.4, 3.5, 1.55, 0.55))
    plot(ecdf(earlier), verticals = TRUE, do.points = FALSE, col = "#963E27", col.01line = NA,
         lwd = 1.05, xlim = c(-12, max(earlier) + 15), ylim = c(0, 1), yaxt = "n",
         xlab = "Minutes from longest-period end to last observed awakening",
         ylab = "Share of paired animal-nights", bty = "l", main = "")
    axis(2, at = seq(0, 1, 0.25), labels = sprintf("%d%%", seq(0, 100, 25)), las = 1)
    points(0, mean(earlier == 0), pch = 21, bg = "white", col = "#282421", cex = 0.85)
    mtext(sprintf("%d with both endpoints · %d agree · %d without a qualifying bout",
                  length(earlier), sum(earlier == 0), sum(is.na(pairs$minutes_earlier))),
          side = 3, adj = 0, line = 0.35)
  }
  render_primate_figure(file.path(output, "huangshan-endpoint-differences"), draw, 6.4, 3.5)
}

summarize_endpoint_steps <- function(pairs) {
  pairs <- pairs[!is.na(pairs$minutes_earlier), ]
  minutes_between <- function(start, end) {
    zone <- "Asia/Shanghai"
    as.numeric(difftime(as.POSIXct(end, tz = zone), as.POSIXct(start, tz = zone), units = "mins"))
  }
  processing <- minutes_between(pairs$last_qualifying_period_end_local, pairs$waking_local)
  selection <- minutes_between(pairs$longest_period_end_local, pairs$last_qualifying_period_end_local)
  stopifnot(all(processing >= 0), all(selection >= 0),
            all(processing + selection == pairs$minutes_earlier))
  steps <- list(bout_processing = processing, longest_selection = selection,
                combined = pairs$minutes_earlier)
  do.call(rbind, lapply(names(steps), function(step) {
    delta <- steps[[step]]
    q <- quantile(delta, c(0.25, 0.5, 0.75), names = FALSE)
    data.frame(step, paired_nights = length(delta), nights_earlier = sum(delta > 0),
               lower_quartile = q[1L], median = q[2L], upper_quartile = q[3L], maximum = max(delta))
  }))
}

main <- function(args) {
  if (length(args) != 5L) {
    stop("Usage: Rscript analysis/compare-huangshan-endpoints.R STAN_BINARY SCRATCH ",
         "PAIRED_ENDPOINTS OUTPUT_DIR CORES")
  }
  binary <- args[1L]
  scratch <- args[2L]
  output <- args[4L]
  cores <- as.integer(args[5L])
  stopifnot(dir.exists(scratch), dir.exists(output), cores >= 1L)
  pairs <- read.csv(args[3L], colClasses = c(tag = "character"))
  scored <- read_baboon_nights(args[3L], local_zone = "Asia/Shanghai")
  pair_keys <- with(pairs, paste(night_date, tag))
  pair_rows <- match(paste(scored$day, scored$animal), pair_keys)
  stopifnot(nrow(scored) == 288L, !anyDuplicated(pair_keys), !anyNA(pair_rows),
            all(pairs$minutes_earlier >= 0, na.rm = TRUE))
  scored$minutes_earlier <- pairs$minutes_earlier[pair_rows]

  plot_endpoint_differences(pairs, output)

  window <- forecast_split(scored)
  train <- window$train[!is.na(window$train$minutes_earlier), ]
  test <- window$test[!is.na(window$test$minutes_earlier) & window$test$animal %in% train$animal, ]
  stopifnot(identical(test[c("day", "animal")], window$test[c("day", "animal")]))
  complete <- scored[!is.na(scored$minutes_earlier), ]
  plans <- expand.grid(rule = c("scored_awakening", "longest_period_end"), temporary = c(FALSE, TRUE),
                       stringsAsFactors = FALSE)
  jobs <- unlist(lapply(seq_len(nrow(plans)), function(i) {
    plan <- plans[i, ]
    response <- function(rows) {
      if (plan$rule == "longest_period_end") rows$waking <- rows$waking - rows$minutes_earlier
      rows
    }
    id <- paste("huangshan-endpoints", plan$rule, if (plan$temporary) "fortnight" else "stable", sep = "-")
    seed <- if (plan$temporary) 840180L else 840130L
    list(make_job(paste0(id, "-full"), response(complete), NULL, FALSE, plan$temporary, TRUE, seed + 1L),
         make_job(paste0(id, "-animal"), response(train), response(test), FALSE, plan$temporary, TRUE, seed + 2L),
         make_job(paste0(id, "-baseline"), response(train), response(test), FALSE, plan$temporary, FALSE, seed + 3L))
  }), recursive = FALSE)
  fits <- run_jobs(jobs, binary, scratch, cores)
  estimates <- list()
  scores <- list()
  for (i in seq_len(nrow(plans))) {
    indices <- (3L * (i - 1L) + 1L):(3L * i)
    plan <- plans[i, ]
    estimates[[i]] <- data.frame(plan, fits[[indices[1L]]]$estimates, row.names = NULL)
    job <- jobs[[indices[2L]]]
    historical <- historical_errors(job$train, job$test, adjust_troop = FALSE)
    scores[[i]] <- do.call(rbind, lapply(prior_scales, function(scale) {
      key <- as.character(scale)
      animal <- fits[[indices[2L]]]$forecasts[[key]]
      baseline <- fits[[indices[3L]]]$forecasts[[key]]
      errors <- data.frame(day = job$test$day, animal = job$test$animal,
                           baseline_error = job$test$waking - baseline,
                           animal_error = job$test$waking - animal)
      data.frame(plan, prior_scale = scale, first_test_night = min(job$test$day),
                 baboon_forecast_scores(errors),
                 historical_mean_rmse = sqrt(mean(historical$mean^2)),
                 historical_median_mae = mean(abs(historical$median)))
    }))
  }
  outputs <- list(estimates = do.call(rbind, estimates), forecasts = do.call(rbind, scores),
                  diagnostics = fit_diagnostics(jobs, fits), steps = summarize_endpoint_steps(pairs))
  for (name in names(outputs)) {
    write.csv(outputs[[name]], file.path(output, paste0("huangshan-endpoint-", name, ".csv")), row.names = FALSE)
  }
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
