## Normalizer

Normalizers are itself linear activities (or "pipelines") that compute all options necessary for `DSL.insert_task`.
For example, `FailFast.normalizer` will process your options such as `fast_track: true` and add necessary connections and outputs.

The different "step types" (think of `step`, `fail`, and `pass`) are again implemented as different normalizers that "inherit" generic steps.
