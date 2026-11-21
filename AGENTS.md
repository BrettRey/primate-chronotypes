# Repository Guidelines
<!-- SUMMARY: Contributor guidance for the primate chronotypes research seed -->

## Project Scope and Layout

This research seed examines how consistently individual nonhuman primates differ in the timing of sleep or activity. The directory starts with this guide alone. Read the workspace [AGENTS.md](../../../AGENTS.md) and [CLAUDE.md](../../../CLAUDE.md) for shared practices. Record substantive project decisions in `DECISIONS.md` when they are made.

Add directories as the work needs them. Keep analysis scripts in `analysis/` and source notes in `notes/`. Store derived outputs separately from source files so another contributor can reproduce the analysis from the original inputs.

## Data and Measurement

For each dataset, record its citation, version or retrieval date, access terms, and the fields used. Keep source files intact and make cleaning steps reproducible. Define the timing measure and its reference point before comparing estimates. Daily activity onset, nest building, and waking are distinct observations. Separate variation among animals from variation across days within an animal, and qualify conclusions by the conditions in which the animals were measured.

## Running and Checking Analyses

There is no build command, test suite, or established language yet. When adding an analysis, document its exact run command, dependencies, and expected outputs. Use descriptive filenames such as `estimate-onset-repeatability.R` if using R, follow the conventions of the chosen language, and use paths relative to the project root. Check identifiers, repeated observations, missing values, and time units before fitting a model. Report exclusions so readers can reproduce the analysis sample.

## Reviewing Changes

This seed has no Git history yet. When version control is established, use focused commits and describe any changes to data selection, measurement, or conclusions in the review. Include the commands and results needed to verify the change. Use Roughdraft for substantial plans and prose reviews under the workspace guidelines.
