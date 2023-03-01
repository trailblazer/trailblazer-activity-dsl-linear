require "test_helper"

class TerminusTest < Minitest::Spec
  it "#terminus allows adding end events" do
    activity = Class.new(Activity::Railway) do
      terminus :not_found #@ id, magnetic_to computed automatically

      terminus :found,    magnetic_to: :shipment_found #@ id computed automatically
      terminus :found_it, magnetic_to: :shipment_found_it, id: "End.found_it!" #@ all options provided explicitly
    end

    #@ IDs are automatically computed in case of no {:id} option.
    assert_equal Trailblazer::Activity::Introspect.Nodes(activity, id: "End.not_found").data.inspect, %{{:id=>\"End.not_found\", :dsl_track=>:terminus, :extensions=>nil, :stop_event=>true, :semantic=>:not_found}}
    assert_equal Trailblazer::Activity::Introspect.Nodes(activity, id: "End.found_it!").data.inspect, %{{:id=>\"End.found_it!\", :dsl_track=>:terminus, :extensions=>nil, :stop_event=>true, :semantic=>:found_it}}
    assert_equal Trailblazer::Activity::Introspect.Nodes(activity, id: "End.found").data.inspect, %{{:id=>\"End.found\", :dsl_track=>:terminus, :extensions=>nil, :stop_event=>true, :semantic=>:found}}

    with_steps = Class.new(activity) do
      step :a,
        Output(:failure) => Track(:not_found),
        Output(:success) => Track(:shipment_found)
    end

    assert_process_for activity, :success, :found_it, :found, :not_found, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => #<End/:success>
#<End/:success>

#<End/:found_it>

#<End/:found>

#<End/:not_found>

#<End/:failure>
}

    assert_process_for with_steps, :success, :found_it, :found, :not_found, :failure, %{
#<Start/:default>
 {Trailblazer::Activity::Right} => <*a>
<*a>
 {Trailblazer::Activity::Left} => #<End/:not_found>
 {Trailblazer::Activity::Right} => #<End/:found>
#<End/:success>

#<End/:found_it>

#<End/:found>

#<End/:not_found>

#<End/:failure>
}
  end

  it "#terminus accepts {:task}" do
    my_terminus_class = Class.new(Trailblazer::Activity::End)

    activity = Class.new(Activity::Railway) do
      terminus :not_sure, task: my_terminus_class.new(semantic: :tell_me)
    end

    #@ {:task} allows passing {End} instance
    assert_equal Trailblazer::Activity::Introspect.Nodes(activity, id: "End.tell_me").data.inspect, %{{:id=>\"End.tell_me\", :dsl_track=>:terminus, :extensions=>nil, :stop_event=>true, :semantic=>:tell_me}}
    assert_equal Trailblazer::Activity::Introspect.Nodes(activity, id: "End.tell_me").task.class, my_terminus_class
  end
end
