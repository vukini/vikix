# Viaj notoj, en la portebla komputilo kaj la telefonoj

Viaj notoj estas unu dosierujo de Org-dosieroj, `~/Dropbox/notes`. En la portebla komputilo vi faras noton de ĉie per klavo, de tempo al tempo ordigas la enirujon en viajn dosierojn, kaj legas kaj markas viajn TODO-erojn en Emacs. Dropbox transdonas la dosierujon al viaj telefonoj, kie Org-aplikaĵo legas ĝin, aldonas al ĝi kaj ankaŭ markas aĵojn. Neniu konto krom Dropbox, kaj la notoj restas simpla teksto, kiun vi povas malfermi per ajna programo.

Ĝi konsistas el du partoj: la aldonaĵo `inbox` (la klavo kaj la ordigo: `vikix plugin add inbox`) kaj la klavoj `C-c n` de Emacs (Vikix-a `vikix-notes.el`, kiun la konfiguracio de Emacs ŝargas). La dosierujo estas kreita per via unua noto.

## Fari noton

**Super+Alt+i**, super ĉio, kion vi faras, malfermas malgrandan fenestron. Skribu la noton; la unua linio estas ĝia titolo. Aŭ premu **Super+F9** kaj parolu: diktado skribas en la fenestron. **C-c C-c** konservas ĝin, **C-c C-k** forigas ĝin.

**Super+Alt+Shift+i** faras la samon kun tio, kion vi elektis, kaj inkluzivas tion citite en la noton.

Ĉiu noto tuj alvenas al la fino de `~/Dropbox/notes/inbox.org`, kun la horo, kiam vi skribis ĝin, kaj la fenestro, en kiu vi estis (kaj, en Firefox aŭ Nyxt, la adreso de la paĝo). De terminalo aŭ skripto: `inbox add "voku la bankon"`. En Emacs: **C-c n c**.

## Ordigo de la enirujo

**Super+Alt+Shift+s** malfermas terminalon kaj demandas al la modelo, kiun Super+i uzas (`vikix ai use`: unu en ĉi tiu portebla komputilo, aŭ Claude, kaj tiam la teksto de viaj notoj sendiĝas al Anthropic, kiel ĝi diras unue), kie ĉiu noto apartenas: en kiu dosiero, kaj en kiu ĉefa titolo. Ĝi ankaŭ supozas, kiuj notoj estas aĵoj por fari. Vi vidas la liston antaŭ ol io moviĝas:

```
   1  Check the Q3 numbers  → work.org   to-do
   2  Call the bank         → personal.org   to-do
   3  helllo                → stays in the inbox
```

- **Eniru** movas ilin.
- **Nombro** (`3`) ŝanĝas, kie tiu noteto aperos.
- **"t" kaj nombro** (`t 2`) faras ĝin tasko, aŭ ne.
- **"d" kaj nombro** (`d 3`) forigas ĝin; denove `d 3` tenas ĝin.
- **"q"** haltigas, kaj nenio moviĝas.

Taskoj ricevas `TODO` antaŭ sia titolo. `inbox sort --undo` remetadas ĉiun dosieron reen al la stato, en kiu ĝi estis antaŭ la lasta ordigo, kiam nenio ŝanĝis ilin.

Por movi unu noteton per mano, malfermu la enirujon (**C-c n o**), metu la kursoron sur la noteton kaj premu **C-c C-w**: ĝi petas dosieron (`work.org` metos la noteton ĉe ĝia fino) aŭ ĉefan titolon en unu (`work.org/Projects`), kaj la noteto iras tien, for de la enirujo. Tajpu `TODO` antaŭ ĝia titolo por fari ĝin tasko. (La propra ŝlosilo de Org, kun ĝiaj celoj agorditaj al viaj notod dosieroj; via propra `org-refile-targets`, se vi agordis ilin, estas konservataj.)

La unua ordigo kreas kvar dosierojn por ordigi: `work.org`, `personal.org`, `projects.org` (titolo por ĉiu projekto en `~/src`) kaj `someday.org`. Renomigu ilin, aldonu viajn proprajn aŭ forigu ilin: la ordigo ofertas ĉiujn `.org` dosierojn, kiuj troviĝas en la dosierujo, kaj iliajn ĉefajn titolojn.

**Taskoj en Todoist.** Donu al Vikix vian Todoist-tokenon unufoje: `vikix ai key set todoist` (en Todoist: Agordoj, Integradoj, Programisto). Post tio, ĉiu ordigo demandos, ĉu ankaŭ sendi siajn taskojn al Todoist, kaj ĉiu noteto konservas la ligon de la tasko.

## En Emacs

Ĉio troviĝas sub **C-c n**:

