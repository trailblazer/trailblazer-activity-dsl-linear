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
