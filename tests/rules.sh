#!/usr/bin/env bash
# tests/rules.sh — rules.lisp: rules for the desktop that read like sentences.
#
#   Without a screen (StumpWM's window objects can be made without X): a
#   string matches exactly, (:has) anywhere and in any case, (:like) as a
#   pattern, a list any of them, a variable by its value; :type, :workspace
#   (where the window opened), :not and :where; a misspelt verb, matcher or
#   option, a bad pattern and a rule with nothing to do are errors when the
#   file loads, each with its line, and the rest of the file still loads; a
#   rule knows its file, line and owner; loading a file twice leaves one of
#   each rule, a named rule replaces itself in place; a rule that fails is
#   written down, never lets the error out, and is switched off at the
#   third; :once has one window; :on :focus and :close; a verb of your own;
#   a plugin's rules go with it; rules setting each other off are stopped.
#
#   On a hidden screen, in a real StumpWM (as tests/viri.sh): workspace puts
#   a window on its workspace before it shows, and :follow goes along; float
#   sizes and places it by shares of the monitor; tile, title, fullscreen,
#   sticky (floating first, and a change of workspace afterwards is safe),
#   dialog; a reload keeps one of each rule and moves nothing; a rule in
#   ~/.stumpwm.d/rules.lisp is loaded, a mistake there asks nothing here
#   and costs only its form; windows there before StumpWM stay put.
#
# The first part needs sbcl and Quicklisp with StumpWM; the second Xvfb,
# alacritty and Vikix's own StumpWM. Each says what it lacks and
# is skipped without it.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
here=$(cd "$(dirname "$0")/.." && pwd)
real_home=$HOME
ql=${VIKIX_QUICKLISP:-$HOME/quicklisp}
t=$(mktemp -d)
pids=()
cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; rm -rf "$t"; }
trap cleanup EXIT
fail=0
said=()

# --- Without a screen ---------------------------------------------------------

