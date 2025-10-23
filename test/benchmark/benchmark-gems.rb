# output = `bundle exec appraisal trb-2.1 ruby run_activity_for_benchmarking.rb`
# performance_2_1 = output.split("\n").last.match(/\@TRB\s+([\d\.]+)k/)[1].sub(".", "").to_i

output = `NEW_SIGNATURE=1 bundle exec appraisal trb-2.2 ruby run_activity_for_benchmarking.rb`
performance_2_2 = output.split("\n").last.match(/\@TRB\s+([\d\.]+k?)/)[1]#.sub(".", "").to_i

output = `bundle exec appraisal trb-2.1 ruby run_activity_for_benchmarking.rb`
performance_2_1 = output.split("\n").last.match(/\@TRB\s+([\d\.]+k?)/)[1]#.sub(".", "").to_i

puts "@@@@@ 2.1 #{performance_2_1.inspect}"
puts "@@@@@ 2.2 #{performance_2_2.inspect}"

_2_1_i = performance_2_1.sub("k", "000").sub(".", "").to_f
puts "@@@@@ #{_2_1_i.inspect}"
_2_2_i = performance_2_2.sub(".", "").to_f

factor = _2_1_i / _2_2_i

puts "@@@@@ 2.2 is #{factor.round(2).inspect}x slower"
