;;; Compiled by setup, never by a pattern file. No samples or microphone.
(load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
(ql:quickload :cl-collider :silent t)
(in-package :sc-user)
(let* ((sc::*s* nil)
       (definition (defsynth vikix-tone ((freq 440) (dur 0.3) (amp 0.08))
                     (let* ((envelope (env-gen.kr (env '(0 1 0) (list 0.005 dur)) :act :free))
                            (signal (* (sin-osc.ar freq) envelope amp)))
                       (out.ar 0 (list signal signal))))))
  (with-open-file (out (sb-ext:posix-getenv "VIKIX_MUSIC_SYNTH")
                       :direction :output :if-exists :supersede
                       :element-type '(unsigned-byte 8))
    (write-sequence (sc::encode-synthdef definition) out)))
