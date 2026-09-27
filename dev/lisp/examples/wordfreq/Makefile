# make        compile wordfreq.lisp to wordfreq.fasl with SBCL (compile-file)
# make run    run the compiled file on text.txt
# make check  compare the result with expected.txt (the same in every language)
# make clean  remove the compiled file

SBCL ?= sbcl --noinform --non-interactive --no-userinit

wordfreq.fasl: wordfreq.lisp
	$(SBCL) --eval '(compile-file "wordfreq.lisp")' >/dev/null

run: wordfreq.fasl
	sbcl --script wordfreq.fasl text.txt

check: wordfreq.fasl
	sbcl --script wordfreq.fasl text.txt | diff - expected.txt && echo "same as expected.txt"

clean:
	rm -f wordfreq.fasl

.PHONY: run check clean
