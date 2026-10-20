# Aldonaĵoj, unu post la alia

Aldonaĵoj estas etaj aldonaĵoj, kiujn vi elektas: kelkaj vortoj en la menuo, klavo, Super+m-enira komando, foje programo, kiu funkcias en la fono. Ili venas de sia propra deponejo, [vikix-plugins](https://github.com/vukini/vikix-plugins), en versio, kiun Vikix kontrolis, kaj nenio estas aldonata ĝis vi petas tion. Ĉi tiu paĝo estas gvidilo por ĉiu el ili: kion ĝi faras, kiel aldonigi ĝin, kiel uzi ĝin, kie ĝi konservas aĵojn, kaj kion fari kiam ĝi ne funkcias.

## Aldonado, forigo, malŝaltado

```sh
vikix plugin list                 # every plugin, yours marked
vikix plugin add NAME             # says what it runs, needs and changes, asks, then adds it
vikix plugin remove NAME          # runs its remove; your settings for it stay
vikix plugin off NAME             # stop loading it (vikix plugin on NAME brings it back)
vikix plugin safe                 # the next login loads none
```

La ŝlosiloj kaj la menuo de aldonaĵo funkcias tuj. Se la ŝlosilo de aldonaĵo estas la sama kiel tiu de Vikix aŭ de iu el viaj retaj programoj, la aldonaĵo venkas; aperas mesaĝo, kiu mencias ambaŭ, kaj `vikix doctor` listigas ĝin ĝis unu el ili estas forigita; forigante la aldonaĵon, la ŝlosilo estas redonita. La testoj de Vikix kontrolas la aldonaĵojn je la versio, kiu estas uzata, por eviti tiajn konfliktojn antaŭ publikigo. La agordoj de ĉiu aldonaĵo estas viaj, en `~/.config/vikix/plugins/NOMO/`, ili estas kopiaj unufoje kaj neniam anstataŭataj. Aldonaĵo, kiu konservas registron de tio, kion ĝi trovis (serĉo pri flugo, partopreno en kunveno), metas ĝin en la datenbanko, `vikix records` ([LEGŲ](../../README.md#the-record-store-vikix-records)), kie vi povas serĉi ĝin.

La komandoj de aldonaĵo (`inbox`, `repos`, `flights`...) estas en via PATH dum ĝi estas aktivigita, ĉiu kun helpa paĝo, kiu estas kreita el tio, kion ĝi eldonas per `-h`: `man inbox`. `man vikix` listigas ilin post la propraj de Vikix, kaj forigante la aldonaĵon, ĝi forigas ties helpajn paĝojn.

La kodo de aldonaĵo funkcias ene de la labortablo kun ĉiuj ĝiaj kapabloj, kiel via `user.lisp`: aldonaĵu tiujn, kiujn vi fidas. Se unu el ili iam haltigas la lanĉon de la labortablo, ensalutu en teksta konzolo (Ctrl+Alt+F2), ruligu `vikix plugin safe`, ensalutu denove, kaj malŝaltu la kaŭzon.

### Aldonaĵo de alia deponejo

Aldonaĵo ne devas veni de la deponejo de aldonaĵoj: projekto, kiun vi mem kreis (aŭ de iu, kiun vi fidas), kiu konservas dosierujon de aldonaĵoj en la formato de aldonaĵoj, povas esti aldonita de sia deponejo, je la versio, kiun vi elektas.

```sh
vikix plugin add budanth --from https://github.com/you/budanth          # at its newest commit
vikix plugin add budanth --from ~/src/budanth --at v0.3                 # a folder on this machine, at a tag
vikix plugin pin budanth                                                # move it to the newest commit
vikix plugin pin budanth 7903146abc...                                  # or to one you name
vikix plugin status                                                     # each one's repository and commit
```

La kromprogramo estas la dosierujo nomita laŭ ĝi en tiu deponejo (`budanth/` en la deponejo budanth), aŭ la deponejo mem se ĝia `manifest`-dosiero estas ĉe la supro. Vikix alprenas la deponejon je tiu versio al `~/.local/share/vikix/plugins-from/NOMO` kaj skribas linion `budanth from REPO at COMMIT` en vian `plugins.list`; `vikix update` konservas la alprenitan version, kaj nenio alian ŝanĝas ĝin krom `vikix plugin pin`. Ĉio alia estas kiel ĉe ajn kromprogramo: `add` montras kion ĝi faras kaj ŝanĝas, kaj petas, ĝiaj programoj ricevas helppagojn, ĝiaj agordoj estas viaj, `off`, `on` kaj `remove` funkcias simile (remove forigas la alprenitan version; viaj agordoj restas). La diferenco estas la fidemo: Vikix kontrolis la kromprogramojn je sia propra versio, ne ĉi tiuj, kaj `add` diras tion. Nomon, kiun la deponejo de la kromprogramoj havas, ne povas esti prenita de aliloko.

La ŝlosiloj en mallonga resumo. La ŝlosiloj de kromprogramo estas ĉiuj sur Super+Alt, kun Shift por dua sur la sama litero: tie troviĝas ĉio preter la ses ĉefaj programoj ([la regulo por ŝlosiloj](customize.md)).

| Ŝlosilo | Kromprogramo | Kion ĝi faras |
|---|---|---|
| Super+Alt+w | agent-waiting | Iru al la agento, kiu atendas vin, aŭ elektu inter pluraj |
| Super+Alt+u | ai-usage | Kiom el via Claude-plano estas uzata |
| Super+Alt+j | next-meeting | Partoprenu la aktualan kunvenon, aŭ la venontan |
| Super+Alt+c | next-meeting | La kunvenoj de la venonta semajno |
| Super+Alt+f | flights | Serĉu flugojn |
| Super+Alt+g | repos | Kiuj projektoj bezonas aperigi, alpreni aŭ registri ŝanĝojn |
| Super+Alt+i | inbox | Notu en vian enkorbon |
| Super+Alt+Shift+i | inbox | Notu, citante tion, kion vi elektis |
| Super+Alt+Shift+s | inbox | Ordenu la enkorbon |

## agent-waiting: agento atendas vin

Vi komencas Claude Code aŭ Codex pri tasko en unu fenestro kaj faras ion alian en alia. Kiam ĝi bezonas vin, aŭ finis, la baro diras, kiu sesio, kie ĝi estas kaj ĉu ĝi petas ion de vi; notifo diras kion; kaj unu ŝlosilo viiras tien.

**Aldonu ĝin:** `vikix plugin add agent-waiting`. Ĝi aldonas kvin hokojn al la agordoj de Claude Code, `~/.claude/settings.json` (unue oni konservas kopion de la dosiero). Claude Code-sesio, kiu jam funkcias, alprenas ilin, kiam vi tajpas `/hooks` en ĝi (ĝi petas, ke vi rigardu ilin), aŭ kiam ĝi komencas denove. Post ĝisdatigo, kiu alportas novajn hokojn, aldonu ĝin denove: ĝi montras, kion ĝi ŝanĝas, petas, kaj aldonas nur tion, kio ne estas tie. Kiam Codex estas agordita (`~/.codex`), ĝi ankaŭ metas la agordon `notify` de Codex en `~/.codex/config.toml` (unue oni konservas kopion), kiu aktivigas la kromprogramon kiam turno finiĝas; via propra `notify` restas kiel estas, kaj ĝi estas menciita.

**Uzu ĝin:**

- `asks: Esploro tags (3)` en la baro, en la koloro, kiu estas uzata: la sesio nomata *Esploro tags*, en la laborareo 3, petas ion de vi. Ĉu dialogo estas malfermita (permeso, demando kun elektoj) kaj ĝia laboro estas haltigita, aŭ ĝi finis kaj ĝiaj lastaj vortoj petas ion: demandon, aŭ paŝon, kiu estas via (linio, kiu komenciĝas per `You:`).
- `done: Fix the bar (1)`, pli trankvile: tiu sesio finis kaj ne petas ion.
- Kun pluraj: `asks: Esploro tags (3) +1, done 2` estas du, kiuj petas, kaj du, kiuj finis. La nomita estas tiu, al kiu vi devas iri unue: malfermita dialogo antaŭ demando, la plej malnova unue.
- Sesio estas nomata laŭ la titolo de ĝia fenestro, kiun Claude Code agordas por kio la sesio temas, kaj Codex al ĝia fluaĵo; fenestro, kiu ne havas propran titolon, estas nomata laŭ la dosierujo, en kiu la sesio laboras.
- **Codex** estas vidata du manieroj. Dum aprobo aŭ demando atendas, Codex skribas `[ ! ] Action Required` ĉe la komenco de la titolo de sia fenestro, kaj la kromprogramo legas tion: `asks` en la baro, notifo, Super+Alt+w, kun nenio, kion oni devas agordi. Kiam turno finiĝas, ĝia agordo `notify` diras al la kromprogramo, kun la lasta mesaĝo: `done`, aŭ `asks` kiam ĝi finiĝas je demando. Nenio de Codex diras, ke vi respondis, do `done` restas ĝis vi rigardas la fenestron.
- **Notifo** aperas la momenton, kiam sesio petas: `Esploro tags asks (workspace 3)`, kaj sube, kion ĝi petas (`Bash: Install the build`, aŭ ĝia demando). Sesioj, kiuj finis, restas nur en la baro. Por havi notifon ankaŭ por tiuj, aŭ nenian, metu unu el ĉi tiuj en `~/.stumpwm.d/user.lisp`:

  ```lisp
  (setf *agent-waiting-notify* :all)   ; finished sessions too
  (setf *agent-waiting-notify* nil)    ; the bar only
  ```

- **Super+Alt+w**, aŭ klako sur la breto, malfermas la fenestron. Se estas pluraj, ĝi listigas ilin unue, ĉiu kun sia labra spaco, sia nomo, kiom longe ĝi atendis kaj kion ĝi diris; Eniro malfermas la elektitan. Rigardado de fenestro forigas ĝian noton.
- Sesio, kiu haltas dum ĝia propra laboro ankoraŭ funkcias en la fono (testa sezio, kiun ĝi atendas), ne estas finita, kaj ne lasas noton krom se ĝi demandas ion.

**Kie troviĝas la aferoj:** malgranda dosiero por ĉiu fenestro en `~/.local/state/vikix/agents/`: la stato kaj la tempo, la dosierujo, kaj la linio de tio, kio estis dirita.

**Kiam ĝi ne funkcias:**

- *Nenio en la breto:* la sesio komenciĝis antaŭ ol la kromprogramo estis aldonita. Tipe `/hooks` en ĝi, aŭ rekomencu ĝin.
- *Ĝi diras al vi pri permeso kun kelkaj sekundoj da malfrapeto:* la hakilo, kiu diras, ke dialogo malfermiĝis (`PermissionRequest`), ne estas en viaj agordoj. `vikix plugin add agent-waiting` denove aldonas ĝin.
- *Ĝi diras, ke ĝi demandas, sed nenio demandas:* ĝi legis demandon en la lastaj vortoj de la sesio, kiu ne estis por vi. Rigardu la fenestron: tio forigas ĝin.
- *Ĝi diras, ke ĝi finiĝis por sesio, kiu demandis ion de vi:* ĝiaj tri lastaj linioj ne enhavis demandosignon kaj ne enhavis linion komencantan per `Vi:`. Nur tio gravas.
- *Sesio de Codex, kiu finiĝis, ne estas en la breto:* ĝia agordo `notify` ne estas en `~/.codex/config.toml` (la kromprogramo estis aldonita antaŭ ol Codex estis agordita, aŭ la dosiero havas sian propran `notify`). `vikix plugin add agent-waiting` denove aldonas ĝin; sesio de Codex, kiu jam funkcias, akceptas ĝin kiam ĝi denove komenciĝas. Tiu, kiu atendas vian "jes", tamen vidiĝas, per sia titolo.
- Ĝi konas Claude Code kaj Codex. Gemini CLI, Antigravity CLI, OpenCode kaj Aider ne komunikas kun ĝi.

**Forigu ĝin:** `vikix plugin remove agent-waiting` forigas la hakilojn el `~/.claude/settings.json` kaj la agordon `notify` el `~/.codex/config.toml` denove, kaj lasas viajn aliajn agordojn tiel, kiel ili estis.

## ai-usage: kiom da via Claude-plano restas

Kun Claude Pro aŭ Max-plano, Claude Code scias, kiom da la plano vi uzis: la 5-hora fenestro kaj la semajno. Tio metiĝas en la breton, do vi vidas limon alproksimiĝantan.

**Aldonu ĝin:** `vikix plugin add ai-usage`. Claude Code sendas tiujn nombrojn nur al sia statuslinio (la linio sub ĝia prompto), do la kromprogramo fariĝas la statuslinio. Se vi jam havis propran statuslinion, ĝi daŭre funkcios, tra la kromprogramo, kaj revenos kiel ĝi estis, kiam vi forigas ĝin.

**Uzu ĝin:**

- `plan 24% 41%` en la breto: la 5-hora fenestro, poste la semajno. La akcenta koloro ekas je 75%, la koloro por averto ekas je 90%.
- **Super+Alt+u**, aŭ klako: kiom da ĉiu fenestro uzis, kaj kiam ĝi reŝarĝiĝas.
- La propra statuslinio de Claude Code montras la samon, `plan 24% 5h · 41% week`.

**Kie troviĝas la aferoj:** la nombroj en `~/.local/state/vikix/ai-usage`. Ĉiun 15 minutojn maksimume, rekordo en la rekorda stoko: `vikix records list ai-usage` estas via uzo dum la tagoj kaj semajnoj.

**Kiam ĝi ne funkcias:**

- *"ankoraŭ nenio konata":* Claude Code scias nur post sia unua respondo en sesio. Demandu ĝin ion.
- *Ĉiom nenio:* la nombroj venas kun Pro aŭ Max-plano, ne kun API-ŝlosilo.

**Forigu ĝin:** `vikix plugin remove ai-usage` remetias la statuslinion, kiun vi havis antaŭe (aŭ neniun).

## next-meeting: via venonta kunveno, kaj aliĝi al ĝi

Via venonta kunveno en la breto, kun kiom da tempo restas ĝis ĝia komenco; notifo kvin minutojn antaŭe; kaj ununura ŝlosilo por aliĝi al ĝi, kunveno en la Teams-retejo.

**Aldonu ĝin:** `vikix plugin add next-meeting`. Ĝi instaldas du malgrandajn Python-bibliotekojn por legi kalendarojn (ĝi unue demandos). Poste donu al ĝi viajn kalendarojn: la privata ligo de ĉiu, adreso, kiu permesas al la kromprogramo legi tiun kalendaron.

```sh
next-meeting add work      # asks for the link; what you paste isn't shown
next-meeting add home
next-meeting calendars     # your calendars, by label (never the secret part)
next-meeting forget home
```

Kie troviĝas la privata ligilo de ĉiu kalendaro:

- **Microsoft 365 (Outlook en la retejo):** Agordoj, Kalendaro, Kunhavitaj kalendaroj, Eldonu kalendaron; elektu la kalendaron kaj kiom da ĝi estos montrita, Eldonu, poste kopiu la **ICS**-ligilon.
- **Google Kalendaro:** la agordoj de la kalendaro, *Integru kalendaron*, la **sekreta adreso en iCal-formato**.
- **Todoist:** ĝia ligilo al la kalendaro-fonto, kie via plano ofertas unu.

**Privata ligilo estas la ŝlosilo al tiu kalendaro:** ĉiu, kiu havas ĝin, povas legi ĝin. La kromprogramo konservas ilin en dosiero, kiun nur vi povas legi kaj neniam elmontras ilin. Se unu el ili hazarde eliras, redifinu ĝin tie, kie vi ricevis ĝin.

**Uzu ĝin:**

- `Standup 14:30 en 12m` en la breto, por la venonta kunveno ene de kvar horoj; `now: Standup` dum ĝi okazas, en la koloro por emfazo.
- **Super+Alt+j**, aŭ klako: aliĝu al la nun okazanta kunveno, aŭ la venonta. Ligilo al Teams malfermiĝas en la reteja aplikaĵo de Teams (`vikix webapp add teams`), ligilo al Meet en la aplikaĵo de Meet, se vi havas ĝin, ĉio alia en via navigilo.
- **Super+Alt+c:** la venonta semajno, en listo; Eniru aliĝas al la kunveno, kiun vi elektas.
- `next-meeting list` en terminalo: la sama semajno.

**Kie troviĝas la aferoj:** la ligiloj en `~/.config/vikix/plugins/next-meeting/calendars` (600); la kalendaroj kiel lastfoje legitaj en `~/.cache/vikix/next-meeting/`; kion la breto montras en `~/.local/state/vikix/next-meeting`. Ĉiu kunveno, al kiu vi aliĝas, estas registro: `vikix records list next-meeting`.

**Kiam ĝi ne funkcias:**

- *Nenio en la breto:* neniu kunveno ene de la venontaj kvar horoj, aŭ ankoraŭ neniu kalendaro (`next-meeting calendars`). `next-meeting fetch` legas ilin ĉiujn nun kaj diras, kio iris tute malbone.
- *Microsoft 365 ne havas "Eldonu kalendaron":* via organizo malŝaltis la eldonon. Petu helpon de la IT-fako, aŭ uzu la retejan aplikaĵon de Outlook por tiu kalendaro dumtempe.
- *Kunveno ŝanĝiĝis kaj la breto ne montris ĝin:* kalendaroj estas legataj ĉiujn 5 minutojn, kaj Google povas preni tempon por ĝisdatigi la kopion de la ligilo.

**Forigu ĝin:** `vikix plugin remove next-meeting`. Viaj kalendaroligoj restas en la dosierujo de agordoj ĝis vi forigas ĝin.

## flights: serĉado de flugoj el linio

Tipe linion kiel `DXB LHR 12 Nov, back 20th` kaj vidu la flugojn, komence la plej malmultekostaj, kun la plej rapidaj markitaj. Eniru malfermas tiun serĉon en Google Flights, kie vi rezervas (tie aŭ en la retejo de la flugkompanio): la kromprogramo mem neniam rezervas ion. Ĝi ankaŭ povas observi itineron kaj sciigi al vi, kiam ĝi fariĝas pli malmultekosta.

**Aldonu ĝin:** `vikix plugin add flights`. Ĝi kreas Python-programon kun `fast-flights`, la biblioteko, kiu legas Google Flights (unu minuto, unuvoje). Poste agordu vian valuton kaj hejman flughavenon en `~/.config/vikix/plugins/flights/settings`:

```
currency = AED
home = DXB
```

Kun hejma flughaveno, `LHR 12 Nov` sufiĉas.

**Uzu ĝin:**

- **Super+Alt+f** demandas la celon, poste listigas la fluĝojn. Enklaku unu, kaj ĝi malfermos la serĉon en Google Flights; la lasta eniro observas la vojon.
- La celo: du flughavenoj per iliaj tri-leteraj kodoj, dato, kaj `back DATE` por revena vojo. Ankaŭ `business`, `premium`, `first`, `direct`, `2 adults`, `1 child`. Datumoj kiel vi skribus ilin: `12 Nov`, `Nov 12`, `2026-11-12`; `back 20th` por la sama monato.
- Observata vojo estas kontrolata ĉiuj 6 horoj. Kiam ĝia prezo malaltiĝas: notifo, kaj `flight cheaper` en la statusbara ĝis vi rigardas (klaku, aŭ Super+m, *Flights: la observataj, kiuj malpliĝis en prezo*).
- En terminalo:

```sh
flights "LHR JFK 3 Dec business"    # the list, in the terminal
flights watch "DXB LHR 12 Nov"      # watch a route
flights watching                    # what's watched, and the cheapest seen
flights unwatch 2                   # stop watching the second
```

**Kie troviĝas la datumoj:** la kontrolataj itineroj en `~/.config/vikix/plugins/flights/watched`; la viditaj prezoj en `~/.local/state/vikix/flights/`. Ĉiu serĉo kun ĝiaj rezultoj, kaj la prezo de ĉiu kontrolata itinero ĉe ĉiu kontrolo, estas registritaj: `vikix records search singapore`, `vikix records list flights --kind price`.

**Kiam ĝi ne funkcias:**

- *Neniuj flugoj, aŭ eraro, por itinero, kiu ja havas ilin:* `fast-flights` estas neoficiala, kaj ŝanĝo ĉe Google povas interrompi ĝin ĝis la biblioteko estos ĝisdatigita. Serĉu rekte ĉe Google Flights dumtempe.
- *Mankas rekta flugo:* la kromprogramo petas la rektajn flugojn aparte kaj aldonas ilin; se unu ankoraŭ mankas, `direct` en la linio petas nur tiujn.
- *Prezoj en la malĝusta valuto:* `currency =` en la agordoj.

**Forigi ĝin:** `vikix plugin remove flights` forigas ankaŭ ĝian Python-kodon. Viaj kontrolataj itineroj restas en la dosierujo de la agordoj.

## repos: kion viaj projektoj bezonas

Kiaj el viaj git-projektoj havas ne-almetitajn ŝanĝojn, ne-povitajn almetojn, almetojn en GitHub, kiuj ne estis alprenitaj, ne-povitajn etikedojn, aŭ restajn ŝarĝojn. La baro kalkas; unu klavo malfermas terminalon kun la detaloj kaj la komandoj, kiuj devas esti ekzekutitaj.

**Aldoni ĝin:** `vikix plugin add repos`. Ĝi kontrolas ĉiun projekton en `~/src`, kaj ankaŭ en `~/.emacs.d` kaj `~/.dotfiles`. Por ŝanĝi kiujn, vidu la agordojn sube.

**Uzi ĝin:**

- `git 2` en la baro: du projektoj bezonas ion. En la akcenta koloro, kiam io atendas esti movita aŭ alprenita.
- **Super+Alt+g**, aŭ klako: terminalo kun la stato de ĉiu projekto kaj la komandoj, kiuj faras tion, kio estas bezonata. La komandoj estas en la historio de la terminalo: premu **Supre**, por reaperigi ilin, kaj Enter por ekzekuti ilin.
- Super+m, *Projektoj: elektu unu*: la projektoj en listo; Enter ofertas pusi, alpreni, terminalon tie, aŭ Magit en Emacs.
- `repos fetch` nun petas al GitHub, kio estas nova (ĝi faras tion ĉiun 30 minutojn memstare).
- `repos push` puŝas ĉiun projekton, kiu bezonas tion, almetojn kaj etikedojn (`repos push esploro` nur tiun). Projekto, kiun alia projekto referencas, iras unue: Esploro kaj la kromprogramoj antaŭ Vikix, kies dosieroj nomas la almeton de ĉiu, kiun ĝi konstruas. Ĝi ne puŝos Vikix, dum ĝi referencas almeton, kiun GitHub ankoraŭ ne havas, ĉar ĉiu instalado, kiu estis ĝisdatigita, tiam malsukĉigus alpreni ĝin. Kiam GitHub progresis, ĝi unue alprenas tiujn almetojn kaj tiam puŝas denove.
- `repos pull` alprenas la novajn almetojn de GitHub por ĉiu projekto, kaj vi metas ilin sur ilin. Ĝi petas per HTTPS, do ne bezonas pasvorton.
- `repos ship` estas `repos push`, tiam `vikix update core`: la komputilo funkcias kun tio, kion vi puŝis. La paŝo post publikigo.
- `repos update` ĝisdatigas la tutan sistemon (`vikix update`: la pakaĵoj de Void, Vikix, viaj iloj).
- `repos` ankaŭ diras, kiam projekto estas post la almeto, kiun Vikix referencas (`2 past vikix's pin`): ĝi havas laboron, kiun Vikix ankoraŭ ne uzas.

Ĝi neniam puŝas, alprenas aŭ kunigas, krom se vi petas, kaj peti al GitHub neniam bezonas vian pasvorton de SSH: ĝi iras per HTTPS, per la eniro de `gh`, se vi havas unu.

**Agordoj** (`~/.config/vikix/plugins/repos/settings`):

```
roots = ~/src                       # folders whose projects it looks at
extra = ~/.emacs.d ~/.dotfiles      # single projects elsewhere
skip =                              # projects to leave out, by folder name
push = gpush {path}                 # the commands it suggests, if not git's own
pins = esploro:~/src/vikix/bin/vikix-esploro vikix-plugins:~/src/vikix/bin/vikix-plugin
                                    # PROJECT:FILE, the file holding NAME_COMMIT=<sha>
```

**Kiam ĝi ne funkcias:**

- *Privata projekto neniam montras aldonojn por "pull":* GitHub bezonas `gh auth login` por respondi pri privata projekto.
- *Malkorrekta terminalo malfermiĝas:* ĝi malfermas la terminalon de Vikix (Super+Return); `terminal = kitty` en la agordoj indikas alian.

**Forigu ĝin:** `vikix plugin remove repos`.

## inbox: notoj de ĉie

Premante klavon super ĉio, kion vi faras, malfermiĝas eta fenestro; tio, kion vi skribas aŭ diras, finiĝas en via Org-inbox en Dropbox, kiun viaj telefonoj ankaŭ vidas. Poste, per unu klavo, la inbox ordiĝas en viajn notdosierojn. Ĝi havas sian propran gvidilon: [Viaj notoj](notes.md).

**Aldonu ĝin:** `vikix plugin add inbox`. Ĝi bezonas Emacs (`vikix add emacs`) por la fenestro; sen Emacs, la fenestro estas ununura linia "rofi"-peto.

**Uzu ĝin:**

- **Super+Alt+i:** la fenestro. La unua linio estas la titolo de la noto. **Super+F9** permesas paroli en ĝi. **C-c C-c** konservas la noton, **C-c C-k** forigas ĝin.
- **Super+Alt+Shift+i:** la sama, kun tio, kion vi elektis, citita en ĝi.
- **Super+Alt+Shift+s:** ordigu la inbox. Modelo sugestas, kie ĉiu noto iras kaj kiuj estas la farotaj aferoj; vi ŝanĝas tion, kion vi volas (`3` por movi la noton 3, `t 3` por fari ĝin farota aŭ ne, `d 3` por forigi), Enter faras ĝin. `inbox sort --undo` remetigas ĉion.
- `inbox add "voku la bankon"` el terminalo.
- `notes-sync` (aŭ Super+m, *Notoj: sinkronigu kun Dropbox*): viaj notoj nun estas en Dropbox. Ĝi lanĉas Dropbox se ĝi ne funkcias, prenas la notdosierojn reen en la sinkronigon de ĉi tiu laptopo, se selektiva sinkronigo forlasis ilin, kaj atendas ĝis Dropbox diras, ke ĝi estas ĝisdatigita.

**Kie la aferoj estas:** la notoj en `~/Dropbox/notes/`; la inbox estas `inbox.org` (alia dosiero: `file = ~/notes/inbox.org` en `~/.config/vikix/plugins/inbox/settings`); la kopioj, kiujn ĉiu ordigado konservas, estas en `~/.local/state/vikix/inbox/sorts/`.

**Kiam ĝi ne funkcias:**

- *Du fenestroj malfermiĝas, de Emacs kaj de rofi:* la noton ne povis aldoni en Emacs (pli malnova kromprogramo kun Emacs, kiu malfermas dosierojn nur por legi). `vikix update` alportas la solvon.
- *Neniu paĝadreso en noto de la navigilo:* Firefox konservas siajn malfermajn langetojn ĉiun 15 sekundojn, do paĝo malfermata juste antaŭe eble ankoraŭ ne estas konata; retejaj programoj (Chromium) donas nur sian titolon.
- *Farotaj aferoj ne atingas Todoist:* `vikix ai key set todoist` unufoje, kun la tokeno el la Agordoj, Integrigoj, Programisto de Todoist.

**Forigu ĝin:** `vikix plugin remove inbox`. Viaj notoj restas tie, kie ili estas.
