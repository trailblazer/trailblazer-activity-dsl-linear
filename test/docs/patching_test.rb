require "test_helper"

#@ Test {Operation.patch}
class PatchDSLTest < Minitest::Spec
  module Song; end

  module Song::Operation
    #:delete_assets
    class DeleteAssets < Trailblazer::Activity::Railway
      step :rm_images
      step :rm_uploads
      #~meths
      include T.def_steps(:rm_images, :rm_uploads)
      #~meths end
    end
    #:delete_assets end

    #:delete
    class Delete < Trailblazer::Activity::Railway
      step :delete_model
      step Subprocess(DeleteAssets), id: :delete_assets
      #~meths
      include T.def_steps(:delete_model)
      #~meths end
    end
    #:delete end
  end

  module Song::Operation
    class Destroy < Trailblazer::Activity::Railway
      #~meths
      include T.def_steps(:policy, :find_model)
      #~meths end

      step :policy
      step :find_model
      step Subprocess(Delete), id: :delete
    end
  end

  it "provides the {#patch} function" do
    module Song::Operation
      #:patch_function
      class Erase < Destroy # we're inheriting from Song::Operation::Destroy
        #~meths
        module A
        #~meths end
        def self.tidy_storage(ctx, **)
          # delete files from your amazing cloud
        end
        #~meths
        end
        extend T.def_steps(:tidy_storage)
        #~meths end
        # These steps are inherited:
        # step :policy
        # step :find_model
        # step Subprocess(Delete), id: :delete

        extend Trailblazer::Activity::DSL::Linear::Patch::DSL

        # Note the path you pass to #patch.
        patch(:delete, :delete_assets) {
          step Erase.method(:tidy_storage), after: :rm_images
        }
      end
      #:patch_function end
    end

    # Trailblazer::Developer.wtf?(Song::Operation::Erase, [{seq: []}])
    assert_invoke Song::Operation::Destroy, seq: %{[:policy, :find_model, :delete_model, :rm_images, :rm_uploads]}
    assert_invoke Song::Operation::Erase, seq: %{[:policy, :find_model, :delete_model, :rm_images, :tidy_storage, :rm_uploads]}
  end
end

#@ Test Subprocess(..., patch: ...)
# DISCUSS: maybe we can remove the {:patch} option at some point.
class DocsSubprocessPatchTest < Minitest::Spec
  it do
    Delete = PatchDSLTest::Song::Operation::Delete

    module Memo
      #:destroy
      class Destroy < Trailblazer::Activity::Railway
        def self.tidy_storage(ctx, **)
          # delete files from your amazing cloud
          true
        end
        #~meths
        include T.def_steps(:policy, :find_model)
        #~meths end
        step :policy
        step :find_model
        step Subprocess(Delete,
          patch: {
            [:delete_assets] => -> { step Destroy.method(:tidy_storage), before: :rm_uploads }
          }
        )
      end
      #:destroy end
    end

    assert_invoke Memo::Destroy, seq: %{[:policy, :find_model, :delete_model, :rm_images, :rm_uploads]}
  end

  it do
    Delete = PatchDSLTest::Song::Operation::Delete

    module Asset
      class Destroy < Trailblazer::Activity::Railway
        extend T.def_steps(:tidy_storage)

        #:patch_self
        step Subprocess(
          Delete,
          patch: -> { step Destroy.method(:tidy_storage), before: :delete_model }
        ), id: :delete
        #:patch_self end
      end
    end

    assert_invoke Asset::Destroy, seq: %{[:tidy_storage, :delete_model, :rm_images, :rm_uploads]}
  end
end



