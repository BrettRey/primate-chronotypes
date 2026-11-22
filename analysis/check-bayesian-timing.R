source("analysis/check-baboon-rolling-forecasts.R")
source("analysis/titi-multiverse.R")

prior_scales <- c(30, 15)

prepare_fit <- function(train, test, endpoint, trend, persistent, temporary, separate,
                        adjust_troop = FALSE) {
  # Equivalent fixed-effect columns to the original fits, with a mean for each cohort.
  titi <- "cohort" %in% names(train)
  fixed <- if (titi) {
    if (trend) ~ 0 + cohort + cohort:elapsed_weeks else ~ 0 + cohort
  } else if (adjust_troop) {
    if (trend) ~ 0 + troop + elapsed_weeks else ~ 0 + troop
  } else {
    if (trend) ~ elapsed_weeks else ~ 1
  }
  center <- if (titi) 0 else if (endpoint == "onset") 480 else 1080
  x <- model.matrix(fixed, train)
  dates <- unique(as.character(train$date))
  animals <- if (persistent) unique(as.character(train$animal)) else character()
  blocks <- if (temporary) unique(as.character(train$animal_fortnight)) else character()
  spreads <- if (!persistent) character() else if (separate) levels(train$cohort) else "common"
  coefficient_animal_var <- numeric(ncol(x))
  if (adjust_troop && persistent) {
    membership <- unique(train[c("animal", "troop")])
    stopifnot(!anyDuplicated(membership$animal), all(test$animal %in% animals))
    troops <- split(as.character(membership$animal), membership$troop, drop = TRUE)
    troop_cols <- match(paste0("troop", names(troops)), colnames(x))
    stopifnot(!anyNA(troop_cols), all(lengths(troops) <= 2L))
    # The troop mean absorbs the average animal effect, independently of the contrast.
    coefficient_animal_var[troop_cols] <- 1 / lengths(troops)
    pairs <- troops[lengths(troops) == 2L]
    first_animals <- vapply(pairs, `[`, character(1), 1L)
    animals <- names(pairs)
  }
  animal_spread <- if (separate && persistent) {
    match(train$cohort[match(animals, train$animal)], spreads)
  } else {
    rep(1L, length(animals))
  }
  indices <- function(data) {
    if (adjust_troop && persistent) {
      animal <- match(data$troop, animals, nomatch = 0L)
      weight <- ifelse(data$animal %in% first_animals, 1, -1) / sqrt(2)
    } else {
      animal <- match(data$animal, animals, nomatch = 0L)
      weight <- rep(1, nrow(data))
    }
    list(date = match(data$date, dates, nomatch = 0L),
         animal = animal, animal_weight = weight,
         block = match(data$animal_fortnight, blocks, nomatch = 0L))
  }
  ids <- indices(train)
  list(data = list(n = nrow(train), k = ncol(x), n_dates = length(dates),
                   n_animals = length(animals), n_spreads = length(spreads),
                   n_blocks = length(blocks), date_id = I(ids$date), animal_id = I(ids$animal + 1L),
                   animal_spread_id = I(animal_spread), block_id = I(ids$block),
                   y = I(train[[endpoint]] - center), x = x,
                   animal_weight = I(ids$animal_weight),
                   coefficient_animal_var = I(coefficient_animal_var),
                   coefficient_prior_sd = I(ifelse(grepl("elapsed_weeks", colnames(x)), 10, 120))),
       spreads = spreads, x_test = if (is.null(test)) NULL else model.matrix(fixed, test),
       test_ids = if (is.null(test)) NULL else indices(test), center = center)
}

columns <- function(name, n) {
  if (n) paste0(name, ".", seq_len(n)) else character()
}

weighted_quantiles <- function(x, weights) {
  order <- order(x)
  approx(cumsum(weights[order]), x[order], xout = c(0.025, 0.5, 0.975), rule = 2)$y
}

