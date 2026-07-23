module Trailblazer
  class Activity
    module DSL
      module Feature
        module OutputTuples
          module Helper
            module_function

            # Logic related to {Output() => ...}, called "Wiring API".
            # def Output(semantic, is_generic: true)
            #   Output::Semantic.new(semantic, is_generic) # FIXME: do we still need {is_generic}?
            # end
# TODO: deprecate signal, semantic, make it Output(:semantic, signal: Bla)
            def Output(semantic, **options)
              return Output::CustomSignal.new(semantic, options[:signal]) if options.key?(:signal)

              Output::Semantic.new(semantic)
            end

            # def End(semantic)
            #   End.new(semantic).freeze
            # end

            # def end_id(semantic:, **)
            #   "End.#{semantic}" # TODO: use everywhere
            # end

            def Track(color, wrap_around: false)
              Target::Track.new(color, [], wrap_around: wrap_around).freeze
            end

            # def Id(id)
            #   Id.new(id).freeze
            # end
          end # Helper
        end
      end
    end
  end
end
