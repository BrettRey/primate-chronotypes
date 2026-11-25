# Sleep endpoint figures
<!-- SUMMARY: Commands and data sources for the endpoint paper's two submission figures -->

These figures use the paired Huangshan endpoints and the Laikipia acceleration
traces described in [comparative waking feasibility](comparative-waking-feasibility.md).
The scripts require R, Cairo and the EB Garamond typeface. The input data are
distributed by their original repositories under their respective terms.

From the repository root, reconstruct the intermediate inputs and draw the
figures. Set `primate_data` to a directory containing the Yang publisher
supplement and the Laikipia acceleration archive as described in the
[source and reproduction notes](comparative-waking-feasibility.md#paired-endpoint-comparison-on-huangshan-video-scores).

```sh
python3 analysis/recover-macaque-sleep.py --compare-endpoints \
  "$primate_data/yang-mmc2.zip" "$primate_data/huangshan-paired-endpoints.csv"
python3 analysis/check-laikipia-waking-traces.py "$primate_data/laikipia-acc.zip" \
  analysis/results/laikipia-sleep-pairs.csv analysis/results/laikipia-waking-trace-audit.csv \
  "$primate_data/laikipia-waking-example-traces.csv"
Rscript analysis/plot-endpoint-submission-figure1.R \
  "$primate_data/huangshan-paired-endpoints.csv" analysis/results/endpoint-submission-figure1.pdf
Rscript analysis/plot-endpoint-submission-figure2.R \
  "$primate_data/laikipia-waking-example-traces.csv" analysis/results/endpoint-submission-figure2.pdf
```

For a 600-dpi raster instead, use the same command with a `.png` output name.
Both panels in Figure 2 are from the [CC BY 4.0 Laikipia Movebank deposit](https://doi.org/10.5441/001/1.625).
The article's captions explain the selected periods and the plotting conventions.
