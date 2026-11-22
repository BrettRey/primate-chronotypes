# Bayesian check of the first paper

This check refits the eight titi and eight baboon Gaussian specifications in the [first paper](paper-draft.md) with the original data, fixed and random effects, matched baselines, and forecast dates. It includes the first-20-night baboon estimates, the fixed holdouts, and the rolling baboon forecasts. Point forecasts average the timing predictions over the posterior. The scoring uses the same clock-time and night-centred errors and the same historical means and medians as the original analysis.

The priors are expressed in minutes. The normal priors on the means have a standard deviation of 120 minutes and are centred at lights-on for the titi monkeys, 20:00 for baboon period onset, and 06:00 for the baboon period end. Calendar slopes have a zero-centred normal prior with a standard deviation of 10 minutes per week. The half-normal prior scales for residual, date and fortnight standard deviations are 60, 40 and 30 minutes, respectively. The persistent standard deviation has a half-normal prior with a scale of either 30 or 15 minutes. Four Stan chains sample under the 30-minute prior. Weighting the draws by the prior density ratio gives the summaries for the 15-minute prior. [Priors for hierarchical standard deviations](https://sites.stat.columbia.edu/gelman/bayescomputation/Gelman2006.pdf)

## Results

| Outcome | Original persistent SD estimates, min | Bayesian posterior medians across both priors, min |
|---|---:|---:|
| Baboon period onset | 10.6–10.7 | 10.3–11.2 |
| Baboon period end | 0–3.2 | 2.4–3.5 |
| Titi onset, 2023 cohort | 2.9–4.1 | 3.1–4.6 |
| Titi onset, 2024 cohort | 13.2–15.6 | 13.2–16.7 |

The two boundary estimates for baboon period end became posterior medians of about 2.5 minutes, with 95% credible intervals extending from about 0.1 to 8 minutes. A continuous positive prior allows spreads arbitrarily close to zero and gives zero posterior probability to exactly zero. In the broad-prior fit, adding an animal effect improved pooled rolling onset RMSE by 0.12–0.54 minutes. On the matching late dates, changes ranged from a 0.81-minute worsening to a 0.70-minute improvement. Rolling end-time errors increased slightly in all four specifications under both priors. [Estimates](../analysis/results/bayesian-timing-estimates.csv) · [Baboon forecasts](../analysis/results/bayesian-timing-baboon-forecasts.csv)

The simplest titi Bayesian model and the historical cohort mean each had a fixed-holdout RMSE of about 33.3 minutes. In the broad-prior model their difference was about 0.01 minutes, smaller than the approximate Monte Carlo standard error of 0.04 minutes for the model RMSE. The latter comes from projecting the prediction draws onto the RMSE gradient at their posterior mean. Adding a calendar trend improved 2023 forecasts and worsened 2024 forecasts under both priors. [Titi forecasts](../analysis/results/bayesian-timing-titi-forecasts.csv)

The 354 final fits had zero divergent transitions. Across fixed coefficients and the residual, date, persistent and temporary scale parameters present in each fit, the largest rank-normalized split R-hat was 1.00997. The smallest bulk effective sample size was 299.3 and the smallest tail effective sample size was 115.1. The smallest effective sample size based on the normalized 15-minute prior weights was 2,350 of 2,400 draws. The smallest weight-based fraction over all fits was 93.9%. This last diagnostic describes concentration of the reweighting ratios separately from the chain diagnostics. The historical benchmark scores and evaluation counts matched the recorded frequentist comparison. [Per-fit sampling and weight diagnostics](../analysis/results/bayesian-timing-diagnostics.csv) · [Original benchmarks](../analysis/results/primate-forecast-benchmarks.csv)

## Reproduction

Use CmdStan, R with `lme4`, `jsonlite`, and `posterior`, and a fresh working directory for the model binary and intermediate fits. The commands below assume `cmdstan_dir` points to a working CmdStan installation. The script reuses the pinned titi archive and the reconstructed 2012 baboon records. Use fewer cores if needed.

```sh
bayes_work=$(mktemp -d)
cp analysis/bayesian-timing.stan "$bayes_work/model.stan"
make -C "$cmdstan_dir" "$bayes_work/model"
mkdir "$bayes_work/fits"
Rscript analysis/check-bayesian-timing.R "$bayes_work/model" "$bayes_work/fits" \
  analysis/results 8 all
```
