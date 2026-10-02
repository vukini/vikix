# Nyxt, the browser you change in Lisp

Nyxt is a web browser written in Common Lisp, the language StumpWM is written in. Its keys, its commands and how it loads pages are all Lisp, and you can change them while it runs, the way you can change the desktop. Firefox stays your browser for the web at large; Nyxt is the one Vikix uses for its guides and docs, and the one to shape to your own reading.

It comes with the feature `lisp-apps`, beside Lem and McCLIM's Listener:

```sh
vikix add lisp-apps          # Nyxt, Lem and the Listener
vikix lisp-apps status       # what's here, and its colours
vikix remove lisp-apps       # takes them away again; your config stays
```

Nyxt is in the launcher (`Super+d`). Everything below is safe to try: your config is a file of your own, and the snapshot history keeps it.

## What Vikix sets up in Nyxt

- **Guides and docs open in it.** `Super+m` → *Vikix guide in the browser* and *Programming docs*, and `docs` in a terminal, open in Nyxt once it's installed.
- **It wears the desktop's colours.** Its status bar, prompts and messages take the theme's colours, and `vikix theme NAME` repaints a running Nyxt at once.
- **Emacs can reach into it.** A Lisp prompt inside the browser, on `127.0.0.1:4006`, with the same password as the desktop's.
- **Your config is yours.** `~/.config/nyxt/config.lisp`, copied once and never overwritten, loads Vikix's part first; what you write below that line wins.

Nyxt's own commands are one key away: `Ctrl+Space` asks for a command by name (type a few letters of it), and `Ctrl+Space`, then `manual`, opens Nyxt's manual.

## Guides and docs in Nyxt

The menu entries and the `docs` alias run `vikix-docs-open`, which hands local pages to Nyxt as `file://` addresses. If Nyxt is already open, the page joins it as a new tab, and StumpWM brings its window forward from whatever workspace it's on. Without Nyxt, `vikix-docs-open` uses `xdg-open`, your default browser.

To send guides and docs to another browser, name it in `~/.config/vikix/docs-browser`, one word on a line:

```sh
echo firefox > ~/.config/vikix/docs-browser
```

Delete the file to have Nyxt again. The rest of the web is unaffected either way: links from other programs go to your default browser (`~/.config/mimeapps.list`).

## Nyxt's colours

Nyxt reads the desktop's palette, `~/.config/vikix/theme/palette` (the `key=#rrggbb` lines `vikix theme` writes for every program), each time it starts, and builds a Nyxt theme from it. `vikix theme NAME` also asks a running Nyxt to read it again: the status bars and the message line change at once, and new tabs and prompts follow.

Pages keep their own colours. If Nyxt's dark mode is on (its settings can switch it on for every page), it darkens pages too; [No dark mode on the guide pages](#no-dark-mode-on-the-guide-pages) keeps it off Vikix's guide.

To keep Nyxt's own colours, take the line that loads Vikix's part out of your `config.lisp`. `vikix lisp-apps status` says which you have:

```
nyxt's colours follow vikix theme (~/.config/nyxt/config.lisp loads Vikix's part)
```

## Your Nyxt config

| Where | Whose | What |
|---|---|---|
| `~/.config/nyxt/config.lisp` | yours | Your settings, keys and commands, in Lisp (package `nyxt-user`). Copied once from Vikix's starter |
| `~/.local/share/vikix/nyxt/vikix.lisp` | Vikix's | The colours, the remote calls `vikix theme` makes, and Swank. A link into `~/vikix`, kept current by `vikix update`: don't edit it |

The starter `config.lisp` is a few lines: the `in-package` line, the load of Vikix's part, and room for yours below. A line of yours placed after the load wins over Vikix's. Two you may want:

```lisp
;; No Swank in Nyxt (see "Nyxt from Emacs").
(setf *vikix-swank-port* nil)

;; A light theme's pages unchanged: no dark mode on any page.
(define-configuration web-buffer
  ((default-modes (remove 'nyxt/mode/style:dark-mode %slot-value%))))
```

