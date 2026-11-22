library(lme4)

# The Movebank archive describes the study location near these coordinates.
minutes_since_dawn <- function(night) {
  morning <- night + 1L
  tz <- "Africa/Nairobi"
  dawn <- suncalc::getSunlightTimes(
    data = data.frame(date = sort(unique(morning)), lat = 0.35595, lon = 36.92738),
    keep = "nightEnd", tz = tz
  )
  forecast_time <- as.POSIXct(paste(morning, "06:05:00"), tz = tz)
  as.numeric(difftime(forecast_time, dawn$nightEnd[match(morning, dawn$date)], units = "mins"))
}

waking_neighbour_formulas <- list(
  dawn_history_focal = minutes_to_wake ~ dawn + focal_motion + (1 | tag),
  all_peers = minutes_to_wake ~ dawn + focal_motion + peer_motion + (1 | tag),
  nearby_15m = minutes_to_wake ~ dawn + focal_motion + peer_motion +
    neighbour_contrast_15m + (1 | tag),
  nearby_30m = minutes_to_wake ~ dawn + focal_motion + peer_motion +
    neighbour_contrast_30m + (1 | tag)
)

forecast_waking_neighbours <- function(train, test) {
  if (!nrow(test)) return(NULL)
  predictions <- lapply(waking_neighbour_formulas, function(formula) {
    fit <- lmer(formula, data = train,
                control = lmerControl(check.conv.singular = "ignore"))
    list(minutes = pmax(0, predict(fit, newdata = test)), singular = isSingular(fit),
         note = paste(fit@optinfo$conv$lme4$messages, collapse = " | "))
  })
  reference <- c(NA, "dawn_history_focal", "all_peers", "all_peers")
  do.call(rbind, lapply(seq_along(predictions), function(i) {
    prediction <- predictions[[i]]
    model <- names(predictions)[i]
    reference_model <- reference[i]
    base_error <- if (is.na(reference_model)) NA_real_ else {
      test$minutes_to_wake - predictions[[reference_model]]$minutes
    }
    data.frame(model, reference_model, night_date = test$night_date, tag = test$tag,
               n_train = nrow(train), error = test$minutes_to_wake - prediction$minutes,
               reference_error = base_error, singular = prediction$singular,
               fit_note = prediction$note)
  }))
}

waking_neighbour_scores <- function(rows) {
  data.frame(model = rows$model[1L], reference_model = rows$reference_model[1L],
             n_wakes = nrow(rows), n_dates = length(unique(rows$night_date)),
             mae = mean(abs(rows$error)), rmse = sqrt(mean(rows$error^2)),
             mae_gain = mean(abs(rows$reference_error)) - mean(abs(rows$error)),
             rmse_gain = sqrt(mean(rows$reference_error^2)) - sqrt(mean(rows$error^2)),
             max_abs_error = max(abs(rows$error)),
             n_singular_dates = length(unique(rows$night_date[rows$singular])),
             fit_note = paste(unique(rows$fit_note[nzchar(rows$fit_note)]), collapse = " | "))
}

run_baboon_waking_neighbours <- function(output_dir = "analysis/results") {
  features <- read.csv(file.path(output_dir, "baboon-waking-neighbour-inputs.csv"))
  pairs <- read.csv(file.path(output_dir, "baboon-sleep-pairs.csv"))
  features$night_date <- as.Date(features$night_date)
  features$tag <- factor(features$tag)
  features$dawn <- minutes_since_dawn(features$night_date)
  dates <- sort(unique(as.Date(pairs$night_date)))
  stopifnot(length(dates) > 15L, all(features$night_date %in% dates),
            all(is.finite(features$dawn)), all(features$minutes_to_wake > 0),
            !anyDuplicated(features[c("night_date", "tag")]))

  predictions <- lapply(dates[-seq_len(15L)], function(day) {
    train <- features[features$night_date < day, ]
    test <- features[features$night_date == day & features$tag %in% train$tag, ]
    forecast_waking_neighbours(train, test)
  })
  predictions <- do.call(rbind, predictions)
  if (is.null(predictions)) stop("No late wake with eligible training records")
  by_model <- split(predictions, factor(predictions$model, levels = names(waking_neighbour_formulas)))
  summary <- do.call(rbind, lapply(by_model, waking_neighbour_scores))
  nightly <- lapply(split(predictions, predictions$night_date), function(night) {
    by_model <- split(night, factor(night$model, levels = names(waking_neighbour_formulas)))
    scores <- do.call(rbind, lapply(by_model, waking_neighbour_scores))
    data.frame(night_date = night$night_date[1L], n_train = night$n_train[1L], scores)
  })
  write.csv(summary, file.path(output_dir, "baboon-waking-neighbour-summary.csv"), row.names = FALSE)
  write.csv(do.call(rbind, nightly), file.path(output_dir, "baboon-waking-neighbour-by-night.csv"),
            row.names = FALSE)
}

if (sys.nframe() == 0L) run_baboon_waking_neighbours()
