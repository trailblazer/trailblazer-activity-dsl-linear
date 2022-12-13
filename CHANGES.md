# 1.0.1

* Use `trailblazer-activity` 0.15.0.
* Remove `Path::DSL.OptionsForSequenceBuilder` and move concrete code to `Path::DSL.options_for_sequence_build`
  which returns a set:

  1. default termini instructions for the concrete strategy
  2. options specific for this strategy subclass.

  Everything else, such as merging user options, computing and adding termini, etc, now happens in
  `Strategy::DSL.OptionsForSequenceBuilder`.
* Adding `Subprocess(Create, strict: true)` to wire all outputs of `Create` automatically.
  Each output will be wired to its same named Track(semantic).
* Adding `Strategy(termini: )`
* For `output:` in combination with `:output_with_outer_ctx`, deprecate the second positional argument and make it
  the `:outer_ctx` keyword argument instead.
* Introduce `Linear.Patch` as the public entry point for patching activities.
* Remove `Runtime.initial_aggregate` step for the input and output pipelines which results in slightly better runtime performance and
  less code.

## Variable Mapping

* Simplify the architecture in `VariableMapping`, filters are now added directly into the `Pipeline`.
  Performance increase from 17k to 25k from 1.0.0 to this version.
* Introduce `Inject(:variable)` to supersede the version receiving a big mapping hash.
* Add Inject(:variable, override: true) to always write a variable to ctx, regardless of its presence.
* Fix a bug where `Inject()` would override `In()` filters even though the latter was added latest. This
  is fixed by treating both filter types equally and in the order they were added by the user (and the macro).

# 1.0.0

## Additions

* Introduce composable input/output filters with `In()`, `Out()` and `Inject()`. # FIXME: add link
* We no longer store arbitrary variables from `#step` calls in the sequence row's `data` field.
  Use the `DataVariable` helper to mark variables for storage in `data`.

  ```ruby
  step :find_model,
    model_class: Song,
    Trailblazer::Activity::DSL::Linear::Helper.DataVariable() => :model_class
  ```
* Add `Normalizer.extend!` to add steps to a particular normalizer. # FIXME: add link
* Add `Strategy.terminus` to add termini. # FIXME: add link
* The `Sequence` instance is now readable via `#to_h`: `Strategy.to_h[:sequence]`.
* In Normalizer, the `path.wirings` step is now named `activity.wirings`.

## Design

  * DSL logic: move as much as possible into the normalizer as it's much easier to understand and follow (and debug).
  * Each DSL method now directly invokes a normalizer pipeline that processes the user options and produces an ADDS structure.
* We now need `Sequence::Row` instances in `Sequence` to adhere to the Adds specification.
* Rename `Linear::State` to `Linear::Sequence::Builder`. This is now a stateless function, only.
  Sequence::Builder.()
* @state ?
* Remove `Strategy@activity` instance variable and move it to `@state[:activity]`.
* Much better file structuring.

## Internals

* Use `Trailblazer::Declarative::State` to maintain sequence and other fields. This makes inheritance consistent.
* Make `Strategy` a class. It makes constant management much simpler to understand.
* `Linear.end_id` now accepts keyword arguments (mainly, `:semantic`).
* `Strategy.apply_step_on_state!` is now an immutable `Sequence::Builder.update_sequence_for`.
* The `Railway.Path()` helper returns a `DSL::PathBranch` non-symbol that is then picked up and processed by the normalizer (exactly how we do it with `In()`, `Track()` etc.). Branching implementation is handled in `helper/path.rb`.
* Remove `State.update_options`. Use `@state.update!`.
* Remove `Helper.normalize`.
* Remove `Linear::DSL.insert_task`. The canonical way to add steps is using the ADDS interface going through a normalizer.
  That's why there's a normalizer for `end` (or "terminus") now for consistency.
* Remove `Helper::ClassMethods`, `Helper` is now the namespace to mix in your own functions (and ours, like `Output()`).
* Introduce `Helper::Constants` for namespaced macros such as `Policy::Pundit()`.

## Renaming

* Rename `Linear::State::Normalizer` to `Linear::Normalizer::Normalizers` as it represents a container for normalizers.
* Move `Linear::Insert` to `Activity::Adds::Insert` in the `trailblazer-activity` gem.
* Move `Linear::Search` to `Linear::Sequence::Search` and `Linear::Compiler` to `Linear::Sequence::Compiler`.
* `TaskWrap::Pipeline.prepend` is now `Linear::Normalizer.prepend_to`. To use the `:replace` option you can use `Linear::Normalizer.replace`.
* Move `Sequence::IndexError` to `Activity::Adds::IndexError` in the `trailblazer-activity` gem. Remove `IndexError#step_id`.
* Move DSL structures like `OutputSemantic` to `Linear` namespace.

