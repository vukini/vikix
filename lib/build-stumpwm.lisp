;;;; lib/build-stumpwm.lisp — build StumpWM as a single executable.
;;;;
;;;; Void has no stumpwm package, so Vikix builds it from Quicklisp.
;;;; Run by install/30-lisp.sh as:
;;;;
;;;;   VIKIX_WM_OUTPUT=~/.local/bin/stumpwm \
;;;;     sbcl --non-interactive --load lib/build-stumpwm.lisp
;;;;
;;;; The image also contains Swank, so the running window manager can be
;;;; reached from Emacs (SLIME) and changed while it runs.

(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))

;; StumpWM itself, plus Swank for live editing from Emacs.
(ql:quickload '(:stumpwm :swank) :silent t)

(let ((output (sb-ext:posix-getenv "VIKIX_WM_OUTPUT")))
  (unless output
    (error "set VIKIX_WM_OUTPUT to the path of the executable to write"))
  (format t "~&;; writing ~a~%" output)
  ;; save-lisp-and-die freezes this whole Lisp — StumpWM and Swank already
  ;; loaded — into one file. :toplevel is what runs when that file starts.
  (sb-ext:save-lisp-and-die output
                            :executable t
                            :toplevel (lambda ()
                                        (stumpwm:stumpwm)
                                        (sb-ext:exit))))
