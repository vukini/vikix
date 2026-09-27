# make        check that it parses (Julia compiles each function as it first runs)
# make run    run dispatch.jl
# make clean  nothing to remove: Julia keeps no files here

JULIA ?= julia --startup-file=no

build:
	$(JULIA) -e 'Meta.parseall(read("dispatch.jl", String)); println("dispatch.jl parses")'

run:
	$(JULIA) dispatch.jl

clean:

.PHONY: build run clean
