#!/usr/bin/env bash
# tests/errors.sh — errors.lisp: a mistake in a file costs only that part.
#
#   A file loads a form at a time: a form that fails is skipped and the
#   rest still load; a ( never closed skips the rest (it can't be read);
#   the line given is the form's, not the comment's above it; each error is
#   written down in $VIKIX_STATE/errors/, and only the newest are kept;
#   functions defined this way still know their file (M-. finds them).
#   With nobody to ask (no screen), it goes on as if "skip" were picked.
#   Errors StumpWM doesn't catch: the plain word for a float timer, timers
#   made whole again, and asking stops after three errors in 20 seconds.
#
# Needs sbcl and Quicklisp with StumpWM (VIKIX_QUICKLISP, default
# ~/quicklisp); no X: nothing here opens a window.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
unset DISPLAY
here=$(cd "$(dirname "$0")/.." && pwd)
ql=${VIKIX_QUICKLISP:-$HOME/quicklisp}/setup.lisp
command -v sbcl >/dev/null && [ -f "$ql" ] || { echo "errors: needs sbcl and Quicklisp; skipped"; exit 0; }
sbcl --noinform --non-interactive --load "$ql" --eval '(ql:quickload :stumpwm :silent t)' >/dev/null 2>&1 ||
  { echo "errors: Quicklisp has no StumpWM; skipped"; exit 0; }
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
export HOME="$t/home" VIKIX_STATE="$t/state"
mkdir -p "$HOME" "$VIKIX_STATE"

cat > "$t/mixed.lisp" <<'EOF'
(in-package :stumpwm)
(defvar *errors-test-a* :a)

;; A comment above the bad form: the line given is the form's.
(errors-test-no-such-function 1)
(defun errors-test-fn () :defined)
(defvar *errors-test-b* :b)
EOF
cat > "$t/unclosed.lisp" <<'EOF'
(in-package :stumpwm)
(defvar *errors-test-c* :c)
(defvar *errors-test-d* (list 1 2)
(defvar *errors-test-e* :e)
EOF

printf '(in-package :stumpwm)\n(defvar *errors-test-f* :f)\n' > "$t/clean.lisp"

out=$(sbcl --noinform --non-interactive --load "$ql" \
  --eval '(ql:quickload :stumpwm :silent t)' \
  --eval '(in-package :stumpwm)' \
  --eval "(handler-bind ((warning #'muffle-warning)) (load \"$here/config/stumpwm/vikix/errors.lisp\"))" \
  --eval "(progn
  (defvar *fails* 0)
  (defmacro check (name form)
    \`(unless (ignore-errors ,form) (incf *fails*) (format t \"FAIL: ~a~%\" ,name)))
  (defun reports () (directory \"$t/state/errors/*.txt\"))
  (defun report-text (n) (uiop:read-file-string (nth n (sort (reports) #'string< :key #'namestring))))

  ;; Asking can't happen here (no screen): skipping is what's done.
  (check \"a file with a bad form: not clean\" (null (vikix-load-forms \"$t/mixed.lisp\" \"mixed.lisp\")))
  (check \"the forms before it loaded\" (eq (symbol-value '*errors-test-a*) :a))
  (check \"and the ones after it\" (and (eq (symbol-value '*errors-test-b*) :b)
                                    (eq (funcall 'errors-test-fn) :defined)))
  (check \"one report, naming the form's own line\"
         (and (= 1 (length (reports))) (search \"in mixed.lisp, line 5\" (report-text 0))))
  (check \"the report says what failed\" (search \"ERRORS-TEST-NO-SUCH-FUNCTION\" (report-text 0)))
  (check \"what it defined knows its file\"
         (progn (require :sb-introspect)
                (equal (namestring (truename \"$t/mixed.lisp\"))
                       (namestring (sb-introspect:definition-source-pathname
                                    (first (sb-introspect:find-definition-sources-by-name 'errors-test-fn :function)))))))

  (check \"a ( never closed: not clean\" (null (vikix-load-forms \"$t/unclosed.lisp\" \"unclosed.lisp\")))
  (check \"what came before it loaded\" (eq (symbol-value '*errors-test-c*) :c))
  (check \"what's after it wasn't (it can't be read)\" (not (boundp '*errors-test-e*)))
  (check \"the report names the line where the ( is\" (search \"in unclosed.lisp, line 3\" (report-text 1)))

  (check \"a clean file is clean\" (eq t (vikix-load-forms \"$t/clean.lisp\" \"clean.lisp\")))

  (let ((*vikix-errors-kept* 3))
    (dotimes (i 5) (vikix-error-report (make-condition 'simple-error :format-control \"n ~d\" :format-arguments (list i)) \"in a test\"))
    (check \"only the newest reports are kept\" (= 3 (length (reports)))))

  ;; Errors StumpWM doesn't catch.
  (let ((*timer-list* (list (make-timer :time 1.5e7 :function (lambda ()) :args nil))))
    (check \"a float timer gets a plain word\"
           (search \"3/10\" (vikix-error-hint (make-condition 'type-error :datum 5.39e7 :expected-type 'unsigned-byte))))
    (vikix-repair-timers)
    (check \"and carrying on makes its time whole\" (integerp (timer-time (first *timer-list*)))))
  (check \"no word for other errors\" (null (vikix-error-hint (make-condition 'simple-error :format-control \"x\"))))
  (let ((*vikix-recent-errors* '()))
    (check \"two errors: still asking\" (not (or (vikix-error-storm-p) (vikix-error-storm-p))))
    (check \"the third in 20 s: not any more\" (vikix-error-storm-p)))
  (let ((*vikix-recent-errors* (list (- (get-internal-real-time) (* 30 internal-time-units-per-second))
                                     (- (get-internal-real-time) (* 25 internal-time-units-per-second)))))
    (check \"errors longer ago don't count\" (not (vikix-error-storm-p))))
  (check \"no window manager to ask: NIL, not an error\" (null (vikix-ask \"Q\" '((\"a\" 1)))))
  (sb-ext:exit :code (if (zerop *fails*) 0 1)))" 2>&1) || {
  echo "$out" | grep -E "^FAIL" || echo "$out" | tail -20
  exit 1
}
echo "errors: ok"
