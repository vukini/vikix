;;; vikix-theme.el --- Emacs follows `vikix theme'  -*- lexical-binding: t; -*-

;; Emacs takes the desktop's theme: `vikix theme NAME' switches it with
;; everything else. Vikix keeps this file current (it is
;; ~/.local/share/vikix/emacs/vikix-theme.el, a link into the Vikix
;; checkout), and your config loads it when it's there:
;;
;;   (load (expand-file-name "~/.local/share/vikix/emacs/vikix-theme") t t)
;;
;; The built-in themes have a theme made for them: vikix-dark and
;; vikix-light are Catppuccin's Mocha and Latte, gruvbox-dark, nord-dark and
;; tokyo-night-dark Doom's, and contrast-dark is Modus Vivendi, which comes
;; with Emacs and keeps every colour
;; at 7:1. The packages are installed from MELPA the first time they're
;; needed. Any other theme (yours, or one imported from Omarchy), or one
;; whose package can't be installed (no network), becomes `vikix-palette':
;; the theme's own colours, which `vikix theme' writes to
;; ~/.config/vikix/theme/palette.
;;
;; `vikix theme NAME' calls `vikix-theme-apply' in the running Emacs, so
;; it changes at once.  To keep a theme of your own instead, don't load
;; this file.

;;; Code:

