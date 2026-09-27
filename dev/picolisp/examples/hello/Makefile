# make        check that hello.l reads (PicoLisp has nothing to compile: it runs as it reads)
# make run    run it
# make clean  nothing to remove: PicoLisp keeps no files here

build:
	pil -'in "hello.l" (while (read))' -'prinl "hello.l reads"' -bye

run:
	pil hello.l


clean:

.PHONY: build run clean
