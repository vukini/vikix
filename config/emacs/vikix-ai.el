;;; vikix-ai.el --- AI in Emacs, on Vikix's settings  -*- lexical-binding: t; -*-

;; gptel on the model Super+i uses (`vikix ai use'): Claude, or a model on
;; this laptop through Ollama. Vikix keeps this file current: it is
;; ~/.local/share/vikix/emacs/vikix-ai.el, a link into the Vikix checkout,
;; and your config loads it when it's there, after its own gptel setup:
;;
;;   (load (expand-file-name "~/.local/share/vikix/emacs/vikix-ai") t t)
;;
;; It adds two backends, "Claude" and "Local", and keeps yours (OpenAI,
;; ...). The default follows ~/.config/vikix/ai: read again at each C-c g
;; (gptel) or C-c G (gptel-menu), so `vikix ai use claude' reaches a
;; running Emacs. A backend you pick in the menu stays until that file
;; changes. Nothing connects until you ask, and a chat that can't answer
;; says what's missing instead of asking for a key.

;;; Code:

(require 'json)
(require 'subr-x)
(require 'cl-lib)

(defvar gptel-backend)
(defvar gptel-model)
(declare-function gptel-make-anthropic "gptel-anthropic")
(declare-function gptel-make-ollama "gptel-ollama")
(declare-function gptel-backend-name "gptel-openai")
(declare-function gptel--process-models "gptel-openai")

(defvar vikix-ai-config
  (expand-file-name "vikix" (or (getenv "XDG_CONFIG_HOME") "~/.config"))
  "Vikix's settings: ai (use=, model=) and secrets/.")

(defvar vikix-ai-ollama "127.0.0.1:11434"
  "Where Ollama listens (`vikix ai setup' starts it).")

(defconst vikix-ai-claude-default 'claude-sonnet-5
  "Claude's model when model= is empty, as Super+i's.")

(defvar vikix-ai-claude nil "The Claude backend.")
(defvar vikix-ai-local nil "The backend for the models on this laptop.")
(defvar vikix-ai--applied :none
  "The (use . model) last made the default, so a change is noticed.")

(defun vikix-ai--read (file)
  "FILE's contents, trimmed, or nil when it's missing or empty."
  (when (file-readable-p file)
    (with-temp-buffer
      (insert-file-contents file)
      (let ((s (string-trim (buffer-string))))
        (unless (string-empty-p s) s)))))

(defun vikix-ai--setting (key)
  "KEY's value in ~/.config/vikix/ai (the last line for it), or nil."
  (let ((file (expand-file-name "ai" vikix-ai-config)) value)
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (while (re-search-forward
                (format "^[ \t]*%s[ \t]*=\\([^#\n]*\\)" (regexp-quote key)) nil t)
          (setq value (string-trim (match-string 1))))))
    (and value (not (string-empty-p value)) value)))

(defun vikix-ai--anthropic-key ()
  "The Anthropic key: from the session, or from `vikix ai key set' since.
A key set after login isn't in this Emacs's environment yet."
  (let ((key (getenv "ANTHROPIC_API_KEY")))
    (if (and key (not (string-empty-p key)))
        key
      (vikix-ai--read (expand-file-name "secrets/ANTHROPIC_API_KEY" vikix-ai-config)))))

(defun vikix-ai--local-models ()
  "The models Ollama has, as symbols; `down' when it isn't running.
Asked each time (a second at most), so a model you just got is there."
  (with-temp-buffer
    (if (not (eq 0 (ignore-errors
                     (call-process "curl" nil t nil "-fsS" "--max-time" "1"
                                   (format "http://%s/api/tags" vikix-ai-ollama)))))
        'down
      (goto-char (point-min))
      (let ((tags (ignore-errors (json-parse-buffer :object-type 'alist :array-type 'list))))
        (mapcar (lambda (m) (intern (alist-get 'name m))) (alist-get 'models tags))))))

(defun vikix-ai--claude-models (model)
  "Claude's models for the menu: MODEL and Vikix's default first."
  (let ((known (bound-and-true-p gptel--anthropic-models))
        (first (delete-dups (delq nil (list model vikix-ai-claude-default)))))
    ;; What gptel knows of its newest Sonnet (images, tools, caching)
    ;; holds for the models it doesn't know yet; not its price.
    (append (mapcar (lambda (m)
                      (let ((newest (cdr (car known))))
                        (cons m (list :capabilities (plist-get newest :capabilities)
                                      :mime-types (plist-get newest :mime-types)
                                      :context-window (plist-get newest :context-window)))))
                    first)
            (seq-remove (lambda (m) (memq (car-safe m) first)) known))))

(defun vikix-ai--set-models (backend models)
  "BACKEND's models, now MODELS.
By the slot's place, looked up at run time: gptel may not be loaded
yet when this file is, and its accessors' setf can't be expanded then."
  (aset backend (cl-struct-slot-offset 'gptel-backend 'models)
        (gptel--process-models models)))

(defun vikix-ai--backends (model models)
  "Claude's models (MODEL first, when it's Claude's) and Local's (MODELS).
Each backend is made once, then its models changed in place, so a chat
already on it stays on it."
  (let ((claude (vikix-ai--claude-models model))
        ;; gptel needs one: Super+i's first choice stands in until you
        ;; have a model.
        (local (or (and (listp models) models) '(llama3.2:3b))))
    (if vikix-ai-claude
        (vikix-ai--set-models vikix-ai-claude claude)
      (setq vikix-ai-claude
            (gptel-make-anthropic "Claude"
              :key #'vikix-ai--anthropic-key :stream t :models claude)))
    (if vikix-ai-local
        (vikix-ai--set-models vikix-ai-local local)
      (setq vikix-ai-local
            (gptel-make-ollama "Local"
              :host vikix-ai-ollama :stream t :models local)))))

(defun vikix-ai-sync (&optional force)
  "Make gptel's default the model `vikix ai use' names, if that changed.
With FORCE (interactively), make it the default again anyway."
  (interactive (list t))
  (require 'gptel)
  (require 'gptel-anthropic)            ; not every gptel is autoloaded
  (require 'gptel-ollama)
  (let* ((use (downcase (or (vikix-ai--setting "use") "local")))
         (model (let ((m (vikix-ai--setting "model"))) (and m (intern m))))
         (models (vikix-ai--local-models))
         (now (cons use model)))
    (vikix-ai--backends (and (equal use "claude") model) models)
    (when (or force (not (equal now vikix-ai--applied)))
      (setq vikix-ai--applied now)
      (if (equal use "claude")
          (setq-default gptel-backend vikix-ai-claude
                        gptel-model (or model vikix-ai-claude-default))
        (setq-default gptel-backend vikix-ai-local
                      gptel-model (cond (model)
                                        ((and (listp models) (memq 'llama3.2:3b models)) 'llama3.2:3b)
                                        ((and (listp models) (car models)))
                                        (t 'llama3.2:3b)))))
    (when (called-interactively-p 'interactive)
      (message "gptel: %s on %s" gptel-model (gptel-backend-name gptel-backend)))
    models))

(defun vikix-ai--check (models)
  "Stop, saying what to do, when the default model can't answer.
MODELS are Ollama's (see `vikix-ai--local-models'). Only Vikix's
backends are checked: one of yours is yours."
  (let ((backend (default-value 'gptel-backend))
        (model (default-value 'gptel-model)))
    (cond
     ((and (eq backend vikix-ai-claude) (not (vikix-ai--anthropic-key)))
      (user-error "Claude needs your Anthropic key: in a terminal, vikix ai key set anthropic.  Or a model on this laptop: vikix ai use local"))
     ((not (eq backend vikix-ai-local)))
     ((eq models 'down)
      (user-error "Local AI isn't running: in a terminal, vikix ai setup.  Or Claude: vikix ai use claude"))
     ((null models)
      (user-error "No local model yet: Super+m, Local AI, to choose one.  Or Claude: vikix ai use claude"))
     ((not (memq model models))
      (user-error "You don't have the model %s: vikix ai models gets it, or change model= in ~/.config/vikix/ai" model)))))

;; Before gptel's own questions (the buffer, a key), so a missing key is
;; explained rather than asked for. Your keys to gptel and gptel-menu stay
;; as they are.
(defun vikix-ai--before-chat (&rest _)
  "Follow `vikix ai use' before a chat starts, and check it can answer."
  (interactive
   (lambda (spec)
     (vikix-ai--check (vikix-ai-sync))
     (advice-eval-interactive-spec spec))))

(defun vikix-ai--before-menu (&rest _)
  "Follow `vikix ai use' before the menu opens (not checked: it's where you'd switch)."
  (vikix-ai-sync))

(advice-add 'gptel :before #'vikix-ai--before-chat)
(advice-add 'gptel-menu :before #'vikix-ai--before-menu)

(provide 'vikix-ai)
;;; vikix-ai.el ends here
