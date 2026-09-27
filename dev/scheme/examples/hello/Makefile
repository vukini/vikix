# make        compile hello.ss to hello.so with Chez Scheme (compile-program)
# make run    run the compiled program
# make clean  remove the compiled file

hello.so: hello.ss
	echo '(compile-program "hello.ss")' | scheme -q >/dev/null

run: hello.so
	scheme --program hello.so


clean:
	rm -f hello.so

.PHONY: run clean
