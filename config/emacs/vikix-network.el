;;; vikix-network.el --- The Network Office -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'json)
(require 'button)
(require 'subr-x)
(require 'svg)
(require 'tramp)

(defvar vikix-network-command
  (list (expand-file-name "../../bin/vikix-network"
                          (file-name-directory (or load-file-name buffer-file-name)))))
(defvar-local vikix-network--data nil)
(defvar-local vikix-network--network nil)
(defvar-local vikix-network--device nil)
(defvar-local vikix-network--process nil)
(defvar-local vikix-network--deadline nil)
(defvar-local vikix-network--timer nil)
(defvar-local vikix-network--detail nil)
(defvar-local vikix-network--owner nil)
(defvar-local vikix-network--frame nil)
(defvar-local vikix-network--message "Reading local network information…")
(defvar-local vikix-network--after nil)

(defun vikix-network--home ()
  (if (buffer-live-p vikix-network--owner) vikix-network--owner (current-buffer)))

(defun vikix-network--net ()
  (cl-find vikix-network--network (alist-get 'networks vikix-network--data)
           :key (lambda (n) (alist-get 'id n)) :test #'equal))

(defun vikix-network--node ()
  (cl-find vikix-network--device (alist-get 'devices (vikix-network--net))
           :key (lambda (d) (alist-get 'address d)) :test #'equal))

(defun vikix-network--button (label fn)
  (insert-text-button label 'follow-link t 'action (lambda (_) (funcall fn)))
  (insert "  "))

(defun vikix-network--finished (owner out err proc)
  (unwind-protect
      (when (buffer-live-p owner)
        (with-current-buffer owner
          (when (eq proc vikix-network--process)
            (when (timerp vikix-network--deadline) (cancel-timer vikix-network--deadline))
            (let ((done vikix-network--after) (ok nil))
              (setq vikix-network--deadline nil vikix-network--process nil vikix-network--after nil)
              (condition-case problem
                  (if (zerop (process-exit-status proc))
                      (progn
                        (setq vikix-network--data
                              (with-current-buffer out
                                (json-parse-string (buffer-string) :object-type 'alist :array-type 'list
                                                   :null-object nil :false-object nil)))
                        (setq ok t vikix-network--message
                              "Current observations; missing devices may be hidden or unresponsive."))
                    (setq vikix-network--message
                          (let ((text (with-current-buffer err (string-trim (buffer-string)))))
                            (if (string-empty-p text) "Request stopped." text))))
                (error (setq vikix-network--message (error-message-string problem))))
              (vikix-network--render)
              ;; Opening remote files can change the current buffer. Finish drawing first.
              (when (and ok done)
                (condition-case problem (funcall done)
                  (error (with-current-buffer owner
                           (setq vikix-network--message (error-message-string problem))
                           (vikix-network--render)))))))))
    (when (buffer-live-p out) (kill-buffer out))
    (when (buffer-live-p err) (kill-buffer err))))

(defun vikix-network--request (&rest args)
  "Run the backend without blocking Emacs. One owned, bounded request at a time."
  (when vikix-network--process (user-error "A request is running; press s to stop it"))
  (let* ((owner (current-buffer))
         (out (generate-new-buffer " *Network response*"))
         (err (generate-new-buffer " *Network error*"))
         (proc nil))
    (setq vikix-network--message (concat (capitalize (car args)) "…"))
    (condition-case failure
        (setq proc
              (make-process
               :name "vikix-network" :buffer out :stderr err :noquery t
               :command (append vikix-network-command args) :connection-type 'pipe
               :sentinel (lambda (p _event)
                           (when (memq (process-status p) '(exit signal))
                             (vikix-network--finished owner out err p)))))
      (error
       (kill-buffer out) (kill-buffer err)
       (setq vikix-network--after nil)
       (setq vikix-network--message (error-message-string failure))))
    (when proc
      (setq vikix-network--process proc
            vikix-network--deadline
            (run-at-time 210 nil (lambda ()
                                  (when (process-live-p proc) (interrupt-process proc))))))
    (vikix-network--render)))

(defun vikix-network-refresh ()
  "Read current observations and apply this network's saved discovery choice."
  (interactive)
  (with-current-buffer (vikix-network--home) (vikix-network--request "refresh")))

(defun vikix-network-stop ()
  (interactive)
  (with-current-buffer (vikix-network--home)
    (when (process-live-p vikix-network--process)
      (interrupt-process vikix-network--process))))

(defun vikix-network-discover ()
  (interactive)
  (with-current-buffer (vikix-network--home)
    (unless (vikix-network--net) (user-error "Select a connected network first"))
    (vikix-network--request "discover" vikix-network--network)))

(defun vikix-network-ports ()
  (interactive)
  (with-current-buffer (vikix-network--home)
    (unless (vikix-network--node) (user-error "Select a device first"))
    (vikix-network--request "ports" vikix-network--network vikix-network--device)))

(defun vikix-network-identify ()
  "Probe the selected device's services for names, versions and OS clues."
  (interactive)
  (with-current-buffer (vikix-network--home)
    (unless (vikix-network--node) (user-error "Select a device first"))
    (vikix-network--request "identify" vikix-network--network vikix-network--device)))

(defun vikix-network-name ()
  "Save a friendly name for the selected device; empty clears it."
  (interactive)
  (with-current-buffer (vikix-network--home)
    (unless (vikix-network--node) (user-error "Select a device first"))
    (let ((name (read-string "Friendly name (empty clears): "
                             (alist-get 'friendly_name (vikix-network--node)))))
      (vikix-network--request "name" vikix-network--network vikix-network--device "--" name))))

(defun vikix-network--label (device)
  (let ((friendly (alist-get 'friendly_name device))
        (reported (alist-get 'name (car (alist-get 'names device)))))
    (format "%s · %s"
            (cond ((and friendly (not (string-empty-p friendly))) friendly)
                  ((and reported (not (string-empty-p reported))) reported)
                  (t (alist-get 'role device)))
            (alist-get 'address device))))

(defun vikix-network-policy ()
  (interactive)
  (with-current-buffer (vikix-network--home)
    (unless (vikix-network--net) (user-error "Select a connected network first"))
    (let ((mode (completing-read "Discovery on this network: "
                                 '("manual" "discover" "ports") nil t)))
      (vikix-network--request "policy" vikix-network--network mode))))

(defun vikix-network--choose (id &optional device)
  (with-current-buffer (vikix-network--home)
    (setq vikix-network--network id vikix-network--device device)
    (vikix-network--render)))

(defun vikix-network--colour (face fallback)
  (let ((colour (face-foreground face nil t)))
    (if (and (stringp colour) (not (string= colour "unspecified-fg"))) colour fallback)))

(defun vikix-network--graph (net)
  "A membership graph, with one clickable SVG branch per device.
Buttons also carry text, so keyboard navigation and a non-SVG Emacs work."
  (let* ((devices (alist-get 'devices net))
         (id (alist-get 'id net))
         (fg (vikix-network--colour 'default "#dddddd"))
         (accent (vikix-network--colour 'font-lock-keyword-face "#77aaff")))
    (insert (propertize "Local network\n" 'face 'bold))
    (insert "Edges mean network membership, not physical wiring.\n\n")
    (dolist (device devices)
      (let* ((ip (alist-get 'address device))
             (label (vikix-network--label device))
             (selected (equal ip vikix-network--device))
             (start (point)))
        (insert-text-button (concat "  ├── " label "\n") 'follow-link t
                            'face (if selected 'highlight 'button)
                            'action (lambda (_) (vikix-network--choose id ip)))
        (when (and (display-graphic-p) (image-type-available-p 'svg))
          (let ((svg (svg-create 420 55))
                (short-label (truncate-string-to-width label 39 nil nil "…")))
            (svg-line svg 16 0 16 55 :stroke fg :stroke-width 2)
            (svg-line svg 16 27 42 27 :stroke fg :stroke-width 2)
            (svg-rectangle svg 42 4 365 46 :rx 8 :fill (if selected accent "none")
                           :stroke accent :stroke-width 2)
            (svg-text svg short-label :x 54 :y 32 :font-size 15
                      :fill (if selected (or (face-background 'default nil t) "#222222") fg))
            (put-text-property start (1- (point)) 'face '(:underline nil))
            (put-text-property start (1- (point)) 'display (svg-image svg :ascent 'center))))))))

(defun vikix-network--render ()
  (let* ((inhibit-read-only t)
         (old-point (point))
         (rows (alist-get 'networks vikix-network--data)))
    (unless (vikix-network--net)
      (setq vikix-network--network (alist-get 'id (car rows)) vikix-network--device nil))
    (let ((net (vikix-network--net)))
      (unless (vikix-network--node)
        (setq vikix-network--device (alist-get 'address (car (alist-get 'devices net))))))
    (erase-buffer)
    (insert (propertize "Network Office\n\n" 'face '(:height 1.4 :weight bold)))
    (insert vikix-network--message "\n\n")
    (vikix-network--button "Refresh" #'vikix-network-refresh)
    (vikix-network--button "Discover devices" #'vikix-network-discover)
    (vikix-network--button "Discovery preference" #'vikix-network-policy)
    (when vikix-network--process (vikix-network--button "Stop" #'vikix-network-stop))
    (insert "\n\n")
    (unless rows (insert "No connected Ethernet or Wi-Fi IPv4 network found.\n"))
    (dolist (net rows)
      (let ((id (alist-get 'id net)))
        (vikix-network--button
         (format "%s (%s)" (alist-get 'name net) (alist-get 'interface net))
         (lambda () (vikix-network--choose id)))))
    (insert "\n\n")
    (when-let* ((net (vikix-network--net)))
      (insert (format "Discovery: %s   Subnet: %s\n"
                      (alist-get 'policy net) (string-join (alist-get 'subnets net) ", ")))
      (unless (alist-get 'identifiable net)
        (insert "Gateway identity incomplete: automatic discovery is unavailable.\n"))
      (unless (alist-get 'nmap vikix-network--data)
        (insert "Install nmap with vikix pkg add nmap to discover devices and check ports.\n"))
      (when-let* ((stamp (alist-get 'scanned net)))
        (insert (format "Last scan: %s (results expire after ten minutes)\n"
                        (format-time-string "%H:%M:%S" (seconds-to-time stamp)))))
      (unless (string-empty-p (or (alist-get 'error net) ""))
        (insert (alist-get 'error net) "\n"))
      (insert "\n")
      (vikix-network--graph net))
    (insert "\ng refresh · d discover · p ports · i identify · n name · c preference · s stop · q close\n")
    (goto-char (min old-point (point-max)))
    (vikix-network--details)))

(defun vikix-network--details ()
  (when (buffer-live-p vikix-network--detail)
    (let ((device (vikix-network--node))
          (owner (current-buffer)))
      (with-current-buffer vikix-network--detail
        (let ((inhibit-read-only t))
          (erase-buffer)
          (if (not device) (insert "Select a device in the graph.\n")
            (insert (propertize (vikix-network--label device) 'face '(:height 1.3 :weight bold)) "\n\n")
            (insert (format "%s\nObserved through: %s\nMAC: %s\n\n"
                            (alist-get 'role device) (alist-get 'evidence device)
                            (or (and (not (string-empty-p (alist-get 'mac device))) (alist-get 'mac device)) "unknown")))
            (dolist (name (alist-get 'names device))
              (insert (format "Reported name: %s (%s)\n" (alist-get 'name name) (alist-get 'source name))))
            (cond ((alist-get 'os_clues device)
                   (dolist (clue (alist-get 'os_clues device))
                     (insert (format "Likely OS: %s (%s; not verified)\n"
                                     (alist-get 'name clue) (alist-get 'source clue)))))
                  ((alist-get 'identified device) (insert "OS: unknown — services gave no OS clue.\n"))
                  (t (insert "OS: not inspected.\n")))
            (insert "\n")
            (vikix-network--button "Inspect common TCP ports" #'vikix-network-ports)
            (vikix-network--button "Identify device" #'vikix-network-identify)
            (vikix-network--button "Friendly name" #'vikix-network-name)
            (insert "\n\n")
            (if (not (alist-get 'checked device)) (insert "Ports have not been checked.\n")
              (insert "Port names without a probe result are suggestions. Service and OS clues are tentative.\n\n")
              (dolist (port (alist-get 'ports device))
                (let ((number (alist-get 'port port)))
                  (insert (format "%5d/tcp  %-9s %s\n" number (alist-get 'state port) (alist-get 'service port)))
                  (when (alist-get 'probed port)
                    (insert "  Service probe: "
                            (string-join (delq nil (list (alist-get 'product port)
                                                        (alist-get 'version port)
                                                        (alist-get 'extra port))) " ") "\n"))
                  (when (equal (alist-get 'state port) "open")
                    (dolist (action (cond ((memq number '(80 443 8000 8080 8443 9090)) '("Browser"))
                                          ((= number 22) '("SSH terminal" "Remote files"))))
                      (let ((kind action) (ip (alist-get 'address device)))
                        (vikix-network--button action
                         (lambda () (with-current-buffer owner (vikix-network--connect kind ip number))))))
                    (insert "\n"))))
              (insert (or (alist-get 'other_ports device) "") "\n"))
            (insert "\nDiscovery may miss devices. No device history is kept.\n"))
          (goto-char (point-min)))))))

(defun vikix-network--connect (kind ip port)
  "A user action only. Addresses come from validated backend observations."
  (unless (and (string-match-p "\\`[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+\\'" ip)
               (integerp port) (< 0 port 65536))
    (user-error "Invalid service address"))
  (when vikix-network--process (user-error "Wait for the current request first"))
  (let ((identity vikix-network--network))
    (setq vikix-network--after
          (lambda ()
            (unless (cl-find identity (alist-get 'networks vikix-network--data)
                             :key (lambda (n) (alist-get 'id n)) :test #'equal)
              (user-error "Network changed; select the device again"))
            (vikix-network--open-service kind ip port)))
    (vikix-network--request "status")))

(defun vikix-network--open-service (kind ip port)
  (pcase kind
    ("Browser" (browse-url (format "%s://%s:%d/" (if (memq port '(443 8443)) "https" "http") ip port)))
    ((or "SSH terminal" "Remote files")
     (let ((user (read-string "Remote user: " (user-login-name))))
       (unless (string-match-p "\\`[a-zA-Z0-9_][a-zA-Z0-9_.-]*\\'" user)
         (user-error "Enter a remote login name"))
       (if (equal kind "Remote files")
           (dired (format "/ssh:%s@%s#%d:/" user ip port))
         (make-process :name "Network SSH" :noquery t :buffer nil
                       :command (list "alacritty" "-e" "ssh" "-p" (number-to-string port) "-l" user ip)))))))

(defun vikix-network--cleanup ()
  (when (timerp vikix-network--timer) (cancel-timer vikix-network--timer))
  (when (timerp vikix-network--deadline) (cancel-timer vikix-network--deadline))
  (when (process-live-p vikix-network--process)
    (interrupt-process vikix-network--process))
  (when (buffer-live-p vikix-network--detail) (kill-buffer vikix-network--detail)))

(defun vikix-network--frame-deleted (frame)
  (let ((buffer (frame-parameter frame 'vikix-network-buffer)))
    (when (buffer-live-p buffer) (kill-buffer buffer))))
(add-hook 'delete-frame-functions #'vikix-network--frame-deleted)

(defun vikix-network-close ()
  (interactive)
  (with-current-buffer (vikix-network--home)
    (let ((frame vikix-network--frame))
      (kill-buffer (current-buffer))
      (when (frame-live-p frame) (delete-frame frame)))))

(defvar vikix-network-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "TAB") #'forward-button)
    (define-key map (kbd "<backtab>") #'backward-button)
    (define-key map (kbd "RET") #'push-button)
    (define-key map (kbd "g") #'vikix-network-refresh)
    (define-key map (kbd "d") #'vikix-network-discover)
    (define-key map (kbd "p") #'vikix-network-ports)
    (define-key map (kbd "c") #'vikix-network-policy)
    (define-key map (kbd "s") #'vikix-network-stop)
    (define-key map (kbd "q") #'vikix-network-close)
    map))
;; The launcher reloads this file in an existing Emacs, whose map already exists.
(define-key vikix-network-mode-map (kbd "i") #'vikix-network-identify)
(define-key vikix-network-mode-map (kbd "n") #'vikix-network-name)
(define-derived-mode vikix-network-mode special-mode "Network Office"
  (visual-line-mode 1)
  (add-hook 'kill-buffer-hook #'vikix-network--cleanup nil t))

(defun vikix-network-open (display)
  "Open a dedicated frame, including from a daemon without graphical frames."
  (let ((existing (cl-find-if (lambda (f) (buffer-live-p (frame-parameter f 'vikix-network-buffer))) (frame-list))))
    (if existing
        (progn (select-frame-set-input-focus existing) (frame-parameter existing 'outer-window-id))
      (let* ((frame (make-frame `((display . ,display) (name . "Network Office")
                                  (width . 150) (height . 42) (menu-bar-lines . 0) (tool-bar-lines . 0))))
             (buffer (generate-new-buffer "*Network Office*"))
             (detail (generate-new-buffer "*Network device*")))
        (select-frame-set-input-focus frame)
        (set-frame-parameter frame 'vikix-network-buffer buffer)
        (delete-other-windows)
        (switch-to-buffer buffer)
        (set-window-buffer (split-window-right) detail)
        (with-current-buffer detail
          (special-mode)
          (visual-line-mode 1)
          (use-local-map vikix-network-mode-map)
          (setq-local vikix-network--owner buffer))
        (with-current-buffer buffer
          (vikix-network-mode)
          (setq vikix-network--detail detail vikix-network--frame frame)
          (vikix-network--request "status")
          (setq vikix-network--timer
                (run-at-time 10 10
                 (lambda ()
                   (when (buffer-live-p buffer)
                     (with-current-buffer buffer
                       (unless vikix-network--process (vikix-network-refresh))))))))
        nil))))

(provide 'vikix-network)
;;; vikix-network.el ends here
