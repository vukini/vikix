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
#
# A float written as a delay to run-with-timer fails here too: it stops
# the event loop of StumpWM (errors.lisp mends such a timer when it meets
# one; this keeps them from being written).
#
# With no files given, it then loads keys.lisp and help.lisp and checks the
# rule for keys (each modifier means one thing: keys.lisp): none of Vikix's
# keys breaks it, it finds the ones that would, Super+Shift+digit sends a
# window to a workspace, and the keys from before the rule go at a reload.
# Then the
# key card (Super+/): every key in *vikix-bindings* is in a group and on
# the card, at any screen size; a key inside a map (:map "layout m") is in
# the help right under the key that opens it, and off the card, which is
# full; a wrong :map is refused as the file loads; and a reload sets which-key-mode rather
# than toggling it. Against the real StumpWM when Quicklisp has it (the
# layer must then compile without a warning), else against stand-ins.

set -euo pipefail
export VIKIX_SWANK_PORT=9   # never the live desktop's Swank: vikix eval from a test goes nowhere
export EMACS_SOCKET_NAME=/nonexistent/emacs-server   # never the live desktop's Emacs: emacsclient from a test goes nowhere
unset VIKIX_AGENT VIKIX_DIR VIKIX_STATE   # the desktop session's: from an agent's shell they'd point a test at the real ~/vikix and state, and hide the keys
cd "$(dirname "$0")/.."
command -v sbcl >/dev/null || { echo "FAIL no sbcl (xbps-install sbcl, or apt install sbcl)"; exit 1; }

if [ "$#" -gt 0 ]; then
  files=("$@")
else
  mapfile -t files < <(find config lib -name '*.lisp' | sort)
fi

