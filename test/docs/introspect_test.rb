require "test_helper"

class DocsIntrospectTest < Minitest::Spec
  Song = Module.new

  module Song::Activity
    class Save < Trailblazer::Activity::Railway
      step :save
    end
  end

  #:create
  module Song::Activity
    class Create < Trailblazer::Activity::Railway
      step :validate
      step Subprocess(Save),
        id: :save
    end
  end
  #:create end

  it do
    #:nodes
    attrs = Trailblazer::Activity::Introspect.Nodes(Song::Activity::Create, id: :validate)
    #:nodes end
=begin
    #:nodes-puts
    puts attrs.id   #=> :validate
    puts attrs.task #=> #<Trailblazer::Activity::TaskBuilder::Task user_proc=validate>
    puts attrs.data[:extensions] => []
    #:nodes-puts end
=end

    assert_equal attrs.id, :validate
  end

  it "with {:task}" do
    #:nodes-task
    attrs = Trailblazer::Activity::Introspect.Nodes(Song::Activity::Create, task: Song::Activity::Save)
    attrs.id #=> :save
    #:nodes-task end

    assert_equal attrs.id, :save
  end
end
