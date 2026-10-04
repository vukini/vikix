#!/usr/bin/env bash
# lib/registry.sh — Vikix's commands (config/stumpwm/vikix/registry.lisp),
# as lines for scripts and tests that don't run StumpWM.
#
#   lib/registry.sh keys     each key: its name, the command it runs, what
#                            it does, tab-separated, in the registry's order
#   lib/registry.sh menu     each Super+m entry: its label, what it needs
#                            (empty when nothing), in the menu's order
#   lib/registry.sh agent    each command an agent may run: its name, what
#                            it does
#
# Needs sbcl: it loads registry.lisp itself, so nothing here can differ
# from what the desktop loads.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
command -v sbcl >/dev/null || { echo "registry: needs sbcl" >&2; exit 2; }
case ${1:-} in
  keys)  form='(dolist (b (vikix-registry-bindings)) (format t "~a	~a	~a~%" (first b) (second b) (third b)))' ;;
  menu)  form='(dolist (e (vikix-registry-menu)) (format t "~a	~a~%" (first e) (or (third e) "")))' ;;
  agent) form='(dolist (c *vikix-commands*) (when (getf c :agent) (format t "~(~a~)	~a~%" (getf c :name) (getf c :does))))' ;;
  *) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
sbcl --noinform --no-sysinit --no-userinit --non-interactive \
  --eval '(defpackage :stumpwm (:use :cl))' --eval '(in-package :stumpwm)' \
  --load "$root/config/stumpwm/vikix/registry.lisp" --eval "$form" 2>/dev/null
