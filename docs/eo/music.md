# Unua muzika ŝablono

Muziko estas malgranda Lisp-skizlibro. SuperCollider kreas la sonon,
per la subteno de JACK en PipeWire; la horloĝo de la ŝablono funkcias en sia propra SBCL-procezo, aparte de StumpWM.

## Unua sono

Ekzekutu `vikix add music`. Ĉi tio instaldas SuperCollider (la paketo de Void inkluzivas Qt), la bibliotekon JACK de PipeWire kaj rtkit, aktivigas rtkit, kaj uzas la ekzistantan instalon de Quicklisp por kompili la originalan sintetan paletron per cl-collider.
Neniuj specimenoj estas elŝutataj. Se Muziko jam estis instalita antaŭ la paletro,
ekzekutu `vikix music setup` unufoje por kompili la novan versitan pakaĵon. Via unua ŝablono estas unufoje kopiata al
`~/music/first-song/patterns.lisp`; la agordo neniam anstataŭigas ĝin.

```sh
vikix music doctor
vikix music tone
vikix music play
```

Komencu kun malalta laŭteco de la laŭtparlilo. La sono daŭras ĉirkaŭ trionon de sekundo, je 880 Hz kiel defaŭlto. La komenca melodio uzas pli altajn tonojn, kiuj estas pli facile aŭdeblaj per laŭtparoliloj de portebla komputilo; malaltaj sinuso-tonoj povas esti malfortaj, eĉ se la aŭdkapablo de la navigilo ŝajnas normala. Ekzistantaj melodioj neniam estos reskribitaj per ĝisdatigo. `Play` ripetas la unuan melodion ĝis `Ctrl+C`. Ĉiu ekzemplo havas sian propran sonmotoron; ĝi ne konektas al motoro, kiun vi jam komencis. `doctor` kontrolas instalitajn komandojn kaj la preparitan sintezilon, ne aŭdeblan eliron, latenton aŭ prioritaton en reala tempo. Se la motoro ne povas komenci, kontrolu, ĉu PipeWire funkcias dum via ensaluto, kaj kontrolu la eraron en la terminalo.

## Redaktu dum ĝi ludas

Dosiero povas enhavi tempon kaj ĝis 32 nomitajn melodiojn. Unu elektita melodio ludas je unu momento, ĉiu listo plenigas kvar-taktan frazon, kun rektaj paŝoj kiel defaŭlto:

```lisp
(tempo 120)
(defpattern melody '(a5 - c6 - e6 - c6 -))
(defpattern pulse '(x - x -))
```

`-` estas paŭzo; `x` estas sono de 220 Hz, generata per la sama simpla sinusa ondo. La notoj gamas de C0 ĝis B8; uzu `cs4` por C♯ kaj `eb4` por Eb. La tempovito estas de 60 ĝis 200 batoj por minuto, kun 1 ĝis 128 paŝoj en unu ciklo.

```sh
vikix music check ~/music/first-song/patterns.lisp
vikix music play ~/music/first-song/patterns.lisp --pattern melody
vikix music play ~/music/first-song/patterns.lisp --bars 4
```

La dosiero estas legata kiel datumoj, kaj neniam estas interpretata. Konservu validan redakton, kaj ĝi efektivigos sin ĉe la sekva takto, kiu ankoraŭ ne estis sendita al la motoro (ĉirkaŭ 100 milisekundoj antaŭe). Ne valida redakto, nekompleta konservado aŭ mankanta dosiero konservas la lastan bonan ŝablonon kaj elmontras la kialon. Dum la komenco, ne valida dosiero estas rifuzata. Prokrastigita horloĝo preterlasas mankantajn momentojn anstataŭ aktivigi vagon da notoj.

Antaŭ redaktu, faru `vikix snapshot "antaŭ muzika redakto"`. Nur la dosieroj `~/music/SONG/patterns.lisp` aldonas sin al la ekzistanta historio de momentaj bildoj; registraĵoj, prilaborita aŭdio kaj nestigitaj dosierujoj ne aldonas sin. `vikix changes` montras la redakton; `vikix undo` restarigas la antaŭan momentan bildon kaj la ludilo legas la restarigitan ŝablonon ĉe la sekva takto. Restarigo kovras ankaŭ la aliajn dosierojn en tiu momento: reviziu ĝian liston antaŭ akcepti ĝin. Ŝablonoj ekster ĉi tiu dosierujo povas esti ludataj, sed ili ne ricevas momentan bildon aŭtomate.

## Sonoj, ŝablon-akiro kaj ritmo

La opciaj kampoj apartenas al ĉiu ŝablono, post ĝia listo de notoj:

```lisp
(defpattern beat '(x - x x) :sound 'kick :gain 0.7 :swing 0.3)
(defpattern phrase '(c3 - g3 c4) :sound 'bell :gain 0.5)
```

