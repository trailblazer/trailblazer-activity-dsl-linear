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
