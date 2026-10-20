# Libroj el Markdown

Vi havas tekston en Markdown kaj vi volas krei el ĝi libron: EPUB-formato, kiu bone aspektas sur ekrano kun teknologio e-ink, kaj PDF-formato por presi aŭ montri sur ekrano. `vikix publish` kreas ambaŭ el unu dosierujo, kontrolas ilin antaŭ ol ĝi deklaras ilin pretaj, kaj metas la EPUB-on sur vian legilon, kiam vi ĝin konektas. Ĝi venas kun la funkcio `publish` (`vikix add publish`), kaj ĉiu libro, kiun vi kreas, estas produktata laŭ la sama maniero, do la demando "ĉu ĉi tiu libro estas finita?" havas nur unu respondon.

## Kio estas libro

Libro estas dosierujo. Ĝia teksto estas en Markdown, en unu el tri formoj:

- `chapters/*.md`, unu dosiero por ĉapitro, ordigita laŭ la nomo (`01-start.md`, `02-next.md`, kaj tiel plu);
- aŭ unu dosiero, `book.md`, kiam ne ekzistas `chapters/`;
- aŭ la dosieroj, kiujn vi listigas sub `chapters:` en `publish.yml`, en tiu ordo; listo tie venkas super ambaŭ.

Krome al la teksto, troviĝas `publish.yml`. Ĝi estas la metadatumo-dosiero de pandoc, do pandoc legas ĝin kiel ĝi estas: `title`, `author`, `lang`, kaj ĉio alia, kion pandoc konas. Tri ŝlosiloj estas apartenaj al Vikix: `name` (kiel nomiĝas la kreitaj dosieroj; la nomo de la dosierujo, se vi ne specifas ĝin), `chapters` (la ordo supre) kaj `mainfont` (la tiparo de la PDF-formato, vidu sube). `words.txt` apud ĝi enhavas la proprajn vortojn de la libro por la kontrolo de ortografio, unu vorto por linio.

```yaml
title: "Living in Lisp"
author: "A. Writer"
lang: en-GB
name: a-small-book
```

Por komenci:

```sh
vikix publish new ~/src/a-small-book --title "Living in Lisp"
```

La dosierkolekto estas kreata, se ĝi ne ekzistas. `--title` estas la titolo de la libro; sen ĝi, la nomo de la dosierkolekto estas uzata (`a-small-book` donas `A small book`). `--lang LANG` agordas la lingvon (`en-GB` se vi ne agordas ĝin), kaj `author` estas plenigata de la valoro de `user.name` en Git, aŭ via enira nomo. `new` skribas la dosieron `publish.yml`, unuan ĉapitron (`chapters/01-start.md`), malplenan `words.txt`, metas `out/` en `.gitignore`, kaj aldonas la linion de la celoj por la kompilado al la `Makefile` de la dosierkolekto (al donita dosiero, se ĝi ekzistas, vidu *De Makefile*). Ĝi neniam reskribas libron, kiu jam ekzistas: dosierkolekto kun `publish.yml` restas kiel ĝi estas, kaj tio estas sciigite. En Git-depotujo ĝi enmetas nur tiujn dosierojn, kiujn ĝi skribis, kaj informas pri tio (`enmetite: ... via sekva enmeto uzos ĝin`); `--no-commit` lasas Git netuŝita.

## Krei libron

```sh
vikix publish a-small-book        # the EPUB and the PDF
vikix publish a-small-book epub   # the EPUB alone
vikix publish a-small-book pdf    # the PDF alone
```

La libron oni trovas per tri manieroj: per la nomo de ĝia dosierujo en `~/src` (ankaŭ unu nivelon pli sube, do libro ene de kolekto estas trovata), per la `name` en ĝia `publish.yml`, aŭ vi faras `vikix publish` ene de la dosierujo sen ajna nomo. Ankaŭ vojo al la dosierujo funkcias.

La dosieroj finiĝas en la `out/` de la libro: `out/NOME.epub` kaj `out/NOME.pdf`, kie `NOME` estas la `name` el `publish.yml`. Ambaŭ ricevas enhavotabelon el viaj titoloj (du nivelojn profunde en la EPUB). Ĉiu estas kontrolata dum la procezo (la sekvaj du sekcioj diras kiel), kaj dosiero, kiu malsukĉas en la kontrolo, neniam ricevas la nomon de la libro; la unua, kiu malsukĉas, finas la procezon, do post forigita EPUB, la PDF ne estos provata. Sukcesa kompilo diras:

```
out/a-small-book.epub  (96 KB, epubcheck: no errors)
out/a-small-book.pdf  (240 KB, Typst: no warnings)
```

Se la libro estas projekto, kiun `vikix project` konas (vidu [Projektoj](customize.md#projektoj)), la konstruo en `out/` skribas datitan eniron, `published`, en ĝian `log.md`, kun la dosieroj kaj iliaj grandecoj, aldonas ĝin, kaj diras tion post la du linioj supre:

```
:: noted in /home/you/src/a-small-book/log.md
:: committed: log.md (896f4e9); your next push takes it
```

Libro, kiu ne estas parto de projekto, ne estos inkluzivita. `--no-log` (aŭ `VIKIX_PUBLISH_LOG=0` en la medio) lasas la protokolon netuŝita; `--no-commit` (aŭ `VIKIX_PUBLISH_COMMIT=0`) lasas Git netuŝita. Dosiero, kiu enhavas viajn ŝanĝojn kaj atendas, neniam estos inkluzivita sub via nomo: ĝi estos lasita al vi, kaj tio estas deklarite; nek io estos inkluzivita dum daŭras kunigo aŭ refarado.

## La EPUB, por legiloj kun ekranoj bazitaj sur e-ink-teknologio

Pandoc generas la EPUB-dosieron. Poste Vikix ĝustigas ĝin por malgrandaj ekranoj: ĉiu tabelo fariĝas vico da kartoj, kaj ĉiu unucela kupro fariĝas flanka noto. Kial: la legilaj programoj por 7-colaj ekranoj bazitaj sur e-ink-teknologio malpliigas la tabelojn, kaj tabelo kun tri kolumnoj aperas kiel difuzaĵo. La solvo estas en la dosiero `lib/publish/fix-tables.py`, la sama dosiero, kiun la funkcio `doc-to-epub` uzas en claude.ai, do la poŝkomputilo kaj la nubo generas la saman libron.

La kodo estas lasita sen kolorigi kaj konservas siajn spacojn. La kolorigado de pandoc envolvas ĉiun vorton de la kodo en sia propra etikedon, kaj la legiloj kun ekranaj teknologioj bazitaj sur e-ink-teknologio forigas la spacojn inter la etikedoj, do listo perdas sian indenton kaj siajn kolumnojn. Konstruado, dum kiu tio okazus, estos malakceptita, kaj la paĝoj estos nomitaj.

Fine, la programo `epubcheck` de W3C legas la dosieron. Dosiero, kiun ĝi malakceptas, estos konservata kiel `out/NAME.epub.rejected`, kaj vi vidos la raporton de `epubcheck`; ĝi neniam estos konservata kiel la libro. `epubcheck` estas Java-programo, ne apartenanta al Void, do Vikix alportas ĝin kiel fiksitan version kaj kontrolas ĝin kontraŭ sia kontrolsumo (`vikix publish setup` faras tion, kaj `vikix add publish` lanĉas ĝin).

## La PDF

La PDF pasas tra la Typst-generilo de pandoc. La tiparo estas IBM Plex Serif, kun araba skribo en Amiri: araba libro (`lang: ar`) uzas Amiri tra la tuta teksto, kaj la araba teksto en ajna alia libro ankaŭ uzas Amiri. Sekcio en la araba estas markita per la propra markado de pandoc, la sama, kiun la kontrolilo de ortografio legas (vidu sube):

```markdown
::: {dir=rtl lang=ar}
...
:::
```

En la EPUB-formato, la markilo konservas la direkton de la teksto de dekstro al maldekstro. En la PDF-formato, Typst starigas la arabajn literojn dekstre de si mem, sed la markilo ne atingas ilin (la Typst-eldonilo de Pandoc forigas ĝin), tiel la alineo konservas la alineon de la libro, kun sia punkto fine de la linio ĉe la maldekstro.

`mainfont` en `publish.yml` elektas alian tiparon por la tuta libro. Tiparo, pri kiu Typst avertas (ekzemple, tiparo, kiu ne estas instalita), estas konservata kiel `out/NAME.pdf.rejected`, kun la avertoj montritaj, sed neniam kiel la libro.

## Kontrolado de la libro: ortografio, ligiloj, kompilo

```sh
vikix publish a-small-book check
```

`check` unue kontrolas la ortografon, poste la ligilojn, poste kunigas ambaŭ formatojn en provizora dosierujo kaj nenion konservas: ĝi diras, ĉu la libro povus esti kreita, kaj nenio en `out/` ŝanĝiĝas. Ĝi estas la demando, kiun vi devas demandi antaŭ ol vi deklaras la manuskripton finita. La teksto unue estas kontrolata intence: titolo, kiu ne ekzistas, haltigus Typst kun propra mesaĝo, dum la ligila kontrolo nomas la ĉapitron. Vorto aŭ ligilo, kiu ne estas ĝusta, haltigas la procezon tie, antaŭ la kreado, kaj diras, kion fari:

```
publish: check: the spelling above wants a look (fix it, or vikix publish spell --keep for the words that are right)
```

Kiam ĉio estas bone, la lasta linio estas:

```
check: a-small-book builds, passes epubcheck and Typst, its spelling and its links (3 files of text)
```

**Ortografio.** La lingvo (`lang`) de la libro estas kontrolata kontraŭ la vortaro de LibreOffice: ĉu ĝi estas angla (Brita, `en_GB`), Esperanto (`eo`) aŭ araba (`ar`). Libro en ajna alia lingvo ne estas ortografie kontrolata: tio estas indikata (`ortografio: ne, ne kontrolata per vortaro`), kaj la procezo daŭras. Fragmento en alia lingvo estas kontrolata en sia propra lingvo, kiam vi markas ĝin, ekzemple `::: {lang=eo}` ĉirkaŭ bloko aŭ `[libro]{lang=eo}` sur vorto. Kodo, kruda HTML kaj matematikaj esprimoj ne estas teksto, do ili estas forlasataj. Vortoj kun cifero (`FTS5`, `0x1000`) kaj vortoj kun unu letrao ankaŭ ne estas kontrolataj. La propraj vortoj de la libro, ĝiaj nomoj kaj terminoj, estas enmetataj en la dosiero `words.txt`, unu vorto por linio.

```sh
vikix publish a-small-book spell          # the unknown words, each with its chapter
vikix publish a-small-book spell --keep   # and all of them into words.txt
```

`spell` listigas la nekonatajn vortojn laŭalfabete, kun la unua ĉapitro, en kiu ili aperas (la nomo de la dosiero, sen la dosierujo aŭ `.md`), kaj la nombro de pliaj aperoj:

```
spelling, en_GB: 2 words not in the dictionary or words.txt
  defun                    01-start and 3 more
  teh                      02-next
```

Ĉi tie `defun` estas vorto el la libro, kaj `teh` estas tajperaro. `spell --keep` aldonas ĉiun nekonatan vorton al `words.txt`, por ke vi povu legi ilin: forigu tiujn, kiuj vere estas tajperoj, kaj la ceteraj restu kiel vortoj de la libro. En git-depotio, ĝi tiam registras `words.txt`, nur tiun dosieron; `--no-commit` lasas git-on netuŝita. Kiam nenio estas nekonata, ĝi diras tion: `spelling: ĉiu vorto estas konata (en_GB, kaj words.txt)`.

**Ligoj.** `vikix publish a-small-book links` faras nur ĉi tiun parton. Ligo al `#a-heading` devas trovi tiun titolon en la libro. Dosiero aŭ bildo apud la teksto devas esti tie. Adreso en la reto devas respondi: tiu, kiu respondis, estas notita en `~/.cache/vikix/publish-links.json` kaj ne estas demandata denove dum unu semajno, do kontrolado ĉiutage ne alvenas al ĉiu retejo; tiu, kiu ne respondis, estas demandata ĉe ĉiu kontrolado. Paĝo, kiu respondis per 403 al skripto, ankoraŭ estas tie; tiu, kiu respondis per 404 aŭ ne respondis, ne estas. Ligo `mailto:` aŭ `tel:` ne bezonas esti serĉata, kaj estas lasata netuŝita. Sen reto, la ligoj de la reto estas lasataj por la venonta fojo, kaj la kontrolado diras tion prefere ol malsukĉi:

```
links: 14 in the text, all found (2 on the web, 9 to headings, 3 to files)
links: no network, so 3 on the web are left for next time
```

Manko de ligilo estas indikata kun la koncerna ĉapitro kaj la kialo, kaj la testo malsukĉas.

## Al la leganto

```sh
vikix publish a-small-book --send
```

`--send` kreas la EPUB-dosieron kaj kopias ĝin al la konektita legilo. Ĝi rekonas Kindle-n, kiu estas konektita kiel disko (la dosiero estos kopiata en la dosierujon `documents/`), Kobo-n (en la ĉefa dosierujo de la disko), ajnan diskon kun dosierujo `Books`, Android-legilon, kiel BOOX en reĝimo de dosiertransigo (per MTP, en ĝian internan memoron en la dosierujo `Books`), kaj legilon kun aktivigita USB-elsenviza reĝimo (adb, en `/sdcard/Books`). Ĝi provos ĉi tiujn opciojn en la supra ordo kaj informos, kie la libro estis kopiata:

```
:: sent: adb:/sdcard/Books/a-small-book.epub
```

Se ne troviĝas legilo, ĝi ĉesas kaj informas pri tio: enŝovu unu, aŭ ĉe Android-legilo, elektu datenaj transigo. `--to FOLDER` donas al vi la eblecon mem elekti la lokon, ajnan dosierujon, kaj nenio estas serĉata.

## El Makefile

La `Makefile` de libro finiĝas per unu linio:

```makefile
-include $(HOME)/.local/share/vikix/publish/publish.mk
```

Tio donas `make epub`, `make pdf` kaj `make check`, la samajn tri komandojn, de la interna parto de la dosierujo. La streketo en `-include` estas tio, kio permesas, ke la aliaj celoj de la projekto funkciu sur maŝino, kie `publish` ne estas instalita: `make` preterlasas dosieron, kiun ĝi ne povas trovi, anstataŭ ĉesigi la procezon. `vikix publish new` skribas la linion por vi; en `Makefile`, kiun vi jam havas, metu ĝin kiel la lasta.

Por la interesitoj: la celoj nur vokas `lib/publish/build`, la skripto malantaŭ `vikix publish` ankaŭ. Unu afero estas malsama. `make epub` ne skribas la eniron en la protokolo de la projekto: nur `vikix publish` konas la projekton.

Dokumento de Word povas esti la teksto de la libro. Nomu ĝin sub `chapters:` en `publish.yml`, kaj pandoc legas ĝin rekte, inkluzive de la tabeloj:

```yaml
title: "Living in Lisp"
lang: en-GB
chapters: [../a-small-book.docx]
```

## La kapablo "doc-to-epub"

La kapablo `doc-to-epub` ĉe claude.ai estas kreita el la samaj dosieroj kiel la versio por portebla komputilo: `lib/publish/skill/SKILL.md`, `fix-tables.py` kaj `epub.css`. `vikix publish skill` kunigas ilin en `~/Downloads/doc-to-epub.zip` (`vikix publish skill ZIP` donas alian lokon), preta por elŝuti en claude.ai sub Agordoj, Kapabloj, Kapabloj, anstataŭ la ekzistanta. Tiel, korekto al la procezo por ekranoj kun elektronika papero ĉi tie atingas la nubon dum la venonta elŝuto, kaj nenio estas duobla.

## Kiam libro ne kompilas

Komencu kun tio, kio estas ĉi tie:

```sh
vikix publish status
```

Ĝi listigas la ilojn (Pandoc, Typst, Java), epubcheck, la tri vortarojn, la Python-bibliotekojn, la du tiparojn (IBM Plex Serif, Amiri) kaj la komunaĵajn celojn de la kompilado, kaj indikas `manas` ĉe ĉiu, kiu mankas, kun la komando, kiu alportas ĝin. `vikix publish setup` instalas la mankantajn pakojn, alportas epubcheck kaj la vortarojn, kaj metias la komunaĵajn celojn de la kompilado; ĝi estas kion `vikix add publish` faras por vi, kaj estas sekura refari ĝin.

- **Neniu Java** signifas, ke epubcheck ne povas funkcii, do neniu EPUB estos generita. La funkcio `publish` bezonas la funkcion `java`, do `vikix add publish` alportas ĝin; se ĝi forestas, `vikix add java`.
- **Vortaro mankas** ne haltigas la kompiladon: oni diras, ke la ortografio en tiu lingvo ne estos kontrolata, kaj `vikix publish setup` alportas la vortarojn.
- **Tiparo, kiu ne ekzistas** estas averto de Typst, do la PDF aperos kiel `NAME.pdf.rejected`. `status` diras, kiu el la du tiparoj mankas; vi devas instali vian propran `mainfont` sur la maŝino.
- **EPUB malakceptita** aperas kun la raporto de epubcheck en la terminalo, kaj la dosiero kiel `NAME.epub.rejected` por malfermi kaj kontroli.

`vikix add publish` instalas la funkcion. `vikix remove publish` forigas epubcheck, la vortarojn kaj la komunaĵajn celojn de la kompilado; viaj libroj kaj iliaj dosieroj en `out/` restas tie, kie ili estas.