| Sono | Karaktero | Kion faras X |
|---|---|---|
| `sine` (defaŭlta) | La originala pura sinuso | Ludas 220 Hz |
| `kick` | Malalta sinuso kun malaltiĝanta tonalto | Aktivigas tamburon |
| `snare` | Bruo kaj malalta tono | Aktivigas tamburon |
| `closed-hat` | Mallongaj metalaj tonoj kaj bruo | Aktivigas fermitan hi-haton |
| `bass` | Fundamenta tono kaj dua harmonio | Ludas 220 Hz |
| `bell` | Tri ne-harmoniaj sinuso-tonoj | Ludas 220 Hz |

Tamburoj akceptas nur `x` kaj `-`; anstataŭigu tonojn antaŭ ol elekti tamburon.
Sinuso, baso kaj sonorilo ankaŭ akceptas tonalton. Ĉiuj ses estas originalaj
sintezoj en `lib/music/synth.lisp`, distribuitaj sub la MIT-licenco de Vikix
(`LICENSE`). Ne ekzistas uzitaj registraĵoj aŭ eksteraj sonaj bankoj.

**Gajno de ŝablono** estas multiplikilo de 0 ĝis 1, defaŭlte 1. **Gajno de sesio**
restas de 0 ĝis 0,1, defaŭlte 0,08; la du multiplikiĝas, do ŝablona gajno 0,5 ĉe
sesia gajno 0,08 produktas amplitudon 0,04. Sesia gajno ne estas konservata en
la partituro. Ĉi tiuj estas limoj de amplitudo por ĉiu voĉo, ne limigilo de la laŭteco de la laŭtparolilo aŭ kumulita eliro. Diferencaj sonoroj povas soni pli laŭte je la sama
amplitudo. Ekzistantaj sinusa partituroj konservas sian originalan sonon kaj nivelon.

**Svingo** gamas de 0 ĝis 0,5, defaŭlte 0. Ĝi prokrastas paŝojn 2, 4, 6 kaj tiel plu
je tiu frakcio de unu rekta paŝo, sen ŝanĝi la longon de la takto.
Je 0,5, ĉiu paro havas 3:1 tempan proporcion. Nula svingo postulas paran
nombron de paŝoj; paŭzoj kalkas kiel paŝoj. Redaktadoj de sono, gajno de ŝablono kaj svingo efikas kune en la sekva ne-planita takto, inkluzive de la pozicio de la ludkapo.

La navigilo havas regilojn por Sono, Gajno de ŝablono kaj Svingo por la elektita
ŝablono, kaj inkluzivas ne-defaŭltajn valorojn en sia Lisp-subteksto. Novaj kampoj
uzas la samajn kontrolkontrolpunktojn/malfari kaj kontrolkontrolpunktojn de malnovaj versioj kiel notoj. Nekonataj sonoj, duoblaj aŭ nekonataj opcioj, nefinaj kaj for de la intervalo nombroj,
tonaj tamburaj notoj kaj paraj-longaj svingaj ŝablonoj estas malakceptataj kiel datumoj.
La eksperimenta Cuis-vido konservas siajn ekzistantajn regilojn; uzu la navigilon
aŭ la dosieron de la partituro por ĉi tiuj novaj kampoj.

## Akordprogresioj

Progresio estas alia nomita ŝablono: elektu ĝin aŭ asignu ĝin al padeto.
La navigilo montras akordblokojn anstataŭ notĉeloj. Aldonu ĝian formon al via
dosiero de la partituro por krei ĝin:

```lisp
(defprogression verse '(I (vi 2) - IV V) :key 'f :sound 'bell :gain 0.6)
```

Ĉiu simpla grado daŭras unu takton de kvar batadoj. `(vi 2)` daŭras du taktojn; `-` estas
taktpaŭzo, kaj `(- 2)` estas du taktpauzo. Ekzistas 1–32 blokoj, ĉiu
1–16 plenaj taktoj, kaj maksimumo 128 taktoj entute. La sekvenco ripetiĝas; elektante
ĝian padon, ĝi komenciĝas ĉe la unua takto. `play --bars N` kalkas taktojn, inkluzive de paŭzoj,
ne la tutajn sekvencojn. Modeloj kaj progresioj dividas la limon de 32 nomoj.

La majuskla/minuskla distingo gravas por la gradoj: `I II III IV V VI VII` estas majoraj triadoj;
`i ii iii iv v vi vii` estas minoraj triadoj. Iliaj baznotoj uzas la duontonajn diferencojn 0, 2, 4, 5, 7, 9, 11 de la gamo, komencante de la toniko. Minusklaj leteroj ŝanĝas la
trion, ne la gamon: `vi` en C estas A-minora; `i` en C estas C-minora. Ne ekzistas
deduktita minora modo, malkreskita akordo, septima aŭ inversio. Miksitaj majuskla/minusklaj leteroj, kiel `Iv`, estas malakceptitaj. Aliaj nomoj kaj opcioj de la partituro ne estas sensivaj al la majuskla/minuskla distingo.

