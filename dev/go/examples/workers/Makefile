# make        build ./workers
# make run    count primes with one worker per CPU
# make clean  remove what make built

workers: main.go go.mod
	go build -o workers .

run: workers
	./workers

clean:
	rm -f workers

.PHONY: run clean
