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

;; The dist install/30-lisp.sh pins (VIKIX_QL_DIST, a dated Quicklisp
;; release): when ~/quicklisp is at another, it is moved to the pin first,
;; so every build takes the same libraries. Quicklisp's own fetcher speaks
;; plain HTTP, which is why the address isn't https.
(let ((pin (sb-ext:posix-getenv "VIKIX_QL_DIST"))
      (dist (ql-dist:find-dist "quicklisp")))
  (when (and pin (plusp (length pin))
             (or (null dist) (string/= (ql-dist:version dist) pin)))
    (format t "~&;; Quicklisp is at ~a; moving it to Vikix's pin, ~a~%"
            (if dist (ql-dist:version dist) "no dist") pin)
    (ql-dist:install-dist
     (format nil "http://beta.quicklisp.org/dist/quicklisp/~a/distinfo.txt" pin)
     :replace t :prompt nil)))

;; StumpWM itself, plus Swank for live editing from Emacs.
(ql:quickload '(:stumpwm :swank) :silent t)

;; clx-truetype, for the contrib module ttf-fonts (TrueType fonts in the
;; bar and menus; see theme.lisp). It isn't in Quicklisp: 30-lisp clones it
;; into ~/quicklisp/local-projects. Without it StumpWM still builds, and
;; keeps its bitmap font.
(handler-case (ql:quickload :clx-truetype :silent t)
  (error (e) (format t "~&;; clx-truetype not built in (~a); bitmap font only~%" e)))

(let ((output (sb-ext:posix-getenv "VIKIX_WM_OUTPUT")))
  (unless output
    (error "set VIKIX_WM_OUTPUT to the path of the executable to write"))
  (format t "~&;; writing ~a~%" output)
  ;; save-lisp-and-die freezes this whole Lisp — StumpWM and Swank already
  ;; loaded — into one file. :toplevel is what runs when that file starts.
  (sb-ext:save-lisp-and-die output
                            :executable t
                            :toplevel (lambda ()
                                        ;; 30-lisp asks the new image whether it
                                        ;; starts before it replaces the old one:
                                        ;; loaded this far, it says so and leaves.
                                        (when (sb-ext:posix-getenv "VIKIX_WM_CHECK")
                                          (format t "stumpwm image ok~%")
                                          (sb-ext:exit :code 0))
                                        (stumpwm:stumpwm)
                                        (sb-ext:exit))))