summarize_fit <- function(chains, fit_data) {
  draws <- as.matrix(do.call(rbind, chains))
  data <- fit_data$data
  scale_cols <- columns("persistent_sd", data$n_spreads)
  coef_cols <- columns("beta", data$k)
  diagnostics_cols <- c("date_sd", "residual_sd", coef_cols, scale_cols,
                        columns("temporary_sd", as.integer(data$n_blocks > 0)))
  diagnostic <- function(name, measure) {
    values <- do.call(cbind, lapply(chains, `[[`, name))
    measure(values)
  }
  diagnostics <- data.frame(
    divergences = sum(draws[, "divergent__"]),
    max_treedepth = max(draws[, "treedepth__"]),
    max_rhat = max(vapply(diagnostics_cols, diagnostic, numeric(1), measure = posterior::rhat)),
    min_bulk_ess = min(vapply(diagnostics_cols, diagnostic, numeric(1), measure = posterior::ess_bulk)),
    min_tail_ess = min(vapply(diagnostics_cols, diagnostic, numeric(1), measure = posterior::ess_tail))
  )
  forecasts <- list()
  estimates <- list()
  for (scale in prior_scales) {
    # The ratios of the half-normal densities equal those of the normal densities
    # at positive SDs. Sampling under the broader prior bounds these ratios.
    scales <- draws[, scale_cols, drop = FALSE]
    weights <- exp(rowSums(dnorm(scales, 0, scale, log = TRUE) -
                             dnorm(scales, 0, prior_scales[1L], log = TRUE)))
    weights <- weights / sum(weights)
    name <- as.character(scale)
    diagnostics[[paste0("weight_ess_", name)]] <- 1 / sum(weights^2)
    if (length(scale_cols)) {
      estimates[[name]] <- do.call(rbind, lapply(seq_along(scale_cols), function(j) {
        q <- weighted_quantiles(scales[, j], weights)
        data.frame(prior_scale = scale, cohort = fit_data$spreads[j],
                   persistent_lower = q[1L], persistent_median = q[2L], persistent_upper = q[3L])
      }))
    }
    if (!is.null(fit_data$x_test)) {
      beta <- drop(crossprod(weights, draws[, coef_cols, drop = FALSE]))
      predict_effect <- function(raw, sd, ids) {
        # A group with no training data contributes its prior mean of zero.
        effects <- drop(crossprod(weights, raw * sd))
        c(0, effects)[ids + 1L]
      }
      ids <- fit_data$test_ids
      prediction <- fit_data$center + drop(fit_data$x_test %*% beta) +
        predict_effect(draws[, columns("date_raw", data$n_dates), drop = FALSE],
                       draws[, "date_sd"], ids$date)
      if (data$n_animals) {
        prediction <- prediction + ids$animal_weight *
          predict_effect(draws[, columns("animal_raw", data$n_animals), drop = FALSE],
                         scales[, data$animal_spread_id, drop = FALSE], ids$animal)
      }
      if (data$n_blocks) {
        prediction <- prediction +
          predict_effect(draws[, columns("block_raw", data$n_blocks), drop = FALSE],
                         draws[, "temporary_sd.1"], ids$block)
      }
      forecasts[[name]] <- prediction
    }
  }
  list(diagnostics = diagnostics, estimates = do.call(rbind, estimates), forecasts = forecasts)
}

run_chain <- function(binary, data_file, output_file, seed, chain, draws, warmup, delta) {
  log_file <- paste0(output_file, ".log")
  args <- c("sample", paste0("num_samples=", draws), paste0("num_warmup=", warmup),
            "adapt", paste0("delta=", delta), "algorithm=hmc", "engine=nuts", "max_depth=12",
            "data", shQuote(paste0("file=", data_file)), "random", paste0("seed=", seed),
            paste0("id=", chain), "output", shQuote(paste0("file=", output_file)),
            "refresh=0", "sig_figs=12")
  status <- system2(binary, args, stdout = log_file, stderr = log_file)
  if (status != 0L) stop(paste(readLines(log_file), collapse = "\n"))
  read.csv(output_file, comment.char = "#", check.names = FALSE)
}

fit_timing <- function(job, binary, scratch) {
  directory <- file.path(scratch, job$id)
  dir.create(directory, showWarnings = FALSE)
  priors <- with(job, prepare_fit(train, test, endpoint, trend, persistent, temporary, separate,
                                 adjust_troop = isTRUE(job$adjust_troop)))
  input <- file.path(directory, "data.json")
  jsonlite::write_json(priors$data, input, auto_unbox = TRUE, digits = NA)
  cache <- file.path(directory, "summary.rds")
  result <- if (file.exists(cache)) readRDS(cache) else NULL
  attempt <- if (is.null(result)) 0L else if (is.null(result$diagnostics$attempt)) {
    1L
  } else {
    result$diagnostics$attempt
  }
  while (attempt == 0L ||
         (attempt < 3L && with(result$diagnostics, divergences > 0 || max_rhat > 1.01 ||
                              max_treedepth >= 12))) {
    attempt <- attempt + 1L
    delta <- c(0.95, 0.99, 0.995)[attempt]
    warmup <- c(if (job$sample == "rolling") 500L else 750L, 1500L, 2200L)[attempt]
    draws <- c(if (job$sample == "rolling") 600L else 1000L, 1500L, 2500L)[attempt]
    chains <- lapply(seq_len(4L), function(chain) {
      output <- file.path(directory, paste0("chain-", attempt, "-", chain, ".csv"))
      run_chain(binary, input, output, job$seed + 100000L * (attempt - 1L),
                chain, draws, warmup, delta)
    })
    result <- summarize_fit(chains, priors)
    result$diagnostics$attempt <- attempt
    summary <- file.path(directory, "next-summary.rds")
    saveRDS(result, summary)
    stopifnot(file.rename(summary, cache))
    message("Fitted ", job$id, " (attempt ", attempt, ")")
  }
  result$diagnostics$attempt <- attempt
  result
}

