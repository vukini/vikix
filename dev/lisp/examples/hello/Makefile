# make        compile hello.lisp to hello.fasl with SBCL (compile-file)
# make run    run the compiled file
# make clean  remove the compiled file

SBCL ?= sbcl --noinform --non-interactive --no-userinit

hello.fasl: hello.lisp
	$(SBCL) --eval '(compile-file "hello.lisp")' >/dev/null

run: hello.fasl
	sbcl --script hello.fasl

clean:
	rm -f hello.fasl

.PHONY: run clean
