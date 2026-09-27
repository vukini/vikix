# make        check that it parses (Julia compiles each function as it first runs)
# make run    run hello.jl
# make clean  nothing to remove: Julia keeps no files here

JULIA ?= julia --startup-file=no

build:
	$(JULIA) -e 'Meta.parseall(read("hello.jl", String)); println("hello.jl parses")'

run:
	$(JULIA) hello.jl

clean:

.PHONY: build run clean
