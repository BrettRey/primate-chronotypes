# Feasibility of a comparative waking-time analysis

**Assessment.** The Sonso chimpanzee and Mpala olive baboon datasets support separate descriptions of recorded waking. Comparing their persistent individual spreads would require a defensible match between waking definitions and a common timescale for repeat observations.

## Waking measures

Hozer et al. coded sleep and wake from infrared recordings in five-minute blocks. Their Sonso workbook records `Wake_time` as decimal local hours and includes sunrise times. The paper describes morning waking, and the exact rule for marking its start in the recorded sequence needs clarification. [Study methods](https://doi.org/10.1016/j.cub.2025.11.057) · [Workbook and code, version 1](https://doi.org/10.6084/m9.figshare.30418156.v1)

The Mpala accelerometer endpoint is the end of the longest classified sleep period, formed by merging nearby low-activity bouts within a noon-to-noon window. The reconstructed timestamps are in East Africa Time, the same clock reference as Sonso. The published 2019 video scores cover evening states. [Study methods](https://doi.org/10.7554/eLife.73695) · [Behavioural validation coverage](#behavioural-validation-coverage)

## Repeat coverage

| | Sonso chimpanzees | Mpala olive baboons |
|---|---:|---:|
| Endpoint records | 122 | 354 |
| Animals with records | 35 | 22 |
| Animals observed repeatedly | 25 | 20 |
| Dates with multiple animals | 8 of 113 | 33 of 34 |
| Median records per animal | 2 | 21 |
| Median span for repeatedly observed animals | 250 days | 27.5 days |
| Animals with pairs at both 1–13 and 14–32 days apart | 7 | 12 |

The Sonso counts include all numeric waking entries in the workbook. Hozer et al. report 116 nights in their waking model. The lag bands reflect the fortnight models and the longest within-animal Mpala lag. Sonso has much less information on waking differences among animals observed on the same night.

## Reproduction

Download the [CC BY 4.0 Sonso workbook](https://ndownloader.figshare.com/files/61472446), retrieved 21 November 2026. The script reads `Id`, `Date`, and numeric `Wake_time` from sheet `SLEEP`. The Mpala input is the [reconstructed waking table](../analysis/results/baboon-sleep-pairs.csv) from the [CC0 Movebank archive](https://doi.org/10.5441/001/1.3q2131q5).

```sh
python3 analysis/check-comparative-waking-coverage.py /path/to/Hozer-et-al_2026_Current-Biology_Data.xlsx
```

The script requires Python with `openpyxl`. The downloaded Sonso workbook has SHA-256 `7a4518031641c3a67e187da9adb5f7beab03a2890c05aa3f5c7973adc0356f8b`.

## Additional datasets checked on 21 November 2026

### Olive baboons in Laikipia, 2014–2015

The public CC BY 4.0 Movebank deposit contains raw tri-axial acceleration bursts, GPS, animal identifiers, and deployment records for six adult females in four troops. The study reports 1,644 baboon-days. Its published code uses the start and end of the longest classified sleep period as timing endpoints, as in the 2012 study. See the reconstruction and comparison below. [Movebank archive](https://doi.org/10.5441/001/1.625) · [Study](https://doi.org/10.1098/rspb.2024.1330) · [Endpoint code](https://github.com/CarterLoftus/intergroup_sleep/blob/446448b8436f0408f87d13f7ec9359ef1ce860b7/CODE/04_effect_of_cosleeping_on_sleep_quality.R)

### Tibetan macaques in Huangshan, 2021–2022

The public supplement contains 204,932 minute-by-minute video scores. In `iSleep.xlsx`, combine `Date` and `Time`, sort within `S1eepperiod` (with a digit 1), and take the minute after the last `state=1` as coded waking. Assign the night by subtracting 12 hours from the waking timestamp before taking the date. All 288 periods have this transition, with one record per animal-night. All 27 animals contribute repeated records, 29 of 30 nights contain multiple animals, and 25 animals contribute pairs in both lag bands above. The median is 11 records per animal and 51 days from first to last record.

The study methods describe overnight recording and define night by astronomical twilight and dawn. Supplementary Table S2 defines awakening as when the animal finishes sleeping. The archived sequences end one or two minutes after the last observed sleep-to-wake transition. The methods, Table S2, workbook field definitions and accompanying time-series script leave the stopping or trimming rule for the archived sequences unspecified. I use *last observed awakening* for this endpoint. The data ZIP has SHA-256 `3ae96a020431e4ee5be268b58ecef7dfd15c8b3e064667e10804858aa6b73de5`. [Study](https://doi.org/10.1016/j.anbehav.2026.123659) · [Scoring definitions](https://ars.els-cdn.com/content/image/1-s2.0-S000334722600196X-mmc1.docx) · [Data and code ZIP](https://ars.els-cdn.com/content/image/1-s2.0-S000334722600196X-mmc2.zip)

### Other accelerometry leads

The Laikipia project also collared vervets at the same site using the same protocol. The public deposit verified above covers the baboons. The Da Gama chacma study collected continuous accelerometry, and its public table contains aggregated transitions without the timestamps needed to reconstruct waking. [Laikipia baboon and vervet study](https://doi.org/10.1002/ajpa.23259) · [Da Gama data deposit](https://doi.org/10.5061/dryad.0rxwdbsc9)

## Replication and video comparison

I reproduced the Laikipia supplement’s 1,627 detected sleep periods from 1,634 recorded animal-nights after the study’s illness exclusion. Nine failed the published coverage checks, leaving 1,618 paired endpoints from 377 nights. On 23 complete animal-nights spanning all six animals, both endpoints exactly matched the source R functions. The source supplement documents nights when intervening activity truncated the detected sleep period. Twenty-two of the reconstructed intervals end before midnight. These times remain in the analysis as classified endpoints. [Reconstruction](../analysis/results/laikipia-sleep-pairs.csv) · [Loftus et al., supplementary methods and Figure S6](https://doi.org/10.6084/m9.figshare.27093873.v1)

The primary Laikipia comparison uses the 123 nights with all six animals, from 23 January to 26 May 2014. For each archive, the same four Gaussian specifications cross a calendar trend with an animal-by-fortnight effect and include a shared date effect. Laikipia models also vary whether they include fixed troop effects. Forecasting uses the final third of eligible dates, scoring previously observed animals and refitting the matched baseline without the persistent animal effect. The CSV gives restricted maximum-likelihood point estimates, maximum-likelihood profile intervals from `lme4`, and any profiling warnings. The ranges below summarise specification dependence.

| Sample | Persistent onset SD, min | Second endpoint | Persistent SD, min | RMSE gain, min |
|---|---:|---|---:|---:|
| Mpala 2012 | 10.6–10.7 | End of longest classified sleep period | 0–3.2 | −0.02 to 0.00 |
| Laikipia, all six, pooling troops | 24–27 | End of longest classified sleep period | 28–30 | 0.05 to 0.60 |
| Laikipia, all six, accounting for troop | 35–37 | End of longest classified sleep period | 0–5.3 | About 0 |
| Huangshan macaques | | Video-scored awakening | 3.5–3.8 | 0.45 to 0.84 |

Laikipia forecasts of the end time had errors around 103–104 minutes root mean square in the balanced holdout. With the full archive, the troop-adjusted end-time spread was 11–12 minutes and forecast gains were 0.16–0.55 minutes. That holdout included four animals, compared with all six in the balanced holdout. Only two troops contain observed pairs. The two pairs’ early-to-late onset differences retained the same direction, while one pair’s end-time difference reversed. On the same-night macaque score, awakening gains ran from −0.16 to 0.07 minutes. [Model and forecast results](../analysis/results/primate-waking-replication.csv) · [Within-troop contrasts](../analysis/results/laikipia-troopmate-contrasts.csv)

### Running the comparison

Use Python 3.11 or later with NumPy and openpyxl, and R with lme4. Download the [Laikipia acceleration ZIP](https://datarepository.movebank.org/server/api/core/bitstreams/6e4f68da-b276-4b4a-85b4-8bdf4b6bb298/content), [deployment reference CSV](https://datarepository.movebank.org/server/api/core/bitstreams/811a0229-dfa6-4905-afcb-83ae607b717a/content), and [Huangshan supplement](https://ars.els-cdn.com/content/image/1-s2.0-S000334722600196X-mmc2.zip) to a working directory outside the repository. Save them using the input filenames below. Run these commands from the repository root with `primate_data` set to that working directory.

```sh
python3 analysis/recover-baboon-sleep.py --laikipia "$primate_data/laikipia-acc.zip" \
  "$primate_data/laikipia-sleep-pairs.csv"
python3 analysis/recover-macaque-sleep.py "$primate_data/yang-mmc2.zip" \
  "$primate_data/huangshan-sleep-pairs.csv"
Rscript analysis/compare-primate-waking.R "$primate_data/laikipia-sleep-pairs.csv" \
  "$primate_data/laikipia-reference.csv" "$primate_data/huangshan-sleep-pairs.csv" analysis/results
```

The Laikipia endpoints derive from [Isbell et al.’s CC BY 4.0 deposit](https://doi.org/10.5441/001/1.625). The deployment CSV SHA-256 is `8bbac23ec713c3bb24732e9690b2f603783fe2a4556bb402a98f256435cd3a00`. The scripts check the published acceleration ZIP’s Movebank MD5 and the macaque supplement SHA-256. The macaque export stores the first scored sleep minute for traceability and the comparison fits the waking endpoint only.

## Early classified waking times

I replayed the full noon-to-noon activity traces for all 22 Laikipia records with an endpoint before midnight. Each record had 721–832 subsequent minute bursts. Using the original smoothing and merging rules, 21 contained another classified low-activity period after the selected one. The longest later period in those 21 records had a median duration of 167 minutes and ranged from 38 to 285 minutes. The early records came from five animals across 21 dates, with 12 from one animal. [Trace audit](../analysis/results/laikipia-waking-trace-audit.csv)

On the earliest record, the longest interval ended at 22:02. Three shorter intervals followed, the last ending at 05:55. Another animal recorded that night had a much longer selected period ending at 05:21 and a later interval from 07:10 to 08:32. The example shows why choosing the last qualifying interval would define a different endpoint and could capture morning rest. Accelerometry establishes further quiet periods in these traces. Identifying sustained waking would require evidence that distinguishes sleep from quiet wakefulness. [Example traces](../analysis/results/laikipia-waking-example.png) · [Source supplement, Figure S6](https://doi.org/10.6084/m9.figshare.27093873.v1)

The audit also includes the same-night comparison for the earliest endpoint. The script checks that both reconstructed endpoints and the burst count match the saved table before reporting any later periods. Run these commands with the same input ZIP and Python dependencies as above. The figure uses Cairo and EB Garamond.

```sh
python3 analysis/check-laikipia-waking-traces.py "$primate_data/laikipia-acc.zip" \
  analysis/results/laikipia-sleep-pairs.csv analysis/results/laikipia-waking-trace-audit.csv \
  "$primate_data/laikipia-waking-example-traces.csv"
Rscript analysis/plot-laikipia-waking-traces.R "$primate_data/laikipia-waking-example-traces.csv" \
  analysis/results/laikipia-waking-example.png
```

## Behavioural validation coverage

The CC0 Dryad version 6 scoring file, retrieved 21 November 2026, contains 230 scored intervals from seven olive baboons on 2 and 12 August 2019. The latest interval ends at 21:32 East Africa Time after applying the archive’s 16-second clock correction. All `Unalert` scores, which the validation code treats as sleep, come from one animal. The final paper reports agreement across 301 matched minute epochs. That comparison calibrates state classifications at the observed times. Estimating agreement on sustained waking requires paired behavioural and accelerometer records that span the morning transition. [Dryad archive](https://doi.org/10.5061/dryad.p5hqbzkqf) · [Final paper](https://doi.org/10.7554/eLife.73695) · [Validation code](https://github.com/CarterLoftus/baboon_sleep/blob/5b5dff9780a1e8084a9a6aa73281d066f204e091/CODE/validation_study/02_sleep_validation.R)

Download `2019_Papio_anubis_behavioral_scoring_Loftus_et_al_Dryad.csv` from the January 2022 file list. The coverage script checks the SHA-256 and uses the published start and stop times.

```sh
python3 analysis/check-baboon-validation-coverage.py /path/to/2019_Papio_anubis_behavioral_scoring_Loftus_et_al_Dryad.csv
```

## Simulated overnight interruption

The input is a complete noon-to-noon series at one-minute intervals. Simulated log activity is 2 during sleep and 5 during wake. In every case sleep starts at 20:00 and morning waking occurs at 06:00. An interruption temporarily returns activity to 5. The existing classifier smooths the series, identifies low-activity bouts longer than 30 minutes, merges bouts separated by less than 45 minutes, and selects the longest resulting period. [Classifier](../analysis/recover-baboon-sleep.py) · [Source methods](https://doi.org/10.6084/m9.figshare.27093873.v1)

| Simulated interruption | Classified onset | Classified end |
|---|---:|---:|
| None | 20:00 | 06:00 |
| 44 minutes starting at 01:00 | 20:00 | 06:00 |
| 45 minutes starting at 01:00 | 20:00 | 01:00 |
| 45 minutes starting at 23:00 | 23:45 | 06:00 |

At 01:00, extending the interruption by one minute splits the classified period and moves its end five hours earlier. At 23:00, the same 45-minute interruption leaves a longer period after the gap, which moves the classified onset instead. This illustrates how the rule can turn differences in overnight activity into differences in the timing endpoints even when simulated bedtime and morning waking coincide. The activity levels and interruptions are illustrative inputs. [Simulation results](../analysis/results/baboon-interruption-simulation.csv)

Run from the repository root with Python and NumPy.

```sh
python3 analysis/simulate-baboon-interruption.py analysis/results/baboon-interruption-simulation.csv
```

## Partially pooled Bayesian comparison

I fit Gaussian models to the recorded endpoint in each archive. Each model has a date effect shared by the animals observed that day. A persistent animal intercept shrinks deviations toward a study-wide mean or, when Laikipia models allow separate troop means, the mean for that animal’s troop. For sampling, the latter models express these effects as a combined troop mean and a contrast for each observed pair. Each archive has its own persistent standard deviation. I vary whether the models include independent animal offsets for consecutive 14-day blocks anchored on the archive’s first date. These initial fits omit calendar trends.

Forecasts average over the posterior and use the earlier comparison’s final-third holdouts for previously observed animals. The refitted matched baseline omits the persistent intercept. A new date or animal-by-fortnight offset contributes zero to the forecast. Historical forecasts use the training mean and median for each troop when the model adjusts for troop, and the study group’s mean and median otherwise. The priors and sampler settings follow the first paper’s Bayesian check. The two half-normal scales for the persistent standard deviation are 15 and 30 minutes. [First paper’s Bayesian check](first-paper-bayesian-check.md)

The schedule replay uses Laikipia’s 738 balanced animal-nights. Simulated morning time has a shared date standard deviation of 15 minutes and residual standard deviation of 20 minutes. The persistent animal standard deviation is zero. The second series subtracts five hours from the recorded endpoint on 12 evenly spaced nights for one animal, using the shift from the deterministic interruption example. This illustrative frequency is a simulation input. Both series use the same random draws and fitting procedure.

### Results

On the 123 balanced Laikipia nights, posterior medians for the persistent spread were 22–31 minutes with a shared mean and 8–11 minutes with troop means, across priors and model specifications. Holding the fortnight choice fixed, changing the prior scale from 15 to 30 minutes moved the troop-adjusted median from 7.7 to 10.5 minutes in the model without fortnight effects. Its central 95% posterior intervals were 0.3–26.4 and 0.4–42.2 minutes, respectively. Only two troops supply within-troop pairs, leaving considerable uncertainty about the spread. [Posterior estimates](../analysis/results/comparative-waking-bayes-estimates.csv)

In Laikipia’s balanced holdout, adding the persistent effect to the troop-adjusted models improved clock-time root mean squared error (RMSE) by 0.02–0.04 minutes against matched baselines of about 104 minutes. In the full archive, troop-adjusted medians were 11–16 minutes and the corresponding RMSE gain was 0.38–0.59 minutes on a different holdout with four animals. [Forecast scores](../analysis/results/comparative-waking-bayes-forecasts.csv)

In the balanced sample, the mean signed difference between the two AI troopmates reversed from +14.6 minutes in training to −21.1 minutes in the holdout. The model without fortnight offsets forecast a difference of +4.6 to +6.2 minutes across priors. The LI pair retained the same ordering, with its mean difference going from −11.1 to −40.8 minutes. The corresponding forecast was −5.0 to −3.8 minutes. [Troopmate comparison](../analysis/results/comparative-waking-bayes-troopmates.csv)

For Huangshan video-scored awakening, posterior medians were 3.6–3.9 minutes. Adding a persistent effect improved clock-time RMSE by about 0.37 minutes in the model without fortnight offsets and worsened it by about 0.18 minutes in the fortnight model. The raw training mean had an RMSE of 21.89 minutes on the same 108 animal-nights, compared with 25.10–25.16 minutes for the animal models. The training median had a mean absolute error of 12.80 minutes, compared with 21.88–21.91 minutes for the animal models’ posterior mean forecasts. Training observations were unevenly distributed across dates. The raw mean weights each observation equally. The date effects can cushion the influence of densely sampled training dates on the fitted mean. [Forecast scores](../analysis/results/comparative-waking-bayes-forecasts.csv)

In the simulated series, the five-hour shifts moved the median persistent spread from 3.7 to 15.4 minutes under the 15-minute prior, and from 4.2 to 19.4 minutes under the 30-minute prior. The recorded classification time acquired a persistent component in this replay even though the simulated morning waking process had none. [Simulation summaries](../analysis/results/comparative-waking-bayes-simulation.csv)

The 32 final fits had zero divergent transitions. The largest split R-hat for the monitored coefficients and scale parameters was 1.010. The forecast counts and historical benchmark errors match direct calculations from the holdout records. [Sampling diagnostics](../analysis/results/comparative-waking-bayes-diagnostics.csv)

### Reproduction

Compile the current Stan source as in the first paper’s Bayesian check and recover the Laikipia and Huangshan tables above. From the repository root, run the following with a fresh scratch directory for the comparative fits. [Stan build instructions](first-paper-bayesian-check.md#reproduction)

```sh
mkdir "$bayes_work/comparative-fits"
Rscript analysis/fit-comparative-waking-bayes.R "$bayes_work/model" \
  "$bayes_work/comparative-fits" analysis/results/laikipia-sleep-pairs.csv \
  "$primate_data/laikipia-reference.csv" "$primate_data/huangshan-sleep-pairs.csv" \
  analysis/results 8
```

## Paired endpoint comparison on Huangshan video scores

I applied the baboon bout rules directly to the minute-by-minute macaque video scores. I kept contiguous sleep bouts longer than 30 minutes, joined successive qualifying bouts separated by less than 45 minutes, and took the first minute after the end of the longest resulting period. If periods tied for longest, I used the first. I also retained the last qualifying end to describe how much discrepancy arose during bout processing and how much arose when choosing the longest among the resulting periods. The full baboon pipeline uses smoothing and an activity cutoff upstream of these rules. [Baboon rule and source supplement](https://doi.org/10.6084/m9.figshare.27093873.v1) · [Huangshan scoring and archive](#tibetan-macaques-in-huangshan-20212022)

The endpoints agree on 30 of 287 paired animal-nights. On the other 257 nights the longest period ends earlier. Across all 287 pairs, the median difference is 253 minutes, with quartiles of 54 and 418 minutes and a maximum of 640 minutes. The longest period ends before midnight on 89 nights. All last observed awakenings occur after midnight. On the most discrepant night, the rule selects a 35-minute bout ending at 19:59, followed by 488 minutes scored as sleep across 46 later bouts. One of the 288 records yields no qualifying period. Its longest continuous sleep bout lasts exactly 30 minutes. The figure shows the cumulative share of paired nights with a difference at or below each value on the horizontal axis. [Endpoint differences (PDF)](../analysis/results/huangshan-endpoint-differences.pdf)

The end of the last qualifying period is earlier than the last observed awakening on 206 nights. Choosing the longest qualifying period moves the endpoint earlier again on 182 nights. The two differences have medians of 40 and 181 minutes across the same 287 pairs, including zero differences. They add to the combined difference on each night. [Endpoint-step summaries](../analysis/results/huangshan-endpoint-steps.csv)

I refit both Gaussian specifications under both prior scales for each endpoint, using 287 paired records for estimation and the same 108 animal-nights on 10 dates for forecast evaluation. The one unpaired record lies in the training window, so the paired training set has 179 of the original 180 records. Each forecast is evaluated against its own endpoint. The ranges below span both priors and the two choices for fortnight effects. [Posterior estimates](../analysis/results/huangshan-endpoint-estimates.csv) · [Forecast scores](../analysis/results/huangshan-endpoint-forecasts.csv)

| Endpoint | Posterior median persistent SD, min | Animal-model RMSE, min | RMSE gain vs. matched baseline, min | Historical-mean RMSE, min |
|---|---:|---:|---:|---:|
| Last observed awakening | 3.7–4.0 | 24.6–25.5 | −0.04 to −0.02 | 21.6 |
| End of longest selected period | 25.6–48.0 | 176.8–179.8 | 1.37–4.40 | 182.3 |

Applying the bout-processing and longest-period selection procedure changed the estimated spread and the gain from adding a persistent animal effect. The magnitude of the spread for the longest-period end was sensitive to the prior. In the estimate and forecast CSV files, `scored_awakening` identifies last observed awakening. The descriptive file `huangshan-endpoint-steps.csv` reports earlier shifts for each stage and for the complete procedure. Individual minute scores remain in the publisher archive.

The 12 final fits had zero divergent transitions. Among monitored coefficients and scale parameters, the largest split R-hat was 1.009 and the smallest bulk and tail effective sample sizes were 337 and 529. The minimum weight-based effective sample size for the 15-minute prior was 994 of 4,000 draws. The [estimates table](../analysis/results/huangshan-endpoint-estimates.csv) gives posterior medians and central 95% intervals for all eight endpoint, prior and fortnight combinations. [Per-fit diagnostics](../analysis/results/huangshan-endpoint-diagnostics.csv)

### Reproduction

Use the Huangshan supplement above, Python with NumPy and openpyxl, and the current Stan binary. Plotting uses Cairo and EB Garamond. Run from the repository root.

```sh
python3 analysis/recover-macaque-sleep.py --compare-endpoints \
  "$primate_data/yang-mmc2.zip" "$primate_data/huangshan-paired-endpoints.csv"
mkdir "$bayes_work/huangshan-endpoint-fits"
Rscript analysis/compare-huangshan-endpoints.R "$bayes_work/model" \
  "$bayes_work/huangshan-endpoint-fits" "$primate_data/huangshan-paired-endpoints.csv" \
  analysis/results 8
```