| Ŝlosiloj | Kio ĝi faras |
|---|---|
| `C-c n a` | La agendo: ĉi tiu semajno, poste ĉiuj TODO en viaj notoj, ilia ĵurnalo kaj viaj Trakoj (`tracks/`, la kromprogramo de Budanth) |
| `C-c n t` | Ĉiuj TODO; premu "t" sur unu por marki ĝin farita |
| `C-c n c` | Noteto en la enirujon |
| `C-c n o` | Malfermu notod dosieron, unue la enirujon |
| `C-c n j` | La hodiaŭa ĵurnala paĝo, `journal/2026-10-03.org` |
| `C-c C-w` | En noteto: movu ĝin en alian notod dosieron, aŭ sub unu el ĝiaj ĉefaj titoloj |
| `C-c n f` | Trovu noteton per ĝia titolo, aŭ komencu novan |
| `C-c n i` | Ligo al alia noteto, kie vi estas |
| `C-c n l` | Kio ligas al ĉi tiu noteto |
| `C-c n g` | La grafikaĵo de viaj notoj kaj iliaj ligoj, en la navigilo |

La lastaj kvin uzas org-roam (kaj la grafikaĵo org-roam-ui), la kromprogramoj por ligoj inter notoj, kiel Obsidian havas ilin. emacs-void instalas ilin kun siaj aliaj pakaĵoj (vi estas demandata la unuan fojon, kiam unu estas bezonata, ĉu vi volas agordadon sen ili). Ilia indekso de viaj notoj estas konservata sur la laptopo (`~/.cache/vikix/org-roam.db`), neniam en Dropbox, kaj estas kreita denove el la dosieroj, kiam ajn ĝi estas bezonata; la grafikaĵo estas servata nur al ĉi tiu laptopo.

Notod dosiero malfermita en Emacs mem prenas la ŝanĝojn, kiujn la telefonoj faras al ĝi, kondiĉe ke vi ne ŝanĝis ĝin en Emacs. Notoj malfermiĝas pretaj por redakti, kvankam emacs-void malfermas aliajn dosierojn nur por legi (ĝia `my/editable-directories` diras, kiuj dosierujoj estas esceptitaj).

## Sur la telefonoj

Ĉiu telefono bezonas Org-aplikon, kiu sinkronigas kun Dropbox. Montru ĝin al la dosierujo `notes` en via Dropbox; ĝi legas kaj skribas la samajn dosierojn kiel Emacs.

### Android: Orgzly Revived

