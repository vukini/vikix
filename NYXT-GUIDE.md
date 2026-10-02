# Nyxt guide: notes for a future guide

Material for a guide to Nyxt on Vikix (a `docs/nyxt.md` some day, written by the `explainer` agent in the guides' style). Gathered with Vid on 2026-10-02, while Nyxt became Vikix's docs browser, took the desktop's colours and got a Swank for Emacs (0.71.47 to 0.71.61). **Tested** marks what was run against Nyxt 3.11.8 (Void's package), on a hidden display with Vid's settings; the rest are ideas, not yet tried.

## What Vikix sets up

- **Guides and docs open in Nyxt** (0.71.47). `vikix-docs-open FILE|URL...` sends local guides and docs to Nyxt when it's installed (the feature `lisp-apps`), else `xdg-open`. Super+m → *Vikix guide in the browser*, *Programming docs*, and the `docs` alias use it. A running Nyxt gets the page as a new buffer, through its socket (`$XDG_RUNTIME_DIR/nyxt/nyxt.socket`), and StumpWM brings its window forward (`vikix-raise-class "Nyxt"`). `~/.config/vikix/docs-browser` (one word, such as `firefox`) names another browser. The rest of the web stays with the default browser.
- **The desktop's colours** (0.71.52). `~/.local/share/vikix/nyxt/vikix.lisp` (Vikix's, a link to `config/nyxt/vikix.lisp`) builds a Nyxt theme from `vikix theme`'s palette. `vikix theme NAME` repaints a running Nyxt over its socket. That needs remote execution, which the same file switches on.
- **Your config**: `~/.config/nyxt/config.lisp`, copied once, then yours. It loads Vikix's part first; anything below that line wins. Take the line out to keep Nyxt's own colours. `vikix lisp-apps status` says whether yours loads it.
- **Swank for Emacs** (0.71.57): `127.0.0.1:4006`, only when `~/.slime-secret` has a password, guarded as StumpWM's is (a wrong password, or none within 5 seconds, ends only that connection). `(setf *vikix-swank-port* nil)` below the load line keeps it closed. StumpWM's Swank is 4004; 4005 is left for your own SLIME.

## Connecting from Emacs

1. `M-x slime-connect RET 127.0.0.1 RET 4006`. SLIME sends the password by itself. If it says the versions differ, answer `y`.
2. The REPL is in the package `nyxt-user`.
3. Emacs may be connected to StumpWM and Nyxt at once. A Lisp buffer sends to the *default* connection, the last one made. `M-x slime-list-connections` shows them: the **Port** column tells them apart (4006 Nyxt, 4004 StumpWM), `*` marks the default, `d` on a line makes it the default, `R` removes a dead one. `M-x slime-cycle-connections` also switches.

## Evaluating in a buffer

Use a Lisp file (say `~/nyxt.lisp`) that starts with:

```lisp
(in-package #:nyxt-user)
```

SLIME reads that line for the package; without it the forms run in `cl-user`, and `define-command-global` isn't found.

| Keys | What it sends |
|---|---|
| `C-M-x` | the top-level form around the cursor (the usual one for a `define-command-global`) |
| `C-c C-c` | the same, compiled, with warnings shown on the code |
| `C-x C-e` | the expression before the cursor, e.g. `(title (current-buffer))`; the result in the echo area |
| `C-c C-r` | the region |
| `C-c C-k` | the whole file |

`~/.config/nyxt/config.lisp` starts with the same `in-package` line, so it can be worked on the same way. `C-c C-k` on it is safe: Vikix's part starts Swank only once.

Without Emacs: `nyxt --remote --quit --eval '(...)'` runs Lisp in a running Nyxt over its socket (what `vikix theme` uses). Its output goes to Nyxt's log, `~/.local/share/nyxt/nyxt.log`, not to the terminal.

## Examples

### A command: open the page in Firefox (tested)

Some sites don't work well in WebKit; this hands the page to Firefox. It's in Ctrl+Space as soon as it's evaluated.

```lisp
(define-command-global open-in-firefox ()
  "Open the current page in Firefox."
  (uiop:launch-program (list "firefox" (render-url (url (current-buffer)))))
  (echo "Sent to Firefox: ~a" (title (current-buffer))))
```

