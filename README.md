# Primate Chronotypes

An early research project on how consistently individual nonhuman primates differ in the timing of sleep and activity across days and settings.

See [AGENTS.md](AGENTS.md) for contributor guidance. Its workspace links apply to the parent portfolio checkout.

## Titi monkey simulation

Run the pilot from the repository root. It was checked with R 4.6.2 and `lme4` 2.0.6.

```sh
Rscript analysis/simulate-titi-onset.R
```

The script downloads and verifies the pinned [titi onset archive](https://github.com/guadarf/Lunar-gravity-sleep/blob/a499224e6972c277cfd889e614e39e94e85d8276/data/Data_S3_all_onsetData_titi.csv) from Rodríguez Ferrante et al. It reads the recording schedule and generates all onset values used in the simulation. Results in `analysis/results/` include the simulation runs and seeds, plus the median and the 10th and 90th percentiles for estimated spread and held-out RMSE gain in each condition. Positive RMSE gain favours the animal model over the model with cohort and date effects alone.

The observed-data script reports pooled and separate cohort estimates with 95% profile likelihood intervals, plus held-out prediction errors. Estimates, intervals, and forecasts are descriptive summaries. The simulation and observed fits can be run independently.

```sh
Rscript analysis/fit-titi-onset.R
```

The authors' [plotting code](https://github.com/guadarf/Lunar-gravity-sleep/blob/a499224e6972c277cfd889e614e39e94e85d8276/1_individual_plotsAndModels.R#L812) gives onset in hours from midnight. We express it in minutes relative to the study's 06:00 lights-on schedule. [Study methods](https://doi.org/10.64898/2026.01.27.701907)

## Titi onset multiverse

```sh
Rscript analysis/titi-multiverse.R
```

This exploratory analysis crosses common or separate cohort spreads, with or without temporary shifts within animals and cohort calendar trends. `analysis/results/titi-multiverse-*` contains the estimates, held-out forecasts, differences between models that change one choice, and recovery summaries from the 1,000 seeded pilot datasets. The figure uses the same held-out records across all eight models. The `observed` and `replay` arguments run the two stages separately.

## Ten-day recording window check

```sh
Rscript analysis/check-titi-ten-day-windows.R
```

Each ten-day window is paired with an expanding earlier record ending on the same date. Both fits use the same animals and forecast the same later observations. See the [window results](analysis/results/titi-ten-day-windows.csv) and [cohort summaries](analysis/results/titi-ten-day-summary.csv).

## Olive baboon sleep timing

The [paired endpoint table](analysis/results/baboon-sleep-pairs.csv) contains 354 baboon-nights from 22 animals across 34 night dates. We recovered the sequence reported by Loftus et al. (2022). The 506 recorded tag-nights yielded 491 classified sleep periods, 368 after the recording coverage exclusion, and 354 after the recording gap exclusion. The animals contributed between 1 and 30 paired nights, with a median of 21. Two animals contributed one night each. [Study, Figure 1 and Methods](https://doi.org/10.7554/eLife.73695)

Each row identifies a tag and gives the estimated sleep onset and final waking from its longest classified sleep period. Timestamps use East Africa Time (UTC+03:00). The night date is the local calendar date at the start of the noon-to-noon interval. The script reconstructs the timing measurements from accelerometer bursts using the published workflow. [Authors' code at the retrieved revision](https://github.com/CarterLoftus/baboon_sleep/tree/5b5dff9780a1e8084a9a6aa73281d066f204e091/CODE/main_analysis)

Download the four `Collective movement in wild baboons-acc-*.csv.zip` files to one directory. The script verifies each file against the archive checksum and handles the duplicate events at the three file boundaries. This command was checked with Python 3.14.10 and NumPy 2.4.2. [Movebank archive, retrieved 2026-11-21, CC0](https://doi.org/10.5441/001/1.3q2131q5)

```sh
python3 analysis/recover-baboon-sleep.py /path/to/movebank-files analysis/results/baboon-sleep-pairs.csv
```

### Paired comparison and forecasts

```sh
Rscript analysis/fit-baboon-sleep.R
```

Models use minutes since local noon and an effect shared by animals on each night. The four specifications cross a linear calendar trend with temporary animal effects in 14-day blocks starting at the first paired date. The [estimates](analysis/results/baboon-sleep-estimates.csv) give persistent between-animal SDs and 95% profile likelihood intervals for the full record and the first 20 nights as numbered by the authors. The table includes profiling warnings.

The [forecasts](analysis/results/baboon-sleep-forecasts.csv) use the same 85 pairs from the 12 latest dates for both endpoints. Each comparison adds a persistent animal effect to a baseline with the same calendar and temporary effects. Scores include RMSE and MAE for clock-time predictions and RMSE after centring errors within each night with multiple animals.

In the full record, persistent SDs were 10.6–10.7 minutes for onset and 0–3.2 minutes for waking across specifications. Holding out the later dates, adding persistent animal effects changed onset RMSE by −0.9 to +2.0 minutes and left waking RMSE within 0.03 minutes of its matched baseline. Two dates accounted for 79% of the basic waking model's squared forecast error. These estimates describe one group over this recording period.

### Night-by-night forecasts

```sh
Rscript analysis/check-baboon-rolling-forecasts.R
```

Start with 15 paired dates so that training spans two fortnights. Refit before each subsequent night using earlier records only. This yields 156 forecasts for each endpoint across 19 nights. The [summary](analysis/results/baboon-rolling-summary.csv) reports pooled scores and splits out the original 12 late dates. The [nightly scores](analysis/results/baboon-rolling-by-night.csv) retain the training and scoring counts for every fit.

Across the 19 nights, adding persistent animal effects lowered onset RMSE by 0.18–0.57 minutes for clock time and 0.53–1.08 minutes for timing relative to other animals on the same night. The change in waking RMSE was within 0.20 minutes. For onset on the original late dates, the change in clock-time RMSE ranged from a 0.79-minute improvement to a 0.79-minute worsening.

The rolling tables also report paired MSE gains for the clock-time and night-centred scores on exactly the records with multiple animals per night. [Supporting comparison](notes/forecast-diagnostics.md#rolling-forecast-scores)

### Historical timing benchmarks

```sh
Rscript analysis/check-primate-forecast-benchmarks.R
```

The script scores training-only means and medians on the same fixed and rolling holdouts as the models. It checks that the late rolling subset contains exactly the fixed baboon animal-nights. [Benchmark scores](analysis/results/primate-forecast-benchmarks.csv) · [Supporting table](notes/forecast-diagnostics.md#historical-forecast-benchmarks)

### Waking likelihood sensitivity

```sh
Rscript analysis/check-baboon-waking-likelihood.R
```

This check uses `glmmTMB` 1.1.15.2. It fits Gaussian and fixed Student-t residuals with 3 and 7 degrees of freedom by maximum likelihood on the same records and the same 85 held-out baboon-nights. The [comparison](analysis/results/baboon-waking-likelihood.csv) gives spread estimates, forecast scores, simulated error maxima, and optimizer diagnostics for all four waking specifications. The [likelihood grid](analysis/results/baboon-waking-likelihood-profile.csv) shows the effect of fixing the persistent standard deviation in the simplest specification. [Package documentation](https://glmmtmb.github.io/glmmTMB/reference/nbinom2.html)

### Morning neighbour activity pilot

Download the four `Collective movement in wild baboons-gps-*.csv.zip` files into the same directory as the four accelerometry parts. The preparation script verifies all eight archive checksums. The forecast script uses R with `lme4` and `suncalc` (checked with versions 2.0.6 and 0.5.4). [Movebank archive](https://doi.org/10.5441/001/1.3q2131q5)

```sh
python3 analysis/prepare-baboon-waking-neighbours.py /path/to/movebank-files analysis/results/baboon-waking-neighbour-inputs.csv
Rscript analysis/check-baboon-waking-neighbours.R
```

For a forecast at 06:05 local time, use the first ten distinct GPS fixes before 06:02 and the mean log VeDBA at 06:02–06:04. The baseline uses time since astronomical dawn, focal motion, and an animal random intercept. Nested models add mean peer motion and a distance-weighted peer mean centred on the unweighted mean, with exponential distance scales of 15 and 30 m. Both peer summaries use the same observed collars and exclude the focal animal. Fit on earlier dates and score later waking times for previously recorded animals, starting after the first 15 paired dates.

Of 170 classified endpoints later than 06:05, 154 had matching telemetry. All four models scored the same 56 later-date wakes across 17 nights. Mean absolute error was 11.58 min in the baseline, 11.87 min with mean peer motion, and 11.82–11.83 min with distance weighting. The forecast target is restricted in hindsight to late endpoints from one troop. [Matched records](analysis/results/baboon-waking-neighbour-inputs.csv) · [Forecast summary](analysis/results/baboon-waking-neighbour-summary.csv) · [Scores by night](analysis/results/baboon-waking-neighbour-by-night.csv)

### Paper figures

Install EB Garamond and use an R build with Cairo support. Run these commands from the repository root. They write vector PDFs and 300 DPI PNGs to `analysis/results/`.

```sh
Rscript analysis/plot-primate-timing-summary.R
Rscript analysis/plot-primate-timing-diagnostics.R
Rscript analysis/plot-primate-timing-supplement.R
Rscript analysis/titi-multiverse.R plot
```

The diagnostics command also writes [Gaussian simulated maximum-error quantiles](analysis/results/baboon-gaussian-error-maxima.csv) and [waking loss concentration by night](analysis/results/baboon-fixed-waking-error-concentration.csv).

The main paper displays observed timing by date and the multiverse estimates and gains. The supplement shows the simulated spread estimates, absolute titi forecast errors, recording windows, and baboon errors by night. [Observed timings](notes/paper-draft.md#records-and-timing-measures) · [Supporting figures](notes/forecast-diagnostics.md)

## Comparative waking follow-up

The Laikipia replication reconstructs waking from a later olive baboon archive and compares estimates and forecasts with and without troop effects. The Tibetan macaque analysis uses waking scored from video. The [feasibility notes](notes/comparative-waking-feasibility.md#replication-and-video-comparison) give the measurement definitions, source files, results, and reproduction commands.

Original code and repository documentation are available under the [MIT License](LICENSE). Third-party papers and datasets retain their own terms.
