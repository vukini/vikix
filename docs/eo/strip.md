# La vico, labortablo kiu ruliĝas

Aroj bonas por du aŭ tri fenestroj. Kun kvin, ĉiu estas tro malgranda por labori en, aŭ plejparto estas kaŝitaj malantaŭ aliaj. Vico estas alia maniero ordigi labortablon: ĝiaj fenestroj staras unu apud la alia en vico, kiu estas pli larĝa ol la ekrano, ĉiu kiel larĝa kiel ĝi devas esti, kaj vi moviĝas laŭ la vico. Nenio malpliiĝas kiam fenestro malfermiĝas, kaj nenio estas kaŝita: tio, kio ne estas sur la ekrano, estas simple flanke.

![Vico de kvin kolumnoj: la ekrano montras du el ili, la aliaj staras preter ĝiaj randoj, kaj Super+h kaj Super+l moviĝas laŭ la vico](diagrams/strip.svg)

Kolumno estas unu fenestro, aŭ kelkaj staplitaj unu super la alia. La ekrano montras kiel multajn kolumnojn ĝi povas; la resto daŭre ruliĝas preter ĝiaj randoj, kaj revenas en la momento, kiam vi iras al ili.

Vi elektas ĝin por unu labortablo je la sama tempo. La aliaj restas kiel estas, kaj la labortablo revenas al aro, kiam ajn vi volas, dividita kiel antaŭe. La ideo estas de Niri, Wayland-komponanto; en Vikix ĝi nomiĝas Viri.

## Fari labortablon vico, kaj poste denove aro

Ĉiuj el ĉi tiuj, sur la labortablo, kiun vi volas:

- `Super+m`, poste *Vico: ĉi tiu labortablo ruliĝas horizontale* (Viri), aŭ *denove aro* (en *Fenestroj*, aŭ tajpu `strip`)
- `Super+Ctrl+Space`, la ŝlosiloj por la aranĝo, poste `s` (aŭ `Space` por la menuo, poste *Vico: kolumnoj unu apud la alia, kiuj ruliĝas horizontale*)
- `vikix viri` en terminalo (`vikix viri on` kaj `vikix viri off` diras, kiu estas aktiva)

Ĝiaj fenestroj konservas la ordon, en kiu ili staris: de maldekstre al dekstre, poste de supraĵo al subaĵo. La sama ago (aŭ `vikix viri off`) faras ĝin denove aro, dividita kiel antaŭe, antaŭ ol ĝi estis vico, ĉiu fenestro revenas al sia loko. Fenestro malfermita dum ĝi estis vico, aliĝas al la divido, en kiu vi estas.

Por fari, ke labortablo ĉiam komencu kiel vico, estu regulo en `~/.stumpwm.d/rules.lisp` ([Reguloj por la labortablo](rules.md) estas ties paĝo):

```lisp
(when-workspace 3 (command "vikix-viri on"))
```

## Navigado tra ĝi

| Klavokombinaĵo | Kio ĝi faras |
|---|---|
| `Super+h`, `Super+l` | la kolumno maldekstre, dekstre; la vido ruliĝas kiam necesas |
| `Super+j`, `Super+k` | malsupre kaj supren, en kolumno de pluraj fenestroj |
| `Super+Home`, `Super+End` | la unua kolumno de la vido, kaj ĝia lasta |
| `Super+Shift+h`, `Super+Shift+l` | movu ĉi tiun kolumnon maldekstren aŭ dekstren laŭ la vido |
| `Super+Shift+j`, `Super+Shift+k` | movu ĉi tiun fenestron malsupren aŭ supren en sia kolumno |
| `Super+Tab` | reen al la fenestro en kiu vi estis antaŭe; denove alternas inter la du |
| `Super+o` | ĉiuj labrejoj montrataj kiel malgrandaj, la vido inter ili, por elekti fenestron |
| `Super+g` | la listo de ĉiuj fenestroj en ĉiuj labrejoj, por iri al unu |

