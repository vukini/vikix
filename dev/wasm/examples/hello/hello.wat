;; hello.wat — WebAssembly written by hand, in its text form.
;;
;; A WebAssembly program can do nothing outside itself unless the host
;; hands it a function to call. Here that's WASI's fd_write, "write these
;; bytes to this file descriptor" (1 is the terminal). The text sits in the
;; module's own memory at byte 16; bytes 0-7 describe where it is and how
;; long (an "iovec"), which is what fd_write asks for.
(module
  (import "wasi_snapshot_preview1" "fd_write"
    (func $fd_write (param i32 i32 i32 i32) (result i32)))
  (memory (export "memory") 1)                       ;; one page: 64 KiB
  (data (i32.const 16) "Hello from WebAssembly\n")   ;; 23 bytes
  (func (export "_start")                            ;; where WASI starts a program
    (i32.store (i32.const 0) (i32.const 16))         ;; the text starts at 16
    (i32.store (i32.const 4) (i32.const 23))         ;; and is 23 bytes long
    (drop (call $fd_write
      (i32.const 1)     ;; to the terminal
      (i32.const 0)     ;; the iovec at 0
      (i32.const 1)     ;; one iovec
      (i32.const 8)))))  ;; where to put the number of bytes written