collect_jobs <- function() {
  titi <- read_multiverse_schedule(include_onsets = TRUE)
  fold <- forecast_split(titi)
  titi_train <- titi[fold$train, ]
  titi_test <- titi[fold$test, ]
  baboons <- read_baboon_nights("analysis/results/baboon-sleep-pairs.csv")
  late_start <- baboon_late_start(sort(unique(baboons$day)))
  earlier <- baboons[baboons$day < late_start, ]
  later <- baboons[baboons$day >= late_start & baboons$animal %in% earlier$animal, ]
  rolling <- baboon_rolling_origins(baboons)
  jobs <- list()
  pairs <- list()
  add_fit <- function(dataset, spec, sample, train, test, endpoint, trend,
                      persistent, temporary, separate) {
    id <- paste(dataset, spec, sample, if (persistent) "animal" else "baseline",
                if (sample == "rolling") min(test$day) else "", sep = "-")
    jobs[[id]] <<- list(id = id, dataset = dataset, spec = spec, sample = sample,
                        train = train, test = test, endpoint = endpoint, trend = trend,
                        persistent = persistent, temporary = temporary, separate = separate)
    id
  }
  add_pair <- function(group, animal, baseline, train, test, endpoint, spec, sample) {
    pairs[[length(pairs) + 1L]] <<- list(dataset = group, animal = animal, baseline = baseline,
                                       train = train, test = test, endpoint = endpoint,
                                       spec = spec, sample = sample)
  }
  for (i in seq_len(nrow(specifications))) {
    spec <- specifications[i, ]
    trend <- spec$calendar == "date_and_trend"
    temporary <- spec$temporary == "fortnight"
    separate <- spec$spread == "separate"
    add_fit("titi", spec$spec, "full", titi, NULL, "onset", trend, TRUE, temporary, separate)
    id <- add_fit("titi", spec$spec, "fixed", titi_train, titi_test,
                  "onset", trend, TRUE, temporary, separate)
    base <- add_fit("titi", spec$calendar, "fixed", titi_train, titi_test,
                    "onset", trend, FALSE, FALSE, FALSE)
    add_pair("titi", id, base, titi_train, titi_test, "onset", spec$spec, "fixed")
  }
  for (i in seq_len(nrow(baboon_specs))) {
    spec <- baboon_specs[i, ]
    label <- paste0("B", i)
    for (sample in c("full", "first_twenty")) {
      train <- if (sample == "full") baboons else baboons[baboons$day < as.Date("2012-08-20"), ]
      add_fit("baboon", label, sample, train, NULL, spec$endpoint, spec$trend, TRUE,
              spec$temporary, FALSE)
    }
    windows <- c(list(list(train = earlier, test = later)), rolling)
    for (j in seq_along(windows)) {
      sample <- if (j == 1L) "fixed" else "rolling"
      train <- windows[[j]]$train
      test <- windows[[j]]$test
      id <- add_fit("baboon", label, sample, train, test, spec$endpoint, spec$trend, TRUE,
                    spec$temporary, FALSE)
      base <- add_fit("baboon", label, sample, train, test, spec$endpoint, spec$trend, FALSE,
                      spec$temporary, FALSE)
      add_pair("baboon", id, base, train, test, spec$endpoint, label, sample)
    }
  }
  for (i in seq_along(jobs)) jobs[[i]]$seed <- 751923L + i
  list(jobs = jobs, pairs = pairs, late_start = late_start)
}