`:key 'f` starigas la tonikon por la tuta progresio; la defaŭlto estas C.
Uzu leteron C–B kun opcia `s` por kresko aŭ `b` por bemolo (`fs`, `bb`).
La baznoto komenciĝas ĉe tiu skribita toniko en la okavo 3 (do C-bemolo estas B2), kaj
la gradoj plii de tie. Majoraj triadoj aldonas 4 kaj 7 duontonojn; minoraj triadoj
aldonas 3 kaj 7. En F, `I` ludas F3–A3–C4, kaj `vi` ludas D4–F4–A4.
Ĉi tio estas proksimaj, bazpoziciaj aranĝoj, sen ia voĉdirekta adapto.

Ĉiu okupata takto reartikulas ĉiujn tri notojn kune, uzante la ekzistantan
mallongan notenvelopon (0,3 sekundoj); plilongigi blokon ripetas tiun akordon
en ĉiu takto, anstataŭ teni ĝin. La tri voĉoj dividas la gajnon de la modelo
egale, kaj poste multiplikas per la gajno de la sesio. Sinuso, baso kaj sonorilo estas disponeblaj;
tamburoj kaj svingo estas malakceptitaj por progresioj. Ekzistantaj modeloj de notoj konservas
siajn tempigojn kaj nivelojn.

Elektu la gradon kaj **Taktoj** de ĉiu bloko, movu ĝin al nova pozicio aŭ uzu
ĝiajn maldekstraj/dekstraj sagoj, kaj elektu **Tonikon** por transponi la progresion.
Sono kaj gajno de la modelo funkcias kiel antaŭe. Ĉiu redakto validigas la tutan partituron,
prenas fotoon kaj ŝanĝas nur la necesajn erojn. Reordigi movas
muzikan valoron inter la ekzistantaj pozicioj; komentoj kaj spacoj restas
en siaj originalaj pozicioj. Nerilataj formoj estas konservataj. Redakto, kiu estas malfreska, estas malakceptata. La Lisp-subteksto reprezentas la samajn akceptitajn blokojn, daŭrojn,
tonikon kaj sonon; ĝi normaligas unu-taktan blokon al simpla grado.

Redaktoj faritaj en vivo validiĝas ĉe la sekva ne-planita takto, konservante la planitan
taktindicon modulo la nova longo de la progresio. Ŝanĝi la tonikon transponas tiun
sekvan takton. Nevalidaj redaktoj konservas la lastan bonan ludon, blokojn kaj subtekston.
La konturo de la emfazo sekvas la takton raportitan de la aparta Lisp-horloĝo,
inkluzive de taktpauzo; neniu muziko estas planita en la navigilo. La eksperimenta
Cuis-vido ne redaktas akordajn blokojn: uzu la navigilon aŭ la partituran dosieron.

## Lisp el terminalo aŭ Emacs

`vikix music repl` malfermas apartan lokan Lisp-REPL. En Emacs, uzu
`C-u M-x run-lisp` kaj enigu `vikix music repl` kiel la komandon.

```lisp
(tone 880)
(play "/home/YOU/music/first-song/patterns.lisp")
(stop)
(quit)
```

Tono estas finita; la komando "Stop" finigas la procezon de la muzika motoro kaj forigas la vicojn de sonoj.
La komando "Quit" aŭ Ctrl+C ankaŭ fermas la muzikan motoron. Ĉi tiu REPL (Interaga interpreto) taksas via
Lisp-kodon kaj havas la permesojn de via uzanto; muzika motoro ne. Ne ekzistas
REPL-a reto. La muzika motoro aŭskultas nur la lokan TCP-adreson kun nova sesia
pasvorto, sen UDP-a aŭskultilo, sen eniroj de mikrofono kaj sen anonco de servoj.

## Malfermu la muzikan interfacon

La navigilo estas la defolta muzika interfaco. En unu terminalo, lanĉu la
sesion; en alia, malfermu la vidadon de la navigilo:

```sh
vikix music serve
vikix music web
```

`serve` ankaŭ akceptas la `patterns.lisp` de kanto. Por redakti ĝin, ĝi devas esti en
`~/music/SONG/patterns.lisp`, kie estas stokitaj la momentaj kopioj. La navigilo malfermiĝas
kun via defolta navigilo. La eksperimenta Cuis-alternativo malfermiĝas per
`vikix music cuis` kaj bezonas `vikix add cuis`; ĝi funkcias
en provizora baza bildo kaj ne ŝanĝas vian konservitan Cuis-bildon.
Fermu ĝian muzikfenestron por fini tiun provizoran bildon.

