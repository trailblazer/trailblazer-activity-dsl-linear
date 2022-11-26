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
          # @param :strict If true, all outputs of {activity} will be wired to the track named after the
          #   output's semantic.
          def Subprocess(activity, patch: {}, strict: false)
            activity = Linear.Patch(activity, patch)

            outputs  = activity.to_h[:outputs]
            options  = {}

            if strict
              options.merge!(
                outputs.collect { |output| [Output(output.semantic), Track(output.semantic)] }.to_h
              )
            end

            {
              task:    activity,
              outputs: outputs.collect { |output| [output.semantic, output] }.to_h,
            }.
            merge(options)
          end

          def In(**kws);     VariableMapping::DSL::In(**kws); end
          def Out(**kws);    VariableMapping::DSL::Out(**kws); end
          def Inject(*args, **kws); VariableMapping::DSL::Inject(*args, **kws); end

          def DataVariable
            DataVariableName.new
          end
        end # Helper
      end # Linear
    end # DSL
  end # Activity
end