Nyxt reads `config.lisp` and Vikix's part when it starts, so a change takes effect at the next start (or at once, evaluated from Emacs). The snapshot history keeps all of `~/.config/nyxt`: `vikix changes` shows what changed there, and `vikix undo` takes it back. Nyxt writes settings of its own beside yours, in `auto-config.3.lisp` (what you change from its menus); the history keeps that too.

## Nyxt from Emacs

Swank is the program inside a running Lisp that lets Emacs's SLIME talk to it: evaluate code, look at values, jump to the source. StumpWM has one on port 4004 (see [How it fits together](how-it-works.md)); Vikix's part starts one in Nyxt on 4006.

### Connecting to Nyxt

1. In Emacs, `M-x slime-connect RET 127.0.0.1 RET 4006`. SLIME sends the password by itself. If it says the SLIME and Swank versions differ, answer `y`: it works.
2. You're at a REPL inside the browser, in the package `nyxt-user`. Try `(render-url (url (current-buffer)))`, the address of the page you're on.

It answers only on your own machine, and only with the password in `~/.slime-secret`, the same file StumpWM's Swank uses (Vikix makes it). Without that file, Nyxt's Swank doesn't start at all. A client that sends a wrong password, or none within 5 seconds, is turned away without taking Swank down for the next one.

Emacs can be connected to StumpWM and Nyxt at once. A Lisp buffer sends to the *default* connection, the last one made. `M-x slime-list-connections` shows them: the **Port** column tells them apart (4006 Nyxt, 4004 StumpWM) and `*` marks the default. On a line there, `d` makes it the default and `C-k` closes it. `M-x slime-cycle-connections` switches too.

### Evaluating in a Lisp buffer

Keep your experiments in a Lisp file (say `~/nyxt.lisp`) that starts with:

```lisp
(in-package #:nyxt-user)
```

SLIME reads that line to know the package. Without it the forms run in `cl-user`, and Nyxt's names, such as `define-command-global`, aren't found.

| Keys | What it sends to Nyxt |
|---|---|
| `C-M-x` | The top-level form around the cursor: the usual one for a command |
| `C-c C-c` | The same, compiled, with warnings shown on the code |
| `C-x C-e` | The expression before the cursor, such as `(title (current-buffer))`; the result shows in the echo area |
| `C-c C-r` | The region |
| `C-c C-k` | The whole file |

`~/.config/nyxt/config.lisp` starts with the same line, so you can work on it the same way. `C-c C-k` on it is safe: Vikix's part starts Swank only once.

A few things to try with `C-x C-e`:

- `(mapcar #'title (buffer-list))`: the titles of your open pages.
- `(render-url (url (current-buffer)))`: the current address.
- `M-.` on any Nyxt name (`render-url`, `print-status`) jumps into Nyxt's own source, in `/usr/share/nyxt/source/`; `M-,` comes back.

### Without Emacs

`nyxt --remote --quit --eval '(...)'` runs Lisp in the running Nyxt, over its socket in your runtime folder (`$XDG_RUNTIME_DIR/nyxt/nyxt.socket`, yours alone). It's what `vikix theme` uses. Whatever the code prints goes to Nyxt's log, `~/.local/share/nyxt/nyxt.log`, not to your terminal.

## Examples to try

Each of these was run against Nyxt 3.11.8, Void's package. Paste one into your Lisp buffer and `C-M-x` it to try it now; put it in `config.lisp`, below the load line, to keep it.

### Open the page in Firefox

Some sites work badly in WebKit, the engine Nyxt draws pages with. This command hands the page to Firefox:

```lisp
(define-command-global open-in-firefox ()
  "Open the current page in Firefox."
  (uiop:launch-program (list "firefox" (render-url (url (current-buffer)))))
  (echo "Sent to Firefox: ~a" (title (current-buffer))))
```

It's a command as soon as it's evaluated: `Ctrl+Space`, `open-in-f`, `Enter`. Change it and `C-M-x` again to replace it, with no restart.

### No dark mode on the guide pages