Klaku nomitan padon por elekti kaj ludigi ĝian ŝablon, aŭ elektu ŝablon kaj
premu Ludi. Unu ŝablono ludas je unu fojo; ŝanĝante padon, la malnova ĉesas
kaj la nova komenciĝas de sia komenco. Klakante la ludantan padon, ĝi daŭre ludas.
Partituroj sen banko konservas la padojn en fila ordo. Kontroloj de la labortablo
uzas sian propran muzikprefikson (sube). Ĉiu paŝo pentras la elektitan noton; dua
klako sur tiu noto kreas paŭzon. La navigilo ofertas la kompletan notgamon; la
Cuis-komparaĵo cikligas malgrandan paletron de altaj notoj kaj montras
dek ses paŝojn por paĝo. Kontroloj de tempo kaj gajno funkcias en ambaŭ.
Tempo estas konservata en la kanto; la sesia gajno estas limigita al 0.1. La
navigilo ankaŭ konservas la sonon, la relativan gajnon kaj la ritmon por ĉiu
ŝablono. Redaktadoj de dosiero
aperas en la sekva mezuro, kaj ambaŭ vidpunktoj refreŝiĝas el la sama dosiero.

La strio **Ĉi tiu ŝablono en Lisp** de la navigilo montras la elektitan ŝablon
kaj la tempon kiel Lisp-formatoj. Ĝi sekvas notredaktadojn, tempŝanĝojn, ŝablonelekton
kaj eksterajn dosierredaktadojn. Ĉi tio estas legebla reprezentacio de la
tabelo; la dosiero konservas siajn proprajn komentojn kaj formatigon.
Nevalida redaktado lasas la lastan bonan tabelon kaj subtitolon videblajn kune.

Akcento sekvas la ludantan paŝon, inkluzive de paŭzoj, kiam la ludanta
ŝablono estas elektita. Ĝia tempo venas de la Lisp-horloĝo, do temporedaktado
efektiviĝas sur la ludkapo kiam la sekva mezuro estas planita. Ĉi tio estas
bilda gvidilo, ne mezuro de la latenteco de la laŭtparlilo. Prokrastigita
konekto povas breve kaŝi la konturon; haltigante aŭ malkonektante, ĝi malaperas.

Redaktado unue faras momentan kopion kaj anstataŭigas nur la ŝanĝitan noton, tempon,
sonon, gajnon, ritmon aŭ
bankajn tokenojn, konservante ekzistantajn komentojn kaj formatigon. Kreante bankon,
aldoniĝas nova formato. Nevalida revizio estas rifuzata: reviziu
la refreŝigitan tabelon kaj provu denove. Nevalidaj dosierredaktadoj lasas la lastan
bonan ŝablon videbla kaj aŭdebla, kun eraro. La prototipa redaktilo akceptas
entierajn tempojn kaj simplajn ŝablonajn nomojn faritajn el literoj, ciferoj kaj
strekoj. Pli elaboraj Lisp-formatoj ankoraŭ povas esti ludataj per `play`.

Fermante vidpunkton, la ludilo daŭre funkcias. Haltigante en ajn vidpunkto, la sono
ĉesas;
Ctrl+C en la sesia terminalo haltigas ĝian ludilon, fermas la lokan servilon
kaj forigas ĝian konektan dosieron. Malfermu alian vidpunkton por rekonekti. La
servilo ligas nur al 127.0.0.1, kontrolas la devenojn de la navigilo kaj bezonas
freŝan sesian tokenon el privata konekta dosiero. Ĝi akceptas muzikajn operaciojn,
ne Lisp- aŭ Smalltalk-evaluadon. La aŭdio de la navigilo neniam estas uzata.

## Konservu asignojn de la padetoj

Malfermu **Redaktu asignojn de la padetoj**, elektu numeron de padeto kaj nomitan
ŝablon, tiam klaku **Konservu asignon**. Elektu **Neasignita** por forigi asignon
de padeto. La unua asigno ankaŭ konservas la aliajn padetojn laŭ fila ordo, do ili
restas tie, kie ili estis. Ĉiuj nomitaj ŝablonoj restas disponeblaj en la ŝablon-
elektilo, eĉ se neniu padeto referencas ilin. La partituro konservas la asignojn
kiel datumoj:

```lisp
(bank 1 melody 2 pulse 8 melody)
```

