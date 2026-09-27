# blocks.rb — blocks, and a class that writes its own methods.
#
# A block is a piece of code handed to a method, between { } or do ... end.
# Ruby's collections take blocks for almost everything, and your own
# methods can too: `yield` runs the block they were given. Classes stay
# open while the program runs, so code can add methods to them.

# Blocks, chained: each method takes a block and hands on a new collection.
squares_of_odds = (1..10).select { |n| n.odd? }.map { |n| n * n }
puts "squares of the odd numbers to 10: #{squares_of_odds.inspect}"

# A method of our own that takes a block: it runs it and times it.
def timed(label)
  started = Time.now
  result = yield                     # run the block, keep what it gives back
  puts format("%s took %.3f s", label, Time.now - started)
  result
end

sum = timed("doubling and adding a million numbers") { (1..1_000_000).map { |n| n * 2 }.sum }
puts "the sum: #{sum}"

# A class that makes a method for each colour, while the program runs.
class Light
  %w[red amber green].each do |colour|
    define_method("#{colour}?") { @colour == colour }
    define_method("#{colour}!") { @colour = colour; self }
  end
end

light = Light.new.green!
puts "is the light green? #{light.green?}; red? #{light.red?}"
puts "methods Ruby wrote for Light: #{Light.instance_methods(false).sort.join(', ')}"