no_screen() {
  command -v sbcl >/dev/null && [ -f "$ql/setup.lisp" ] || { echo "rules: needs sbcl and Quicklisp; the part without a screen skipped"; return 0; }
  sbcl --noinform --non-interactive --load "$ql/setup.lisp" --eval '(ql:quickload :stumpwm :silent t)' >/dev/null 2>&1 ||
    { echo "rules: Quicklisp has no StumpWM; the part without a screen skipped"; return 0; }
  mkdir -p "$t/home" "$t/state"

  cat > "$t/mine.lisp" <<'LISP'
(in-package :stumpwm)
(defvar *seen* '())
(defvar *my-class* "FromAVariable")
(define-rule-verb note (what) "Note WHAT, for the test." (push (list what (window-class (rule-window))) *seen*))

(when-window (:class "Firefox") (note :exact))
(when-window (:class (:has "fire")) (note :has))
(when-window (:title (:like "^Mozilla .*x$")) (note :like))
(when-window (:class ("Chromium" "Brave")) (note :any))
(when-window (:class *my-class*) (note :variable))
(when-window (:class "Emacs" :not (:title "Esploro")) (note :not))
(when-window (:where (lambda (w) (equal (window-role w) "pop-up"))) (note :where))
(when-window (:type :dialog) (note :type))
(when-window (:workspace 2) (note :workspace))
(when-window (:class "Lisp") (push (list :own (window-title (window))) *seen*))

;; A comment above the bad rule: the line given is the rule's.
(when-window (:class "Firefox") (flaot :width "65%"))
(when-window (:clas "Firefox") (note :never))
(when-window (:title (:like "(unclosed")) (note :never))
(when-window (:class "Firefox") :sometimes t (note :never))
(when-window (:class "Firefox"))
(when-window (:class 12) (note :never))

(when-window (:class "Once") :once t (note :once))
(when-window (:class "Focused") :on :focus (note :focus))
(when-window (:class "Closed") :on :close (note :close))
(when-window (:class "Named") :name "the named one" (note :named-1))
(when-window (:class "After") (note :after))
LISP

  cat > "$t/again.lisp" <<'LISP'
(in-package :stumpwm)
(when-window (:class "Named") :name "the named one" (note :named-2))
LISP

  cat > "$t/failing.lisp" <<'LISP'
(in-package :stumpwm)
(when-window (:class "Breaks") (error "this rule breaks"))
(when-window (:class "Breaks") (note :still-runs))
(when-window (:where (lambda (w) (error "the matcher breaks ~a" (window-class w)))) (note :never))
(when-window (:class "NoWindowVerb") (note :ok))
(when-window (:class "Loops") (vikix-rules-for (window) :open))
LISP

  local out
  out=$(HOME="$t/home" VIKIX_STATE="$t/state" DISPLAY='' sbcl --noinform --non-interactive --load "$ql/setup.lisp" \
    --eval '(ql:quickload :stumpwm :silent t)' \
    --eval '(in-package :stumpwm)' \
    --eval "(handler-bind ((warning #'muffle-warning)) (load \"$here/config/stumpwm/vikix/errors.lisp\") (load \"$here/config/stumpwm/vikix/rules.lisp\"))" \
    --eval "(progn
  (defvar *fails* 0)
  (defmacro check (name form)
    \`(unless (ignore-errors ,form) (incf *fails*) (format t \"FAIL: ~a~%\" ,name)))
  (defun win (class &key (title \"\") (role \"\") (type :normal) (res class))
    (make-instance 'tile-window :class class :res res :title title :role role :type type))
  (defun opens (w) (setf *seen* '()) (vikix-rules-new-window w) (reverse (mapcar #'first *seen*)))
  (defun reports () (directory \"$t/state/errors/*.txt\"))
  (defun all-reports () (format nil \"~{~a~%~}\" (mapcar #'uiop:read-file-string (reports))))
  (defun rule-of (text) (find text *vikix-rules* :key #'vikix-rule-text :test #'search))

  (check \"the verbs are there, float and fullscreen among them\"
         (subsetp '(\"float\" \"fullscreen\" \"workspace\" \"tile\" \"sticky\" \"dialog\" \"title\" \"focus\" \"run\" \"command\" \"notify\" \"say\" \"open-project\" \"theme\")
                  (vikix-rule-verb-names) :test #'equal))
  (check \"float is still Common Lisp's, fullscreen StumpWM's\" (and (= 2.0 (float 2)) (fboundp 'fullscreen)))

  (handler-bind ((warning #'muffle-warning))
    (vikix-load-forms \"$t/mine.lisp\" \"mine.lisp\"))

  ;; Matching
  (check \"a string matches exactly\" (equal (opens (win \"Firefox\")) '(:exact :has)))
  (check \"and not a part, as StumpWM's own rules would\" (equal (opens (win \"Firefox-esr\")) '(:has)))
  (check \"(:has) in any case\" (equal (opens (win \"WATERFIRE\")) '(:has)))
  (check \"(:like) is a pattern on the whole text\" (and (equal (opens (win \"X\" :title \"Mozilla Firefox\")) '(:like))
                                                         (null (opens (win \"X\" :title \"Old Mozilla Firefox\")))))
  (check \"a list: any of them\" (and (equal (opens (win \"Brave\")) '(:any)) (equal (opens (win \"Chromium\")) '(:any))))
  (check \"a variable: its value when the window comes\"
         (and (equal (opens (win \"FromAVariable\")) '(:variable))
              (progn (setf *my-class* \"Changed\") (equal (opens (win \"Changed\")) '(:variable)))
              (null (opens (win \"FromAVariable\")))))
  (check \":not\" (and (equal (opens (win \"Emacs\" :title \"notes.org\")) '(:not))
                       (null (opens (win \"Emacs\" :title \"Esploro\")))))
  (check \":where\" (equal (opens (win \"Any\" :role \"pop-up\")) '(:where)))
  (check \":type\" (equal (opens (win \"Any\" :type :dialog)) '(:type)))
  (check \":workspace is where the window opened\"
         (let ((w (win \"Any\")) (w3 (win \"Any\")))
           (setf (gethash w *vikix-rule-opened-in*) (make-instance 'group :number 2 :name \"two\")
                 (gethash w3 *vikix-rule-opened-in*) (make-instance 'group :number 3 :name \"three\"))
           (and (equal (opens w) '(:workspace)) (null (opens w3)))))
  (check \"Lisp of your own, with (window)\"
         (progn (setf *seen* '()) (vikix-rules-new-window (win \"Lisp\" :title \"mine\"))
                (equal *seen* '((:own \"mine\")))))

  ;; Mistakes are found when the file loads
  (check \"six mistakes, six reports, each with its line\"
         (and (= 6 (length (reports)))
              (every (lambda (line) (search (format nil \"in mine.lisp, line ~d\" line) (all-reports))) '(18 19 20 21 22 23))))
  (check \"the report says what's wrong, in plain words\"
         (and (search \"flaot isn't a verb\" (all-reports))
              (search \":CLAS isn't something a rule can match\" (all-reports))
              (search \"has a pattern that can't be read\" (all-reports))
              (search \":SOMETIMES isn't an option\" (all-reports))
              (search \"This rule does nothing\" (all-reports))
              (search \"A rule's :class is 12\" (all-reports))))
  (check \"none of the six became a rule, and the rest of the file loaded\"
         (and (= 15 (length *vikix-rules*)) (rule-of \"After\")))

  ;; What a rule knows about itself
  (check \"its text, file, line and owner\"
         (let ((r (rule-of \"(note :exact)\")))
           (and (equal (vikix-rule-text r) \"(when-window (:class \\\"Firefox\\\") (note :exact))\")
                (search \"mine.lisp\" (vikix-rule-file r))
                (eql 6 (vikix-rule-line r))
                (equal (vikix-rule-owner r) \"mine.lisp\"))))
  (check \"how often it ran\" (plusp (vikix-rule-runs (rule-of \"(note :exact)\"))))

  ;; Loading again
  (let ((order (mapcar #'vikix-rule-key *vikix-rules*)))
    (handler-bind ((warning #'muffle-warning))
      (vikix-load-forms \"$t/mine.lisp\" \"mine.lisp\")
      (vikix-load-forms \"$t/again.lisp\" \"again.lisp\"))
    (check \"a second load leaves one of each rule, in the same order\"
           (equal order (mapcar #'vikix-rule-key *vikix-rules*)))
    (check \"a named rule is replaced where it stood\"
           (and (equal (opens (win \"Named\")) '(:named-2))
                (equal (vikix-rule-owner (find \"the named one\" *vikix-rules* :key #'vikix-rule-key :test #'equal)) \"again.lisp\"))))

  ;; :once, :focus, :close
  (check \":once has the first window only\" (and (equal (opens (win \"Once\")) '(:once)) (null (opens (win \"Once\")))))
  (check \"and stays had over a reload\"
         (progn (handler-bind ((warning #'muffle-warning)) (vikix-load-forms \"$t/mine.lisp\" \"mine.lisp\"))
                (null (opens (win \"Once\")))))
  (check \":on :focus runs on focus, not on opening\"
         (and (null (opens (win \"Focused\")))
              (progn (setf *seen* '()) (vikix-rules-focus-window (win \"Focused\") nil) (equal (mapcar #'first *seen*) '(:focus)))
              (progn (vikix-rules-focus-window nil nil) t)))
  (check \":on :close runs when the window goes\"
         (progn (setf *seen* '()) (vikix-rules-destroy-window (win \"Closed\")) (equal (mapcar #'first *seen*) '(:close))))

  ;; Failing
  (let ((before (length (reports))))
    (handler-bind ((warning #'muffle-warning)) (vikix-load-forms \"$t/failing.lisp\" \"failing.lisp\"))
    (let ((breaks (rule-of \"this rule breaks\"))
          (matcher (rule-of \"the matcher breaks\")))
      (check \"a rule that fails lets nothing out, and the next rule still runs\"
             (equal (opens (win \"Breaks\")) '(:still-runs)))
      (check \"the failure is written down, with the rule\"
             (and (> (length (reports)) before) (search \"in the rule (when-window (:class \\\"Breaks\\\")\" (all-reports))))
      (check \"it is still on after two\" (progn (opens (win \"Breaks\")) (vikix-rule-on-p breaks)))
      (check \"and off at the third, with its last error kept\"
             (progn (opens (win \"Breaks\"))
                    (and (not (vikix-rule-on-p breaks)) (= 3 (vikix-rule-failures breaks))
                         (search \"this rule breaks\" (vikix-rule-last-error breaks)))))
      (check \"off, it runs no more\" (progn (opens (win \"Breaks\")) (= 3 (vikix-rule-failures breaks))))
      (check \"a matcher of yours that fails is the rule's failure too\" (not (vikix-rule-on-p matcher)))
      (check \"a reload switches it on again\"
             (progn (handler-bind ((warning #'muffle-warning)) (vikix-load-forms \"$t/failing.lisp\" \"failing.lisp\"))
                    (vikix-rule-on-p (rule-of \"this rule breaks\"))))
      (check \"a verb that needs a window, in a rule without one, fails cleanly\"
             (let ((r (rule-of \"NoWindowVerb\")))
               (and (null (vikix-run-rule r nil :open)) (= 1 (vikix-rule-failures r)))))
      (check \"rules setting each other off are stopped\"
             (let ((r (rule-of \"Loops\")))
               (opens (win \"Loops\"))
               (and (plusp (vikix-rule-failures r)) (search \"eight deep\" (all-reports)))))
      (check \"only the newest reports are kept\" (<= (length (reports)) *vikix-errors-kept*))))

  ;; Plugins
  (let ((*vikix-plugin* \"demo\"))
    (declare (special *vikix-plugin*))
    (proclaim '(special *vikix-plugin*))
    (eval '(let ((*vikix-plugin* \"demo\")) (when-window (:class \"FromAPlugin\") (note :plugin)))))
  (check \"a plugin's rule is its own\" (equal (vikix-rule-owner (rule-of \"FromAPlugin\")) \"plugin demo\"))
  (check \"and goes when plugins are unloaded, the others staying\"
         (let ((n (length *vikix-rules*)))
           (and (= 1 (vikix-remove-rules :owner-prefix \"plugin \"))
                (= (1- n) (length *vikix-rules*))
                (null (rule-of \"FromAPlugin\")))))

  ;; For Viri: does a rule float this window?
  (eval '(when-window (:class \"Floats\") (float :width \"50%\")))
  (check \"a rule with float says so before the window is placed, and the same afterwards\"
         (let ((w (win \"Floats\")))
           (and (vikix-rules-float-p w) (not (vikix-rules-float-p (win \"Firefox\")))
                (progn (vikix-remove-rules :key (vikix-rule-key (rule-of \"Floats\"))) (not (vikix-rules-float-p (win \"Floats\")))))))

  ;; Sizes
  (check \"a size is pixels, or a share of the monitor\"
         (and (= 300 (vikix-rule-length 300 1280 \"x\")) (= 832 (vikix-rule-length \"65%\" 1280 \"x\"))
              (= 160 (vikix-rule-length \" 12.5 % \" 1280 \"x\")) (null (vikix-rule-length nil 1280 \"x\"))
              (null (ignore-errors (vikix-rule-length \"65\" 1280 \"x\")))))

  (check \"the list has a line a rule\" (= (length (vikix-rules-lines)) (length *vikix-rules*)))
  (format t \"~a~%\" (if (zerop *fails*) \"no-screen: ok\" \"no-screen: failed\")))" 2>&1) || true
  if grep -q '^no-screen: ok$' <<<"$out"; then
    said+=("matching, mistakes found at load with their line, one rule after a second load, failing rules switched off at the third, :once, :focus and :close, plugins' rules")
  else
    echo "$out" | grep -v '^;\|^$' | tail -25
    echo "FAIL: the rules without a screen"
    fail=1
  fi
}

no_screen

# --- On a hidden screen ---------------------------------------------------------

on_screen() {
  local wm=${VIKIX_TEST_STUMPWM:-$real_home/.local/bin/stumpwm} need
  for need in Xvfb alacritty xdpyinfo; do
    command -v "$need" >/dev/null || { echo "rules: needs $need and an X server; the part on a screen skipped"; return 0; }
  done
  [ -x "$wm" ] || { echo "rules: needs Vikix's StumpWM ($wm); the part on a screen skipped"; return 0; }
  check() { "${@:2}" || { echo "FAIL: $1"; fail=1; }; }

  # A free screen and a free port: tests run side by side.
  local n port home
  n=$(( 500 + RANDOM % 400 ))
  while [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ]; do n=$((n + 1)); done
  port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  export DISPLAY=":$n"
  Xvfb "$DISPLAY" -screen 0 1280x800x24 -nolisten tcp >/dev/null 2>&1 &
  pids+=($!)

  home="$t/wm-home"
  mkdir -p "$home/.stumpwm.d" "$home/.local/state/vikix" "$home/.config/vikix"
  cp "$here/config/stumpwm/init.lisp" "$home/.stumpwm.d/"
  cp -r "$here/config/stumpwm/vikix" "$home/.stumpwm.d/"
  sed -i "s/(defparameter \\*vikix-swank-port\\* 4004)/(defparameter *vikix-swank-port* $port)/" "$home/.stumpwm.d/vikix/swank.lisp"
  [ -d "$ql" ] && ln -s "$ql" "$home/quicklisp"
  echo "rules-test" > "$home/.slime-secret"; chmod 600 "$home/.slime-secret"
  touch "$home/.local/state/vikix/welcome"     # no welcome terminal

  cat > "$home/.stumpwm.d/rules.lisp" <<'LISP'
(in-package :stumpwm)
(when-window (:class "ToTwo") (workspace 2))
(when-window (:class "Follow") (workspace 3 :follow t))
(when-window (:class "Corner") (float :width "50%" :height "25%" :corner :bottom-right))
(when-window (:class "Middle") (float :width 400 :height 300))
(when-window (:class "Named") (title "my name"))
(when-window (:class "Full") (fullscreen))
(when-window (:class "Sticky") (sticky))
(when-window (:class "Dialog") (dialog))
(when-window (:class "Retile") (float) (tile))
(when-window (:class "Broken") (workspace 42))
(when-window (:class "ToTwo" :title "twice") (workspace 2) (workspace 4))
LISP
  cat > "$home/.stumpwm.d/user.lisp" <<'LISP'
(in-package :stumpwm)
;; Which windows StumpWM itself put on a workspace as they opened (it runs
;; this hook only then), and where.
(defvar *rules-test-placed* '())
(defun rules-test-placed (window group &rest ignore)
  (declare (ignore ignore))
  (push (list (window-class window) (group-number group)) *rules-test-placed*))
(add-hook *place-window-hook* 'rules-test-placed)
(when-window (:class "FromUser") (title "from user.lisp"))
LISP

  start_wm() {
    HOME=$home VIKIX_SWANK_PORT=$port "$wm" >>"$t/wm.log" 2>&1 &
    wm_pid=$!
    pids+=("$wm_pid")
    answers 60
  }
  # answers SECONDS: wait that long, at most, for the test StumpWM to answer.
  # (One that is busy takes 10 seconds to say so, so count time, not tries.)
  answers() {
    local until=$((SECONDS + $1))
    while [ "$SECONDS" -lt "$until" ]; do [ "$(ask '(princ 1)')" = 1 ] && return 0; sleep 0.5; done
    return 1
  }
  # What the test StumpWM said and wrote down, for a failure nobody can see.
  diagnose() {
    echo "--- the test StumpWM's log:"; grep -v '^;' "$t/wm.log" | tail -60
    echo "--- its errors:"; head -40 "$home"/.local/state/vikix/errors/*.txt 2>/dev/null | cut -c1-300
    if [ -n "${VIKIX_TEST_KEEP:-}" ] && command -v import >/dev/null; then
      mkdir -p "$VIKIX_TEST_KEEP"; import -window root "$VIKIX_TEST_KEEP/screen-$$.png" 2>/dev/null && echo "--- its screen: $VIKIX_TEST_KEEP/screen-$$.png"
      cp "$t/wm.log" "$VIKIX_TEST_KEEP/wm-$$.log" 2>/dev/null || true
    fi
  }
  ask() { HOME=$home VIKIX_SWANK_PORT=$port python3 "$here/bin/vikix-eval" "(progn (setf *print-pretty* nil) $1)" 2>&1 | grep -v '^=> ' || true; }
  # yes FORM: is it true in the test StumpWM?
  yes() { [ "$(ask "(princ (if $1 1 0))")" = 1 ]; }
  the() { echo "(find \"$1\" (screen-windows (current-screen)) :key (function window-class) :test (function equal))"; }
  win() {   # win CLASS [TITLE]: a window of that class, and wait till StumpWM has it
    LIBGL_ALWAYS_SOFTWARE=1 alacritty --class "$1" --title "${2:-$1}" -e sleep 300 >/dev/null 2>&1 &
    pids+=($!)
    for _ in $(seq 1 40); do
      yes "(find \"${2:-$1}\" (screen-windows (current-screen)) :key (function window-title) :test (function equal))" && break
      sleep 0.25
    done
    sleep 0.4
  }
  # go N: to workspace N (asked, not typed: a key can be lost while StumpWM is busy)
  go() { ask "(switch-to-group (find $1 (screen-groups (current-screen)) :key (function group-number)))" >/dev/null; sleep 0.3; }
  here_is() { ask '(princ (group-number (current-group)))'; }
  group_of() { ask "(princ (group-number (window-group $(the "$1"))))"; }

  for _ in $(seq 1 30); do xdpyinfo >/dev/null 2>&1 && break; sleep 0.2; done
  local wm_pid
  start_wm || { echo "FAIL: the test StumpWM didn't start"; diagnose; fail=1; return 0; }

  check "rules.lisp and user.lisp both gave their rules: $(ask '(princ (length *vikix-rules*))')" test "$(ask '(princ (length *vikix-rules*))')" = 12
  check "each knows whose it is" yes '(equal (remove-duplicates (mapcar (function vikix-rule-owner) *vikix-rules*) :test (function equal)) (list "rules.lisp" "user.lisp"))'

  win Plain
  check "a window no rule is about opens where you are, tiled" yes "(and (eql 1 (group-number (window-group $(the Plain)))) (typep $(the Plain) (quote tile-window)))"

  win ToTwo
  check "workspace: the window is on workspace 2: $(group_of ToTwo)" test "$(group_of ToTwo)" = 2
  check "and you stay where you were: $(here_is)" test "$(here_is)" = 1
  check "StumpWM put it there as it opened, before it showed" yes '(member (list "ToTwo" 2) *rules-test-placed* :test (function equal))'
  check "the rule ran once and noted the window" yes "(and (= 1 (vikix-rule-runs (first *vikix-rules*))) (gethash $(the ToTwo) *vikix-rule-notes*))"

  win Follow
  check ":follow goes along: $(here_is)" test "$(here_is)" = 3
  check "with the window focused" yes '(equal (window-class (current-window)) "Follow")'
  go 1

  win Corner
  check "float: the window floats" yes "(typep $(the Corner) (quote float-window))"
  check "at half the width and a quarter of the height below the bar, in the bottom right corner: $(ask "(let ((p (window-parent $(the Corner)))) (princ (list (xlib:drawable-x p) (xlib:drawable-y p) (xlib:drawable-width p) (xlib:drawable-height p))))")" \
    yes "(multiple-value-bind (ax ay aw ah) (vikix-rule-area (current-head)) (let* ((p (window-parent $(the Corner))) (w (floor (* 50 aw) 100)) (h (floor (* 25 ah) 100))) (and (= (xlib:drawable-width p) w) (= (xlib:drawable-height p) h) (= (xlib:drawable-x p) (+ ax (- aw w 8))) (= (xlib:drawable-y p) (+ ay (- ah h 8))))))"
  win Middle
  check "sizes in pixels, and the middle when no place is given" \
    yes "(multiple-value-bind (ax ay aw ah) (vikix-rule-area (current-head)) (let ((p (window-parent $(the Middle)))) (and (= (xlib:drawable-width p) 400) (= (xlib:drawable-height p) 300) (= (xlib:drawable-x p) (+ ax (floor (- aw 400) 2))) (= (xlib:drawable-y p) (+ ay (floor (- ah 300) 2))))))"

  win Named
  check "title: the window has the name" yes "(equal (window-name $(the Named)) \"my name\")"
  win FromUser
  check "a rule in user.lisp works the same" yes "(equal (window-name $(the FromUser)) \"from user.lisp\")"
  win Retile
  check "float then tile: tiled again" yes "(typep $(the Retile) (quote tile-window))"
  win Dialog
  check "dialog: floating, and kept as a dialog" yes "(and (typep $(the Dialog) (quote float-window)) (vikix-dialog-p $(the Dialog)))"
  win Full
  check "fullscreen" yes "(window-fullscreen $(the Full))"
  ask "(delete-window $(the Full))" >/dev/null; sleep 0.7

  win Broken
  check "a rule that fails leaves the window where it opened, the desktop answering" yes "(and (eql 1 (group-number (window-group $(the Broken)))) (= 1 (vikix-rule-failures (find \"Broken\" *vikix-rules* :key (function vikix-rule-text) :test (function search)))))"
  check "and the failure is written down" test -n "$(grep -l 'There is no workspace 42' "$home"/.local/state/vikix/errors/*.txt 2>/dev/null)"

  win ToTwo twice
  check "two rules about one window: the last workspace wins, with no stop on the way: $(ask '(princ (group-number (window-group (find "twice" (screen-windows (current-screen)) :key (function window-title) :test (function equal)))))')" \
    yes '(and (eql 4 (group-number (window-group (find "twice" (screen-windows (current-screen)) :key (function window-title) :test (function equal))))) (member (list "ToTwo" 4) *rules-test-placed* :test (function equal)))'

  win Sticky
  check "sticky: the window floats and is on every workspace" yes "(and (typep $(the Sticky) (quote float-window)) (member $(the Sticky) *always-show-windows*) (every (lambda (g) (member $(the Sticky) (group-windows g))) (screen-groups (current-screen))))"
  go 2; go 5; go 1
  check "and changing workspace afterwards is safe: $(here_is)" test "$(here_is)" = 1
  ask "(progn (disable-always-show-window $(the Sticky) (current-screen)) (delete-window $(the Sticky)))" >/dev/null; sleep 0.7

  # On a strip (Viri), a window a rule floats isn't a column.
  if yes "(fboundp 'viri-group-p)"; then
    go 6
    win Plain strip-a; win Plain strip-b
    ask '(run-commands "vikix-viri")' >/dev/null; sleep 0.5
    win Corner on-strip
    check "on a Viri strip a window a rule floats is no column: $(ask '(princ (mapcar (function window-title) (viri-columns (current-group))))')" \
      yes '(and (viri-group-p) (= 2 (length (viri-columns (current-group)))) (not (member "on-strip" (viri-columns (current-group)) :key (function window-title) :test (function equal))))'
    go 1
  fi

  # A mistake in a file of rules, with nobody asked: only its form is lost.
  printf '(in-package :stumpwm)\n(when-window (:class "Late") (title "late"))\n(when-window (:class "Late") (flaot))\n' > "$t/late.lisp"
  ask "(let ((*vikix-errors-ask* nil)) (vikix-load-forms \"$t/late.lisp\" \"late.lisp\"))" >/dev/null
  check "a mistake costs only its own rule: $(ask '(princ (length *vikix-rules*))')" test "$(ask '(princ (length *vikix-rules*))')" = 13

  # A reload: exactly what the files say, and no window moved.
  ask "(move-window-to-group $(the Named) (find 5 (screen-groups (current-screen)) :key (function group-number)))" >/dev/null
  ask '(loadrc)' >/dev/null
  answers 60 || true
  check "after a reload: the files' rules, one of each: $(ask '(princ (length *vikix-rules*))')" test "$(ask '(princ (length *vikix-rules*))')" = 12
  check "and no window was moved: $(group_of Named) $(group_of ToTwo)" test "$(group_of Named) $(group_of ToTwo)" = "5 2"
  check "and the failures counted start again" yes '(zerop (reduce (function +) (mapcar (function vikix-rule-failures) *vikix-rules*)))'

  # StumpWM starting again with the windows there: they stay where they are.
  kill "$wm_pid" 2>/dev/null || true
  for _ in $(seq 1 20); do kill -0 "$wm_pid" 2>/dev/null || break; sleep 0.25; done
  start_wm || { echo "FAIL: the test StumpWM didn't start again, with its windows there"; diagnose; fail=1; return 0; }
  sleep 1
  check "StumpWM started again: the windows that were there set no rule off: $(ask '(princ (list (length (screen-windows (current-screen))) (reduce (function +) (mapcar (function vikix-rule-runs) *vikix-rules*))))')" \
    yes '(and (> (length (screen-windows (current-screen))) 5) (zerop (reduce (function +) (mapcar (function vikix-rule-runs) *vikix-rules*))))'
  check "nothing asked, nothing failed, in the whole run" test -z "$(grep -il 'debugger\|unhandled' "$t/wm.log" 2>/dev/null)"
  [ "$fail" = 0 ] || diagnose
  [ "$fail" = 0 ] && said+=("and on a screen: workspace before the window shows, float by shares of the monitor, tile, title, fullscreen, sticky, dialog, a failing rule, a reload, a restart")
  return 0
}

on_screen

[ "$fail" = 0 ] || exit 1
echo "rules: ${said[*]:-nothing could be tested here}"
