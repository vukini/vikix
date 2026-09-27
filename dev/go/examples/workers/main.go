// main.go — goroutines and channels: several workers at once.
//
// Counting the primes below two million, split into ranges. Each range
// goes to its own goroutine (a function running alongside the others, far
// cheaper than a thread); each sends its answer back on a channel. main
// collects the answers as they arrive, in whatever order they finish.
package main

import (
	"fmt"
	"runtime"
	"time"
)

type result struct {
	from, to, primes int
}

func isPrime(n int) bool {
	if n < 2 {
		return false
	}
	for d := 2; d*d <= n; d++ {
		if n%d == 0 {
			return false
		}
	}
	return true
}

// count sends how many primes are in [from, to) on out.
func count(from, to int, out chan<- result) {
	n := 0
	for i := from; i < to; i++ {
		if isPrime(i) {
			n++
		}
	}
	out <- result{from, to, n}
}

func main() {
	const limit = 2_000_000
	workers := runtime.NumCPU()
	step := limit / workers

	start := time.Now()
	out := make(chan result)
	for w := 0; w < workers; w++ {
		to := (w + 1) * step
		if w == workers-1 {
			to = limit
		}
		go count(w*step, to, out) // `go` starts it and moves on at once
	}

	total := 0
	for w := 0; w < workers; w++ {
		r := <-out // wait for the next worker to finish, whichever it is
		fmt.Printf("%8d-%-8d %6d primes\n", r.from, r.to, r.primes)
		total += r.primes
	}
	fmt.Printf("%d primes below %d, counted by %d workers in %v\n",
		total, limit, workers, time.Since(start).Round(time.Millisecond))
}