An auto-rule changes a page's modes when its address matches. This one keeps dark mode off Vikix's guide, which has colours of its own, and off the docs in `~/dev`, while other pages stay dark:

```lisp
;; Vikix's guide and ~/dev's docs have their own colours: no dark mode there.
(define-auto-rule
    `(match-regex ,(format nil "^file://~a\\.local/share/vikix/guide/"
                           (namestring (user-homedir-pathname)))
                  ,(format nil "^file://~adev/" (namestring (user-homedir-pathname))))
  :excluded '(nyxt/mode/style:dark-mode))
```

- The first part is the test. It's evaluated, and what comes back is called with the page's address. `match-regex` takes one or more patterns; the others are `match-domain`, `match-host`, `match-port`, `match-scheme` and `match-url`.
- `:excluded` turns modes off on matching pages, `:included` turns them on.
- Rules apply as a page loads: reload it (`Ctrl+r`, or `F5`) to see one.

### Page tools

A file of commands for what's on a page, made on a Vikix laptop as an example of what a few dozen lines of Lisp can add. Save the code below as `~/.config/nyxt/page-tools.lisp` and load it from `config.lisp`, below Vikix's line:

```lisp
(load (merge-pathnames "page-tools.lisp" (uiop:xdg-config-home "nyxt/")))
```

Then each is in `Ctrl+Space`:

| Command | What you get | Where it goes |
|---|---|---|
| `save-page-images` | Every picture on the page, in the page's order, each once | `~/Pictures/Nyxt/<page title>/` |
| `page-to-markdown` | The page's article (no menus or footers, when the page marks its article) as Markdown, links still working | `~/Documents/Nyxt/<page title>.md`, and the clipboard |
| `page-to-epub` | The page as an e-book, pictures inside, for an e-reader | `~/Documents/Nyxt/<page title>.epub` |
| `tabs-to-epub` | Every open tab as one e-book, a chapter each: a reading list | `~/Documents/Nyxt/Reading list <date>.epub` |
| `clip-selection` | The selected text as a quote, with the date, the page's title and its link | The end of `~/Documents/Nyxt/clips.md`, and the clipboard |
| `summarize-page` | A short summary in bullet points, and who the page is for | A page of its own in Nyxt, kept until Nyxt quits |
| `show-url-qrcode` | The page's address as a QR code, to open it on a phone | A page of its own (Nyxt's own command: nothing to add) |

Things to know about them:

- **They need pandoc** for Markdown and e-books (`vikix add cli-extras`), and **`llm`** for the summary (`vikix add llm`).
- **The summary goes to Claude.** `summarize-page` sends the page's text to Anthropic through `llm`, with the key from `vikix ai key set anthropic`, and takes seconds. To keep pages on the machine, set `*summary-model*` to `nil` in `config.lisp`, after the page tools' line: `llm`'s default model then answers (a local one, if that's what you chose), free and private, but it can take minutes on a long page and says less. For a small local model, set `*summary-max-chars*` near 6000 too.
- **Pictures behind a login don't come.** `save-page-images` fetches pictures itself, without the browser's cookies.
- **Pages that mark no article** (`<article>` or `<main>`) come whole, menus and all.
- **Where things go** can be changed: `*page-tools-folder*` (Markdown, e-books, clips) and `*clips-file*`, set in `config.lisp` after the page tools' line.

For the curious, how they read the page: `(document-model buffer)` is Nyxt's parsed copy of it (made with plump); `clss:select` finds elements in it with CSS selectors; `plump:clone-node` copies a part, so the page itself isn't changed; `make-addresses-whole`, in the file, makes links and pictures absolute so they still work away from the page; and `ps-eval` runs JavaScript written in Lisp (Parenscript) in the page, here to read the selection.

The file:

```lisp
(in-package #:nyxt-user)

;;; Page tools: a page's images, the page as Markdown or an e-book (or all
;;; open pages as one), the selection clipped to a notes file, and a summary
;;; by llm. The QR code of a page is Nyxt's own: show-url-qrcode.

