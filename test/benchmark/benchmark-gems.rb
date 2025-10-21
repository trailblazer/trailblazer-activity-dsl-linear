# output = `bundle exec appraisal trb-2.1 ruby run_activity_for_benchmarking.rb`
# performance_2_1 = output.split("\n").last.match(/\@TRB\s+([\d\.]+)k/)[1].sub(".", "").to_i

output = `NEW_SIGNATURE=1 bundle exec appraisal trb-2.2 ruby run_activity_for_benchmarking.rb`
performance_2_2 = output.split("\n").last.match(/\@TRB\s+([\d\.]+k?)/)[1]#.sub(".", "").to_i

output = `bundle exec appraisal trb-2.1 ruby run_activity_for_benchmarking.rb`
performance_2_1 = output.split("\n").last.match(/\@TRB\s+([\d\.]+k?)/)[1]#.sub(".", "").to_i

puts "@@@@@ 2.1 #{performance_2_1.inspect}"
puts "@@@@@ 2.2 #{performance_2_2.inspect}"
