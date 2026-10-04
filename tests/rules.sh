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
#   The rules with no window, the clock and the battery being the test's
#   own: at runs at its time and once, on its days, not again after a
#   reload or a restart (what ran is written down), up to an hour late after
#   a sleep (:late t however late, :late nil never), and a rule written
#   after its time waits for the next; each counts from when it last ran,
#   once after a long sleep; when-battery-below once as the charge goes
#   under its mark, again after the charger or a charge above it;
#   when-charging and when-on-battery at the change; at-login once a login,
#   one added later once too, one that fails not retried; when-workspace by
#   number, name or list; their mistakes found as the file loads.
#
#   On a hidden screen, in a real StumpWM (as tests/viri.sh): workspace puts
#   a window on its workspace before it shows, and :follow goes along; float
#   sizes and places it by shares of the monitor; tile, title, fullscreen,
#   sticky (floating first, and a change of workspace afterwards is safe),
#   dialog; a reload keeps one of each rule and moves nothing; a rule in
#   ~/.stumpwm.d/rules.lisp is loaded, a mistake there asks nothing here
#   and costs only its form; windows there before StumpWM stay put; the
#   ticker runs, one of it; at-login runs once, not at a reload nor when
#   StumpWM starts again in the same login; when-workspace on arriving.
#
# RULES_SKIP_SCREEN=1 leaves the part on a screen out (a quick run).
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

  # Seeing and steering them (vikix rules): loaded last, by the checks below.
  cat > "$t/seeing.lisp" <<'LISP'
(in-package :stumpwm)
(when-window (:class "Seen") :name "seen-rule" (note :seen))
(when-window (:class "Seen") :on :focus (note :seen-focus))
(when-window (:class "Seen" :title "never") (note :other))
(when-window (:class "SeenBreaks") (error "seen breaks"))
(when-window (:class "Seen") :once t :name "seen-once" (note :once))
(at "09:00" :name "seen-at" (say "x"))
(when-window (:class "Elsewhere") (workspace 77))

