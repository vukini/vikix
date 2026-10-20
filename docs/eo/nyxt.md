# Nyxt, la retumilo, kiun vi povas ŝanĝi per Lisp

Nyxt estas retumilo skribita en Common Lisp, la lingvo en kiu ankaŭ StumpWM estas skribita. Ĝiaj klavoj, ĝiaj komandoj kaj la maniero kiel ĝi ŝargas paĝojn, ĉio estas Lisp, kaj vi povas ŝanĝi ilin dum ĝi funkcias, same kiel vi povas ŝanĝi la labortablon. Firefox restas via retumilo por la vasta interreto; Nyxt estas la retumilo, kiun Vikix uzas por siaj gvidiloj kaj dokumentoj, kaj la retumilo, kiun vi povas prilabori por konveni al via propra legmaniero.

Ĝi venas kun la funkcio `lisp-apps`, krom la programoj Lem kaj la aŭskultilo de McCLIM:

```sh
vikix add lisp-apps          # Nyxt, Lem and the Listener
vikix lisp-apps status       # what's here, and its colours
vikix remove lisp-apps       # takes them away again; your config stays
```

Nyxt estas en la lanĉilo (`Super+d`). Ĉio sube estas sekura por provi: via konfiguracia dosiero estas via propra, kaj la historio de la kopioj konservas ĝin.

## Kion Vikix agordas en Nyxt

- **Gvidiloj kaj dokumentoj malfermiĝas en ĝi.** `Super+m` → *Gvidilo de Vikix en la navigilo* kaj *Programadaj dokumentoj*, kaj `docs` en terminalo, malfermiĝas en Nyxt post instalado.
- **Ĝi portas la kolorojn de la labortablo.** Ĝia stato-barao, petoj kaj mesaĝoj prenas la kolorojn de la temo, kaj `vikix theme NOMO` tuj re-pentras funkציantan Nyxt.
- **Emacs povas atingi ĝin.** Lisp-petilo ene de la navigilo, ĉe `127.0.0.1:4006`, kun la sama pasvorto kiel la labortablo.
- **Via konfiguracio estas via.** `~/.config/nyxt/config.lisp`, kopiita unufoje kaj neniam anstataŭigita, unue ŝargas la parton de Vikix; ĉio, kion vi skribas sub tiu linio, venkas.

La propraj komandoj de Nyxt estas nur unu klavo for: `Ctrl+Space` petas komandon laŭnome (tipu kelkajn literojn de ĝi), kaj `Ctrl+Space`, poste `manual`, malfermas la manlibron de Nyxt.

## Gvidiloj kaj dokumentoj en Nyxt

La menuaj eniroj kaj la aliaso `docs` faras `vikix-docs-open`, kiu transdonas lokajn paĝojn al Nyxt kiel `file://` adresoj. Se Nyxt jam estas malfermita, la paĝo aliĝas al ĝi kiel nova langeto, kaj StumpWM alportas ĝian fenestron al la avantaĝo de ĉiu labra spaco. Sen Nyxt, `vikix-docs-open` uzas `xdg-open`, vian defaŭltan navigilon.

Por sendi gvidilojn kaj dokumentojn al alia navigilo, nomu ĝin en `~/.config/vikix/docs-browser`, unu vorto sur unu linio:

```sh
echo firefox > ~/.config/vikix/docs-browser
```

Forigi la dosieron por rehavi Nyxt. La resto de la interreto restas netuŝita: ligoj el aliaj programoj direktiĝas al via defolta navigilo (`~/.config/mimeapps.list`).

**Ĉiu dokumento, kiel paĝo.** `Super+F2` serĉas en ĉiuj dokumentoj en la maŝino (ĉi tiuj gvidiloj, manpaĝoj, dokumentoj kaj PDF-oj de viaj projektoj, viaj notoj, la API-referencoj en la dokumentaroj de Zeal, kaj ligoj al la interreto, kiuj tion diras) kaj montras la rezultojn en listo. Kun Nyxt, la sama serĉo ankaŭ estas paĝo: `Super+m` → *Ĉiu dokumento kiel paĝo en Nyxt*, `vikix docs page WORDS` en terminalo, aŭ `Ctrl+Space`, poste `vikix-docs`, en Nyxt mem. La rezultoj estas grupigitaj laŭ ilia fonto, ĉiu kun butono *Malfermi* kaj, se ekzistas alia loko por legi ĝin, dua butono nomata por ĝi (*En Emacs*, *En terminalo*); *Trovi…* serĉas denove. Nyxt estas lanĉata se ĝi ne funkcias, kaj ĝia fenestro aperas antaŭe.