# --no-userinit: ~/.sbclrc may load Quicklisp and more, which this doesn't need.
read_rc=0
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
           (float-delays (form file start)
             ;; (run-with-timer 0.3 ...) stops the event loop of StumpWM: the
             ;; time it makes is a float, where a whole number is declared.
             ;; 3/10 is the way to write it.
             (when (consp form)
               (when (and (symbolp (first form))
                          (string= (symbol-name (first form)) "RUN-WITH-TIMER")
                          (consp (rest form))
                          (or (floatp (second form))
                              (and (consp (cddr form)) (floatp (third form)))))
                 (format t "FAIL ~a, line ~d: (run-with-timer ~a ...): a float as a delay stops the event loop of StumpWM; write it as a fraction, 3/10 for 0.3~%"
                         file (line-at file start) (second form))
                 (incf failed))
               (loop for rest on form
                     do (float-delays (first rest) file start)
                     while (consp (rest rest)))))
           (check (file)
             (with-open-file (in file)
               (let ((*package* (make-package (gensym "VIKIX-TEST") :use (list :cl)))
                     (*read-eval* nil)
                     (fixes 0))
                 (loop
                   (peek-char t in nil nil)   ; past the blanks: the line given is the form'"'"'s
                   (let ((start (file-position in)))
                     (handler-case
                         (let ((form (read in nil in)))
                           (when (eq form in) (return))
                           (incf forms)
                           (float-delays form file start))
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
  --end-toplevel-options -- "${files[@]}" || read_rc=$?
[ "$#" -gt 0 ] && exit "$read_rc"

# --- the key card and which-key (help.lisp) ------------------------------------------------
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
ql=${VIKIX_QUICKLISP:-$HOME/quicklisp}/setup.lisp
layer=config/stumpwm/vikix
real=0
if [ -f "$ql" ] && sbcl --noinform --no-sysinit --no-userinit --non-interactive --load "$ql" \
     --eval '(handler-case (ql:quickload :stumpwm :silent t) (error () (sb-ext:exit :code 2)))' >/dev/null 2>&1; then
  real=1
fi
if [ "$real" = 1 ]; then
  against="the real StumpWM"
  cat > "$t/prelude.lisp" <<EOF
(load "$ql")
(ql:quickload :stumpwm :silent t)
(in-package :stumpwm)
;; The layer compiles against the real StumpWM without a warning: no
;; unknown function or variable, no wrong number of arguments.
(let ((problems '()))
  (handler-bind ((warning (lambda (w)
                            (unless (typep w 'sb-kernel:redefinition-warning)
                              (push (remove #\Newline (princ-to-string w)) problems))
                            (muffle-warning w))))
    (with-compilation-unit ()
      (dolist (f '("config/stumpwm/init.lisp" "$layer/theme.lisp" "$layer/registry.lisp" "$layer/keys.lisp" "$layer/help.lisp"))
        (compile-file f :output-file (format nil "$t/~a.fasl" (pathname-name f))))))
  (dolist (p problems) (format t "FAIL compiling the layer: ~a~%" p)));; No X here: binding a key mustn't try to tell the X server.
(setf (fdefinition 'sync-keys) (lambda () nil))
EOF
else
  against="stand-ins for StumpWM (no StumpWM in Quicklisp here)"
  # Stand-ins for the parts of StumpWM that keys.lisp and help.lisp use as they load.
  cat > "$t/prelude.lisp" <<'EOF'
(defpackage :xlib (:use :cl) (:export #:display-finish-output #:change-property #:delete-property #:keysym->keycodes #:keycode->keysym))
(defpackage :stumpwm (:use :cl))
(in-package :stumpwm)
(defvar *top-map* (make-hash-table :test 'equal))
(defvar *key-press-hook* '())
(defun kbd (k) k)
(defun define-key (map key command) (setf (gethash key map) command))
(defmacro add-hook (hook fn) `(setf ,hook (adjoin ,fn ,hook)))
(defmacro remove-hook (hook fn) `(setf ,hook (remove ,fn ,hook)))
(defmacro defcommand (name args prompts &body body)
  (declare (ignore prompts))
  `(defun ,name ,args ,@(if (stringp (first body)) (rest body) body)))
EOF
fi
cat > "$t/check.lisp" <<EOF
(in-package :stumpwm)
(defvar *failed* 0)
(defun fail (fmt &rest args) (incf *failed*) (format t "FAIL ~?~%" fmt args))
(load "$layer/registry.lisp")
(load "$layer/keys.lisp")
(load "$layer/help.lisp")
(load "$layer/help.lisp")             ; a reload
(unless (= 1 (count 'which-key-mode-key-press-hook *key-press-hook*))
  (fail "which-key-mode should be on, once, after a reload; hooks: ~s" *key-press-hook*))
(vikix-which-key nil)
(when (member 'which-key-mode-key-press-hook *key-press-hook*)
  (fail "(vikix-which-key nil) should turn which-key-mode off"))
(vikix-which-key t)
(unless (equal (second (assoc "s-slash" *vikix-bindings* :test #'string=)) "vikix-keys-card")
  (fail "Super+/ should be in *vikix-bindings*, running vikix-keys-card"))
(unless (string= (vikix-pretty-key "s-slash") "Super+/")
  (fail "s-slash should read Super+/, not ~s" (vikix-pretty-key "s-slash")))
;; Shift+grave is the keysym asciitilde: the help should name the key on
;; the keyboard. (code-char 96) is the grave, which this shell string can't hold.
(let ((want (format nil "Super+Shift+~c" (code-char 96))))
  (unless (string= (vikix-pretty-key "s-asciitilde") want)
    (fail "s-asciitilde should read ~a, not ~s" want (vikix-pretty-key "s-asciitilde"))))
(unless (equal (second (assoc "s-grave" *vikix-bindings* :test #'string=)) "next")
  (fail "Super+grave should be in *vikix-bindings*, running next"))
;; The rule for keys (keys.lisp): none of Vikix's own breaks it.
(dolist (p (vikix-key-problems))
  (fail "~a (~a) breaks the rule for keys: ~a" (first p) (second p) (third p)))
;; And the rule finds the keys that would.
(loop for (key command owner breaks) in
      '(("s-w"      "exec firefox"            nil nil)      ; one of the six main apps
        ("s-P"      "exec vikix-project pick" nil t)        ; another app on Super+Shift
        ("s-M-p"    "exec vikix-project pick" nil nil)
        ("s-M-E"    "exec esploro --new"      nil nil)
        ("s-g"      "toggle-gaps"             nil t)        ; a switch on plain Super
        ("s-C-g"    "toggle-gaps"             nil nil)
        ("s-C-w"    "exec firefox"            nil t)        ; an app on Super+Ctrl
        ("s-C-Left" "vikix-move left"         nil t)        ; moving a window with Ctrl
        ("s-S-Left" "vikix-move left"         nil nil)
        ("s-H"      "vikix-move left"         nil nil)
        ("s-M"      "vikix-webapp mail"       :webapp t)
        ("s-M-m"    "vikix-webapp mail"       :webapp nil)
        ("s-j"      "next-meeting-join"       :plugin t)
        ("s-M-j"    "next-meeting-join"       :plugin nil)
        ("s-M-I"    "inbox-quote"             :plugin nil)
        ("Print"    "exec vikix-screenshot area clip" nil nil)   ; no Super: its own ways
        ("s-F3"     "my-command"              nil nil))     ; yours, and nothing the rule knows
      unless (eq (and (vikix-key-problem key command owner) t) breaks)
        do (fail "~a running ~a should ~:[keep~;break~] the rule for keys: ~s"
                 key command breaks (vikix-key-problem key command owner)))
(loop for (key layer) in '(("s-w" :super) ("s-H" :shift) ("s-S-Left" :shift) ("s-asciitilde" :shift)
                           ("s-M-e" :alt) ("s-M-E" :alt) ("s-C-a" :ctrl) ("Print" nil) ("XF86AudioMute" nil))
      unless (eq (vikix-key-layer key) layer)
        do (fail "~a should be on ~s, is on ~s" key layer (vikix-key-layer key)))
;; Super+Shift+digit sends the window to that workspace. With no keyboard
;; to ask (here), the keys are a US keyboard's.
(unless (equal *vikix-workspace-send-keys*
               '("s-parenright" "s-exclam" "s-at" "s-numbersign" "s-dollar" "s-percent" "s-asciicircum" "s-ampersand" "s-asterisk" "s-parenleft"))
  (fail "Super+Shift+0 ... 9 should be bound for a US keyboard here: ~s" *vikix-workspace-send-keys*))
;; A key Vikix had before the rule goes at a reload, while it still runs
;; what Vikix gave it; one given something else since stays.
(when (and (fboundp 'lookup-key) (fboundp 'undefine-key))
  (define-key *top-map* (kbd "s-E") "exec spacefm")
  (define-key *top-map* (kbd "s-P") "exec my-own-program")
  (define-key *top-map* (kbd "s-C-3") "gmove 3")
  (load "$layer/registry.lisp")
  (load "$layer/keys.lisp")
  (when (lookup-key *top-map* (kbd "s-E")) (fail "the old key Super+Shift+e should be let go at a reload"))
  (when (lookup-key *top-map* (kbd "s-C-3")) (fail "the old key Super+Ctrl+3 should be let go at a reload"))
  (unless (equal (lookup-key *top-map* (kbd "s-P")) "exec my-own-program")
    (fail "a key of yours on one of the old keys should stay"))
  (unless (equal (lookup-key *top-map* (kbd "s-exclam")) "vikix-send 1")
    (fail "Super+Shift+1 should send the window to workspace 1: ~s" (lookup-key *top-map* (kbd "s-exclam"))))
  (unless (equal (lookup-key *top-map* (kbd "s-S-Left")) "vikix-move left")
    (fail "Super+Shift+Left should move the window left")))
;; Every one of Vikix's own keys is in a named group: Other is for yours.
(dolist (e (vikix-key-entries))
  (when (string= (fourth e) "Other")
    (fail "~a (~a) is in no group: add its command to *vikix-key-groups*" (first e) (third e))))
;; The registry (registry.lisp): every command once, and the two lists made from it.
(let ((names (mapcar (lambda (c) (getf c :name)) *vikix-commands*)))
  (unless (= (length names) (length (remove-duplicates names)))
    (fail "two commands of the registry have one name"))
  (unless (equal *vikix-bindings* (vikix-registry-bindings))
    (fail "after a reload *vikix-bindings* should be the registry's keys, each once"))
  (unless (= (length *vikix-bindings*) (length (remove-duplicates (mapcar #'first *vikix-bindings*) :test #'equal)))
    (fail "a key is written for two commands in registry.lisp")))
(let ((menu (vikix-registry-menu)))
  (unless (equal (first (first menu)) "Welcome: first steps")
    (fail "the menu should start with the welcome: ~a" (first (first menu))))
  (unless (equal (second (car (last menu))) 'vikix-power)
    (fail "the menu should end with Power: ~s" (car (last menu))))
  (unless (equal (assoc "Search every document (guides, projects, notes, man pages)" menu :test #'string=)
                 '("Search every document (guides, projects, notes, man pages)" (run-shell-command "vikix-docs pick") nil "Help"))
    (fail "a command that runs a program is (run-shell-command ...) in the menu, under its :label, with its section"))
  (unless (equal (third (assoc "Printers" menu :test #'string=)) "system-config-printer")
    (fail "a command's :needs is its menu entry's"))
  (unless (member '("Install a program" (vikix-in-terminal "vikix pkg add") nil "Start") menu :test #'equal)
    (fail "a command with :do is that form in the menu"))
  ;; The menu's sections come in *vikix-menu-groups*' order, each whole.
  (let ((sections (remove-duplicates (mapcar #'fourth menu) :test #'equal :from-end t)))
    (unless (equal sections (remove-if-not (lambda (g) (member g sections :test #'equal)) *vikix-menu-groups*))
      (fail "the menu's sections should be in *vikix-menu-groups*' order, each in one piece: ~s" sections))))
;; A mistake in a command is an error as its file loads, saying what.
(loop for (form want) in '(((define-vikix-command t1 "x" :rnu "exec x" :key "s-M-F12") ":rnu is no option")
                           ((define-vikix-command t2 "x" :key "s-M-F12") "it does nothing")
                           ((define-vikix-command t3 "x" :do (print 1) :key "s-M-F12") "a key runs a command")
                           ((define-vikix-command t4 "x" :run "exec x" :menu "Nowhere") "is no part of the menu")
                           ((define-vikix-command t5 "x" :run "exec x") "nothing would ever run it")
                           ((define-vikix-command t6 :run "exec x" :key "s-M-F12") "its words")
                           ((define-vikix-command t7 "x" :run "exec x" :map "nowhere x") "no command opens a map called nowhere")
                           ((define-vikix-command t8 "x" :run "exec x" :map "layout") "a map's name and the key in it")
                           ((define-vikix-command t9 "x" :do (print 1) :map "layout x") "with :map it needs :run")
                           ((define-vikix-command t10 "x" :run "exec x" :key "s-C-SPC x") ":key is one key"))
      do (let ((said (handler-case (progn (eval form) "no error") (error (e) (princ-to-string e)))))
           (unless (search want said)
             (fail "~s should be refused, saying ~s: ~a" form want said))))
(when (vikix-command 't1) (fail "a refused command is in the registry all the same"))
;; A key inside a map (registry.lisp, :map "layout m"): in *vikix-bindings*
;; as the two keys, read as "Super+Ctrl+Space, m", on the card as "then m"
;; right under the key that opens the map and in its group, and not bound
;; in *top-map* (the map reads it itself).
(let ((main (find "vikix-main" *vikix-bindings* :key #'second :test #'equal :from-end t)))
  (unless (equal (first main) "s-C-SPC m")
    (fail "vikix-main should be in *vikix-bindings* a second time as \"s-C-SPC m\": ~s" main)))
(unless (equal (vikix-pretty-key "s-C-SPC m") "Super+Ctrl+Space, m")
  (fail "s-C-SPC m should read Super+Ctrl+Space, m: ~s" (vikix-pretty-key "s-C-SPC m")))
(unless (equal (vikix-command-keys (vikix-command 'main)) '("s-C-m" "s-C-SPC m"))
  (fail "main's keys should be its own and the map's: ~s" (vikix-command-keys (vikix-command 'main))))
(unless (equal (vikix-command-keys (vikix-command 'viri)) '("s-C-SPC s"))
  (fail "viri's only key should be the map's: ~s" (vikix-command-keys (vikix-command 'viri))))
(let* ((entries (vikix-key-entries))
       (opener (position "Super+Ctrl+Space" entries :key #'first :test #'equal))
       (after (and opener (subseq entries (1+ opener) (+ opener 10)))))
  (unless opener (fail "the layout map's opener should be among the help's entries"))
  (unless (and after (every (lambda (e) (eql 0 (search "then " (first e)))) after)
               (equal (fourth (first after)) "Windows & frames")
               (equal (mapcar #'first after) '("then m" "then s" "then g" "then t" "then w" "then h" "then u" "then r" "then Space")))
    (fail "the layout map's keys should follow its opener in the help as \"then m\" ..., in its group and in the order its words name them: ~s" (mapcar #'first after))))
(when (find-if (lambda (e) (or (eql 0 (search "then " (first e))) (equal (third e) "vikix-keys-card"))) (vikix-card-entries))
  (fail "the card's rows should leave the keys inside a map out, and its own key: the card is full"))
(when (fboundp 'lookup-key)
  (when (ignore-errors (lookup-key *top-map* (kbd "m")))
    (fail "m alone should not be bound in *top-map*: a map's key is the map's")))
;; One written in user.lisp (after keys.lisp) is bound and in the menu at
;; once, before Power; written again, it is there once.
(defvar *vikix-menu* (vikix-registry-menu))
(dotimes (i 2)
  (define-vikix-command my-notes "My notes"
    :run "exec my-notes" :key "s-M-F12" :menu "Work" :label "Notes of mine"))
(unless (equal (if (fboundp 'lookup-key) (lookup-key *top-map* (kbd "s-M-F12")) (gethash "s-M-F12" *top-map*))
               "exec my-notes")
  (fail "a command defined after the keys were bound should have its key bound"))
(unless (= 1 (count "s-M-F12" *vikix-bindings* :key #'first :test #'equal))
  (fail "its key should be in *vikix-bindings*, once"))
(unless (and (= 1 (count "Notes of mine" *vikix-menu* :key #'first :test #'equal))
             (equal (first (car (last *vikix-menu* 2))) "Notes of mine")
             (equal (second (car (last *vikix-menu*))) 'vikix-power))
  (fail "its menu entry should be there once, just before Power: ~s" (last *vikix-menu* 2)))
;; (Taken out again: the key card below is measured with Vikix's keys alone.)
(setf *vikix-bindings* (remove "s-M-F12" *vikix-bindings* :key #'first :test #'equal)
      *vikix-commands* (remove 'my-notes *vikix-commands* :key (lambda (c) (getf c :name))))
;; What agents are offered: only what is marked, and nothing that isn't refused.
(unless (and (vikix-agent-commands) (every (lambda (c) (getf c :agent)) (vikix-agent-commands)))
  (fail "agents should be offered the commands marked :agent, and no others"))
(dolist (c (vikix-agent-commands))
  (when (or (getf c :do) (eql 0 (search "exec " (getf c :run))))
    (fail "~(~a~) is for agents, and starts a program or runs a form: only StumpWM commands are" (getf c :name))))
(loop for (name want) in '(("terminal" "is not for agents") ("no-such-command" "there is no command") ("power" "is not for agents"))
      do (unless (search want (vikix-agent-run name))
           (fail "an agent asking for ~a should be refused (~a): ~a" name want (vikix-agent-run name))))
;; Keys pushed from user.lisp land in a group too.
(push '("s-F2" "exec obsidian" "Obsidian") *vikix-bindings*)
(push '("s-F3" "my-command" "Mine") *vikix-bindings*)
(push '("s-F4" "exec zotero" "Zotero" "Reading") *vikix-bindings*)
(push '("s-C-p" "exec env FOO=1 vikix-screenshot area clip" "Shot") *vikix-bindings*)
(loop for (key want) in '(("Super+F2" "Apps") ("Super+F3" "Other") ("Super+F4" "Reading")
                          ("Super+Ctrl+p" "Screenshots & recording"))
      for got = (fourth (find key (vikix-key-entries) :key #'first :test #'string=))
      unless (equal got want) do (fail "~a should be in ~a, is in ~s" key want got))
(let ((names (mapcar #'first (vikix-card-groups))))
  (unless (equal (last names 2) '("Reading" "Other"))
    (fail "a group of your own should come last but for Other: ~s" names)))
;; No key lost: each on the card once, at any monitor size, in columns no
;; taller than the monitor and, side by side, no wider (1366x768 and up;
;; smaller monitors get cut descriptions, and may still run over).
(let ((want (sort (mapcar (lambda (e) (list (first e) (second e))) (vikix-card-entries))
                  #'string< :key #'first)))
  (loop for (rows chars) in '((50 250) (32 175) (100 500) (25 140) (12 90) (5 40))
        do (multiple-value-bind (columns key-width desc-width)
               (vikix-card-layout (vikix-card-groups) rows chars)
             (let ((got (loop for c in columns append
                              (loop for line in c
                                    when (and (consp line) (eq (first line) :key))
                                      collect (rest line)))))
               (unless (equal (sort got #'string< :key #'first) want)
                 (fail "the card at ~dx~d lost or doubled keys: ~d of ~d"
                       rows chars (length got) (length want))))
             (when (find-if (lambda (c) (> (length c) (max 3 rows))) columns)
               (fail "a column at ~dx~d is taller than ~d lines" rows chars rows))
             (when (and (>= chars 170)          ; a laptop's 1366x768 and up
                        (> (- (* (length columns) (+ key-width 2 desc-width 4)) 4) chars))
               (fail "the card at ~dx~d is wider than the monitor: ~d columns of ~d"
                     rows chars (length columns) (+ key-width 2 desc-width)))
             (dolist (c columns)
               (when (eq (car (last c)) :blank)
                 (fail "a column ends in a blank line at ~dx~d" rows chars))
               (unless (and (consp (first c)) (eq (first (first c)) :heading))
                 (fail "a column at ~dx~d doesn't start with its group's name" rows chars))))))
;; The lines themselves: no more than fit, and every key in them.
(let ((lines (vikix-card-strings 45 240)))
  (unless (<= (length lines) 45)
    (fail "the card is ~d lines, more than the 45 that fit" (length lines)))
  (dolist (e (vikix-card-entries))
    (unless (find-if (lambda (l) (search (first e) l)) lines)
      (fail "~a isn't on the card" (first e))))
  (unless (search "Super+/" (first lines))
    (fail "the card's first line should name its own key, since it isn't a row: ~a" (first lines))))
(format t "key card: ~d keys in ~d groups, against $against~%"
        (length (vikix-key-entries)) (length (vikix-card-groups)))
(sb-ext:exit :code (if (zerop *failed*) 0 1))
EOF
card_rc=0
out=$(sbcl --noinform --no-sysinit --no-userinit --non-interactive \
        --load "$t/prelude.lisp" --load "$t/check.lisp" 2>&1) || card_rc=$?
if grep -q -e '^FAIL' -e '^key card:' <<<"$out"; then
  grep -e '^FAIL' -e '^key card:' <<<"$out"
else
  echo "FAIL the key card check didn't run:"; grep -v "^[0-9]*: " <<<"$out" | tail -15; card_rc=1
fi
grep -q '^FAIL' <<<"$out" && card_rc=1
# Scripts without sbcl at hand read Vikix's keys out of registry.lisp with
# grep (vikix-webapp, one migration): what they find is what the registry has.
here=$(pwd)   # the checkout: this script went there at its start
found=$(VIKIX_DIR="$here" bash -c 'eval "$(sed -n "/^vikix_keys() {/,/^}/p" "$VIKIX_DIR/bin/vikix-webapp")"; vikix_keys' | grep -vxE 's-[1-9]' | sort)
real=$("$here/lib/registry.sh" keys | cut -f1 | grep '^s-' | grep -v ' ' | sort)   # a key inside a map ("s-C-SPC m") is no key of theirs
if [ -z "$real" ] || [ "$found" != "$real" ]; then
  echo "FAIL the keys vikix-webapp reads from registry.lisp aren't the registry's: $(diff <(echo "$found") <(echo "$real") | grep '^[<>]' | tr '\n' ' ')"
  card_rc=1
fi
[ "$read_rc" = 0 ] && [ "$card_rc" = 0 ]
