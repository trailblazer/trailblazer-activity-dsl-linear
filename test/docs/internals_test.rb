require "test_helper"

class DocsInternalsDataVariableTest < Minitest::Spec
  Song = Module.new

  #:data_variable
  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      step :find_model,
        model_class: Song,
        DataVariable() => :model_class # mark :model_class as data-worthy.
      #~meths
      include T.def_steps(:find_model)
      #~meths end
    end
  end
  #:data_variable end

  it "provides DataVariable() to store in {row.data}" do
    #:data_variable_read
    Song::Activity::Create
      .to_h[:nodes][1][:data][:model_class] #=> Song
    #:data_variable_read end

    assert_equal Song::Activity::Create.to_h[:nodes][1][:data][:model_class], Song
  end
end
