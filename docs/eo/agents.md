# Agentoj en agado

Unu agento estas terminalo, kun kiu vi komunikas. Tri aŭ kvar samtempe estas malgranda oficejo: ĉiu bezonas lokon por labori, vi bezonas vidi, kiu kion faras, kaj kiam du atingas la saman aĵon, iu devas diri tion. Ĉi tiu paĝo montras, kiel tiu oficejo funkcias en Vikix: lanĉante agenton, vidante ilin ĉiujn, donante al ĉiu laborpostenon, kaj la reguloj, kiuj validas kiam ili renkontiĝas. [Laborante kun AI](ai.md) enhavas la reston: kiuj estas la agentoj, ŝlosiloj kaj modeloj, la labortablo kiel iloj.

Por esplorado pri Grok Bot kaj nublaboro, uzu [paskon de Grok Bot](ai.md#transdonoj-de-grok-bot): apartan lokalan vicon de resumoj kaj respondoj por revizii. Pasko de Grok ne lanĉas oficejan laboranton; vi povas transdoni ĝiajn reviziitajn rezultojn al laboranto ĉi tie.

Tri kutimoj portas la tutan paĝon:

1. **Lanĉu agentojn kun Vikix**, `Super+a` aŭ `vikix agent`, neniam nur `claude`: tiel ili ricevas kopion de viaj dosieroj, la Vikix-kapablecon, neniajn API-ŝlosilojn, kaj la regulojn.
2. **Unu laborposteno por ĉiu laboro**: `vikix agents desk PROJECT TOPIC` kreas la lokon, `vikix agents worker TOPIC "la tasko"` metas agenton labori tie. Sen laborposteno, sen laboro: agento forigita de laborposteno estas malakceptata kiam ĝi atingas dosierojn de projekto, kaj oni diras al ĝi, kiel sidiĝi.
3. **`vikix agents` kiam vi perdas la kontrolon.**

## Unu agento

`Super+a` petas *Agento ĉi tie* aŭ *Agento ĉe nova laborposteno*, poste kiu agento; la unua, kun via (Claude Code, krom se vi elektis alian: `vikix agent --default codex`), malfermas terminalon kun ĝi en via hema dosierujo (`vikix agents here`; Codex tie ricevas la "doman" reĝimon, kiel ĉe laborposteno: [Reĝimoj](#reĝimoj-kiel-multe-codex-laboristo-estas-libera)). Antaŭ ol la agento lanĉiĝas, Vikix faras kopion de viaj dosieroj, do poste:

```sh
vikix changes      # what the agent changed in your config, notes, dotfiles
vikix undo         # put it all back
```

La agento konas la labortablon de la Vikix-kapableco: demandu ĝin per vortoj. *Malfermu Firefox en labloko 2. Kial ĉi tiu fenestro aperis? Agordu la temon al vikix-light.* Ĝi proponas regulojn anstataŭ skribi ilin, demandas antaŭ ol redakti, kaj neniam akiras viajn API-ŝlosilojn aŭ vian SSH-agenton (vidu *Kion la agento ne akiras* en [Laboro kun AI](ai.md)).

Dua `Super+a`, *Agento ĉi tie*, estas dua agento, kaj tiel plu. Nenio malhelpas vin; la resto de ĉi tiu paĝo diras, kion fari, kiam vi havas plurajn.

## Vidi ĉiujn

`vikix agents help` estas la mapo de la komandoj, unu linio por ĉiu, en la ordo de ĉi tiu paĝo: vidi ilin, labortablo por ĉiu, laboristoj, la propraj de la agento, la reguloj de la domo. `vikix agents help desk` estas unu plena komando, same kiel `vikix agents desk -h`; `man vikix-agents` enhavas ĉion.

```
$ vikix agents
3 agents, 1 waiting for you:
  claude   ~/src/vikix-wifi (wifi, 2 uncommitted)      workspace 4   35 min      working
           wifi · Claude: ◑ Wi-Fi picker
  claude   ~/src/novel-chapter-3 (chapter-3, nothing uncommitted)  workspace 5   2 h 10 min  waits for your yes
           May I run the spell check over the whole book?
  codex    ~                                           workspace 2   12 min      running
```

Linio por ĉiu agento: kiu ĝi estas; la dosierujo, en kiu ĝi laboras, kun sia branĉo kaj kiom da nekomenigitaj dosieroj estas tie; ĝia labra spaco; kiom longe ĝi funkcias; kaj kion ĝi faras. *Laboras* kaj *estas ĉe sia komanda linio* estas prenita de la markilo, kiun Claude Code tenas ĉe la komenco de la titolo de sia fenestro, aŭ, por agento kies titolo ne diras ion (Codex ne skribas markilon), de la oficeja ĵurnalo, kiun ĝiaj hakoj skribas: ago komenciĝis, redakto aŭ komando en la lasta minuto estas *laboras (komando 12 sekundoj antaŭe)*, paŭzo permesita sen io post ĝi *estas ĉe sia komanda linio* ([Kio tenas la regulojn](#kio-tenas-la-regulojn-por-ĉiu-agento)); *atendas vian jes*, *demandis al vi ion* kaj *finis sian agon* de la kromprogramo, kiu atendas la agenton, se vi havas ĝin ([Kromprogramoj](plugins.md)); sub tiu, kiu atendas, estas tio, kion ĝi demandis, sub la ceteraj, la titolo, kiun la agento skribas en sia komanda linio, post la nomo, kiun ĝia fenestro havas sur la labortablo, kiam ĝi estas sur labortablo (`wifi · Claude`: vidu [Labortablo por ĉiu](#labortablo-por-ĉiu)). Agento, kies komanda linio estas tenata de eldono aŭ de testoj, diras tion: *atendas eldonon* (ĝia eldono estas en la vico de `.claude/release`, post alia; sub ĝi, ekde kiam kaj post kio), *eldonas* (kiu paŝo estas la eldono), *atendas testan tempon* (ĝiaj testoj atendas unu el la tempoj de la maŝino `tests/run.sh`, aliaj testoj); aŭ *testas*. Tiu, kies labortablo malaperis dum ĝi funkcias, diras, kio restas: *ĝia labortablo malaperis; la ĉefa branĉo havas komenigojn por puŝi: gup*, tiam *ĝia labortablo malaperis kaj la ĉefa branĉo estas puŝita: fermu la komandan linion* (`--json` havas ĝin kiel `attention`: `asks`, `gup`, `close` aŭ malplena; la koloroj de la labortablo koloras la komandan linion laŭ la sama maniero, vidu [Labortablo por ĉiu](#labortablo-por-ĉiu)). Agento sen propra fenestro (unu en Emacs, unu en teksta komanda linio) estas lasta, kun la loko, kie ĝi funkcias. Programo de provizanto, kiu ne estas sesio, ne estas listigita: unu funkcias kiel servilo (`codex app-server`, la daemonon runit tenas; `claude mcp serve`; `opencode serve`), aŭ unu sen kontrola komanda linio kaj sen fenestro ĉi tie. Sesio en komanda linio, en tmux, trans ssh aŭ en Emacs-a komanda linio havas komandan linion; adaptilo nur sur kanaloj (ACP) ne havas.

La sama listo sur la labortablo: `Super+m` → *AI* → *Agentoj: kiu funkcias, kaj iru al unu*. Elektu linion kaj vi estas en la labra spaco de tiu agento, ĉe sia fenestro. `vikix agents --json` estas la listo por skripto, kaj la MCP-ilo `agents` donas ĝin al agento, do unu agento povas vidi la aliajn.

Nenio ĉi tie haltas, sendas signalon aŭ enigas en agenton: la listo nur legas tion, kio estas tie.

## Labortablo por ĉiu

Agento komencita per `Super+a`, *Agento ĉi tie*, sidas en via hejma dosierujo, kaj laboras ĉie, kie vi sendas ĝin. Du el ili sur unu projekto tiam redaktas unu labran kopion: git ne povas diri, kies ŝanĝo estas de kiu, la duon-skribita redakto de unu rompas la testojn de la alia, kaj neniu povas komenigi ĝin senprobleme. Labortablo donas al ĉiu laborpeco sian propran kopion, kaj laboranto estas agento, kiun oni metis labori en unu:

```sh
vikix agents desk vikix wifi-fix
a desk: in ~/src/vikix-wifi-fix, a new worktree on the branch wifi-fix. Nobody sits at it: vikix agents worker wifi-fix "the task" starts a worker there
vikix agents worker wifi-fix "the Wi-Fi picker should scan first"
a worker at ~/src/vikix-wifi-fix, the task its first prompt, on workspace 4
```

Kio okazis: oni kreis apartan `git`-laborareon de `~/src/vikix` apud `~/src/vikix-wifi-fix` sur nova branĉo `wifi-fix`, kun sia propra notlibro kaj sen iu ajn uzanto; poste oni prenis la unuan malplenan laborareon (4) (kiam ĉiuj naŭ havas fenestrojn, oni kreas novan nomatan `wifi-fix`, al kiu oni alvenas per `Super+0` kaj lasas denove, kiam ĝi estas malplena), kaj malfermis terminalon en la laborareo kun via asistanto, kiu komencas la taskon, same kiel `Super+a`. `Super+4` nun estas tiu asistanto. Ĝi faras la ŝanĝojn en sia branĉo, en sia dosierujo; `~/src/vikix` kaj ĉiuj aliaj laborareoj restas tiel, kiel ili estas. `vikix agents desk vikix wifi-fix --task "..."` faras ambaŭ samtempe.

Laborareo estas la loko: la laborareo, ĝia branĉo, ĝia notlibro. Asistanto estas unu asistanto pri unu tasko tie, kaj laborareo prenas siajn asistantojn unu post la alia, sur la sama branĉo: kiam la unua finis (aŭ vi forigis ĝin), `vikix agents worker wifi-fix "now the password dialog"` komencas la sekvan, kaj la notlibro movas la taskon antaŭen, kun kiel ĝi finiĝis kaj la kompleta transdono de la asistanto (stato, konto, sekva paŝo kaj taksado), al la historio de la laborareo, kiun `vikix agents handoff wifi-fix` montras sub *Asistantoj antaŭ ĉi tiu*; tio, kio restas en la laborareo, estas en la aktuala notlibro por la sekva asistanto, kies unua mesaĝo portas ĝin: la akceptaj kriterioj kun iliaj indikoj, la decidoj, la difektoj kaj la trovitaj problemoj (la unua tago kun du provizantoj perdis kvar problemojn kaj tri difektojn ĉe nova asistanto, 2026-10-11). Du samtempe estas rifuzitaj: en unu laborareo `git` ne povas diri, kies dosieroj estas kies, do la reguloj de la domo ne povus diri tion nek. `vikix agents tell` parolas al la asistanto, kiu estas tie, `dismiss` finas ĝin. `vikix agents worker wifi-fix` sen tasko estas sesio en la laborareo, asistanto, kun kiu oni povas paroli, la notlibro restas tiel, kiel ĝi estas.

La terminalo de la asistanto estas nomata laŭ sia laborareo sur la ekranreĝo: `wifi-fix · Claude`, la temo kaj la provizanto, en la titolo, la listo de fenestroj (`Super+g`), la superrigardo kaj la paletro, de la momento, kiam la asistanto estas en la laborareo (ekigita tie, sidigita per `vikix agents sit`, aŭ prenita denove per `resume`) ĝis ĝi foriras. Du el la sama provizanto en laborareo estas `wifi-fix · Claude 1` kaj `wifi-fix · Claude 2`, ĉiu konservas sian numeron dum ĝi funkcias; alia provizanto en la sama laborareo estas `wifi-fix · Codex`. La titolo, kiun la asistanto mem skribas (la ŝanĝa marko de Claude Code, kiu estas kiel *labori* kaj *esti ĉe sia mesaĝo* estas interpretata), estas konservata aparte, do ĉio, kion ĝi faras al sia titolo, ne ŝanĝas la nomon, kaj nenio perdiĝas: `vikix agents` montras ambaŭ. Terminalo, kies asistanto foriris, estas denove simpla, aŭ nomata laŭ la sekva asistanto, kiu funkcios en ĝi, ene de duonminuto; terminalo sen asistanto en laborareo, kaj nomo, kiun vi donis al fenestro per la komando `title` de StumpWM, estas lasitaj tiel, kiel ili estas.

**Tri koloroj diras, kion terminalo bezonas de vi.** En la fenestrolisto de la breto kaj en la titolo de la fenestro, la terminalo de asistanto prenas koloron dum io estas via farenda, kaj estas simpla dum la resto de la tempo. Dum la asistanto *atendas vin* (permeso, demando, ĝiaj lastaj vortoj petas ion: tion, kion la kromtavola asistanto notigas), ĝi havas la unuan koloron. Kiam ĝia laborareo malaperis dum la asistanto ankoraŭ sidas en la terminalo (rilato forigis la laborareon, aŭ vi fermis la laborareon) kaj la propra branĉo de la projekto havas ŝanĝojn, kiujn ĝia deveno ne havas, ĝi havas la duan: la rilato atendas `gup`. Kiam tio ankaŭ estas sendita, la tria: nenio restas krom fermi la terminalon. La nomo restas en tia terminalo (`wifi-fix · Claude`), do vi scias, kio ĝi estis. La koloroj estas la temo, do hela temo kaj malluma temo ĉiu havas sian propran: `agent_asks`, `agent_released` kaj `agent_pushed` en la dosiero de la temo, aŭ la flavo, verdo kaj ciano de la terminalo, kie temo ne nomas ilin (vidu [Faru ĝin via](customize.md#la-aspekto)). `vikix agents` diras la samon per vortoj (*ĝia laborareo malaperis; ĉefbranĉo havas ŝanĝojn por sendi: gup*; *ĝia laborareo malaperis kaj ĉefbranĉo estas sendita: fermu la terminalon*), kaj la Oficejo desegnas la laborareon en la sama koloro. Ĉu la branĉo estas sendita, oni legas de la propraj ref-dosieroj de la deponejo, do puŝo de ie ajn (via `gup`, `git push` en ŝelo) estas vidata ene de sekundoj; nenio ĉi tie puŝas aŭ fermas ion.

La projekto estas iu el `vikix project list`, laŭ ajna parto de ĝia nomo (`vikix`, `novel`, `nov`). La temo estas unu aŭ du vortoj por la laboro: ĝi fariĝas la fino de la dosierujo kaj la nomo de la branĉo, do elektu ian, kiu diras, kion la asistanto faras (`wifi-fix`, `chapter-3`, `typos`), ne kiu estas ĝi (`agent-2`). Temo, kiu ne donas nomon por branĉo, estas rifuzita.

`Super+a`, *Asistanto en nova laborareo*, aŭ `Super+Alt+d` tiam `n` (la ŝlosiloj de la laborareo: `Super+Alt+d` malfermas malgrandan karton de ili, `n` nova laborareo, `w` asistanto en unu, `r` prenu unu denove, `c` fermu unu, `h` ĝia transdono, `o` la Oficejo, `t` testu laborareon, `p` paŭzu ĝian asistanton aŭ lasu ĝin iri, `i` noti por ĝi, `x` forigu ĝin), aŭ `Super+m` → *AI* → *Asistantoj: nova laborareo, kun asistanto, kiam vi donas al ĝi taskon*, petas la projekton en menuo, tiam la temon, tiam la taskon. Eniri sen io estas la laborareo sola. Tasko, kiu estas tajpita, pasas al la demandoj de la asistanto: kiu asistanto, via unue, la ceteraj kiel `vikix agent --list` havas ilin (unu, kiu ankoraŭ ne estas instalita, estas proponita kun ĝia instalilo en la terminalo), kaj tiuj, kiuj povas funkcii sur modelo en ĉi tiu laptopo; tiam ĉu la asistanto rajtas sendi, kiel vi. Ne estas la kutima: la asistanto faras la ŝanĝojn, vi sendas. Jes sendas vian SSH-asistanton kun ĝi (`vikix agent` konservas ĝin aliflanke: post via unua puŝo de la tago, ĝi tenas vian malŝlositan ŝlosilon), do `git push` funkcias en tiu laborareo. La Oficejo havas la saman kiel formularo, **Nova laborareo…**, kun la elektoj de la asistanto kiel ujoj por marki (vidu [La Oficejo](#la-oficejo)). Aliaj formularoj:

```sh
vikix agents desk notes                       # a project that is no repository: a desk is its own folder
vikix agents worker ~/src/notes "sort them"   # a worker there, on a workspace to itself
vikix agents worker typos "..." --here        # in this terminal, no new workspace
vikix agents worker typos "..." --use codex
vikix agents worker typos "..." --use antigravity
vikix agents worker typos "..." --use aider --local   # on a model on this laptop
vikix agents worker typos "..." --push                # it may push as you (your SSH agent goes with it)
vikix agents worker typos "..." --no-tests            # its tests don't run by themselves when it hands in
vikix agents desk novel typos --task "..." --use codex   # the desk and the worker in one go, with the worker's words
```

Skribotablo, kiu jam ekzistas, estas uzata denove, ĝi neniam estas farita dufoje: la dua `vikix agents desk vikix wifi-fix` diras tion, kaj kiu estas tie. Projekto ene de kolekto (`books/novel`) ricevas sian propran dosierujon ene de la labradarburo de la kolekto, `~/src/books-typos/novel`. Projekto, kiu ne estas git-deponejo, ne havas labradarburojn: ĝia skribotablo estas la dosierujo mem, kaj temo ne estas bezonata; nomu la dosierujon al `worker`. Deponejo sen temo estas malakceptata: ĝia propra dosierujo estas nur por kunfandiĝo, kaj neniu agento laboras tie.

### Neniu skribotablo, neniu laboro

Skribotabloj helpas nur se agentoj uzas ilin. Tial la regulo, kiun Claude Code aplikas antaŭ ĉiu redaktado: **agento ŝanĝas projekton nur de skribotablo, kaj neniam en la propra dosierujo de la projekto.** Agento komencas per `Super+a`, *Agento ĉi tie*, sidas en via hejma dosierujo; la momento, kiam ĝi atingas dosieron en `~/src/vikix` aŭ `~/src/novel`, la redaktado estas malakceptata, kaj ĝi legas kial:

> Vikix-oficejo: ~/src/vikix/bin/vikix-wifi estas en la projekto vikix, kaj vi ne estas ĉe skribotablo. Agento laboras sur deponejo nur de sia propra skribotablo, labradarburo de ĝi. Prenu unu de ĉi tie: faru `vikix agents sit vikix TEMO` (vorto aŭ du por la laboro; ĝi kreas ~/src/vikix-TEMO sur la branĉo TEMO, aŭ prenas la ekzistantan, kaj sidas vin tie), tiam laboru en tiu dosierujo kaj faru aliĝon tie. La propra dosierujo de la projekto, ~/src/vikix, estas nur por kunfandiĝo.

La agento sidas memstare, sen restartigo:

```
$ vikix agents sit vikix wifi-fix
claude 48213 is seated at ~/src/vikix-wifi-fix: a new worktree on the branch wifi-fix. Work there (cd ~/src/vikix-wifi-fix) and commit there, on the branch wifi-fix; the house rules take that folder as yours now, and vikix agents shows you at it.
```

De tiam la labortablo apartenas al tiu agento: ĝiaj modifoj tie aprobas, `vikix agents` listigas ĝin ĉe `~/src/vikix-wifi-fix (wifi-fix, 2 neakceptitaj)` kun la branĉo kaj kio atendas tie, kaj `vikix agents close` rifuzas la labortablon dum ĝi estas uzata. Agento, kiu jam havas labrotabelon, kreita mane aŭ per la propra subteno por labrotabeloj de Claude Code, sidas ĉe ĝi per `vikix agents sit` kaj nenio pli, kaj ĝi estas lanĉata de ene de ĝi; agento, kiun vi lanĉis per `vikix agents worker`, estas ĉe unu el ili de la komenco. Projekto, kiu ne estas deponejo, ne havas labortabelojn kaj nenian regulon: la agento laboras en sia dosierujo.

Du pliaj rifuzoj. La propra dosierujo de la projekto estas rifuzata de ĉiu labortablo, nomante la labortablon de la agento (*~/src/vikix estas la propra dosierujo de la projekto, kiu estas nur por kunfandado: neniu agento modifas ĝin. Via labortablo estas ~/src/vikix-wifi-fix: faru la ŝanĝon tie*). Kaj komanda linio estas submetata al la regulo, kiam ĝi skribus tien (`sed -i`, `>` en dosieron, `mv`, `git commit`, `git rebase` kaj simile): la hakilo legas la komandon, trovas la lokojn, kiujn ĝi nomas, kaj rifuzas ĝin laŭ la sama maniero; komando, kiu nur legas (`cat`, `grep`, `git log`, `git worktree list`), aprobas. La regulo validas por ĉiu projekto, kiun `vikix project list` konas, kiu estas git-deponejo; deponejo, kiu ne estas projekto (`~/.dotfiles`), ne estas regulata. Ĉiu rifuzo estas stokata en la registra datumbazo (`vikix records list office --kind refused`).

La listigo montras, kiu ankoraŭ ne sidas ie:

```
  claude   ~ (no desk)                                workspace 1   1 d        at its prompt
  claude   ~/src/vikix-wifi-fix (wifi-fix, 2 uncommitted)   workspace 4   35 min     working
```

### Provado de laboro de programo rekte sur la labortablo

La laboro de programo atingas la aktivan labortablon nur kiam ĝi estas publikigita, kaj publikiĝo estas versia numero. Iteracii dek fojojn antaŭ unu estas la kutima situacio, do ekzistas maniero por provi la laboron de programo rekte sur la labortablo, kiel ĝi estas:

```
$ vikix try agent-work
:: the desktop takes ~/src/vikix-agent-work: agent-work at 3e23404, not main (vikix try off, or vikix update core, puts main back)
:: stage 10-packages
...
:: StumpWM reloaded: the new keys, bar and menu are in use
!! the desktop runs ~/src/vikix-agent-work (agent-work at 3e23404, since 2026-10-06 21:10; vikix try), not main: vikix update core (gup) puts it back on main
```

La instalita versio, `~/vikix`, estas metita ĉe la lasta versio de la labortablo anstataŭ ĉe la ĉefa versio, kaj la paŝoj de la ĉefaj ĝisdatigoj estas farataj kiel post `gup`: novaj pakoj en la listoj, servoj, ligoj al la konfiguraj dosieroj, migradoj, StumpWM estas refreŝigita. Nombru la labortablon laŭ ĝia temo, ĝia branĉo aŭ ĝia dosierujo, aŭ faru `vikix try` sen ajna enhavo el la labortablo. La agente faras la versiojn, vi provas, vi rigardas, vi diras kio estas erare, ĝi faras novajn versiojn, vi provas denove. `vikix try status` diras, kion la labortablo faras, kaj `vikix agents` diras tion en sia unua linio.

Tri aferoj, kiujn vi devas scii. Ĝi bezonas versiojn: dosieroj, kiuj ne estas versietaj en la labortablo, estas rifuzitaj, kaj la mesaĝo diras tion. Unu labortablo je unu fojo: la sekva `vikix try` anstataŭigas la antaŭan, kaj diras ĝin. Kaj provo neniam estas konservita post ĝisdatigo: `gup` aŭ `vikix update core` remetas `~/vikix` al la ĉefa versio antaŭ ol ĝi estas elŝutita, kaj `vikix try off` faras tion tuj, kun la paŝoj, kiam vi volas, ke la eldonita labortablo estu rekreita sen elŝutado. La propra dosierujo de la projekto estas rifuzita, kiel ĉie.

### Tago kun du agentoj en Vikix

```sh
vikix agents desk vikix wifi-fix --task "the Wi-Fi picker should scan first"   # workspace 4
vikix agents desk vikix docs-pass --task "read docs/ for anything stale"        # workspace 5
```

Ĉiu komencas sian taskon en sia propra labora spaco. Ĉiu laboras en sia propra laborarbo, kaj kiam ĝi finas, ĝi finas per la propra eldon-paŝo de la projekto (por Vikix, `.claude/release wifi-fix "..."`), kiu kunigas la branĉon kaj forigas la laborarbon kaj la branĉon: la labora tablo "purigas" sin. Ĉiuj restantaj procezoj en tiu dosierujo ricevas mesaĝon de la sekva `gup` aŭ `vikix update core` (*la dosierujo, de kie ĉi tio komenciĝis, ne plu ekzistas: la procezo estas lanĉata de /home/you*), kaj tiel la procezo daŭras. `vikix agents` montras dumtempe `~/src/vikix-wifi-fix (wifi-fix, 3 ne-aligitaj)` kaj `~/src/vikix-docs-pass (docs-pass, 1 ne-aligita)`, do vi povas tuj vidi, kiu havas kion.

### Libro

```sh
vikix agents desk novel chapter-3 --task "draft chapter three from the outline"
a desk, and a worker at it: in ~/src/novel-chapter-3, a new worktree on the branch chapter-3, the task its first prompt, on workspace 5
```

La agenteo skribas kaj almetas la ĉapitron `chapter-3`. Se ĝi plaĉas al vi:

```sh
cd ~/src/novel && git merge chapter-3     # the work comes in
vikix agents close chapter-3              # the desk goes
the desk is closed: ~/src/novel-chapter-3 removed, the branch chapter-3 deleted
```

Aŭ diru al la agento: *kunigu vian branĉon en la ĉefa branĉo*; la funkcio diras al ĝi kiel, kaj ĝi diras al vi, kiam la laborposteno povas esti forigita.

### Fermado de laborposteno

`vikix agents close` forigas laborpostenon: ĝia laborarbo estas forigita, kaj ĝia branĉo estas forigita post kiam la laboro estas finita. Nomu la laborpostenon per ĝia temo, ĝia branĉo, ĝia dosierujo, aŭ kiel `PROJECTO TEMO`; se nenio estas nomita, tiam `Super+Alt+d` poste `c`, aŭ `Super+m` → *AI* → *Agentoj: fermu laborpostenon*, petas, kiun, kaj en terminalo sen grafika interfaco ĝi listigas ilin:

```sh
vikix agents close
The desks:
  ~/src/novel-chapter-3  (branch chapter-3, in; nothing uncommitted)
  ~/src/vikix-wifi-fix  (branch wifi-fix, not in main yet; 3 uncommitted; at work: claude 48213)
```

Ĝi rifuzas dum agento ankoraŭ laboras tie (*claude 48213 ankoraŭ laboras en ~/src/vikix-wifi-fix: lasu ĝin fini, aŭ fermu ĝian terminalon*) kaj dum dosieroj atendas sen esti konfirmitaj (*3 dosieroj ne konfirmitaj: unue konfirmu ilin tie, aŭ --force forigas ilin*). Konservatas branĉo, kiu ankoraŭ ne estas kunigita, kaj la mesaĝo diras tion: kunigu ĝin, poste `git branch -d` en la projekto, aŭ --force, kiu forigas la branĉon kaj ĝian laboron. La laborloko, kiun la "skatolo" havis, estas simple denove malplena. Kiam "skatolo" estas fermita, la agento diras al vi tion en sia lasta mesaĝo: ke la "skatolo" ne plu ekzistas, kiu branĉo estis kunigita aŭ konservita, kaj kio restas por vi fari (puŝi, aŭ provi ĝin sur la komputila labortablo).

### La transdono: kion la "skatolo" memoras

"Skatolo" daŭras pli longe ol la agento, kiu laboras sur ĝi. Ĉiu konservas malgrandan registron (`~/.local/state/vikix/office/desks/`, unu dosiero por "skatolo", nomita laŭ la deponejo kaj la laborarbo, neniam laŭ proceso), kaj `vikix agents handoff` montras ĝin:

```
$ vikix agents handoff wifi-fix
Desk ~/src/vikix-wifi-fix (branch wifi-fix), project vikix  [3f9a1c2b7d4e]
Task (user, 2 h ago): the Wi-Fi picker should scan first, then show the list
Status: review (claude 48213, 20 min ago)
Estimate (claude 48213, 1 h ago): 40 min, if the picker needs no new test; finished in 45 min against 40 min, 5 min over
Done and decided (claude 48213, 20 min ago):
  scan before the list in bin/vikix-wifi; kept the old order under --no-scan
Left to do, next (claude 48213, 20 min ago):
  Vid tries it on the laptop; then release
Checks:
  passed  tests/run.sh wifi  (claude 48213, 25 min ago, on 7c1e0f2, clean tree)  fresh
Now: wifi-fix at 7c1e0f2, nothing uncommitted
Sessions: claude 0f1e2d3c-… (2 h ago)
At the desk now: claude 48213
  claude 48213: pre-edit and pre-shell hooks (vikix agents touch): 14 edits proposed through them
  no filesystem enforcement by Vikix: a worktree keeps copies apart, it is no sandbox
```

Tri specoj de tasko, apartigitaj kaj ĉiu kun propra identigilo. La **tasko** estas via, laŭ viaj vortoj: `vikix agents worker wifi-fix "..."` agas, kiam la laboristo komencas, kaj donas ĝin al la agento kiel ĝia unua instrukcio (la tasko de la laboristo antaŭe estas enmetita en la historion de la sistemo, kune kun la rezulto), tiel la sistemo komencas labori tuj (Claude Code, Codex, OpenCode, Gemini CLI kaj Antigravity CLI uzas tion; Aider ne uzas, kaj ricevas instrukcion legi la registron); aŭ `vikix agents handoff --task "..."` agas poste; ĉiu tasko havas propran registron, kun identigilo kaj lanĉnumero (*La laboro: taskoj kaj ilia historio*, sube). La **transdono** estas de la agento: stato (laboranta, atendanta, revizianta, finita, aŭ provizore haltigita: forlasita, por esti reaktivigita poste), estimo, kio ŝanĝiĝis kaj decidiĝis, kio restas kaj la sekva ago. La **estimo** estas, kiom da tempo la laboro daŭros de la momento de la enigo, supoze ke ne aperas gravaj problemoj (`--estimate "40 min, se la selektilo ne bezonas novan teston"`: unue daŭro, en minutoj, horoj aŭ tagoj, kaj poste, post komo, la supozoj); agento, kiu komencis kun tasko, estas petata pri nova, kiel baldaŭ kiel ĝi konas la tipon de la laboro. La registro kaj `vikix agents` kalkas ĝin malantaŭen (*28 min restas el 40 min*, *10 min preter la 40 min*), kaj kiam la stato estas finita, ili diras, kiel ĝi iris (*finita en 45 min anstataŭ 40 min, 5 min preter*). La horloĝo estas de la sistemo, do la tempo pasigita atendanta vi estas kalkata, kiel estus por homo; estimo, kiun oni denove enigas, reaktivigas ĝin. Kion **Vikix legas mem** estas la resto: la aldonitaj kaj ne-aldonitaj dosieroj ĉe ĉiu enigo, kaj por kontrolo, la aldonita versio kaj ĉu la arbo estis ŝanĝita tiam. Kontrolo estas markita kiel *malnova* en la momento, kiam la kodo diferencas de tio, sur kio ĝi funkciis, per alia aldonita versio aŭ aliaj ne-aldonitaj ŝanĝoj, do malnova "verda" neniam estas akceptata kiel nova. La sesioj estas la identigiloj de la konversacioj de la provizantoj kaj nenio pli: neniu transkripcio estas kopiata, kaj linio, kiu ŝajnas esti ŝlosilo aŭ tokeno, estas tuj malakceptata.

La agento skribas per la sama komando, aŭ per la MCP-iloj `handoff` kaj `handoff_update`, laŭ kiu agento temas:

```sh
vikix agents handoff --status working --estimate "40 min, if the picker needs no new test"
vikix agents handoff --status review --summary "..." --next "..."
vikix agents handoff check "tests/run.sh wifi" --ok
vikix agents handoff session codex 01a111e5-…      # a conversation that can be resumed here
echo '{"status":"waiting","next":"needs the laptop"}' | vikix agents handoff --from -
vikix agents park wifi-fix --next "once the new laptop is here"   # kept aside: blocked on parked in the Office, not needing you
```

`vikix agents park [DESK]` estas la stato *parkita* laŭ sia propra nomo, via aŭ de la agento: la laborposteno estas forigita, por esti reaktivigita poste, kaj la sistemo listigas ĝian taskon sub **Blokita** (*blokita ĉe parkita*), tamen la agento forlasis ĝin (demando, kiun ĝi petis kun stato *atendas*, alie tenus ĝin sub *Bezonas atenton*); `--next "..."` anstataŭigas la sekvan paŝon per tio, kion fari kiam ĝi estos reaktivigita. Nenio estas haltigita per ĝi: agento, kiu ankoraŭ laboras ĉe la laborposteno, daŭras, kaj la laborposteno estas konsiderata aktiva ĝis ĝi estos forigita (`vikix agents pause` tenas unu); laboranto, kiu komencis labori tie, aŭ ajna skribita stato, reaktivigas ĝin.

Kun iu el tiuj agordoj, `handoff` skribas anstataŭ montri (`vikix agents handoff set` diras la saman, nur unu vorto pli longa); de ekstere de la laborposteno, unue nomu ĝin, kiel por `close`: `vikix agents handoff wifi-fix --task "..."`.

**La transdono** (ekde versio 0.72.34) estas la resto de la registrado, la kampoj, kiujn laboranto plenigas dum la laboro, por ke tiu, kiu prenas la laborpostenon poste, vi, recenzanto aŭ alia provizanto, komencu de faktoj, anstataŭ de konversacio. Ĉiu linio estas subskribita kiel la aliaj, ĉiu listo konservas kvindek, linio estas interrompita je mil karakteroj, kaj linio, kiu ŝajnas esti ŝlosilo, estas rifuzata.

```
Acceptance (user, 2 h ago): 2 of 3 done
  [x] the picker scans before it lists  (claude 48213, 30 min ago)
  [x] the old order stays under --no-scan  (claude 48213, 25 min ago)
  [ ] a test covers the scan
Decided (1):
  the scan runs in the bar's thread, never in StumpWM's  (claude 48213, 1 h ago)
Defects: 1 open
  open      a card that takes longer than two seconds to scan shows an empty list first  (claude 48213, 20 min ago)
Review: 0 open, 1 addressed
  addressed bin/vikix-wifi:88 the timeout is read twice  (codex 51002, 15 min ago; addressed by claude 48213)
Changed (vikix, 20 min ago): 2 files against 3a9f1c0
  +41 -6  bin/vikix-wifi
  +12 -0  tests/wifi.sh (uncommitted)
Commits (vikix, 20 min ago): 1 past 3a9f1c0
  7c1e0f2  wifi: scan before the list
```

La **akceptaj** kriterioj estas viaj, donitaj kun la tasko, unu linio por ĉiu: `vikix agents worker wifi-fix "..." --acceptance "la selektilo skanas antaŭ ol ĝi listigas" --acceptance "..."` (`desk --task` prenas ilin laŭ la sama maniero, kiel dosiero kun planoj, `acceptance = ["...", "..."]`, kaj `vikix agents handoff --acceptance "..."` poste, kio anstataŭigas la tutan liston). La laboristo markas unu per `vikix agents handoff --done 2`, kaj la rekordo, la listo, kaj la Oficejo diras *2 el 3*. **Decidoj** (`--decided "..."`) estas la faritaj elektoj, do la sekva laboristo ne re-malfermas ilin; **difektoj** (`--defect "..."`, fermitaj per `--defect-done N`) estas tio, kion la laboristo scias, ke estas erara aŭ mankas; **reviziaj** trovoj (`--review "bin/vikix-wifi:88 la tempo limigo estas legata dufoje"`, kio tenas la lokon aparte; `--review-done N` markas, ke unu estis pritrakta) estas revizianto, aŭ via. Kio **ŝanĝiĝis** kaj la **alŝarĝoj** neniam estas tajpitaj: Vikix legas ilin el Git ĉiufoje, kiam la transdono estas skribita kaj dum la testanto faras la teston, kompare kun la bazo, la alŝarĝo, kie la branĉo de la laborposteno forlasis la propran projekton, kun la ne alŝarĝitaj dosieroj markitaj kaj nova, ankoraŭ netrakita dosiero, kiu estas deklarita kiel nova. La MCP-ilo `handoff_update` prenas la samajn kampojn laŭ iliaj nomoj (`acceptance` kiel listo, `done`, `defect`, `defect_done`, `review`, `review_done`, `decided`), `--from` prenas ilin kiel JSON, kaj la paĝo de la laborposteno en la Oficejo montras ilin ĉiujn sub *Kion la agento diras* kaj *Observita stato de Git*.

La sesida ID de Claude Code kaj la konversida ID de Antigravity CLI estas notitaj de la propra hakilo; la ceteraj diras sian per `session`. `vikix agents handoff list` estas ĉiu laborposteno kun rekordo, `vikix agents` montras la staton de la laborposteno de ĉiu agento sub ĝia linio, kaj `Super+m` → *AI* → *Agentoj: transdono de laborposteno* elektas unu. `vikix agents close` markas la rekordojn kiel fermitaj kaj konservas ilin, kaj tiel faras ankaŭ publikigo, kiu forigas la laborpostenon (`.claude/release`), do laborposteno, kies laboro aperas, estas montrata kiel fermita, ne kiel atendanta. Rekordo, kiu ne plu estas volata, de laborposteno, kies laborarbo malaperis, estas forigita per `vikix agents handoff forget DESK` (la Arkivo de la Oficejo havas la saman, unu rekordo je unu tempo, kaj *Purigu arkivon* por ĉiuj el ili); sen nomita laborposteno, ĝi listigas tiujn, kiuj povus esti forigitaj. Ĝi rifuzas dum la dosierujo ekzistas (anstataŭe fermu la laborpostenon) aŭ agento ankoraŭ estas en ĝi, kaj ne prenas nenion alian kun ĝi: nenia dosiero, nenia branĉo, nenia konservita konversacio.

### Reaktivigi laborpostenon

```
$ vikix agents resume wifi-fix
Desk ~/src/vikix-wifi-fix ...            (the handoff, as above)

resumed: claude session 0f1e2d3c-… at ~/src/vikix-wifi-fix, its conversation continues (its store has it)
on workspace 4
```

`vikix agents resume` montras la transiron, la staton de Git kaj la freŝecon de la kontrolitaj elementoj, kaj poste komencas agenton ĉe la labortablo. Kiam la registrado indikas sesion, kaj la deponejo de la provizanto ankoraŭ enhavas ĝin, tiu mema konversacio estas daŭrigita: `claude --resume ID`, `codex resume ID`, `opencode --session ID`, `agy --conversation ID`, ĉiu laŭ la instrukcioj de la instalita helpilo. Alie, komenciĝas nova konversacio, kun la transiro sur la terminalo, kaj la linio klarigas kial: neniu sesio notita, la deponejo de la provizanto perdis ĝin, aŭ la provizanto ne povas daŭrigi sesion (Aider ne havas sesiidentigojn; la opcio `--resume` de Gemini CLI estas prenita el ĝia dokumentaro, sed ne estis kontrolita ĉi tie). Kiam la propra deponejo de la provizanto enhavas konversacion por tiu dosierujo, kiun la registro ne nomas, ĝi estas proponita, kun la komando, kiu indikas ĝin, kaj neniam estas prenita: nenio daŭrigas la plej freŝan konversacion, kaj nenio komencas duan agenton ĉe labortablo, kiu jam havas unu (`--another` faras tion, intence). `--fresh` petas novan konversacion, `--use codex` petas alian provizanton, `--here` petas ĉi tiun terminalon.

### Laboranto: agento ĉe labortablo, okupiĝante pri tasko

Laboranto estas tio, kion `vikix agents worker wifi-fix "la selektilo de Wi-Fi devas unue skani"` komencas (aŭ `vikix agents desk vikix wifi-fix --task "..."`, la labortablo kaj la laboranto kune). La agento estas komencita por la tasko, kun sia unua peto, kaj kun la loko de la registro de la labortablo, tiel ke ĝi aperas sur tio, por kio la labortablo estas uzata, anstataŭ ĉe malplena peto. La laboranto raportas laŭ sia konstruo. Kiam ĝia stato fariĝas *revizia*, *atendanta* aŭ *finita*, notifo sur la komputila ekrano diras tion, kun sia sekva paŝo (neniam por stato, kiu restis, aŭ por via propra ŝanĝo). Kaj laboranto, kiu finas sian vicon havante ŝanĝitajn dosierojn sen skribi sian transiron, estas petata unufoje, de la Halto-hok de Claude Code (`vikix agents stopping`, agordita per `vikix agent` kun la reguloj de la domo; la dosiero de hokoj de Codex estas la sama), skribi ĝin antaŭ ol ĝi finiĝas; la fino post tio estas lasita, tiel ke nenio estas ripetata. Labortablo sen tasko, kun sesio, kun kiu vi simple parolas, estas petata en la sama maniero ĝis ĝia registro havas staton, kaj poste estas lasata sola: unu linio, tiel ke la Oficejo neniam montras la labortablon kun *nenia transiro*. Kaj labortablo, kiun la versio fermas sen stato, ricevas *finitan* kaj la linion de la versio, ĉar la laboro estas sur la ĉefa branĉo, kion ajn la agento ne diris.

**La tasko havas sian propran registrilon** (de 2026-10-14; `lib/tasks.py`, la unua fazo de `plans/DESIGN-office-tasks.md`), krom la labortablo, ĉe kiu ĝi estas farata, kaj la agento, kiu faras ĝin: `~/.local/state/vikix/office/tasks/ID.json`, kreita per ĉiu maniero, en kiu la laboro komenciĝas (`worker`, `desk --task`, `sit --task`, `handoff --task`, la formularoj de la Oficejo, plano), kun identigilo por la tuta vivo (`t-20261014-7f3a9c`), kiu kreis ĝin (*via*; la propra agento, por tiu, kiu sidiĝis kun `--task`; *per plano Nomo* por la plan-ekzekutanto; *nekonata* por tiu, kiu venas de antaŭe), ĝia prioritato (normala, ĝis la vico venas), kiam ĝi estis kreita, lanĉita kaj finita, la transiro, kiel la agento lasis ĝin, kaj ĉiu lanĉo kun sia numero: `office/sequence` donas unu al ĉiu laboranto, kiun la oficejo komencas, tiel ke la ordo, en kiu ili estis komencitaj, estas konservata, kaj du agentoj de Claude estas distingitaj (`#104 claude`). La registro de la labortablo celas sian taskon per identigilo, kaj la tasko konservas sian historion, kiam la laborantoj de la labortablo ŝanĝiĝas: dua laboranto pri alia tasko lasas la antaŭan *blokita ĉe laboranto* ĉe la labortablo, sesio aŭ `resume` estas lanĉo de la sama tasko kun la sekva numero, kaj daŭrigo kun alia provizanto estas notita kiel transiro inter ili. **Du statoj, tenataj aparte.** La stato de la laboranto estas tio, kio estis observata, ĉiufoje, kun kie ĝi estis legita kaj kiom certe (*ida, fidinda: la marko de la titolo; foririnta, deduktita: la procezo foriris*). La stato de la tasko estas registrita, kaj ŝanĝiĝas nur per nomita paŝo: *preta* kiam ĝi estas kreita, *ekzekutanta* ĉe lanĉo, *bezonas decidon* kiam la transiro de la agento diras, ke ĝi atendas, *bezonas revizion* kiam ĝi diras revizion, *preta por eldonado* kiam ĝi diras finita (la laboro de la agento estas farita; via ne), *blokita* ĉe sia laboranto kiam la procezo de la laboranto finiĝas, ĉe la testoj, kiam ili malsukĉesas sen laboranto tie, aŭ ĉe *parkita*, kiam la transiro diras tion; *kompletita* de la eldonado, aŭ per fermo de la labortablo kun ĝia branĉo kunigitaj; *nuligita* per fermo kun `--force`. Vorto, kiu petas la staton, en kiu la tasko estas, nenion ŝanĝas. Eliro de laboranto neniam kompletigas aŭ nuligas ion: la tasko estas blokita je sia laboranto kaj restas videbla, por ke ĝi estu daŭrigita, transdonita aŭ nuligita; nova laboranto ĉe la sama labortablo lasas la antaŭan taskon laŭ la sama maniero, ĉe la labortablo.

**Kio "farita" signifas**, la ununura tabelo, kiun ĉiu laboranto ricevas ĉe la fino de sia unua peto, paŝo po linio, kio ajn la provizanto estas (`DONE` en `lib/handoff.py`; la kapablo de la programo havas ĝin en `projects.md` kiel *Tago de laboranto*):

| Paŝo      | Kio |
|-----------|------|
| Komprenu | la taskon kaj ĝiajn akceptkriteriojn; legu la transiron kaj la instrukciojn de la projekto. |
| Taksante | kiam vi konas la formon de la laboro, diru kiom da tempo ĝi daŭros, supoze ke ne aperas gravaj problemoj: `vikix agents handoff --status working --estimate "40 min"`, aŭ la ilo de la MCP `handoff_update`. |
| Rigardu | la dosierojn, kiujn la tasko tuŝas, antaŭ ol ŝanĝi ilin. |
| Ŝanĝu     | ĉe via labortablo, sur ĝia branĉo. |
| Testu     | la testojn, kiujn la ŝanĝo atingas, per la ekzekutanto de la projekto (`tests/run.sh --changed`); korigu tion, kio malsukĉesas, kaj reekzekutu ilin. Kiam la mapo elektas la tutan asemblaĵon, diru tion kaj kio estas la alterna kosto, antaŭ ol ekzekuti; la ekzekuto ĉe labortablo estas registrita, tiel ke nek la testanto nek la eldonanto reekzekutos ĝin. |
| Gvidu     | ĝisdatigu tiujn, kiujn la ŝanĝo faras malĝustaj, en la sama aldonitaĵo. |
| Aldonigu | nur la dosierojn, kiujn vi ŝanĝis, per nomo. |
| Transdonu | staton, kio ŝanĝiĝis kaj kial, kio estas decidita, kio restas, la testoj, kiujn vi faris, la difektoj, kiujn vi konas. |
| Redonu    | per la oficejo (`vikix agents handoff --status review`); ne kunigu, eldonu aŭ puŝu, krom se la tasko aŭ la reguloj de la domo diras tion. |
| Petu       | kiam io esenca mankas, aŭ ago perdas datumojn, malfermas truon aŭ ŝanĝas la dezajnon; decidu pri la rutino mem. Riparo (io, kio estas metita reen sur la komputilan ekranon) estas farita kaj raportita unue; ŝanĝo, kiu igus Vikix fari ĝin mem, estas proponita kiel demando, kun sia testa kosto. |
| Skatolo     | se via konservas la `.git`-on de la labortablo aŭ la staton de la oficejo nur-legaj (Codex faras tion), ekzekutu `git`, la testojn kaj `vikix` ekstere: petu eskaligi; la reguloj de la domo permesas tagon de labortablo sen peto. |

La Hok de Halto tenas Claude Code kaj Codex al la transdono (laboranto, kiu ŝanĝis dosierojn, estas unuafoje petata pri sia transdono antaŭ ol ĝi finiĝas); provizanto sen hoko estas tenata nur per la tabelo, kaj la linioj de la transdono diras, kiu ĝi estas.

Noto por laboranto, kiu laboras: `vikix agents tell wifi-fix "provu ankaŭ la duan karton de la laptopo"`. Ĝi atendas ĉe la labortablo, montrita per `vikix agents handoff` kaj kalkita sub la linio de la agento en `vikix agents`, kaj la hoko transdonas ĝin al la agento ĉe sia sekva voko al la ilo, subskribita kaj tempstampita, tiel ke nenio estas tajpita en ĝian fenestron. Agento ĉe sia peto ne faras vokon al ilo ĝis kiam vi parolas al ĝi, tiel ke `tell` diras, kiam tio estas: la noto atendas ĝis via sekva demando al ĝi, ne al la hoko. `tell wifi-fix "..." --now` anstataŭe vekigas ĝin: agento ĉe sia peto (halto permesita, nenio de tiam), kies konversacion ĝia provizanto povas daŭrigi, estas petata ekziti kaj daŭrigi kun la noto kiel sia peto, en terminalo ĉe la labortablo, kaj la registro registras *vekigita*; kiam ĝi ne povas esti (la agento laboras, du estas ĉe la labortablo, neniu konversacio estas notita, neniu komputila ekrano), kio estas dirata, kaj la noto atendas kiel kutime. Nur la hokoj de Claude Code kaj Codex povas transdoni vortojn al la agento: por la aliaj `tell` diras tion, la noto restas en la transdono por ke la agento legu ĝin tie, kaj `resume` legas la notojn por kiu ajn agento prenas la labortablon. Noto estas por kiu ajn laboras ĉe la labortablo, nun aŭ poste; tio, kion `dismiss` kaj `handover` lasas (*skribu vian transiron, kaj poste haltu*), estas por la unu agento, al kiu ili estas adresitaj, kaj forigita, kiam ĝi foriras, kaj laboranto neniam ricevas noton de antaŭ ol ĝi komenciĝis, krom se ĝi estas via (la unua tago kun du provizantoj donis nuligadon al la sekva laboranto, kiu obeis kaj haltis, 2026-10-11). Noto estas teksto kiel la transdono: linio, kiu ŝajnas kiel ŝlosilo, estas malakceptita.

### La laboro: taskoj kaj ilia historio

Labortablo estas loko, kaj laboranto estas kiu ajn, kiu sidas ĉe ĝi; la propra laboro estas **tasko**, kaj ĉiu havas sian propran registrilon, krom la labortablo, ĉe kiu ĝi estas farita, kaj la agento, kiu faras ĝin. Ĝi estas kreita per ĉiu maniero, en kiu la laboro komenciĝas (`vikix agents desk vikix wifi-fix --task "..."`, `vikix agents worker`, `vikix agents sit --task`, `vikix agents handoff --task`, la formularoj de la Oficejo, plano) kaj vivas en `~/.local/state/vikix/office/tasks/`, unu dosiero por tasko, nomita per sia **identigilo**: la tago, kiam ĝi estis kreita, kaj ses heksaj ciferoj, `t-20261014-0d2c16`, kiun ĝi konservas por la tuta vivo. Laborantoj venas kaj foriras ĉe la labortablo; la tasko konservas sian identigilon, kiu kreis ĝin (vi, agento, plano), ĝian prioritaton, kiam ĝi estis kreita, lanĉita kaj finita, ĉiu lanĉo, kiu laboris pri ĝi, kaj la transiron de la agento, kiel ĝi estis lasita ĉe la lasta skribo. La registro de la labortablo celas sian taskon per identigilo, kaj la tasko celas sian labortablon, tiel ke `vikix agents handoff` kaj `vikix agents task` montras la saman laboron el du flankoj.

Ĉiu lanĉo havas **numeron**, la ordon, en kiu la laborantoj estis komencitaj: `#1`, `#2`, kaj tiel plu, de unu kalkilo por la tuta oficejo (`office/sequence`, prenitaj sub seruro, tiel ke du lanĉoj samtempe neniam dividas numeron, kaj ĝi neniam malpliiĝas). La linio de labortablo en la Oficejo portas ĝin antaŭ la projekto, kaj `vikix agents resume` prenas la sekvan: laboranto daŭrigita estas nova lanĉo de la sama tasko, kio ajn la provizanto estas. Agento, kiun vi komencis kaj sidigis kun `vikix agents sit --task`, aŭ tasko donita al labortablo kun `handoff --task`, dum agento estas tie, funkcias sen numero: la oficejo neniam komencis tiun agenton, kaj neniu numero estas kreita.

**Du statoj, tenataj aparte.** Tio, kion la laboranto faras (laboras, ĉe sia peto, atendas vian "jes", foriris) estas legita de ĝia terminalo ĉe ĉiu rigardo, kun kie ĝi estis legita kaj kiom certe (*fidinda*, *deduktita*, *nekonata*). Kio la tasko estas, estas registrita, kaj ŝanĝiĝas nur per nomita paŝo: *preta* kiam ĝi estas kreita, *ekzekutanta* ĉe lanĉo, *bezonas decidon* kiam la transdono de la agento diras, ke ĝi atendas, *bezonas revizion* kiam ĝi diras revizion, *preta por eldonado* kiam ĝi diras finita (ĝia laboro estas farita, via ne), *blokita* ĉe sia laboranto kiam la procezo de la laboranto finiĝis, ĉe la testoj, kiam ili malsukĉesis sen laboranto tie, aŭ ĉe *parkita*, kiam la transdono diras tion; *kompletita* de la eldonado, aŭ per fermo de la labortablo kun ĝia branĉo kunigitaj; *nuliigita* per fermo kun `--force`. Vorto, kiu petas la staton, en kiu la tasko estas, nenion ŝanĝas. Eliro de laboranto neniam kompletigas aŭ nuliĝas ion: la tasko estas blokita je sia laboranto kaj restas videbla, por ke ĝi estu daŭrigita, transdonita aŭ nuliĝinta; nova laboranto ĉe la sama labortablo lasas la antaŭan taskon laŭ la sama maniero, ĉe la labortablo.

`vikix agents tasks` estas la tabulo en la teksto, la samaj sekcioj, kiujn la oficejo uzas (*The Office*, sube): tio, kio bezonas vian atenton, poste "En Procezo", "Vendejo", "Blokita" kaj "Finfarita", vico por ĉiu tasko, poste la malplenaj laborpostenoj kaj tiuj, kiuj estas fermitaj hodiaŭ:

```
$ vikix agents tasks
The last launch number is 2.
Needs attention (1):
  worker stopped: vikix · the seconds, then the date on hover [t-20261014-5ec49e] · claude, #1 — the worker stopped: exit 1 (25 min)
Running (1) · sorted by launch order, oldest first:
  #2 claude · vikix/wifi-fix · 35 min · running · the Wi-Fi picker should scan first, then show the list  [t-20261014-0d2c16]
Queue (1 queued) · 0 workers running, up to 2 at once · auto off: nothing starts by itself, queue start does:
  1. the guide review · vikix, desk to make: guide-review · priority high · next, when a slot is free  [t-20261014-7f3a9c]
  Next to start: the guide review — eligible in priority and queue order (vikix agents queue start)
Blocked (2):
  #1 claude · vikix/bar-clock · 25 min · blocked on worker · the seconds, then the date on hover  [t-20261014-5ec49e]
      worker stopped 25 min ago: exit 1, 3 uncommitted
  launch order unknown · vikix/bar-clock · 2 h · blocked on worker · the bar's clock should show seconds  [t-20261014-0d68eb]
Completed (1) · sorted by launch order, oldest first · the last day:
  #0 claude · vikix/office-ui · released 0.72.26 · 3 h ago · the Office's first page  [t-20261013-1a2b3c]
      took 1 h 20 min · finished in 1 h 20 min against 1 h, 20 min over
Desks standing empty (1):
  vikix / notes · claude · stands empty
Closed today (0):
  none
```

La vico de tasko estas ĝia lanĉa numero kaj provizanto, ĝia laborposteno kiel projekto/branĉo (aŭ la laborposteno, kiun ĝi devas fari, laŭ ĝia temo), kiom da tempo ĝi estas tie, ĝia stato en unu vorto (*ekzekutata*; *neaktiva, tasko malferma* por laboranto ĉe ĝia komanda linio pri tasko ankoraŭ malferma; *bezonas revizion*; *blokita ĉe laboranto*; *eldonita 0.72.26*), ĝiaj vortoj kaj ĝia ID. *Lanca ordo nekonata* estas tasko sen lanĉa numero: unu adoptita antaŭ la registradoj (sube), aŭ unu, kies agento la oficejo neniam lanĉis. `--sort KEY` ordigas Ekzekutatajn kaj Finigitajn (laŭ lanĉo, la plej maljuna unue kaj kiel defaŭlto; la plej nova; kreita; aktiveco; prioritato; stato; projekto; provizanto), la Vico ĉiam estas laŭ vica ordo, kaj `--all` montras ĉiun finitan taskon anstataŭ la taskojn de la lasta tago; `--json` estas la tabulo kiel la oficejo legas ĝin. `vikix agents task ID` estas la paĝo de unu tasko, kun ĝia historio; la nomo de laborposteno sufiĉas por ĝia tasko:

```
$ vikix agents task wifi-fix
Task t-20261014-0d2c16: the Wi-Fi picker should scan first, then show the list
Status: running (user, just now): desk --task
Origin: yours
Priority: normal
Project: vikix
Desk: ~/src/vikix-wifi-fix (branch wifi-fix)  [c23757154330]
Launch: #2 claude · just now · by user
Created: just now; queued: unknown; launched: just now; last activity: just now; done: unknown
Text:
  the Wi-Fi picker should scan first, then show the list
Handoff (the agent's words, as the desk's record had them at the last write):
  status working (user, just now)
Launches: 1
  #2  claude  just now  by user  (desk --task)  not ended
History (4 events, newest first; vikix agents events t-20261014-0d2c16 has them all):
  2026-10-14 07:14  handoff  by user  status working
  2026-10-14 07:14  launched #2  by user  provider claude, how desk --task, from ready
  2026-10-14 07:14  worker  by user  task the Wi-Fi picker should scan first, then show the list
  2026-10-14 07:14  created  by user  title the Wi-Fi picker should scan first, then show the list
```

*Nekonata* ĉe paĝo estas tempo aŭ fakto, pri kiu la registro neniam enhavis informojn: ĉi tiu tasko neniam estis metita en vican vicon kaj ne estis farita, do ambaŭ indikas tion, kaj nenio estas supozata anstataŭe. La paĝo de la haltigita laboristo diras, kiel ĝi finiĝis:

```
$ vikix agents task t-20261014-5ec49e
Task t-20261014-5ec49e: the seconds, then the date on hover
Status: blocked (vikix, just now): the worker stopped
Blocked on worker: the worker stopped
...
Launch: #1 claude · just now · by user · ended
...
Launches: 1
  #1  claude  just now  by user  (worker)  ended just now, exit 0
History (5 events, newest first; vikix agents events t-20261014-5ec49e has them all):
  2026-10-14 07:14  blocked  by vikix  running -> blocked, on worker, reason the worker stopped
  2026-10-14 07:14  exited  by vikix  code 0
  2026-10-14 07:14  launched #1  by user  provider claude, how worker, from ready
  2026-10-14 07:14  worker  by user  task the seconds, then the date on hover
  2026-10-14 07:14  created  by user  title the seconds, then the date on hover
```

La elira kodo venas de la propra terminalo: ĉiu terminalo de laboristo faras sian agenton sub unu linio, kiu notigas, kiel la procezo finiĝis (`vikix agents exited`), do la historio de la tasko enhavas ĝin, sendepende de la provizanto, kun aŭ sen konektiloj.

**La tabloj de antaŭ.** Tablo kreita antaŭ ol la registroj ekzistis, havas taskon en sia propra registro kaj neniun taskoregistron: la unua `vikix update` kun ĉi tiu (la migrado, aŭ `vikix agents tasks adopt` farita mane, sekure refariĝa) kreas unu por ĉiu tasko de la tablo kaj por ĉiu laboristo en sia historio, kun tio, kion la registro de la tablo sciis, kaj nenion pli. Kiu donis la taskon kaj kiam ĝi estis skribita, estas tie; la lasta stato de la transdono estas legita en staton (aktiva estas *aktiva*, finita sur tablo, kiun la versio fermis, estas *finita*, historio-eniro sen ajn stato estas *nuligita*); tio, kion la registro neniam havis, estas lasita malplena kaj montrata kiel *nekonata*: la lanĉorda, ekzemple, kiu estas la kialo, ke tia tasko montras `#?` en la listo kaj *nekonata lanĉorda* en la Oficejo, kaj kiam ĝi estis lanĉita. Nenio estas inventita por pleni truon, kaj la registro de la tablo estas tuŝita nur en la ID-oj, kiuj estas reskribitaj en ĝin. Tiu, kies laborarbo foriris kaj kies registro neniam estis fermita (versio de antaŭ la registroj, `git worktree remove` farita mane), ne estas lasita aktiva: ĝi estas blokita sur sia tablo en la sama momento, ĉar neniu laboristo iamuj movos ĝin, kaj la Oficejo petas, ke vi nuligu ĝin aŭ faru ĝin preta denove (2026-10-17: ses tiaj vicoj staris en Aktiva dum dek tagoj). La paĝo de la adoptita tasko diras, kion ĝi ne povis scii:

```
$ vikix agents task bar-clock
Task t-20261014-0d68eb: the bar's clock should show seconds
Status: blocked (user, just now): another task started at its desk
Blocked on worker: another task started at its desk
Origin: yours
Priority: normal
Project: vikix
Desk: ~/src/vikix-bar-clock (branch bar-clock)  [c16d6c81c1e6]
Launch: not launched
Created: just now; queued: unknown; launched: unknown; last activity: just now; done: unknown
Text:
  the bar's clock should show seconds
Handoff (the agent's words, as the desk's record had them at the last write):
  status working (user, just now)
  done and decided (user): half done
History (2 events, newest first; vikix agents events t-20261014-0d68eb has them all):
  2026-10-14 07:14  blocked  by user  running -> blocked, on worker, reason another task started at its desk
  2026-10-14 07:14  adopted  by vikix  status running, unknown: its launch order; when it was launched, title the bar's clock should show seconds
```

**La eventoj.** Ĉiu paŝo estas linio en unu dosiero, `~/.local/state/vikix/office/events-YYYY-MM.jsonl`, dosiero por ĉiu monato, al kiu oni aldonas informojn kaj neniam reskribas, kaj ĝi pluvivas post la registraĵoj: tasko kreita, lanĉita kun sia numero, tasko sendita, kontrolita, demando farita (la tasko atendas), kaj respondita (laboro rekomencita), blokita kaj malblokita, fermita, sendita, liberigita, finita, anulita, akceptita; linio nomas sian taskon kaj sian laborpostenon, kaj la propra registraĵo konservas nur la lastajn kvardek, do la tutan historion oni legas de ĉi tie. `vikix agents events` montras ĝin, komencante de la plej nova, por la laborposteno, ĉe kiu vi sidas, tasko aŭ laborposteno laŭnomo, aŭ ĉio (`--all`), reen al certa tempo (`--since 2h`, `30 min`, `3 days`, `2026-10-10`), `--limit N` linioj (cento), `--json` la linioj kiel ili estas:

```
$ vikix agents events --all --since 1h
2026-10-14 07:14  handoff  by user  status working
2026-10-14 07:14  launched #2  by user  provider claude, how desk --task, from ready
2026-10-14 07:14  worker  by user  task the Wi-Fi picker should scan first, then show the list
2026-10-14 07:14  created  by user  title the Wi-Fi picker should scan first, then show the list
2026-10-14 07:14  blocked  by vikix  running -> blocked, on worker, reason the worker stopped
2026-10-14 07:14  exited  by vikix  code 0
2026-10-14 07:14  launched #1  by user  provider claude, how worker, from ready
2026-10-14 07:14  blocked  by user  running -> blocked, on worker, reason another task started at its desk
2026-10-14 07:14  worker  by user  task the seconds, then the date on hover
2026-10-14 07:14  created  by user  title the seconds, then the date on hover
2026-10-14 07:14  adopted  by vikix  status running, unknown: its launch order; when it was launched, title the bar's clock should show seconds
```

Ĉiu linio estas subskribita, kiel la transdonoj: *uzanto* por via agado, *vikix* por kio la oficejo mem legis (eliro, publikigo, akcepto), agento kun nomo kaj numero por ĝia transdono. La samaj registroj estas tio, kion la Oficejo uzas (la lanĉa numero en la vico, la skatolo **Taska registro** kaj la historio en paĝo de la laborposteno), kion `vikix agents office --json` kaj la MCP-ilo `office` enhavas en sia versio 2, kaj kion la MCP-ilo `tasks` (nur por legi) donas al agento; la publikigo aldonas *publikita* kaj finiĝas la taskoj de la laborposteno. La agordoj de la taska tabulo (`at_once`, `auto`, `quiet`, `delegate`, `delegate_max`) estas skribitaj kiel komentoj kun siaj defaŭltaj valoroj en `~/.config/vikix/office` per la sama ĝisdatigo; la listo de atento kaj la planilo nun legas ĉi tiujn agordojn. La kompleta taska tabulo kun kvin sekcioj restas pli posta fazo (`plans/DESIGN-office-tasks.md`).

### Prioritatoj kaj la taska vico

La prioritato de tasko estas `critical` (kritika), `high` (alta), `normal` (normala) aŭ `low` (malalta). Ĝia pozicio ene de tiu prioritato estas aparta. `vikix agents queue` montras ambaŭ, la sekvan taŭgan taskon, kaj kial ajna tasko devas atendi. Legi la vicon aŭ refreŝigi la Oficejon neniam komencas laboriston.

Kreu taskon sen komenci ĝin, poste vicu ĝin:

```sh
vikix agents task new vikix picker "Improve the picker" --use codex --priority high
vikix agents queue add TASK
vikix agents queue start
```

Anstataŭigu `TASK` per la ID, kiun eldonis la komando `task new`. Ripetu `--after TASK`, kiam nova tasko dependas de aliaj taskoj. Dependo devas esti plenumita; kiam ambaŭ taskoj uzas la saman labortablon, *preta por publikigo* estas sufiĉa, ĉar la sekva tasko konstruiĝas sur tiu branĉo. La nova labortablo estas kreata nur kiam la tasko komenciĝas. Por enmetu taskon, kiu jam estas preta ĉe ekzistanta labortablo, uzu ĝian ID de `vikix agents task DESK`.

- `queue add TASK --first` metas ĝin unue ene de ĝia prioritato.
- `queue next TASK` faras ĝin la sekva taŭga tasko inter la prioritatoj.
- `queue up TASK` kaj `queue down TASK` movas ĝin ene de ĝia prioritato.
- `task priority TASK high` ŝanĝas la prioritaton sen ŝanĝi la manualan ordon.
- `queue defer TASK` resendas ĝin al la stato "preta"; `--later` resendas ĝin al la atendolisto.
- `task ready TASK` faras taskon, kiu estis prokrastita aŭ blokita, pretan kaj aprobas ĝin.
  Laboranto, kiu ankoraŭ estas ĉe sia labortablo, devas unue fini aŭ esti fermita.
- `task cancel TASK "reason"` anuladas la taskon. Ekzistanta laboranto daŭras; anulado ne estas komando por forigi aŭ signali ĝin.
- `queue start [TASK]` komencas unu taŭgan taskon. `queue pause` kaj `queue go`
  haltigas kaj daŭrigas la planadon sen haltigi la laborantojn.

Nur la uzanto ŝanĝas prioritatojn, ordigas la atendoliston, anuladas taskojn aŭ komencas laboranton en la atendolisto. Agentoj povas legi `queue --json`; ĝia informo ankaŭ aperas en la nur-legenda kopio de la oficejo kaj en la ilo MCP `office`.

La Oficejo havas skatolojn **Atendolisto** kaj **Blokita**. Ĉiu linio de la atendolisto montras ĝian pozicion, prioritaton kaj la blokadon, kun butonoj por ĝiaj agoj. Sur linio de la atendolisto, `!` signifas "komencu sekve", `+`/`-` ŝanĝas la prioritaton, `M-p`/`M-n` movas supren/malsupren, `d` prokrastas, `k` anuladas kun konfirmo, kaj `S` komencas ĝin. Sur tasko, kiu estas preta ĉe labortablo, `Q` aldonas ĝin al la atendolisto. **Komencu sekve** elektas la unuan taŭgan taskon. `K` nun montras aŭ kaŝas laborotablojn, kiuj estas en paŭzo (iam `k`).

#### Kapacito kaj aŭtomataj komencoj

La agordoj estas en `~/.config/vikix/office`:

```text
at_once=2
auto=off
```

Aŭtomataj valoroj aplikiĝas, se tiuj linioj mankas. `auto=on` laŭsprece permesas, ke planitaj taskoj komencu kaj plenumu aprobitajn taskojn ĝis la maksimuma kapacito. Nenio ŝanĝas ĉi tiun agordon por vi. Sen ĝi, evento nur anoncas novajn taskojn, kiuj estas pretaj. Eventoj inkluzivas transdonojn, elirojn, respondojn, publikigojn, ŝanĝojn de la vico kaj fermadon de laborpostenoj. `queue tick` prilaboras eventon kaj obeas la saman agordon. Ne ekzistas daŭra programo aŭ planita laboro en la procezo de StumpWM.

La planilo kalkulas la observitajn laboristojn en laborantaj aŭ reviziataj taskoj kaj atendatajn lanĉojn de terminaloj. Paŭzitaj laboristoj ne uzas lokon. Tasko atendas, se la detektilo ne funkcias, ĝia provizanto ne funkcias, ĝi ne estas aprobita, respondo aŭ dependeco ankoraŭ estas necesaj, ĝia laborposteno estas paŭzita aŭ okupata, aŭ ĝia branĉo estas publikiĝanta. Ĝi neniam prenas mankantajn observojn kiel permeson por lanĉi. Planitaj laboristoj uzas la saman kapaciton kaj lanĉblokadon; propra `at-once`-valoro de plano povas apliki pli malgrandan limon. Plano, kiun vi laŭsprece komencis, ankoraŭ plenumas siajn aprobitajn paŝojn kun `auto=off`; ĝiaj dependecaj kaj publikigaj kondiĉoj restas en la mano de la planilo.

Lanĉo rezervas sian lanĉnumeron kaj lokon, antaŭ ol malfermi la terminalon. La viciĝinta tasko konservas sian ID-on, historion kaj registritajn elektojn de laboristoj. Rezervado restas ĝis la laboristo estas observita aŭ ĝia eliro estas registrita. Post du minutoj, posta provo kun fidinda detektilo markas neklara lanĉo kiel blokita; ĝi neniam lanĉas ĝin denove aŭtomate. Kontrolu la laborpostenon, antaŭ ol reaktivigi tiun taskon.

`queue bump TASK --over DESK` estas laŭsprece malprioritigo: ĝi paŭzas la laboriston de DESK ĉe ĝia venonta uzo de ilo kaj komencas TASK ĉe alia laborposteno. La malnova tasko registras, kial ĝi estis paŭzita. `vikix agents go DESK` restaŭras ĝin. La planilo neniam memvole malprioritigas. Ĝia paŭzo estas kunlabora, do la malnova laboristo povas fini sian aktualan uzon de ilo, antaŭ ol ĝi atendas.

### Reĝimoj: kiel multe Codex-laboristo estas libera

Codex plenumas tion, kion ĝi estas petita, en sia propra sandbox (bubblewrap kaj seccomp en Void), kaj petas vin antaŭ ĉiu paŝo ekster ĝi. Ĉe laborposteno, kiu havas multajn paŝojn: la `.git`-dosiero de la laborposteno estas dosiero, kiu celas al la deponejo, kiun la sandbox tenas kiel sola-lektiva, do ĉiu aliĝo petas; do, faru kopion, la testojn kaj la transdonon, kiuj skribas sub `~/.local/state`. Kaj la sandbox kiel via propra `~/.codex/config.toml` povas plivastigi, al kiuj ĝi povas aliri la propran dosierojn de la projekto kaj ĉiun alian laborpostenon. Do, Vikix komencas Codex kun **reĝimo**, `vikix agent --mode supervised|autonomous|unrestricted`, kaj `vikix agents worker`, `desk --task` kaj `resume` uzas la saman vorton:

- **supervised**: La sandbox de Codex estas la laborposteno mem (la dosierujo kaj `/tmp`; viaj `writable_roots` estas metitaj flanke por la sesio, do la propra dosierujo de la projekto, `~/vikix` kaj la aliaj laborpostenoj estas sola-lektivaj por ĉio, kion ĝi plenumas), la reto estas malŝaltita, kaj ĉiu paŝo ekster ĝi petas vin, krom se la reguloj de Vikix permesas ĝin (sube).
- **autonomous**: la sama sandbox, la reto estas ŝaltita (por `pip`, `cargo`, peto per HTTPS), kaj revizianto de Codex mem (`--approve-for-me`) respondas pri la paŝoj ekster ĝi anstataŭ vi. Ĉi tio estas tio, kion laboristo ĉe laborposteno ricevas, kiam nenio diras alie, kaj kion la *Agento ĉi tie* de Super+a ricevas en via hejma dosierujo (dosierujo sen deponejo; tie la sandbox estas via hejmo kaj `/tmp`): la defaŭlta agordo estas `mode=autonomous` en `~/.config/vikix/office`, kiun Vikix skribas kun sia signifo la unuan fojon, kiam Codex komenciĝas, kaj vi povas ŝanĝi ĝin. En deponejo, kiu ne estas laborposteno (propra dosierujo de projekto, nekonata), Codex funkcias kiel via propra `~/.codex/config.toml` diras.
- **unrestricted**: neniu sandbox kaj neniu aproboj (`--dangerously-bypass-approvals-and-sandbox`), por VM aŭ ujujo. Ĝi neniam estas la defaŭlta: ĝi estas tajpita ĉiufoje, avertita en la terminalo kaj en notifiko, rifuzita en propra dosierujo de projekto, kaj skribita en la registron de la laborposteno, do la protektaj linioj de la transdono diras *neniu sandbox: ne limigita, de la uzanto* sub tiu agento.

**La reguloj de Vikix por Codex**, `config/codex/vikix.rules`, ligitaj kiel `~/.codex/rules/vikix.rules` per `vikix agents hooks codex --install` (Codex legas ĉiun `.rules`-dosieron tie, do dosiero de vi apud ĝi restas, kaj unu en la vojo estas lasita sole), permesas, ke la tago de laborposteno funkciu ekster la sandbox sen peto: `git` en la branĉo de la laborposteno (aldoni, aliĝi, stato, diferenco, registro, reordigi, elpreni, peti, kunfandi, meti en la atendanton, simpla `branch` aŭ `tag`), `tests/run.sh`, `vikix` (kopio, ŝanĝoj, agentoj, provi, dokumentoj, kio, kial, reguloj, taksi, projekto, rekordoj, kuracisto, temo) kaj `.claude/release`, kiuj mem rifuzas la danĝerajn kazojn. `git push` kaj `vikix update` petas (laboristo komencita kun `--push` estas celita por pusi), forigo de branĉo, etikedo aŭ laborposteno petas (fermo de laborposteno estas `vikix agents close`), kaj `sudo`, `doas` kaj forcita puzo estas tute malpermesitaj. `codex execpolicy check --rules ~/.codex/rules/vikix.rules -- git commit -m x` montras, kion komando ricevas. Codex kongruas regulon de la unua vorto de la komando, do `timeout 20s vikix snapshot ...` nenion kongruigis kaj petis ĉiufoje (2026-10-11, ĉiu mesaĝo de kopio estis aprobeda unufoje): la kromaĵo de la reguloj por ĉiu paŝo ekster la sandbox (sube) permesas la samajn komandojn sub `timeout`, `env`, `nice`, `VAR=valoro` aŭ `bash -lc`, se ĉiu komando de la linio estas unu el ili; la petoj kaj malpermesitaj kazoj restas en Codex.

**La instrukcioj de la deponejo.** Codex legas `AGENTS.md` de la radiko de la deponejo ĝis la dosierujo, en kiu ĝi laboras, neniam `CLAUDE.md`. Vikix donas al ĝi, por la sesio, `CLAUDE.md` kiel la dosiero, al kiu ĝi povas reteni sin, kiam dosierujo ne havas `AGENTS.md`, kun la kapo de Codex pligigitaj por teni la tuton de Vikix; deponejo kun `AGENTS.md` estas legita kiel intencis ĝia aŭtoro. Do, Codex-laboristo en Vikix legas la samajn instrukciojn kiel Claude Code. La gvidilo de la laborposteno restas `~/.codex/AGENTS.md`, kiel antaŭe.

**La fidindeco de la kromaĵo.** Codex plenumas kromaĵon de vi nur post tio, ke vi fidis ĝin en `/hooks`, per la hanko de la dosiero, kiun ĉiu versio, kiu ŝanĝas la dosieron, forigas. Kiam `~/.codex/hooks.json` estas de Vikix (la ligo, kiun `--install` faras, aŭ kopio de la dosiero) kaj la dosierujo estas unu el viaj projektoj (`vikix project list`) aŭ neniu deponejo (via hejmo, *Agento ĉi tie* de Super+a), `vikix agent` pasas `--dangerously-bypass-hook-trust`: Vikix prizorgas, ke tiu dosiero estas tia farante ĝin. En deponejo, kiu ne estas via projekto, la propra peto de Codex restas, do nekonata `.codex/hooks.json` neniam funkcios sen fidemo; `VIKIX_CODEX_HOOK_TRUST=ask` tenas la peton ĉie. `vikix agents hooks codex` diras, kiu tenas, kaj legas vian `~/.codex/config.toml` por agordo sub titolo, kiun Codex ne legas (`sandbox_mode` sub `[section]` linio nenion faris, kaj Codex funkcis sola-lektiva, petante por ĉiu skribo, 2026-10-11); `vikix doctor` diras la samon. La dosiero estas via: Vikix neniam skribas ĝin.

La reĝimoj estas de Codex por nun: `--mode` kun alia agento estas rifuzita per la vortoj, kaj la mapigo de ĉiu alia provizanto venas, kiel ĝi estas provita (Claude Code's `--permission-mode`, OpenCode's `permission` bloko, Gemini CLI's `--approval-mode`). Kio la reĝimo ŝanĝas, estas kiu respondas pri paŝo ekster la sandbox; la kromaĵo de la reguloj funkcias antaŭ, ke ĉiu el ili vidas ĝin, kaj la sandbox sub ambaŭ. Kio ĝi ne faras: komando, kiu skribas tra programo, kiun la kromaĵo ne konas, ankoraŭ pasas la kromaĵon (la sandbox tenas ĝin al la laborposteno), kaj la revizianto en *autonomous* estas la juĝo de modelo kaj ne regulo. Kion la unua viva provo montris (2026-10-10, `tests/codex.sh --live`, per la mano: unu `codex exec` ĉe laborposteno en la *autonomous* vico): la sandbox estas kiel dirite, la laborposteno estas skribebla kaj la propra dosierujo de la projekto, la `.git` de la laborposteno kaj la dosierujo de la deponejo estas sola-lektivaj; la kromaĵoj de Codex aperas ([Kio tenas la regulojn](#kio-tenas-la-regulojn-por-ĉiu-agento)); kaj Codex, kiu diris nur sian taskon, funkcigis `git commit` kaj la transdonon ene de la sandbox, vidis ambaŭ fiaskis en la sola-lektiva `.git` kaj stato, kaj haltis, kie unu, ricevante la unuan peton de laboristo, kiu finiĝas per la difino de farite kaj ĝia frazo pri la sandbox, petis funkcigi ĉion ekstere, kaj la reguloj permesis la takson, la aliĝon kaj la transdonon sen peto. Do, komencu Codex-laboriston tra la oficejo (`vikix agents worker`, `desk --task`, `handover`), kiu donas al ĝi tiun peton. La provo de 2026-10-11 (Codex 0.162.1) aldonis unu paŝon: `timeout 20s vikix snapshot ...`, kiu neniu regulo kongruigis, eliris el la sandbox tra la permeso de la kromaĵo, notita en la ĵurnalo kiel komando de la agento; `codex exec` devigas `approval never` sen `--approve-for-me` (*Eskaligita re-provo estas malpermesita de ĉi tiu medio*), do la *supervizata* vico estas sondata nur en sia propra sesio.

### Paŭzado de laboristo, kaj vicoj

`vikix agents pause wifi-fix` tenas la laboriston: la sekva afero, kiun ĝi faras, redaktado, komando aŭ legado, atendas en la kromaĵo kun sia kompleta kunteksto, ne kostante ion, ĝis `vikix agents go wifi-fix`. La paŭzo okazas ĉe tiu sekva alvoko, ne ĉe ĉi tiu momento, do longa pensado aŭ legado finiĝas unue. Post dek minutoj la atendanta alvoko estas rifuzita kun kialo, la vico finiĝas sen difekto, kaj la laboristo diras, ke ĝi estas paŭzita. `go` tiam vekas ĝin, anstataŭ atendi vian sekvan vorton (ĝis 2026-10-11 ĝi sidis ĉe sia peto ĝis vi parolis al ĝi): kiel `tell --now` faras, la ununura agento ĉe la laborposteno, ĉe sia peto, kun konversacio, kiun ĝia provizanto povas rekomenci, estas petita eliri kaj rekomencita kun la vortoj por daŭrigi, kie ĝi estis, kaj la registro logas *vekita*; kiam ĝi ne povas esti (du ĉe la laborposteno, neniu konversacio por rekomenci, neniu labortablo) `go` diras kialon kaj la vortoj atendas en ĝia enirejo, legita ĉe ĝia sekva uzo de ilo. `vikix agents go wifi-fix` diras, por kiom da tempo la laborposteno estis paŭzita kaj kiu daŭrigas; la tenita alvoko tiam pasas kun vorto de la kromaĵo, do la laboristo, kiu ne vidis la atendon, scias, ke ĝi estis paŭzita, de kiu kaj por kiom da tempo, kaj daŭrigas, kie ĝi estis, kun notoj, kiujn vi lasis dumtempe (`tell`). `vikix agents` kaj la Oficejo montras la laborpostenon kiel paŭzita, de kiu kaj de kiam. `--hard` frostigas la procezon de la agento ĉiun momenton anstataŭe (SIGSTOP, trovita per ĝia proceza deskriptoro, neniam per nomo) kaj `go` degelas ĝin: por agento sen kromaĵo, kiel Aider, aŭ urĝeco, kaj dirita kiel tia, ĉar peto en la flugo povas finiĝi dum tempa paŭzo.

Du laboristoj, kiuj atingas la saman dosieron, estas haltigitaj ĉe via peto, kiel la reguloj de la domo diras sube. Kun `vikix agents turns wifi-fix on`, la laboristo ĉe tiu laborposteno atendas anstataŭe: redaktado de dosiero, kiun alia agento ŝanĝis, ne aliĝita, atendas pri la aliĝo de tiu agento, ĝis dek minutoj, kaj daŭrigas kun "via vico", kiam ĝi venas, aŭ petas vin, kiam ĝi ne venas. Nur ĵurnala eniro ne tenas: kiam la dosiero estas aliĝita en la laborposteno de la alia, la vico estas libera. Du atendantaj pri ĉiu estas viditaj, kaj la posta petas vin tuj. Ĝi estas senŝaltita laŭ defaŭlto, ĉar silento estas malĝusta por sesio, kun kiu vi parolas; `turns off` redonas la peton.

### Kiam la reto foriras

Claude Code ripetas peton dum kelkaj minutoj se la reto estas neaktiva, poste forlasas kaj finas la rondon kun API-ero (*Ne povas atingi la API-serveron*, *Konekto perdiĝis dum la respondo*); ĝis la 14-a de oktobro 2026, la agento tiam restis ĉe sia komando ĝis vi tajpis *daŭrigu*, kiam vi rimarkis. Nun, observanto sekvas ĉiun Claude Code ĉe labra tablo, aktivigita de ĝia konektilo ĉe ĝia unua voko al ilo (unu malgranda procezo, kiu legas nur la finon de la transskribaĵo, kaj nur kiam ĝi kreskis; `VIKIX_RECONNECT=0` en la medio de la agento malhelpas la konektilon komenci unu). Ĝi vidas la rondon fini tiel, notis la paŭzon en la ĵurnalo, do `vikix agents` diras *haltigita de la reto: rekomencita kiam ĝi revenos*, kaj petas la gastiganton de la API pri konekto ĉiun dek sekundojn, sen sendi ion (`api.anthropic.com`, aŭ la gastiganto de `ANTHROPIC_BASE_URL`). Kiam ĝi respondas dufoje sinsekve, la agento estas vekita kiel `go` vekas unu: oni petas, ke ĝi eliru kaj ĝia konversacio estas rekomencita per la vortoj por daŭrigi, nomante la eron kaj kiom longe la reto estis neaktiva, kaj la registraĵoj notigas *la reto revenis*. Observanto paŭzas kiam la konversacio daŭras memstare (vi tajpis *daŭrigu* antaŭe), finiĝas kun ĝia agento (vekita agento estas nova procezo, kiu ricevas sian propran observanton ĉe sia unua voko), kaj forlasas post unu tago. `vikix agents reconnect wifi-fix` faras la saman mane, nun, por unu labra tablo aŭ por ĉiuj (`--all`): ĝi diras kiam la lasta rondo de la agento ne finiĝis pro la reto, aŭ kiam la gastiganto ankoraŭ ne respondas (`--wait` atendas pri tio). Eniro, kiu eksvalidiĝis kaj la kreditoj finiĝis, finas la rondon same, kaj ĝi ne estas la eraro de la reto: tiuj restas viaj. Nur la transskribaĵo de Claude Code diras, kiel rondo finiĝis, do Codex-laboranto haltigita de la reto ankoraŭ estas rekomencita mane, kaj agento en via hema dosierujo (*Agento ĉi tie*) ne havas labran tablon, je kiu rekomenci.

### La testanto: manuela procezo revenas kontrolita

La Oficejo ankaŭ sekvas rondojn, kaj komencas laboranton rekte per `tests/run.sh`.
La testa linio de la labra tablo montras kompletigitajn/totalajn kaj restantajn nombrojn, la nomojn
de la testoj nun funkciantaj, kaj proksiman tempon restantan. Ĝia testa kesto havas la rondon kiel tablon,
unu linio po testo en la ordo de la rulanto: la testo, ĝia stato (pasis, malsukcesis,
funkcianta, en vico), kiom da tempo ĝi daŭris aŭ daŭras ĝis nun, ĝia takso (ĉirkaŭ kiom
da tempo restas, pasinta takso, ĉirkaŭ kiom da tempo kiam ĝi komenciĝis, aŭ nekonata), kaj
*suspektata haltigita* en la lasta kolumno, kiam ĝi estas. Taksoj uzas la
lastan sukcesan daŭron de ĉiu testo sur ĉi tiu maŝino; paralela laboro estas kalkulata, sed
tempo atendanta pri la vicoj de aliaj rondoj estas aldona. La unua rondo ne havas
historion, kaj troa tempo igas la totalan ETA nekonata. Funkcianta testo, kiu pasis
tri fojojn la antaŭan daŭron (kaj almenaŭ kvin minutojn), aŭ dek kvin
minutojn sen historio, estas **suspektata haltigita**. Ĉi tio estas longdaŭra
averto, ne pruvo: silentaj testoj ankoraŭ povas funkcii. Testoj en vico neniam estas
markitaj kiel haltigitaj, kaj nenio estas haltigita aŭtomate. Direktaj rondoj konservas
sian eliron kaj kontrolon pri la procezo en la terminalo de la laboranto; **Skiptu testojn** kaj
**Testa registo** apartenas al rondoj komencitaj de la testanto de la Oficejo.

Kiam laboranto starigas sian statuson al *reviziu*, la testoj de ĝia labra tablo funkcias memstare: `vikix agents test wifi-fix` estas tio, kio funkcias, skripto kaj neniam agento. Ne kiam rondo de la rulanto jam pasis pri tiu specifa versio (la `tests/run.sh` de laboranto ĉe labra tablo registras sian rezulton en la registraĵo kiel la testanto faras, kaj la publikigo legas la saman), nek dum unu funkcias ĉe la labra tablo: la enirujo tiam diras tion, kaj nenio funkcias dufoje. Ĝi funkcias la `tests/run.sh` de la projekto en la labra arbo, `--changed` de kie la branĉo forlasis la propran projekton, tra la vico de la rulanto kiel ajna alia rondo (kaj post la testoj de publikigo, kiam unu el la projekto estas testata: la du samtempe malsukcesis pro ŝarĝo sole; ne pro ŝanĝo, kiun neniu testo kovras, plano aŭ dezajno, pri kiuj `tests/changed.sh` diras kaj funkcias samtempe; atendo prenita estas dirita en la kontrolo aparte de la tempo de la rondo), kaj skribas la rezulton en la registraĵon kiel kontrolon subskribitan *vikix*, la malsukcesintaj testoj nomitaj kaj la unua linio de la malsukceso konservita, kaj en la enirujon de la laboranto, do la laboranto legas ĝin ĉe sia sekva voko al ilo kaj solvas siajn proprajn erarojn; `vikix agents test --log wifi-fix` montras la tutan rondon. `vikix agents` diras *testanta* dum ĝi funkcias, kaj la Oficejo listigas la labran tablon sub **Testanta**, ĝia linio dirante, kio funkcias kaj ekde kiam, kun **Skiptu testojn** sur la linio; la testa kesto de la labra tablo havas la publikigon, kiun ĝi atendas, la lastajn liniojn de la rondo (la eliro de ĉiu testo aperas tute kiam ĝi finiĝas) kaj **Testa registo**, la tuta rondo ĝis nun en la panelo de la labra tablo. **Skiptu testojn** (`vikix agents test --skip wifi-fix`, la ŝlosilo `s`) estas por kiam vi ne volas atendi: la testanto finiĝas, la rulanto kaj ĝiaj testoj kun ĝi, kaj la registraĵo ricevas kontrolon markitan *preterlasita* pri la versio, kiel ĝi estas, kiun ĉeno de plano prenas kiel la manuale kontrolita, do la sekva tasko komenciĝas; la laboranto estas dirita en sia enirujo. La publikigo neniam prenas preterlasitan kontrolon por rondo de si mem. Projekto sen `tests/run.sh` estas dirita tiel, sen kontrolo. La publikigo legas la samajn kontrolajn punktojn: `.claude/release` preterlasas sian propran rondon, kaj diras tion, kiam la registraĵo havas pasantan rondon de la rulanto tiel larĝa kiel sia propra pri la sama versio, je kiu ĝi kunigas, kun pura arbo (unu versio estis testita kvar fojojn en unu tago, 2026-10-11); rondo de nomitaj testoj, kontrolo pri pli malnova versio aŭ malsukcesa rondo post la pasinta ne pruvas ion, kaj `--tests none` restas kiel ĝi estis tajpita. Labra tablo kreita, aŭ laboranto komencita, kun `--no-tests` (la *Neniu testo sole* kesto de la Oficejo) ne funkcias ion je la manuela procezo: la testoj estas por vi por funkcii, kun `vikix agents test wifi-fix`, la *Testo* de la Oficejo aŭ la ŝlosilo `t` de la labra tablo, kaj `vikix agents test --all` forlasas tian labran tablon kaj diras tion. La agordo estas de la labra tablo, konservita en ĝia registraĵo kaj montrita de `vikix agents handoff` kaj en la Oficejo (*testoj ne aktivigitaj*); laboranto komencita pri tasko sen `--no-tests` havas la testojn denove.

`vikix agents test --all` prenas ĉiun labran tablon en revizio. En la ordo en kiu ili iris al revizio, labra tablo aliĝas al aro kiam ĝi ŝanĝis nenian dosieron, kiun la aro havas; la aro estas kunigita al la propra branĉo de la projekto en forĵetinda labora arbo, forigita poste, kaj testita unufoje, la kontrolo de ĉiu labra tablo dirante kun kiu, ĉar pasado sole kaj malsukceso kune estas por kio aro. Labra tablo, kiu transiras kun unu en la aro, funkcias sole, en sia propra labora arbo kiel ĝi estas, kaj oni diras al ĝi, kun kio ĝi transiras. Nenio tuŝas la branĉon de labra tablo: kunigo, kiu konfliktas, nur sendas tiun labran tablon por funkcii sole.

### Plano: taskoj en ordo, funkcias por vi

Kelkaj taskoj, kiuj apartenas kune, kelkaj konstruantaj sur aliaj, estas plano: TOML-dosiero nomante la projekton kaj ĝiajn taskojn, ĉiu estas la laboro de unu laboranto, kaj `vikix agents plan run plan.toml` funkcias, kreante la labrajn tabulojn kaj komencante la laborantojn per `vikix agents desk` kaj `vikix agents worker` kiel vi farus mane.

```toml
project = "vikix"
at-once = 2            # workers running together, at most
gate = "me"            # a desk's release waits for your yes

[[task]]
name = "events"
desk = "office-events"
task = "An event log for the office: one line a hand-in, a check, a release."

[[task]]
name = "runner"
desk = "office-events"               # the same desk: the next worker in the chain
after = ["events"]
task = "The plan runner, waking on the event log."
release = "The office's event log and the plan runner"

[[task]]
name = "box"
after = ["runner"]                   # at another desk: waits for office-events to be released
task = "A Plans box in the Office, above the desks."
agent = "codex"                      # the worker's choices, as the New worker form has them
push = false
no-tests = false
```

Taskoj ĉe unu laborposteno estas ĉeno, ĝiaj laboristoj en sia vico laboras ĉe unu branĉo, laŭ la ordo en la dosiero: la sekva komencas post kiam la lasta finis (stato *revizio* aŭ *finiĝis*) kaj ĝiaj testoj pasis, kun la transdono, la lasta restas por legi, kaj la laborposteno estas liberigata unufoje, ĉe la fino de la ĉeno, kun la projekta `.claude/release`. Taskoj ĉe diversaj laborpostenoj estas farataj samtempe, ĝis `at-once`. Tasko post tasko ĉe alia laborposteno atendas, ke tiu laborposteno estu liberigata, kaj komenciĝas ĉe nova laborposteno, kreita el la ĉefa, tial tia tasko devas esti la unua ĉe sia laborposteno. Tasko kun `no-tests`, aŭ projekto sen `tests/run.sh`, estas transdonata sole. La taskonomo estas la laborposteno, se ĝi estas forlasita.

La ekzekutanto estas skripto, ne agento: ĝi ne redaktas dosieron, ne respondas al peto, neniam metas du laboristojn ĉe unu laborposteno, kaj neniam kunigas aŭ puŝas (la skripto pri la publikigo kunigas, `gup` restas via). Laboristo, kiu finis sian taskon, estas forigata post kiam ĝiaj testoj finiĝis, ĉar laboristo ĉe sia laborposteno neniam legas noton. Rondo estas unu laboristo laboranta pri tasko; se la testoj de iu ne pasis, aŭ se li forlasis sen transdoni, li fiaskis, kaj la laboristo de la sekva rondo estas informata pri tio en la enirejo de la laborposteno; la tria fiasko haltigas tiun laborpostenon kun la notacio **Bezonas atenton**, kun la stato de la laborposteno fiksita kiel *atendante* de vikix, kiel fiaskis publikigo, kaj la tasko lasita kun dosieroj ne enmetitaj kiam ĝia laboristo foriris. Vi daŭrigas de tie per la mano: transdonu la taskon mem, aŭ korektu kaj reekzekutu la publikigon kun `vikix agents plan release DESK`, kio estas ankaŭ via "jes", kiam la pordo estas *mi*.

Plano komenciĝas de ŝablono. `vikix agents plan templates` listigas ilin: Vikix's (`config/plans/`: *one-task*, unu tasko, unu laboristo ĉe unu laborposteno, liberigata kiam lia laboro estas finita; *build-chain*, konstruu, poste ĝiaj testoj, poste ĝia gvidlibro, tri laboristoj en sia vico ĉe unu laborposteno, liberigata unufoje ĉe la fino; *two-desks*, du laborpostenoj samtempe, ĉiu kun sia propra parto, poste tasko kunigas ilin ĉe nova laborposteno) kaj via propra, `~/.config/vikix/plans/templates/*.toml`, plano de kiu la unua linio estas `# NAME — por kio ĝi estas uzata`, kun `PROJECT` kie la projekto estas, `topic` en la nomo de ĉiu laborposteno, kaj `EDIT:` komencas la liniojn, kiujn vi devas skribi; unu el viaj kun Vikix-nomo anstataŭas ĝin. `vikix agents plan new TEMPLATE NAME PROJECT [--at-once N] [--gate me|none]` skribas la kopion al `~/.config/vikix/plans/NAME.toml` kun la projekto, kaj la du agordoj, se ili estas donitaj, plenigitaj, ĉiu laborposteno nomata por la plano (`topic` fariĝas `NAME`, `topic-one` `NAME-one`), kaj la komentoj de la ŝablono restas, do la dosiero klarigas sin mem. Tiam vi skribas ĝiajn liniojn `EDIT:` per viaj propraj vortoj: `plan run` rifuzas taskon, kiu ankoraŭ tenas unu, kaj ĝis la plano esti ekzekutita, ĝi estas *projekto*, kiun `plan status` listigas, kaj la Oficejo montras en la skatolo "Planoj" kun ĝia "Ekzekutu". La "Nova plano..." de la Oficejo estas formo kun la taskoj de la ŝablono kiel ĝiaj kampoj, kiu skribas la vortojn (vidu [La Oficejo](#la-oficejo)).

Ĝia stato estas eltrovita ĉiun fojon el la dosiero de la plano kaj la registraĵoj de la laborposteno (kiu tasko estas de la registro, kio okazis antaŭe en ĝia historio, la kontrolaj punktoj kaj ilia freŝeco, kiu estas ĉe la laborposteno), do refaro ne perdas ion, kaj `plan run` daŭrigas; nur ĝiaj ŝanĝoj estas ĝiaj, en `~/.local/state/vikix/office/plans/`. Ĝi vekiĝas ĉe la okazaĵa registro de la oficejo, `~/.local/state/vikix/office/events-YYYY-MM.jsonl`, unu linio estas transdono, kontrola punkto, komencita laboristo, fermita laborposteno aŭ agento, kiu foriris, skribite de ĉiu registraĵa skribo (kaj, de 2026-10-14, ĉiu paŝo de la registro de tasko: kreita, lanĉita kun ĝia numero, blokita, elirita, liberigata, kompletigita; `vikix agents events` relege ĝin), kaj rigardas sin ĉe si unufoje ĉiu minuto. `vikix agents plan status` diras kie ĉiu plano estas, unu linio laborposteno kaj unu linio tasko; `plan pause` ne komencas ion novan, `plan stop` finas la ekzekutanton (la laboristoj laborantaj daŭrigas), `plan log` estas kion ĝi faris. Kion ĝi ne povas scii: kiujn dosierojn du laborpostenoj tuŝos; la ŝanĝoj kaj la reguloj pri konfliktoj prizorgas tion.

### Forigo de laboristo, kaj kiel li foriris

`vikix agents dismiss wifi-fix` petas al la agento de la laborposteno, ke li eliru, kaj konservas la laborpostenon, ĝian branĉon kaj ĝiajn dosierojn, do `vikix agents resume` prenas ĝin poste; ĝi estas la "Fermu agenton" de la Oficejo de la terminalo. Noto iras al la laboristo unue, "forigata: skribu vian transdonon, se vi povas, poste haltigu", nur por tiu agento: unu meze de la ŝanĝo legas ĝin ĉe sia sekva voko de ilo, kaj neniu posta agento ĉe la laborposteno faras tion; la registro notiĝas pri la forigo kaj kiom da dosieroj restis ne enmetitaj. Agento neniam forigas sin mem. Iu ajn maniero ke agento forlasas laborpostenon, forigata, elirinta aŭ elirinta, la hoketo `SessionEnd` de Claude Code (`vikix agents left`; la dosiero de hoketoj de Codex havas la saman, kvankam `codex exec` ne aktivigas, do la foriro de Codex estas notita el sia propra sesio) notiĝas en la registro, do la sekva ĉe la laborposteno, kaj la Oficejo, vidas *Foriris: forigata, 3 ne enmetitaj*.

### Transdono de laborposteno

Claude Code dezajnas ĉe laborposteno, Codex implementas, Claude kontrolas: ĉiu paŝo estas transdono, kaj `vikix agents handover wifi-fix --to codex` estas la ununura komando, kiu faras tion. Ĝi estas rifuzita dum la agento de la laborposteno estas meze de paŝo (redakto, komando aŭ paŝo komencita en la lasta minuto, kiel la ĵurnalo de la hoketoj diras), krom se estas `--now`; tiam la agento estas petata pri sia transdono en noto (nur por li), kaj estas donita ĝis du minutoj por skribi ĝin, la transdono de la registro estas observata por la ŝanĝo (agento ĉe sia vokilo ne legas noton, do oni ne atendas pri ĝi); tiam la tasko de la sekva agento estas fiksita: `--task "..."`, aŭ la sekva paŝo de la registro, kiel la agento lasis ĝin, neniam la tasko, kiel ĝi estis, kio estis la lasta agento (la dezajnero *plano, sen kodo* fariĝis la ordonoj de Codex la unua tago, kaj li transdonis post 27 sekundoj), kaj se neniu, la transdono estas rifuzita kaj la agento restas; tiam ĝi estas forigata kiel `dismiss`, la tasko antaŭe kaj ĝia transdono iras en la historion de la laborposteno, kaj la sekva agento estas komencita kun `vikix agents resume wifi-fix --use codex --fresh` (`--mode` kiel laboristo), ĝia unua vokilo estas ĝia tasko, la kampoj de la laborposteno (la kriterioj, la decidoj, la difektoj, la trovoj, kio ŝanĝiĝis, la enmetoj) kaj la konto kaj la sekva paŝo de la lasta agento, do ĝi komenciĝas el tio, kion la lasta lasis, anstataŭe de vaka vokilo. La registro notiĝas *transdonita: claude -> codex* kaj konservas ambaŭ sesiojn, do `vikix agents resume --use claude` poste trovas la konversacion de Claude, kaj `--use codex` tiun de Codex. Nenio de ajna konversacio estas kopiata: git, la registro kaj la dokumentoj de la projekto estas la komuna bazo. Agento neniam transdonas sian propran laborpostenon.

### Kontrolo de alia agento

`vikix agents review wifi-fix --use codex` havas alian provizon legi la laboron de laborposteno kaj diri kion ĝi trovas, sen iam ajn esti ĉe la laborposteno. La lasta enmeto de la laborposteno estas elprenita en forigita laborareo, de sia propra (la ne enmetitaj dosieroj estas forlasitaj, kaj oni diras tion), kaj la recenzanto estas elprenita tie sen fenestro kaj sen maniero skribi: Codex kiel `codex exec --sandbox read-only` kun aproboj forigitaj kaj ŝema outputo, Claude Code kiel `claude -p --permission-mode plan` kun la sama ŝemo petita en la linio; ĝiaj ŝlosiloj kaj via SSH-agento estas retenitaj kiel `vikix agent` retenas ilin. Ĝi ricevas la taskon, la akceptaj kriterioj, kiel la laboristo indikis ilin, la decidoj jam faritaj, la propra konto de la laboristo kaj kie la branĉo lasis la propran de la projekto, kaj estas petita pri trovoj en unu formo: kie (`FILE:LINE`), kiom gravas (alta, meza, malalta) kaj unu aŭ du frazoj, kiujn persono agos pri ili. Ĝi funkcias aparte de via ŝelo, kiel la recenzado de transdono, kaj diras tion (recenzado legita de fluejo sub tempo limigita forigis la recenzanton kaj perdis ĝiajn trovojn la unua tago); `--here` atendas por ĝi. Ĉiu trovo iras en la *Recenzon* de la transdono, subskribite de la recenzanto (*codex 1234*), linio iras en la enirejon de la laborposteno kaj la loglibro de la registro, kaj la laborareo estas forigita; `vikix agents review --log wifi-fix` konservas la vortojn de la recenzanto. Laboristo laboranta legas la trovojn ĉe sia sekva voko de ilo, kiel ĝi legas ajnan noton; unu, kiu transdonis, sidas ĉe sia vokilo kaj ne faras ion, do ĝi estas vekita kiel `tell --now` vekas ĝin: petite eliri kaj rekomencite kun la linio de la recenzado kiel sia vokilo, ĝia konversacio estas konservita, kaj kiam ĝi ne povas esti (ĝia stato estas nekonata, neniu konversacio por rekomenci), la komputilo estas dirita, ke ĝi devas esti. La laboristo adresas ilin kaj markas ĉiu kun `vikix agents handoff --review-done N`. `--use` ne dirita prenas la provizon, kiu ne estas la de la laborposteno (la laboro de Codex estas legita de Claude, tiu de Claude de Codex); `--prompt "rigardu atente la repetan ciklon"` aldontas viajn vortojn. `vikix agents` kaj la Oficejo diras *sub recenzado de codex* sub la agento de la laborposteno dum ĝi funkcias, nomas la propran procezon de la recenzanto *recenzante* kiam ĝi havas terminalon, kaj rifuzas sekundan recenzadon ĝis la unua finiĝas; recenzanto, kiu fiaskas, aŭ respondas en prozo, estas konservita kiel ĝi estas (unu trovo enhavante ĝiajn vortojn, aŭ la fiasko en la loglibro) anstataŭe de perdi. Recenzado mem ĉe ĉiu transdono estas unu linio en `~/.config/vikix/office`, `review=codex`; ĝi estas forigita, krom se vi skribas ĝin, ĉar recenzado kostas la tempon de modelo kaj estas petita, ne supozita. La *Recenzu per...* butono de la Oficejo (la ŝlosilo `r`) komencas unu ĉe la elektita laborposteno, petante kiu recenzanto, kiam ambaŭ estas instalitaj, kaj la paĝo de la laborposteno montras la trovojn malfermajn aŭ adresitajn.

Ĉiu el la komandoj de la laboristo havas formon por la komputilo: en la ŝlosiloj de la laborposteno (`Super+Alt+d`) `w` komencas laboriston ĉe laborposteno (la laborposteno elektita en menuo, la tasko tajpita, nenio por sesio, poste kiu agento kaj ĉu ĝi povas puŝi, kiel nova laborposteno petas; laborposteno kun agento ĉe ĝi estas rifuzita en notifo), `t` testas la laboron de laborposteno, `p` paŭzas ĝian agenton aŭ lasas ĝin iri, `i` lasas noton, `x` forigas ĝin, ĉiu petante kiu laborposteno en menuo, kaj `Super+m` → *AI* havas la samon (*Agentoj: laboristo ĉe laborposteno*); la Oficejo havas ilin kiel butonoj.

### Tago kun la du provizantoj

La komandoj de la oficejo faras la tagon, kiun la dezajno en `plans/DESIGN-codex-integration.md` priskribas, unu registro de komenco ĝis fino. Claude Code dezajnas, Codex implementas, Claude recenzas, Codex korektas, la domo publikigas:

```sh
vikix agents desk vikix wifi-fix --task "design the Wi-Fi picker's rescan: a plan in plans/, no code" --use claude
vikix agents handoff wifi-fix                  # Claude's hand-in: status review, the design decided, its next step written
vikix agents handover wifi-fix --to codex      # Codex starts on that next step (or --task "..."), with the record; it implements, tests, hands in
vikix agents review wifi-fix --use claude      # Claude reads Codex's last commit: findings into the record, Codex woken with them
vikix agents handoff wifi-fix                  # the findings addressed (--review-done N), the tests' check fresh
.claude/release wifi-fix "the Wi-Fi picker rescans"   # the house's release step, from any shell; a fresh check on the commit spares its tests
```

La unua tia tago estis okazigita rekte en Vikixo, la 11-an de oktobro 2026, ĉe la paĝo `random-guide` (paĝo kun hazardaj gvidaj informoj, `vikix docs random`). Ĝi montras, laŭ la registroj de la paĝo, kion ĝi faris kaj kion ĉiu paŝo trovis:

```sh
vikix agents desk vikix random-guide --task "design a guide page at random: a plan in plans/, no code" --use claude
                                               # claude: the design (plans/DESIGN-random-guide.md), status review in 15 min
vikix agents handover random-guide --to codex  # codex got the task unchanged, "no code": it handed in review after 27 s, having done nothing
vikix agents dismiss random-guide
vikix agents worker random-guide "Implement plans/DESIGN-random-guide.md as it stands" --use codex
                                               # the dismissal's note reached the new worker at its first tool call: it obeyed, and stopped; and once more
vikix agents worker random-guide "Implement plans/DESIGN-random-guide.md as it stands" --use codex
                                               # the third codex implemented it: commit 7f9f534, its tests, status review
vikix agents review random-guide --use claude  # four findings (a guide's table, the deck's round, a dead line, apostrophes); run under a timeout, the reviewer was orphaned once
vikix agents worker random-guide "Address the review of your commit 7f9f534 ..." --use codex
                                               # the new worker found the findings, the defects and the decisions gone from the record; it put them back from its task
                                               # its tests/run.sh --changed hit the queue's deadline waiting for rescue; a named rerun passed
.claude/release random-guide "..."             # refused twice: a timing check in tests/house.sh at a load of 5.5 on 4 cores, then a screen test
```

El tio aperis ses problemoj en la laboro (la tasko de la transdono, la ricevanto de la notoj, la revizio en la antaŭgrundo, la trovitaj aferoj, kiuj ne estis legitaj tuj, la historio de la registro, la subskribo de la komandoj de la agento) kaj kvar kostoj (unu aldonita modifo estis testita kvar fojojn; modifo de du planoj estis testita dum tridek minutoj, la testanto atendas pri la publikigo; la tempo-kontrolo fiaskis pro la ŝarĝo; la solaj testoj daŭras kun la opcio `--changed` preter ilia limdato), ĉiu el ili estis korektita en la posta versio kun sia propra testo. La komandoj supre estas la maniero, kiel ĝi devas funkcii nun.

### Kiam laborotablo ne aperas

`vikix agents` ne montras novan linion kaj la laborspaco estas malplena: la laborotablo ne estis kreita. De la terminalo, la kialo estas afiŝata (*ne ekzistas projekto nomata...*: `vikix project list` listigas ilin, kaj ajna parto de la nomo funkcias); de `Super+m`, ĝi aperas kiel notifo. La kutima kaŭzo estas nomo, kiu ne estas la projekto (`novel-second-edition` kiam la projekto estas `novel`).

## La reguloj de la laborejo

Laborotabloj tenas la agentojn aparte. La reguloj diras, kio okazas, kiam ili renkontiĝas, kaj ili estas tenataj de Claude Code mem: agento Vikix, kiu startis, faras `vikix agents touch` antaŭ ĉiu redaktado (ĉi tio estas hakilo, donita al Claude Code por tiu sesio per `--settings`; nenio estas skribita al via propra Claude-agordo). La hakilo prenas kvinon de sekundo, ne petas nenion de la labortablo, kaj notigas la dosieron en la ĵurnalo de la laborejo, `~/.local/state/vikix/office/journal.jsonl`, kiu nur konservas la agentojn, kiuj ankoraŭ funkcias.

### Du agentoj sur unu dosiero

La agento en la laborspaco 5 baldaŭ redaktos `bin/vikix-wifi`, kiun la agento en la laborspaco 4 ŝanĝis en sia labora arbo kaj ankoraŭ ne aldonis. Claude Code haltas kaj petas vin, en sia propra fenestro de permeso:

> Vikix-laboro: alia agento laboras pri ĉi tiu dosiero. Claude 48213 (~/src/vikix-wifi-fix) ŝanĝis ĝin en ~/src/vikix-wifi-fix, kaj la ŝanĝo ne estis aldonita. `vikix agents clash ~/src/vikix-docs-pass/bin/vikix-wifi` montras ambaŭ ŝanĝojn. Ĉu permesi, ke ĉi tiu redaktu ĝin ankaŭ?

Vi havas tri respondojn. *Jes*: ambaŭ ŝanĝoj estas aldonitaj, kaj kiu ajn kunigas la ŝanĝojn due, tiu decidas pri la superkovro. *Ne*: ĉi tiu agento ricevas la mesaĝon, ke la redaktado estis rifuzita, kaj vi diras al ĝi kial (*lasu bin/vikix-wifi al la alia agento*). Aŭ rigardu unue:

```
$ vikix agents clash ~/src/vikix-docs-pass/bin/vikix-wifi
~/src/vikix-docs-pass/bin/vikix-wifi: 2 agents on it. Each one's change, uncommitted:

== claude 48213, changed in ~/src/vikix-wifi-fix ==
diff --git a/bin/vikix-wifi b/bin/vikix-wifi
...
== claude 51002, edited it ==
(no change in the worktree: the edit is still to come)

Which stays is yours to say: tell the other agent to drop its change, or let both go in and settle the merge.
```

La sama principo validas ene de unu labora kopio: kiam du agentoj uzas la saman komputilon kaj la dua redaktas dosieron, kiun la unua jam redaktis, la sistemo scias, kaj Claude Code demandas pri tio ( *Claude 48213 ankaŭ redaktis ĝin, antaŭ 4 minutoj*).

`vikix agents clash` simple listigas ĉiujn dosierojn, pri kiuj laboras du agentoj, kaj `vikix agents` markas tiun dosieron sub ĉiu agento:

```
  claude   ~/src/vikix-docs-pass (docs-pass, 1 uncommitted)   workspace 5   1 h    working
           on bin/vikix-wifi with claude 48213 too (vikix agents clash bin/vikix-wifi)
```

### Transiro

Agento povas redakti dosieron en la laborloko de alia agento, kaj povas iri al la fenestro de alia agento (la ilo MCP `focus_window`), sed neniam silente. La redaktado okazas, kaj la agento estas informata, per vortoj, kiujn ĝi legas antaŭ ol agi: *ĉi tiu dosiero estas en ~/src/vikix-wifi-fix, la dosierujo, en kiu Claude 48213 laboras, ne via; la transiro estas registrita; redaktu ĝin nur se la uzanto petis tion, alie lasu ĝin al tiu agento kaj informu la uzanton.* La transiro estas konservata en la registra datumbazo, kaj `vikix agents crossings` listigas la lastajn:

```
$ vikix agents crossings
1  2026-10-06 11:42  office/crossing  claude 51002 edited ~/src/vikix-wifi-fix/bin/vikix-wifi, in claude 48213's folder
```

Agento en via hejm-dosierujo ne posedas dosierujon, do nenio estas eniro al ĝi: ĉio sub la hejmo estus.

### Ŝeloj lasitaj dormi en ciklo

Komando, kiun agento tajpis, povas ripetiĝi, atendante linion, kiu neniam venos (`ĝis grep -q exit log; do sleep 20; faru`, kun la dosierujo nomata neĝuste): la agento daŭrigas ĉe sia komanda linio kaj la ciklo restas, ŝelo kun nur `sleep` sub ĝi, dum horoj. La Oficejo vidas la agenton ĉe sia komanda linio kaj diras, ke la terminalo povas esti fermita; `vikix agents` kaj la vico de laboristoj de la Oficejo diras, kiom da tiaj ŝeloj ĝi havas, kaj `vikix agents tidy` listigas ilin laŭ agento kaj finigas ilin per "jes" (`--yes` de skripto). Ŝelo kalkuliĝas post dek minutoj da nur dormo, kaj nur unu ricevas sian komandon en la linio (`bash -c`): skripto, kiu dormas inter siaj paŝoj, `tests/run.sh` atendas disponeblan tempon, faras ion. Ciklo, kiun la agento intencas konservi, atenta observo, ŝajnas la sama, do nenio estas finita sen peto; `vikix memory left` listigas ilin inter la eblaj opcioj.

### Kio tenas la regulojn, por ĉiu agento

`vikix agents hooks` diras tion klare, kaj la lastaj linioj de la transdono diras tion por la agentoj ĉe la laborposteno:

```
$ vikix agents hooks
claude    given to Claude Code by vikix agent at every start (--settings): pre-edit and pre-shell hooks
codex     hooks in ~/.codex/hooks.json: PreToolUse (apply_patch read for its files, Bash; a clash refused once, since it can't ask), PermissionRequest (a step out of the sandbox: off the desk denied, a routine command allowed, ...), UserPromptSubmit, Stop and SessionEnd (...); and Vikix's rules in ~/.codex/rules/vikix.rules (...). Seen firing here on 2026-10-10 (tests/codex.sh --live, Codex 0.160): UserPromptSubmit, PreToolUse, PermissionRequest (...) and Stop; SessionEnd not in codex exec
          not installed (vikix agents hooks codex --install links ~/.codex/hooks.json)
          not installed (vikix agents hooks codex --install links ~/.codex/rules/vikix.rules)
          trust: vikix agent passes --dangerously-bypass-hook-trust in your projects and in a folder of no repository (your home, Super+a's here) when the hook file is Vikix's ...
          ~/.codex/config.toml: sandbox_mode, approval_policy stand under [section], a table Codex doesn't read, so they do nothing; move the lines above the first [...] header (your file: Vikix doesn't write it)
opencode  a plugin on tool.execute.before (edit, write, bash): a refused edit throws, with the reason ...
          not installed (vikix agents hooks opencode --install links ~/.config/opencode/plugins/vikix-office.js)
gemini    a BeforeTool hook to merge into ~/.gemini/settings.json by hand ... unverified here
antigravity a plugin of Vikix's that vikix agent installs with agy plugin install ...: pre-edit and pre-shell hooks
aider     no hooks: instructions only (the guide it reads), and git
```

Tri niveloj, kaj la listo neniam asertas pli ol ekzistas. *Instrukcioj nur*: la agento legis la regulojn en sia gvidlibro, kaj git poste montras, kion ĝi faris. *Antaŭ-redakta hakoj*: la domaj reguloj funkcias antaŭ ĉiu redaktado kaj ŝelkomando kaj povas rifuzi ĝin; Claude Code kaj Antigravity CLI havas ilin el `vikix agent`, Codex kaj OpenCode ricevas ilin de adaptilo, kiun vi instalas unufoje (`--install` ligas dosieron de Vikix en iliajn dosierujojn kaj lasas vian propran dosieron netuŝita; la hakoj de Codex estis viditaj agi ĉi tie la 10-an de oktobro 2026, `tests/codix.sh --live`; la formo de Gemini estas el ĝia dokumentaro kaj estas markita kiel neprovita ĝis unu el ili agas ĉi tie). *Apliko de dosierujaj reguloj*: neniu el Vikix. Laborujo konservas kopiojn aparte, kaj la hako legas la vortojn de ŝelkomando; neniu el ili estas sandbox, kaj la paĝo ne nomas ilin tiel. Codex alportas sian propran sandbox, kaj en la *supervizataj* kaj *sendependaj* reĝimoj ([Reĝimoj](#reĝimoj-kiel-multe-codex-laboristo-estas-libera)) Vikix limigas ĝin al la labortablo; la transdono diras tion sub Codex ĉe la labortablo (*sandboxigita al sia labortablo*), kaj *neniu sandbox: senrestrikta, fare de la uzanto* kiam vi petis tion. Hako, kiun provizanto mankas, ne malhelpas alian funkcii: la transdono kaj la rekomenco estas la samaj por ĉiu agento.

**La hakoj de Codex**, `config/codex/hooks.json` ligita kiel `~/.codex/hooks.json`, estas la samaj reguloj ĉe la iloj de Codex, ĉar ĝiaj hakoj malsamas de tiuj de Claude Code en tri manieroj. Ĝia redakta ilo estas `apply_patch`, kies eniro estas la teksto de la ŝanĝo, do la hako legas ĉiun dosieron, kiun la ŝanĝo nomas (ĝia Dosiero por Ĝi, Aldonu Dosieron, Forigu Dosieron kaj Movu al linioj; ŝanĝo aplikita per Bash heredoc estas la sama) kaj juĝas ĉiu el ili kiel redakton: malpermesita de labortablo aŭ en la propra dosierujo de la projekto, indikita interŝanĝo, mesaĝo de `vikix agents tell` sendita. Ĝia hako ne povas demandi, do konflikto (alia agento en la dosiero) estas rifuzita unufoje, kun la kialo kaj `vikix agents clash FILE`, kaj la sama redakto ene de dek minutoj estas akceptita, Codex informis vin, kiel faras OpenCode. Kaj ĝi havas hakon ĉe ĉiu paŝo ekster sia sandbox (`PermissionRequest`, `vikix agents touch --for codex --escalation`): unu, kiu skribus en la propran dosierujon de la projekto, `~/vikix`, alia labortablo aŭ `~/.config/vikix/secrets/` estas rifuzita kun la kialo, sendepende de la reĝimo kaj kie ajn la agento estas (anstataŭ seance en via hejma dosierujo), do en *sendependa* la kontrolanto neniam vidas tiujn; rutinetera estas permesita, do neniu peto: la komandoj, kiujn la dosiero de la reguloj de Vikix permesas (`vikix snapshot` kaj la aliaj komandoj `vikix`, `git` en la branĉo, `tests/run.sh`, `.claude/release`), sub `timeout`, `env`, `nice`, `VAR=value` aŭ `bash -lc` ankaŭ, ĉiu komando de la linio estas unu el ili, nenio estas anstataŭigita en ĝi (`$(...)`), neniu re-direktado sed al `/dev/null`; ĉiu alia paŝo estas lasita al vi aŭ la kontrolanto, kaj kiam ĝi estas via, la noto de la agento atendas diras, ke Codex *atendas vian afirmon*. Tri pliaj hakoj donas la statojn: komencita rondo (`UserPromptSubmit`) estas notita en la ĵurnalo, do Codex, kiu pripensas antaŭ sia unua ilo-voko, estas *aktiva*; ĝia Hako Haltu petas al laboranto ĝian transdonon, kiel faras Claude Code, kaj skribas la noton *finis sian rondon* kun la lastaj vortoj de Codex, kaj halto akceptita estas *ĉe sia peto* ĝis la sekva rondo; ĝia SessionEnd notigas kiel ĝi foriris (Codex ne donas kialon, do la rekordo diras *foriris*). La paĝo de la transdono diras, kiu el ĉi tiuj Codex ĉe la labortablo havas: ĝiajn redaktojn viditajn per la hako, aŭ la dosiero de la hako instalita kaj neniu vidita ankoraŭ, aŭ nur instrukcioj. La ID de la sesio de Codex atingas la rekordon per la samaj hakoj, do `vikix agents resume` trovas ĝian konversacion sen ke vi tajpu ĝin, en ĝiaj dosieroj por la lanĉo aŭ, de Codex 0.160, ĝia stokaĵo de la konversacio (`session_index.jsonl`, `thread_history_1.sqlite`, nur legebla).

La hako notigas redakton antaŭ ol ĝi okazas, do notiĝo en la ĵurnalo estas propono; kio fakte ŝanĝiĝis estas tion, kion diras git (`vikix agents` nombras la nekomititajn dosierojn, `vikix agents clash FILE` montras la diferencon). Neniu el ĉi tio solvas la ŝanĝojn de alia agento, respondas al ĝiaj petoj, haltigas ĝin aŭ fermas ĝian labortablon: tiuj estas via.

### Kion la reguloj ne faras

Konflikto kaj interŝanĝo ne haltigas nenion memstare: la tiu, kiu decidas, estas vi, ĉe la peto de Claude Code (la aldonaĵo de OpenCode povas nur rifuzi aŭ permesi, do ĝi rifuzas konflikton unufoje kaj permesas la saman redakton kiam ĝi estas provita denove ene de dek minutoj, la agento informante vin). Nur la regulo de la labortablo rifuzas rekte, kaj ĝi nomas la manieron eliri. La reguloj validas por Claude Code, Antigravity CLI kaj Codex, kaj la aldonaĵo de OpenCode tenas la redaktan hakon; Gemini CLI kaj Aider ne havas tian hakon, do konflikto kun unu el ili estas vidita poste, en `vikix agents` kaj `vikix agents clash`, ne antaŭ la redakto, kaj nenio malhelpas al ili aliri la propran dosierujon de la projekto. La hakoj de Antigravity ne povas diri al la agento ion sen decidi, do interŝanĝo petas al vi, kun la kialo, kie Claude Code estas informita kaj daŭras; ĝia hako estas aldonaĵo de Vikix, kiun `vikix agent` metis en lokon (`agy plugin list` montras `vikix`), do ĝi restas inter sesioj, kaj `agy plugin disable vikix` forŝaltas ĝin. Claude Code-sesio komencita antaŭ la ĝisdatigo, aŭ per `VIKIX_OFFICE=0 vikix agent`, ankaŭ ne havas hakon; unu komencita antaŭ la regulo de la labortablo havas la redaktan hakon, sed ne tiun pri la ŝelkomandoj, ĉar Claude Code legas siajn hakojn ĉe la komenco. Ŝelkomando, kiu skribas per programo, kiun la hako ne konas (propra Python-skripto de la agento), pasas. Kaj ili konas dosierojn, ne signifon: du agentoj redaktantaj diversajn dosierojn de unu funkcio ne estas konflikto por ili.

## De la flanko de la agento

La kapablo de Vikix diras al ĉiu agento la samajn regulojn, do vi povas teni ĝin je ili: rigardu `vikix agents` antaŭ ŝanĝi dosierojn en dosierujo, en kiu alia agento estas; prenu labortablon antaŭ tuŝi deponejon (`vikix agents sit`), komitigu tie en tiu branĉo kaj lasu la propran dosierujon de la projekto netuŝita; legu la transdonon kiam vi aliĝas al labortablo, kaj skribu ĝin kiam vi transdonas laboron reen, kiam vi estas blokita, kaj kiam vi finis; kiam la laboro estas kunfandita, diru tion kaj permesu, ke vi fermu la labortablon, kaj unufoje la labortablo estas fermita (per publikigo aŭ fare de vi), diru tion al vi en ĝia lasta mesaĝo, kun kio restas por vi fari; neniam haltu, sendu signalon aŭ tajpu en la fenestron de alia agento, kaj neniam respondu al demando, kiun alia agento petis al vi. Agento kun la iloj de MCP havas `agents` por vidi la aliajn, `handoff` kaj `handoff_update` por la rekordo de la labortablo, kaj `focus_window` por iri al unu, kaj la lasta estas registrita kiel interŝanĝo.

## Ankoraŭ ne tie

Laborloko kaj koloro de la baro ĉiu; transdonante fenestron de unu agento al alia; listo de permesoj por ĉiu agento. Supera agento, kiu skribas planojn por ke vi aprobu ilin (neniam unu, kiu ekzekutas ilin). La formo de la hako de Gemini CLI kaj ĝia rekomenco, provitaj sur aparato, kiu havas ilin; tuta tago kun la du provizantoj sur Vikix mem ([pli alte](#tago-kun-la-du-provizantoj)), kaj la reĝimo por la aliaj provizantoj. Ĉiu venos kiel ĝi estas bezonata; la pecoj, kiuj estas ĉi tie, estas tiuj, kiuj la unuaj semajnoj kun pluraj agentoj petis.

## La Oficejo

`Super+m` → **AI** → **Oficejo: taskoj, labortabloj kaj agentoj**, la paletro de
**oficejo**, aŭ `vikix agents office` malfermas apartan Emacs-kadron. Ĝi
heredas la temon de Vikix de Emacs. La ekzistanta menuo de la agento kaj la
komandoj de la terminalo restas disponeblaj; sen Emacs, la komando malfermas
la ekzistantan menuon de la agento. Konversacioj restas en la terminalo de
ĉiu agento. Malfermita dum ĝi jam estas malfermita, la Oficejo venas al la
antaŭo anstataŭe: la labortablo iras al sia fenestrenespaco, aŭ alportas
ĝin ĉi tien de kaŝita.

La Oficejo konektas al via ekzistanta Emacs-servero kaj malfermas laŭvice
X11-fenestron en la lanĉa labortablo, inkluzive kiam Emacs funkcias kiel
daimon kun nur fenestroj de la terminalo. Se ĝi estas nehavebla,
okupita aŭ raportas eraron, la lanĉilo diras kial; ĝi neniam startigas
alian Emacs aŭ restarigas la duan kopion de via konservita sesio. En via
ekzistanta Emacs, uzu `M-x server-start` se ĝia servero ne funkcias, tiam
provu denove. Heredita agordo `ALTERNATE_EDITOR` ne povas startigi duan
ekzempleron ĉi tie.

**En terminalo.** Sen ekrano, sur senkapa servero aŭ super SSH, aŭ kun
`vikix agents office --tty` ie ajn, la Oficejo malfermiĝas en la terminalo,
en kiun vi tajpis: `emacsclient -nw` faras tekstan kadron de via funkcianta
Emacs tie, kun la samaj du paneloj (la labortablo sub la listo kiam la
terminalo estas pli mallonga ol cent kolumnoj), kaj `q` fermas tiun kadron,
do la ŝelo revenas. Ĝi estas la sama Emacs kaj la sama servero: se neniu
funkcias, la sama mesaĝo kiel sur la labortablo, kaj ankoraŭ neniam dua
Emacs. Ĉi interne de Emacs, `M-x vikix-office-open-here` malfermas ĝin en
la kadro, en kiu vi estas, kaj `q` tiam metas la fenestrojn de tiu kadro
reen kiel ili estis.

Ĉe la supro, **Planujoj**-skatolo kiam plano kuris aŭ estis skribita
(`vikix agents plan`): plano, ĝia grupo, projekto kaj ĉu ĝia rulanto
funkcias, linio, labortablo diras, kie la ĉeno de tiu labortablo staras kaj
kio bezonas vin; labortablo de plano diras, kiu en sia linio **Plano**.
Plano skribita kaj ankoraŭ ne rulita (`plan new`, aŭ **Nova plano…**) estas
*borfado* tie, kun la taskoj ankoraŭ tenante la ŝablonajn liniojn `EDIT:` sub
*Bezonas vin*. Ĉiu plano finiĝas per la agoj, kiujn ĝia stato prenas, ĉiu
`vikix agents plan` de la Oficejo: **Rulu** por borfado, kies vortoj estas
skribitaj (**Rulu denove** por unu haltigita aŭ kies rulanto ne funkcias: ĝi
daŭras), **Paŭzu** kaj **Haltu** dum ĝi funkcias, **Daŭrigu**, kiu malfermas
la dosieron de la plano en la panelo de la labortablo (`RET` sur labortablo
re-donas la panelon), kaj **Registru**, kion la rulanto faris. Plano farita,
ĉiu labortablo de ĝi liberigita, lasas la skatolon por la Arkiva paĝo, kie
**Planujoj faritaj**-skatolo listigas ĝin kun kiam ĝi finiĝis kaj ĝiaj
labortabloj liberigitaj, konservante **Redaktu** kaj **Registru**; la
Arkiva Butono nombras la planujojn faritajn aparte de la rekordoj (*Arkivo (3,
1 plano)*).

La maldekstra flanko estas **la tabulo**: kvin sekcioj, numeritaj, skatolo
ĉiu, linio, tasko (*La laboro: taskoj kaj ilia historio*, pli alte), kaj la
titolo de la kadro nombras tion, kio bezonas vin (*La Oficejo (3)*):

1.  **Bezonas pri atento** (`1`): la elementoj, ĉiu el kiuj estas afero, kiun vi povas fari
    ion pri (*Bezonas pri atento kaj decidoj*, sube), kun ĝiaj agoj
    kiel butonoj.
2.  **Funkcianta** (`2`): la taskoj, kiuj funkcias, atendas decidon aŭ estas
    en revizio, ĉiu en vico: `#104 claude · vikix/wifi-fix · 35 min · funkcias ·
    la selektilo de Wi-Fi devas unue skani`, la lanĉa numero kaj la
    provizanto unue, do du Claude-laborantoj estas distingataj, poste la
    tabulo, kiom da tempo, la stato en unu vorto, la vortoj de la
    tasko. Laboranto ĉe sia peto pri tasko ankoraŭ malferma diras *malaktiva, tasko malferma*; unu paŭzita, testanta aŭ
    tenata de la atenda vico, diras tion. Sub la linio, la vicoj de la
    tabulo kiel antaŭe: la projekto kun la labra spaco de ĉiu aktiva
    laboranto klare etikedita (`claude · labra spaco 2`; pluraj laborantoj
    ĉiu tenas sian propran etikedon; unu sen fenestro de labra spaco diras
    tion, ne disponebla labra spaco diras *nekonata labra spaco*), **Tasko**, **Aktiva** (kio estas observata, krom la
    registrita **Transdono** kun la taksado de la laboranto),
    **Aperigo** dum ĝia branĉo estas aperigita, **Plano** kiam ĝi estas
    la tabulo de plano, **Sekva** kaj **Antaŭa** (la laborantoj antaŭ
    ĉi tiu tasko, plej nova unue; tri en la vico, ĉiuj sur la paĝo), ĝiaj
    **Testoj** kun **Preterlasu testojn** dum ili funkcias, kaj **Nova
    laboranto…** kiam ĝi staras sen iu ajn ĉe ĝi. Tabulo kun laboranto
    ĉe ĝi kaj sen rekordo de tasko ankaŭ estas ĉi tie, dirante tion;
    dosierujo en kiu laboranto simple funkcias (unu komencita en `~`) estas
    *ne tabulo*.
3.  **Vico** (`3`): la resumigo de la planilo (laborantoj en uzo de `at_once`,
    aŭtomate ŝaltita aŭ ne, *planilo paŭzita de vi*), *Sekva:… ĉar…* kun
    **Komencu sekvan**, poste la vicoj de taskoj en la vico, ĉiu kun sia
    pozicio, prioritato, la tabulo por krei kaj kial ĝi atendas, kaj ĝiaj
    agoj kiel butonoj (Komencu, Funkcigu sekvan, Supre, Malsupre,
    Prioritato, Prokrastu, Forigu); post ili la taskoj pretaj sed ne en
    la vico (**Metu en vicon**) kaj la proponoj, kiuj atendas vian
    aprobon. La Vico konservas sian ordon, sendepende de la ordigo.
4.  **Blokita** (`4`): `#107 codex · testoj de instalilo · 2 horoj · blokita
    ĉe laboranto · …`, kaj sub ĝi kial: *laboranto haltigita antaŭ 2
    horoj: eliro 1, 3 ne komenigitaj*, *atendas por t-…*, aŭ la
    kaŭzo registrita; **Preparu** permesas al la planilo havi ĝin denove.
5.  **Finita** (`5`): la lasta tago, kun la aperigo (*aperigis 0.72.26*), *akceptita, ne ankoraŭ aperigita* por tasko, kies
    laboro estas en kaj kies aperigo ne estas, *nuligita*; sub ĝi kiom
    da tempo ĝi prenis, kaj kie ĝi finiĝis kontraŭ la taksado de la
    laboranto. Pli maljunaj estas en la Arkivo.

`s` ŝanĝas la ordigon de Funkciantaj kaj Finitaj (orda laŭ lanĉo, la plej
maljuna unue, estas la defaŭlto; plej nova unue; kreita; lasta agado;
prioritato; stato; projekto; provizanto), la titolo de la skatolo diras
ĝin. Ĉiu stato estas vorto, kaj koloro neniam tenas sole: tabulo, kies
faktiga fenestro bezonas vin, estas desegnita en la koloro, kiun la
labra spaco donas al tiu faktiga fenestro (ĝia linio kaj vico Aktiva,
kaj la linio de la laboranto sur la paĝo): unu dum la laboranto atendas
vin, alia kiam ĝia tabulo estas aperigita kaj atendas por `gup`, la
tria kiam tio estas aperigita kaj la faktiga fenestro povas esti
fermita; la temo, `agent_asks`, `agent_released` kaj `agent_pushed`,
aŭ la propraj avertoj, sukceso kaj konstantaj vizaĝoj de Emacs, sen
paletro. Ĉiu skatolo estas desegnita al la larĝo de ĝia fenestro,
regulo inter ĝiaj vicoj, kaj desegnita denove kiam la fenestro estas
ŝanĝita; faktica fenestro, kiu ne povas montri la skatolaajn
karakterojn, ricevas ASCII-ajn. Tabulo sen io sur ĝi ankoraŭ desegnas
siajn kvin sekciojn, ĉiu dirante ke ĝi estas malplena, kaj diras kie
komenci.

La **tabuloj sen laborantoj** (tabulo sen malferma tasko kaj sen iu ĉe
ili; unu kies tasko estas preta kaj ne en la vico, diras tion, kun
**Metu en vicon**) kaj la tabuloj **fermitaj hodiaŭ** (`vikix-laborantoj fermas`, aŭ la aperigo, kiu forigis
ĝin: plej nova unue, kiu fermis ĝin kaj kiam, nenio por fari ĉe ĝi,
*Forgesu tiun rekordon…* sur ĝia paĝo) estas sur paĝo por si (la butono
**Tabuloj kaj fermitaj**, aŭ `K`; **Reiru al tabuloj**, aŭ `K` denove,
revenigas); post tago la rekordo de fermita tabulo estas en la Arkivo,
la tria paĝo (`A`). Kiam nenio funkcias kaj nenio estas en la vico, la
tabulo diras, ke la tabuloj estas sur tiu paĝo.

La **paĝo de la tasko** (`RET` sur vico, aŭ klako) estas la dekstra
pano: la skatolo **Rekordo de la tasko** unue (la ID; la origino kaj
prioritato; la stato, kiun la oficejo registris, kun kialo, subskribita;
la tabulo, aŭ la tabulo por krei; kion ĝi atendas; la lanĉo kun sia
numero; la stato de la laboranto, kiel ĝi estis observita, kun kie ĝi
estis legita kaj kiom certe; la tempoj, *nekonata* kie la rekordo neniam
havis unu; la decidoj malfermaj kaj responditaj, ĉiu kun **Respondu…**),
poste la vortoj de la tasko, kion la laboranto diras, la stato de Git,
la kontrolitaj, la laborantoj antaŭe, la aktivaj laborantoj kaj la
konservitaj konversacioj kiel antaŭe. **Historio** (`h`) malvolvas la
eventojn de la tasko sur la paĝo, plej nova unue, la samaj vicoj, kiujn
`vikix-laborantoj tasko` presas, kaj refoldas ilin. Tasko, kiu ankoraŭ
ne estas ĉe tabulo (en la vico, aŭ preta kun la tabulo por krei
nomita), havas sian propran paĝon: ĝia rekordo kaj la agoj de la vico.
La agoj kiel butonoj estas nur tiuj, kiuj aplikiĝas, kiel antaŭe, kaj
**Iru al laboranto** (`a`) restas unu klavo de ĉiu vico.

La skatolo **Kion la laboranto diras** estas la transdono kiel la
laboranto skribis ĝin, kiun Vikix ne kontrolas: la stato kun tio, kion
ĝi signifas (*revizio · la laboranto petas vin rigardi ĝian laboron*),
la taksado kontraŭ la horloĝo, la resumigo kaj la sekva paŝo, poste la
kriterioj, la decidoj, la difektoj kaj la trovoj de la revizio kiel
punktoj, ĉiu vico subskribita en la ombro ĉe ĝia fino kun kiu skribis
ĝin kaj kiam; tabulo kies laboranto ankoraŭ ne skribis ion, diras tion
en unu linio. Ne disponebla aktiva malkovro estas **nekonata**, neniam
pruvo, ke laboranto haltis. Tabuloj sen transdonoj ankoraŭ aperas.
Dosierujo, en kiu laboranto simple funkcias (unu komencita en `~`, aŭ en
propra dosierujo de la projekto), ricevas vicon ankaŭ, markita kiel **ne
tabulo**: ĝia linio estas la dosierujo, ĝia paĝo nomas la laborantojn,
kio funkcias tie, kaj Iru al laboranto kaj Fermu laboron de laboranto
kiel ĉe tabulo. Ĝi ne havas staton de Git, neniu transdono kaj neniu
Daŭrigu, ĉar ne estas tabulo por daŭrigi; `vikix-laborantoj sidas
PROJEKTO TEMA` el la propra ŝelo de la laboranto, starigas ĝin ĉe unu.
Forigitaj laborarboj sen aktiva laboranto iras en la **Arkivo**,
apartigita de la nuntempaj tabuloj, kiam ilia tago en Fermitaj finiĝas
(sur la loko, kiam la laborarbo foriris sen ke la tabulo estas fermita).
Transdono, kiu diras "finita" sole, ne arkivas ekzistantan tabulon kaj
ne forigas ajnajn dosierojn.

**Aperigoj.** Sub la tabulo, skatolo **Aperigoj** listigas la aperigojn
en via projekto, kiel `.claude/release --queue` faras: la temo de ĉiu
el ili, ĝia paŝo el la sep (*paŝo 4 el 7: testado (ŝanĝita)*), de kiam,
kaj kiom da tempo restas, kun la projekto kaj la linio, kiun ĝi alportas;
la unu, kies vico ĝi estas, venas unue, tiuj, kiuj atendas la blokon,
post ĝi, ĉiu dirante, kun kiu ĝi estas malantaŭ. Sub la linio, la sep
paŝoj kiel strio, *kontrolas › origino › sur ĉefa › testado ›
kunfandado › versio › tabulo*, la unu, kiu estas en progreso, en
grasa kaj tiuj, kiuj estis faritaj, en la ombro (paŝo, kiu ne aplikiĝas,
neniu origino aŭ nenio por refari, estas preterigita, do la nombroj
estas la samaj en ĉiu aperigo). Dum aperigo testas, ĝiaj testoj sekvas
kiel tablo, ĉiu vico, kiel la skatolo Testado desegnas kuron: finita,
en progreso kaj en la vico, kiom da tempo ĉiu prenis kaj ĝia taksado,
de la lasta fojo, ke ĝi pasis sur tiu maŝino. La taksado de la tutaĵo
estas la testoj plus la paŝoj post (*ĉirkaŭ 3 min restas*); antaŭ ol
la testoj komenciĝas, ĝi diras, ke la testoj decidas, post ili *sub
minuto*. Tabulo, kies branĉo estas aperigita, diras la saman linion en
vico **Aperigo** sub ĝia Transdono, kaj en ĝia stato de Git. La skatolo
estas legita de la notoj, kiujn ĉiu aperigo konservas pri si mem
(`.git/vikix-release-queue/`, unu dosiero estas en progreso, ok
lini'); noto de aperigo, kiu finiĝis, estas preterigita, neniam
forigita. Kiam neniu estas en progreso, deponejo, kiu aperigis
antaŭe, ricevas la linion *Neniu aperigo en progreso*, kaj maŝino,
kiu neniam aperigis, ne montras ion.

Klaku **Arkivo** (aŭ premu `A`) por vidi historiajn taskojn,
transdonojn kaj kontrolitajn, la trian paĝon, kaj super ili la faritajn
planojn. Arkivitaj eniroj diras, ke neniu ago estas bezonata; Iru al
laboranto, Daŭrigu kaj Fermu laboranton estas forestaj. Iliaj malnovaj
sekvaj agoj estas historiaj, ne novaj instrukcioj. **Forgesu tiun
rekordon…** forigas tiun unu rekordon post konfirmo (kiel
`vikix-laborantoj transdono forgesu` faras); ĝiaj dosieroj, branĉo kaj
konservitaj konversacioj restas. **Reiru al tabuloj** (`A` denove)
revenigas al la nuntempa laboro. Ĉiu paĝo kalkas la vicojn de tiu
paĝo; la Nova tasko, Nova tabulo, Nova plano kaj la butonoj Nova
projekto, la skatolo Aperigoj kaj la skatolo Planoj estas la unuaj en
la unua paĝo, la skatolo Faritaj planoj en la Arkivo.

**Purigu arkivon** permanente forigas la arkivitajn rekordojn de tabuloj
post konfirmo. Ĝi re-kontrolas la precizajn rekordojn, padojn de
laborarbo kaj aktivajn laborantojn; ŝanĝitaj rekordoj, re-malfermitaj
tabuloj aŭ ne disponebla malkovro bezonas refreŝigon kaj novan
konfirmon. Dosieroj de projekto, branĉoj kaj la konservitaj
konversacioj de la provizantoj restas netuŝitaj. Ne ekzistas aŭtomata
tempo aŭ limo de grandeco.

Klaku vicon, aŭ uzu `n`/`p` por elekti ĝin. `RET` eniras ĝian paĝon;
`C-x o` movas inter la panojn; `1` ĝis `5` iras al sekcio de la tabulo,
kun ĝia unua vico elektita. Nur disponeblaj agoj estas montritaj.
`Tab` vizitas la butonojn, `T` kreas novan taskon, `N` novan tabulon, `L`
skribas novan planon, `R` kreas novan projekton, `w` komencas laboranton
ĉe la elektita tabulo, `a` iras al laboranton, `c` daŭrigas tabulon, `P`
paŭzas ĝian laboranton aŭ lasas ĝin iri, `t` faras ĝiajn testojn (**Preterlasu testojn** sur la vico finas ilin dum ili funkcias), `r`
petas al alia provizanto revizii ĝian lastan komenton, `i` lasas
noton al ĝia laboranto, `C` fermas tabulon, `s` ŝanĝas la ordigon, `h`
malvolvas la historion de la tasko, `H` malfermas ĉi tiun ĉapitron de
la manlibro, `g` refreŝigas kaj `q` fermas la Oficejon. Sur la elektita
tasko: `!` faras ĝin sekve, `+` kaj `-` movas ĝian prioritaton, `M-p` kaj
`M-n` movas ĝin supren kaj malsupren en ĝia vico, `d` prokrastas ĝin, `k`
nuligas ĝin, `S` komencas la sekvan en la vico, `Q` metas pretan en la
vicon, `D` respondu ĝian decidon, `y` akceptas ĝian revizion kaj `b`
sendas ĝin reen kun noton. La respondo de butono (*lasu iri, paŭzita 3
min; claude 48213 iras ĉe sia sekva voko*) restas en la kaplinio super
la refreŝigoj, kiuj sekvas, ĝis `g` aŭ la sekva butono, kaj la vico
estas desegnita tuj, do tabulo lasita perdas sian *paŭzita de* kaj ĝia
Butono Iru diras Paŭzu denove. Vico diras, kiam ĝia tabulo estas
paŭzita kaj de kiu, kiam ĝiaj testoj funkcias, kiu estas reviziante
ĝin, kaj kiom da notoj atendas por ĝia laboranto; la detaloj diras, kiel
la lasta laboranto foriris. Oficejo, kiu ne montras tabulon kaj
kaplinion nomantan *versio de la kontrolpunkto*, havas paĝon pli malnovan
ol ĝia kreado: Emacs ŝarĝis `vikix-oficejo.el` antaŭ ol ĝisdatigo
alportis pli novan `vikix-laborantoj oficejo --json`. Ŝarĝu la
dosieron denove (`M-x ŝarĝu-dosieron ~/.local/share/vikix/emacs/vikix-oficejo.el`)
aŭ restartigu Emacs. Detaloj konservas la taskon de la uzanto,
subskribitan konton de laboranto, observitan staton de Git, raportitajn
kontrolitajn kaj disponeblecon de konservitaj konversacioj aparte.
**Revizio ne signifas kunfandita.** Nova kontrolo signifas, ke ĝia
registrita kodo kongruas kun la nuntempa observado; ĝi ne sendepende
verifas la raporton de la laboranto.

**Iru al laboranto** permesas al vi elekti, kiam pluraj laborantoj
kunhavas tabulon. Ĝi re-rezolvas la elektitan procezon tra la labra
spaco antaŭ ol ĝi koncentriĝas. Laboranto sen fenestro de labra spaco
estas identigita kaj ne povas esti koncentrigita ĉi tie.

**Fermu laboranton** (`x`) petas, kiu laboranto kiam tabulo havas
plurajn, kaj poste petas konfirmon antaŭ ol petas ĝian eliron.
Funkcianta laboro haltas; la tabulo, branĉo kaj dosieroj restas por
pli poste. La identeco de la procezo estas re-kontrolita tiel, ke
malfreska vido ne povas fermi anstataŭigan procezon. Se ĝi ankoraŭ
eliras post tri sekundoj, la Oficejo diras tion; ĝi ne forcastas ĝin.
`q` fermas nur la fenestron de la Oficejo.

**Nova tasko…** (`T`, super de la tabulo) estas formo por aparta tasko,
kun nenio komencita de ĝi: la vortoj; skribtablo, kie neniu laboras
(ĝia projekto estas la tasko), aŭ la projekto kaj la temo de la skribtablo,
kiun la planilo kreas por ĝi (depotujo bezonas unu); la prioritato (normala
krom se vi diras); la taskoj, kiujn ĝi atendas, laŭ ID; la elektoj de la
laboranto, kiel la formo de la skribtablo montras ilin (la agento, loka
modelo, povas povi, neniu testado memstare, la reĝimo); kaj **Vigu ĝin**,
senmarkita: markita, la tasko tuj eniras la vicon, por **Komencu la
sekvan** aŭ `auto=on`; senmarkita, ĝi estas preta, kaj **Vigu ĝin** en
ĝia vico (`Q`) vicos ĝin poste. Ĝi transdonas siajn vortojn al
`vikix agents office --new-task` kiel ili estas, kiu malakceptas, en la
propra kaplinio de la formo, skribtablon kun jam malfermita tasko, depotujon
sen nek skribtablo nek temo, kaj ĉion krom la uzanto, kiu kreas ĝin.

**Nova skribtablo…** (`N`, super de la tabulo) kaj **Nova laboranto…** (`w`,
en la vico de skribtablo kaj en la detaloj de skribtablo, kie neniu
laboras) estas formularoj, desegnitaj en la panelo de la skribtablo kaj en
la terminalo. Nova skribtablo petas la projekton (menuo de
`vikix project list`, klako aŭ `RET` sur la `[elekto]` malfermas ĝin; ĝi
ĉiam estas elektita, neniam supozita el la elektita skribtablo), la temon
(unu aŭ du vortoj; depotujo bezonas unu, projekto, kiu ne estas depotujo,
funkcias en sia propra dosierujo), kaj la taskon; nenio tajpita por la
tasko estas nur la skribtablo, por laboranto poste. Nova laboranto petas
nur la taskon; nenio tajpita estas sesio, agento por paroli, la
registraĵo restas kiel estas; skribtablo kun agento ĉe ĝi ne bezonas
duan, kaj diras tion. Ambaŭ havas la elektojn de la laboranto kiel
kontrolujoj por marki: la agento (via, aŭ ajna `vikix agent --list` havas,
neinstalita donas sian instalilon en la terminalo), *sur modelo sur ĉi tiu
poŝkomputilo* (tiuj, kiuj povas, estas nomitaj), *povas povi, kiel vi*
(via SSH-agento kuniras, kiel `--push` faras), kaj *neniu testado memstare
kiam ĝi transdonas* (`--no-tests`: la butono Test ankoraŭ faras ilin).
`TAB` moviĝas inter la kampoj, `C-c C-c` estas la butono, `C-c C-k`
malvalidigas. La formo transdonas siajn vortojn al `vikix agents desk` aŭ
`vikix agents worker` kiel ili estas, kiuj respondas en la kaplinio de la
Oficejo; malakcepto (projekto ne elektita, temo, kiu ne donas nomon de
branĉo, agento ĉe la skribtablo jam) estas dirita en la propra kaplinio
de la formo kaj lasas la formon malfermita por korekti. La terminalo de
laboranto malfermiĝas sur la labortablo, do de terminalo Oficejo sen
ekrano, nur la skribtablo povas esti kreita.

**Nova plano…** (`L`, super de la tabulo) skribas planon el ŝablono kiel
formo, desegnita, kie la formularoj de la skribtablo estas, ĝiaj propraj
agordoj en kesto kun regulo inter ili: la ŝablono (Vikix kaj via, ĉiu
kun sia linio pri si; klako aŭ `RET` sur la `[elekto]` malfermas la
liston), la projekto (nur la depotujoj, ĉar la skribtabloj de plano estas
laborarboj), la nomo de la plano (vorto: la nomo de la dosiero sub
`~/.config/vikix/plans/`, kaj ĝiaj skribtabloj), laborantoj tuj kaj la
pordo (malplena, la ŝablono). Nenio estas elektita por vi. Post kiam
ŝablono estas elektita, ĝiaj taskoj aperas kiel la kampoj de la formo,
en ordo, ĉiu tasko en sia propra kesto (denove fermita dekstre, kiam
ĝiaj kampoj kreskas) kun regulo inter ĝiaj partoj: la nomo de la tasko,
skribtablo (`temo` fariĝas la nomo de la plano), kaj la taskoj, kiujn ĝi
atendas, ĝiaj vortoj, ĝia linio de publikigo (unu linio, kion la
publikigo alportas: kion la komito kaj etikedoj de la publikigo diras
post la versio, `Vikix 0.72.44: tiu linio`; por la lasta tasko ĉe
skribtablo, ĉar skribtablo estas publikigita unufoje, ĉe la fino de ĝia
ĉeno), ĝiaj linioj de akcepto, la agento kaj ĝiaj ŝaltiloj (loka
modelo, povas povi, neniu testado) kaj la reĝimo. Linio, kiun la ŝablono
petas, ke vi skribu (`EDIT:`), estas la sugesto sub malplena kampo, kun
ekzemplo post *ekz.*, kiu montras la formon; ajna alia vorto de la
ŝablono estas la kampo, por redakti. **Aldonu taskon** metas malplenan
taskon post la cetero, kaj **Forigu ĉi tiun taskon** forigas unu, la
tajpita restas. **Skribu planon** skribas la dosieron kun viaj vortoj en
(`vikix agents office --plan … --tasks`, la taskoj kiel JSON sur ĝia
eniro; la kaplinio de la ŝablono estas konservita, do la dosiero ankoraŭ
klarigas sin) kaj malfermas ĝin en la panelo de la skribtablo; la kesto
de Planhava ĝin kiel provon kun ĝia **Ekzekutu**. La vortoj de tasko
restinta malplena konservas la linion `EDIT:` de la ŝablono, por la
dosiero poste, kaj la provo diras tion sub *Bezonas vin*. Nenio funkcias
ĝis Ekzekutu. Nomo prenita, tasko sen nomo aŭ vortoj, aŭ ŝablono, kiu
ne legas kiel plano, estas dirita en la propra kaplinio de la formo kaj
lasas la formon malfermita.

**Nova projekto…** (`R`, super de la tabulo) kreas projekton el formo,
desegnita, kie la aliaj formularoj estas: `vikix project new` kun ĝiaj
vortoj. La nomo (vorto: la dosierujo sub `~/src`, aŭ la unua
`root=` de `~/.config/vikix/projects`, kaj la nomo de la depotujo), kie
ĝi iras (nenio estas elektita por vi: *GitHub, publika*; *GitHub,
privata*; *Ĉi tie, depotujo*, git-depotujo sur ĉi tiu maŝino sole; *Dosierujo*,
dosierujo kun protokolo kaj sen git), la titolo (la kaplinio de la
protokolo kaj la README; malplena, la nomo kiel vortoj), priskribo (unu
linio: la dua linio de la README kaj GitHub's About; por depotujo) kaj la
unua paŝo (la linio *Sekva* de la protokolo, kiun la formo Nova
skribtablo tiam montras), kaj *Apartigu protokolon*, kiu konservas la
protokolon en `~/src/project-logs/NOMO`, ekster la depotujo, por publika
ekzemplero, kies protokolo estas via. Depotujo ricevas README, la
protokolon, se ne apartigita, kaj unu komito en via defolta branĉo de
git (`main` se ĝi nenion diras). Sur GitHub, ĝi estas kreita per `gh`
kun la priskribo kiel ĝia About, la origino estas agordita kiel gh
agordas ĝin, kaj puŝita unufoje per la eniro de gh per HTTPS, do via
pasvorto de SSH-ŝlosilo neniam estas petata; la formo diras, kun kiu
konto gh estas enirita, kaj malakceptas la du elektojn de GitHub, dirante
kial, kiam gh ne estas instalita, ne estas enirita (`gh auth login`) aŭ
GitHub ne estas atingebla. La Oficejo atendas ĝis du kaj duona minutoj
por la puŝo. La lasta linio de la fonoprozesso (la URL de GitHub, aŭ
kie la protokolo estas) estas la kaplinio de la Oficejo, kaj la projekto
estas en la listo de la formo Nova skribtablo tuj. Nomo prenita sur
GitHub, aŭ dosierujo, kiu havas protokolon aŭ estas en depotujo jam,
estas dirita en la propra kaplinio de la formo kaj lasas la formon
malfermita; malakcepto de GitHub lasas la depotujon ĉi tie, kun la linio
`gh repo create` por ekzekuti poste.

**Gvidilo** (`H`, super de la tabulo) malfermas ĉi tiun ĉapitron de la
manlibro de Vikix (`info vikix`, la, kiun `vikix update core` skribas
al `~/.local/share/info/`) en la panelo de la skribtablo; `RET` sur
skribtablo redonas la panelon. Sen la instaleita manlibro, la butono
diras tion.

**Fermu skribtablon…** (`C`, en la detaloj de skribtablo, kie neniu
laboras) estas `vikix agents close` de la Oficejo: post jes, la
laborarbo estas forigita kaj la branĉo forigita kiam ĝia laboro estas en,
tenita kaj dirita alie, kaj la registritaĵo estas tenita kiel fermita.
Skribtablo kun nekomititaj dosieroj petas sian propran jes unue, por
forĵeti ilin (`--force`, kiu prenas nekunigitan branĉon kun ili); ne al
tio fermas nenion. Skribtablo kun agento ĉe ĝi ne estas proponata:
Fermu agenton unue, aŭ lasu ĝin fini.

**Daŭrigu** proponas nomitan provizon kaj aŭ ĝian registritan konservitan
konversacion aŭ aŭscentan **Komencu denove**. Ĝi uzas `vikix agents
resume`, inkluzive de ĝiaj kontrolaj ripetaj sesioj. Konservita
konversacio, kiu malaperas post la elekto, malsukĉesas anstataŭe de
silente komenciĝi denove. La Oficejo ne proponas duan agenton ĉe
okupita skribtablo aŭ rekreas forigitan laborarbon; la ekzistanta CLI
restas disponebla por tiuj operacioj.

Refreŝigo funkcias en la fono ĉiujn dek sekundojn, kun unu refreŝigo je
fosto kaj tempo limigita. Ĝi konservas la elekton kaj pozicion de la
panelo, neniam koncentriĝas je fenestro, kaj haltas kiam la vido fermiĝas.
Je fiasko, la kaplinio diras kial, la antaŭa informo restas videbla, kaj
aktiva agado iĝas nekonata; agoj atendas sinsekecan refreŝigon.
`vikix agents office --json` eksponas la saman momentan staton al
skriptoj, inkluzive de eraroj pri malkovro, la vico de publikigo kaj la
tabulo (`tabulo`: la sekcioj kun siaj vicoj, kiel la paĝo desegnas
ilojn; `vikix agents tasks --json` estas la sama tabulo sole); la
ekzistanta ilo MCP `office` ankaŭ redonas ĝin, kaj la ilo MCP `tasks` la
tabulon, do agento vidas la oficejon, kiel vi faras. Ĝi estas vido de
ekzistantaj skribtabloj kaj transdonoj, ne alia magazeno de taskoj.

## Bezonas atenton kaj decidojn

La Oficejo komenciĝas kun **Bezonas atenton**: individuaj demandoj,
permesoj, malsukcigitaj testoj, revizioj, publikigoj, haltigitaj
laborantoj kaj necertaj agadoj. Ĉiu ero nomas sian taskon kaj laboranton,
diras, kial ĝi bezonas vin, kaj montras, kiom longe ĝi atendis, kiam tiu
tempo estas konata. Senaganta terminalo sole neniam signifas, ke tasko
estas finita. Malsukcigitaj testoj aperas nur dum ilia rezulto estas
freŝa kaj la laboranto estas senaganta aŭ forigita. Kontrolo Akcepti de
revizio bezonas freŝajn pasigitajn testojn, aŭ la esplicita agordo
sen-testado de la skribtablo.

`vikix agents attention` eldonas la saman liston; `--json` eksponas ĝiajn
registraĵojn. `Super+Alt+d` tiam `?`, aŭ Super+m → AI → Agentoj: kio
bezonas vin, malfermas ĝian menuon. La refreŝigo de la Oficejo kaj
`attention --notify` notifikas unufoje por ĉiu ero, inkluzive trans
reŝargoj de la Oficejo; registrita demando notifikas tuj. Nur-legi
momentaj statoj kaj la ilo MCP `office` ne notifikas.

Laborantoj registras elektojn esplicite, do la demando postulas reŝargon:

```sh
vikix agents ask "Keep the old order?" \
  --choice "keep: compatible with existing scripts" \
  --choice "drop: simpler implementation" \
  --recommend keep --reason "Existing scripts still use it" \
  --context "The guide documents both orders" --blocks
```

Ekzistas la ebleco de dek malfermaj demandoj por ĉiu tasko. Por aktiva tasko, la argumento `--blocks`
metas ĝin en staton *bezonanta decidon*; haltigita tasko restas blokita. Sen ĝi, la
ekzekutanto povas daŭrigi sendependan laboron.
En la Oficejo, **Respondu…** (aŭ `D` ĉe demando aŭ ĝia tasko) ofertas la
elektojn, kaj **Alia…** por viaj propraj vortoj. Neniu rekomendo estas sendita
sen via elekto. Vi ankaŭ povas uzi la komandon `vikix agents answer ID "via respondo"`.
Ekzekutantoj ne povas respondi per la CLI aŭ MCP. La respondo en libera teksto restas
teksto; ĝi neniam estas ekzekutata kiel komando.

Respondo eniras la enirkeston de la tasko, kaj la hakoj liveras ĝin dum la sekva voko.
Provizantoj sen hakoj povas uzi la komandon `vikix agents ask --wait ID`: ĝi atendas ĝis
dek minutoj, kaj poste eliras kun kodo 3 se la demando ankoraŭ ne estas respondita. `VIKIX_ASK_LIMIT`
elektas pli mallongan liman tempon en sekundoj. MCP `decide` registras demandon, kaj `decision`
legas ĝin. La respondo estas konservata en `office/decisions/ID.json`, eĉ post la
livero al la enirkesto, kaj aperas en la transdono kaj rekomenco. Respondi al la lasta
blokanta demando permesas al atenda tasko denove funkcii; ĝi neniam komencas procezon
aŭ rekomencas taskon blokitan ĉar ĝia ekzekutanto eliris.

Inferita demando havas **Registri decidon…** por doni al ĝi rekordon.
Petoj pri permeso restas en la propra aproba interfaco de la ekzekutanto; **Iru al
ekzekutanto** portas vin tien. **Akcepti kontrolon** markas la laboron preta por publikigo;
**Reen al la laboro…** lasas reagecon en la enirkesto. **Publiki…** petas
resumon kaj malfermas la publikigan skripton de la projekto en terminalo; ĝi ne
puŝas. La butono **Tablestro** por aliaj elementoj malfermas la ekzistantajn regilojn de la tasko.

Funkcianta tasko kun inferita aŭ nekonata stato de ekzekutanto kaj sen lastatempa
aktiveco iĝas *neklarigita* post 20 minutoj. `quiet=MINUTES` en
`~/.config/vikix/office` ŝanĝas tiun limon. Nehavebla detektado estas montrata
eksplice; manka pruvaro ne estas aserto, ke ekzekutanto haltis.
