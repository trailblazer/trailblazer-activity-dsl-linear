require "test_helper"
=begin
:before, :after, :replace, :delete, :group, :id
=end
module A
  class Id_DocSeqOptionsTest < Minitest::Spec
    Memo = Struct.new(:text)

    #:id
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        step :save, id: :save_the_world
        step :notify
        #~id-methods
        include T.def_steps(:validate, :save, :notify)
        #~id-methods end
      end
    end
    #:id end

    it ":id shows up in introspect" do
=begin
      output =
        #:id-inspect
        Trailblazer::Developer.railway(Memo::Activity::Create)
        #=> [>create_model,>validate,>save_the_world]
        #:id-inspect end
=end

      assert_process Memo::Activity::Create, :success, :failure, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*save>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*notify>
<*notify>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
)
      assert Activity::Introspect.Nodes(Memo::Activity::Create, id: :save_the_world)
      #:id-introspect
      puts Activity::Introspect.Nodes(Memo::Activity::Create, id: :save_the_world)
      #=> #<struct Trailblazer::Activity::Schema::Nodes::Attributes id=:save_the_world, ...>
      #:id-introspect end
    end
  end
end

module B
  class Delete_DocsSequenceOptionsTest < Minitest::Spec
    Memo = A::Id_DocSeqOptionsTest::Memo

    it ":delete removes step" do
      #:delete
      module Memo::Activity
        class Admin < Create
          step nil, delete: :validate
        end
      end
      #:delete end

=begin
     output =
      #:delete-inspect
      Trailblazer::Developer.railway(Memo::Create::Admin)
      #=> [>create_model,>save_the_world]
      #:delete-inspect end
=end

      assert_process Memo::Activity::Admin, :success, :failure, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*save>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*notify>
<*notify>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
)
    end
  end
end

module C
  class Before_DocsSequenceOptionsTest < Minitest::Spec
    it ":before" do
      Memo = A::Id_DocSeqOptionsTest::Memo

      #:before
      module Memo::Activity
        class Authorized < Memo::Activity::Create
          step :policy, before: :validate
          #~before-methods
          include T.def_steps(:policy)
          #~before-methods end
        end
      end
      #:before end

      assert_process Memo::Activity::Authorized, :success, :failure, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*policy>
<*policy>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*save>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*notify>
<*notify>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
)
    end

  end
end

module D
  class After_DocsSequenceOptionsTest < Minitest::Spec
    it ":before" do
      Memo = Class.new(A::Id_DocSeqOptionsTest::Memo)
      Memo::Activity = Module.new
      Memo::Activity::Create = Class.new(A::Id_DocSeqOptionsTest::Memo::Activity::Create)

      #:after
      module Memo::Activity
        class Authorized < Memo::Activity::Create
          step :policy, after: :validate
          #~before-methods
          include T.def_steps(:policy)
          #~before-methods end
        end
      end
      #:after end


    assert_process Memo::Activity::Authorized, :success, :failure, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*policy>
<*policy>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*save>
<*save>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*notify>
<*notify>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
)
    end
  end
end

module E
  class Replace_DocsSequenceOptionsTest < Minitest::Spec
    Memo = Class.new
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        step :save
        step :notify
        #~id-methods
        include T.def_steps(:validate, :save, :notify)
        #~id-methods end
      end
    end

    it "{:replace} automatically assigns ID" do
      #:replace
      module Memo::Activity
        class Update < Create
          step :update, replace: :save
          #~replace-methods
          include T.def_steps(:update)
          #~replace-methods end
        end

      end
      #:replace end

      assert Activity::Introspect.Nodes(Memo::Activity::Update, id: :update)

      assert_process Memo::Activity::Update, :success, :failure, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*update>
<*update>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*notify>
<*notify>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
)
    end
  end
end

#@ {#replace} with {:id}
module E_2
  class Replace_With_ID_DocsSequenceOptionsTest < Minitest::Spec
    Memo = Class.new
    module Memo::Activity
      class Create < Trailblazer::Activity::Railway
        step :validate
        step :save
        step :notify
        #~id-methods
        include T.def_steps(:validate, :save, :notify)
        #~id-methods end
      end
    end

    it "{:replace} automatically assigns ID" do
      #:replace
      module Memo::Activity
        class Update < Create
          step :update, replace: :save, id: :update_memo
          #~replace-methods
          include T.def_steps(:update)
          #~replace-methods end
        end

      end
      #:replace end

      assert Activity::Introspect.Nodes(Memo::Activity::Update, id: :update_memo)

      assert_process Memo::Activity::Update, :success, :failure, %(
#<Start/:default>
 {Trailblazer::Activity::Right} => <*validate>
<*validate>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*update>
<*update>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => <*notify>
<*notify>
 {Trailblazer::Activity::Left} => #<End/:failure>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:failure>
)
    end
  end
end