(defvar *page-tools-folder* (merge-pathnames "Documents/Nyxt/" (user-homedir-pathname))
  "Where Markdown, e-books and clips go.")

(defvar *clips-file* (merge-pathnames "clips.md" *page-tools-folder*)
  "The notes file clip-selection adds to.")

(defvar *summary-model* "claude-sonnet-5"
  "The llm model summarize-page asks: Claude, through llm-anthropic and your
key (vikix ai key set anthropic). \"llama3.2:3b\" for the local one (slow on
the CPU: minutes a page, and less sharp); nil for llm's default.")

(defvar *summary-max-chars* 50000
  "How much of a page summarize-page sends: about 12,000 tokens, which
Claude reads in seconds. For a local model, 6000: Ollama's default context
cut a 4,000-token page short, and the CPU took five minutes to read it.")

;;; --- Helpers ----------------------------------------------------------------

(defun page-file-name (title)
  "TITLE as a file name: no slashes, no leading dot, not too long."
  (let ((name (string-trim " ." (substitute-if #\- (lambda (c) (find c "/\\:*?\"<>|")) title))))
    (subseq name 0 (min 80 (length name)))))

(defun page-url (buffer address)
  "ADDRESS (as written in the page, maybe relative) made whole against BUFFER's URL."
  (quri:render-uri (quri:merge-uris (quri:uri address) (url buffer))))

(defun image-address (img)
  "IMG's picture, as written in the page. Lazy-loading pages keep it in
data-src, with a placeholder (a data: URI) in src."
  (find-if (lambda (s) (and s (plusp (length s)) (not (str:starts-with-p "data:" s))))
           (list (plump:attribute img "src") (plump:attribute img "data-src"))))

(defun local-path (address)
  "The file behind a file:// ADDRESS, or ADDRESS as it is."
  (let ((uri (quri:uri address)))
    (if (string= "file" (quri:uri-scheme uri))
        (quri:url-decode (quri:uri-path uri))
        address)))

(defun pandoc (input &rest args)
  "Run pandoc on the string INPUT with ARGS; its output as a string."
  (with-input-from-string (in input)
    (uiop:run-program (cons "pandoc" args) :input in :output :string)))

(defun make-addresses-whole (buffer node &key local-images)
  "In NODE (a part of BUFFER's page, copied), links and pictures made whole,
so they still work away from the page. LOCAL-IMAGES: file:// pictures as
plain paths, which pandoc reads when it makes an e-book."
  (loop for a across (clss:select "a[href]" node)
        do (ignore-errors
            (setf (plump:attribute a "href") (page-url buffer (plump:attribute a "href")))))
  (loop for img across (clss:select "img" node)
        for src = (image-address img)
        when src do (ignore-errors
                     (let ((whole (page-url buffer src)))
                       (setf (plump:attribute img "src")
                             (if local-images (local-path whole) whole)))))
  node)

(defun page-html (buffer &key local-images)
  "BUFFER's article (else its main part, else all of it) as HTML, with
make-addresses-whole. A copy: the page isn't changed."
  (let* ((dom (document-model buffer))
         (part (or (loop for selector in '("article" "main" "body")
                         for found = (clss:select selector dom)
                         when (plusp (length found)) return (elt found 0))
                   dom))
         (node (plump:clone-node part t)))
    (plump:serialize (make-addresses-whole buffer node :local-images local-images) nil)))

(defun page-markdown (buffer &key local-images (shift 0))
  "BUFFER's article as Markdown. SHIFT moves its headings down that many levels."
  (pandoc (page-html buffer :local-images local-images)
          "-f" "html" "-t" "gfm-raw_html" "--wrap=none"
          (format nil "--shift-heading-level-by=~d" shift)))

(defun today ()
  (multiple-value-bind (s m h day month year) (get-decoded-time)
    (declare (ignore s))
    (format nil "~d-~2,'0d-~2,'0d ~2,'0d:~2,'0d" year month day h m)))

;;; --- Images -----------------------------------------------------------------

(define-command-global save-page-images ()
  "Save every image on the page into ~/Pictures/Nyxt/<page title>/."
  (let* ((buffer (current-buffer))
         (folder (merge-pathnames (format nil "Pictures/Nyxt/~a/" (page-file-name (title buffer)))
                                  (user-homedir-pathname)))
         (addresses
           (remove-duplicates
            (loop for img across (clss:select "img" (document-model buffer))
                  for src = (image-address img)
                  when src collect (page-url buffer src))
            :test #'string= :from-end t))
         (saved 0))
    (ensure-directories-exist folder)
    (loop for address in addresses
          for n from 1
          for name = (or (car (last (str:split "/" (quri:uri-path (quri:uri address)))))
                         "image")
          do (handler-case
                 ;; Numbered, so they keep the page's order, and two
                 ;; pictures with the same name don't overwrite each other.
                 (let ((to (merge-pathnames (format nil "~3,'0d-~a" n name) folder)))
                   (if (string= "file" (quri:uri-scheme (quri:uri address)))
                       (uiop:copy-file (local-path address) to)   ; a local page
                       (alexandria:write-byte-vector-into-file
                        (dex:get address :force-binary t) to :if-exists :supersede))
                   (incf saved))
               (error (e) (log:warn "Couldn't save ~a: ~a" address e))))
    (echo "Saved ~d of ~d images to ~a" saved (length addresses) (namestring folder))))

;;; --- Markdown and e-books ---------------------------------------------------

(define-command-global page-to-markdown ()
  "Save the page's article (or the whole page) as Markdown, in
~/Documents/Nyxt/<page title>.md, and copy it to the clipboard."
  (let* ((buffer (current-buffer))
         (file (merge-pathnames (format nil "~a.md" (page-file-name (title buffer)))
                                *page-tools-folder*))
         (markdown (format nil "# ~a~%~%Source: <~a>~%~%~a"
                           (title buffer) (render-url (url buffer)) (page-markdown buffer))))
    (ensure-directories-exist file)
    (alexandria:write-string-into-file markdown file :if-exists :supersede)
    (copy-to-clipboard markdown)
    (echo "Markdown saved to ~a (and copied)" (namestring file))))

(defun write-epub (title chapters file)
  "An EPUB at FILE called TITLE, from CHAPTERS: a list of (title url buffer)."
  (let ((markdown
          (with-output-to-string (out)
            (dolist (chapter chapters)
              (destructuring-bind (name address buffer) chapter
                ;; Each page a chapter: its title the top heading, its own
                ;; headings one level down.
                (format out "# ~a~%~%Source: <~a>~%~%~a~%~%"
                        name address (page-markdown buffer :local-images t :shift 1)))))))
    (ensure-directories-exist file)
    ;; Pandoc fetches the web pictures itself and puts them in the book.
    (pandoc markdown "-f" "gfm" "-t" "epub3" "-o" (namestring file)
            "--metadata" (format nil "title=~a" title)
            "--metadata" "lang=en")
    file))

(define-command-global page-to-epub ()
  "Save the page as an e-book, ~/Documents/Nyxt/<page title>.epub, pictures
included."
  (let* ((buffer (current-buffer))
         (file (merge-pathnames (format nil "~a.epub" (page-file-name (title buffer)))
                                *page-tools-folder*)))
    (echo "Making an e-book of ~a..." (title buffer))
    (write-epub (title buffer) (list (list (title buffer) (render-url (url buffer)) buffer)) file)
    (echo "E-book saved to ~a" (namestring file))))

(define-command-global tabs-to-epub ()
  "Save every open web page as one e-book, a chapter each:
~/Documents/Nyxt/Reading list <date>.epub."
  (let* ((buffers (remove-if-not (lambda (b) (and (typep b 'web-buffer)
                                                  (member (quri:uri-scheme (url b))
                                                          '("http" "https" "file")
                                                          :test #'equal)))
                                 (buffer-list)))
         (title (format nil "Reading list ~a" (subseq (today) 0 10)))
         (file (merge-pathnames (format nil "~a.epub" title) *page-tools-folder*)))
    (if (null buffers)
        (echo "No web pages open")
        (progn
          (echo "Making an e-book of ~d pages..." (length buffers))
          (write-epub title
                      (mapcar (lambda (b) (list (title b) (render-url (url b)) b)) buffers)
                      file)
          (echo "E-book of ~d pages saved to ~a" (length buffers) (namestring file))))))

;;; --- Clipping the selection -------------------------------------------------

(define-command-global clip-selection ()
  "Add the selected text, as a Markdown quote with the page's title and
address, to ~/Documents/Nyxt/clips.md, and copy it."
  (let* ((buffer (current-buffer))
         (html (ps-eval :buffer buffer
                 (let ((selection (ps:chain window (get-selection))))
                   (if (> (ps:@ selection range-count) 0)
                       (let ((div (ps:chain document (create-element "div"))))
                         (ps:chain div (append-child (ps:chain selection (get-range-at 0)
                                                               (clone-contents))))
                         (ps:@ div inner-h-t-m-l))
                       "")))))
    (if (or (null html) (string= (string-trim '(#\Space #\Newline) html) ""))
        (echo "Select some text first")
        (let* ((html (plump:serialize (make-addresses-whole buffer (plump:parse html)) nil))
               (markdown (string-trim '(#\Newline #\Space)
                                      (pandoc html "-f" "html" "-t" "gfm-raw_html" "--wrap=none")))
               (quote (format nil "~{> ~a~^~%~}" (str:lines markdown)))
               (clip (format nil "## ~a, [~a](~a)~%~%~a~%~%"
                             (today) (title buffer) (render-url (url buffer)) quote)))
          (ensure-directories-exist *clips-file*)
          (with-open-file (out *clips-file* :direction :output
                                            :if-exists :append :if-does-not-exist :create)
            (write-string clip out))
          (copy-to-clipboard clip)
          (echo "Clipped to ~a" (namestring *clips-file*))))))

;;; --- A summary by llm -------------------------------------------------------

(defvar *page-summaries* (make-hash-table :test #'equal)
  "Summaries made this session, by id: (title url markdown model).")

(define-internal-page page-summary (&key id)
    (:title "*Summary*")
  "A summary summarize-page made."
  (destructuring-bind (&optional title address markdown model) (gethash id *page-summaries*)
    (spinneret:with-html-string
      (:h1 (or title "Summary"))
      (:p (:a :href address address))
      (:raw (if markdown (pandoc markdown "-f" "gfm" "-t" "html") "<p>Gone: summarize the page again.</p>"))
      (:p (:small (format nil "By llm~@[ (~a)~]: a model's summary; check what matters." model))))))

(define-command-global summarize-page ()
  "Summarize the page with llm (your default model, or *summary-model*), in
a page of its own."
  (let* ((buffer (current-buffer))
         (text (page-markdown buffer))
         ;; Of a long page, the start (see *summary-max-chars*).
         (text (subseq text 0 (min (length text) *summary-max-chars*)))
         (id (princ-to-string (get-universal-time))))
    (echo "Summarizing ~a with llm..." (title buffer))
    (let ((summary
            (with-input-from-string (in text)
              (uiop:run-program
               (append (list "llm")
                       (when *summary-model* (list "-m" *summary-model*))
                       (list "-s" "Summarize this web page for a busy reader: 5 to 8 Markdown bullet points with the key facts, then one sentence on who it is for. Use only what the page says."))
               :input in :output :string :error-output :string))))
      (setf (gethash id *page-summaries*)
            (list (title buffer) (render-url (url buffer)) summary *summary-model*))
      (buffer-load-internal-page-focus 'page-summary :id id))))
```

A few things learned while writing it, in case you write your own:

- `remove-duplicates` keeps the *last* copy of each unless given `:from-end t`: without it the pictures came out of order.
- An empty result from `clss:select` is an empty vector, not `nil`, so `(or (clss:select "main" dom) ...)` never falls through: test its length.
- `show-url-qrcode` isn't in `nyxt-user`: from Lisp it's `nyxt/mode/document:show-url-qrcode`; from `Ctrl+Space`, its name is enough.
- `llm` takes the Anthropic key from the environment. A Nyxt started from the desktop has it.

## Ideas for your own

Some directions, from small to big, none of them built yet:

- **Commands that join Nyxt to the desktop:** add the page to a project's log (`vikix project log NAME "read: <title> <url>"`), open the site as a web app (`vikix webapp`), send the window to another workspace (`vikix eval`).
- **How pages load:** rewrite addresses (to a lighter front end of a site), block domains, switch scripts off on one site.
- **Your own `Ctrl+Space` sources:** every doc under `~/dev`, your project folders.
- **Pages of your own:** `define-internal-page`, as `summarize-page` uses, builds a page from Lisp when it's opened: a start page with your projects, say.

## When Nyxt misbehaves

- **A change to Vikix's part didn't take.** The theme follows `vikix theme` live, but a new `vikix.lisp` (after `vikix update`) and your own `config.lisp` are read when Nyxt starts. Quit Nyxt (`Ctrl+Space`, `quit`) and start it again; your tabs come back.
- **Nothing answers on 4006.** Nyxt isn't running, or it started without `~/.slime-secret`, or something else had the port. Its log, `~/.local/share/nyxt/nyxt.log`, says which ("Swank not started ...").
- **`C-x C-e` stops in the debugger with "invalid number of arguments: 3".** Nyxt's Swank is built into it and older than the SLIME Emacs installs, which sends a few calls more arguments. Vikix's part makes those calls take them (since Vikix 0.71.60), so this means it isn't loaded: check `vikix lisp-apps status`, then restart Nyxt.
- **A Nyxt with no window.** A `nyxt URL` started while another Nyxt was closing can be left behind: a process, but no window and no socket. It holds nothing useful: `pkill -x nyxt`, then start Nyxt again.
- **Your config stops partway after the checkout moved.** A `config.lisp` copied before Vikix 0.71.58 guards the load of Vikix's part with `probe-file`, which on SBCL lets through a link whose file has gone, and the error then stops the rest of your file. The starter now catches the error instead; change your load line to match it:

```lisp
(handler-case (load (merge-pathnames "vikix/nyxt/vikix.lisp" (uiop:xdg-data-home)))
  (file-error () nil))
```

- **A remote call printed nothing.** `nyxt --remote --eval` and Swank's output go to Nyxt's log or the REPL, never to the shell that sent them.

## For the curious: how Vikix's part works

All of it is `config/nyxt/vikix.lisp` in the checkout, one file of Lisp loaded into Nyxt:

- **The colours.** `vikix-palette` reads the palette file, keeping only `key=#rrggbb` lines; `vikix-make-theme` builds a `theme:theme` from `bg`, `fg`, `sel`, `subtle`, `dim`, `color5` (else `accent`), `color2` and `alert` (none without `bg` and `fg`). A method on `customize-instance` sets it as the browser starts, after your whole config has loaded.
- **The live repaint.** `vikix theme` runs `theme_nyxt` in `bin/vikix`: only when a Nyxt of yours is running, it sends `(vikix-theme-apply)` with `nyxt --remote --quit --eval`, and gives up after 3 seconds. That needs `remote-execution-p`, which the same file switches on. Nyxt works out each object's style once, when the object is made, so `vikix-fresh-style` runs a style slot's initial value again for each window's message line and status bar.
- **Swank.** `vikix-start-swank` runs from the same `customize-instance` method, so a `(setf *vikix-swank-port* nil)` anywhere in your config counts. It wraps Swank's password check in a 5-second limit and its accepting loop so a refused client ends only itself (`vikix-guard-swank`, StumpWM's guard from `swank-guard.lisp`, ported), and lets newer SLIME's calls through to the older Swank (`vikix-swank-accept-newer-calls`).
- **The docs.** `bin/vikix-docs-open` turns files into `file://` addresses and runs `nyxt` with them; a running Nyxt takes them over its socket. It then asks StumpWM, through `vikix eval`, to run `vikix-raise-class` (in `commands.lisp`), which brings the first window of class `Nyxt` forward.
