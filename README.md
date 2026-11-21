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

Original code and repository documentation are available under the [MIT License](LICENSE). Third-party papers and datasets retain their own terms.
