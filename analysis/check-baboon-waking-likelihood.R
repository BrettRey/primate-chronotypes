source("analysis/fit-baboon-sleep.R")

fit_waking <- function(formula, data, degrees_freedom, fixed_animal_sd = NULL) {
  student <- is.finite(degrees_freedom)
  family <- if (student) glmmTMB::t_family() else gaussian()
  map <- if (student) list(psi = factor(NA)) else NULL
  groups <- vapply(reformulas::findbars(formula), function(bar) as.character(bar[[3L]]), character(1L))
  n_groups <- length(groups)
  animal_index <- match("animal", groups)
  if (!is.null(fixed_animal_sd)) {
    mapping <- seq_len(n_groups)
    mapping[animal_index] <- NA_integer_
    map$theta <- factor(mapping)
  }
  control <- glmmTMB::glmmTMBControl(
    optimizer = optim, optArgs = list(method = "BFGS"), optCtrl = list(maxit = 3000, reltol = 1e-10),
    conv_check = "skip"
  )

  candidates <- lapply(c(0.3, 2, 7, 15), function(sd) {
    start <- list(theta = rep(log(sd), n_groups))
    if (student) start$psi <- log(degrees_freedom)
    if (!is.null(fixed_animal_sd)) start$theta[animal_index] <- log(fixed_animal_sd)
    notes <- character()
    fit <- tryCatch(withCallingHandlers(
      glmmTMB::glmmTMB(formula, data = data, family = family, REML = FALSE,
                       start = start, map = map, control = control),
      warning = function(warning) {
        notes <<- c(notes, conditionMessage(warning))
        invokeRestart("muffleWarning")
      }
    ), error = function(error) NULL)
    if (is.null(fit)) return(NULL)
    fit$fit_notes <- paste(unique(notes), collapse = " | ")
    fit
  })
  candidates <- Filter(Negate(is.null), candidates)
  usable <- vapply(candidates, function(fit) {
    gradient <- fit$obj$gr(fit$fit$par)
    isTRUE(fit$fit$convergence == 0L) && is.finite(fit$fit$objective) &&
      all(is.finite(gradient)) && max(abs(gradient)) < 0.01
  }, logical(1L))
  if (!any(usable)) stop("Could not optimize waking model: ", deparse(formula))
  good <- candidates[usable]
  good[[which.min(vapply(good, function(fit) fit$fit$objective, numeric(1L)))]]
}

group_sd <- function(model, group) {
  effect <- glmmTMB::VarCorr(model)$cond[[group]]
  if (is.null(effect)) return(NA_real_)
  attr(effect, "stddev")[[1L]]
}

simulate_waking_errors <- function(model, degrees_freedom, test) {
  date_index <- as.integer(factor(test$day))
  n_dates <- max(date_index)
  n_records <- nrow(test)
  night_sd <- group_sd(model, "date")
  residual_scale <- sigma(model)
  set.seed(73695)
  replicate(2000L, {
    shared <- rnorm(n_dates, sd = night_sd)[date_index]
    individual <- if (is.finite(degrees_freedom)) rt(n_records, degrees_freedom) else rnorm(n_records)
    max(abs(shared + residual_scale * individual))
  })
}

waking_likelihood_result <- function(spec, degrees_freedom, data, train, test) {
  formula <- with(spec, baboon_formula(endpoint, trend, temporary))
  baseline <- with(spec, baboon_formula(endpoint, trend, temporary, persistent = FALSE))
  full <- fit_waking(formula, data, degrees_freedom)
  earlier <- fit_waking(formula, train, degrees_freedom)
  comparison <- fit_waking(baseline, train, degrees_freedom)

  forecast_error <- function(fit) {
    test$waking - predict(fit, test, allow.new.levels = TRUE)
  }
  errors <- data.frame(day = test$day, animal = test$animal,
                       baseline_error = forecast_error(comparison), animal_error = forecast_error(earlier))
  simulations <- simulate_waking_errors(earlier, degrees_freedom, test)
  data.frame(
    spec, likelihood = if (is.finite(degrees_freedom)) "student_t" else "gaussian",
    n_fit_pairs = nrow(data), animal_sd = group_sd(full, "animal"),
    date_sd = group_sd(full, "date"), animal_fortnight_sd = group_sd(full, "animal_fortnight"),
    residual_scale = sigma(full), degrees_freedom,
    n_train_pairs = nrow(train), first_test_night = min(test$day),
    baboon_forecast_scores(errors),
    baboon_simulated_maximum_summary(errors$animal_error, simulations),
    full_objective = full$fit$objective, forecast_objective = earlier$fit$objective,
    baseline_objective = comparison$fit$objective,
    full_positive_hessian = isTRUE(full$sdr$pdHess),
    forecast_positive_hessian = isTRUE(earlier$sdr$pdHess),
    baseline_positive_hessian = isTRUE(comparison$sdr$pdHess),
    full_fit_note = full$fit_notes, forecast_fit_note = earlier$fit_notes,
    baseline_fit_note = comparison$fit_notes
  )
}

waking_likelihood_profile <- function(data, simplest) {
  full <- baboon_formula("waking", FALSE, FALSE)
  baseline <- baboon_formula("waking", FALSE, FALSE, persistent = FALSE)
  do.call(rbind, lapply(seq_len(nrow(simplest)), function(i) {
    df <- simplest$degrees_freedom[i]
    no_animal <- fit_waking(baseline, data, df)
    spreads <- c(2, 4, 6, 8)
    values <- vapply(spreads, function(sd) {
      fit_waking(full, data, df, fixed_animal_sd = sd)$fit$objective
    }, numeric(1L))
    data.frame(likelihood = simplest$likelihood[i], degrees_freedom = df,
               animal_sd = c(0, spreads), objective = c(no_animal$fit$objective, values),
               optimized_objective = simplest$full_objective[i])
  }))
}

run_waking_likelihood_check <- function(input = "analysis/results/baboon-sleep-pairs.csv",
                                        output_dir = "analysis/results") {
  data <- read_baboon_nights(input)
  # Measure waking from 06:00 local time to keep the intercept on the scale of the other effects.
  data$waking <- data$waking - 18 * 60
  first_test <- baboon_late_start(sort(unique(data$day)))
  train <- data[data$day < first_test, ]
  test <- data[data$day >= first_test & data$animal %in% train$animal, ]
  specs <- subset(baboon_specs, endpoint == "waking")
  stopifnot(nrow(data) == 354L, nrow(train) == 269L, nrow(test) == 85L)

  rows <- lapply(seq_len(nrow(specs)), function(i) {
    spec <- specs[i, ]
    do.call(rbind, lapply(c(Inf, 3, 7), function(degrees_freedom) {
      waking_likelihood_result(spec, degrees_freedom, data, train, test)
    }))
  })
  summary <- do.call(rbind, rows)
  profile <- waking_likelihood_profile(data, subset(summary, !trend & !temporary))
  profile$objective_increase <- profile$objective - profile$optimized_objective
  write.csv(summary, file.path(output_dir, "baboon-waking-likelihood.csv"), row.names = FALSE)
  write.csv(profile, file.path(output_dir, "baboon-waking-likelihood-profile.csv"), row.names = FALSE)
}

if (sys.nframe() == 0L) run_waking_likelihood_check()