Eblas unu banko, kun lokoj de 1 ĝis 32. Interspaco kaj la sama ŝablono sur
kelkaj areoj estas permesataj. `(bank)` lasas ĉiun areon neasignita; neniu banka formo
uzas la originalajn areojn laŭ la ordo en la dosiero. Nomoj ne estas sentemaj al majuskloj kaj minuskloj, kaj banko povas
aperi antaŭ siaj ŝablonoj. Duplikaj numeraj valoroj por areoj, multoblaj bankoj, nekonataj
nomoj de ŝablonoj, lokoj ekster la intervalo kaj nekompletaj paroj estas eraroj, kaj ili neniam
estas silente forigitaj. Invalidaj dosieroj estas rifuzataj dum la lanĉo; invalidaj ŝanĝoj dum la
uza tempo konservas la lastajn bonajn areojn kaj la ludon, kaj ekrano montras eraron.

Asignoj survivas post fermo de la navigilo kaj reloĝigo de la sesio. Ili uzas
la samajn kontrolajn mekanismojn por kopioj kaj versioj kiel la ŝanĝoj en la matricoj: `vikix undo`
restaŭras ilin ankaŭ, kaj malnovaj asignaj ŝanĝoj aŭ aktivigoj de areoj estas rifuzataj.
Ŝanĝi aŭ forigi asignon ne ŝanĝas la ludatan ŝablonon. Klaku areon
por ŝanĝi; **Playing** (Ludante) nomas la aktualan ŝablonon, kaj ĉiuj areoj asignitaj al ĝi
briletas. Nur unu ŝablono ludas samtempe. La eksperimenta vidpunkto Cuis ankoraŭ
elektas ŝablonojn rekte; redaktu asignojn de bankoj en la navigilo aŭ en la partituro.

## Kontrolliloj por labortablo

Lanĉu `vikix music serve` kiel antaŭe. **Super+Alt+F8** malfermas la muzikajn
kontrollilojn: **p** ludas la elektitan ŝablonon, **s** haltigas, **1–9** ludas tiun
bankan areon, **0** elektas el ĉiuj asignitaj lokoj (1–32), kaj **o** malfermas
la navigilon. **r** komencas la registradon kaj **Shift+r** haltigas la registradon. Ĉiu ago fermas la prefikson; Escape anstataŭigas. La samaj elektoj
troviĝas en **Super+m → Music**. Super+ciferoj ankoraŭ elektas laborajn spacojn kaj
ekzistantaj klavoj de la programo restas senŝanĝaj. Malplena areo raportas eraron
sen ŝanĝi la ludon. Ankoraŭ estas nur unu banko; tio elektas
ĝiajn asignitajn areojn, ne duan bankon aŭ novan kanton.

Ĉi tiuj komandoj kontrolas nur la aktivan komunan sesion. Ili neniam lanĉas
motorn aŭ servon memstare. Manka, haltigita aŭ okupita sesio
respondas tuj, kaj la kontroloj por la labortablo montras sciigon; kontrolu ĝian
terminalon. La memstara `vikix music play` ankoraŭ havas sian propran ludilon kaj
ne estas kontrolata de la Halto de la komuna sesio.

```sh
vikix music control play
vikix music control stop
vikix music control bank 12
vikix music control bank
vikix music control state
```

La indika linio senbrua montras `music 2/4 · 120` dum la ludado: ritmo, kiu estas uzata ĉirkaŭ unufoje por sekundo, kaj la tempovaldoro de la planita indika linio. Ĝi povas saltu la ritmonombrojn kaj ne estas migra metronomo aŭ mezurado de aŭda latenco. Ĝi malaperas post la interrompo aŭ perdo de la konekto ĉe la sekva uzado. Komenca ludilo montras strekon ĝis ĝia horloĝo provizas indikan linion. Nek StumpWM nek la navigilo planas sonojn.

La navigilo sekvas la paletron de Vikix, inkluzive de malhelaj temoj, ĉe sia sekva stato-refreŝigo. Ĉeloj, padetoj kaj la ludkapo retenas sian ekzistantan konduton; la ludkapo kaj la fokusa konturo uzas la teman akcenton. Manĝanta paletro uzas la malhelan temon de Vikix. Ŝanĝi temojn ne bezonas refari la muzikon aŭ refreŝigi la paĝon.

## Registru kaj konservu muzikpecon

Registrado estas ĉiam esplicita. En la navigilo elektu **Registri fonton**, poste **Ekregistru**; **Halte registri** finas la muzikpecon kaj forigas ĝian registrilon. La navigilo kaj la indika linio nomas la aktivan fonton en la avertkoloro. La prefikso **r** de la Muziko startas **nur la motoron**; **Shift+r** haltigas la registradon. La stato de registrado ankaŭ estas en `vikix music control state` aŭ **Super+m → Muziko → Stato de registrado** (`vikix music control record-state`). Nur malfermi la Muzikon, elekti fonton aŭ ludi ŝablonon neniam malfermas la mikrofnon.

```sh
vikix music control record
vikix music control record-stop
vikix music control record --source microphone
vikix music control record --source mixed
```

