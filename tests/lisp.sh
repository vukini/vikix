#!/usr/bin/env bash
# tests/lisp.sh — every Lisp file reads cleanly: balanced parentheses,
# closed strings, nothing the reader rejects.
#
# Without it, a missing paren in keys.lisp passes every other test and
# only shows up at login, as an error message on the desktop. This reads
# the files; it doesn't run them, so it needs neither X nor StumpWM, only
# sbcl. Packages that exist only inside StumpWM (xlib, swm-gaps, ...) are
# made up on the spot, since reading `xlib:with-state` would otherwise
# fail for a reason that has nothing to do with the file.
#
#   tests/lisp.sh [FILE...]    the given files, or every Lisp file Vikix ships

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
cd "$(dirname "$0")/.."
command -v sbcl >/dev/null || { echo "FAIL no sbcl (xbps-install sbcl, or apt install sbcl)"; exit 1; }

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  mapfile -t files < <(find config lib -name '*.lisp' | sort)
fi

# --no-userinit: ~/.sbclrc may load Quicklisp and more, which this doesn't need.
sbcl --noinform --no-sysinit --no-userinit --non-interactive --eval '
(let ((failed 0) (forms 0))
  (labels ((line-at (file position)
             ;; The line POSITION is on, for the message.
             (with-open-file (in file)
               (1+ (loop repeat position
                         count (eql (read-char in nil #\Space) #\Newline)))))
           (make-it-readable (c)
             ;; A package or an external symbol that only StumpWM has.
             (let ((pkg (package-error-package c))
                   (args (simple-condition-format-arguments c)))
               (if (stringp pkg)
                   (make-package pkg :use nil)
                   (export (intern (first args) pkg) pkg))))
           (check (file)
             (with-open-file (in file)
               (let ((*package* (make-package (gensym "VIKIX-TEST") :use (list :cl)))
                     (*read-eval* nil)
                     (fixes 0))
                 (loop
                   (let ((start (file-position in)))
                     (handler-case
                         (if (eq (read in nil in) in)
                             (return)
                             (incf forms))
                       (sb-int:simple-reader-package-error (c)
                         (when (> (incf fixes) 500) (error c))
                         (make-it-readable c)
                         (file-position in start))
                       (end-of-file ()
                         (format t "FAIL ~a: the form at line ~d never closes (a missing paren or quote)~%"
                                 file (line-at file start))
                         (incf failed)
                         (return))
                       (reader-error (c)
                         (format t "FAIL ~a, line ~d: ~a~%"
                                 file (line-at file (file-position in))
                                 ;; SBCL adds the stream and position below; the line says it.
                                 (subseq (princ-to-string c) 0
                                         (position #\Newline (princ-to-string c))))
                         (incf failed)
                         (return)))))))))
    (let ((files (rest (member "--" sb-ext:*posix-argv* :test (function string=)))))
      (mapc (function check) files)
      (format t "lisp: ~d files, ~d forms read~%" (length files) forms)
      (sb-ext:exit :code (if (zerop failed) 0 1)))))' \
  --end-toplevel-options -- "${files[@]}"
