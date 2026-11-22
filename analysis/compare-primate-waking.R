source("analysis/fit-baboon-sleep.R")

read_laikipia_nights <- function(pairs, reference) {
  nights <- read_baboon_nights(pairs)
  metadata <- unique(read.csv(reference)[c("animal.id", "animal.group.id")])
  stopifnot(!anyDuplicated(metadata$animal.id))
  nights$troop <- factor(metadata$animal.group.id[match(nights$animal, metadata$animal.id)])
  stopifnot(!anyNA(nights$troop), nlevels(nights$troop) == 4L)
  nights
}

forecast_split <- function(nights) {
  first_test <- baboon_late_start(sort(unique(nights$day)))
  train <- nights[nights$day < first_test, ]
  test <- nights[nights$day >= first_test & nights$animal %in% train$animal, ]
  list(train = train, test = test)
}

check_timing <- function(nights, sample, endpoints, adjust_troop = FALSE) {
  specs <- baboon_specs[baboon_specs$endpoint %in% endpoints, ]
  split <- forecast_split(nights)
  results <- lapply(seq_len(nrow(specs)), function(i) {
    spec <- specs[i, ]
    formula <- with(spec, baboon_formula(endpoint, trend, temporary))
    baseline <- with(spec, baboon_formula(endpoint, trend, temporary, persistent = FALSE))
    if (adjust_troop) {
      formula <- update(formula, . ~ . + troop)
      baseline <- update(baseline, . ~ . + troop)
    }
    data.frame(sample, adjust_troop, spec,
               baboon_estimates(formula, nights),
               baboon_forecasts(formula, baseline, spec$endpoint, split$train, split$test))
  })
  do.call(rbind, results)
}

check_troopmates <- function(nights) {
  pairs <- split(nights, nights$troop)
  pairs <- pairs[vapply(pairs, function(rows) length(unique(rows$animal)) == 2L, logical(1))]
  first_test <- min(forecast_split(nights)$test$day)
  results <- lapply(pairs, function(rows) {
    animals <- sort(unique(as.character(rows$animal)))
    columns <- c("day", "onset", "waking")
    both <- merge(rows[rows$animal == animals[1L], columns],
                  rows[rows$animal == animals[2L], columns], by = "day")
    do.call(rbind, lapply(c("onset", "waking"), function(endpoint) {
      difference <- both[[paste0(endpoint, ".x")]] - both[[paste0(endpoint, ".y")]]
      train <- difference[both$day < first_test]
      test <- difference[both$day >= first_test]
      scores <- rmse_stats(data.frame(baseline = test^2, with_animal = (test - mean(train))^2))
      data.frame(troop = rows$troop[1L], endpoint, first_animal = animals[1L],
                 second_animal = animals[2L], n_train = length(train), n_test = length(test),
                 train_mean_difference = mean(train), test_mean_difference = mean(test), scores)
    }))
  })
  do.call(rbind, results)
}

main <- function(args) {
  if (length(args) != 4L) {
    stop("Usage: Rscript analysis/compare-primate-waking.R LAIKIPIA_PAIRS REFERENCE MACAQUE_PAIRS OUTPUT_DIR")
  }
  laikipia <- read_laikipia_nights(args[1L], args[2L])
  macaques <- read_baboon_nights(args[3L], local_zone = "Asia/Shanghai")
  baboons <- read_baboon_nights("analysis/results/baboon-sleep-pairs.csv")
  complete_dates <- ave(rep(1L, nrow(laikipia)), laikipia$day, FUN = length) ==
    nlevels(laikipia$animal)
  paired <- laikipia[complete_dates, ]
  endpoints <- c("onset", "waking")
  estimates <- rbind(
    check_timing(baboons, "mpala_2012", endpoints),
    check_timing(paired, "laikipia_all_six", endpoints),
    check_timing(paired, "laikipia_all_six", endpoints, adjust_troop = TRUE),
    check_timing(laikipia, "laikipia_full", endpoints),
    check_timing(laikipia, "laikipia_full", endpoints, adjust_troop = TRUE),
    check_timing(macaques, "huangshan", "waking")
  )
  write.csv(estimates, file.path(args[4L], "primate-waking-replication.csv"), row.names = FALSE)
  write.csv(check_troopmates(paired), file.path(args[4L], "laikipia-troopmate-contrasts.csv"),
            row.names = FALSE)
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
