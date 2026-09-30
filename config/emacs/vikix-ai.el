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
;;
;; And your agent (Super+a's): `vikix-ai-agent', a chat with it in
;; agent-shell, and `vikix-ai-agent-terminal', in a terminal; both
;; started by `vikix agent'. Your config binds them (emacs-void: C-c a,
;; C-c A).

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

(defconst vikix-ai--sum
  (when load-file-name
    (with-temp-buffer
      (insert-file-contents load-file-name)
      (secure-hash 'sha256 (current-buffer))))
  "This file's checksum as it was loaded: `vikix update' reloads it when it changed.")

(defvar vikix-ai-config
  (expand-file-name "vikix" (or (getenv "XDG_CONFIG_HOME") "~/.config"))
  "Vikix's settings: ai (use=, model=), agent (agent=) and secrets/.")

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

(defun vikix-ai--setting (key &optional file)
  "KEY's value in ~/.config/vikix/FILE (ai when nil; the last line for it), or nil."
  (let ((file (expand-file-name (or file "ai") vikix-ai-config)) value)
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

;;; Agents: your agent (Super+a's) in Emacs, started by `vikix agent'.

;; `vikix-ai-agent' is a chat with it in agent-shell, over ACP; and
;; `vikix-ai-agent-terminal' runs it in a terminal (vterm when you have it).
;; Both start it through `vikix agent', as Super+a does: the guide, no API
;; keys or SSH agent in its environment (this Emacs has them all), and a
;; snapshot first, so `vikix changes' shows what it did. agent-shell's list
;; is Vikix's four, each started that way; set `agent-shell-agent-configs'
;; after this file to have others (they start without Vikix's rules).

(defvar agent-shell-preferred-agent-config)
(defvar agent-shell-agent-configs)
(defvar agent-shell-anthropic-claude-acp-command)
(defvar agent-shell-openai-codex-acp-command)
(defvar agent-shell-google-gemini-acp-command)
(defvar agent-shell-opencode-acp-command)
(defvar vterm-shell)
(declare-function vterm "vterm")
(declare-function term-char-mode "term")
(declare-function agent-shell-cwd "agent-shell")

(defconst vikix-ai-agents
  '((claude   claude-code agent-shell-anthropic-make-claude-code-config "claude"   "claude-agent-acp")
    (codex    codex       agent-shell-openai-make-codex-config          "codex"    "codex-acp")
    (gemini   gemini-cli  agent-shell-google-make-gemini-config         "gemini"   nil)
    (opencode opencode    agent-shell-opencode-make-agent-config        "opencode" nil))
  "The agents that speak ACP: Vikix's name, agent-shell's, its config,
the agent's program, and its ACP adapter (nil: it speaks ACP itself).")

(defun vikix-ai--agent ()
  "Your agent: agent= in ~/.config/vikix/agent (`vikix agent --default'), or claude."
  (intern (or (vikix-ai--setting "agent" "agent") "claude")))

(defun vikix-ai--installed-p (program)
  "Is PROGRAM where `vikix agent --install' puts it, or on PATH?"
  (or (file-executable-p (expand-file-name program "~/.local/bin"))
      (and (equal program "opencode") (file-executable-p "~/.opencode/bin/opencode"))
      (executable-find program)))

(defun vikix-ai--about (name)
  "What NAME is and how it signs in, as `vikix agent --list' says it."
  (with-temp-buffer
    (when (eq 0 (ignore-errors (call-process "vikix" nil t nil "agent" "--list")))
      (goto-char (point-min))
      (when (re-search-forward (format "^[* ] %s +[^ ]+ +\\(.+\\)$" name) nil t)
        (match-string 1)))))

(defun vikix-ai--terminal-key ()
  "The key for `vikix-ai-agent-terminal' (C-c A in emacs-void), or its M-x."
  (substitute-command-keys "\\[vikix-ai-agent-terminal]"))

(defun vikix-ai--agent-ready (name)
  "Stop, saying what to do, unless NAME can start over ACP.
In the terminal's words (`vikix agent'): the agent first, then its adapter."
  (let ((entry (assq name vikix-ai-agents)))
    (cond
     ((not (executable-find "vikix"))
      (user-error "vikix isn't on PATH: agents start through it"))
     ((eq name 'aider)
      (user-error "Aider doesn't speak ACP: %s runs it in a terminal" (vikix-ai--terminal-key)))
     ((not entry)
      (user-error "no agent called %s: vikix agent --list shows them" name))
     ((not (vikix-ai--installed-p (nth 3 entry)))
      (let ((about (vikix-ai--about name)))
        (user-error "%s isn't installed%s.  To install it, in a terminal: vikix agent --install %s"
                    name (if about (concat ": " about) "") name)))
     ((and (nth 4 entry) (not (vikix-ai--installed-p (nth 4 entry))))
      (user-error "%s is installed, but not its ACP adapter, for editors.  In a terminal: vikix agent --install %s (adds only the adapter)"
                  name name)))))

(defun vikix-ai-agent ()
  "A chat with your agent (Super+a's), over ACP, in agent-shell.
Started by `vikix agent --acp'; the one this project has already, if any."
  (interactive)
  (let ((name (vikix-ai--agent)))
    (vikix-ai--agent-ready name)
    (unless (require 'agent-shell nil t)
      (user-error "agent-shell isn't installed: M-x package-install RET agent-shell"))
    (let ((agent-shell-preferred-agent-config (nth 1 (assq name vikix-ai-agents))))
      (call-interactively #'agent-shell))))

(defun vikix-ai-agent-terminal ()
  "Your agent (Super+a's) in a terminal, as `vikix agent' starts it."
  (interactive)
  (unless (executable-find "vikix")
    (user-error "vikix isn't on PATH: agents start through it"))
  (if (require 'vterm nil t)
      (let ((vterm-shell "vikix agent"))
        (vterm "*vikix agent*"))
    (switch-to-buffer (make-term "vikix agent" "vikix" nil "agent"))
    (term-char-mode)))

(defvar vikix-ai-transcripts
  (expand-file-name "vikix/agent-shell"
                    (or (getenv "XDG_STATE_HOME") "~/.local/state"))
  "Where agent-shell keeps its transcripts: one folder, only yours to read.")

(defun vikix-ai--transcript-file ()
  "A new transcript's path: PROJECT-TIME.md in `vikix-ai-transcripts'.
Not in the project, as agent-shell would: a transcript is the whole
conversation, pasted secrets too, and it doesn't belong next to your code."
  (let ((project (file-name-nondirectory (directory-file-name (agent-shell-cwd)))))
    (unless (file-directory-p vikix-ai-transcripts)
      (make-directory vikix-ai-transcripts t)
      (set-file-modes vikix-ai-transcripts #o700))
    (expand-file-name (format "%s-%s.md" (if (string-empty-p project) "home" project)
                              (format-time-string "%F-%H-%M-%S"))
                      vikix-ai-transcripts)))

(with-eval-after-load 'agent-shell
  (setq agent-shell-transcript-file-path-function #'vikix-ai--transcript-file)
  (setq agent-shell-anthropic-claude-acp-command '("vikix" "agent" "--acp" "claude")
        agent-shell-openai-codex-acp-command     '("vikix" "agent" "--acp" "codex")
        agent-shell-google-gemini-acp-command    '("vikix" "agent" "--acp" "gemini")
        agent-shell-opencode-acp-command         '("vikix" "agent" "--acp" "opencode")
        agent-shell-agent-configs (mapcar #'caddr vikix-ai-agents)))

(provide 'vikix-ai)
;;; vikix-ai.el ends here