;; Vikix's own rules (the end of rules.lisp): what its hooks were, said as rules.
(let ((lazarus (vikix-rule-called "Vikix: Lazarus's windows float, all but its main one"))
      (learn (vikix-rule-called "Vikix: vikix learn's lesson and shell, each in its half")))
  (check "Lazarus: a dialog, the welcome screen and anything undocked match; the main window, under each of its three titles, doesn't"
         (and (vikix-rule-fits-p lazarus (win "lazarus" :title "Project Options"))
              (vikix-rule-fits-p lazarus (win "Lazarus-ide" :title "Welcome to Lazarus IDE 3.6"))
              (vikix-rule-fits-p lazarus (win "lazarus" :title ""))
              (not (vikix-rule-fits-p lazarus (win "lazarus" :title "Lazarus")))
              (not (vikix-rule-fits-p lazarus (win "lazarus" :title "MainIDE")))
              (not (vikix-rule-fits-p lazarus (win "lazarus" :title "Lazarus IDE v3.6 - project1")))
              (not (vikix-rule-fits-p lazarus (win "Firefox" :title "Lazarus")))))
  (check "it floats them at their own size, and Viri is told so" (equal (vikix-rule-verbs lazarus) '("FLOAT")))
  (check "vikix learn's two panes match, and no other terminal"
         (and (vikix-rule-fits-p learn (win "vikix-learn-lesson")) (vikix-rule-fits-p learn (win "vikix-learn-shell"))
              (not (vikix-rule-fits-p learn (win "Alacritty")))))
  (check "the hooks they were are gone"
         (not (or (member 'vikix-float-lazarus-window *new-window-hook*) (member 'vikix-learn-place *new-window-hook*)))))
(check "float :own t takes no size or place"
       (search "keeps the window's own size and place"
               (princ-to-string (nth-value 1 (ignore-errors (let ((*vikix-rule-window* (win "X"))) (vikix-verb-float :own t :width 300)))))))

(defun refusal (what)
  "The words vikix-rule-called refuses WHAT with."
  (princ-to-string (nth-value 1 (ignore-errors (vikix-rule-called what)))))

(let* ((rule (vikix-rule-called "seen-rule"))
       (n (vikix-rule-number rule))
       (w (win "Seen")))
  (check "a rule is found by its name, its number, and words only its text has"
         (and (eq rule (vikix-rule-called (princ-to-string n)))
              (eq (vikix-rule-called "seen breaks") (rule-of "seen breaks"))))
  (check "a name no rule has, a number past the end, words two rules have and no word at all are refused, each saying why"
         (and (search "No rule is called" (refusal "no such rule"))
              (search "There is no rule 9999" (refusal "9999"))
              (search "There is no rule 0" (refusal "0"))
              (search "say which by its number" (refusal "Seen"))
              (search "Which rule" (refusal ""))))
  (check "the list has every rule, with its number, its name and where it is written"
         (let ((listed (vikix-rules-list)))
           (and (= (length listed) (length *vikix-rules*))
                (equal (getf (nth (1- n) listed) :name) "seen-rule")
                (eql (getf (nth (1- n) listed) :number) n)
                (search "seeing.lisp:2" (getf (nth (1- n) listed) :from)))))
  (opens w)
  (check "it ran, and its line of the list says so"
         (and (= 1 (vikix-rule-runs rule)) (search "  1×  " (vikix-rule-listed rule))
              (not (search "never" (vikix-rule-listed rule)))))
  (let ((failures (vikix-rule-failures (rule-of "the matcher breaks"))))
    (multiple-value-bind (ran waiting) (vikix-rules-why w)
      (check "why: the rules that ran for the window, oldest first, each with what set it off and when"
             (and (equal (mapcar (lambda (e) (vikix-rule-name (third e))) ran) '("seen-rule" "seen-once"))
                  (every (lambda (e) (and (eq (second e) :open) (integerp (first e)) (null (fifth e)))) ran)))
      (check "why: a rule that matches it and runs on focus is waiting for that"
             (eq (second (find (rule-of "(note :seen-focus)") waiting :key #'first)) :on-focus))
      (check "why: a rule that doesn't match it isn't named"
             (not (find (rule-of "(note :other)") waiting :key #'first))))
    (check "looking is never a rule's failure, even with a matcher of yours that breaks"
           (= failures (vikix-rule-failures (rule-of "the matcher breaks")))))
  (check "why, in words: what ran, and what waits with its reason"
         (let ((text (vikix-rules-why-text w)))
           (and (search "Rules that ran for it" text) (search "on open" text)
                (search "it runs when the window gets the focus" text))))
  (let ((later (win "Seen")))
    (vikix-rule-switch rule nil)
    (multiple-value-bind (ran waiting) (vikix-rules-why later)
      (check "why: for a window no rule ran for, each rule that matches says why not"
             (and (null ran)
                  (eq (second (find rule waiting :key #'first)) :off-you)
                  (eq (second (find (vikix-rule-called "seen-once") waiting :key #'first)) :once-done))))
    (check "off, it doesn't run, and the list says by whom and until when"
           (and (null (member :seen (opens later)))
                (eq (vikix-rule-off-reason rule) :you)
                (search "switched off by you, until the next reload" (vikix-rule-state-line rule))))
    (vikix-rule-switch rule t)
    (check "on again, it runs" (member :seen (opens (win "Seen")))))
  (check "a window no rule is about: nothing ran, nothing matches"
         (search "No rule matches it either" (vikix-rules-why-text (win "NothingAboutThis" :title "x"))))
  (let ((busy (win "Seen")))
    (opens busy)
    (dotimes (i 30) (vikix-rules-focus-window busy nil))
    (check "a rule that runs at every look leaves one note, its latest, and what happened as the window opened is still there"
           (let ((notes (gethash busy *vikix-rule-notes*)))
             (and (= 1 (count :focus notes :key #'second))
                  (plusp (count :open notes :key #'second))
                  (<= (length notes) *vikix-rule-notes-kept*)))))
  (let ((breaks (rule-of "seen breaks")) (bw (win "SeenBreaks")))
    (dotimes (i 3) (opens bw))
    (check "why: a failure is noted on the window, with the error's words"
           (search "seen breaks" (or (fifth (first (vikix-rules-why bw))) "")))
    (check "a rule switched off after failing says so, and is named for vikix doctor"
           (and (eq (vikix-rule-off-reason breaks) :failures)
                (search "switched off after 3 failures" (vikix-rule-state-line breaks))
                (find "seen breaks" (vikix-rules-problems) :test #'search)))
    (vikix-rule-switch breaks t)
    (check "switched on again, it has three more tries and vikix doctor lets it be"
           (and (vikix-rule-on-p breaks) (zerop (vikix-rule-failures breaks))
                (not (find "seen breaks" (vikix-rules-problems) :test #'search)))))
  (check "a rule naming a workspace that isn't there is named for vikix doctor"
         (find "no workspace 77" (nth-value 1 (vikix-rules-problems)) :test #'search))
  (check "the list, in words: a header, a line a rule, and the reason under one that is off"
         (let ((text (with-output-to-string (*standard-output*) (vikix-rules-cli "list"))))
           (and (search "the rule, and where it is written" text)
                (search "(at \"09:00\" :name \"seen-at\" (say \"x\"))" text)
                (search "switched off after 3 failures" text)
                (search "since the last reload" text))))
  (check "the verbs, the matchers and the rules, each with its line"
         (let ((text (vikix-rules-verbs-text)))
           (and (search "(float &key width height x y corner own)" text)
                (search ":where FUNCTION" text) (search "(at-login VERB...)" text)
                (search "(note what)" text)
                (every (lambda (name) (search (format nil "  (~a" name) text)) (vikix-rule-verb-names)))))
  (check "test and apply take a rule for a window opening, and say so of any other"
         (search "isn't a rule for a window opening"
                 (princ-to-string (nth-value 1 (ignore-errors (vikix-rules-cli "test" "seen-at"))))))
  (check "a word vikix rules doesn't know is refused"
         (search "list, off, on, why, test, apply, forget or verbs"
                 (princ-to-string (nth-value 1 (ignore-errors (vikix-rules-cli "frobnicate")))))))
LISP

  # Remembering a window: how it is known, and your rules.lisp written,
  # a rule replaced where it stands, one taken out. Loaded last too.
  cat > "$t/remember.lisp" <<'LISP'
(in-package :stumpwm)
(defvar *named-frame* nil)
(defun vikix-remember-emacs-named-p (window) (declare (ignore window)) *named-frame*)   ; Emacs isn't asked here
(defun rules-file-text () (uiop:read-file-string (vikix-rules-file)))
(defun count-of (part text) (loop with n = 0 for at = (search part text) then (search part text :start2 (1+ at)) while at do (incf n) finally (return n)))

(check "a window is known by its class"
       (equal (vikix-remember-ways (win "Firefox" :res "Navigator" :title "Mozilla Firefox")) '(:class :instance :title)))
(check "by its instance when that is one of Vikix's own names"
       (eq (first (vikix-remember-ways (win "Alacritty" :res "vikix-nmtui" :title "nmtui"))) :instance))
(check "an Emacs frame by its class, and by its title when it has a name of its own"
       (and (eq (first (vikix-remember-ways (win "Emacs" :res "emacs" :title "notes.org"))) :class)
            (let ((*named-frame* t)) (eq (first (vikix-remember-ways (win "Emacs" :res "emacs" :title "Esploro"))) :title))))
(check "known by its title: the class too, the title whole, and a name that says both"
       (multiple-value-bind (match words) (vikix-remember-match (win "Emacs" :res "emacs" :title "Esploro") :title)
         (and (equal match '(:class "Emacs" :title "Esploro")) (equal words "Emacs \"Esploro\""))))
(check "a share of the monitor is a whole number of percent" (equal (vikix-remember-share 640 1280) "50%"))

;; The file: made when it isn't there, with its first lines.
(check "there is no rules.lisp yet" (not (probe-file (vikix-rules-file))))
(let ((rule (vikix-remember-write '(when-window (:class "Kept") :name "remembered: Kept" (workspace 2))
                                  "remembered: Kept" "Kept")))
  (check "remembering writes rules.lisp, under a dated comment, after its first lines"
         (let ((text (rules-file-text)))
           (and (eql 0 (search ";;;; rules.lisp" text)) (search "(in-package :stumpwm)" text)
                (ppcre:scan ";; Remembered \\d{4}-\\d\\d-\\d\\d: Kept\\n\\(when-window \\(:class \"Kept\"\\) :name \"remembered: Kept\" \\(workspace 2\\)\\)\\n" text))))
  (check "and the rule is loaded, as one of rules.lisp's, with its line"
         (and rule (equal (vikix-rule-owner rule) "rules.lisp")
              (equal (vikix-rule-text rule) "(when-window (:class \"Kept\") :name \"remembered: Kept\" (workspace 2))")
              (eql (vikix-rule-line rule) (vikix-line-at (rules-file-text) (search "(when-window (:class \"Kept\")" (rules-file-text)))))))
;; Lines of your own around it, then the same window remembered again.
(with-open-file (out (vikix-rules-file) :direction :output :if-exists :append)
  (format out "~%;; Mine, by hand.~%(when-window (:class \"Mine\")~%  (title \"mine\"))~%"))
(vikix-load-forms (vikix-rules-file) "rules.lisp")
(vikix-remember-write '(when-window (:class "Kept") :name "remembered: Kept" (workspace 5))
                      "remembered: Kept" "Kept")
(check "remembering the same window again replaces its rule where it stood, and leaves your own lines alone"
       (let ((text (rules-file-text)))
         (and (= 1 (count-of "remembered: Kept" text)) (= 1 (count-of ";; Remembered " text))
              (search "(workspace 5)" text) (not (search "(workspace 2)" text))
              (< (search "remembered: Kept" text) (search ";; Mine, by hand." text))
              (search (format nil "(when-window (:class \"Mine\")~%  (title \"mine\"))") text)
              (= 1 (count "remembered: Kept" *vikix-rules* :key #'vikix-rule-name :test #'equal)))))
;; Forgetting.
(check "a rule written elsewhere can't be forgotten, and the refusal says where it is"
       (search "not in your rules.lisp"
               (princ-to-string (nth-value 1 (ignore-errors (vikix-rules-forget (vikix-rule-called "seen-rule")))))))
(check "forgetting takes a rule of your own out of the file, lines and all, and off the desktop"
       (and (vikix-rules-forget (rule-of "(title \"mine\")"))
            (not (search "(:class \"Mine\")" (rules-file-text)))
            (search ";; Mine, by hand." (rules-file-text))
            (null (rule-of "(title \"mine\")"))
            (search "remembered: Kept" (rules-file-text))))
(check "and a remembered one with its comment"
       (progn (with-output-to-string (*standard-output*) (vikix-rules-cli "forget" "remembered: Kept"))
              (and (not (search "Kept" (rules-file-text)))
                   (not (search ";; Remembered" (rules-file-text)))
                   (null (find "remembered: Kept" *vikix-rules* :key #'vikix-rule-name :test #'equal))
                   (search "(in-package :stumpwm)" (rules-file-text)))))
;; A file that can't be read is only added to.
(with-open-file (out (vikix-rules-file) :direction :output :if-exists :supersede)
  (format out "(in-package :stumpwm)~%(when-window (:class \"Open\"~%"))
(let ((rule (vikix-remember-write '(when-window (:class "Late") :name "remembered: Late" (workspace 1))
                                  "remembered: Late" "Late")))
  (check "a rules.lisp that can't be read is only added to, nothing of it lost"
         (and (search "(when-window (:class \"Open\"" (rules-file-text))
              (search "remembered: Late" (rules-file-text))))
  (check "and forgetting says it can't read the file"
         (search "can't be read"
                 (princ-to-string (nth-value 1 (ignore-errors (vikix-rules-forget rule)))))))
(defun remember-checks-ran () t)
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
         (and (= 17 (length *vikix-rules*)) (rule-of \"After\")))

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

  ;; Seeing and steering them: its own rules and checks, in a file.
  (handler-bind ((warning #'muffle-warning))
    (vikix-load-forms \"$t/seeing.lisp\" \"seeing.lisp\"))
  (check \"the checks of seeing and steering ran to their end\" (fboundp 'refusal))
  (handler-bind ((warning #'muffle-warning))
    (vikix-load-forms \"$t/remember.lisp\" \"remember.lisp\"))
  (check \"the checks of remembering ran to their end\" (fboundp 'remember-checks-ran))
  (format t \"~a~%\" (if (zerop *fails*) \"no-screen: ok\" \"no-screen: failed\")))" 2>&1) || true
  if grep -q '^no-screen: ok$' <<<"$out"; then
    said+=("matching, mistakes found at load with their line, one rule after a second load, failing rules switched off at the third, :once, :focus and :close, plugins' rules, the list, off and on, why a window is where it is, a rule remembered, replaced and forgotten in rules.lisp")
  else
    echo "$out" | grep -v '^;\|^$' | tail -25
    echo "FAIL: the rules without a screen"
    fail=1
  fi
}

no_screen

# --- Without a screen: the clock, the battery, login, workspaces ---------------

no_screen_timed() {
  command -v sbcl >/dev/null && [ -f "$ql/setup.lisp" ] || return 0
  sbcl --noinform --non-interactive --load "$ql/setup.lisp" --eval '(ql:quickload :stumpwm :silent t)' >/dev/null 2>&1 || return 0
  mkdir -p "$t/home2" "$t/state2"

  cat > "$t/timed.lisp" <<'LISP'
(in-package :stumpwm)
(at "09:00" (push :nine *ran*))
(at "10:00" :weekdays (push :weekday *ran*))
(at "11:00" :weekends (push :weekend *ran*))
(at "11:30" :on (:mon :thu) (push :mon-thu *ran*))
(at "12:00" :late t (push :late-t *ran*))
(at "13:00" :late nil (push :late-nil *ran*))
(at ("15:00" "16:30") :name "twice a day" (push :twice *ran*))
(each 30 :minutes (push :each *ran*))
(when-battery-below 20 (push :low *ran*))
(when-charging (push :charging *ran*))
(when-on-battery (push :on-battery *ran*))
(at-login (push :login *ran*))
(when-workspace 3 (push :three *ran*))
(when-workspace ("mail" 5) (push :mail-or-five *ran*))
(at "18:00" (workspace 2))

;; Eight mistakes, each found as the file loads.
(at "25:00" (push :never *ran*))
(at "09:00" :on (:monday) (push :never *ran*))
(at "09:00" :sometimes (push :never *ran*))
(each 0 :minutes (push :never *ran*))
(each 5 :days (push :never *ran*))
(when-battery-below 150 (push :never *ran*))
(at-login)
(when-workspace 3.5 (push :never *ran*))
LISP

  cat > "$t/timed-test.lisp" <<'LISP'
(in-package :stumpwm)
(defvar *fails* 0)
(defmacro check (name form)
  `(unless (ignore-errors ,form) (incf *fails*) (format t "FAIL: ~a~%" ,name)))
(defvar *ran* '())
(defvar *clock* 0)
(defvar *battery* nil)                    ; (LEVEL CHARGER), or nil: no battery
(setf *vikix-rules-now* (lambda () *clock*)
      *vikix-rules-battery* (lambda () (and *battery* (values (first *battery*) (second *battery*)))))
;; October 2026: the 5th is a Monday, the 10th a Saturday.
(defun clock (day hour minute &optional (second 0))
  (setf *clock* (encode-universal-time second minute hour day 10 2026)))
(defun tick () (setf *ran* '()) (vikix-rules-tick) (reverse *ran*))
(defun ran (what) (and (member what (tick)) t))
(defun file () (uiop:getenv "RULES_TEST_FILE"))
(defun load-rules () (handler-bind ((warning #'muffle-warning)) (vikix-load-forms (file) "timed.lisp")))
(defun reports () (format nil "~{~a~%~}" (mapcar #'uiop:read-file-string
                                                 (directory (merge-pathnames "errors/*.txt" (vikix-state-dir))))))
(defun rule-of (text) (find text *vikix-rules* :key #'vikix-rule-text :test #'search))
(defun group-like (number name) (make-instance 'group :number number :name name))
(defun goes-to (number name) (setf *ran* '()) (vikix-rules-focus-group (group-like number name) nil) (reverse *ran*))

(clock 5 8 0)
(load-rules)
(check "fifteen rules and Vikix's own two, the eight mistakes left out" (= 17 (length *vikix-rules*)))
(check "each mistake is said in plain words"
       (every (lambda (words) (search words (reports)))
              '("A rule's time is written" "A rule's :on is a day" ":SOMETIMES isn't an option of an at rule"
                "A rule repeats each whole number" "so many :minutes or :hours" "A battery rule's mark"
                "This rule does nothing" "A workspace rule names a workspace")))

;; Login
(check "at-login runs at the first tick" (equal (tick) '(:login)))
(check "and not at the next" (null (tick)))
(check "nor after a reload" (progn (load-rules) (null (tick))))
(eval '(at-login (push :login-2 *ran*)))
(check "one added during the login runs once, at the next tick" (and (equal (tick) '(:login-2)) (null (tick))))
(eval '(at-login :name "fails" (error "an at-login rule that fails")))
(check "one that fails isn't tried again at every tick"
       (progn (tick) (tick) (= 1 (vikix-rule-failures (find "fails" *vikix-rules* :key #'vikix-rule-key :test #'equal)))))

;; The clock: at
(check "nothing before its time" (progn (clock 5 8 59 40) (not (ran :nine))))
(check "at its time" (progn (clock 5 9 0 10) (ran :nine)))
(check "once" (progn (clock 5 9 0 40) (not (ran :nine))))
(check "not after a reload" (progn (load-rules) (clock 5 9 1 10) (not (ran :nine))))
(check "what ran is written down" (probe-file (merge-pathnames "rules/ran" (vikix-state-dir))))
(check "nor after StumpWM starts again (it reads what was written)"
       (progn (clrhash *vikix-rules-ran*) (setf *vikix-rules-ran-read* nil) (load-rules)
              (clock 5 9 2 10) (not (ran :nine))))
(check ":weekdays on a Monday" (progn (clock 5 10 0 5) (ran :weekday)))
(check ":weekends not on a Monday" (progn (clock 5 11 0 5) (not (ran :weekend))))
(check ":on (:mon :thu) on a Monday" (progn (clock 5 11 30 5) (ran :mon-thu)))
(check "a list of times: each of them" (and (progn (clock 5 15 0 5) (ran :twice)) (progn (clock 5 16 30 5) (ran :twice))
                                            (progn (clock 5 16 31 5) (not (ran :twice)))))
(check "the next day again" (progn (clock 6 9 0 20) (ran :nine)))
(check ":on (:mon :thu) not on a Tuesday" (progn (clock 6 11 30 5) (not (ran :mon-thu))))
(check ":weekends on a Saturday, :weekdays not" (and (progn (clock 10 10 0 5) (not (ran :weekday)))
                                                     (progn (clock 10 11 0 5) (ran :weekend))))
;; Asleep over its time
(check "40 minutes late after a sleep: it runs" (progn (clock 7 8 50) (tick) (clock 7 9 40) (ran :nine)))
(check "90 minutes late: it doesn't, that day" (progn (clock 8 8 50) (tick) (clock 8 10 30) (and (not (ran :nine)) (not (ran :nine)))))
(check "and runs the day after, on time" (progn (clock 9 9 0 5) (ran :nine)))
(check ":late t runs however late, that day" (progn (clock 7 11 50) (tick) (clock 7 20 0) (ran :late-t)))
(check ":late nil doesn't run ten minutes late" (progn (clock 7 12 59) (tick) (clock 7 13 10) (not (ran :late-nil))))
(check "and runs on time" (progn (clock 8 13 0 20) (ran :late-nil)))
;; A new rule
(clock 12 14 0)
(eval '(at "09:30" :late t (push :new *ran*)))
(check "a rule written after its time doesn't run for the time gone by" (and (not (ran :new)) (not (ran :new))))
(check "and runs the next day" (progn (clock 13 9 30 10) (ran :new)))

;; each
(clock 14 8 0)
(eval '(each 10 :minutes :name "ten" (push :ten *ran*)))
(check "each: not when first seen" (not (ran :ten)))
(check "nor a moment early" (progn (clock 14 8 9 50) (not (ran :ten))))
(check "after its time" (progn (clock 14 8 10 0) (ran :ten)))
(check "then counted from when it ran" (and (progn (clock 14 8 19 50) (not (ran :ten))) (progn (clock 14 8 20 10) (ran :ten))))
(check "after a long sleep: once" (progn (clock 14 13 0) (and (ran :ten) (not (ran :ten)))))
(check "a reload doesn't start the count again"
       (progn (eval '(each 10 :minutes :name "ten" (push :ten *ran*))) (clock 14 13 10 5) (ran :ten)))

;; The battery and the charger
(check "no battery: nothing" (progn (setf *battery* nil) (null (intersection (tick) '(:low :charging :on-battery)))))
(check "the first look sets nothing off" (progn (setf *battery* '(60 nil)) (null (intersection (tick) '(:charging :on-battery)))))
(check "under the mark, off the charger: once" (progn (setf *battery* '(19 nil)) (and (ran :low) (not (ran :low)))))
(check "lower still: not again" (progn (setf *battery* '(12 nil)) (not (ran :low))))
(check "the charger in: when-charging" (progn (setf *battery* '(12 t)) (equal (intersection (tick) '(:low :charging :on-battery)) '(:charging))))
(check "the charger out, still under: when-on-battery, and the warning again"
       (progn (setf *battery* '(12 nil)) (let ((r (tick))) (and (member :on-battery r) (member :low r)))))
(check "charged above it and down again: again"
       (progn (setf *battery* '(50 nil)) (tick) (setf *battery* '(19 nil)) (ran :low)))
(check "on the charger under the mark: nothing" (progn (setf *battery* '(50 t)) (tick) (setf *battery* '(10 t)) (not (ran :low))))

;; Workspaces
(check "when-workspace by number" (and (equal (goes-to 3 "3") '(:three)) (null (goes-to 4 "4"))))
(check "by name, and by a list" (and (equal (goes-to 7 "mail") '(:mail-or-five)) (equal (goes-to 5 "5") '(:mail-or-five))))

;; Care
(check "a window's verb in a rule with no window fails cleanly"
       (progn (clock 15 18 0 5) (tick) (= 1 (vikix-rule-failures (rule-of "18:00")))))
(check "a rule switched off doesn't run"
       (progn (setf (vikix-rule-on-p (rule-of "\"09:00\"")) nil) (clock 16 9 0 5) (not (ran :nine))))
(check "they are in the list with the others, each saying what sets it off"
       (let ((listed (vikix-rules-list)))
         (and (= (length listed) (length *vikix-rules*))
              (subsetp '(:at :each :battery-below :login :workspace) (mapcar (lambda (r) (getf r :event)) listed)))))
(check "no ticker without a screen" (null *vikix-rules-timer*))
(format t "~a~%" (if (zerop *fails*) "timed: ok" "timed: failed"))
LISP

  local out
  out=$(HOME="$t/home2" VIKIX_STATE="$t/state2" RULES_TEST_FILE="$t/timed.lisp" DISPLAY='' sbcl --noinform --non-interactive --load "$ql/setup.lisp" \
    --eval '(ql:quickload :stumpwm :silent t)' \
    --eval '(in-package :stumpwm)' \
    --eval "(handler-bind ((warning #'muffle-warning)) (load \"$here/config/stumpwm/vikix/errors.lisp\") (load \"$here/config/stumpwm/vikix/rules.lisp\") (load \"$t/timed-test.lisp\"))" 2>&1) || true
  if grep -q '^timed: ok$' <<<"$out"; then
    said+=("the clock (at, its days, late after a sleep, a new rule, each), the battery and the charger, at-login once, when-workspace")
  else
    echo "$out" | grep -v '^;\|^$' | tail -25
    echo "FAIL: the timed rules without a screen"
    fail=1
  fi
}

no_screen_timed

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
(defvar *rules-test-three* 0)
(when-workspace 3 (incf *rules-test-three*))
LISP
  # Once a login: a line in a file each time it runs.
  echo "(at-login (run \"echo login >> $t/login.txt\"))" >> "$home/.stumpwm.d/rules.lisp"
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

  check "Vikix, rules.lisp and user.lisp all gave their rules: $(ask '(princ (length *vikix-rules*))')" test "$(ask '(princ (length *vikix-rules*))')" = 16
  check "each knows whose it is" yes '(equal (remove-duplicates (mapcar (function vikix-rule-owner) *vikix-rules*) :test (function equal)) (list "Vikix" "rules.lisp" "user.lisp"))'

  logins() { sleep 0.5; wc -l < "$t/login.txt" 2>/dev/null || echo 0; }
  check "the ticker is running, in whole seconds" yes '(and *vikix-rules-timer* (member *vikix-rules-timer* *timer-list*) (every (lambda (tm) (integerp (timer-time tm))) *timer-list*))'
  ask '(vikix-rules-tick)' >/dev/null
  check "at-login ran at the first tick: $(logins)" test "$(logins)" = 1
  ask '(vikix-rules-tick)' >/dev/null
  check "and once: $(logins)" test "$(logins)" = 1

  win Plain
  check "a window no rule is about opens where you are, tiled" yes "(and (eql 1 (group-number (window-group $(the Plain)))) (typep $(the Plain) (quote tile-window)))"

  # Vikix's own rules, which were hooks: Lazarus's windows, vikix learn's panes.
  by_title() { echo "(find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal))"; }
  win lazarus "Project Options"
  check "Vikix's rule floats a Lazarus window that isn't the main one, at its own size" \
    yes "(let ((w $(by_title "Project Options"))) (multiple-value-bind (ax ay aw ah) (vikix-rule-area (current-head)) (declare (ignore ax ay)) (and (typep w (quote float-window)) (not (and (= (xlib:drawable-width (window-parent w)) (floor (* 60 aw) 100)) (= (xlib:drawable-height (window-parent w)) (floor (* 60 ah) 100)))))))"
  win lazarus "Lazarus IDE v3.6 - project1"
  check "and leaves its main window in the tiles" yes "(typep $(by_title "Lazarus IDE v3.6 - project1") (quote tile-window))"
  ask "(progn (delete-window $(by_title "Project Options")) (delete-window $(by_title "Lazarus IDE v3.6 - project1")))" >/dev/null; sleep 0.7
  printf '#!/bin/sh\nsleep 300\n' > "$t/learn"; chmod +x "$t/learn"
  ask "(setf *vikix-learn-command* \"$t/learn\" *vikix-terminal* \"env LIBGL_ALWAYS_SOFTWARE=1 alacritty\")" >/dev/null
  ask '(run-commands "vikix-learn-open c")' >/dev/null
  for _ in $(seq 1 40); do
    yes '(= 2 (count-if (lambda (w) (member (window-class w) (list "vikix-learn-lesson" "vikix-learn-shell") :test (function equal))) (screen-windows (current-screen))))' && break
    sleep 0.25
  done
  sleep 0.5
  check "Vikix's rule puts vikix learn's lesson and its shell each in its half: $(ask '(princ (mapcar (lambda (w) (list (window-class w) (frame-number (window-frame w)))) (group-windows (first *vikix-learn-panes*))))')" \
    yes '(destructuring-bind (group lesson shell from) *vikix-learn-panes* (declare (ignore from)) (flet ((pane (class) (find class (group-windows group) :key (function window-class) :test (function equal)))) (and (pane "vikix-learn-lesson") (pane "vikix-learn-shell") (eq (window-frame (pane "vikix-learn-lesson")) lesson) (eq (window-frame (pane "vikix-learn-shell")) shell))))'
  ask '(progn (let ((lesson (vikix-learn-find-open))) (run-commands "vikix-learn-close") (when lesson (delete-window lesson))) (setf *vikix-terminal* "alacritty"))' >/dev/null; sleep 0.7
  go 1

  win ToTwo
  check "workspace: the window is on workspace 2: $(group_of ToTwo)" test "$(group_of ToTwo)" = 2
  check "and you stay where you were: $(here_is)" test "$(here_is)" = 1
  check "StumpWM put it there as it opened, before it showed" yes '(member (list "ToTwo" 2) *rules-test-placed* :test (function equal))'
  check "the rule ran once and noted the window" yes "(and (= 1 (vikix-rule-runs (third *vikix-rules*))) (gethash $(the ToTwo) *vikix-rule-notes*))"

  win Follow
  check ":follow goes along: $(here_is)" test "$(here_is)" = 3
  check "with the window focused" yes '(equal (window-class (current-window)) "Follow")'
  check "when-workspace ran on arriving at 3: $(ask '(princ *rules-test-three*)')" test "$(ask '(princ *rules-test-three*)')" = 1
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
  check "a mistake costs only its own rule: $(ask '(princ (length *vikix-rules*))')" test "$(ask '(princ (length *vikix-rules*))')" = 17

  # A reload: exactly what the files say, and no window moved.
  ask "(move-window-to-group $(the Named) (find 5 (screen-groups (current-screen)) :key (function group-number)))" >/dev/null
  ask '(loadrc)' >/dev/null
  answers 60 || true
  check "after a reload: the files' rules, one of each: $(ask '(princ (length *vikix-rules*))')" test "$(ask '(princ (length *vikix-rules*))')" = 16
  ask '(vikix-rules-tick)' >/dev/null
  check "at-login doesn't run again at a reload: $(logins)" test "$(logins)" = 1
  check "one ticker after a reload, not two" yes "(= 1 (count (quote vikix-rules-tick) *timer-list* :key (function timer-function)))"
  check "and no window was moved: $(group_of Named) $(group_of ToTwo)" test "$(group_of Named) $(group_of ToTwo)" = "5 2"
  check "and the failures counted start again" yes '(zerop (reduce (function +) (mapcar (function vikix-rule-failures) *vikix-rules*)))'

  # StumpWM starting again with the windows there: they stay where they are.
  kill "$wm_pid" 2>/dev/null || true
  for _ in $(seq 1 20); do kill -0 "$wm_pid" 2>/dev/null || break; sleep 0.25; done
  start_wm || { echo "FAIL: the test StumpWM didn't start again, with its windows there"; diagnose; fail=1; return 0; }
  sleep 1
  check "StumpWM started again: the windows that were there set no rule off: $(ask '(princ (list (length (screen-windows (current-screen))) (reduce (function +) (mapcar (function vikix-rule-runs) *vikix-rules*))))')" \
    yes '(and (> (length (screen-windows (current-screen))) 5) (zerop (reduce (function +) (mapcar (function vikix-rule-runs) *vikix-rules*))))'
  ask '(vikix-rules-tick)' >/dev/null
  check "nor does at-login run again when StumpWM alone starts again, in the same login: $(logins)" test "$(logins)" = 1
  # vikix rules, the command: it only asks the test StumpWM. The windows
  # are there and no rule has run for them (StumpWM has just started again).
  rules() { HOME=$home VIKIX_SWANK_PORT=$port "$here/bin/vikix-rules" "$@" 2>&1 || true; }
  titled() { echo "(find \"$1\" (screen-windows (current-screen)) :key (function window-title) :test (function equal))"; }
  local out rc
  out=$(rules)
  check "vikix rules lists them, numbered, each with where it is written: $(head -2 <<<"$out")" \
    grep -q '^ 3  on .*(when-window (:class "ToTwo") (workspace 2))   rules.lisp:2$' <<<"$out"
  ask "(move-window-to-group $(titled ToTwo) (find 1 (screen-groups (current-screen)) :key (function group-number)))" >/dev/null
  out=$(rules why ToTwo)
  check "why: a window that was there before the rule says so: $out" grep -q 'the window was here before the rule was' <<<"$out"
  out=$(rules test 3)
  check "test says what a rule would do with the windows open now: $out" \
    bash -c "grep -q '^ToTwo \"ToTwo\" (workspace 1, window' <<<'$out' && grep -q 'Nothing was done: vikix rules apply 3 does it' <<<'$out'"
  check "and does nothing: $(ask "(princ (group-number (window-group $(titled ToTwo))))")" yes "(eql 1 (group-number (window-group $(titled ToTwo))))"
  out=$(rules apply 3)
  check "apply runs the rule on the windows open now: $out" grep -q '^    ran     3  (when-window (:class "ToTwo") (workspace 2))' <<<"$out"
  check "and the window went where the rule sends it" yes "(eql 2 (group-number (window-group $(titled ToTwo))))"
  out=$(rules why ToTwo)
  check "why, afterwards: the rule ran for it, by apply: $out" grep -q 'on apply  3  (when-window (:class "ToTwo") (workspace 2))' <<<"$out"
  out=$(rules off 3)
  check "off switches a rule off: $out" yes '(not (vikix-rule-on-p (third *vikix-rules*)))'
  check "and the list says by whom, and until when" grep -q 'switched off by you, until the next reload (vikix rules on 3)' <<<"$(rules)"
  rules on 3 >/dev/null
  check "on switches it on again" yes '(vikix-rule-on-p (third *vikix-rules*))'
  rc=0; out=$(HOME=$home VIKIX_SWANK_PORT=$port "$here/bin/vikix-rules" off 99 2>&1) || rc=$?
  check "a rule that isn't there is refused, in the desktop's own words, and the command fails: $rc $out" \
    bash -c "[ $rc != 0 ] && grep -q 'There is no rule 99: there are 16' <<<'$out'"
  out=$(rules why NoSuchClass)
  check "why for a class no window has names the classes there are: $out" grep -q 'No window has the class "NoSuchClass".*ToTwo' <<<"$out"
  out=$(rules off "\") (run-shell-command \"touch $t/pwned")
  sleep 0.3
  check "a name with a quote and Lisp in it is only a name: $out" bash -c "[ ! -e '$t/pwned' ] && grep -q 'No rule is called' <<<'$out'"
  check "verbs lists them with their arguments" grep -q '^  (workspace target &key follow)$' <<<"$(rules verbs)"
  check "a word it doesn't know is refused" grep -q 'unknown: vikix rules frobnicate' <<<"$(rules frobnicate)"
  check "vikix doctor would name the rule whose workspace isn't there" \
    yes '(find "no workspace 42" (nth-value 1 (vikix-rules-problems)) :test (function search))'
  check "Super+m has the rules, and the command behind it is there" \
    yes '(and (find (quote vikix-rules) *vikix-menu* :key (function second)) (get-command-structure (quote vikix-rules) nil) t)'
  check "a rule's own ^ shows in a message or a menu, where ^ starts a colour" yes '(equal (vikix-rules-carets "(:like \"^a$\")") "(:like \"^^a$\")")'
  # The menu itself, its first entry picked with a key: why the window in
  # front is where it is.
  if command -v xdotool >/dev/null; then
    ask "(focus-all $(titled ToTwo))" >/dev/null; sleep 0.5
    ask '(run-commands "vikix-rules")' >/dev/null &   # waits in its menu
    sleep 2
    xdotool key Return
    wait $! 2>/dev/null || true
    sleep 0.5
    check "the menu's first entry says why the window in front is where it is: $(ask '(princ (screen-last-msg (current-screen)))' | cut -c1-200)" \
      yes '(search "Rules that ran for it" (princ-to-string (screen-last-msg (current-screen))))'
  else
    echo "rules: no xdotool here; the menu's key left out"
  fi

  # Remembering a window (Super+Shift+t): the rule for where it is, written
  # into rules.lisp after a snapshot (a stand-in notes what it was told).
  printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/snaps"\n' "$t" > "$t/snap"; chmod +x "$t/snap"
  ask "(setf *vikix-snapshot-command* \"$t/snap\")" >/dev/null
  remembered() { ask "(princ (vikix-rules-print (vikix-remember-rule $1 ${2:-})))"; }
  check "Super+Shift+t is the key" yes '(equal (lookup-key *top-map* (kbd "s-T")) "vikix-remember")'
  out=$(remembered "$(titled ToTwo)")
  check "a tiled window is known by its class, and remembered on its workspace: $out" \
    test "$out" = '(when-window (:class "ToTwo") :name "remembered: ToTwo" (workspace 2))'
  go 1
  win Kept
  ask "(let ((*vikix-rule-window* $(the Kept))) (vikix-verb-float :width \"40%\" :height \"30%\" :x \"10%\" :y \"20%\"))" >/dev/null; sleep 0.5
  out=$(remembered "$(the Kept)")
  check "a floating window with its size and place, as shares of the monitor: $out" \
    test "$out" = '(when-window (:class "Kept") :name "remembered: Kept" (workspace 1) (float :width "40%" :height "30%" :x "10%" :y "20%"))'
  geometry() { ask "(let ((p (window-parent $1))) (princ (list (xlib:drawable-x p) (xlib:drawable-y p) (xlib:drawable-width p) (xlib:drawable-height p))))"; }
  local before
  before=$(geometry "$(the Kept)")
  ask "(multiple-value-bind (form name) (vikix-remember-rule $(the Kept)) (vikix-remember-write form name \"Kept\"))" >/dev/null
  check "it is written into rules.lisp, after a snapshot that says what for: $(cat "$t/snaps" 2>/dev/null)" \
    bash -c "grep -q ':name \"remembered: Kept\"' '$home/.stumpwm.d/rules.lisp' && grep -qx 'before: a rule for Kept' '$t/snaps'"
  check "and loaded, as one of rules.lisp's" yes '(equal (vikix-rule-owner (vikix-rule-called "remembered: Kept")) "rules.lisp")'
  ask "(delete-window $(the Kept))" >/dev/null; sleep 0.7
  win Kept kept-again
  check "a window like it then opens floating, at the same size and place: $before, $(geometry "$(titled kept-again)")" \
    bash -c "[ -n '$before' ] && [ '$before' = '$(geometry "$(titled kept-again)")' ]"
  win Mid
  ask "(let ((*vikix-rule-window* $(the Mid))) (vikix-verb-float :width \"50%\" :height \"50%\"))" >/dev/null; sleep 0.5
  out=$(remembered "$(the Mid)")
  check "one floating in the middle has no place written, float's own: $out" \
    test "$out" = '(when-window (:class "Mid") :name "remembered: Mid" (workspace 1) (float :width "50%" :height "50%"))'
  out=$(remembered "$(the Mid)" ":workspace-only t")
  check "its workspace only, when asked: $out" test "$out" = '(when-window (:class "Mid") :name "remembered: Mid" (workspace 1))'
  # Two windows of one class, each with an instance of its own (as an
  # Alacritty started with --class): the instance tells them apart.
  win "Shared,inst-a" share-a
  win "Shared,inst-b" share-b
  out=$(ask "(let ((a $(titled share-a)) (b $(titled share-b))) (princ (list (first (vikix-remember-ways a)) (equal (window-class a) (window-class b)) (equal (window-res a) (window-res b)))))")
  check "two windows of a class with instances of their own are known by the instance (way, same class, same instance): $out" \
    bash -c "case '$out' in '(INSTANCE T NIL)'|'(CLASS NIL T)') true ;; *) false ;; esac"
  # The key itself, and the menu's first choice: write it.
  if command -v xdotool >/dev/null; then
    ask "(focus-all $(the Mid))" >/dev/null; sleep 0.5
    xdotool key super+shift+t
    sleep 2
    xdotool key Return
    sleep 1.5
    check "the key shows the rule and, on yes, writes it: $(grep -c . "$home/.stumpwm.d/rules.lisp") lines, $(tail -1 "$home/.stumpwm.d/rules.lisp")" \
      grep -qxF '(when-window (:class "Mid") :name "remembered: Mid" (workspace 1) (float :width "50%" :height "50%"))' "$home/.stumpwm.d/rules.lisp"
    check "with its dated comment above it" bash -c "grep -B1 -F 'remembered: Mid' '$home/.stumpwm.d/rules.lisp' | grep -qE '^;; Remembered [0-9]{4}-[0-9]{2}-[0-9]{2}: Mid\$'"
  else
    echo "rules: no xdotool here; the key that remembers a window left out"
  fi
  out=$(rules forget "remembered: Kept")
  check "vikix rules forget takes a rule out of rules.lisp and off the desktop: $out" \
    bash -c "! grep -q 'remembered: Kept' '$home/.stumpwm.d/rules.lisp' && grep -q 'Taken out of' <<<'$out'"
  check "the rules written by hand around it are still there" grep -q '(when-window (:class "Follow") (workspace 3 :follow t))' "$home/.stumpwm.d/rules.lisp"
  check "and the desktop has let it go" yes '(null (find "remembered: Kept" *vikix-rules* :key (function vikix-rule-name) :test (function equal)))'
  out=$(rules forget FromUser)
  check "a rule of user.lisp isn't the desktop's to take out: $out" grep -q 'is written in user.lisp:[0-9]*, not in your rules.lisp' <<<"$out"
  check "and user.lisp is as it was" grep -q 'FromUser' "$home/.stumpwm.d/user.lisp"

  # The plugins at Vikix's pin say what they want of windows as rules (they
  # were hooks): inbox's note box, agent-waiting's note cleared by a look.
  # Needs a copy of the plugins repository (the dev machine's, or
  # VIKIX_TEST_PLUGINS_REPO); GitHub's runners have none.
  local plugins_repo pin
  plugins_repo=${VIKIX_TEST_PLUGINS_REPO:-$real_home/src/vikix-plugins}
  pin=$(sed -n 's/^PLUGINS_COMMIT=\${VIKIX_PLUGINS_COMMIT:-\([0-9a-f]*\)}.*/\1/p' "$here/bin/vikix-plugin")
  if [ -d "$plugins_repo/.git" ] && git -C "$plugins_repo" cat-file -e "$pin^{commit}" 2>/dev/null; then
    mkdir -p "$t/plugins"
    git -C "$plugins_repo" show "$pin:inbox/plugin.lisp" > "$t/plugins/inbox.lisp"
    git -C "$plugins_repo" show "$pin:agent-waiting/plugin.lisp" > "$t/plugins/agent-waiting.lisp"
    ask "(let ((*vikix-errors-ask* nil)) (let ((*vikix-plugin* \"inbox\")) (vikix-load-forms \"$t/plugins/inbox.lisp\" \"inbox/plugin.lisp\")) (let ((*vikix-plugin* \"agent-waiting\")) (vikix-load-forms \"$t/plugins/agent-waiting.lisp\" \"agent-waiting/plugin.lisp\")))" >/dev/null
    check "the plugins' rules are in the list, as theirs: $(ask '(princ (remove-if-not (lambda (o) (eql 0 (search "plugin " o))) (mapcar (function vikix-rule-owner) *vikix-rules*)))')" \
      yes '(equal (remove-if-not (lambda (o) (eql 0 (search "plugin " o))) (mapcar (function vikix-rule-owner) *vikix-rules*)) (list "plugin inbox" "plugin agent-waiting"))'
    check "and no plugin hangs a function of its own on StumpWM's hooks" \
      yes '(not (or (member (quote inbox-float-box) *new-window-hook*) (member (quote agent-waiting-clear) *focus-window-hook*)))'
    go 1
    win Emacs "Note to inbox"
    check "inbox's rule floats the note's box, 760 by 360, a little above the middle: $(geometry "$(by_title "Note to inbox")")" \
      yes "(let* ((w $(by_title "Note to inbox")) (p (window-parent w))) (multiple-value-bind (ax ay aw ah) (vikix-rule-area (current-head)) (and (typep w (quote float-window)) (= (xlib:drawable-width p) 760) (= (xlib:drawable-height p) 360) (= (xlib:drawable-x p) (+ ax (floor (- aw 760) 2))) (= (xlib:drawable-y p) (+ ay (floor (* 22 ah) 100))))))"
    # The box closed before the focus is moved about: the pointer rests on
    # it, and a floating window under the pointer with the focus given to
    # a tile is a bug of its own (bugs.md, the focus bouncing).
    ask "(delete-window $(by_title "Note to inbox"))" >/dev/null; sleep 0.7
    win Waits
    win Other
    ask "(let ((file (merge-pathnames (princ-to-string (xlib:window-id (window-xwin $(the Waits)))) *agent-waiting-dir*))) (ensure-directories-exist file) (with-open-file (out file :direction :output :if-exists :supersede) (write-line \"ask\" out)))" >/dev/null
    check "an agent's note is there while its window isn't looked at" yes "(probe-file (merge-pathnames (princ-to-string (xlib:window-id (window-xwin $(the Waits)))) *agent-waiting-dir*))"
    ask "(focus-all $(the Waits))" >/dev/null; sleep 0.5
    check "agent-waiting's rule: looking at the window clears its note" yes "(not (probe-file (merge-pathnames (princ-to-string (xlib:window-id (window-xwin $(the Waits)))) *agent-waiting-dir*)))"
    for _ in 1 2 3; do
      ask "(focus-all $(the Other))" >/dev/null; ask "(focus-all $(the Waits))" >/dev/null
    done
    sleep 0.4
    check "a rule that runs at every look leaves one note on the window, not one a look: $(ask "(princ (mapcar (function second) (gethash $(the Waits) *vikix-rule-notes*)))")" \
      yes "(= 1 (count :focus (gethash $(the Waits) *vikix-rule-notes*) :key (function second)))"
    ask '(vikix-remove-rules :owner-prefix "plugin ")' >/dev/null
    check "and they go when the plugins do: $(ask '(princ (remove-duplicates (mapcar (function vikix-rule-owner) *vikix-rules*) :test (function equal)))')" yes '(notany (lambda (o) (eql 0 (search "plugin " o))) (mapcar (function vikix-rule-owner) *vikix-rules*))'
    said+=("the plugins' rules at the pin (inbox's box, agent-waiting's note)")
  else
    echo "(the plugins' rules: no copy of the plugins repository here at the pin; skipped)"
  fi

  check "nothing asked, nothing failed, in the whole run" test -z "$(grep -il 'debugger\|unhandled' "$t/wm.log" 2>/dev/null)"
  [ "$fail" = 0 ] || diagnose
  [ "$fail" = 0 ] && said+=("and on a screen: workspace before the window shows, float by shares of the monitor, tile, title, fullscreen, sticky, dialog, vikix rules (the list, why, test, apply, off and on, forget), a window remembered with its key and reopened where it was, a failing rule, a reload, a restart, the ticker, at-login once")
  return 0
}

[ -n "${RULES_SKIP_SCREEN:-}" ] || on_screen

[ "$fail" = 0 ] || exit 1
echo "rules: ${said[*]:-nothing could be tested here}"
