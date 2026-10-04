# publish.mk — a book's EPUB and PDF, the same way in every project (Vikix
# publish, `vikix add publish`). In the project's Makefile, last:
#
#   -include $(HOME)/.local/share/vikix/publish/publish.mk
#
# (with the dash, the project's other targets still work where publish
# isn't installed). Then:
#
#   make epub     out/NAME.epub, through the e-ink table fix and epubcheck
#   make pdf      out/NAME.pdf, through Typst
#   make check    both into a scratch folder: does it build, and pass?
#
# The text and metadata come from publish.yml (see `build help`). A target
# the project already has keeps its own recipe only if it comes after this
# line; better to give one of them another name.

VIKIX_PUBLISH ?= $(HOME)/.local/share/vikix/publish

.PHONY: epub pdf check
epub pdf check:
	@python3 $(VIKIX_PUBLISH)/build $@
