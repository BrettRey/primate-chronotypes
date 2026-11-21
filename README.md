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

Original code and repository documentation are available under the [MIT License](LICENSE). Third-party papers and datasets retain their own terms.
