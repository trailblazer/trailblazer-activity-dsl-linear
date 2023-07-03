require "test_helper"

class DocsFastTrackFailFastTest < Minitest::Spec
  Song = Struct.new(:id)

  module Song::Activity
    class Create < Trailblazer::Activity::FastTrack
      step :validate,
        fail_fast: true
      step :save
      #~meths
      include T.def_steps(:validate, :save)
      #~meths end
    end
  end

  it do
    assert_invoke Song::Activity::Create, seq: "[:validate, :save]"
    assert_invoke Song::Activity::Create, seq: "[:validate]", terminus: :fail_fast, validate: false
  end
end

class DocsFailFastWithRailwaySubprocessTest < Minitest::Spec
  Song = Struct.new(:id)

  module Song::Activity
    class Validate < Trailblazer::Activity::Railway
      step :validate
      include T.def_steps(:validate)
    end
  end

  module Song::Activity
    class Create < Trailblazer::Activity::FastTrack
      step Subprocess(Validate), fail_fast: true
      step :save
      #~meths
      include T.def_steps(:save)
      #~meths end
    end  
  end

  it do
    assert_invoke Song::Activity::Create, seq: "[:validate, :save]"
    assert_invoke Song::Activity::Create, seq: "[:validate]", terminus: :fail_fast, validate: false
  end
end

class DocsPassFastWithRailwaySubprocessTest < Minitest::Spec
  Song = Struct.new(:id)

  module Song::Activity
    class Validate < Trailblazer::Activity::Railway
      step :validate
      include T.def_steps(:validate)
    end
  end

  module Song::Activity
    class Create < Trailblazer::Activity::FastTrack
      step Subprocess(Validate), pass_fast: true
      step :save
      #~meths
      include T.def_steps(:save)
      #~meths end
    end
  end

  it do
    assert_invoke Song::Activity::Create, seq: "[:validate]", terminus: :pass_fast
    assert_invoke Song::Activity::Create, seq: "[:validate]", terminus: :failure, validate: false
  end
end
