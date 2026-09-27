# make        build ./clicker with lazbuild (Lazarus's command-line builder)
# make run    build, then open the window
# make ide    open the project in the Lazarus IDE
# make clean  remove what make built

# The widget set Void's Lazarus was built for: Qt5 now, GTK2 in older builds.
LAZ := /usr/lib/lazarus
WS  := $(firstword $(foreach w,qt5 gtk2 qt6 gtk3,$(if $(wildcard $(LAZ)/lcl/units/*-linux/$(w)),$(w))))

clicker: clicker.lpr clicker.lpi
	lazbuild --lazarusdir=$(LAZ)/ $(if $(WS),--ws=$(WS)) -q clicker.lpi

run: clicker
	./clicker

ide:
	vikix-lazarus clicker.lpi

clean:
	rm -rf clicker lib

.PHONY: run ide clean
