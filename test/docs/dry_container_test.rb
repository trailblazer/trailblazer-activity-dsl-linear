# require "test_helper"
# require "dry-container"

# class DryContainerTest < Minitest::Spec
#   let(:container) {
#     container = Dry::Container.new
#     container.namespace('song') do
#       namespace('create') do
#         register('model.class') { Song }  # note how dependencies are namespaced depending on their domain.
#         register('contract') { Song::Form }
#       end
#     end
#     container.register('db') { String }
#   }

#   Song = Struct.new(:id)

#   class Song
#     Form = Struct.new(:valid?)
#   end



#   it "what" do
#     # res = container.resolve('repositories.checkout.orders')
#     # puts res.inspect

#     class Validate < Trailblazer::Activity::Railway
#       step :contract

#       def contract(ctx, model:, **)
#         ctx[:contract] = [ctx["contract"], model]
#       end
#     end

#     class Song
#       class Create < Trailblazer::Activity::Railway
#         step :model
#         step Subprocess(Validate)
#         step :save

#         def model(ctx, **)
#           ctx[:model] = ctx["model.class"].new
#         end

#         def save(ctx, model:, **)
#           ctx[:save] = ctx["db"].new
#         end
#       end
#     end # Song

#     class NamespacedContainer
#       def initialize(container, ctx, namespace)
#         @container = container
#         @namespace = namespace
#         @ctx = ctx
#       end

#       def [](key)
#         namespaced_key = "#{@namespace}.#{key}"
#         puts "@@@@@ #{namespaced_key.inspect}"


# # DISCUSS: do we want this prio check?
#         @ctx[key] or @container.key?(namespaced_key) ? @container[namespaced_key] : @container[key] # FIXME: nil, etc
#       end

#       def to_hash
#         @ctx.to_hash # we can't convert @container variables to kwargs anyway
#       end

#       def []=(name, value)
#         @ctx[name] = value
#       end
#     end

#     ctx              = Trailblazer::Context({params: {id: 1}}, {})
#     create_container = NamespacedContainer.new(container, ctx, "song.create")


#     # raise ctx["song.create.model.class"].inspect
#     puts create_container[:params].inspect
#     puts create_container["model.class"].inspect

#     signal, (ctx, _) = Trailblazer::Activity::TaskWrap.invoke(Song::Create, [create_container, {}])

#     ctx.to_hash.inspect.must_equal %{{:params=>{:id=>1}, :model=>#<struct DryContainerTest::Song id=nil>, :contract=>[DryContainerTest::Song::Form, #<struct DryContainerTest::Song id=nil>], :save=>""}}
#   end
# end
