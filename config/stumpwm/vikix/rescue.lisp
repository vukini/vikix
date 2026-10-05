;;;; rescue.lisp — a way out when the desktop is stuck.
;;;;
;;;; StumpWM does everything in one thread: keys, windows, timers, what
;;;; `vikix eval` and the agents' tools ask. When that thread goes round
;;;; and round on something (a rule and the mouse chasing each other's
;;;; focus, 2026-10-05: 70% of a processor for a quarter of an hour, its
;;;; timers never run, every tool timing out), nothing in it can say so or
;;;; stop it. So this file works from outside that thread:
;;;;
;;;;   a beat     a timer notes every two seconds that the loop came round
;;;;   a watcher  another thread reads the beat and how hard the main
;;;;              thread works. No beat and working flat out is stuck: it
;;;;              writes down what the thread was doing, tells you in a
;;;;              notification, and after a minute eases it by itself
;;;;              (rules paused, focus on clicks), after three starts a
;;;;              fresh event loop. No beat and idle is only waiting (a menu
;;;;              or a prompt is open): nothing is done.
;;;;   a key      Super+Ctrl+Alt+Escape frees a stuck desktop. It is read
;;;;              on a connection to X of its own, by a third thread: it
;;;;              works when StumpWM's keys don't.
;;;;   a command  `vikix rescue` (bin/vikix-rescue) asks all this over
;;;;              Swank without going through the main thread, from any
;;;;              terminal, a text console (Ctrl+Alt+F2) or ssh.
;;;;
;;;; (setf *vikix-rescue-auto* nil) in user.lisp: say so, but do nothing
;;;; by itself. What easing changed stays until `vikix rescue undo` or a
;;;; reload: what made the loop is still there.

(in-package :stumpwm)

(defparameter *vikix-stuck-after* 15
  "Seconds without a beat, the main thread busy, before the desktop counts as stuck.")
(defparameter *vikix-stuck-ease-after* 60
  "Seconds stuck before the watcher eases it by itself (rules paused, focus on clicks).")
(defparameter *vikix-stuck-loop-after* 180
  "Seconds stuck before the watcher starts a fresh event loop by itself.")
(defvar *vikix-rescue-auto* t
  "NIL: the watcher tells you the desktop is stuck, and leaves freeing it to you.")
(defparameter *vikix-rescue-busy* 35
  "Percent of a processor the main thread must be using to count as busy, not waiting.")

(defvar *vikix-beat* (get-internal-real-time)
  "When the main loop last came round to its timers (internal real time).")
(defvar *vikix-beat-timer* nil)
(defvar *vikix-watch-thread* nil)
(defvar *vikix-rescue-key-thread* nil)
(defvar *vikix-watch* (list :at nil :ticks nil :said nil :eased nil :looped nil)
  "What the watcher remembers between its looks.")
(defvar *vikix-rescue-did* '()
  "What easing changed, to put back: (:rules) and (:focus OLD-POLICY).")