Nova fenestro malfermiĝas kiel aparta kolumno, tuj dekstre de tiu, en kiu vi estas, kaj ricevas la fokuson. Kiam vi fermas unu, la fokuso iros al la kolumno, kiu prenis ĝian lokon.

La baro ĉe la supro montras, kie vi estas: la fenestroj de la vido en ordo, tiuj sur la ekrano en krampoj, la fenestro, en kiu vi estas, resaltita, kiel en `A [B C] D`. Kolumno de du fenestroj estas skribita `D/C`. La fenestro, en kiu vi estas, havas koloritan randon kaj titolan baron, kiel ĉe la mozaikaj aranĝoj.

La vido ruliĝas nur tiel multe, kiel ĝi devas, por montri la kolumnon, al kiu vi iris, tute, do najbaro povas aperi parte. Ĝi ankaŭ konservas etan parton de la sekva kolumno videbla ĉe ĉiu rando de la ekrano, kiu havas unu, kelkajn dudekojn da pikseloj: vi povas vidi je unua rigardo, ke la vido daŭras tiel. Ĉe la randoj de la vido ne estas, kaj la unua kaj la lasta kolumno staras ĉe la rando de la ekrano. Ĝi glitas tien, en ĉirkaŭ dekono de sekundo.

## Kolumnoj: kiel larĝa, kaj kio estas en ili

| Klavokombinaĵo | Kio ĝi faras |
|---|---|
| `Super+r` | ĉi tiu kolumno pli larĝa: duono de la ekrano, du trionoj, la tuta, tiam triono, kaj denove |
| `Super+b` | ĉi tiu kolumno egale larĝa kiel la spaco, kiun la aliaj kolumnoj sur la ekrano lasas |
| `Super+[`, `Super+]` | ĉi tiu fenestro en la kolumnon maldekstre aŭ dekstre de ĝi, sub la ekzistanta; premite sur fenestro, kiu dividas kolumnon, foriras en sian propran kolumnon tiel |
| `Super+f` | ĉi tiu fenestro sur la tuta ekrano, kaj reen |
| `Super+Ctrl+y` | titolaj baroj sur kaj for, kiel ĉe la mozaikaj aranĝoj |

`Super+b` estas por kiam la larĝoj ne sumiĝas: kolumno du trionoj larĝa apud unu, kiu estas duono, fortranĉas unu el ili. Premite sur kolumno, ĝi donas al tiu kolumno tion, kion la aliaj, kiuj estas tute sur la ekrano, lasas, tiel ke kune ili plenigas ĝin kaj neniu estas fortranĉita. Apud alpingita kolumno, ĝi prenas la reston de la ekrano.

Nova kolumno estas duono de la ekrano larĝa. La fenestroj de kolumno dividas ĝian altecon egale: redaktilo kun terminalo sub ĝi, ekzemple, estas `Super+[` premite sur la terminalo, kiu staras dekstre de la redaktilo.

### Altecoj: pli por unu, malpli por alia

Pilecaj fenestroj dividas la altecon de sia kolumno egale komence. Por doni al unu pli: `Super+v` sur ĝi igas ĝin triono de la kolumno, tiam duono, tiam du trionoj (la paŝoj super tio, kion ĝi havas), kaj post la plej alta, ĉiuj fenestroj de la kolumno estas denove egalaj. La aliaj konservas siajn proporciojn en tio, kio restas. Kun la muso, tiru la randon inter du pilecaj fenestroj supren aŭ malsupren: tio, kion unu gajnas, la alia perdas, dudekonon de la kolumno je la tempo.

Fenestro, kiu unuiĝas al la kolumno, ricevas egalan parton de ĝi. La aranĝo, kiun vi konservas, konservas la altecojn.

### Taboj: unu fenestro je la tempo

Fenestroj pilecaj en kolumno, ĉiu ricevas parton de ĝia alteco. Kiam ili ĉiuj bezonas la tuton (tri terminaloj, du dokumentoj), faru ilin taboj: `Super+z` sur kolumno de pluraj fenestroj montras unu el ili tiel alta kiel la kolumno, kun la aliaj malantaŭ ĝi. Ĉiu estas tabo en la titola baro, la montrata resaltita.