record_errors <- function(pair, fits, scale) {
  name <- as.character(scale)
  train <- pair$train
  test <- pair$test
  y <- test[[pair$endpoint]]
  by <- if (pair$dataset == "titi") as.character(train$cohort) else rep("all", nrow(train))
  groups <- if (pair$dataset == "titi") as.character(test$cohort) else rep("all", nrow(test))
  data.frame(dataset = pair$dataset, spec = pair$spec, endpoint = pair$endpoint,
             sample = pair$sample, prior_scale = scale, day = test$day, cohort = groups,
             animal = test$animal, baseline_error = y - fits[[pair$baseline]]$forecasts[[name]],
             animal_error = y - fits[[pair$animal]]$forecasts[[name]],
             historical_mean_error = y - tapply(train[[pair$endpoint]], by, mean)[groups],
             historical_median_error = y - tapply(train[[pair$endpoint]], by, median)[groups])
}

forecast_summaries <- function(errors, late_start) {
  by <- split(errors, errors[c("dataset", "spec", "sample", "prior_scale")], drop = TRUE)
  do.call(rbind, lapply(by, function(rows) {
    subsets <- list(pooled = rows)
    if (rows$dataset[1L] == "titi") subsets <- c(subsets, split(rows, rows$cohort))
    if (rows$sample[1L] == "rolling") {
      subsets$earlier_dates <- rows[rows$day < late_start, ]
      subsets$original_late_dates <- rows[rows$day >= late_start, ]
    }
    do.call(rbind, lapply(names(subsets), function(name) {
      records <- subsets[[name]]
      scores <- if (rows$dataset[1L] == "baboon") {
        cbind(baboon_forecast_scores(records), baboon_paired_mse_scores(records))
      } else {
        stats <- rmse_stats(data.frame(baseline = records$baseline_error^2,
                                       with_animal = records$animal_error^2))
        data.frame(n_test_pairs = nrow(records), stats,
                   baseline_mae = mean(abs(records$baseline_error)),
                   animal_mae = mean(abs(records$animal_error)))
      }
      data.frame(rows[1L, c("dataset", "spec", "endpoint", "sample", "prior_scale")],
                 subset = name, scores,
                 historical_mean_rmse = sqrt(mean(records$historical_mean_error^2)),
                 historical_median_mae = mean(abs(records$historical_median_error)))
    }))
  }))
}

main <- function(args) {
  if (length(args) != 5L) {
    stop("Usage: Rscript analysis/check-bayesian-timing.R STAN_BINARY SCRATCH OUTPUT_DIR CORES core|rolling|all")
  }
  plan <- collect_jobs()
  selected <- names(Filter(function(job) {
    args[5L] == "all" || (args[5L] == "rolling") == (job$sample == "rolling")
  }, plan$jobs))
  stopifnot(args[5L] %in% c("core", "rolling", "all"), length(selected) > 0L,
            dir.exists(args[2L]), dir.exists(args[3L]))
  fits <- parallel::mclapply(plan$jobs[selected], function(job) {
    fit_timing(job, args[1L], args[2L])
  }, mc.cores = as.integer(args[4L]), mc.preschedule = FALSE)
  stopifnot(all(vapply(fits, is.list, logical(1))))
  estimates <- list()
  diagnostics <- lapply(selected, function(id) {
    job <- plan$jobs[[id]]
    fit <- fits[[id]]
    keys <- data.frame(id = id, dataset = job$dataset, spec = job$spec, endpoint = job$endpoint,
                       sample = job$sample, trend = job$trend, temporary = job$temporary,
                       persistent = job$persistent, n_train = nrow(job$train))
    if (is.null(job$test)) estimates[[id]] <<- cbind(keys, fit$estimates)
    cbind(keys, fit$diagnostics)
  })
  scores <- list()
  pairs <- Filter(function(pair) pair$animal %in% selected, plan$pairs)
  for (dataset in unique(vapply(pairs, `[[`, character(1), "dataset"))) {
    group <- Filter(function(pair) pair$dataset == dataset, pairs)
    errors <- do.call(rbind, lapply(group, function(pair) {
      do.call(rbind, lapply(prior_scales, function(scale) record_errors(pair, fits, scale)))
    }))
    scores[[dataset]] <- forecast_summaries(errors, plan$late_start)
  }
  outputs <- c(list(diagnostics = do.call(rbind, diagnostics)),
               if (length(estimates)) list(estimates = do.call(rbind, estimates)),
               setNames(scores, paste0(names(scores), "-forecasts")))
  for (name in names(outputs)) {
    path <- file.path(args[3L], paste0("bayesian-timing-", name, ".csv"))
    write.csv(outputs[[name]], path, row.names = FALSE)
  }
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
