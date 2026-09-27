# make        compile callcc.ss to callcc.so with Chez Scheme (compile-program)
# make run    run the compiled program
# make clean  remove the compiled file

callcc.so: callcc.ss
	echo '(compile-program "callcc.ss")' | scheme -q >/dev/null

run: callcc.so
	scheme --program callcc.so


clean:
	rm -f callcc.so

.PHONY: run clean
