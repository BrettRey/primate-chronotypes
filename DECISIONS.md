# Decisions
<!-- SUMMARY: Descriptive multiverse for titi onset and paired baboon sleep timing · status: exploratory fits and forecasts complete · updated: 2026-11-21 -->

2026-11-21 — Brett approved the recording schedule simulation in Roughdraft. The pilot estimates the between-animal standard deviation of activity onset after cohort and date adjustment. The initial analysis used a simulation comparison to decide when to fit the observed onsets. The scripts report [simulation summaries](analysis/results/titi-simulation-summary.csv), [observed estimates](analysis/results/titi-observed-fit.csv), and [held-out prediction errors](analysis/results/titi-observed-forecast.csv).

2026-11-21 — Brett chose a multiverse study with descriptive comparisons of magnitude, uncertainty, and predictive performance. This supersedes the pilot's initial pass/fail rule. The analysis uses no significance decisions or p-values.

2026-11-21 — Brett approved crossing cohort pooling, animal-by-fortnight shifts, and cohort calendar trends in Roughdraft. The pilot informed the eight exploratory specifications. Use the same held-out dates and score the same animals for every specification. See the [estimates](analysis/results/titi-multiverse-estimates.csv), [forecasts](analysis/results/titi-multiverse-forecasts.csv), and [seeded simulation summaries](analysis/results/titi-multiverse-simulations.csv).

For the discussion, see the [literature caveats](notes/literature-caveats.md) on recording duration, social synchrony, and what activity timing measures.

2026-11-21 — The paired baboon comparison extends the exploratory titi design to two outcomes from the same animal-nights. Fit a shared night effect in every specification. Cross a linear calendar trend with a temporary animal-by-fortnight effect, and estimate the persistent between-animal spread in minutes for each endpoint. Repeat the estimates using the study's first 20 numbered nights. On the final third of the full archive's paired dates, compare each model with its matched baseline without the persistent animal effect. Keep the same observed pairs for each forecast. [Source study, Figure 3 and Methods](https://doi.org/10.7554/eLife.73695)
