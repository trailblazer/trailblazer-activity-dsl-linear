require "test_helper"

class DocsPatchingTest < Minitest::Spec
  it do
    module Memo
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

    signal, (ctx, _) = Trailblazer::Developer.wtf?(Memo::Destroy, [{seq: []}])

    ctx.inspect.must_equal %{{:seq=>[:policy, :find_model, :delete_model, :rm_images, :rm_uploads]}}
  end
end
