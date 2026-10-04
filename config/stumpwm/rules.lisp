;;;; rules.lisp — your rules for the desktop.
;;;;
;;;; A rule says what happens by itself: a window on its workspace as it
;;;; opens, a program started when you log in, a reminder at a time of day.
;;;; This file is yours. Vikix made it once and never changes it, except to
;;;; add the rule you ask for with Super+Shift+t ("remember this window
;;;; here"), under a dated comment at its end.
;;;;
;;;; Every rule below is switched off: it has a ; in front. Take the ; away
;;;; from one (from each of its lines), change it to suit, and reload
;;;; (Super+m, Reload config). Then, in a terminal:
;;;;
;;;;   vikix rules          lists your rules, and says how often each ran
;;;;   vikix rules test     what they would do with the windows open now
;;;;   vikix rules why      why the window in front is where it is
;;;;   vikix rules verbs    everything a rule can match and do
;;;;
;;;; A mistake here costs only its own rule: you're told its line, and the
;;;; rest still load. A rule that fails when a window opens never stops the
;;;; desktop. The guide has the whole of it, and takes four ideas from the
;;;; wish to a rule that works: Super+m, Vikix guide, "Rules for the
;;;; desktop" (docs/rules.md in ~/vikix).

(in-package :stumpwm)

;;; Where windows go
;;;
;;; First what the window must be, then what to do with it. xprop WM_CLASS
;;; and a click on a window gives its instance, then its class.

;; Firefox opens on workspace 2, without showing here first.
; (when-window (:class "Firefox") (workspace 2))

;; Only its first window of a login; later ones open where you are.
; (when-window (:class "Firefox") :once t (workspace 2))

;; Your mail web app has a workspace of its own, and you go along.
; (when-window (:class "vikix-fastmail") (workspace 7 :follow t))

;;; Windows that float instead of taking a tile

;; The sound mixer: half the screen wide, in the middle.
; (when-window (:class (:has "pavucontrol")) (float :width "50%" :height "60%"))

;; A video's small window, in the bottom right corner, on every workspace.
; (when-window (:class "mpv" :title (:has "picture in picture"))
;   (float :width "30%" :height "30%" :corner :bottom-right)
;   (sticky))

;; A colour picker treated as a dialog: floating, centred, kept in front.
; (when-window (:class "Gcolor3") (dialog))

;;; The clock and the battery

;; A reminder at one o'clock, Monday to Friday.
; (at "13:00" :weekdays (notify "One o'clock" "Lunch. Step away from the screen."))

;; A new wallpaper every half hour.
; (each 30 :minutes (run "vikix-wallpaper next"))

;; Once, as the charge goes under 20% off the charger.
; (when-battery-below 20 (notify "Battery at 20%" "Time to find the charger."))

;; When the charger goes in, and when it comes out.
; (when-charging (say "On the charger"))
; (when-on-battery (say "On battery"))

;;; Once a login, and on arriving at a workspace

;; A program started with the desktop: once a login, not at every reload.
; (at-login (run "syncthing --no-browser"))

;; Workspace 6 is always a grid.
; (when-workspace 6 (command "vikix-grid"))

;;; Remembered windows
;;;
;;; Super+Shift+t on a window writes its rule here, below this line, as
;;; "remembered: ...". vikix rules forget N takes one out again.
