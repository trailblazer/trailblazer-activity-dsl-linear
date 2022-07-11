module Trailblazer
  class Activity
    module DSL
      module Linear
        # Data Structures used in the DSL. They're mostly created from helpers
        # and then get processed in the normalizer.
        #
        # @private
        OutputSemantic = Struct.new(:value)
        Id             = Struct.new(:value)
        Track          = Struct.new(:color, :adds, :options)
        Extension      = Struct.new(:callable) do
          def call(*args, &block)
            callable.(*args, &block)
          end
        end
        PathBranch       = Struct.new(:options)
        DataVariableName = Class.new

        # Shortcut functions for the DSL.
        # Those are included in {Strategy} so they're available to all Strategy users such
        # as {Railway} or {Operation}.
        module Helper
          # This is the namespace container for {Contract::}, {Policy::} and friends.
          module Constants
          end

          #   Output( Left, :failure )
          #   Output( :failure ) #=> Output::Semantic
          def Output(signal, semantic=nil)
            return OutputSemantic.new(signal) if semantic.nil?

            Activity.Output(signal, semantic)
          end

          def End(semantic)
            Activity.End(semantic)
          end

          def end_id(semantic:, **)
            "End.#{semantic}" # TODO: use everywhere
          end

          def Track(color, wrap_around: false)
            Track.new(color, [], wrap_around: wrap_around).freeze
          end

          def Id(id)
            Id.new(id).freeze
          end

          def Path(**options, &block)
            options = options.merge(block: block) if block_given?

            Linear::PathBranch.new(options) # picked up by normalizer.
          end

          # Computes the {:outputs} options for {activity}.
          def Subprocess(activity, patch: {})
            activity = Patch.customize(activity, options: patch)

            {
              task:    activity,
              outputs: Hash[activity.to_h[:outputs].collect { |output| [output.semantic, output] }]
            }
          end

          def In(**kws);     VariableMapping::DSL::In(**kws); end
          def Out(**kws);    VariableMapping::DSL::Out(**kws); end
          def Inject(**kws); VariableMapping::DSL::Inject(**kws); end

          def DataVariable
            DataVariableName.new
          end
        end # Helper
      end # Linear
    end # DSL
  end # Activity
end
