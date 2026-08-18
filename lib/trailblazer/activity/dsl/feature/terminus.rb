module Trailblazer
  class Activity
    module DSL
      module Feature
        module Terminus
          def terminus(semantic, terminus_class: Activity::Terminus::Success)
            step **DSL.options_for_terminus_step(semantic: semantic, terminus_class: terminus_class)
          end
        end
      end # Feature
    end
  end
end
