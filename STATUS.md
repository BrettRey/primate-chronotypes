# Primate Chronotypes
<!-- SUMMARY: Single-author multiverse paper on repeatability and prediction · status: revised draft · updated: 2026-11-21 -->

The first paper is a single exploratory reanalysis with two case studies. It asks how much individual timing varies consistently within each study and how much animal history improves forecasts on later dates. Brett agreed to this scope on 2026-11-21. [Decision record](DECISIONS.md)

The titi multiverse, the paired baboon analysis, and the forecasting checks are available in the public repository. [Verified results and scope](notes/write-up-brief.md)

The wider comparative project concerns chronotype distributions across nonhuman primates. It would require comparable timing measures across species and a design that distinguishes endogenous timing from social and environmental influences.

The revised single-author draft, *Individual variation and forecast accuracy in titi monkey activity onset and olive baboon sleep timing*, makes the distinction between estimated individual spread and later-date prediction explicit. It gives baseline and animal-model errors, matched squared-loss comparisons, and conditional simulation quantiles. The main figures show the observed timings and multiverse results. [Paper draft](notes/paper-draft.md) · [Supporting diagnostics](notes/forecast-diagnostics.md) · [Figure 1](analysis/results/primate-timing-observations.png) · [Figure 2](analysis/results/primate-timing-summary.png)

The Student-t sensitivity check for baboon waking is complete. Heavier-tailed fits give small persistent waking spreads and lower mean absolute forecast errors across specifications. The largest observed errors remain much larger than typical simulated maxima. [Likelihood comparison](analysis/results/baboon-waking-likelihood.csv) · [Likelihood grid](analysis/results/baboon-waking-likelihood-profile.csv)

The supplement shows recovery of simulated persistent spread, absolute titi forecast errors, the window and error diagnostics, and training-only mean and median benchmarks. The main text gives the rolling onset gains on the 85 records also used for fixed forecasts. [Supplement](notes/forecast-diagnostics.md) · [Forecast benchmarks](analysis/results/primate-forecast-benchmarks.csv)

The separate repository pilot compares late baboon waking forecasts with and without morning peer activity. On 56 later-date animal-nights after 06:05, the baseline using dawn, focal motion, and animal history had the lowest pooled mean absolute forecast error. Distance weighting improved the all-peer model by 0.04–0.05 minutes. [Pilot design and reproduction](README.md#morning-neighbour-activity-pilot) · [Forecast summary](analysis/results/baboon-waking-neighbour-summary.csv)
