# Decisions
<!-- SUMMARY: Descriptive multiverse for titi onset and paired baboon sleep timing · status: exploratory fits and forecasts complete · updated: 2026-11-21 -->

2026-11-21 — Brett approved the recording schedule simulation in Roughdraft. The pilot estimates the between-animal standard deviation of activity onset after cohort and date adjustment. The initial analysis used a simulation comparison to decide when to fit the observed onsets. The scripts report [simulation summaries](analysis/results/titi-simulation-summary.csv), [observed estimates](analysis/results/titi-observed-fit.csv), and [held-out prediction errors](analysis/results/titi-observed-forecast.csv).

2026-11-21 — Brett chose a multiverse study with descriptive comparisons of magnitude, uncertainty, and predictive performance. This supersedes the pilot's initial pass/fail rule. The analysis uses no significance decisions or p-values.

2026-11-21 — Brett approved crossing cohort pooling, animal-by-fortnight shifts, and cohort calendar trends in Roughdraft. The pilot informed the eight exploratory specifications. Use the same held-out dates and score the same animals for every specification. See the [estimates](analysis/results/titi-multiverse-estimates.csv), [forecasts](analysis/results/titi-multiverse-forecasts.csv), and [seeded simulation summaries](analysis/results/titi-multiverse-simulations.csv).

For the discussion, see the [literature caveats](notes/literature-caveats.md) on recording duration, social synchrony, and what activity timing measures.

2026-11-21 — The paired baboon comparison extends the exploratory titi design to two outcomes from the same animal-nights. Fit a shared night effect in every specification. Cross a linear calendar trend with a temporary animal-by-fortnight effect, and estimate the persistent between-animal spread in minutes for each endpoint. Repeat the estimates using the study's first 20 numbered nights. On the final third of the full archive's paired dates, compare each model with its matched baseline without the persistent animal effect. Keep the same observed pairs for each forecast. [Source study, Figure 3 and Methods](https://doi.org/10.7554/eLife.73695)

2026-11-21 — Check the sensitivity of the baboon forecasts to the late block. The first 14 dates lie in one fortnight, so use the first 15 dates as the initial training record to distinguish the two animal effects. Then update the fit before each subsequent date using earlier records only. Score previously recorded animals on the same pairs across models and endpoints. Report the earlier and original late forecast dates separately, along with pooled scores and scores by date. Retain the existing model specifications.

2026-11-21 — Frame the exploratory write-up around repeatable differences in observed timing and their contribution to forecasts of later records. Use the baboon pairing to compare endpoints within one troop and the titi multiverse to show sensitivity to model and recording window. [Write-up brief](notes/write-up-brief.md)

2026-11-21 — Brett agreed that the titi and baboon reanalyses belong in one first paper. The paper estimates repeatable differences and evaluates later-date forecasts within each dataset. The broader question concerns comparable chronotype distributions across species. [Project status](STATUS.md)

2026-11-21 — Brett specified single authorship. The revised draft states the model choices in a table and shows all multiverse specifications in Figure 1. Figure 2 shows recording-window sensitivity and the distribution of held-out errors. The observed waking extremes motivate considering a Student-t residual sensitivity check. [Paper draft](notes/paper-draft.md)

2026-11-21 — Brett approved the Student-t residual check for baboon final waking. Compare Gaussian and Student-t observation likelihoods under the same maximum-likelihood fitting procedure in all four waking specifications. Fit the distributions to identical records, estimate the Student-t degrees of freedom, and score the original fixed forecast block. Match each animal model to a baseline that omits the persistent animal effect while retaining the other terms. The two extreme waking times passed the source coverage rules and remain in the analysis.

2026-11-21 — Several fits with freely estimated Student-t degrees of freedom failed to converge, and usable fits suggested degrees of freedom near 1.3. The sensitivity check uses fixed degrees of freedom of 3 and 7 to examine heavy and moderate tails with finite residual variance. Retain the same animal effects, dates, and scored pairs. Check numerical stability from several starting values.
