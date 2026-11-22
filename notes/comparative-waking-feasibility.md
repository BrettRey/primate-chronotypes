# Feasibility of a comparative waking-time analysis

**Assessment.** The Sonso chimpanzee and Mpala olive baboon datasets support separate descriptions of recorded waking. Comparing their persistent individual spreads would require a defensible match between waking definitions and a common timescale for repeat observations.

## Waking measures

Hozer et al. coded sleep and wake from infrared recordings in five-minute blocks. Their Sonso workbook records `Wake_time` as decimal local hours and includes sunrise times. The paper describes morning waking, and the exact rule for marking its start in the recorded sequence needs clarification. [Study methods](https://doi.org/10.1016/j.cub.2025.11.057) · [Workbook and code, version 1](https://doi.org/10.6084/m9.figshare.30418156.v1)

Loftus et al. defined Mpala final waking as the end of the longest merged low-activity period within a noon-to-noon window. The reconstructed timestamps are in East Africa Time, the same clock reference as Sonso. Their 2019 validation compared accelerometer and behavioural classifications at the minute level. Agreement on those classifications leaves agreement on final-waking times to be established. The direct download of the small behavioural scoring file returned HTTP 403, so its morning coverage remains unverified. [Study and validation methods](https://cdn.elifesciences.org/articles/73695/elife-73695-v1.pdf) · [Validation data](https://doi.org/10.5061/dryad.p5hqbzkqf)

## Repeat coverage

| | Sonso chimpanzees | Mpala olive baboons |
|---|---:|---:|
| Waking records | 122 | 354 |
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

The public CC BY 4.0 Movebank deposit contains raw tri-axial acceleration bursts, GPS, animal identifiers, and deployment records for six adult females in four troops. The study reports 1,644 baboon-days. Its published code identifies final waking at the end of the longest merged low-activity interval in a noon-to-noon window, as in the 2012 study. See the reconstruction and comparison below. [Movebank archive](https://doi.org/10.5441/001/1.625) · [Study](https://doi.org/10.1098/rspb.2024.1330) · [Waking code](https://github.com/CarterLoftus/intergroup_sleep/blob/446448b8436f0408f87d13f7ec9359ef1ce860b7/CODE/04_effect_of_cosleeping_on_sleep_quality.R)

### Tibetan macaques in Huangshan, 2021–2022

The public supplement contains 204,932 minute-by-minute video scores. In `iSleep.xlsx`, combine `Date` and `Time`, sort within `S1eepperiod` (with a digit 1), and take the minute after the last `state=1` as coded waking. Assign the night by subtracting 12 hours from the waking timestamp before taking the date. All 288 periods have this transition, with one record per animal-night. All 27 animals contribute repeated records, 29 of 30 nights contain multiple animals, and 25 animals contribute pairs in both lag bands above. The median is 11 records per animal and 51 days from first to last record.

The scored sequences end one or two minutes after waking. These records support a comparison of scored awakening over similar repeat intervals. The video endpoint and the baboon accelerometer endpoint remain distinct measurements. The data ZIP has SHA-256 `3ae96a020431e4ee5be268b58ecef7dfd15c8b3e064667e10804858aa6b73de5`. [Study](https://doi.org/10.1016/j.anbehav.2026.123659) · [Scoring definitions](https://ars.els-cdn.com/content/image/1-s2.0-S000334722600196X-mmc1.docx) · [Data and code ZIP](https://ars.els-cdn.com/content/image/1-s2.0-S000334722600196X-mmc2.zip)

### Other accelerometry leads

The Laikipia project also collared vervets at the same site using the same protocol. The public deposit verified above covers the baboons. The Da Gama chacma study collected continuous accelerometry, and its public table contains aggregated transitions without the timestamps needed to reconstruct waking. [Laikipia baboon and vervet study](https://doi.org/10.1002/ajpa.23259) · [Da Gama data deposit](https://doi.org/10.5061/dryad.0rxwdbsc9)

## Replication and video comparison

I reproduced the Laikipia supplement’s 1,627 detected sleep periods from 1,634 recorded animal-nights after the study’s illness exclusion. Nine failed the published coverage checks, leaving 1,618 paired endpoints from 377 nights. On 23 complete animal-nights spanning all six animals, both endpoints exactly matched the source R functions. The source supplement documents nights when intervening activity truncated the detected sleep period. Twenty-two of the reconstructed intervals end before midnight. These times remain in the analysis as classified endpoints. [Reconstruction](../analysis/results/laikipia-sleep-pairs.csv) · [Loftus et al., supplementary methods and Figure S6](https://doi.org/10.6084/m9.figshare.27093873.v1)

The primary Laikipia comparison uses the 123 nights with all six animals, from 23 January to 26 May 2014. For each archive, the same four Gaussian specifications cross a calendar trend with an animal-by-fortnight effect and include a shared date effect. Laikipia models also vary whether they include fixed troop effects. Forecasting uses the final third of eligible dates, scoring previously observed animals and refitting the matched baseline without the persistent animal effect. The CSV gives restricted maximum-likelihood point estimates, maximum-likelihood profile intervals from `lme4`, and any profiling warnings. The ranges below summarise specification dependence.

| Sample | Persistent onset SD, min | Persistent waking SD, min | Waking RMSE gain, min |
|---|---:|---:|---:|
| Mpala 2012 | 10.6–10.7 | 0–3.2 | −0.02 to 0.00 |
| Laikipia, all six, pooling troops | 24–27 | 28–30 | 0.05 to 0.60 |
| Laikipia, all six, accounting for troop | 35–37 | 0–5.3 | About 0 |
| Huangshan macaques | | 3.5–3.8 | 0.45 to 0.84 |

Laikipia waking forecasts had errors around 103–104 minutes root mean square in the balanced holdout. With the full archive, the troop-adjusted waking spread was 11–12 minutes and forecast gains were 0.16–0.55 minutes. That holdout included four animals, compared with all six in the balanced holdout. Only two troops contain observed pairs. The two pairs’ early-to-late onset differences retained the same direction, while one pair’s waking difference reversed. On the same-night macaque score, waking gains ran from −0.16 to 0.07 minutes. [Model and forecast results](../analysis/results/primate-waking-replication.csv) · [Within-troop contrasts](../analysis/results/laikipia-troopmate-contrasts.csv)

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