La defaŭlta ago kaptas nur la elsendojn de la motoro de la nuna sesio, ne la aliajn sonojn de la komputilo. Unue komencu la modelon. La mikrofono kaptas unu monaŭdan aŭ sterean sonfonton de PipeWire (`Audio/Source`); se estas pluraj sonfontoj, nomu unu el ili specife per `--device NODE` (la navigilo havas la saman kampon). Trovu la nomojn de la sonfontoj per `pw-dump`. "Mixed" kunigas la motoron kaj la mikrofnon al la registrigilo; monaŭdaj enirsignoj aliras ambaŭ kanalojn, kaj miksitaj enirsignoj estas sumitaj, do lasu sufiĉan spacon por eviti distoron. La sonoj de la mikrofono neniam estas aŭditaj per la laŭtparoliloj de Music. Se mankas aŭ estas neklara sonfonto, ĝi estos malakceptita. Aparatoj kun pli ol du konektiloj estos malakceptitaj, anstataŭ oni provos diveni la kanalparon.

"Playback Stop" ankoraŭ haltigas la ludigon; "Haltigi registradon" estas aparta ago. Ŝanĝi la "pads" anstataŭigas la motoron, do la registrado de motoro/miksita sono finiĝos kiel parta, kiam la sonfonto malaperas. Haltigu la registradon, antaŭ ol ŝanĝi la "pads". Kiam oni fermas la navigilon, la ekzistanta registrado daŭre funkcias: rekonektu por haltigi ĝin, aŭ premu Ctrl+C en la terminalo de la sesio. Kiam la sesio finiĝas, la registrado kaj la antaŭmontro estas haltigitaj. Neniu registrado komenciĝas memstare, kaj neniu registrataĵo estas aŭtomate forigita.

Ĉiu registradaĵo estas rezervita ekskluzive sub `~/music/inbox/SONG/YYYY-MM-DD/take-NNNN/`, uzante la nomon de la aktiva kanto kaj la lokan daton je la komenco de la registrado. Sekvaj registradaĵoj plibonigas la numeron; ekzistantaj dosierujoj neniam estos reuzataj. `audio.pcm` estas sterea senkapo, 48 000 Hz, signita 16-bita, malgranda finordo PCM. `take.json` registras la sonfonton kaj la formaton antaŭ ol la sonoj komenciĝas; `stopped.json` registras normalan haltigon aŭ konatan partan eraron. Se mankas aŭ ne legeblas la metadatumoj pri la haltigo, tio signifas, ke la registrado estis interrompita kaj neniam finiĝis. La listo montras la sonfonton, la statuson, la daŭron kaj la ID. La kruda sonmaterialo evitas, ke la fina WAV-kapo estu perdita dum interrompo. Ĝi uzas proksimume 11 MB por minuto.

Malfermu "Capture inbox" kaj "Refresh captures", poste "Preview", "Loop", "Stop preview / loop", aŭ enigu la nomon de la kanto kaj elektu "File copy". La antaŭmontro uzas PipeWire, ne la sonojn de la navigilo, kaj ĝi postulas haltigitan registradon. Kiam oni komencas registradon, la antaŭmontro unue haltigas. Operacioj de la komanda linio uzas la saman aŭtentikitan vojon:

```sh
vikix music control inbox
vikix music control preview --take SONG/YYYY-MM-DD/take-0001
vikix music control loop --take SONG/YYYY-MM-DD/take-0001
vikix music control preview-stop
vikix music control file --take SONG/YYYY-MM-DD/take-0001 --song another-song
```

Arkivado kreas novan, ekskluzivan dosierujon sub
`~/music/another-song/captures/YYYY-MM-DD/` kaj konservas la originalan dosieron kiel
kopion por restorigi. Plia kopiado kreas novan numeron por la enmeto; ĝi neniam
anstataŭigas pli malnovan kopion. Kantotitoloj uzas literojn, ciferojn, substrekojn kaj
strekojn. Operacioj pri enmeto rifuzas simbolajn ligojn. Audio estas for de la
restoriga procezo; faru apartan kopion. Vikix ne forigas ajnan el la kopioj.

### Restarigu kaj kontrolu la enmeton

En kazo de perdo de la aparato, fiasko de la registrililo aŭ plena disko, la
registrililo ĉesas, kaj ĉiu datumo jam skribita restas. La navigilo/stato raportas la
fiaskon; fiasko de la disko ankaŭ povas malpermesi skribi la finan markilon. Post
liberigo de la spaco, uzu **Refreŝigu enmetojn** kaj antaŭrigardu la partan enmeton.
Fiasko de la arkivado povas lasi nekompletan celdosierujon; konservu ĝin kaj provu denove
kun nova numero por la enmeto, uzante la neŝanĝitan originalan dosieron. Sukcesa kopio
havas `filed.json` kun `complete: true`; manka markilo signifas, ke la kopiado ne finiĝis.
Ne traktu partan celdosierujon kiel kopion.