| Klavokombinaĵo | Kio ĝi faras |
|---|---|
| `Super+z` | la fenestroj de ĉi tiu kolumno kiel taboj; denove, pilecaj unu super la alia |
| `Super+j`, `Super+k` | la sekva tabo, la antaŭa |
| `Super+Shift+j`, `Super+Shift+k` | movu ĉi tiun tabon |
| `Super+[`, `Super+]` | alportu la fenestron en la kolumnon apud ĝi, kiel plia tabo tie; aŭ forigu tabon en sian propran kolumnon |

Klako sur tabo iras al ĝi. La baro kunigas la fenestrojn de tabita kolumno per `+`, kiel en `A [B D+E+C]`, kie pileca estas kunigita per `/`. La aranĝo, kiun vi konservas, memoras, kiuj kolumnoj estis tabitaj. Kun titolaj baroj forigitaj (`Super+Ctrl+y`), la taboj ankoraŭ funkcias per la klavoj; nur ne estas ion, sur kion klaki.

## Alpingi kolumnon

Kelkaj fenestroj, kiujn vi volas vidi, kio ajn vi faras: babilaĵo, paĝo, kiun vi legas, terminalo kun funkciaĵo. Sur vido, ili ruliĝus kun la resto. `Super+\` alpingas la kolumnon, en kiu vi estas: ĝi iras al la maldekstra rando de la ekrano kaj restas tie, kaj la aliaj kolumnoj ruliĝas en la spaco apud ĝi.

| Klavokombinaĵo | Kio ĝi faras |
|---|---|
| `Super+\` | alpingi ĉi tiun kolumnon; sur la alpingita kolumno, forigi ĝin denove |
| `Super+h` de la unua el la aliaj | en la alpingitan kolumnon |
| `Super+l` de la alpingita kolumno | al la kolumno, kiu staras apud ĝi nun |

Unu kolumno estas alpingita je la tempo: alpingi alian kaj ĝi prenas ĝian lokon. La baro montras ĝin unue, kun baro post ĝi: `D | A [B C] E`. Ĝi konservas sian larĝon (`Super+r` kaj la muso ŝanĝas ĝin kiel por ajna kolumno, kvankam ĝi neniam prenas pli ol du trionoj de la ekrano), ĝi povas enhavi plurajn fenestrojn (`Super+[` de la kolumno apud ĝi), kaj nenio moviĝas preter ĝi. La aranĝo, kiun vi konservas, memoras, kiu kolumno estis alpingita. Kolumno tro larĝa por la spaco, kiun la alpingita lasas, staras kun sia maldekstra rando ĉe la alpingita kolumno kaj sia dekstra parto preter la rando de la ekrano; `Super+b` sur ĝi igas ĝin taŭgi al la spaco egale.

Du komandoj ne havas sian propran klavon, por klavo en `user.lisp` se vi volas unu: `vikix-move-end first` kaj `vikix-move-end last` alportas la kolumnon, en kiu vi estas, al la komenco aŭ la fino de la vido.

## La muso

| Fari tion | Kaj |
|---|---|
| Tenas `Super` kaj turnas la radon super la vido | vi iras laŭ ĝi, kiel `Super+h` kaj `Super+l` faras |
| Turnas la radon super la nomoj de la fenestroj de la baro | la sama |
| Glitas du fingrojn flankdirekte sur la tuŝplato, super la vido | la sama: la vido ruliĝas kiel larĝa paĝo |
| Tiras la titolan baron de fenestro (aŭ tenas `Super` kaj tiras ie ajn en ĝi) | ĝia kolumno iras kun la indikilo, kaj restas tie, kie vi lasas ĝin |
| Tiras la flankan randon de kolumno (aŭ tenas `Super` kaj tiras kun la dekstra butono) | la kolumno iĝas pli larĝa aŭ pli mallarĝa, dudekonon de la ekrano je la tempo |
| Tiras la randon inter du fenestroj pilecaj en kolumno | la unu kreskas kaj la alia malgrandigas |
| Klikas la nomon de fenestro en la baro | vi iras al ĝi |

La du fingroj de la tuŝplato estas la rapida maniero: glititaj flankdirekte super vido, ili iras laŭ ĝi, kolumno por ĉiu mallonga streko, la maniero, en kiu ĉio alia ruliĝas sub ili (kiel via estas agordita: fingroj maldekstren iras al la kolumno maldekstre, aŭ alportas la kolumnon dekstre, kie ruliĝo estas "natura"). Supre kaj sube ili ruliĝas la programon, kiel ĉiam, kaj eta flosado flankdirekte dum vi faras tion ne iras alie. Tri fingroj faras la samon sur ajna labrejo, kaj supren aŭ malsupren iras tra la fenestroj de kolumno: `vikix gestures` diras, kiel ili estas agorditaj, kaj `vikix gestures off` haltigas ilin ([La komandoj](commands.md) havas la agordojn). Vido prenas flankdirektan ruliĝon por si, do programo sur unu, kiu ruliĝas flankdirekte (larĝa folio, longa linio), ruliĝas kun sia ruliĝa baro, aŭ kun `Shift` kaj la rado; la agordo sube donas ĝin reen.

Larĝo agordita per tirado povas esti ajna dudekono de la ekrano; `Super+r` tiam alportas la kolumnon al la sekva el ĝiaj kvar larĝoj.

## Kio estas malsama de mozaikoj

La plej multaj klavoj faras sur vido tion, kion ili faras ĉie. Kelkaj apartenas al mozaikoj, kaj diras tion, kiam ili estas premita sur vido prefere ol fari ion surprizan:

| Klavokombinaĵo | Sur vido |
|---|---|
| `Super+b` | La klavo por flanko per flanko: sur vido, ĝi igas ĉi tiun kolumnon pleni la spacon, kiun la aliaj lasas (supre). Vido ne havas dividojn: nova fenestro ricevas kolumnon, kaj `Super+[` kaj `Super+]` pilecas. |
| `Super+v` | La klavo por unu super la alia: sur vido, ĝi igas ĉi tiun fenestron pli alta en sia kolumno (supre). |
| `Super+u`, `Super+Shift+u` | Neniu malfaro de aranĝo: vido konservas sian ordon, kaj vi movas kolumnon reen. |
| `Super+z` | La fenestroj de ĉi tiu kolumno kiel taboj (supre), kie sur mozaikoj ĝi konservas nur unu fenestron sur la labrejo. |
| `Super+Shift+o`, `Super+Ctrl+m` | Reĝimoj de reto kaj ĉefo kaj pileco estas manieroj de mozaikoj. |
| `Super+Shift+g` | La fenestro, kiun vi elektas, venas al la vido, kiel kolumno apud la, en kiu vi estas. |
| `Super+m` → *Alportu ĉiujn fenestrojn de alia labrejo ĉi tie* | Ili ĉiuj venas al la vido kiel kolumnoj; de vido al mozaika labrejo, ili alvenas mozaike. Neniu estas lasita flosante, sed dialogo, aŭ fenestro, pri kiu via regulo estas flosanta. |
| `Super+Shift+1` … `9` | Kolumno estas kio moviĝas sur vido, do la tuta kolumno iras al tiu labrejo: fenestro sola en sia kolumno iras sola; unu, kiu dividas ĝin, prenas la aliajn kun si. Sur alia vido, ĝi alvenas kiel la kolumno, kiu ĝi estis (sia larĝo, taboj aŭ pileco, la altecoj); sur mozaika labrejo, ĝiaj fenestroj estas mozaikaj. Por sendi unu fenestron de pluraj, foriru el la kolumno unue (`Super+[` aŭ `Super+]`). |

Dialogoj (pasvorto-kesto, dosier-elektejo) flosas en la mezo de la ekrano, kiel ĉe mozaikoj, kaj ne estas kolumnoj.

## Agordoj

En `~/.stumpwm.d/user.lisp`, ĉiu linio; `vikix eval '(loadrc)'` aplikas la dosieron ([Fari ĝin via](customize.md) havas pli pri ĝi):

```lisp
(setf *viri-default-width* 2/3)   ; a new column's width: a part of the screen (1/2 as it comes)
(setf *viri-centre* t)            ; keep the column you're in in the middle of the screen
(setf *viri-peek* 0)              ; no sliver of the next column at the screen's edges (24 pixels as it comes)
(setf *viri-animate* nil)         ; jump instead of sliding
(setf *viri-animate-seconds* 0.2) ; or slide more slowly (0.12 as it comes)
(setf *viri-width-step* 1/10)     ; dragging an edge goes a tenth of the screen at a time
(setf *viri-scroll-clicks* 3)     ; two fingers walk along the strip sooner (6 as it comes; more is slower)
(setf *viri-scroll-walks* nil)    ; two fingers swept sideways scroll the program, not the strip
```

La fenestro-aranĝo bezonas komponanton, kiun Vikix uzas (picom). Sen ĝi, la fenestroj saltus, ĉar ĉiu paŝo kaŭzus, ke ĉiu programo redrawnas sian fenestron.

Regulo povas doni al fenestro de programo ĝian larĝon aŭ lokon kiam ĝi malfermiĝas: `(width 2/3)` kaj `(join :left)`, kiel klarigite en [Kion faras regulo](rules.md#kion-regulo-faras). La kolumnoj de fenestro-aranĝo, iliaj larĝoj kaj la maniero kiel ili estas organizitaj, ankaŭ estas konservitaj per [konservitaj aranĝoj](customize.md#konservitaj-aranĝoj), kaj projekto malfermita per `vikix project open` revenas kiel la fenestro-aranĝo, kiun vi lasis.

## Kiam ĝi ne funkcias ĝuste

- **Fenestro kuŝas sur sia najbaro, aŭ restas interspaco, kie ĝi estis.** Premu dufoje `Super+Ctrl+y` (fenestra titolo aperas kaj malaperas): la fenestro-aranĝo estas refarita. Ĝi ne devus okazi, do ĝi indikas raporton: `vikix debug` generas raporton.
- **Programo ŝajnas malfreska kiam vi revenas al ĝi.** Kolumnoj preter la rando de la ekrano estas movitaj tien, ne kaŝitaj, do programoj daŭre desegnas; programo, kiu paŭzas kiam ĝi pensas, ke neniu rigardas, povas preni momenton por sin ĝustigi.
- **Du fingroj moviĝas tro rapide, tro malrapide, aŭ en la malĝusta direkto.** La valoro de `*viri-scroll-clicks*` supre indikas, kiom ili moviĝas dum ĉiu paŝo. La direkto estas la direkto de ruliĝo de via tuŝplato, la sama kiel en ĉiu programo; tri fingroj ankaŭ sekvas ĝin, krom se `natural` en `~/.config/vikix/gestures` diras alie.
- **Vi preferus havi la kahelajn fenestrojn reen.** `vikix viri off`. Nenio perdiĝas: la fenestroj, kaj la aranĝoj, kiujn la labr-spaco havis antaŭe.

## Por la kuriozaj: kiel funkcias fenestro-aranĝo

Ĝi estas unu dosiero, `config/stumpwm/vikix/viri.lisp`, kaj ĝi estas pli malgranda, ol ĝi ŝajnas. StumpWM havas du tipojn de labr-spacoj enkonstruitaj: kahelaj, kiuj posedas la lokojn de la fenestroj, kaj flotantaj, kiuj lasas ĉiu fenestro tie, kie ĝi estas metita. Fenestro-aranĝo estas flotanta labr-spaco (`viri-group`, subklaso de `float-group` de StumpWM), en kiu Viri faras la metadon. La propra kodo de StumpWM ankoraŭ fokusigas, levigas kaj fermas la fenestroj; `viri.lisp` nur transprenas tion, kion fenestro-aranĝo faras malsame: fenestro aliĝas (`group-add-window`), foriras (`group-delete-window`), estas fokuse (`group-focus-window`), kaj muskliko (`group-button-press`).

Kion la fenestro-aranĝo memoras, estas malgranda: listo de kolumnoj, ĉiu kun siaj fenestroj de supra ĝis suba, ĝia larĝo kiel parto de la ekrano kaj la fenestro, kiu estis fokuse en ĝi lastfoje; kaj kiom la fenestro-aranĝo estis ruliĝinta, en pikseloj de ĝia maldekstra rando. Ĉio sur la ekrano sekvas el tio. `viri-place` kalkulas la lokon kaj grandon de ĉiu fenestro el ili, kaj `viri-layout` vokas ĝin ĉiam, kiam io ŝanĝiĝis.

Jen kio okazas kiam vi premas `Super+l`:

![Super+l igas funckion vikix-focus, kiu petas al la fenestro-aranĝo la sekvan kolumnon; fokuso de ĝi ruliĝas la fenestro-aranĝon, kiu glitas ĝiajn fenestrojn kaj poste aranĝas ilin](diagrams/strip-scroll.svg)

Tri aĵoj en ĝi estas tie pro la funkcio de X kaj StumpWM:

- **La klavoj ne estas apartenaj al la fenestro-aranĝo.** StumpWM unue serĉas en sia ĉefa klava mapo, kaj ĉiu klavo de Vikix estas en la ĉefa. Do `Super+l` igas funckion `vikix-focus`, kiu trakurigas la fenestro-aranĝon kaj moviĝas inter la sekcioj ĉie aliloke. `vikix-move`, `vikix-split` kaj la aliaj estas faritaj laŭ la sama maniero.
- **La fenestro-aranĝo estas ciklo, ne tempigilo.** `viri-slide` movas ĉiun kolumnon iomete, ok foje, kun mallonga paŭzo inter ili. Tempigilo volus frakcion de sekundo kiel ĝia malrapidiĝo, kaj la tempigiloj de StumpWM ĉesas funkcii, kiam oni donas al ili tian.
- **La indikilo estas kunprenita.** La fokuso de Vikix sekvas la manson. Kiam la fenestro-aranĝo moviĝas sub indikilo, kiu restas senmova, X raportas, ke la indikilo eniris la fenestron, kiu aperis sub ĝi, kaj tiu fenestro reenprenus la fokuson. Do `viri-keep-pointer` movas la indikilon al la fokuse fenestro kaj forigas tiujn raportojn.

La alteco de fenestro en sia kolumno estas pezo, 1 por egala partigo, konservita de la fenestro (`*viri-weights*`); `viri-heights` transformas la pezojn de kolumno en pikseloj. Kio estas tabulita estas notita laŭ la sama maniero (`*viri-tabbed*`): `viri-place` donas al ĉiu fenestro de tabulita kolumno la tutan kolumnon kaj kaŝas ĉiujn krom la fenestro, kiun ĝi montras, same kiel la fenestroj de kahelo malantaŭ la fenestro ĉe la avanĝo estas kaŝitaj, kaj la titolo (`vikix-titlebar-draw` en `windows.lisp`) desegnas ĉelon por ĉiu fenestro. La fiksita kolumno estas la unua kolumno de la fenestro-aranĝo en tiu listo, notita en tabelo apud ĝi (`*viri-pinned*`); `viri-spans` donas al ĝi la maldekstran randon de la ekrano ĉiam, kiam la fenestro-aranĝo ruliĝas, kaj komencas la aliajn, kie ĝi finiĝas.

La desegnita superrigardo (`Super+o`) estas `overview.lisp`; la fenestro-aranĝo donas al ĝi siajn kolumnojn kiel skatoloj pere de `viri-overview-boxes`. Artefarita intelekta agento vidas fenestro-aranĝon per la ilo `desktop` de `vikix mcp`, kiu listigas ĝiajn kolumnojn de maldekstro al dekstro kun iliaj larĝoj kaj kiuj estas sur la ekrano ([Laborado kun AI](ai.md)).

La dezajno, kun kio estis planita kaj kio ŝanĝiĝis dum la konstruado, estas `plans/DESIGN-viri.md` en la projekto.
