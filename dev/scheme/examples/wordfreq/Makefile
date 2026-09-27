# make        compile wordfreq.ss to wordfreq.so with Chez Scheme (compile-program)
# make run    run the compiled program on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove the compiled file

wordfreq.so: wordfreq.ss
	echo '(compile-program "wordfreq.ss")' | scheme -q >/dev/null

run: wordfreq.so
	scheme --program wordfreq.so text.txt

check: wordfreq.so
	scheme --program wordfreq.so text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -f wordfreq.so

.PHONY: run check clean