Senpaga kaj malfermfonta: el [F-Droid](https://f-droid.org/packages/com.orgzlyrevived/) aŭ Google Play. (La originala Orgzly ne estas plu ĝisdatigita; Revived estas ĝia daŭrigo.)

1. Malfermu ĝin, poste **Agordoj → Sinkronigo → Deponejoj**, kaj aldonu **Dropbox**-deponejon.
2. Enirus en Dropbox, kiam ĝi petas, kaj permesu al Orgzly.
3. Por la dosierujo, tajpu **`/notes`**: la dosierujo ene de via Dropbox, sen "Dropbox".
4. Revenu kaj premu **Sinkronigi** (la rondaj sagoj). Ĉiu `.org` dosiero fariĝas notlibro: Enirujo, Laboro, Persona kaj la resto.

Por ke novaj notoj iru al la enirujo, elektu **enirujo** kiel la notlibro por novaj kaj dividitaj notoj en la agordoj. Sinkronigo okazas, kiam vi premas la butonon; pli novaj versioj ankaŭ povas sinkronigi sin mem kiam la aplikaĵo malfermiĝas kaj post ĉiu ŝanĝo (**Agordoj → Sinkronigo**, aŭtomata sinkronigo). Se la paĝoj de la ĵurnalo (`journal/`) ne aperas, aldonu `/notes/journal` kiel duan Dropbox-deponejon.

La agendo estas serĉo: `ad.7` listigas la venontajn sep tagojn, `i.todo` ĉiujn TODO. Orgzly ankaŭ povas memorigi pri planita tempo aŭ fino (**Agordoj → Memoriloj**).

### iPhone: beorg

El la App Store. Senpaga, kun kromprogramoj, kiujn vi povas aĉeti interne (temoj, pli da sinkronigaj elektoj); sinkronigo kun Dropbox estas en la senpaga parto.

1. Malfermu ĝin, poste **Agordoj → Sinkronigo**, kaj elektu **Dropbox**.
2. Agordu la dosierujon al **`/notes`**.
3. Frapu **Ligu Konton**, kaj permesu al beorg en Dropbox.

beorg sinkronigas la `.org` dosierojn en tiu dosierujo. Por vidi ankaŭ la paĝojn de la ĵurnalo, ĝi bezonas, ke subdosieroj estu aktivigitaj: malfermu la dosieron `init.org` en beorg (ĝiaj propraj agordoj, konservitaj en la sama dosierujo) kaj aldonu la linion `(set! sync-subfolders #t)`, poste rekomencu beorg. Ĝia divida folio aldonas ligon aŭ tekston el ajna aplikaĵo al la enirujo, kaj ĝia agendo kaj taskolisto legas ĉiun dosieron.

### Kion ĉiu povas fari

| | Laptopo (Emacs) | Orgzly Revived | beorg |
|---|---|---|---|
| Legi ĉiun noton | jes | jes | jes |
| Enmeti noton en la enirujon | Super+Alt+i, C-c n c | jes (kaj el la divida menuo) | jes (kaj el la divida folio) |
| Marki TODO kiel farita | jes | jes | jes |
| La agendo, la venonta semajno | jes | jes (kiel serĉo) | jes |
| Memoriloj je planita tempo | ne | jes | jes |
| La ĵurnalo | C-c n j | kun la dua deponejo | kun subdosieroj aktivigitaj |
| Ordigo de la enirujo per modelo | Super+Alt+Shift+s | ne | ne |
| Ligoj inter notoj, reversoj, la grafikaĵo | jes (org-roam) | ligoj aperas kiel teksto | ligoj aperas kiel teksto |

## Importado de Obsidian-vaulto

`vikix obsidian` konvertas Obsidian-vaulton en Org-notojn en `~/Dropbox/notes/vault/`, unue dosierujo po do. La vaulto mem estas nur legata: nenio en ĝi ŝanĝiĝas, do Obsidian daŭre funkcias kiel antaŭe, ĝis vi estas kontentaj pri la kopioj de Org.

```sh
vikix obsidian                     # the vault's folders, how many notes, which are converted
vikix obsidian convert Books       # one folder (. for the notes at the vault's top)
vikix obsidian report Books        # what didn't convert cleanly, note by note (in Emacs)
vikix obsidian convert --all       # every folder not left out
```

- **Ligoj restas ligoj.** Ĉiu notoj ricevas ID-on, kaj `[[Alia noto]]` fariĝas org-roam-ligo al ĝi, do `C-c n f`, reverso-ligoj kaj la grafikaĵo kovras la deponejon. Ligo al dosierujo, kiu ankoraŭ ne estis konvertita, funkcios, kiam tiu dosierujo estos konvertita.
- **Kio akompanas:** la titolo, sinonimoj kaj etikedoj (el la nomo de la dosiero kaj ĝia prefakso; aliaj prefaksoj fariĝas ecoj), titoloj, listoj, taskoj, tabeloj, kodo, kaj la dosieroj, kiujn noto montras aŭ al kiuj ĝi ligas (bildoj, PDF-oj, sonoj), kiuj estas kopitaj en `vault/attachments/`. Nur tiuj dosieroj, ne ĉiu dosiero en la deponejo.
- **Kion la raporto listigas:** ligon al noto, kiu ne ekzistas aŭ estas en dosierujo, kiu estis forlasita (restas kiel teksto), du notoj kun la sama nomo (la pli proksima estas uzata, kiel faras Obsidian), noto enmetita en alian (Org ne povas enmeti: ĝi fariĝas ligo), ligo al titolo (ĝi iras al la noto), Excalidraw-desegnaĵoj (restas kun sia nomo), ==elstarigita teksto== (fariĝas grasa) kaj citaĵoj.
- **Forlasitaj:** la dosierujoj nomitaj en `~/.config/vikix/obsidian` (`skip =`: importitaj, kiel Readwise kaj Google Keep, la dosierujo de aldonaĵoj, ŝablonoj). Forigu unu el la listo por konverti ĝin. La sama dosiero diras, kie estas la deponejo (`vault =`) kaj kie iras la notoj (`to =`).
- **Rekonverti dosierujon** reskribas ĝiajn notojn, escepte ĉiu, kiun vi ŝanĝis post tio, kion la raporto nomas (`--force` reskribas ilin ankaŭ).

Ĝi bezonas pandoc (`vikix add cli-extras`).

## Kio moviĝas, kaj kio ne

- **La tuta dosierujo moviĝas**, dum la programo Dropbox funkcias sur la portebla komputilo (`vikix add dropbox`). Dropbox nur transportas ŝanĝojn dum ĝi funkcias: noto prenita kun ĝi, kiam ĝi estis haltigita, aperas kiam vi lanĉas ĝin. `notes-sync` (Super+m, *Notoj: sinkronigi kun Dropbox*) lanĉas ĝin se necese kaj atendas ĝis viaj notoj estas senditaj; `dropbox filestatus ~/Dropbox/notes` diras, ĉu ili estas.
- **Propra de la portebla komputilo:** agordoj kaj raportoj de `vikix obsidian` (`~/.local/state/vikix/obsidian/`), indekso de org-roam (`~/.cache/vikix/org-roam.db`), la grafikaĵo, la kopioj, kiujn ĉiu programo konservas por `--undo` (`~/.local/state/vikix/inbox/sorts/`), kaj la agordoj de la kromprogramo inbox.
- **Du ŝanĝoj al la sama dosiero, antaŭ ol unu el ili estis sinkronigita** (ekzemple, la telefono ne konektita), ne povas ambaŭ venki. Dropbox konservas la alian kune kun ĝi kiel `inbox (konflikta kopio).org`: malfermu ambaŭ, kopiu la mankantajn partojn, kaj poste forigu la kopion. Orgzly demandas, ĉu ĝi devas rekargi la dosieron (**Force Load**) aŭ konservi la version de la telefono (**Force Save**); beorg avertas vin kaj konservas la version, kiun ĝi anstataŭigis.
