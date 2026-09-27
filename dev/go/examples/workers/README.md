# workers (Go)

What Go is known for: easy concurrency. The primes below two million,
counted by one goroutine per CPU, each sending its answer on a channel.
The ranges finish in a different order each run; the total is always
148933.

    make run

Try: set `workers := 1` and compare the time; make the first range much
bigger than the others and see who finishes last; run `go run -race .`
after sharing a counter between goroutines without the channel.
Docs: `go doc runtime.NumCPU`; the Concurrency part of A Tour of Go, https://go.dev/tour
