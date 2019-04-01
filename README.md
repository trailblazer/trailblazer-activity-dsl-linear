# Trailblazer-Activity-DSL-Linear

_The popular Railway/Fasttrack DSL for building activities._


# Overview

This gem allows creating activities by leveraging a handy DSL. Built-in are the strategies `Path`, the popular `Railway` and `FastTrack`. The latter is used for `Trailblazer::Operation`.

Note that you don't need to use the DSL. You can simply create a InIm structure yourself, or use our online editor.

Full documentation can be found here: trailblazer.to/2.1/#dsl-linear

## Normalizer

Normalizers are itself linear activities (or "pipelines") that compute all options necessary for `DSL.insert_task`.
For example, `FailFast.normalizer` will process your options such as `fast_track: true` and add necessary connections and outputs.

The different "step types" (think of `step`, `fail`, and `pass`) are again implemented as different normalizers that "inherit" generic steps.


`:sequence_insert`
`:connections` are callables to find the connecting tasks
