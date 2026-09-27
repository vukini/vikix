# make        check that it parses (Julia compiles each function as it first runs)
# make run    run wordfreq.jl on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  nothing to remove: Julia keeps no files here

JULIA ?= julia --startup-file=no

build:
	$(JULIA) -e 'Meta.parseall(read("wordfreq.jl", String)); println("wordfreq.jl parses")'

run:
	$(JULIA) wordfreq.jl text.txt

check:
	$(JULIA) wordfreq.jl text.txt | diff - expected.txt && echo "same as expected.txt"

clean:

.PHONY: build run check clean