;; A reload puts rules and focus back itself (rules.lisp, windows.lisp).
(setf *vikix-rescue-did* '())

(defun vikix-beat () (setf *vikix-beat* (get-internal-real-time)))

(defun vikix-beat-age ()
  "Seconds since the main loop last came round."
  (/ (- (get-internal-real-time) *vikix-beat*) internal-time-units-per-second))

;;; --- How hard the main thread works ------------------------------------------------

(defun vikix-main-ticks ()
  "The processor time the main thread has used, in the kernel's ticks (100
a second), from /proc; nil when it can't be read."
  (ignore-errors
   (let* ((tid (sb-thread::thread-os-tid (sb-thread:main-thread)))
          (line (with-open-file (in (format nil "/proc/self/task/~d/stat" tid))
                  (read-line in)))
          ;; The name, in brackets, may hold spaces: count from after it.
          (fields (ppcre:split " " (subseq line (+ 2 (position #\) line :from-end t))))))
     (+ (parse-integer (nth 11 fields)) (parse-integer (nth 12 fields))))))

(defun vikix-main-busy (&optional (seconds 1/2))
  "Percent of a processor the main thread uses, measured over SECONDS.
Not for the main thread itself: it sleeps."
  (let ((before (vikix-main-ticks)))
    (sleep seconds)
    (let ((after (vikix-main-ticks)))
      (if (and before after)
          (round (- after before) seconds)      ; ticks are hundredths of a second
          0))))

(defun vikix-rescue-state (&optional busy)
  "How the desktop is: (:state :fine, :waiting or :stuck, :age SECONDS,
:busy PERCENT). BUSY, when given, is the main thread's work already measured."
  (let* ((age (vikix-beat-age))
         (busy (or busy (if (< age 6) 0 (vikix-main-busy)))))
    (list :state (cond ((< age 6) :fine)
                       ((>= busy *vikix-rescue-busy*) :stuck)
                       (t :waiting))
          :age (round age) :busy busy)))

;;; --- What the main thread is doing -----------------------------------------------

(defun vikix-main-backtrace (&optional (frames 30))
  "The main thread's stack as text, asked of it from another thread; nil
when it doesn't answer within two seconds."
  (if (in-main-thread-p)
      (ignore-errors (backtrace-string))
      (let ((text nil) (done (sb-thread:make-semaphore)))
        (ignore-errors
         (sb-thread:interrupt-thread
          (sb-thread:main-thread)
          (lambda ()
            (setf text (ignore-errors
                        (with-output-to-string (out)
                          (sb-debug:print-backtrace :stream out :count frames))))
            (sb-thread:signal-semaphore done))))
        (sb-thread:wait-on-semaphore done :timeout 2)
        text)))

(defun vikix-rules-running ()
  "The rules that ran in the last second, each with how often: a rule in a
loop shows here. Not for the main thread: it sleeps."
  (when (boundp '*vikix-rules*)
    (let ((before (mapcar (lambda (rule) (cons rule (vikix-rule-runs rule)))
                          (symbol-value '*vikix-rules*))))
      (sleep 1)
      (loop for (rule . runs) in before
            for now = (vikix-rule-runs rule)
            when (> now runs)
              collect (list (- now runs) (vikix-one-line (vikix-rule-text rule) 100))))))

(defun vikix-rescue-report ()
  "Print how the desktop is, in words, and what its main thread is doing.
Meant to be called from a thread that isn't the main one."
  (destructuring-bind (&key state age busy) (vikix-rescue-state)
    (ecase state
      (:fine (format t "The desktop is coming round: its loop last did ~d second~:p ago.~%" age age))
      (:waiting (format t "The desktop is waiting, not stuck: its loop hasn't come round for ~d seconds, but it is idle (~d% of a processor).~%A menu or a prompt of StumpWM's is probably open: Escape closes it.~%" age busy))
      (:stuck (format t "The desktop is stuck: its loop hasn't come round for ~d seconds, and it is working at ~d% of a processor.~%" age busy)))
    (format t "Rules: ~:[on~;paused~].  Focus follows ~:[clicks~;the mouse~].~%"
            (and (boundp '*vikix-rules-paused*) (symbol-value '*vikix-rules-paused*))
            (eq *mouse-focus-policy* :sloppy))
    (unless (in-main-thread-p)
      (let ((running (ignore-errors (vikix-rules-running))))
        (when running
          (format t "Rules that ran in the last second:~%~:{  ~d times: ~a~%~}" running))))
    (unless (eq state :fine)
      (let ((backtrace (vikix-main-backtrace 25)))
        (format t "What its main thread is doing:~%~a~%" (or backtrace "  (it didn't say within two seconds)"))))
    state))

;;; --- Freeing it ------------------------------------------------------------------------

(defun vikix-rescue-ease ()
  "The mild steps, plain settings another thread may make: no rule runs,
and focus stops following the mouse. Returns what it changed, in words."
  (let ((did '()))
    (when (and (boundp '*vikix-rules-paused*) (not (symbol-value '*vikix-rules-paused*)))
      (setf (symbol-value '*vikix-rules-paused*) t)
      (push '(:rules) *vikix-rescue-did*)
      (push "rules paused" did))
    (unless (eq *mouse-focus-policy* :click)
      (push (list :focus *mouse-focus-policy*) *vikix-rescue-did*)
      (setf *mouse-focus-policy* :click)
      (push "focus follows clicks, not the mouse" did))
    (nreverse did)))

(defun vikix-rescue-fresh-loop ()
  "Take the main thread out of what it is doing and into a fresh event
loop, as errors.lisp's \"carry on\" does. From another thread. True when
the thread took it."
  (let ((done (sb-thread:make-semaphore)))
    (ignore-errors
     (sb-thread:interrupt-thread
      (sb-thread:main-thread)
      (lambda ()
        (let ((restart (find-restart :new-io-loop)))
          (sb-thread:signal-semaphore done)
          (when restart
            (ignore-errors (vikix-repair-timers))
            (invoke-restart restart))))))
    (sb-thread:wait-on-semaphore done :timeout 3)))

(defun vikix-rescue-came-round-p (&optional (within 5))
  "Wait up to WITHIN seconds for a new beat. True when one came."
  (let ((beat *vikix-beat*))
    (loop repeat (* 4 within)
          do (when (/= beat *vikix-beat*) (return t))
             (sleep 1/4))))

(defun vikix-rescue-free ()
  "Free a stuck desktop: ease it, and if its loop still doesn't come round,
start a fresh one. Returns (values CAME-ROUND WHAT-WAS-DONE), the second a
list of words. From a thread that isn't the main one."
  (let ((did (vikix-rescue-ease)))
    (cond ((vikix-rescue-came-round-p 4) (values t did))
          (t (when (vikix-rescue-fresh-loop)
               (setf did (append did (list "a fresh event loop"))))
             (values (vikix-rescue-came-round-p 6) did)))))

(defun vikix-rescue-undo ()
  "Put back what easing changed. Returns it in words."
  (let ((undone '()))
    (dolist (change *vikix-rescue-did*)
      (case (first change)
        (:rules (when (boundp '*vikix-rules-paused*)
                  (setf (symbol-value '*vikix-rules-paused*) nil)
                  (push "rules on again" undone)))
        (:focus (setf *mouse-focus-policy* (second change))
                (push (format nil "focus follows ~:[clicks~;the mouse~] again" (eq (second change) :sloppy))
                      undone))))
    (setf *vikix-rescue-did* '())
    undone))

;;; --- Telling you, without the main thread -------------------------------------------

(defun vikix-rescue-notify (title body &optional (urgency "critical"))
  "A notification, sent by notify-send from this thread: dunst is another
program, and shows it though StumpWM is stuck."
  (ignore-errors
   (sb-ext:run-program "notify-send" (list "-a" "Vikix" "-u" urgency "--" title body)
                       :search t :wait nil :output nil :error nil)))

(defun vikix-rescue-words (did)
  (format nil "~:[Nothing needed changing~;~:*~{~a~^, ~}~]." did))

;;; --- The watcher ---------------------------------------------------------------------------

(defun vikix-watch-step ()
  "One look by the watcher thread, every three seconds."
  (let* ((now (get-internal-real-time))
         (ticks (vikix-main-ticks))
         (then (getf *vikix-watch* :at))
         (elapsed (and then (/ (- now then) internal-time-units-per-second)))
         (busy (if (and elapsed (plusp elapsed) ticks (getf *vikix-watch* :ticks))
                   (round (- ticks (getf *vikix-watch* :ticks)) elapsed)
                   0)))
    (setf (getf *vikix-watch* :at) now
          (getf *vikix-watch* :ticks) ticks)
    ;; Slept much longer than three seconds: the laptop was asleep, or this
    ;; thread was held up with all the others. The beat is old for that
    ;; reason alone; look again next time.
    (when (and elapsed (< elapsed 10))
      (destructuring-bind (&key state age &allow-other-keys) (vikix-rescue-state busy)
        (case state
          (:stuck
           (when (and (>= age *vikix-stuck-after*) (not (getf *vikix-watch* :said)))
             (setf (getf *vikix-watch* :said) t)
             (let ((backtrace (vikix-main-backtrace)))
               (vikix-error-report
                (make-condition 'simple-error
                                :format-control "The desktop's main loop hadn't come round for ~d seconds, working at ~d% of a processor."
                                :format-arguments (list age busy))
                "the watcher found the desktop stuck (rescue.lisp)" backtrace))
             (vikix-rescue-notify
              "The desktop is stuck"
              (format nil "Its loop hasn't come round for ~d seconds. Super+Ctrl+Alt+Escape frees it; so does `vikix rescue free` in a terminal, or on a text console (Ctrl+Alt+F2).~:[~; It eases itself in ~d seconds.~]"
                      age *vikix-rescue-auto* (max 0 (- *vikix-stuck-ease-after* age)))))
           (when (and *vikix-rescue-auto* (>= age *vikix-stuck-ease-after*) (not (getf *vikix-watch* :eased)))
             (setf (getf *vikix-watch* :eased) t)
             (let ((did (vikix-rescue-ease)))
               (vikix-rescue-notify "Still stuck: eased"
                                    (format nil "~a `vikix rescue undo` or Reload config puts it back." (vikix-rescue-words did)))))
           (when (and *vikix-rescue-auto* (>= age *vikix-stuck-loop-after*) (not (getf *vikix-watch* :looped)))
             (setf (getf *vikix-watch* :looped) t)
             (vikix-rescue-fresh-loop)
             (vikix-rescue-notify "Still stuck: a fresh event loop"
                                  "Your windows and settings stay as they are. `vikix rescue` says how it is now.")))
          (:fine
           (when (getf *vikix-watch* :said)
             (vikix-rescue-notify "The desktop is coming round again"
                                  (format nil "~:[~;Rules are paused and focus follows clicks until `vikix rescue undo` or Reload config. ~]What it was doing is written in ~~/.local/state/vikix/errors/."
                                          *vikix-rescue-did*)
                                  "normal"))
           (setf (getf *vikix-watch* :said) nil
                 (getf *vikix-watch* :eased) nil
                 (getf *vikix-watch* :looped) nil)))))))

(defun vikix-watch-loop ()
  ;; The step by name each time round, so a reload's new one is used.
  (loop (ignore-errors (funcall 'vikix-watch-step))
        (sleep 3)))

;;; --- The key: Super+Ctrl+Alt+Escape, on a connection of its own -----------------

(defun vikix-rescue-key-pressed ()
  "What the key does, in the key's own thread."
  (destructuring-bind (&key state age &allow-other-keys) (vikix-rescue-state)
    (if (eq state :fine)
        (vikix-rescue-notify "The desktop is coming round"
                             "Nothing to free. (This key, Super+Ctrl+Alt+Escape, is for when it is stuck.)"
                             "normal")
        (multiple-value-bind (came-round did) (vikix-rescue-free)
          (vikix-rescue-notify
           (if came-round "Freed" "Still not coming round")
           (format nil "It ~:[was waiting~;had been stuck~] for ~d seconds. ~a~:[ Try `vikix rescue` from a text console (Ctrl+Alt+F2).~; `vikix rescue undo` or Reload config puts rules and focus back.~]"
                   (eq state :stuck) age (vikix-rescue-words did) came-round))))))

(defun vikix-rescue-key-loop ()
  "Grab the key on a second connection to X and wait for it. Ends when X does."
  (let ((display (xlib:open-default-display)))
    (unwind-protect
         (let* ((escape #xff1b)
                (codes (multiple-value-list (xlib:keysym->keycodes display escape)))
                (super (or (ignore-errors (modifiers-super *modifiers*)) '(:mod-4)))
                (alt (or (ignore-errors (modifiers-meta *modifiers*)) '(:mod-1)))
                (numlock (or (ignore-errors (modifiers-numlock *modifiers*)) '(:mod-2)))
                (wanted (append '(:control) super alt)))
           (dolist (screen (xlib:display-roots display))
             (dolist (code codes)
               ;; With Caps Lock or Num Lock on, the key arrives with those too.
               (dolist (extra (list '() '(:lock) numlock (cons :lock numlock)))
                 (xlib:grab-key (xlib:screen-root screen) code
                                :modifiers (apply #'xlib:make-state-mask (append wanted extra))
                                :owner-p nil))))
           (xlib:display-finish-output display)
           (loop (xlib:event-case (display :force-output-p t)
                   (:key-press () (ignore-errors (funcall 'vikix-rescue-key-pressed)) t)
                   (t () t))))
      (ignore-errors (xlib:close-display display)))))

(defcommand vikix-rescue () ()
  "How the desktop is: coming round, waiting or stuck (`vikix rescue` in a terminal says more, and works when this can't)."
  (message "~a" (with-output-to-string (*standard-output*) (vikix-rescue-report))))

;;; --- Starting them ---------------------------------------------------------------------------

(defun vikix-thread-alive-p (thread)
  (and thread (sb-thread:thread-alive-p thread)))

;; Only on a desktop: without a screen (the tests that read this file)
;; there is no loop to watch and no key to grab.
(when (and (boundp '*screen-list*) *screen-list*)
  (ignore-errors
   (when (and *vikix-beat-timer* (timer-p *vikix-beat-timer*))
     (cancel-timer *vikix-beat-timer*)))
  (vikix-beat)
  (setf *vikix-beat-timer* (run-with-timer 2 2 'vikix-beat))
  (unless (vikix-thread-alive-p *vikix-watch-thread*)
    (setf *vikix-watch-thread*
          (sb-thread:make-thread 'vikix-watch-loop :name "vikix-watch")))
  (unless (vikix-thread-alive-p *vikix-rescue-key-thread*)
    (setf *vikix-rescue-key-thread*
          (sb-thread:make-thread (lambda () (ignore-errors (vikix-rescue-key-loop)))
                                 :name "vikix-rescue-key"))))