Se la programo Muziko ne povas funkcii, la konservita enmeto povas esti aŭskultita rekte:

```sh
pw-play --raw --rate 48000 --channels 2 --format s16 ~/music/inbox/SONG/DATE/TAKE/audio.pcm
```

Audio-redaktilo povas importi la saman krudan formaton; ĝi ignoras la lastan, nekompletan, kvar-oketajn sterean kadron. Gravaj elektraj interrompoj povas kaŭzi perdon de ne-ankaŭ konservitaj datumoj; la programo sinkronigas audio-erojn dum ili alvenas, sed ĝi ne povas reskapi la datumojn, kiujn la aparato neniam skribis. Konservu la originalan krudan dosieron dum vi reskiras aŭ konvertas ĝin.

Manuala kontrolo post instalado: ludu melodion, registru nur la sonon de la motoro dum kelkaj sekundoj, haltigu kaj antaŭrigardu ĝin. Kontrolu, ĉu aliaj sonoj de la komputilo ne estas aŭdeblaj. Eksplicite elektu la mikrofonon, registru mallongan parolan frazon, haltigu, kaj konfirmu, ke la mikrofono estas liberigita. Ripetu kun aŭskultiloj kaj kontrolu ambaŭn fontojn. Ripetu melodion, haltigu la ripeton, konservu ĝin dufoje kaj kontrolu ambaŭ nombritajn kopiojn kaj la originalon en la enirujo. Fine, interrompu la sesion dum registrado, restartigu kaj antaŭrigardu la konservitan partan melodion. Izolitaj aŭtomataj alirvojoj/fontaj agordoj ne anstataŭas ĉi tiun homan mikrofonon kaj realan kontrolon de la aŭskultado.

## Eksportu partituron kiel MIDI kaj WAV

La komando `send` unufoje legas la konservitan partituron kiel datumon kaj eksportas ĉiun nomitan melodion aparte. Ĝi funkcias dum la programo estas haltigita aŭ ludas, kaj neniam kontaktas, haltigas aŭ ŝanĝas la kunhavitan sesion. Ĝi ne eksportas ne-ankaŭ konservitajn modifojn, gajnon de la sesio, ludon de la pad aŭ registraĵojn de la enirujo.

```sh
vikix music send ~/music/first-song/patterns.lisp
vikix music send ~/music/first-song/patterns.lisp --pattern verse --repeat 4
vikix music send ~/music/first-song/patterns.lisp --format midi
```

Senaro, ĝi uzas `~/music/first-song/patterns.lisp`. `--pattern Nomo`
elektas unu nomon, sen atenti pri kapitalaj literoj; alie ĉiu nomo aperas unufoje en la dosiero
laŭ la ordo, inkluzive de nomoj sen prefiksoj. Paŭzoj kaj duplikataj asignoj ne ŝanĝas la aperordan
aŭ ripetas ŝablonon. `--repeat N` ripetas ĉiu kompletan ŝablonon 1–16 fojojn, defaŭlte 1: ŝablona
sekvenco estas unu kvar-takta frazo; progresio estas ĝia kompleta sekvenco, inkluzive de silentaj frazoj
kaj plilongigitaj blokaj daŭroj. La totala nominala daŭro de aro estas limigita al unu horo; elektu
malpli da ŝablonoj aŭ ripetoj por pli longa komponaĵo.

Ĉiu sukcesa komando elprintas novan dosierujon sub la dosierujo de la komponaĵo,
nomitan `render/`, kun la nomo `send-DATUMO-TEMPO-UNIK`. Ĝi enhavas numeritajn ŝablonajn dosierojn
kaj `export.json`, kiu listigas originalajn nomojn, tempon, nominalan daŭron, dosierajn nomojn,
WAV-daŭron kaj nombron de ripetoj. Sekuraj dosieraj nomoj povas anstataŭi interpunkciajn signojn;
la nombro tenas malsamajn nomojn distingeblaj. La defaŭlto skribas kaj `.mid` kaj `.wav`;
`--format midi` aŭ `--format wav` skribas nur tiun formaton. MIDI bezonas SBCL; WAV ankaŭ bezonas
SuperCollider kaj la paletron, preparitan per `music setup`. Ĝi ne bezonas PipeWire, JACK,
navigilon aŭ aŭdaparaton.

