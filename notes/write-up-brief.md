# Repeatability of observed primate timing
<!-- SUMMARY: Results and scope for writing up the exploratory titi and baboon multiverses · status: working brief · updated: 2026-11-21 -->

## Question

How much do animals differ consistently in their timing over the recording period, and how much does knowing an animal's history help predict its timing on later dates? Use the estimated between-animal standard deviation in minutes after accounting for effects shared on a date. Forecast comparisons use the same later observations of previously recorded animals for each specification.

## Captive titi monkeys

The outcome is locomotor activity onset relative to scheduled lights-on. In models with a common between-animal spread and no linear calendar trend, allowing animal-specific shifts by fortnight reduced the estimated persistent spread from 11.2 to 7.3 minutes. The corresponding 95% profile intervals were 7.3–16.0 and 0–12.6 minutes. When the two cohorts had their own spreads, estimates across specifications were 2.9–4.1 minutes in 2023 and 13.2–15.6 in 2024. Across all eight specifications, the matched animal models changed RMSE on the same 325 later records by −1.06 to +0.39 minutes. [Source study](https://doi.org/10.64898/2026.01.27.701907) · [Estimates](../analysis/results/titi-multiverse-estimates.csv) · [Forecasts](../analysis/results/titi-multiverse-forecasts.csv)

The recording schedule can make temporary shifts look persistent. In simulations with a 20-minute fortnight spread, a 20-minute residual spread, and zero persistent spread, the common-spread model without a trend estimated a median persistent spread of 10.8 minutes when it omitted the fortnight effect. Including the effect reduced the median to 0.3 minutes. In the observed ten-day check, shorter windows changed estimates in both directions, with median changes of −0.3 and −0.6 minutes for 2023 and 2024. [Simulation results](../analysis/results/titi-multiverse-simulations.csv) · [Ten-day comparisons](../analysis/results/titi-ten-day-summary.csv)

## Wild olive baboons

Use sleep onset and final waking estimated from accelerometry on the same 354 animal-nights. Full-record estimates across specifications were 10.6–10.7 minutes for onset and 0–3.2 minutes for waking. The simplest model's 95% profile intervals were 6.7–16.2 and 0–8.1 minutes, respectively. Fitting only the source study's first 20 numbered nights preserved the ordering of the point estimates. [Source study](https://doi.org/10.7554/eLife.73695) · [Estimates](../analysis/results/baboon-sleep-estimates.csv)

With the models updated before each of 19 forecast nights, adding persistent animal effects lowered onset RMSE by 0.18–0.57 minutes for clock time and by 0.53–1.08 minutes relative to other animals on the same night. Waking RMSE changed by less than 0.20 minutes. Two dates contributed 79% of the waking squared error in the simplest model on the original late block. [Night-by-night forecasts](../analysis/results/baboon-rolling-summary.csv) · [Fixed-block forecasts](../analysis/results/baboon-sleep-forecasts.csv)

## Scope

The titi comparison shows how recording duration and temporary shifts affect estimates of repeatability. The baboon comparison shows how repeatability can differ between two timing measures in one troop. A species comparison would require comparable outcomes sampled under comparable conditions. Claims about endogenous timing would require measurements that distinguish clock differences from the effects of light, social schedules, and other shared conditions. [Literature caveats](literature-caveats.md)
