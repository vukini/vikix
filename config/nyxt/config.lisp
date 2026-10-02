;;;; config.lisp — your Nyxt config: yours, copied once, never overwritten.
;;;;
;;;; Nyxt's keys, commands and modes are Lisp, and this file is where yours
;;;; go. Nyxt's manual (M-x manual, or nyxt:manual) shows how.

(in-package #:nyxt-user)

;; Vikix's part: Nyxt in the desktop's colours, following `vikix theme'.
;; Take this line out to keep Nyxt's own.
;; Not there, or a link to a file that's gone (a moved checkout, which
;; probe-file doesn't notice): Nyxt keeps its own colours, and the rest of
;; this file still loads.
(handler-case (load (merge-pathnames "vikix/nyxt/vikix.lisp" (uiop:xdg-data-home)))
  (file-error () nil))

;; Your own settings below, so they win. For example, a light theme's
;; pages unchanged, without the dark mode Nyxt's settings may switch on:
;; (define-configuration web-buffer
;;   ((default-modes (remove 'nyxt/mode/style:dark-mode %slot-value%))))
