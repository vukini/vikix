# make        compile pictures.rkt with raco make (into compiled/)
# make run    draw the picture into triangle.png
# make view   draw it, then open it
# make clean  remove what raco made, and the picture

build:
	raco make pictures.rkt

run: build
	racket pictures.rkt

view: run
	xdg-open triangle.png >/dev/null 2>&1 &

clean:
	rm -rf compiled triangle.png

.PHONY: build run view clean
