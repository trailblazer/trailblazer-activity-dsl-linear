require "test_helper"
=begin
:before, :after, :replace, :delete, :group, :id
=end
class DocSeqOptionsTest < Minitest::Spec
  module Id
    class Memo < Struct.new(:text)
    end

    #:id
    class Memo::Create < Trailblazer::Activity::Path
      step :create_model
      step :validate
      step :save, id: :save_the_world
      #~id-methods
      def create_model(options, **)
      end

      def validate(options, **)
      end

      def save(options, **)
      end
      #~id-methods end
    end
    #:id end
  end

  it ":id shows up in introspect" do
    Memo = Id::Memo
    output =
      #:id-inspect
      Trailblazer::Developer.railway(Memo::Create)
      #=> [>create_model,>validate,>save_the_world]
      #:id-inspect end

    output.must_equal %{[>create_model,>validate,>save_the_world]}
  end

  it ":delete removes step" do
    Memo = Id::Memo

    #:delete
    class Memo::Create::Admin < Memo::Create
      step nil, delete: :validate
    end
    #:delete end

     output =
      #:delete-inspect
      Trailblazer::Developer.railway(Memo::Create::Admin)
      #=> [>create_model,>save_the_world]
      #:delete-inspect end

    output.must_equal %{[>create_model,>save_the_world]}
  end


  it ":before" do
    Memo = Id::Memo

    #:before
    class Memo::Create::Authorized < Memo::Create
      step :policy, before: :create_model
      #~before-methods
      def policy(options, **)
      end
      #~before-methods end
    end
    #:before end

    output =
      #:before-inspect
      Trailblazer::Developer.railway(Memo::Create::Authorized)
      #=> [>policy,>create_model,>validate,>save_the_world]
      #:before-inspect end

    output.must_equal %{[>policy,>create_model,>validate,>save_the_world]}
  end

  it ":after" do
    Memo = Id::Memo

    #:after
    class Memo::Create::Logging < Memo::Create
      step :logger, after: :validate
      #~after-methods
      def logger(options, **)
      end
      #~after-methods end
    end
    #:after end

    output =
      #:after-inspect
      Trailblazer::Developer.railway(Memo::Create::Logging)
      #=> [>create_model,>validate,>logger,>save_the_world]
      #:after-inspect end

    output.must_equal %{[>create_model,>validate,>logger,>save_the_world]}
  end

  it ":replace" do
    Memo = Id::Memo

    #:replace
    class Memo::Update < Memo::Create
      step :find_model, replace: :create_model, id: :update_memo
      #~replace-methods
      def find_model(options, **)
      end
      #~replace-methods end
    end
    #:replace end

    output =
      #:replace-inspect
      Trailblazer::Developer.railway(Memo::Update)
      #=> [>update_memo,>validate,>save_the_world]
      #:replace-inspect end

    output.must_equal %{[>update_memo,>validate,>save_the_world]}
  end
end
