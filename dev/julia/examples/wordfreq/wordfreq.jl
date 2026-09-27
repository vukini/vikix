# wordfreq.jl — the ten most common words in a text file.
#
# A word is a run of letters, compared in lower case. A Dict counts them;
# sort with a `by` function puts the most common first.
#
#   julia wordfreq.jl text.txt

if length(ARGS) != 1
    println(stderr, "usage: wordfreq.jl FILE")
    exit(2)
end

counts = Dict{String,Int}()
for m in eachmatch(r"[a-z]+", lowercase(read(ARGS[1], String)))
    counts[m.match] = get(counts, m.match, 0) + 1
end

# The higher count first (hence the minus); the same count in alphabetical order.
for (word, count) in first(sort(collect(counts), by = wc -> (-wc[2], wc[1])), 10)
    println(lpad(count, 4), " ", word)
end
