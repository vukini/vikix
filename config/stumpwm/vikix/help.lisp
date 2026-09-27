;;;; help.lisp — finding your way: the keys, and every command.
;;;;
;;;; Both are searchable menus: type to narrow the list, Enter to run the
;;;; highlighted entry, Escape to close. So the help is also a launcher —
;;;; you can do the thing from the list you looked it up in.
;;;;
;;;;   vikix-keys      (s-F1)  every Vikix key, from *vikix-bindings*
;;;;   vikix-commands          every StumpWM command, with its description
;;;;   vikix-prefix-keys       StumpWM's own keys, after the prefix Ctrl+t
;;;;   describe-key      (StumpWM's own) press a key, see what it does

(in-package :stumpwm)

(defparameter *vikix-key-names*
  '(("RET" . "Return") ("TAB" . "Tab") ("ESC" . "Escape") ("Print" . "Print Screen")
    ("period" . ".") ("equal" . "=")
    ("XF86AudioRaiseVolume"  . "Volume-up key")
    ("XF86AudioLowerVolume"  . "Volume-down key")
    ("XF86AudioMute"         . "Mute key")
    ("XF86AudioMicMute"      . "Mic-mute key")
    ("XF86MonBrightnessUp"   . "Brightness-up key")
    ("XF86MonBrightnessDown" . "Brightness-down key"))
  "Key names as StumpWM writes them, and as they are printed on the keyboard.")

(defun vikix-pretty-key (key)
  "\"s-C-RET\" -> \"Super+Ctrl+Return\". Modifiers are only read at the
front, so a name like Brightness-up is never mistaken for one."
  (let ((mods "") (rest key))
    (loop for (prefix . word) in '(("s-" . "Super+") ("C-" . "Ctrl+") ("M-" . "Alt+") ("S-" . "Shift+"))
          do (loop while (and (> (length rest) 2)
                              (string= prefix rest :end2 2))
                   do (setf mods (concatenate 'string mods word)
                            rest (subseq rest 2))))
    ;; A capital letter means Shift is held: "s-H" is Super+Shift+h.
    (when (and (= (length rest) 1) (upper-case-p (char rest 0)))
      (setf mods (concatenate 'string mods "Shift+")
            rest (string-downcase rest)))
    (concatenate 'string mods
                 (or (cdr (assoc rest *vikix-key-names* :test #'string=)) rest))))

(defun vikix-keys-table ()
  "The rows of the key help: (label command). Built from *vikix-bindings*,
plus the workspace keys, which keys.lisp binds in a loop. The key column
is as wide as the longest key, so no key runs into its description."
  (let* ((rows (append
                (mapcar (lambda (b)
                          (list (vikix-pretty-key (first b)) (third b) (second b)))
                        *vikix-bindings*)
                '(("Super+1 ... Super+9" "Go to workspace 1-9" "grouplist")
                  ("Super+Ctrl+1 ... 9" "Send window to workspace 1-9" "gmove")
                  ("Ctrl+t then ?" "StumpWM's own keys (after the prefix)" "vikix-prefix-keys"))))
         (width (reduce #'max rows :key (lambda (row) (length (first row))))))
    (mapcar (lambda (row)
              (list (format nil "~va  ~a" width (first row) (second row))
                    (third row)))
            rows)))

(defcommand vikix-prefix-keys () ()
  "Show StumpWM's own keys: the ones pressed after the prefix key (Ctrl+t)."
  (display-bindings-for-keymaps (list *escape-key*) *root-map*))

(defcommand vikix-keys () ()
  "Show every Vikix key; pick one to run it."
  (let ((choice (select-from-menu (current-screen) (vikix-keys-table)
                                  "Keys (type to search): ")))
    (when choice
      (run-commands (second choice)))))

(defun vikix-first-line (string)
  (if string (subseq string 0 (or (position #\Newline string) (length string))) ""))

(defun vikix-commands-table ()
  "The rows of the command list: (label command-name), sorted by name."
  (let (rows)
    (maphash (lambda (symbol command)
               (declare (ignore command))
               (let ((name (string-downcase (symbol-name symbol))))
                 (push (list (format nil "~28a ~a" name
                                     (vikix-first-line
                                      (documentation symbol 'function)))
                             name)
                       rows)))
             *command-hash*)
    (sort rows #'string< :key #'second)))

(defcommand vikix-commands () ()
  "Show every StumpWM command with its description; pick one to run it."
  (let ((choice (select-from-menu (current-screen) (vikix-commands-table)
                                  "Commands (type to search): ")))
    (when choice
      (run-commands (second choice)))))
