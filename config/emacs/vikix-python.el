;;; vikix-python.el --- Python in Emacs, as an IDE  -*- lexical-binding: t; -*-

;; What makes a Python file in Emacs an IDE, on what Vikix installs
;; (`vikix add python': ruff, pytest, uv, pyright, ipython). Vikix keeps
;; this file current (it is ~/.local/share/vikix/emacs/vikix-python.el, a
;; link into the Vikix checkout), and your config loads it when it's
;; there:
;;
;;   (load (expand-file-name "~/.local/share/vikix/emacs/vikix-python") t t)
;;
;; Opening a .py file turns on `vikix-python-mode', which finds the
;; project's venv by itself (the nearest .venv up from the file, as uv
;; makes it; else ~/dev/python/.venv, the one JupyterLab runs on) and
;; gives it to everything started from the buffer: the language server
;; (pyright, through eglot), the REPL, the tests, ruff. A project that
;; declares its dependencies (pyproject.toml, requirements.txt) and has no
;; .venv gets none, not the shared one: C-c p v makes its own. The mode line
;; says which: Py[.venv], Py[dev], or Py[no venv]. ruff's findings are
;; shown beside pyright's (flymake), and the buffer is formatted with
;; ruff when saved (C-c p F turns that off here). Under C-c p:
;;
;;   C-c p t   test the function at point (pytest FILE::name)
;;   C-c p T   test this file
;;   C-c p P   test the project
;;   C-c p r   run this file
;;   C-c p s   the REPL (ipython, or python, from the venv)
;;   C-c p f   format the buffer with ruff
;;   C-c p F   format on save: on or off, for this buffer
;;   C-c p c   ruff check the project
;;   C-c p v   the venv: which one; none, offers to make it (uv venv)
;;   C-c p i   the IDE: code left, the REPL and the tests' output right
;;   C-c p d   the offline docs (~/dev/python/docs, in the browser)
;;   C-c p q   close the project: its files (saved first, if you say so),
;;             the REPL, the tests' window and pyright; then the frame
;;
;; The tests and runs go to a compilation buffer, so a failing line is a
;; link (Enter on it, M-g M-n for the next). A key for what isn't
;; installed says what to do instead of failing. Nothing here changes
;; your python.el or eglot settings: the venv is given per buffer.

;;; Code:

