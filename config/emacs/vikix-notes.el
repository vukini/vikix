;;; vikix-notes.el --- your Org notes in ~/Dropbox/notes  -*- lexical-binding: t; -*-

;; The notes the inbox plugin's box writes to (Super+Alt+i), and `inbox
;; sort' files into work.org, personal.org, projects.org, someday.org: one
;; folder of Org files, in Dropbox so the phones have them too. Vikix
;; keeps this file current (it is ~/.local/share/vikix/emacs/vikix-notes.el,
;; a link into the Vikix checkout), and your config loads it when it's
;; there:
;;
;;   (load (expand-file-name "~/.local/share/vikix/emacs/vikix-notes") t t)
;;
;; It gives you, under C-c n:
;;
;;   C-c n a   the agenda: this week, then every TODO in the notes
;;   C-c n t   every TODO in the notes, to tick off (t on one)
;;   C-c n c   a note into the inbox, from inside Emacs
;;   C-c n o   open a notes file (the inbox first)
;;   C-c n j   today's journal page (journal/2026-10-03.org)
;;   C-c C-w   in a note: refile it into another notes file, or under one
;;             of its top headings (Org's own key; the targets are set
;;             here unless you've set your own org-refile-targets)
;;   C-c n f   find a note by its title, or start a new one (org-roam)
;;   C-c n i   a link to another note, here (org-roam)
;;   C-c n l   what links to this note: its backlinks (org-roam)
;;   C-c n g   the graph of your notes and their links, in the browser
;;             (org-roam-ui, on 127.0.0.1 only)
;;
;; org-roam and org-roam-ui are your config's to install (emacs-void
;; does, with use-package); a config without them is asked the first
;; time they're needed, from MELPA. org-roam's index of the notes is a
;; database kept out of Dropbox (~/.cache/vikix/org-roam.db): it's made
;; again from the files whenever needed. A notes file open in Emacs
;; follows what the phones change in it (auto-revert), until you edit
;; it. The agenda's files are left alone when you've chosen your own
;; (org-agenda-files); made the folder after Emacs started, the agenda
;; finds it at the next C-c n a.

;;; Code:

(require 'subr-x)
(require 'package)

(defvar vikix-notes-directory (expand-file-name "~/Dropbox/notes/")
  "The notes folder: Org files, the inbox among them.")

(defvar vikix-notes-inbox nil
  "The inbox file; nil for the inbox plugin's (its settings' file =), or
inbox.org in `vikix-notes-directory'.")

(defvar vikix-notes-journal "journal/"
  "Where the journal's pages go, in `vikix-notes-directory'.")

(defvar vikix-notes-map (make-sparse-keymap)
  "Notes' keys, on C-c n.")

(declare-function org-roam-db-autosync-mode "org-roam-db")
(declare-function org-roam-node-find "org-roam-node")
(declare-function org-roam-node-insert "org-roam-node")
(declare-function org-roam-buffer-toggle "org-roam-mode")
(declare-function org-roam-dailies-goto-today "org-roam-dailies")
(declare-function org-roam-ui-open "org-roam-ui")
(defvar org-roam-directory)
(defvar org-roam-db-location)
(defvar org-roam-dailies-directory)
(defvar org-roam-dailies-capture-templates)
(defvar org-agenda-files)
(defvar org-agenda-custom-commands)
(defvar org-capture-templates)
(defvar org-refile-targets)
(defvar org-refile-use-outline-path)
(defvar org-outline-path-complete-in-steps)
(defvar httpd-host)

(defun vikix-notes-inbox-file ()
  "The inbox: as the inbox plugin's settings say, or inbox.org in the notes."
  (or vikix-notes-inbox
      (let ((settings (expand-file-name "vikix/plugins/inbox/settings"
                                        (or (getenv "XDG_CONFIG_HOME") "~/.config"))))
        (when (file-readable-p settings)
          (with-temp-buffer
            (insert-file-contents settings)
            (when (re-search-forward "^[ \t]*file[ \t]*=[ \t]*\\(.+?\\)[ \t]*$" nil t)
              (expand-file-name (match-string 1))))))
      (expand-file-name "inbox.org" vikix-notes-directory)))

;;; The agenda

(defun vikix-notes-agenda-files ()
  "The notes folder and its journal: every .org file in them."
  (seq-filter #'file-directory-p
              (list vikix-notes-directory
                    (expand-file-name vikix-notes-journal vikix-notes-directory))))

(defvar vikix-notes--agenda-set nil
  "The org-agenda-files this file last set: while it's still that, it's
ours to bring up to date; changed, it's yours.")

(defun vikix-notes--agenda-files ()
  "org-agenda-files: yours, when you've set your own; else the notes, as
they are now (a journal begun since counts)."
  (when (or (null org-agenda-files) (equal org-agenda-files vikix-notes--agenda-set))
    (setq org-agenda-files (vikix-notes-agenda-files)
          vikix-notes--agenda-set org-agenda-files)))

(defun vikix-notes--agenda-setup ()
  (with-eval-after-load 'org
    (vikix-notes--agenda-files))
  (with-eval-after-load 'org-agenda
    (unless (assoc "n" org-agenda-custom-commands)
      (add-to-list 'org-agenda-custom-commands
                   '("n" "Notes: this week, then every TODO"
                     ((agenda "" ((org-agenda-span 'week)))
                      (alltodo "" ((org-agenda-overriding-header "Every TODO in your notes")))))))))

(defun vikix-notes-agenda ()
  "This week, then every TODO in the notes."
  (interactive)
  (require 'org-agenda)
  (vikix-notes--agenda-files)
  (unless org-agenda-files (user-error "No notes yet in %s: Super+Alt+i takes one" vikix-notes-directory))
  (org-agenda nil "n"))

(defun vikix-notes-todos ()
  "Every TODO in the notes: t on one ticks it."
  (interactive)
  (require 'org-agenda)
  (vikix-notes--agenda-files)
  (org-todo-list))

;;; Refiling: C-c C-w into another notes file

(defun vikix-notes-files ()
  "The notes files: the inbox, then every .org file at the top of the folder."
  (let ((inbox (vikix-notes-inbox-file)))
    (cons inbox (remove inbox (when (file-directory-p vikix-notes-directory)
                                (directory-files vikix-notes-directory t "\\`[^.].*\\.org\\'"))))))

(defun vikix-notes--refile-setup ()
  "org-refile-targets: yours, when you've set your own; else the notes
files and their top headings, as `inbox sort' offers them. Org's own
default would be the headings of the file you're in only."
  (with-eval-after-load 'org-refile
    (unless org-refile-targets
      (setq org-refile-targets '((vikix-notes-files :maxlevel . 1))
            ;; "work.org" is the file's end, "work.org/Projects" a heading in it.
            org-refile-use-outline-path 'file
            org-outline-path-complete-in-steps nil))))

;;; Capture, opening

(defun vikix-notes-capture ()
  "A note into the inbox, from inside Emacs (Super+Alt+i does it from anywhere)."
  (interactive)
  (require 'org-capture)
  (let ((org-capture-templates
         `(("i" "Inbox" entry (file ,(vikix-notes-inbox-file))
            "* %?\n:PROPERTIES:\n:CREATED:  %U\n:END:\n" :empty-lines 0))))
    (org-capture nil "i")))

(defun vikix-notes-open ()
  "Open a notes file, the inbox first."
  (interactive)
  (let* ((files (vikix-notes-files))
         (names (mapcar (lambda (f) (file-relative-name f vikix-notes-directory)) files))
         (pick (completing-read "Notes file: " names nil nil nil nil (car names))))
    (find-file (expand-file-name pick vikix-notes-directory))))

;;; org-roam: links, backlinks, the journal, the graph

(defun vikix-notes--package (pkg why)
  "PKG, installed from MELPA after asking (WHY says what it's for); t when it's here."
  (or (require pkg nil t)
      (when (y-or-n-p (format "%s needs %s, from MELPA. Install it now? " why pkg))
        (unless (bound-and-true-p package--initialized) (package-initialize))
        (unless (assq pkg package-archive-contents)
          (package-refresh-contents))
        (package-install pkg)
        (require pkg nil t))
      (user-error "%s isn't installed" pkg)))

(defun vikix-notes--roam ()
  "org-roam, set up on the notes (installed first when it isn't)."
  (vikix-notes--package 'org-roam "Linking notes")
  (unless (and (boundp 'org-roam-directory)
               (equal (file-truename org-roam-directory) (file-truename vikix-notes-directory))
               (bound-and-true-p org-roam-db-autosync-mode))
    (setq org-roam-directory (file-truename vikix-notes-directory)
          ;; A database, made again from the files whenever needed: never in
          ;; Dropbox, which would sync it half-written.
          org-roam-db-location (expand-file-name "vikix/org-roam.db"
                                                 (or (getenv "XDG_CACHE_HOME") "~/.cache"))
          org-roam-dailies-directory vikix-notes-journal
          org-roam-dailies-capture-templates
          '(("d" "default" entry "* %<%H:%M> %?"
             :target (file+head "%<%Y-%m-%d>.org" "#+title: %<%Y-%m-%d %A>\n"))))
    (make-directory (file-name-directory org-roam-db-location) t)
    (org-roam-db-autosync-mode 1)))

(defun vikix-notes-find ()
  "Find a note by its title, or start a new one."
  (interactive)
  (vikix-notes--roam)
  (org-roam-node-find))

(defun vikix-notes-insert-link ()
  "A link to another note, here (a new one when it isn't there yet)."
  (interactive)
  (vikix-notes--roam)
  (org-roam-node-insert))

(defun vikix-notes-backlinks ()
  "What links to this note."
  (interactive)
  (vikix-notes--roam)
  (org-roam-buffer-toggle))

(defun vikix-notes-journal-directory ()
  "The journal's folder, made when it isn't there yet: org-roam opens
today's page without making it, and the first auto-save then fails."
  (let ((dir (expand-file-name vikix-notes-journal vikix-notes-directory)))
    (make-directory dir t)
    dir))

(defun vikix-notes-journal ()
  "Today's journal page."
  (interactive)
  (vikix-notes--roam)
  (require 'org-roam-dailies)
  (vikix-notes-journal-directory)
  (org-roam-dailies-goto-today))

(defun vikix-notes-graph ()
  "The graph of your notes and their links, in the browser."
  (interactive)
  (vikix-notes--roam)
  ;; Its web server listens on every network unless told: this laptop only.
  (setq httpd-host "127.0.0.1")
  (vikix-notes--package 'org-roam-ui "The notes' graph")
  (org-roam-ui-open))

;;; Changes from the phones

(defun vikix-notes--follow-disk ()
  "A notes file open here takes what the phones (or the inbox's box)
wrote to it, through Dropbox, while it has no unsaved changes."
  (when (and buffer-file-name
             (file-in-directory-p buffer-file-name vikix-notes-directory))
    (auto-revert-mode 1)))

(add-hook 'find-file-hook #'vikix-notes--follow-disk)

;;; Keys

(define-key vikix-notes-map "a" #'vikix-notes-agenda)
(define-key vikix-notes-map "t" #'vikix-notes-todos)
(define-key vikix-notes-map "c" #'vikix-notes-capture)
(define-key vikix-notes-map "o" #'vikix-notes-open)
(define-key vikix-notes-map "j" #'vikix-notes-journal)
(define-key vikix-notes-map "f" #'vikix-notes-find)
(define-key vikix-notes-map "i" #'vikix-notes-insert-link)
(define-key vikix-notes-map "l" #'vikix-notes-backlinks)
(define-key vikix-notes-map "g" #'vikix-notes-graph)

(vikix-notes--agenda-setup)
(vikix-notes--refile-setup)
(keymap-global-set "C-c n" vikix-notes-map)

(provide 'vikix-notes)
;;; vikix-notes.el ends here