Ambaŭ formatoj uzas la konservitan tempon (defaŭlte 120), altonojn, paŭzojn, svingon kaj
voĉojn de la progresio de la ludilo. Svingo alternas la komencajn momentojn de la taktoj
per la konservita frakcio de takto. La daŭro de noto estas la pli mallonga el 0,3 sekundoj
kaj 80% de rekta takto; akordoj de la progresio reaperas dum 0,3 sekundoj en ĉiu okupata takto,
inkluzive de ripetitaj taktoj. Ili ne daŭras inter blokoj. Eksporto komenciĝas je tempo nulo kaj
konservas la finajn silentajn taktojn. Noto, kiu estas prokrastita post la fino de la lasta takto,
konservas sian plenan daŭron: MIDI finiĝas post la fino de la noto, WAV post ĝia envolvaĵo plus
du blokoj de 64 samploj (ĉirkaŭ 2,7 ms) por la planado kaj kontrolfrekvenca rondigo de la motoro.
Alie, dosieroj finiĝas ĉe la nominala limo de takto. Svinganta lasta noto povas do fari ke dosiero
estas iomete pli longa ol la takta reto; uzu la nominalan daŭron dum aranĝado de ripetoj en DAW.

MIDI estas tipo-0 Standard MIDI-dosiero kun tempo kaj 4/4 metadataro, je 9.600 taktoj
po kvar-takto. La tempo estas rondigita al la plej proksima mikrosekundo por kvar-takto
kaj eventoj al la plej proksima takto. Altonaj notoj uzas kanalon 1; melodia `x` estas A3
(MIDI 57). Tamburoj uzas kanalon 10 kun la ĝeneralaj MIDI-notoj 36 (basotamburo), 38 (snare)
kaj 42 (ferma hi-hat). Velocaj skaloŝablonaj gajnoj al 1–127; voĉoj de la progresio
dividas tiun gajnon per tri. Nula gajno forlasas not-eventojn. Ne estas ŝanĝoj de programo:
**MIDI enhavas notojn kaj tempigon, ne la sintetezajn timbrojn de Vikix aŭ krudan registritan
aŭdion**. Elektu instrumentojn en la riceva programo; ĝia rapida respondo kaj envolvaĵo estos malsamaj.

WAV estas stereofona, 48.000 Hz, signita 16-bita PCM. Finita SuperCollider-rendirado senrete
uzas la saman preparitan sesvoĉan paletron kaj eventajn funkciojn kiel viva ludado, je fiksa
sesia gajno de 0,08, multiplikita per la ŝablonaj gajnoj (dividitaj per tri por ĉiu voĉo de
progresio). Ĝi ignoras la gajno-glitilon de la viva sesio. La mallonga silenta prepara intervalo
de la rendirilo estas forigita. Ĉiu voĉo konservas sian liberigitan envolvaĵon; la ferma hi-hat
daŭras 61 ms, sendepende de la daŭro de la noto. Sonoj bazitaj sur bruo povas malsimili inter
rendiradoj; la tempigo estas fiksita, sed identaj aŭdi-oktoj ne estas promesataj. Neniu viva sono
aŭ mikrofono estas registrita, kaj neniu normaligo estas aplikata.

La aro fariĝas videbla sub sia fina nomo nur post kiam ĉiuj petitaj dosieroj sukcesis. Pli fruaj
eksportoj neniam estas anstataŭigitaj. Invalidaj komponaĵoj, mankantaj sonoj, fiaskoj de la
rendirilo, plenaj diskoj kaj Ctrl+C lasas pli fruajn arojn netuŝitaj; normalaj fiaskoj kaj
traktitaj signaloj elĉesas la infanojn de la komando kaj forigas ĝian provizoran dosierujon
`send-*`. Elektrokut-malfunkcio aŭ nekaptebla forigo povas lasi tiun kaŝitan provizoran dosierujon;
ĝi ne estas kompleta eksporto. Konservu kompletitajn arojn, kopiajn, aparte: momentfoto-malfaron
kovras komponaĵojn, ne rendiritajn dosierojn.

Manuala kontrolo post instalado: tenu ŝablonan ludilon ludantan, faru `send` kun mallonga svinga
melodio kaj progresio, kiu enhavas silenton, kaj kontrolu, ke la ludilo konservas sian elekton,
gajnon kaj pozicion. Malfermu la rezultan MIDI en DAW, elektu instrumentojn kaj kontrolu notojn,
tempon kaj paŭzojn. Aŭskultu la WAV kaj komparu ĝian timbron kun viva ludado je sesia gajno de 0,08.
Faru la eksporton denove kaj konfirmu, ke la pli frua aro restas. Aŭtomatigitaj izolaj lanĉiloj
kaj rendiradoj de formondoj ne establas realan aŭskultan kvaliton por komputilo.

## Kio venos poste

Integriĝo en DAW, MIDI-kontrulilo kaj variaĵoj restas.

`vikix remove music` forigas la dependaĵojn de la funkcio, kiam nenia alia parto de la sistemo
bezonas ilin, kaj la preparitan sintezilon, konservante `~/music`. `vikix music setup` povas
rekonstrui la sintezilon sen anstataŭigi viajn ŝablonojn.