(require 'subr-x)
(require 'seq)
(require 'package)

(defvar vikix-theme-dir
  (expand-file-name "vikix/theme" (or (getenv "XDG_CONFIG_HOME") "~/.config"))
  "Where `vikix theme' writes the current theme's name and colours.")

(defvar vikix-theme-schemes
  '(("vikix-dark"       catppuccin       catppuccin-theme (catppuccin-flavor . mocha))
    ("vikix-light"      catppuccin       catppuccin-theme (catppuccin-flavor . latte))
    ("gruvbox-dark"     doom-gruvbox     doom-themes)
    ("nord-dark"        doom-nord        doom-themes)
    ("tokyo-night-dark" doom-tokyo-night doom-themes)
    ("contrast-dark"    modus-vivendi    nil))
  "Vikix's theme, then Emacs's theme, the package it's in (nil: built in),
and a variable to set first, as (VARIABLE . VALUE).")

(defvar vikix-theme--applied nil
  "The theme last applied, as (VIKIX-NAME . EMACS-THEME).")

(defun vikix-theme--read (file)
  "FILE's contents in `vikix-theme-dir', or nil."
  (let ((f (expand-file-name file vikix-theme-dir)))
    (when (file-readable-p f)
      (with-temp-buffer (insert-file-contents f) (buffer-string)))))

(defun vikix-theme-current ()
  "The current Vikix theme's name; \"vikix-dark\" when there's none."
  (let ((name (string-trim (or (vikix-theme--read "current") ""))))
    (if (string-match-p "\\`[[:alnum:]_-]+\\'" name) name "vikix-dark")))

(defun vikix-theme-palette ()
  "The current theme's colours, as an alist of (KEY . \"#rrggbb\")."
  (let ((text (or (vikix-theme--read "palette") "")) (start 0) colours)
    (while (string-match "^\\([[:alnum:]_]+\\)=\\(#[[:xdigit:]]\\{6\\}\\)" text start)
      (push (cons (match-string 1 text) (match-string 2 text)) colours)
      (setq start (match-end 0)))
    colours))

(defun vikix-theme--ensure (package)
  "PACKAGE installed (from MELPA, the first time); nil when it can't be."
  (or (null package)
      (package-installed-p package)
      (condition-case err
          (progn
            (require 'package)
            (unless (assq package package-archive-contents)
              (package-refresh-contents))
            (package-install package)
            t)
        (error (message "vikix-theme: %s couldn't be installed (%s); using the theme's own colours"
                        package (error-message-string err))
               nil))))

(deftheme vikix-palette "The current Vikix theme's own colours.")

(defun vikix-theme--palette-faces ()
  "Set `vikix-palette' from the current theme's colours; nil without them."
  (let* ((p (vikix-theme-palette))
         (c (lambda (&rest keys)
              (seq-some (lambda (k) (cdr (assoc k p))) keys))))
    (when (and (funcall c "bg") (funcall c "fg"))
      (let ((bg (funcall c "bg")) (fg (funcall c "fg"))
            (subtle (funcall c "subtle" "fg")) (dim (funcall c "dim" "color8"))
            (accent (funcall c "accent" "color4")) (alert (funcall c "alert" "color1"))
            (sel (funcall c "sel" "color0")) (low (funcall c "color0" "sel"))
            (comment (funcall c "color8" "subtle"))
            (red (funcall c "color1")) (green (funcall c "color2"))
            (yellow (funcall c "color3")) (blue (funcall c "color4"))
            (magenta (funcall c "color5")) (cyan (funcall c "color6"))
            (orange (funcall c "color9" "color1")))
        ;; The colours set the last time stay in the theme's settings
        ;; after it is disabled, and a face's link to the theme goes with
        ;; the disabling, so setting the faces again would only add a
        ;; second setting a face, and the old one wins when the theme is
        ;; enabled: every theme of yours after the first kept the first's
        ;; colours. So the theme starts empty each time.
        (disable-theme 'vikix-palette)
        (put 'vikix-palette 'theme-settings nil)
        (custom-theme-set-faces
         'vikix-palette
         `(default ((t (:foreground ,fg :background ,bg))))
         `(cursor ((t (:background ,accent))))
         `(region ((t (:background ,sel :extend t))))
         `(highlight ((t (:background ,sel))))
         `(hl-line ((t (:background ,low :extend t))))
         `(fringe ((t (:background ,bg))))
         `(vertical-border ((t (:foreground ,dim))))
         `(window-divider ((t (:foreground ,dim))))
         `(mode-line ((t (:foreground ,fg :background ,low :box (:line-width 1 :color ,dim)))))
         `(mode-line-inactive ((t (:foreground ,subtle :background ,bg :box (:line-width 1 :color ,low)))))
         `(header-line ((t (:foreground ,fg :background ,low))))
         `(minibuffer-prompt ((t (:foreground ,accent :weight bold))))
         `(line-number ((t (:foreground ,comment :background ,bg))))
         `(line-number-current-line ((t (:foreground ,accent :background ,bg :weight bold))))
         `(link ((t (:foreground ,blue :underline t))))
         `(shadow ((t (:foreground ,comment))))
         `(error ((t (:foreground ,alert :weight bold))))
         `(warning ((t (:foreground ,yellow :weight bold))))
         `(success ((t (:foreground ,green :weight bold))))
         `(isearch ((t (:foreground ,bg :background ,accent))))
         `(lazy-highlight ((t (:foreground ,fg :background ,sel))))
         `(show-paren-match ((t (:foreground ,accent :background ,sel :weight bold))))
         `(font-lock-comment-face ((t (:foreground ,comment :slant italic))))
         `(font-lock-doc-face ((t (:foreground ,comment))))
         `(font-lock-string-face ((t (:foreground ,green))))
         `(font-lock-keyword-face ((t (:foreground ,magenta))))
         `(font-lock-builtin-face ((t (:foreground ,cyan))))
         `(font-lock-function-name-face ((t (:foreground ,blue))))
         `(font-lock-variable-name-face ((t (:foreground ,fg))))
         `(font-lock-type-face ((t (:foreground ,yellow))))
         `(font-lock-constant-face ((t (:foreground ,orange))))
         `(font-lock-warning-face ((t (:foreground ,red :weight bold))))
         `(font-lock-preprocessor-face ((t (:foreground ,cyan))))
         `(org-level-1 ((t (:foreground ,accent :weight bold))))
         `(org-level-2 ((t (:foreground ,magenta :weight bold))))
         `(org-level-3 ((t (:foreground ,cyan))))
         `(org-block ((t (:background ,low :extend t)))))
        t))))

(defun vikix-theme-apply (&optional force)
  "Take the current Vikix theme (`vikix theme').
Does nothing when it's the one already applied, unless FORCE."
  (interactive (list t))
  (let* ((name (vikix-theme-current))
         (scheme (cdr (assoc name vikix-theme-schemes)))
         (theme (car scheme)) (package (cadr scheme)) (setting (nth 2 scheme)))
    (when (or force (not (equal (car vikix-theme--applied) name)))
      (unless (and theme (vikix-theme--ensure package))
        (setq theme nil))
      (when setting (set (car setting) (cdr setting)))
      ;; One theme at a time: the one before (Vikix's or your config's)
      ;; would show through wherever the new one sets nothing.
      (mapc #'disable-theme custom-enabled-themes)
      (cond
       ((and theme (ignore-errors (load-theme theme t) t)))
       ((vikix-theme--palette-faces)
        (setq theme 'vikix-palette)
        (enable-theme 'vikix-palette))
       (t (setq theme nil)
          (message "vikix-theme: no colours for %s yet (vikix theme %s writes them)" name name)))
      (setq vikix-theme--applied (cons name theme))
      theme)))

;; Take the theme now, as the config loads this file.
(vikix-theme-apply)

(provide 'vikix-theme)
;;; vikix-theme.el ends here