## Koloroj de Nyxt

Nyxt legas la paletron de la labortablo, `~/.config/vikix/theme/palette` (la linioj `key=#rrggbb`, kiujn `vikix theme` skribas por ĉiu programo), ĉiufoje kiam ĝi komenciĝas, kaj konstruas temon por Nyxt el ĝi. `vikix theme NAME` ankaŭ petas funkciantan Nyxt-on legi ĝin denove: la statusbaroj kaj la mesaĝlinio ŝanĝiĝas tuj, kaj novaj langetoj kaj promptoj sekvas.

Paĝoj konservas siajn proprajn kolorojn. Se la malluma reĝimo de Nyxt estas aktivigita (ĝiaj agordoj povas aktivigi ĝin por ĉiu paĝo), ĝi ankaŭ malheligas paĝojn; [Neniu malluma reĝimo en la gvidpaĝoj](#neniu-malhela-reĝimo-en-la-gvidaj-paĝoj) tenas ĝin malaktivigita en la gvidlibro de Vikix.

Por konservi la proprajn kolorojn de Nyxt, forigu la linion, kiu ŝargas la parton de Vikix el via `config.lisp`. `vikix lisp-apps status` diras, kiujn vi havas:

```
nyxt's colours follow vikix theme (~/.config/nyxt/config.lisp loads Vikix's part)
```

## Via konfiguraj dosiero de Nyxt

| Kio | De kiu | Kio enhavas |
|---|---|---|
| `~/.config/nyxt/config.lisp` | Via | Viaj agordoj, ŝlosiloj kaj komandoj, en la lingvo Lisp (paketo `nyxt-user`). Unufoje kopia de la komenca dosiero de Vikix |
| `~/.local/share/vikix/nyxt/vikix.lisp` | De Vikix | La koloroj, la foraj alvokoj, kiujn `vikix theme` faras, kaj Swank. Ligo al `~/vikix`, kiun `vikix update` tenas ĝisdata: ne redaktu ĝin |

La komenca `config.lisp` enhavas kelkajn liniojn: la linio `in-package`, la alŝtado de la parto de Vikix, kaj spaco por viaj agordoj sube. Via linio, metita post la alŝtado, superregas tiun de Vikix. Du linioj, kiujn vi eble volas aldoni:

```lisp
;; No Swank in Nyxt (see "Nyxt from Emacs").
(setf *vikix-swank-port* nil)

;; A light theme's pages unchanged: no dark mode on any page.
(define-configuration web-buffer
  ((default-modes (remove 'nyxt/mode/style:dark-mode %slot-value%))))
```

Nyxt legas la dosieron `config.lisp` kaj la parton de Vikix kiam ĝi komenciĝas, do ŝanĝo efikas ĉe la sekva starto (aŭ tuj, se ĝi estas kalkulita de Emacs). La historio konservas ĉiujn datumojn de `~/.config/nyxt`: `vikix changes` montras, kio ŝanĝiĝis tie, kaj `vikix undo` malfarigas la ŝanĝojn. Nyxt skribas siajn proprajn agordojn krom viaj, en la dosiero `auto-config.3.lisp` (tio, kion vi ŝanĝas de ĝiaj menuoj); la historio ankaŭ konservas tiujn.

## Nyxt de Emacs

Swank estas la programo ene de funkcia Lisp, kiu permesas al SLIME de Emacs komuniki kun ĝi: kalkuli kodon, kontroli valorojn, iri al la fonto. StumpWM havas ĝin sur la pordo 4004 (vidu [Kiel ĝi kunlaboras](how-it-works.md)); la parto de Vikix startigas ĝin en Nyxt sur la pordo 4006.

### Konekto al Nyxt

1. En Emacs, `M-x slime-connect RET 127.0.0.1 RET 4006`. SLIME sendas la pasvorton mem. Se ĝi diras, ke la versioj de SLIME kaj Swank malsamas, respondu `j`: ĝi funkcios.
2. Vi estos en REPL ene de la navigilo, en la paketo `nyxt-user`. Provu `(render-url (url (current-buffer)))`, la adreso de la paĝo, kie vi estas.

Ĝi respondas nur sur via propra maŝino, kaj nur kun la pasvorto en `~/.slime-secret`, la sama dosiero, kiun uzas Swank de StumpWM (Vikix kreas ĝin). Sen tiu dosiero, Swank de Nyxt tute ne startiĝos. Kliento, kiu sendas malĝustan pasvorton aŭ neniun ene de 5 sekundoj, estos forigita sen malŝalti Swank por la sekva.

Emacs povas esti konektita al StumpWM kaj Nyxt samtempe. Lisp-bufro sendas al la *defaŭlta* konekto, la lasta kreita. `M-x slime-list-connections` montras ilin: la kolumno **Port** distingas ilin (4006 Nyxt, 4004 StumpWM), kaj `*` markas la defaŭltan. Sur linio tie, `d` igas ĝin la defaŭlta kaj `C-k` fermas ĝin. `M-x slime-cycle-connections` ankaŭ ŝanĝas.

### Kalkulado en Lisp-bufro

Konservu viajn eksperimentojn en Lisp-dosiero (ekzemple `~/nyxt.lisp`), kiu komenciĝas per:

```lisp
(in-package #:nyxt-user)
```

SLIME legas tiun linion por identigi la pakon. Sen ĝi, la formularoj funkcios en `cl-user`, kaj la nomoj de Nyxt, kiel `define-command-global`, ne estos trovitaj.

| Klaviĝoj | Kion ĝi sendas al Nyxt |
|---|---|
| `C-M-x` | La ĉefa formulo ĉirkaŭ la kursoro: la kutima por komando |
| `C-c C-c` | La sama, kompilita, kun avertoj montritaj sur la kodo |
| `C-x C-e` | La esprimo antaŭ la kursoro, kiel `(title (current-buffer))`; la rezulto aperas en la ekziga areo |
| `C-c C-r` | La regiono |
| `C-c C-k` | La tuta dosiero |

`~/.config/nyxt/config.lisp` komenciĝas per la sama linio, do vi povas labori pri ĝi laŭ la sama maniero. `C-c C-k` sur ĝi estas sekura: la parto de Vikix komencas Swank nur unufoje.

Kelkaj aferoj, kiujn vi povas provi kun `C-x C-e`:

- `(mapcar #'title (buffer-list))`: la titoloj de viaj malfermitaj paĝoj.
- `(render-url (url (current-buffer)))`: la nuna adreso.
- `M-.` sur ajna nomo de Nyxt (`render-url`, `print-status`) saltas al la propra fontokodo de Nyxt, en `/usr/share/nyxt/source/`; `M-,` revenas.

### Sen Emacs

`nyxt --remote --quit --eval '(...)'` igas Lisp funkcii en la funkcianta Nyxt, per ĝia soketo en via provizora dosierujo (`$XDG_RUNTIME_DIR/nyxt/nyxt.socket`, nur por vi). Ĝi estas tio, kion `vikix theme` uzas. Ĉio, kion la kodo eldonas, iras al la protokolo de Nyxt, `~/.local/share/nyxt/nyxt.log`, ne al via terminalo.

## Ekzemploj por provi

Ĉiu el ĉi tiuj estis igita funkcii kontraŭ Nyxt 3.11.8, la pako de Void. Kopiu unu en vian Lisp-bufron kaj `C-M-x`-igu ĝin por provi ĝin nun; metu ĝin en `config.lisp`, sub la linio de ŝarĝo, por konservi ĝin.

### Malfermu la paĝon en Firefox

Kelkaj retejoj funkcias malbone en WebKit, la motoro, per kiu Nyxt desegnas paĝojn. Ĉi tiu komando transdonas la paĝon al Firefox:

```lisp
(define-command-global open-in-firefox ()
  "Open the current page in Firefox."
  (uiop:launch-program (list "firefox" (render-url (url (current-buffer)))))
  (echo "Sent to Firefox: ~a" (title (current-buffer))))
```

Ĝi estas komando, tuj post ĝia ekzekuto: `Ctrl+Space`, `open-in-f`, `Enter`. Ŝanĝu ĝin, kaj denove `C-M-x` por anstataŭigi, sen restartigo.

### Neniu malhela reĝimo en la gvidaj paĝoj

Aŭtomata regulo ŝanĝas la reĝimojn de paĝo, kiam ĝia adreso kongruas. Ĉi tiu regulo malŝaltas la malhelan reĝimon por la gvidpaĝo de Vikix, kiu havas siajn proprajn kolorojn, kaj por la dokumentoj en `~/dev`, dum aliaj paĝoj restas en malhela reĝimo:

```lisp
;; Vikix's guide and ~/dev's docs have their own colours: no dark mode there.
(define-auto-rule
    `(match-regex ,(format nil "^file://~a\\.local/share/vikix/guide/"
                           (namestring (user-homedir-pathname)))
                  ,(format nil "^file://~adev/" (namestring (user-homedir-pathname))))
  :excluded '(nyxt/mode/style:dark-mode))
```

- La unua parto estas la testo. Ĝi estas taksata, kaj la rezulto estas alsendata kun la adreso de la paĝo. `match-regex` prenas unu aŭ pli da ŝablonoj; la aliaj estas `match-domain`, `match-host`, `match-port`, `match-scheme` kaj `match-url`.
- `:excluded` malŝaltas reĝimojn sur la kongruaj paĝoj, `:included` ŝaltas ilin.
- Reguloj aplikiĝas dum la paĝo ŝarĝiĝas: refreŝigu ĝin (`Ctrl+r`, aŭ `F5`) por vidi ekzemplon.

### Paĝaj iloj

Dosiero de komandoj por tio, kio troviĝas sur paĝo, kreita sur komputilo Vikix kiel ekzemplo de tio, kion kelkaj dekoj da linioj de Lisp povas aldoni. Konservu la kodon sube kiel `~/.config/nyxt/page-tools.lisp` kaj ŝarĝu ĝin el `config.lisp`, sub la linio de Vikix:

```lisp
(load (merge-pathnames "page-tools.lisp" (uiop:xdg-config-home "nyxt/")))
```

Tiam ĉiu estas disponebla per `Ctrl+Space`:

| Komando | Kion vi ricevas | Kien ĝi iras |
|---|---|---|
| `save-page-images` | Ĉiun bildon en la paĝo, laŭ la ordo de la paĝo, ĉiu unufoje | `~/Pictures/Nyxt/<titolo de la paĝo>/` |
| `page-to-markdown` | La artikolo de la paĝo (neniuoj menuoj aŭ piednotoj, se la paĝo markas sian artikolon) kiel Markdown, ligiloj ankoraŭ funkcias | `~/Documents/Nyxt/<titolo de la paĝo>.md`, kaj la intertabelo |
| `page-to-epub` | La paĝo kiel elektronika libro, bildoj ene, por elektronika legilo | `~/Documents/Nyxt/<titolo de la paĝo>.epub` |
| `tabs-to-epub` | Ĉiu malfermita langeto kiel unu elektronika libro, ĉiu ĉapitro: listo de legendaĵoj | `~/Documents/Nyxt/Reading list <dato>.epub` |
| `clip-selection` | La elektita teksto kiel citaĵo, kun la dato, la titolo de la paĝo kaj ĝia ligilo | La fino de `~/Documents/Nyxt/clips.md`, kaj la intertabelo |
| `summarize-page` | Mallonga resumeto en buletpunktoj, kaj por kiu la paĝo estas | Paĝo de si mem en Nyxt, konservata ĝis Nyxt estas fermata |
| `show-url-qrcode` | La adreso de la paĝo kiel QR-kodo, por malfermi ĝin en telefono | Paĝo de si mem (propra komando de Nyxt: nenio por aldoni) |

Gravaj aferoj pri ili:

- **Ili bezonas pandoc** por Markdown kaj elektronikaj libroj (`vikix add cli-extras`), kaj **`llm`** por la resumeto (`vikix add llm`).
- **La resumeto iras al Claude.** `summarize-page` sendas la tekston de la paĝo al Anthropic per `llm`, kun la ŝlosilo de `vikix ai key set anthropic`, kaj tio daŭras kelkajn sekundojn. Por konservi paĝojn sur la aparato, agordu `*summary-model*` al `nil` en `config.lisp`, post la linio de la iloj de la paĝo: la defaŭlta modelo de `llm` tiam respondas (loka modelo, se vi tion elektis), senpage kaj private, sed tio povas daŭri minutojn por longa paĝo kaj ĝi diras malpli. Por malgranda loka modelo, agordu `*summary-max-chars*` al proksimume 6000 ankaŭ.
- **Bildoj malantaŭ eniro ne aperas.** `save-page-images` memprenas bildojn, sen la kukoj de la navigilo.
- **Paĝoj, kiuj ne markas artikolon** (`<article>` aŭ `<main>`), aperas tute, kun menuoj kaj ĉio.
- **Kien aferoj iras** povas esti ŝanĝita: `*page-tools-folder*` (Markdown, elektronikaj libroj, citaĵoj) kaj `*clips-file*`, agorditaj en `config.lisp` post la linio de la iloj de la paĝo.

Por la kuriozuloj, kiel ili legas la paĝon: `(document-model buffer)` estas la parsema kopio de ĝi en Nyxt (kreita per plump); `clss:select` trovas elementojn en ĝi per CSS-selektiloj; `plump:clone-node` kopias parton, tiel ke la paĝo mem ne estas ŝanĝita; `make-addresses-whole`, en la dosiero, faras ligilojn kaj bildojn absolutaj, tiel ke ili ankoraŭ funkcias ekster la paĝo; kaj `ps-eval` plenumas JavaScript-on skribitan en Lisp (Parenscript) en la paĝo, ĉi tie por legi la elekton.

La dosiero:

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

Kelkaj aferoj, kiujn mi lernis dum la skribo, por la okazo ke vi skribu vian propran:

- `remove-duplicates` konservas la *lastan* kopion de ĉiu, krom se oni donas `:from-end t`: sen ĝi la bildoj aperas en malorda vico.
- Malplena rezulto de `clss:select` estas malplena vektoro, ne `nil`, do `(or (clss:select "main" dom) ...)` neniam funkcios: testu ĝian longon.
- `show-url-qrcode` ne estas en `nyxt-user`: el Lisp, ĝi estas `nyxt/mode/document:show-url-qrcode`; de `Ctrl+Space`, sufiĉas ĝia nomo.
- `llm` prenas la ŝlosilon de Anthropic el la medio. Nyxt, lanĉita de la labortablo, havas ĝin.

## Ideoj por via propra

Kelkaj direktoj, de malgrandaj ĝis grandaj, neniu el ili ankoraŭ realigita:

- **Komandoj, kiuj ligas Nyxt al la labortablo:** aldonu la paĝon al la registro de projekto (`vikix project log NAME "read: <title> <url>"`), malfermu la retejon kiel ret-aplikon (`vikix webapp`), sendu la fenestron al alia labortablo (`vikix eval`).
- **Kiel paĝoj ŝarĝiĝas:** reskribu adresojn (al pli malpeza fronta parto de la retejo), bloku domajnojn, malaktivigu skriptojn en unu retejo.
- **Via propra `Ctrl+Space`-fontoj:** ĉiu dokumento sub `~/dev`, viaj projekto-dosieroj.
- **Via propraj paĝoj:** `define-internal-page`, kiel uzas `summarize-page`, kreas paĝon el Lisp kiam ĝi malfermiĝas: ekzemple, komenca paĝo kun viaj projektoj.

## Kiam Nyxt kondutas neadekvate

- **Ŝanĝo en la parto de Vikix ne efikis.** La temo sekvas `vikix theme` retime, sed nova `vikix.lisp` (post `vikix update`) kaj via propra `config.lisp` estas legata kiam Nyxt startas. Fermu Nyxt (`Ctrl+Space`, `quit`) kaj re-startigu ĝin; viaj etikedoj revenos.
- **Nenio respondas ĉe 4006.** Nyxt ne funkcias, aŭ ĝi startis sen `~/.slime-secret`, aŭ io alia uzis la porton. Ĝia registro, `~/.local/share/nyxt/nyxt.log`, diras kio ("Swank ne startis ...").
- **`C-x C-e` haltas en la senbugilo kun "invalid number of arguments: 3".** La Swank de Nyxt estas integrita en ĝi kaj estas pli malnova ol la instaloj de SLIME Emacs, kiuj sendas kelkajn vokon kun pli da argumentoj. La parto de Vikix igas tiujn vokon preni ilin (ekde Vikix 0.71.60), do tio signifas, ke ĝi ne estas ŝarĝita: kontrolu `vikix lisp-apps status`, kaj poste re-startigu Nyxt.
- **Nyxt sen fenestro.** Fermado de la lasta fenestro de Nyxt, aŭ `nyxt URL` startita dum alia Nyxt fermiĝis, povas lasi unu malantaŭ: procezo, sed neniu fenestro kaj neniu soketo, do nenio povas atingi ĝin. Ĝi ne enhavas ion utile. La paĝo de dokumentado (`vikix docs page`, aŭ ĝia eniraĵo `Super+m`) fermas tian Nyxt mem antaŭ ol ĝi startas novan, kaj notifiko diras *Stukinta Nyxt estis fermita*. Aliloke: `pkill -x nyxt`, kaj poste re-startigu Nyxt.
- **Notifiko diras *Nyxt ne respondas*.** La Nyxt, kiun vi havas malfermita, perdis sian soketon, do la paĝo de dokumentado ne povas esti sendita al ĝi kaj dua Nyxt malfermiĝas por la paĝo. Via malfermita restas sola, ĉar vi uzas ĝin. Fermu ĝin kiam vi pretas, kaj vi havos unu Nyxt.
- **Via konfiguracio haltas meze post la ŝanĝo.** `config.lisp`, kopia antaŭ Vikix 0.71.58, gardas la ŝarĝon de la parto de Vikix per `probe-file`, kiu en SBCL permesas unui ligon, kies dosiero malaperis, kaj la eraro tiam haltigas la reston de via dosiero. La komencigilo nun kaptas la eraron; ŝanĝu vian ŝarĝolinion por kongrui kun ĝi:

```lisp
(handler-case (load (merge-pathnames "vikix/nyxt/vikix.lisp" (uiop:xdg-data-home)))
  (file-error () nil))
```

- **Fora ekzameno ne produktas eliron.** `nyxt --remote --eval` kaj la eliro de Swank aperas en la protokoloj de Nyxt aŭ en la REPL, sed neniam en la konsolo, kiu sendis la komandon.

## Por la kuriozaj: kiel funkcias la parto de Vikix

Ĉio troviĝas en `config/nyxt/vikix.lisp` en la projekta dosierujo, unu dosiero de Lisp, kiu estas ŝarĝita en Nyxt:

- **La koloroj.** `vikix-palette` legas la dosieron de la paletro, kaj konservas nur liniojn de la formo `key=#rrggbb`; `vikix-make-theme` konstruas `theme:theme` el `bg`, `fg`, `sel`, `subtle`, `dim`, `color5` (aŭ `accent`), `color2` kaj `alert` (nenio, se mankas `bg` kaj `fg`). Metodo en `customize-instance` agordas ĝin dum la lanĉo de la navigilo, post kiam la tuta agordo estis ŝarĝita.
- **La rapida refreŝigo.** `vikix theme` ekzekutas `theme_nyxt` en `bin/vikix`: nur se aktivas via kopio de Nyxt, ĝi sendas `(vikix-theme-apply)` per `nyxt --remote --quit --eval`, kaj ĉesas post 3 sekundoj. Tio postulas `remote-execution-p`, kiun la sama dosiero aktivigas. Nyxt kalkulas la stilon de ĉiu objekto nur unufoje, kiam la objekto estas kreita, do `vikix-fresh-style` re-ekzekutas la komencan valoron de la stila loko por ĉiu mesaĝa linio kaj statbaraĵo de ĉiu fenestro.
- **Swank.** `vikix-start-swank` estas ekzekutata de la sama metodo `customize-instance`, do `(setf *vikix-swank-port* nil)` ie ajn en via agordo kontas. Ĝi limigas la kontrolon de pasvorto de Swank al 5 sekundoj kaj ĝia akcepta ciklo, tiel ke malakceptita kliento nur ĉesigos sin mem (`vikix-guard-swank`, la gardo de StumpWM el `swank-guard.lisp`, adaptita), kaj permesas, ke la novaj alvokoj de SLIME atingas la malnovan Swank (`vikix-swank-accept-newer-calls`).
- **La dokumentado.** `bin/vikix-docs-open` konvertas dosierojn en adresojn de `file://` kaj ekzekutas `nyxt` kun ili; aktiva kopio de Nyxt prenas ilin per sia soketo. Poste ĝi petas al StumpWM, per `vikix eval`, ke ĝi ekzekutu `vikix-raise-class` (en `commands.lisp`), kiu alportas la unuan fenestron de la klaso `Nyxt` al la avanparto.
