require "test_helper"

class WiringApiDocsTest < Minitest::Spec
# {#terminus} 1.0
  module A
    class Payment
      module Operation
      end
    end

    #:terminus
    module Payment::Operation
      class Create < Trailblazer::Activity::Railway
        step :find_provider

        terminus :provider_invalid # , id: "End.provider_invalid", magnetic_to: :provider_invalid
        #~meths
        include T.def_steps(:find_provider)
        #~meths end
      end
    end
    #:terminus end
    # @diagram wiring-terminus
  end

  #@ we cannot route to {End.provider_invalid}
  it { assert_invoke A::Payment::Operation::Create, seq: "[:find_provider]" }
  it { assert_invoke A::Payment::Operation::Create, find_provider: false, seq: "[:find_provider]", terminus: :failure }

# {#terminus} 1.1
  module B
    class Payment
      module Operation
      end
    end

    #:terminus-track
    module Payment::Operation
      class Create < Trailblazer::Activity::Railway
        step :find_provider,
          # connect {failure} to the next element that is magnetic_to {:provider_invalid}.
          Output(:failure) => Track(:provider_invalid)

        terminus :provider_invalid
        #~meths
        include T.def_steps(:find_provider)
        #~meths end
      end
    end
    #:terminus-track end
  end

  #@ failure routes to {End.provider_invalid}
  it { assert_invoke B::Payment::Operation::Create, seq: "[:find_provider]" }
  it { assert_invoke B::Payment::Operation::Create, find_provider: false, seq: "[:find_provider]", terminus: :provider_invalid }

  it do
    signal, (ctx, _) = B::Payment::Operation::Create.([{find_provider: false, seq: []}, {}])
    assert_equal signal.to_h[:semantic], :provider_invalid
=begin
    #:terminus-invalid
    signal, (ctx, _) = Payment::Operation::Create.(provider: "bla-unknown")
    puts signal.to_h[:semantic] #=> :provider_invalid
    #:terminus-invalid end
=end

  end
end