(require 'subr-x)
(require 'cl-lib)
(require 'compile)
(require 'python)

(require 'flymake)

(defvar eglot-managed-mode-hook)

(defgroup vikix-python nil "Python in Emacs, as an IDE, on Vikix." :group 'python)

(defcustom vikix-python-shared-venv "~/dev/python/.venv"
  "The venv for a file in no project of its own: the one `vikix add python' makes."
  :type 'directory)

(defcustom vikix-python-format-on-save t
  "Format the buffer with ruff when it is saved (C-c p F changes it for a buffer)."
  :type 'boolean)

(defcustom vikix-python-docs "~/dev/python/docs"
  "The offline docs' folder (python-3.N-docs-html inside), from `vikix add python'."
  :type 'directory)

(defconst vikix-python-roots
  '(".venv" "pyproject.toml" "setup.py" "setup.cfg" "requirements.txt" ".git")
  "What marks a project's root: the nearest folder up with one of these.")

(defconst vikix-python-project-files
  '("pyproject.toml" "uv.lock" "setup.py" "setup.cfg" "requirements.txt")
  "What says a project wants a venv of its own: the shared one isn't used then.")

(defconst vikix-python--sum
  (when load-file-name
    (with-temp-buffer
      (insert-file-contents load-file-name)
      (secure-hash 'sha256 (current-buffer))))
  "This file's checksum as it was loaded.
`vikix update' reloads it when it changed.")

;; --- where things are ----------------------------------------------------

(defun vikix-python-root (&optional dir)
  "The project's root for DIR (the buffer's folder): see `vikix-python-roots'.
The folder itself when nothing up from it marks a project."
  (let* ((dir (file-name-as-directory (expand-file-name (or dir default-directory))))
         (found (locate-dominating-file
                 dir (lambda (d)
                       (cl-some (lambda (m) (file-exists-p (expand-file-name m d)))
                                vikix-python-roots)))))
    (file-name-as-directory (expand-file-name (or found dir)))))

(defun vikix-python--venv-p (dir)
  "Whether DIR is a venv: it has bin/python."
  (and dir (file-executable-p (expand-file-name "bin/python" dir))))

(defun vikix-python--project-p (root)
  "Whether ROOT declares its dependencies (see `vikix-python-project-files')."
  (cl-some (lambda (f) (file-exists-p (expand-file-name f root)))
           vikix-python-project-files))

(defun vikix-python-venv (&optional root)
  "The venv for ROOT (the buffer's project).
ROOT/.venv; else, for a folder that declares no dependencies (a script,
the examples), the shared one; else nil, since a project's packages
aren't in the shared venv and C-c p v makes its own."
  (let* ((root (or root (vikix-python-root)))
         (own (expand-file-name ".venv" root))
         (shared (expand-file-name vikix-python-shared-venv)))
    (cond ((vikix-python--venv-p own) (directory-file-name own))
          ((and (not (vikix-python--project-p root)) (vikix-python--venv-p shared))
           (directory-file-name shared)))))

(defvar-local vikix-python--venv nil "The buffer's venv, as the mode found it.")
(defvar-local vikix-python--root nil "The buffer's project root, as the mode found it.")

(defun vikix-python--venv-name ()
  "The venv as the mode line says it: .venv, dev (the shared one), or no venv."
  (cond ((null vikix-python--venv) "no venv")
        ((string= vikix-python--venv
                  (directory-file-name (expand-file-name vikix-python-shared-venv)))
         "dev")
        (t ".venv")))

(defun vikix-python--bin (program)
  "PROGRAM's path: the venv's when it has it, else PATH's, else nil."
  (let ((own (and vikix-python--venv
                  (expand-file-name (concat "bin/" program) vikix-python--venv))))
    (cond ((and own (file-executable-p own)) own)
          ((executable-find program)))))

(defun vikix-python--python ()
  "The interpreter: the venv's python, else python3."
  (or (vikix-python--bin "python") "python3"))

(defun vikix-python--environment (venv)
  "`process-environment' with VENV's bin first on PATH and VIRTUAL_ENV set."
  (let ((bin (expand-file-name "bin" venv)))
    (append (list (concat "PATH=" bin path-separator (or (getenv "PATH") ""))
                  (concat "VIRTUAL_ENV=" venv))
            (cl-remove-if (lambda (e) (string-match-p "\\`\\(PATH\\|VIRTUAL_ENV\\)=" e))
                          process-environment))))

(defun vikix-python--give-venv ()
  "Give the buffer its venv: PATH for what it starts, the REPL's root."
  (when vikix-python--venv
    (setq-local process-environment (vikix-python--environment vikix-python--venv))
    (setq-local exec-path (cons (expand-file-name "bin" vikix-python--venv) exec-path))
    (setq-local python-shell-virtualenv-root vikix-python--venv)
    ;; Your interpreter (ipython, say) when the venv has it; else its python.
    ;; The system's ipython would run with the system's packages, not the venv's.
    (unless (file-executable-p (expand-file-name (concat "bin/" python-shell-interpreter)
                                                 vikix-python--venv))
      (setq-local python-shell-interpreter "python")
      (setq-local python-shell-interpreter-args "-i"))))

;; --- ruff: findings beside pyright's, and formatting ---------------------

(defvar-local vikix-python--ruff-process nil "The ruff check running for this buffer.")

(defun vikix-python--ruff-flymake (report-fn &rest _)
  "A flymake backend: ruff check on the buffer's text.
REPORT-FN is given its findings."
  (let ((ruff (vikix-python--bin "ruff")))
    (if (not ruff)
        (funcall report-fn nil)   ; no ruff: nothing to say, and no error
      (when (process-live-p vikix-python--ruff-process)
        (kill-process vikix-python--ruff-process))
      (let ((source (current-buffer))
            (name (or (buffer-file-name) "stdin.py")))
        (save-restriction
          (widen)
          (setq vikix-python--ruff-process
                (make-process
                 :name "vikix-ruff" :noquery t :connection-type 'pipe
                 :buffer (generate-new-buffer " *vikix-ruff*")
                 :command (list ruff "check" "--quiet" "--output-format" "concise"
                                "--stdin-filename" name "-")
                 :sentinel
                 (lambda (proc _event)
                   (when (memq (process-status proc) '(exit signal))
                     (unwind-protect
                         (if (with-current-buffer source
                               (eq proc vikix-python--ruff-process))
                             (funcall report-fn
                                      (vikix-python--ruff-diagnostics
                                       (process-buffer proc) source))
                           (flymake-log :warning "an older ruff check's answer dropped"))
                       (kill-buffer (process-buffer proc)))))))
          (process-send-region vikix-python--ruff-process (point-min) (point-max))
          (process-send-eof vikix-python--ruff-process))))))

(defun vikix-python--ruff-diagnostics (output source)
  "The diagnostics for SOURCE in ruff's OUTPUT buffer.
Concise lines: FILE:LINE:COL: CODE text."
  (let (diags)
    (with-current-buffer output
      (goto-char (point-min))
      (while (re-search-forward
              "^.*?:\\([0-9]+\\):\\([0-9]+\\): \\([A-Z]+[0-9]*\\) \\(.*\\)$" nil t)
        (let* ((line (string-to-number (match-string 1)))
               (col (string-to-number (match-string 2)))
               (code (match-string 3))
               (text (match-string 4))
               (region (flymake-diag-region source line col))
               ;; E9 is a syntax error, F a bug (undefined name, unused import),
               ;; the rest style.
               (type (cond ((string-prefix-p "E9" code) :error)
                           ((string-prefix-p "F" code) :warning)
                           (t :note))))
          (when region
            (push (flymake-make-diagnostic source (car region) (cdr region) type
                                           (format "%s %s" code text))
                  diags)))))
    (nreverse diags)))

(defun vikix-python--ruff-join ()
  "Put ruff's backend beside the others in this buffer.
Called again when eglot takes the buffer: it starts with its own alone."
  (when (bound-and-true-p vikix-python-mode)
    ;; python.el's own backend runs pyflakes, which ruff's F rules are;
    ;; without pyflakes installed it only warns that it can't run.
    (remove-hook 'flymake-diagnostic-functions #'python-flymake t)
    (add-hook 'flymake-diagnostic-functions #'vikix-python--ruff-flymake nil t)))

(defun vikix-python-format ()
  "Format the buffer with ruff, keeping point.
A syntax error keeps the buffer as it is, with ruff's words."
  (interactive)
  (let ((ruff (vikix-python--bin "ruff")))
    (unless ruff
      (user-error "ruff isn't installed: in a terminal, vikix add python"))
    (let ((out (generate-new-buffer " *vikix-ruff-format*"))
          (name (or (buffer-file-name) "stdin.py"))
          status)
      (unwind-protect
          (progn
            (setq status (save-restriction
                           (widen)
                           (call-process-region (point-min) (point-max) ruff nil out nil
                                                "format" "--quiet" "--stdin-filename" name "-")))
            (if (eq status 0)
                (save-restriction
                  (widen)
                  ;; Keeps point and the markers, unlike erase and insert.
                  (replace-region-contents (point-min) (point-max) (lambda () out)))
              (user-error "ruff: %s" (string-trim (with-current-buffer out (buffer-string))))))
        (kill-buffer out)))))

(defun vikix-python--format-before-save ()
  "Format with ruff before a save, when that's on and ruff is here."
  (when (and vikix-python-format-on-save (vikix-python--bin "ruff"))
    (condition-case e
        (vikix-python-format)
      (user-error (message "not formatted: %s" (cadr e))))))

(defun vikix-python-format-on-save ()
  "Format on save: on or off, for this buffer."
  (interactive)
  (setq-local vikix-python-format-on-save (not vikix-python-format-on-save))
  (message "ruff format on save: %s, in this buffer"
           (if vikix-python-format-on-save "on" "off")))

;; --- tests, runs, checks: in a compilation buffer ------------------------

(defun vikix-python--compile (command &optional root)
  "Run COMMAND in a compilation buffer, in ROOT (the project's)."
  (when (and (buffer-file-name) (buffer-modified-p))
    (save-buffer))
  (let ((default-directory (or root vikix-python--root (vikix-python-root))))
    (compile command)))

(defun vikix-python--quote (&rest words)
  "WORDS as one shell command: quoted only where the shell needs it.
So the compilation buffer shows pytest pkg/test_a.py::test_a as typed."
  (mapconcat (lambda (w)
               (if (string-match-p "\\`[-[:alnum:]_./:=]+\\'" w) w (shell-quote-argument w)))
             words " "))

(defun vikix-python--has-module (module)
  "Whether the buffer's python can import MODULE."
  (eq 0 (ignore-errors
          (call-process (vikix-python--python) nil nil nil "-c" (concat "import " module)))))

(defun vikix-python--pytest (&rest targets)
  "Run pytest on TARGETS (the project when none), in the project."
  (unless (vikix-python--has-module "pytest")
    (user-error (if vikix-python--venv
                    "pytest isn't in this venv: in a terminal, uv pip install pytest (in %s)"
                  "pytest isn't installed: in a terminal, vikix add python")
                vikix-python--root))
  (vikix-python--compile
   (apply #'vikix-python--quote (vikix-python--python) "-m" "pytest" targets)))

(defun vikix-python--file ()
  "The buffer's file, relative to the project."
  (unless (buffer-file-name)
    (user-error "This buffer has no file"))
  (file-relative-name (buffer-file-name) (or vikix-python--root (vikix-python-root))))

(defun vikix-python-test ()
  "Test the function at point: pytest FILE::Class::name."
  (interactive)
  (let ((name (python-info-current-defun)))
    (unless name
      (user-error "Not inside a function"))
    (vikix-python--pytest
     (concat (vikix-python--file) "::" (string-replace "." "::" name)))))

(defun vikix-python-test-file ()
  "Test this file."
  (interactive)
  (vikix-python--pytest (vikix-python--file)))

(defun vikix-python-test-project ()
  "Test the project."
  (interactive)
  (vikix-python--pytest))

(defun vikix-python-run ()
  "Run this file."
  (interactive)
  (vikix-python--compile (vikix-python--quote (vikix-python--python) (vikix-python--file))))

(defun vikix-python-check ()
  "ruff check the project."
  (interactive)
  (let ((ruff (vikix-python--bin "ruff")))
    (unless ruff
      (user-error "ruff isn't installed: in a terminal, vikix add python"))
    (vikix-python--compile (vikix-python--quote ruff "check" "--output-format" "concise" "."))))

;; --- the REPL, the venv, the docs, the layout ------------------------------

(defun vikix-python-repl ()
  "The REPL, from the venv: ipython when it has it, else its python."
  (interactive)
  (run-python nil nil t))

(defun vikix-python-venv-command ()
  "Say which venv the buffer uses.
Without one of the project's own, offer to make it (uv venv)."
  (interactive)
  (if (equal (vikix-python--venv-name) ".venv")
      (message "venv: %s" vikix-python--venv)
    (let ((root (or vikix-python--root (vikix-python-root))))
      (unless (executable-find "uv")
        (user-error "%s, and uv isn't installed to make one: in a terminal, vikix add python"
                    (if vikix-python--venv "The shared venv" "No venv")))
      (when (y-or-n-p (format "%s for %s. Make one there with uv venv? "
                              (if vikix-python--venv
                                  (format "The shared venv (%s)" (abbreviate-file-name vikix-python--venv))
                                "No venv")
                              (abbreviate-file-name root)))
        (let ((default-directory root))
          (with-temp-buffer
            (unless (eq 0 (call-process "uv" nil t nil "venv"))
              (user-error "uv venv: %s" (string-trim (buffer-string))))))
        (vikix-python-mode 1)
        (message "venv made: %s; the next REPL and language server use it"
                 (expand-file-name ".venv" root))))))

(defun vikix-python-docs ()
  "The offline Python docs, in the browser."
  (interactive)
  (let ((index (car (file-expand-wildcards
                     (expand-file-name "*/index.html" vikix-python-docs)))))
    (unless index
      (user-error "The offline docs aren't here: vikix add python puts them in %s"
                  vikix-python-docs))
    (browse-url (concat "file://" index))))

(defun vikix-python--compilation-buffer ()
  "The compilation buffer, made empty when there is none yet."
  (or (get-buffer "*compilation*")
      (with-current-buffer (get-buffer-create "*compilation*")
        (compilation-mode)
        (current-buffer))))

(defun vikix-python-ide ()
  "The IDE: this code on the left, the REPL top right, the tests' output below it.
A test or a run then shows in its window, and the REPL keeps its own."
  (interactive)
  (delete-other-windows)
  (let* ((code (selected-window))
         (right (split-window code (floor (* 0.6 (window-total-width code))) 'right))
         (below (split-window right nil 'below)))
    (set-window-buffer right (or (python-shell-get-buffer)
                                 (progn (run-python nil nil nil)
                                        (python-shell-get-buffer))
                                 (get-buffer-create "*Python*")))
    (set-window-buffer below (vikix-python--compilation-buffer))
    (select-window code)))

(defun vikix-python--under (root buffer)
  "Whether BUFFER is the project's at ROOT: its file, or its folder, is under it."
  (let ((file (or (buffer-file-name buffer)
                  (buffer-local-value 'default-directory buffer))))
    (and file (string-prefix-p root (file-name-as-directory (expand-file-name file))))))

(defun vikix-python--kill-with-process (buffer)
  "Kill BUFFER and the process in it, asking nothing."
  (when (buffer-live-p buffer)
    (let ((proc (get-buffer-process buffer)))
      (when proc
        (set-process-query-on-exit-flag proc nil)
        (delete-process proc)))
    (kill-buffer buffer)))

(declare-function eglot-current-server "eglot")
(declare-function eglot-shutdown "eglot")

(defun vikix-python-quit ()
  "Close the project: its files, the REPL, the tests' window, pyright, the frame.
A changed file is asked about first, as C-x s does. pyright is stopped
for the project (eglot keeps it otherwise). The frame goes when Emacs is
the daemon's (`e FILE' gets its terminal back); a lone Emacs stays."
  (interactive)
  (let* ((root (or vikix-python--root (vikix-python-root)))
         (name (file-name-nondirectory (directory-file-name root)))
         (repl (let ((name (python-shell-get-buffer)))   ; a name, not a buffer
                 (and name (get-buffer name))))
         (compilation (get-buffer "*compilation*"))
         (files (seq-filter (lambda (b) (and (buffer-file-name b) (vikix-python--under root b)))
                            (buffer-list)))
         (server (and (featurep 'eglot) (eglot-current-server))))
    (save-some-buffers nil (lambda () (memq (current-buffer) files)))
    (when server
      (ignore-errors (eglot-shutdown server nil)))
    (when (and repl (vikix-python--under root repl))
      (vikix-python--kill-with-process repl))
    (when (and compilation (vikix-python--under root compilation))
      (vikix-python--kill-with-process compilation))
    (dolist (b files) (kill-buffer b))
    (message "closed %s: %d file%s%s%s" name (length files) (if (= (length files) 1) "" "s")
             (if repl ", the REPL" "") (if server ", pyright" ""))
    (when (daemonp)
      (ignore-errors (delete-frame)))))

;; --- the mode ---------------------------------------------------------------

(defvar vikix-python-mode-map
  (let ((map (make-sparse-keymap))
        (p (make-sparse-keymap)))
    (define-key p "t" #'vikix-python-test)
    (define-key p "T" #'vikix-python-test-file)
    (define-key p "P" #'vikix-python-test-project)
    (define-key p "r" #'vikix-python-run)
    (define-key p "s" #'vikix-python-repl)
    (define-key p "f" #'vikix-python-format)
    (define-key p "F" #'vikix-python-format-on-save)
    (define-key p "c" #'vikix-python-check)
    (define-key p "v" #'vikix-python-venv-command)
    (define-key p "i" #'vikix-python-ide)
    (define-key p "d" #'vikix-python-docs)
    (define-key p "q" #'vikix-python-quit)
    (define-key map (kbd "C-c p") p)
    map)
  "The keys of `vikix-python-mode', under C-c p.")

;;;###autoload
(define-minor-mode vikix-python-mode
  "Python as an IDE: the project's venv for everything, ruff, tests, a layout.
Turned on for every Python buffer when this file is loaded."
  :lighter (:eval (format " Py[%s]" (vikix-python--venv-name)))
  :keymap vikix-python-mode-map
  (if vikix-python-mode
      (progn
        (setq vikix-python--root (vikix-python-root))
        (setq vikix-python--venv (vikix-python-venv vikix-python--root))
        (vikix-python--give-venv)
        (add-hook 'before-save-hook #'vikix-python--format-before-save nil t)
        (add-hook 'eglot-managed-mode-hook #'vikix-python--ruff-join nil t)
        (when (vikix-python--bin "ruff")
          (vikix-python--ruff-join)
          (flymake-mode 1)))
    (remove-hook 'before-save-hook #'vikix-python--format-before-save t)
    (remove-hook 'eglot-managed-mode-hook #'vikix-python--ruff-join t)
    (remove-hook 'flymake-diagnostic-functions #'vikix-python--ruff-flymake t)
    (kill-local-variable 'process-environment)
    (kill-local-variable 'exec-path)
    (kill-local-variable 'python-shell-virtualenv-root)
    (kill-local-variable 'python-shell-interpreter)
    (kill-local-variable 'python-shell-interpreter-args)))

(defun vikix-python--turn-on ()
  "Turn the mode on for a file's buffer.
Not for a scratch, the REPL, or the hidden buffers markdown-mode makes to
colour a code block (flymake would run ruff on every snippet)."
  (when (and (buffer-file-name)
             (or (derived-mode-p 'python-base-mode) (derived-mode-p 'python-mode)))
    (vikix-python-mode 1)))

;; python-base-mode (Emacs 29) is python-mode's and python-ts-mode's
;; parent, and its hook runs before theirs: the venv is in place before
;; your config's eglot-ensure starts pyright.
(add-hook (if (boundp 'python-base-mode-hook) 'python-base-mode-hook 'python-mode-hook)
          #'vikix-python--turn-on)

;; Loaded again (vikix update), or after the files were opened: the mode for them too.
(dolist (b (buffer-list))
  (with-current-buffer b
    (unless (bound-and-true-p vikix-python-mode)
      (vikix-python--turn-on))))

(provide 'vikix-python)
;;; vikix-python.el ends here
