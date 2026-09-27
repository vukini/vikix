# wordfreq.rb — the ten most common words in a text file.
#
# A word is a run of letters, compared in lower case. scan finds them,
# tally counts them, and sort_by with a two-part key puts the most common
# first. Each step hands its result to the next.
#
#   ruby wordfreq.rb text.txt

abort "usage: ruby wordfreq.rb FILE" unless ARGV.size == 1

File.read(ARGV[0]).downcase.scan(/[a-z]+/).tally
    .sort_by { |word, count| [-count, word] }  # the higher count first, then alphabetical
    .first(10)
    .each { |word, count| printf("%4d %s\n", count, word) }
