# make        compile macros.lisp to macros.fasl with SBCL (compile-file)
# make run    run the compiled file
# make clean  remove the compiled file

SBCL ?= sbcl --noinform --non-interactive --no-userinit

macros.fasl: macros.lisp
	$(SBCL) --eval '(compile-file "macros.lisp")' >/dev/null

run: macros.fasl
	sbcl --script macros.fasl

clean:
	rm -f macros.fasl

.PHONY: run clean
