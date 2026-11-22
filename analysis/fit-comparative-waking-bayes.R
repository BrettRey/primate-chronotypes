source("analysis/check-bayesian-timing.R")
source("analysis/compare-primate-waking.R")

make_job <- function(id, train, test, adjust_troop, temporary, persistent, seed) {
  if (adjust_troop && persistent) id <- paste0(id, "-contrasts")
  list(id = id, train = train, test = test, endpoint = "waking", sample = "fixed",
       trend = FALSE, persistent = persistent, temporary = temporary, separate = FALSE,
       adjust_troop = adjust_troop, seed = seed)
}

run_jobs <- function(jobs, binary, scratch, cores) {
  fits <- parallel::mclapply(jobs, function(job) fit_timing(job, binary, scratch),
                             mc.cores = cores, mc.preschedule = FALSE)
  stopifnot(all(vapply(fits, is.list, logical(1))))
  fits
}

fit_diagnostics <- function(jobs, fits) {
  do.call(rbind, Map(function(job, fit) {
    data.frame(id = job$id, n_train = nrow(job$train),
               n_test = if (is.null(job$test)) 0L else nrow(job$test), fit$diagnostics)
  }, jobs, fits))
}

simulate_interrupted_nights <- function(balanced) {
  set.seed(64221L)
  date_offsets <- setNames(rnorm(nlevels(droplevels(balanced$date)), 0, 15),
                           levels(droplevels(balanced$date)))
  control <- balanced
  control$waking <- 1080 + date_offsets[as.character(control$date)] + rnorm(nrow(control), 0, 20)

  # Reuse the five-hour shift in the existing deterministic classifier example.
  example <- read.csv("analysis/results/baboon-interruption-simulation.csv")
  shift <- with(example, classified_end_minutes_early[interruption_starts == "01:00" &
                                                        interruption_minutes == 45L])
  target <- which(as.character(balanced$animal) == "Pa AI WG")
  events <- target[round(seq(1, length(target), length.out = 14L))[-c(1L, 14L)]]
  stopifnot(length(shift) == 1L, length(events) == 12L, !anyDuplicated(events))
  noise <- control
  noise$waking[events] <- control$waking[events] - shift
  list(clean = control, interrupted = noise)
}

historical_errors <- function(train, test, adjust_troop) {
  if (!adjust_troop) {
    return(list(mean = test$waking - mean(train$waking),
                median = test$waking - median(train$waking)))
  }
  group <- as.character(test$troop)
  list(mean = test$waking - tapply(train$waking, train$troop, mean)[group],
       median = test$waking - tapply(train$waking, train$troop, median)[group])
}

main <- function(args) {
  if (length(args) != 7L) {
    stop("Usage: Rscript analysis/fit-comparative-waking-bayes.R STAN_BINARY SCRATCH ",
         "LAIKIPIA_PAIRS REFERENCE MACAQUE_PAIRS OUTPUT_DIR CORES")
  }
  binary <- args[1L]
  scratch <- args[2L]
  output <- args[6L]
  cores <- as.integer(args[7L])
  stopifnot(dir.exists(scratch), dir.exists(output), cores >= 1L)
  laikipia <- read_laikipia_nights(args[3L], args[4L])
  balanced <- complete_laikipia_nights(laikipia)
  macaques <- read_baboon_nights(args[5L], local_zone = "Asia/Shanghai")
  stopifnot(nrow(balanced) == 738L, nrow(laikipia) == 1618L, nrow(macaques) == 288L)

  fake <- simulate_interrupted_nights(balanced)
  simulations <- Map(function(name, rows, seed) {
    make_job(paste0("simulation-", name), rows, NULL, TRUE, FALSE, TRUE, seed)
  }, names(fake), fake, c(840001L, 840002L))
  simulated <- run_jobs(simulations, binary, scratch, cores)
  recovery <- do.call(rbind, Map(function(name, fit) {
    data.frame(scenario = name, known_persistent_sd = 0, fit$estimates)
  }, names(fake), simulated))

  samples <- list(laikipia_all_six = balanced, laikipia_full = laikipia, huangshan = macaques)
  plans <- expand.grid(sample = names(samples), adjust_troop = c(FALSE, TRUE),
                       temporary = c(FALSE, TRUE), stringsAsFactors = FALSE)
  plans <- plans[!(plans$sample == "huangshan" & plans$adjust_troop), ]
  jobs <- list()
  for (i in seq_len(nrow(plans))) {
    plan <- plans[i, ]
    nights <- samples[[plan$sample]]
    window <- forecast_split(nights)
    id <- paste(plan$sample, if (plan$adjust_troop) "troop" else "shared",
                if (plan$temporary) "fortnight" else "stable", sep = "-")
    create <- function(stage, train, test, persistent, offset) {
      make_job(paste(id, stage, sep = "-"), train, test, plan$adjust_troop,
               plan$temporary, persistent, 840100L + 10L * i + offset)
    }
    jobs <- c(jobs, list(create("full", nights, NULL, TRUE, 1L),
                         create("animal", window$train, window$test, TRUE, 2L),
                         create("baseline", window$train, window$test, FALSE, 3L)))
  }
  fits <- run_jobs(jobs, binary, scratch, cores)
  estimates <- list()
  scores <- list()
  contrasts <- subset(check_troopmates(balanced), endpoint == "waking",
                      select = c(troop, endpoint, first_animal, second_animal, n_train, n_test,
                                 train_mean_difference, test_mean_difference))
  forecasts <- list()
  for (i in seq_len(nrow(plans))) {
    indices <- (3L * (i - 1L) + 1L):(3L * i)
    plan <- plans[i, ]
    estimates[[i]] <- data.frame(plan, fits[[indices[1L]]]$estimates, row.names = NULL)
    job <- jobs[[indices[2L]]]
    test <- job$test
    historical <- historical_errors(job$train, test, plan$adjust_troop)
    scores[[i]] <- do.call(rbind, lapply(prior_scales, function(scale) {
      key <- as.character(scale)
      animal <- fits[[indices[2L]]]$forecasts[[key]]
      baseline <- fits[[indices[3L]]]$forecasts[[key]]
      errors <- data.frame(day = test$day, animal = test$animal,
                           baseline_error = test$waking - baseline,
                           animal_error = test$waking - animal)
      if (plan$sample == "laikipia_all_six" && plan$adjust_troop && !plan$temporary) {
        forecasts[[key]] <<- vapply(seq_len(nrow(contrasts)), function(j) {
          first <- animal[test$animal == contrasts$first_animal[j]]
          second <- animal[test$animal == contrasts$second_animal[j]]
          mean(first - second)
        }, numeric(1))
      }
      cbind(plan, prior_scale = scale, first_test_night = min(test$day),
            baboon_forecast_scores(errors),
            historical_mean_rmse = sqrt(mean(historical$mean^2)),
            historical_median_mae = mean(abs(historical$median)))
    }))
  }
  contrasts$bayesian_difference_15 <- forecasts[["15"]]
  contrasts$bayesian_difference_30 <- forecasts[["30"]]
  outputs <- list(estimates = do.call(rbind, estimates), forecasts = do.call(rbind, scores),
                  troopmates = contrasts, simulation = recovery,
                  diagnostics = rbind(fit_diagnostics(simulations, simulated), fit_diagnostics(jobs, fits)))
  for (name in names(outputs)) {
    write.csv(outputs[[name]], file.path(output, paste0("comparative-waking-bayes-", name, ".csv")),
              row.names = FALSE)
  }
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
