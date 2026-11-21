source("analysis/simulate-titi-onset.R")

read_baboon_nights <- function(path) {
  pairs <- read.csv(path, colClasses = c(tag = "character"))
  day <- as.Date(pairs$night_date)
  local_zone <- "Africa/Nairobi"
  noon <- as.POSIXct(paste(day, "12:00:00"), tz = local_zone)
  minutes_since_noon <- function(timestamp) {
    as.numeric(difftime(as.POSIXct(timestamp, tz = local_zone), noon, units = "mins"))
  }
  elapsed_days <- as.integer(day - min(day))
  schedule <- data.frame(
    day, animal = factor(pairs$tag), date = factor(day),
    animal_fortnight = interaction(pairs$tag, elapsed_days %/% 14L, drop = TRUE),
    elapsed_weeks = elapsed_days / 7,
    onset = minutes_since_noon(pairs$onset_local),
    waking = minutes_since_noon(pairs$waking_local)
  )
  stopifnot(!anyNA(schedule), !anyDuplicated(schedule[c("animal", "day")]),
            all(schedule$onset >= 0), all(schedule$waking < 1440),
            all(schedule$onset < schedule$waking))
  schedule[order(schedule$day, schedule$animal), ]
}

baboon_formula <- function(endpoint, trend, temporary, persistent = TRUE) {
  terms <- c("1", "(1 | date)")
  if (trend) terms <- c(terms, "elapsed_weeks")
  if (temporary) terms <- c(terms, "(1 | animal_fortnight)")
  if (persistent) terms <- c(terms, "(1 | animal)")
  reformulate(terms, response = endpoint)
}

baboon_estimates <- function(formula, data) {
  fit <- fit_model(formula, data)
  scales <- as.data.frame(VarCorr(fit))
  animal <- "sd_(Intercept)|animal"
  notes <- character()
  interval <- withCallingHandlers(
    confint(fit, parm = animal, method = "profile", signames = FALSE, quiet = TRUE),
    warning = function(warning) {
      notes <<- c(notes, conditionMessage(warning))
      invokeRestart("muffleWarning")
    }
  )
  effect_sd <- setNames(scales$sdcor, scales$grp)
  data.frame(
    n_pairs = nrow(data), n_animals = length(unique(data$animal)),
    n_dates = length(unique(data$date)),
    animal_sd = effect_sd[["animal"]], animal_lower_95 = interval[animal, 1L],
    animal_upper_95 = interval[animal, 2L], night_sd = effect_sd[["date"]],
    animal_fortnight_sd = if ("animal_fortnight" %in% names(effect_sd)) {
      effect_sd[["animal_fortnight"]]
    } else {
      NA_real_
    },
    residual_sd = sigma(fit), profile_note = paste(notes, collapse = " | ")
  )
}

baboon_forecasts <- function(formula, baseline, endpoint, train, test) {
  error <- function(formula) {
    fit <- fit_model(formula, train)
    test[[endpoint]] - predict(fit, test, allow.new.levels = TRUE)
  }
  baseline_error <- error(baseline)
  animal_error <- error(formula)
  absolute <- rmse_stats(data.frame(baseline = baseline_error^2, with_animal = animal_error^2))
  center_by_night <- function(x) x - ave(x, test$date)
  has_peers <- ave(rep(1L, nrow(test)), test$date, FUN = length) > 1L
  relative <- rmse_stats(data.frame(
    baseline = center_by_night(baseline_error)[has_peers]^2,
    with_animal = center_by_night(animal_error)[has_peers]^2
  ))
  names(relative) <- paste0("within_night_", names(relative))
  data.frame(
    n_train_pairs = nrow(train), first_test_night = min(test$day),
    n_test_pairs = nrow(test), n_test_animals = length(unique(test$animal)),
    n_test_dates = length(unique(test$date)), n_within_night_pairs = sum(has_peers),
    absolute, baseline_mae = mean(abs(baseline_error)), animal_mae = mean(abs(animal_error)),
    relative
  )
}

run_baboon_analysis <- function(input = "analysis/results/baboon-sleep-pairs.csv",
                                output_dir = "analysis/results") {
  schedule <- read_baboon_nights(input)
  # The archived analysis numbers 2012-07-31 as night 1.
  samples <- list(full = schedule, first_twenty = schedule[schedule$day < as.Date("2012-08-20"), ])
  dates <- sort(unique(schedule$day))
  first_test <- dates[(length(dates) * 2L) %/% 3L + 1L]
  train <- schedule[schedule$day < first_test, ]
  test <- schedule[schedule$day >= first_test & schedule$animal %in% train$animal, ]
  specs <- expand.grid(
    endpoint = c("onset", "waking"), trend = c(FALSE, TRUE), temporary = c(FALSE, TRUE),
    stringsAsFactors = FALSE
  )

  results <- lapply(seq_len(nrow(specs)), function(i) {
    spec <- specs[i, ]
    formula <- with(spec, baboon_formula(endpoint, trend, temporary))
    baseline <- with(spec, baboon_formula(endpoint, trend, temporary, persistent = FALSE))
    estimates <- lapply(names(samples), function(name) {
      data.frame(spec, sample = name, baboon_estimates(formula, samples[[name]]))
    })
    list(estimates = do.call(rbind, estimates),
         forecasts = data.frame(spec,
                                baboon_forecasts(formula, baseline, spec$endpoint, train, test)))
  })

  for (kind in c("estimates", "forecasts")) {
    table <- do.call(rbind, lapply(results, `[[`, kind))
    write.csv(table, file.path(output_dir, paste0("baboon-sleep-", kind, ".csv")), row.names = FALSE)
  }
}

if (sys.nframe() == 0L) run_baboon_analysis()