# 0.5.0

* Introduce `:inject` option to pass-through injected variables and to default input variables.
* Remove `VariableMapping::Input::Scoped` as we're now using a separate `Pipeline` for input filtering.
* Massively simplify (and accelerate!) the `Normalizer` layer by using `TaskWrap::Pipeline` instead of `Activity::Path`. Note that you can alter a normalizer by using the `TaskWrap::Pipeline` API now.

# 0.4.3

* Limit `trailblazer-activity` dependency to `< 0.13.0`.

# 0.4.2

* Don't allow duplicate activities in Sequence (#47) :ghost:
* {:inherit} will only inherit the wirings supported in child activity (#48)

# 0.4.1

* Updrading `trailblazer-activity` to use shiny `trailblazer-option`.

# 0.4.0

* Support for Ruby 3.0.

# 0.3.5

* Retain custom wirings within subprocess while patching.

# 0.3.4

* Allow DSL helpers such as `End()` in `Path()`.
* Introduce `Path(..., before: )` option to insert all path member steps before a certain element.
* Allow `Path(..., connect_to: Track(..))`.

# 0.3.3

* Fix for registering `PassFast` & `FailFast` ends in `FastTrack` to fix circuit interface callables which emits those signals.

# 0.3.2

* Updrading `trailblazer-activity` version to utilise new `trailblazer-context` :drum:

# 0.3.1

* Fixes in circuit interface normalization when given task is a {Symbol}, consider additional {task} options (like {id}) and assign {task} symbol as an {id}.

# 0.3.0

* Fix circuit interface callable to make `step task: :instance_method` use circuit signature.

# 0.2.9

* The `Path()` helper, when used with `:end_task` will now automatically _append_ the end task (or terminus) to `End.success`.
  It used to be placed straight after the last path's element, which made it hard to later insert more steps into that very path.

# 0.2.8

* Add `:inherit` option so `step` can override an existing step while inheriting the original `:extensions` and `:connections` (which are the `Outputs`). This is great to customize "template" activities.
* Add `Track(:color, wrap_around: true)` option and `Search::WrapAround` so you can find a certain track color (or the beginning of a Path) even when the path was positioned before the actual step in the `Sequence`.
  Note that this feature is still experimental and might get removed.

# 0.2.7

* `Did you mean ?` suggestions on Linear::Sequence::IndexError.
* Introduce `Linear::Helper` module for strategy extensions in third-party gems.
* Convenient way to patch Subprocess itself using `patch` option.
* Allow multiple `Path()` macro per step.
* Small fix for defining instance methods as steps using circuit interface.

# 0.2.6

* Added `@fields` to `Linear::State` to save arbitrary data on the activity/strategy level.

# 0.2.5

* Patching now requires the [`:patch` option for `Subprocess`](http://2019.trailblazer.to/2.1/docs/activity.html#activity-dsl-options-patching
).

# 0.2.4

* Add a minimal API for patching nested activities. This allows customizing deeply-nested activities without changing the original.

# 0.2.3

* Add `Strategy::invoke` which is a short-cut to `TaskWrap.invoke`. It's available as class method in all three strategies.

# 0.2.2

* Fix requiring `trailblazer/activity.rb`.

# 0.2.1

* Update to `activity-0.9.1` and `context-0.2.0`.

# 0.2.0

* Update to `activity-0.9.0`.

# 0.1.9

* Fix `:extensions` merging that would override `:input` and `:output` if the `:extensions` option was given via the DSL.

# 0.1.8.

* Fix `Linear` namespacing and `require`s.

# 0.1.7

* Add `:connect_to` option to `Path()` to allow re-joining a branched activity.

# 0.1.6

* Use `activity-0.8.3`.

# 0.1.5

* Fix `:override` in combo with a missing `:id` and inheritance by moving the overriding after id generation.

# 0.1.4

* Provide default `:input` and `:output` if one of them is missing.

# 0.1.3

* Simplify `:override` handling by moving it to a later position.

# 0.1.2

* In `Strategy#to_h`, now provide a new member `:activity`, which is the actual `Activity` wrapped by the Path (or whatever) strategy.

# 0.1.1

* Raise when a step has a duplicate, already existing `:id` but is *not* a `:replace`.

# 0.1.0

* This code is extracted, refactored and heavy-metaly simplified from the original `trailblazer-activity` gem.
