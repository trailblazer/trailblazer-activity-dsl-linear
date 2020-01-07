require "test_helper"

class DocsPatchingTest < Minitest::Spec
  it do
    module Memo
      class DeleteAssets < Trailblazer::Activity::Railway
        step :remove_images
        step :remove_uploads
        #~meths
        include T.def_steps(:remove_images, :remove_uploads)
        #~meths end
      end

      class Delete < Trailblazer::Activity::Railway
        step :delete_model
        step Subprocess(DeleteAssets), id: :delete_assets
        #~meths
        include T.def_steps(:delete_model)
        #~meths end
      end

      class Destroy < Trailblazer::Activity::Railway
        def self.tidy_storage(ctx, **)
          true
        end
        #~meths
        include T.def_steps(:policy, :find_model)
        #~meths end

        step :policy
        step :find_model
        step Subprocess(Delete,
          [:delete_assets], -> { step Destroy.method(:tidy_storage), before: :remove_uploads }
        )
      end
    end

    signal, (ctx, _) = Trailblazer::Developer.wtf?(Memo::Destroy, [{seq: []}])

    ctx.inspect.must_equal %{{:seq=>[:policy, :find_model, :delete_model, :remove_images, :remove_uploads]}}
  end
end
