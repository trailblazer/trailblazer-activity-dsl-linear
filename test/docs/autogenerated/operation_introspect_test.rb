require "test_helper"
module Autogenerated
class DocsIntrospectTest < Minitest::Spec
  Song = Module.new

  module Song::Operation
    class Save < Trailblazer::Operation
      step :save
    end
  end

  #:create
  module Song::Operation
    class Create < Trailblazer::Operation
      step :validate
      step Subprocess(Save),
        id: :save
    end
  end
  #:create end

  it do
    #:nodes
    attrs = Trailblazer::Operation::Introspect.Nodes(Song::Operation::Create, id: :validate)
    #:nodes end
=begin
    #:nodes-puts
    puts attrs.id   #=> :validate
    puts attrs.task #=> #<Trailblazer::Operation::TaskBuilder::Task user_proc=validate>
    puts attrs.data[:extensions] => []
    #:nodes-puts end
=end

    assert_equal attrs.id, :validate
  end

  it "with {:task}" do
    #:nodes-task
    attrs = Trailblazer::Operation::Introspect.Nodes(Song::Operation::Create, task: Song::Operation::Save)
    attrs.id #=> :save
    #:nodes-task end

    assert_equal attrs.id, :save
  end
end
end