Then: Ctrl+Space, `open-in-f`, Enter. Edit it and `C-M-x` again to replace it live, no restart.

### An auto-rule: no dark mode on the guide pages (tested)

Nyxt's settings (its auto-config) may turn dark mode on for every page; Vikix's guide has colours of its own. With the rule the guide shows light and other pages stay dark; without it, the guide is turned dark.

```lisp
;; Vikix's guide pages have their own colours: no dark mode there.
(define-auto-rule
    `(match-regex ,(format nil "^file://~a\\.local/share/vikix/guide/"
                           (namestring (user-homedir-pathname))))
  :excluded '(nyxt/mode/style:dark-mode))
```

- `define-auto-rule`: when a page's address matches the test, change its modes. `:excluded` turns modes off, `:included` turns them on.
- The test is evaluated, and its result called with the URL. The other tests: `match-domain`, `match-host`, `match-port`, `match-scheme`, `match-url`, or a URL string for one page exactly.
- Rules apply as a page loads: reload (`r`) or open the page fresh to see one.
- `match-regex` takes several patterns. `~/dev`'s docs too: add `,(format nil "^file://~adev/" (namestring (user-homedir-pathname)))`. Python's and Rust's docs have dark themes of their own, which dark mode would turn back to light.

### Page tools: images, Markdown, e-books, clips, a summary (tested)

Six commands in one file, built with Vid on 2026-10-02 and installed on the laptop as `~/.config/nyxt/page-tools.lisp`, loaded from `config.lisp` by `(load (merge-pathnames "page-tools.lisp" (uiop:xdg-config-home "nyxt/")))`. Tried on a test page (relative, absolute, duplicated and lazy-loaded images, an article between a menu and a footer), a Vikix guide page (`file://`, with a diagram) and the Common Lisp Cookbook over HTTPS.

| Command | What it does |
|---|---|
| `save-page-images` | every picture into `~/Pictures/Nyxt/<page title>/`, numbered in page order, each once; lazy-loaded ones by their real address (`data-src`); `file://` ones copied from disk, the rest fetched with dexador (without the page's cookies: pictures behind a login won't come) |
| `page-to-markdown` | the page's `<article>` (else `<main>`, else everything) through pandoc into `~/Documents/Nyxt/<page title>.md`, with a title line and the source; also onto the clipboard |
| `page-to-epub` | the same as an EPUB, pictures inside (pandoc fetches web pictures itself; local ones are given as paths) |
| `tabs-to-epub` | every open web page as one book, a chapter each, `Reading list <date>.epub` |
| `clip-selection` | the selection as a Markdown quote under `## <date>, [title](url)`, appended to `~/Documents/Nyxt/clips.md` and copied; "Select some text first" when nothing is |
| `summarize-page` | the page's Markdown through `llm` (Claude, `claude-sonnet-5`), shown in a `nyxt:` page of its own (`define-internal-page`; the summary is kept in a table and the page gets only its id, as a summary is too long for an address) |
| `show-url-qrcode` | Nyxt's own (in `nyxt/mode/document`): the page's address as a QR code, for the phone. Nothing to build |

How it works: `(document-model buffer)` is Nyxt's parsed copy of the page (plump); `clss:select` finds elements with CSS selectors; `plump:clone-node` copies a part, so the page itself isn't changed; `make-addresses-whole` makes links and pictures absolute so they work away from the page; `ps-eval` runs JavaScript written in Lisp (Parenscript) in the page, here to read the selection's HTML.

Settings at the top of the file, to `setf` in `config.lisp` after the load line: `*page-tools-folder*`, `*clips-file*`, `*summary-model*`, `*summary-max-chars*`.

Mistakes made on the way, worth a line in the guide:

- `remove-duplicates` keeps the *last* copy unless given `:from-end t`: the pictures came out of order.
- An empty result from `clss:select` is a vector, not nil, so `(or (clss:select "main" dom) ...)` never falls through.
- The local model (`llama3.2:3b`) took 9 minutes on the Cookbook page (12 tokens a second to read it, 2 to write) and Ollama's default context cut the page short anyway; the summary was generic. Claude took 13 seconds and wrote a specific one. A local model wants `*summary-max-chars*` near 6000.
- `show-url-qrcode` isn't in `nyxt-user`: from Lisp it's `nyxt/mode/document:show-url-qrcode`; from Ctrl+Space just its name.
- `llm` takes the Anthropic key from the environment: Nyxt started in the session has it (`vikix ai key set anthropic`).

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

