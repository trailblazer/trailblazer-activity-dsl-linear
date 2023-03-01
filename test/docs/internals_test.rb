require "test_helper"

class DocsInternalsDataVariableTest < Minitest::Spec
  Song = Module.new

  #:data_variable
  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      step :create_model,
        model_class: Song,
        DataVariable() => :model_class # mark :model_class as data-worthy.
      #~meths
      include T.def_steps(:create_model)
      #~meths end
    end
  end
  #:data_variable end

  it "provides DataVariable() to store in {row.data}" do
    #:data_variable_read
    Trailblazer::Activity::Introspect.Nodes(Song::Activity::Create, id: :create_model)
      .data[:model_class] #=> Song
    #:data_variable_read end

    assert_equal Trailblazer::Activity::Introspect.Nodes(Song::Activity::Create, id: :create_model).data[:model_class], Song
  end
end

class DocsInternalsNormalizerExtendTest < Minitest::Spec
  Song = Module.new

  #:upcase
  module MyNormalizer
    def self.upcase_id(ctx, upcase_id: nil, id:, **)
      return unless upcase_id

      ctx[:id] = id.to_s.upcase
    end
  end
  #:upcase end

  #:normalizer-extend
  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      Trailblazer::Activity::DSL::Linear::Normalizer.extend!(
        Song::Activity::Create,
        :step
      ) do |normalizer|
        Trailblazer::Activity::DSL::Linear::Normalizer.prepend_to(
          normalizer,
          "activity.default_outputs", # few steps after "activity.normalize_id"
          {
            "my.upcase_id" => Trailblazer::Activity::DSL::Linear::Normalizer.Task(MyNormalizer.method(:upcase_id)),
          }
        )
      end

      step :create_model, upcase_id: true
      step :validate
      pass :save,         upcase_id: true # not applied!
      #~meths
      include T.def_steps(:create_model, :validate, :save)
      #~meths end
    end
  end
  #:normalizer-extend end

  it "provides" do
    Trailblazer::Activity::Introspect.Nodes(Song::Activity::Create, id: "CREATE_MODEL") #=> #<Node id="CREATE_MODEL"...>

    # Trailblazer::Developer.wtf?(Song::Activity::Create, [{seq: []}]) # FIXME: what were we testing here?

    assert Trailblazer::Activity::Introspect.Nodes(Song::Activity::Create, id: "CREATE_MODEL")
    assert Trailblazer::Activity::Introspect.Nodes(Song::Activity::Create, id: :validate)
    assert Trailblazer::Activity::Introspect.Nodes(Song::Activity::Create, id: :save)
  end
end

class DocsInternalsRecordSymbolOptionTest < Minitest::Spec
  Song = Module.new

  #:record-normalizer
  module MyNormalizer
    #~meths
    def self.upcase_id(ctx, upcase_id: false, id:, **)
      return unless upcase_id

      ctx[:id] = id.to_s.upcase
    end
    #~meths end
    def self.record_upcase_id_flag(ctx, non_symbol_options:, upcase_id: nil, **)
      ctx.merge!(
        non_symbol_options: non_symbol_options.merge(
          Trailblazer::Activity::DSL::Linear::Normalizer::Inherit.Record(
            {upcase_id: upcase_id},   # what do you want to record?
            type: :upcase_id_feature, # categorize the recorded data.
            non_symbol_options: false # this is a real :symbol option.
          )
        )
      )
    end
  end
  #:record-normalizer end

  #:record
  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      #:record-extend
      Trailblazer::Activity::DSL::Linear::Normalizer.extend!(Song::Activity::Create, :step) do |normalizer|
        Trailblazer::Activity::DSL::Linear::Normalizer.prepend_to(
          normalizer,
          "activity.default_outputs", # step after "activity.normalize_id"
          {
            "my.upcase_id"             => Trailblazer::Activity::DSL::Linear::Normalizer.Task(MyNormalizer.method(:upcase_id)),
            "my.record_upcase_id_flag" => Trailblazer::Activity::DSL::Linear::Normalizer.Task(MyNormalizer.method(:record_upcase_id_flag)),
          }
        )
      end
      #:record-extend end

      step :create_model,
        upcase_id: true
      step :validate
      #~meths
      include T.def_steps(:create_model, :validate)
      #~meths end
    end
  end


  module Song::Activity
    class Update < Create
      step :find_model,
        inherit: true, # this adds {, upcase_id: true}
        replace: "CREATE_MODEL"
    end
  end
  #:record end

  it "provides" do
    assert_equal Activity::Introspect.Nodes(Song::Activity::Create).values[1][:data][:id], "CREATE_MODEL"
    assert_equal Activity::Introspect.Nodes(Song::Activity::Update).values[1][:data][:id], "CREATE_MODEL" # FIXME: this test really sucks! it doesn't test anything.
  end
end

class AddsDocsTest < Minitest::Spec
  module Song
  end

  module Song::Activity
    class Create < Trailblazer::Activity::Railway
    end
  end

  it do
    #:adds-pipe
    row = Trailblazer::Activity::TaskWrap::Pipeline::Row[
      "business.task",  # id, required as per ADDS interface
      Object            # task
    ]

    pipeline = [row] # pipe contains one item.
    #:adds-pipe end

    #:adds
    adds = Trailblazer::Activity::Adds::FriendlyInterface.adds_for(
      [
        [Song::Activity::Create, id: "my.create", append: "business.task"],
      ]
    )
    extended_pipeline = Trailblazer::Activity::Adds.apply_adds(pipeline, adds)
    # => [row, #<row with Song::Activity::Create>]
    #:adds end

    assert_equal extended_pipeline.inspect, %{[["business.task", Object], ["my.create", AddsDocsTest::Song::Activity::Create]]}
  end
end