### Small things to try (tested)

- `(mapcar #'title (buffer-list))` with `C-x C-e`: your open pages.
- `(render-url (url (current-buffer)))`: the current address.
- `M-.` on any Nyxt name (`render-url`, `print-status`) jumps into Nyxt's source in `/usr/share/nyxt/source/`; `M-,` comes back.

### Ideas, not yet written

From small to big:

1. **Commands that join Nyxt to the desktop**: add the page to a project's log (`vikix project log NAME "read: <title> <url>"`); open the site as a web app (`vikix webapp`); show a file in Esploro; send the window to a workspace (`vikix eval`).
2. **How pages load**: rewrite addresses (reddit → old.reddit, YouTube → a lighter front end); block domains (Nyxt's request hook); per-site rules (scripts off on one site).
3. **The page itself**: JavaScript run from Lisp, or the page's parsed copy (see the page tools), to fill in a form, or anything in "To do" below.
4. **Your own Ctrl+Space sources**: every doc under `~/dev`; `vikix project` folders; links from Obsidian notes.
5. **Your own `nyxt:` pages** (Spinneret, HTML written as Lisp, built when opened): a start page with the projects and their next steps, `vikix today`, the key card made from StumpWM.
6. **A `vikix learn c` lesson page** with a **Check** button that runs the checker and shows the result beside the lesson.

## To do: page tools not yet built

Ideas from the same conversation (2026-10-02), in the vein of the page tools above. Build each as the others were: on a hidden display, then into `page-tools.lisp` and this file.

1. **Tables → CSV.** Each `<table>` on the page into a CSV file, for a spreadsheet: `clss:select "table"`, rows and cells from the parsed copy.
2. **Save the page's code blocks.** Every `<pre><code>` to files, or a prompt to pick one and copy it (the "send a block to a terminal" idea, done properly).
3. **Download every link of a kind**, e.g. every PDF on a course page (`a[href$=".pdf"]`), into one folder, as save-page-images does.
4. **All open tabs as a Markdown list** of titles and links, to keep a research session.
5. **Ask a question about the page**: summarize-page's route, with a prompt for the question.
6. **Add the page to `note`'s index**, so `note ask` finds it beside your notes.
7. **Reader view**: the page's Markdown rendered back as a clean `nyxt:` page in the guide's style.
8. **Jump to a heading**: the page's headings as a Ctrl+Space source; pick one to scroll there.
9. **Play the page's video in mpv** (with `yt-dlp`).
10. **Clip into a project's log**: clip-selection's quote through `vikix project log NAME`, with a prompt for the project.
11. **A QR code of a link or of the selection**, not only the page: `cl-qrencode` as `show-url-qrcode` uses it.

## Things learned the hard way (for the guide's "when it goes wrong")

- **"invalid number of arguments: 3" on `C-x C-e`.** Nyxt's Swank is built into it and older than MELPA's SLIME, which sends the evaluating calls lines and width, and the macroexpand calls an environment. Since 0.71.60 Vikix's part wraps those calls. The REPL itself always worked.
- **Changes to Vikix's part need a Nyxt restart.** The theme follows `vikix theme` live, but a new `vikix.lisp` (after `vikix update`) is read when Nyxt starts. Quitting and starting Nyxt brings the tabs back.
- **A Nyxt process that isn't a browser.** A `nyxt URL` started while another Nyxt was closing can be left behind: a process, but no window StumpWM lists and no socket. It holds nothing useful; `pkill -x nyxt`, then start Nyxt.
- **Nothing on 4006?** Nyxt isn't running, or started without `~/.slime-secret` (its log says "Swank not started"), or something else held the port (also in the log).
- **A config.lisp copied before 0.71.58** guards the load with `probe-file`, which passes a link whose file has gone (SBCL), so a moved checkout stops the rest of the file. The starter now catches `load`'s `file-error` instead: `(handler-case (load ...) (file-error () nil))`.
- **Remote eval and Swank output** go to Nyxt's log or the REPL, never to the shell that sent them.
