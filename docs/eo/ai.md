# Labori kun AI

Vikix ofertas al vi ĉi tiujn manierojn uzi AI, komencante de la plej kapablaj ĝis la plej privataj:

| | Kio ĝi estas | Kion ĝi bezonas | Kien iras viaj vortoj |
|---|---|---|---|
| **La agento** | Claude Code (aŭ alia agento), en terminalo, kapabla ŝanĝi la labortablon por vi | Konto de Claude (Pro aŭ Max), aŭ API-ŝlosilo de Anthropic; la aliaj bezonas siajn proprajn | Anthropic, aŭ la kompanio de la agento; nenie kun `--local` |
| **Lokaj modeloj** | Modelo, kiu funkcias sur ĉi tiu poŝkomputilo, por babili | `vikix ai setup`, kaj kelkaj gigaojto da diska spaco | Nenie: ĉio restas ĉi tie |
| **`llm`** | Unu komando por ajna modelo, ricevante datenojn de kanalo | `vikix ai llm`, kaj loka modelo aŭ ŝlosilo | Ĉi tie, aŭ al la kompanio de la modelo |
| **Super+i** | Korektu, reskribu, traduku, klarigu aŭ demandu pri la teksto, kiun vi elektis, en ajna programo | `vikix ai llm`, kaj loka modelo (aŭ Claude, se vi volas) | Ĉi tie, krom se vi elektas Claude |
| **Super+F9** | Parolu, kaj ĝi tajpas kion vi diris, en ajna programo | `vikix add dictation` (kelkaj minutoj, unufoje) | Nenie: ĉio restas ĉi tie |
| **Super+F10, Super+F11** | Parolu kun la AI aŭ la agento, kaj ĝi respondas laŭte | `vikix add voice` (minuto, unufoje) | Kiel ĉe Super+i, aŭ ĉe la agento; la aŭskultado kaj la voĉo restas ĉi tie |
| **En Neovim** | Babila pri via kodo, kaj via agento en flanka fenestro (`Space A`) | `vikix add neovim`, kaj loka modelo, ŝlosilo aŭ agento | Kiel ĉe Super+i, aŭ ĉe la agento |
| **En Emacs** | La sama, kun gptel (`C-c g`) kaj agent-shell (`C-c a`) | `vikix add emacs`, kaj loka modelo, ŝlosilo aŭ agento | Kiel ĉe Super+i, aŭ ĉe la agento |
| **`note`** | Demandoj responditaj el viaj propraj notoj, ekzemple, en Obsidian-deponejo, en ajna terminalo | `vikix add notes` (ĝi alportas lokan AI) | Nenie kun loka modelo; al Anthropic, nur la trovitaj fragmentoj, kun Claude |
| **`~/dev/ai`** | Malgrandaj programoj, kiujn vi kreis, kiuj vokas Claude aŭ lokan modelon, kaj unu, kiu respondas el viaj notoj | `vikix add python`, kaj ŝlosilo aŭ loka modelo | Ĉi tie, aŭ al Anthropic kiam vi lanĉas la programojn de Claude |

Vi povas uzi ajnan el ili, ĉiujn el ili, aŭ neniun. Neniu AI funkcios ĝis vi lanĉos ĝin.

## La agento

Agento estas AI, kiu faras aferojn, ne nur parolas pri ili. Claude Code legas dosierojn, lanĉas komandojn kaj redaktas viajn agordojn, kaj ĝi scias, kiel Vikix estas konstruita, do vi povas peti ŝanĝon per simplaj vortoj.

### Lanĉo

Premu **Super+a**. Ĝi demandas: *Agento ĉi tie* aŭ *Agento ĉe nova labortablo*; tiam, kiu agento: unue la via (Claude Code, krom se vi elektis alian: [Alia agento](#alia-agento), sube), la aliaj, kaj tiuj, kiuj povas funkcii sur modelo sur ĉi tiu poŝkomputilo. Eniru dufoje, aŭ `a` en terminalo, malfermas terminalon kun via agento. La dua elekto estas por agento pri projekto, kun kopio de la deponejo por ĝi; ĝi petas la projekton, temon, la taskon kaj kiu agento: [Agentoj](agents.md#labortablo-por-ĉiu) diras, kiam vi volas tion.

La unua fojo, ĝi ofertas instali Claude Code (kun la instalilo de Anthropic, en `~/.local/bin`), tiam ĝi petas, ke vi ensalutu. Ensalutu kun via konto de Claude: la agento tiam uzos vian planon. Se vi prefere pagus laŭ uzo per API-ŝlosilo, vidu [API-ŝlosiloj](#api-ŝlosiloj) sube.

Tajpu kion vi volas kaj premu Return. `/exit` aŭ Ctrl+D eliros.

### Kion demandi

Ĉio pri ĉi tiu labortablo, per viaj propraj vortoj. Ekzemple:

- "Faru, ke Super+t malfermu duan terminalon."
- "Ŝanĝu al la hela temo, kaj faru, ke la skriftotipo de la terminalo estu pli granda."
- "Lanĉu Firefox kaj Emacs sur labortablo 2 kiam mi ensalutas."
- "Kial la Wi-Fi ne konektas? Rigardu la protokolojn."
- "Instalu GIMP, kaj metu ĝin en la lanĉilon."
- "Kion faras la ŝlosilo Super+g?"

Ĝi ne limiĝas al la labortablo: ĝi povas skribi kaj lanĉi kodon en `~/dev`, klarigi eraron aŭ ordigi dosierujon.

### Kiel ĝi scias, kion fari

- **Gvidlibro por la agento.** Vikix instalas kapablon en `~/.claude/skills/vikix`: kie estas ĉiu dosiero, kiuj estas tiuj, kiujn vi rajtas ŝanĝi, la ŝlosiloj, kaj la komandoj de `vikix`. Ĝia unua paĝo estas mallonga (la reguloj, kiuj ĉiam validas); la resto estas paĝo pri temo, kiun la agento legas kiam ĝi bezonas ĝin. Ĝia ĉefa regularo estas tiu en [Kie ĉio estas](map.md): ŝanĝu viajn dosierojn, neniam tiujn de Vikix.
- **Ĝi povas provi antaŭ ol ĝi skribas.** `vikix eval` lanĉas Lisp en la aktiva fenestra administrilo, do la agento povas provi ŝlosilon aŭ koloron sur la aktiva labortablo, vidi, ke ĝi funkcias, kaj nur tiam konservi ĝin en `~/.stumpwm.d/user.lisp`.
- **Ĝi unue demandas.** Laŭ defaŭlto, Claude Code montras ĉiun komandon kaj ĉiun redakton kaj atendas vian "jes". Vi povas lasi ĝin fari pli memstare; ĝia komando `/permissions` montras, kion ĝi povas fari sen demandi.

### Reversaligo de ŝanĝo

Antaŭ ĉiu sesio, Vikix konservas kopion de viaj agordoj. La terminalo diras tion en siaj unuaj linioj:

```
:: snapshot 99e03a6: before an agent session (claude)
:: to see what the agent changed: vikix changes    to take it back: vikix undo
```

Do post sesio:

```sh
vikix changes      # what the agent changed in your files
vikix undo         # put them back as they were before it started
vikix undo         # again: take the undo back
vikix history      # every snapshot, newest first
```

En terminalo, `vikix undo` unue listigas la dosierojn, kiujn ĝi ŝanĝus, kaj demandos. Respondu "ne", se la antaŭa versio ne estas tiu, kiun vi volas (agento, kiu estas lanĉita de redaktilo, ankaŭ uzas antaŭan version), kaj elektu unu el `vikix history` per `vikix undo ID`. Ĉi tio kovras viajn agordojn (la dosieroj en `~/vikix/config/yours.list`), ne ĉion en via hejma dosierujo. Por via laboro, konservu kopiojn: [LEGOTU: Kopioj](../../README.md#backups).

### Alia agento

Claude Code ne estas la sola. Kvin aliaj funkcias simile, kun la sama antaŭa versio unue kaj la sama gvidilo:

| Agento | Eniros per | Ĉu povas funkcii sur ĉi tiu poŝkomputilo | Reĝimoj (`vikix agent --mode`) |
|---|---|---|---|
| **OpenCode** | Ĉiu modelo-kompanio, pri kiu vi havas konton | Jes | Sia propra agordo (demandas antaŭ komando aŭ redaktado, kiel Vikix agordas ĝin) |
| **Codex** (OpenAI) | Via ChatGPT-konto | Jes | `supervised`, `autonomous`, `unrestricted`: ĝia eksperimenta areo estas limigita al la labortablo, kiu respondas al demando for de ĝi |
| **Antigravity CLI** (Google, `agy`) | Via Google-konto (senpaga, AI Pro aŭ AI Ultra), aŭ Gemini API-ŝlosilo | Ne | Sia propra (`--mode plan` por raporto) |
| **Gemini CLI** (Google) | Gemini API-ŝlosilo, aŭ Kodeca Helpa licenco de la laboro | Ne | Sia propra (`--approval-mode`) |
| **Aider** | API-ŝlosilo (`vikix ai key set anthropic`) | Jes | Neniu |

Por la momento, la vorto estas de Codex: `--mode` kun alia agento estas rifuzita, kaj la agordo de ĉiu alia agento aperas, kiam ĝi estas provata. La propra agordo de Claude Code estas `--permission-mode`, kiun `vikix agent` agordas al `plan` por raporto (`vikix diagnose`).

```sh
vikix agent --list                # which are installed, and which Super+a starts
vikix agent --use opencode        # try one: it offers to install it first
vikix agent --default opencode    # make Super+a start it
vikix agent --default claude      # back to Claude Code
vikix add codex                   # or install one as a feature (vikix remove codex takes it away)
```

**Kielu eluzi?** Claude Code estas la kodo, per kiu Vikix estas kreita kaj testata. OpenCode aŭ Aider se vi volas labori sen konekto. Kun Google-konto, Antigravity CLI: en junio 2026, Gemini CLI ĉesis servi personajn kontojn (la senpaga nivelo, AI Pro kaj AI Ultra) kaj sendis ilin tien; Gemini CLI restas por Gemini API-ŝlosilo (`vikix ai key set gemini`, poste `VIKIX_AGENT_API_KEY=1 vikix agent --use gemini`, ĉar ŝlosiloj estas konservataj de la agentoj) aŭ Code Assist Standard aŭ Enterprise-licenco.

**Antigravity CLI** estas instalata de la versio, kiun Vikix uzas kaj kontrolas (ĝia SHA-512 estas en `vikix agent`), ne per la instalilo de Google, kiu skribus linion de PATH en via `.bashrc`, `.profile` kaj `.bash_profile`; `~/.local/bin` jam estas en via PATH. La `agy`, kiun la instalilo de Google metis tie, estas trovata kaj lasata kiel ĝi estas. Ĝi unue malfermiĝas, ĝi enlogigas vin en via navigilo kaj konservas la enlogon en la sistema ŝlosilujo (`/logout` forigas ĝin); por uzi Gemini API-ŝlosilon anstataŭe, agordu `"modelProvider": "gemini"` en `~/.gemini/antigravity-cli/settings.json`, kaj Vikix tiam permesas nur tiun ŝlosilon. De tiam, `agy` ĝisdatigas sin en la fono (`AGY_CLI_DISABLE_AUTO_UPDATE=true` haltigas tion). Ĝi ne havas lokajn modelojn kaj ne parolas ACP. `agy -c` prenas la lastan konversacion en ĉi tiu dosierujo: `vikix agent --use antigravity -c`. Ĝi povas labori ĉe propra skribotablo (`vikix agents worker DESK "..." --use antigravity`); ĝia konversacia ID estas aŭtomate registrita dum transdono, kaj `vikix agents resume DESK` reaktivigas tiun konversacion (`agy --conversation ID`). `vikix mcp register` aldonas la MCP-ilojn de la skribotablo al ĝi (`agy mcp add vikix -- ...`).

**Ĉiam per Vikix:** lanĉu ilin per `vikix agent --use NOME` (aŭ Super+a), ne tajpante `codex` aŭ `opencode`: tio saltas la momentan bildon, kaj la sekurecon sube.

**De redaktilo:** redaktilo, kiu lanĉas agenton, devas ruli `vikix agent --exec NOME` kaj la proprajn opciojn de la agento post tio, aŭ `vikix agent --exec` por via. Ĝi estas la sama lanĉo, kun la sama sekureco, sed silenta: nenio el Vikix en la eliro de la agento, kaj neniu demando. Redaktiloj, kiuj parolas ACP, la Agent Client Protocol (Neovim's CodeCompanion, sube; Emacs's agent-shell; Zed), rulu `vikix agent --acp NOME`: Gemini CLI kaj OpenCode parolas ĝin mem, kaj Claude Code kaj Codex bezonas malgrandan adaptilon, kiun `vikix agent --install claude` (aŭ `codex`) metas apud ili. Ĝi uzas la agenton, kiun vi havas, kaj vian enlogon. Ĝi bezonas Node 22 aŭ pli novan, kiun `vikix add neovim` alportas. Aider kaj Antigravity CLI ne parolas ACP. `vikix agent --which` diras, kiu agento estas via, kaj `vikix ai use` kiu modelo Super+i uzas.

**Senrete**, kun lokala modelo: `vikix agent --use opencode --local` (aŭ codex, aŭ aider; `--model NOME` elektas unu). Ĝi elektas la plej bonan el viaj modeloj por kodo. Atentu: en la CPU de laptopo ĉiu respondo prenas minutojn (Aider en llama3.2:3b prenis pli ol kvar minutojn por unu frazo), kaj malgranda modelo rare faras ŝanĝon memstare. Pli granda modelo (`vikix ai models`) faras pli, tamen pli malrapide.

**Kion agento ne ricevas**, por ke truko kaŝita en retejo aŭ dosiero, kiun ĝi legas, ne povu uzi ĝin:

- **Viaj API-ŝlosiloj**, kaj aliaj sekretoj en la medio (pasvortoj, tokenoj): ĉiu agento enlogiĝas laŭ sia propra maniero, do ŝlosilo ne estas fakturata sen ke vi sciu. Aider ne povas enlogiĝi, do ĝi ricevas la ŝlosilojn de la modelkompanioj (Anthropic, OpenAI, Google, OpenRouter, DeepSeek, Mistral, Groq, xAI), kaj ne aliajn. Ŝelo, kiun la agento malfermas, ankaŭ ne legas ilin reen.
- **Via SSH-agento.** Post via unua `git push` de la tago, ĝi tenas vian malŝlositan ŝlosilon: agento kun ĝi povus puŝi, kiel vi, al ĉio, kion vi povas. Se vi volas, ke la agento puŝu por vi: `VIKIX_AGENT_SSH=1 vikix agent`; ĉe skribotablo, la selektilo demandos (la lasta demando, ne, krom se vi diras jes), aŭ `vikix agents worker DESK "..." --push`.
- **La sesio, de kiu ĝi estis lanĉita.** Claude Code markas la medion de ĉio, kion ĝi kurigas, kiel sia propra filio, kaj skribotablo malfermita ene de sesio (de agento, kiu kurigas `vikix agents worker`, aŭ la oficeja ilo de la MCP-servilo) portas la markojn al la nova agento, kiu tiam konsideras sin kiel filio de tiu sesio kaj ne konservas transskribaĵon ("Transskribaĵkonservado estas malŝaltita: hereda CLAUDE_CODE_CHILD_SESSION-markilo", kaj `vikix agents resume` ne trovas nenion). `vikix agent` forigas ilin: agento de skribotablo estas sia propra sesio.

Ĉi tio evitas akcidentojn; ĝi ne estas muro. La agento kuras kiel vi, kaj povas legi viajn dosierojn. OpenCode estas agordita por demandi antaŭ ol ĝi kurigas komandon aŭ redaktas dosieron, kiel Claude Code faras, krom se viaj propraj agordoj de OpenCode diras alie.

**Kiel ili konas Vikix:** OpenCode legas la saman kapablon kiel Claude Code. Codex, Gemini, Antigravity kaj Aider legas `~/.local/share/vikix/AGENTS.md`, la unua paĝo de la kapablo, kiu nomas la aliajn paĝojn, kie ili povas malfermi ilin: Vikix ligas ĝin kiel `~/.codex/AGENTS.md`, skribas unu-linian `~/.gemini/GEMINI.md`, kiu importas ĝin, skribas propran reguldosieron por Antigravity, `~/.gemini/antigravity-cli/rules/vikix.md`, kiu inkluzivas ĝin (Antigravity legas ĉiun regulon tie), kaj pasigas ĝin al Aider (ne al malgranda loka modelo, por kiu ĝi estas tro longa). Se vi jam havas unu el tiuj dosieroj, ĝi estas via kaj restas; Vikix diras, kiel aldoni la gvidilon al ĝi. Tio estas la reguloj de la skribotablo; projekto venas de la dosiero ĉe ĝia radiko, `AGENTS.md` se ekzistas, `CLAUDE.md` alie: Codex, kiu legas nur `AGENTS.md` mem, ricevas `CLAUDE.md` kiel la dosieron, al kiu ĝi povu reteni por la sesio, plena (vidu [Reĝimoj](agents.md#reĝimoj-kiel-multe-codex-laboristo-estas-libera)).

**La reguloj de la domo** (`vikix agents touch`, [Agentoj en laboro](agents.md)) atingas Claude Code, Antigravity CLI kaj Codex: Claude Code ricevas la hokon por la sesio, Antigravity kiel ŝtopilo de Vikix, kiu restas (`agy plugin list` montras `vikix`; `agy plugin disable vikix` malŝaltas ĝin), Codex de hokdosiero de Vikix, kiun vi ligas unufoje (`vikix agents hooks codex --install`), kiun `vikix agent` fidas por vi en viaj propraj projektoj; la ŝtopilo de OpenCode tenas la redaktan hokon. Codex ankaŭ ricevas **reĝimon**: `vikix agent --use codex --mode supervised|autonomous|unrestricted`, ĝia sandkesto limigita al la dosierujo en la du unuaj kaj la reguldosiero kaj la hoko ĉe ĉiu paŝo ekster la sandkesto, kiu permesas al tago de skribotablo (git en ĝia branĉo, la testoj, `vikix`, sub `timeout` aŭ ne) eliri sen demando, kiam Codex demandos; ĉe skribotablo kaj en via hejmdosierujo (Super+a's *Agento ĉi tie*), la defaŭlta `mode=autonomous` en `~/.config/vikix/office` aplikiĝas, kiam nenio estas tajpita; en deponejo, kiu ne estas skribotablo, Codex kuras kiel viaj agordoj diras. La reĝimoj estas priskribitaj en [Agentoj en laboro](agents.md#reĝimoj-kiel-multe-codex-laboristo-estas-libera).

### Kelkaj samtempe

Agentoj kuras flankvoje, ĉiu en sia propra terminalo, kaj vico de fenestroj, ĉiuj nomitaj "Alacritty", ne diras, kiu estas kiu. `vikix agents` (kaj `Super+m` → *AI* → *Agentoj: kiuj kuras, kaj iru al unu*) listigas ilin: kiu agento, ĝia dosierujo kun branĉo kaj nekompetitaj dosieroj, ĝia labro, kiom da tempo, kaj kion ĝi faras. `vikix agents desk PROJECT TOPIC` kreas skribotablon, propran git-laborarbon, `vikix agents worker TOPIC "..."` metas agenton labori ĉe ĝi en propra labro, kaj la reguloj de la domo diras, kio okazas, kiam du agentoj atingas unu dosieron. Ĉio ĉi, kun ekzemploj, estas en sia propra paĝo: [Agentoj en laboro](agents.md).

## Transdonoj de Grok Bot

Donu al Grok Bot esplorkonsignon kaj konservu ĝian respondon en Vikix por revizio. `vikix grok` tenas lokan vican taskon: vi elektas konsignon, algluas la prompton de la tasko en Grok Bot, kaj aprobas ĝiajn lokajn komandojn por kolekti la konsignon kaj redoni rezulton. Grok Bot devas esti instalata kaj enlogita aparte. Konservu ĝian agordon **Ekzekuto sur Loka Komputilo** ĉe **Demandu ĉiun fojon**.

Malfermu ĝin de `Super+m` → *AI* → *Grok Bot: malfermu* (montrita kiam `~/.local/bin/grok-bot` estas instalita). La najbara *Grok Bot: listi taskojn* malfermas la vicon en terminalo.

Komencu kun tekstdosiero, kiu enhavas la taskon, la fontojn, kiujn ĝi povas uzi, kaj kion utila respondo devus inkludi. Ekzemple, `brief.txt` povus peti komparon de du bibliotekoj uzante ilian publikan dokumentaron. Tiam, en via terminalo:

```sh
task=$(vikix grok new "Compare the libraries" --brief brief.txt --project vikix)
vikix grok prompt "$task"
```

Kopiu la afiŝitan mesaĝon al la Grok-roboto. Krei taskon ne sendas ion; kiam Grok ekzekutas `vikix grok claim ID` **sur via loka komputilo**, la aprobitita komando donas al ĝi la elektitan priskribon kaj markas la taskon kiel "ekzekutata". La projekta nomo estas etikedo por viaj notoj, ne permeso legi la dosierojn de tiu projekto. `--brief -` legas la priskribon de la norma eniro anstataŭ de dosiero.

La mesaĝo klarigas, kiel sendi la respondon per `vikix grok result ID --file -`. La respondo estas JSON kun ĝuste kvar kampoj:

```json
{
  "summary": "The findings, including anything needed to assess them.",
  "sources": [],
  "artifacts": [],
  "questions": []
}
```

`summary` estas teksto; la aliaj kampoj estas listoj de tekstaj ŝnuroj. Fontoj kaj artefaktoj estas HTTP aŭ HTTPS-ligiloj, kiuj ne enhavas enmetitajn kredencialojn. Metu la rezultojn en la resumon, tiel ke la respondo ne dependas de dosiero en la nuba komputilo de Grok. Ligiloj estas opciaj; Vikix ne alprenas aŭ plenumas ilin. `vikix grok instructions` elprintas la kompletan liston de instrukcioj.

Kiam la respondo alvenas, la tasko eniras staton `review` (revizio) kaj Vikix sendas mesaĝon al la labortablo. Reviziu ĝin en via terminalo:

```sh
vikix grok list --state review
vikix grok show "$task"
vikix grok accept "$task"
```

Se vi malfermis novan terminalon, anstataŭigu `"$task"` per la ID el `list`. Akceptante registrojn, pri kiuj vi kontrolis la respondon; ĝi ne aplikas kodon, elŝutas dosierojn aŭ startas alian agenton. Vi povas doni la kontrolitajn rezultojn al [laboranto ĉe la komputilo](agents.md#labortablo-por-ĉiu) por plua laboro.

Se Grok ne povas fini, ĝi registras la kialon per `vikix grok fail ID 'reason'`; `show` konservas la mallongan resumon, la kialon kaj la historion legeblaj. Kreu novan taskon por refari ĝin. Por retiri taskon, uzu `vikix grok cancel ID`. Retiro fermas la lokan registron; ĝi ne haltigas laboron, kiu jam funkcias en Grok Bot. Sendi la saman rezulton denove estas sekura, sed malsama rezulto ne povas anstataŭigi jam liveritan rezulton.

`vikix grok status` montras, ĉu `grok-bot` estas en via komanda vojo, la lokon de la vico kaj la nombrojn laŭ stato. Ĝi ne testas vian konton aŭ la konekton al via komputilo. Ĉi tiu ponto uzas aprobitajn lokajn komandojn, sen fora taska API aŭ oficeja laboranto. Ĝiaj instrukcioj difinas la gamon de la transdono; ili ne izolas la aliajn lokajn komandojn de Grok.

Por la interesatoj: la vico estas privata datbazo SQLite ĉe `~/.local/share/vikix/grok/tasks.db` kiel defaŭlto (`XDG_DATA_HOME` ŝanĝas la bazan datumlokon; `VIKIX_GROK_DIR` elektas la vican dosierujon rekte). `list --json` kaj `show ID --json` provizas strukturigitajn registrojn por viaj propraj iloj. Asertoj estas atomaj, do du Bot-oj ne povas samtempe aserti la saman vican taskon.

## API-ŝlosiloj

Programoj trovas API-ŝlosilon en variablo kiel `ANTHROPIC_API_KEY`. Ne metu ĝin en `~/.bashrc`: tiu dosiero konservas ĉiun version por ĉiam. Vikix havas sekuran lokon:

```sh
vikix ai key set anthropic     # paste the key; it isn't shown
vikix ai key list              # the names, and a short fingerprint, never the key
vikix ai key remove anthropic
```

Aliaj nomoj ankaŭ funkcias: `openai`, `gemini`, `openrouter`, `mistral`, `groq`, `github`, kaj pli (`vikix ai help` listigas ilin).

- **Ĉiu nova terminalo** ricevas la ŝlosilon de tiu momento. Terminalo, kiu jam estis malfermita, ricevas ĝin post `exec bash`; programoj, kiujn la labortablo startigas, ricevas ĝin ĉe la sekva ensaluto.
- **Super+a ne uzas ĝin.** La agentejo uzas vian Claude-ensaluton kaj planon, ne la ŝlosilon, do vi ne estos fakturita dufoje. Por fakturi la agentejon per la ŝlosilo anstataŭe: `VIKIX_AGENT_API_KEY=1 vikix agent`.
- **Neniam tajpu ŝlosilon en la komanda linio** (`vikix ai key set sk-ant-...`): ĝi restus en la historio de via ŝelo. `set` rifuzas ĝin kaj diras al vi, kiel forigi ĝin.
- **`vikix doctor`** serĉas ŝlosilojn lasitajn en la malĝusta loko, kiel `~/.bashrc`, kaj diras, kiel movi ilin.

La ŝlosiloj estas konservitaj en `~/.config/vikix/secrets/`, kiun nur vi povas legi. La [LEGMI-DOSIERO](../../README.md#api-keys) enhavas la detalojn.

## Lokaj modeloj

Loka modelo funkcias sur ĉi tiu laptopo: neniu konto, neniu kosto, kaj nenio forlasas la maŝinon. Ĝi estas pli malgranda kaj pli malrapida ol Claude, sed bona por demandoj, skribado kaj etaj pecoj de kodo, kaj ĝi funkcias senrete.

### Akirado de modelo

```sh
vikix ai setup       # once: installs Ollama, about 100 MB, no password needed
vikix ai models      # choose a model to download
```

`vikix add local-ai` faras la samon kiel `vikix ai setup`, kaj `vikix remove local-ai` la samon kiel `vikix ai uninstall`: lokala AI estas unu el la funkcioj.

`vikix ai models` (aŭ **Super+m** → *Lokala AI: elektu modelon*) kontrolas la memoron de ĉi tiu portebla komputilo kaj diras, kiel ĉiu modelo funkcios ĉi tie: rapide, bone, aŭ malrapide. Pli grandajn modelojn ĝi ne proponas por elŝuti, sed ĉiu instalita modelo restas videbla kun ✓. Instalitaj modeloj ekster la katalogo montras nekonatan grandecon kaj estimitan rapidecon. Bonaj unuaelektoj:

- `llama3.2:3b` (2 GB), por demandoj kaj skribado
- `qwen2.5-coder:3b` (1,9 GB), por kodado

Sur portebla komputilo sen grafika karto, 3B-modelo bezonas kelkajn sekundojn por ŝarĝi, kaj poste ĉirkaŭ dek sekundojn por skribi kelkajn frazojn.

Sur maŝino, kies grafika ĵetono uzas la ĉefan memoron (AMD's Ryzen AI Max, kun 128 GB), la ĵetono funkcias kun la modeloj anstataŭ la CPU: multe pli rapide, kaj ankaŭ kun grandaj modeloj. Ollama forlasas tiun ĵeton, krom se oni petas, do Vikix demandas, kiam la ĵetono povus uzi 32 GB aŭ pli; `graphics=` en `~/.config/vikix/ai` agordas tion al `on` aŭ `off` (`vikix ai restart` aplikas tion), kaj `vikix ai status` diras, ĉu la ĵetono estas uzata. La selektilo tiam proponas la grandajn modelojn, taksitaj laŭ la parametroj, kiuj funkcias sur ĉiu vorto, anstataŭ ilia grandeco: `gpt-oss:120b` (65 GB) respondas je 51 vortoj por sekundo tie, ĉar nur 5 miliardoj el ĝiaj 117 funkcias sur ĉiu vorto (mezurite sur Ryzen AI Max+ 395, 2026-10-19: Vulkan 51, ROCm 35, ĉar ROCm vidas 61 el la 65 GB de la ĵetono kaj lasas parton de la modelo sur la CPU; do ĝi restas ĉe Vulkan, kaj `vikix ai setup` konservas nur tiun bibliotekon). Vikix agordas kuntekston de 32 mil vortoj sur la ĵetono, ĉar la propra elekto de Ollama pri tia granda memoro estas la plej longa modelo, 4,6 GB pli por `gpt-oss:120b`, kaj tio iam uzis la tutan memoron de la ĵetono: la X-servero, rifuzis sian parton, finis la sesion (tri fojojn tiu tago). Petro povas ankoraŭ peti pli, kaj la 120B lasas al la labortablo nur ĉirkaŭ 3 GB el la memoro de la ĵetono, dum la ĵetono havas duonon de la kerno. Modelo, kiu ne taŭgas en la tutan memoron de la ĵetono, funkcias parte sur la CPU, je la rapido de la CPU.

La kerno permesas, ke tia ĵetono uzu duonon de la memoro unue (sur maŝino de 128 GB, 60 GB uzata laŭbezone krom la 4 GB, kiujn la firmware rezervas). `vikix ai share` diras, kiom ĝi povas uzi; `vikix ai share most` permesas al ĝi uzi ĉion krom 16 GB (kernagordo en `/etc/default/grub`, skribita per `sudo`, poste `update-grub`), kio estas tio, kion la plej grandaj modeloj bezonas, kaj `vikix ai share half` remetigas la duonon de la kerno. Ĉiu el tio aplikiĝas ĉe la sekva starigo, kaj `vikix ai setup` proponas la unuan pri tia maŝino, demandante antaŭ ol ĝi ŝanĝas, kiel la maŝino starĝiĝas. La selektilo sekvas: post tiu starigo ĝi proponas la modelojn, kiuj taŭgas al la nova parto, `nemotron-3-super:120b` inter ili.

### Parolante kun ĝi

```sh
vikix ai chat        # talk to it; /bye or Ctrl+D leaves
```

Aŭ **Super+m** → *Lokala AI: parolu kun modelo*.

Dum modelo estas ŝarĝita, la horzonta linio montras **ai**. Ĝi uzas kelkajn gigaojtojn da memoro kaj liberigas ĝin post kvin minutoj senuzo. Por tuj liberigi ĝin: `vikix ai stop`, aŭ **Super+m** → *Lokala AI: forŝarĝi la modelon*.

### Kontroli la staton

```sh
vikix ai status      # running? which model is loaded, and for how long
vikix ai list        # the models you have
vikix ai remove llama3.2:3b
vikix ai restart     # start Ollama again (after changing graphics= in ~/.config/vikix/ai)
vikix ai uninstall   # take Ollama away (add --models to delete the models too)
```

La modeloj estas en `~/.ollama/models`. Ili estas grandaj, do la kopiaj dosieroj ne inkluzivas ilin; vi povas elŝuti ilin denove.

## Tradukado de la gvidiloj al Esperanto

La elŝutita dosieraro inkluzivas `translate-guides-to-epo.sh`, apartan Bash/Python 3-skripton, kiu sendas la Markdown-dosierojn en `docs/` al via loka Ollama-modelo.
El la elŝutita dosieraro, antaŭrigardu la dosierojn, kaj poste traduku:

```sh
./translate-guides-to-epo.sh --dry-run
./translate-guides-to-epo.sh
```

Ollama jam devas esti lanĉita kaj la modelo instalita. La defolta modelo estas
`translategemma:27b` (aŭ la eksportita `OLLAMA_MODEL`); la defolta servilo estas
`http://127.0.0.1:11434`. Nenio estas aŭtomate elŝutata.
La rezulto estas konservata en `~/vikix-guides-eo`, ekster la ĉefkopiaĵa dosierujo, kun la samaj
relativaj dosiernomoj. Ekzistantaj tradukoj estas preterlasataj, do interrompita procezo
povas rekomenci; uzu `--overwrite` por traduki ilin denove. `--source`, `--output`,
`--host` kaj `--timeout` anstataŭigas tiujn agordojn; `--help` listigas la opciojn.
Konservu la fontajn kaj rezultajn dosierujojn aparte.
Petoj al TranslateGemma inkluzivas la fontan anglan (`en`) kaj celan esperantan
(`eo`) en la peto, laŭ la modelo-petformato.

Fiaskinta peto haltigas la skripton kun eraro kaj konservas la antaŭan rezulton
por tiu dosiero. Grandaj dokumentoj estas disigitaj en tekstaj eroj de maksimumo 12000
karakteroj ĉe blankaj linioj (aŭ liniaj limoj en longaj alineoj), kun 32k
konteksto kaj HTTP-tempolimo de 1800 sekundoj por peto. Kodaj eroj estas
kopiataj rekte, sen sendi ilin al la modelo. Ununura proza linio pli granda
ol la er-limo devas esti dividata mane.
Ĉiu dosiero estas konservata nur post kiam ĉiuj ĝiaj eroj sukcesas.
Krudaj modelaj respondoj kun argumentaj kanaloj aŭ prefikso `<think>` estas
reduktitaj al la fina respondo; mankantaj aŭ malplenaj finaj respondoj haltigas la procezon.
Se antaŭa traduko enhavas tiujn argumentajn markilojn, normala rekomencita
procezo raportas ĝin anstataŭ preterlasi ĝin: uzu `--overwrite` por regeneri ĝin.
Revizu la rezulton:
la modela rezulto povas ŝanĝi komandojn, formatigon aŭ signifon spite al la peto.
Ĉi tio produktas Markdown-kopiojn; ĝi ne rekonstruas la retumilon aŭ la gvidilojn de Info.

## `llm` en la komandlinio

`llm` sendas tekston al modelo kaj elprintas la respondon, do ĝi taŭgas en kaskado kun aliaj komandoj. La sama komando funkcias kun loka modelo kaj kun Claude.

```sh
vikix ai llm                               # once: install it (or vikix add llm)
cat notes.md | llm "summarise this"
git diff | llm "write the commit message"
llm "what does chmod 750 mean?"
llm -m llama3.2:3b "..."                   # a local model, by name
llm -m claude-sonnet-5 "..."               # Claude, with your API key
```

Ĝia defaŭlta modelo estas loka, se vi havas lokalan modelon, altrimenti Claude, se vi agordis ŝlosilon de Anthropic. Por elekti: `vikix ai llm --default MODEL`.

Ĉio, kion vi demandas, estas registrita: `llm logs -n 5` montras la lastajn kvin, kaj `llm logs off` haltigas la registradon.

## Demandado de viaj notoj: `note`

`note` respondas al demandoj el dosierujo de Markdown, ekzemple, Obsidian-depoteto, en ajna terminalo. `vikix add notes` instalis ĝin (kaj lokan AI, kiun ĝi bezonas), poste:

```sh
note index ~/General --skip Admin,Readwise   # the first time: about five minutes a thousand notes
note ask "what did I write about runit?"     # the answer, and the notes it came from
note index                                   # after changes, from anywhere: only what changed
```

`note find "..."` listigas la plej proksimajn notojn sen respondo, kaj `note status` montras la dosierujon, la indekson kaj kiu respondas.

Ĝi funkcias en du paŝoj. `note index` disigas ĉiun noton en partojn ĉe ĝiaj titoloj kaj transformas ĉiun en enmeton, liston de nombroj reprezentantaj ĝian signifon, kun eta modelo sur la portebla komputilo. `note ask` faras la saman kun la demando, prenas la ses plej proksimajn partojn kaj generas modelan respondon nur el ili, indikante la notojn. La listo de notoj, kiu estas presita sub ĉiu respondo, permesas kontroli ĝin: eta loka modelo foje respondas el la malĝusta noto.

Kiu respondas sekvas Super+i (`vikix ai use local` aŭ `claude`); `note ask --claude` aŭ `--local` elektas por unu demando. Loke, nenio forlasas la porteblan komputilon. Kun Claude, la ses trovitaj partoj, neniam la tuta dosierujo, estas sendataj al Anthropic, kaj la respondoj estas multe pli bonaj. Dosierujojn, kiujn vi neniam sendus ie ajn, forlasu kun `--skip`: ili eĉ ne estos legataj. Kaŝitaj dosieroj kaj dosierujoj (`.obsidian`, la `.#note.md`, kiun Emacs lasas dum noto ne estas konservata) ankaŭ ne estos uzataj.

Viaj elektoj estas en `~/.config/vikix/notes`: `folder=`, `skip=`, kaj `embed=`, la modelo por enmetoj. `nomic-embed-text` (post `ollama pull nomic-embed-text`) trovas pli bonajn partojn ol all-minilm, sed estas pli malrapida; ŝanĝi ĝin signifas, ke ĉiu noto estos denove legata. La indekso estas `~/.local/share/vikix/notes/index.db`, en dosierujo, kiun nur vi povas legi; `vikix notes uninstall --index` forigas ĝin.

## Viaj propraj programoj: `~/dev/ai`

Por vidi, kiel la resto funkcias, aŭ por konstrui ion propran, `~/dev/ai` enhavas kvar etajn programojn, kiujn vi povas legi, uzi kaj modifi. Ĉiu havas README kaj `make run`:

| Ekzemplo | Kion ĝi montras | Kion ĝi bezonas |
|---|---|---|
| `claude` | Unu demando al Claude: `ask.py` kun la Python-biblioteko de Anthropic, `ask.sh` kun curl kaj jq, unu HTTP-peto | Klavo de Anthropic (`vikix ai key set anthropic`) |
| `local` | La sama demando al modelo sur la portebla komputilo, per la API de Ollama | `vikix add local-ai` kaj modelo |
| `embeddings` | Propoziĵoj transformitaj en nombrojn, konservitaj en SQLite (sqlite-vec), la plej proksimaj al demando laŭ signifo | Ollama, kaj `make setup` (all-minilm, 46 MB) |
| `ask-notes` | Dosierujo de Markdown-notoj, serĉataj kaj respondatitaj | La sama, kaj modelo por respondi (aŭ klavo) |

`ask-notes` estas `note` reduktita, por legi kaj modifi; por ĉiutaga uzo, `note` estas la ĉefa. Ĝi funkcias ankaŭ kun viaj propraj notoj:

```sh
cd ~/dev/ai/examples/ask-notes
make setup                                          # once
make index NOTES=~/General SKIP=Admin,Readwise      # about five minutes a thousand notes; later, only what changed
make ask QUESTION="What did I write about runit?"   # the local model answers, naming the notes
make ask QUESTION="..." CLAUDE=1                    # Claude answers: those six passages go to Anthropic
```

La indekso, `notes.db`, restas en tiu dosierujo kaj enhavas fragmentojn el viaj notoj: `make clean` forigas ĝin. Kaŝitaj dosieroj kaj dosierujoj (`.obsidian`, la `.#note.md`, kiun Emacs lasas dum noto ne estas konservita) neniam estas legataj, kaj `SKIP` forigas tiujn, kiujn vi neniam sendus ie ajn.

La malgrandaj modeloj estas rapidaj, sed preterlasas aferojn: `all-minilm` foje rangigas la malĝustan noton unue, kaj modelo de 3 gigaojto respondas bazante sin sur ĉio, kio estas donata al ĝi. Ĉiu respondo listigas la notojn, kiuj estis donataj al ĝi, do vi povas kontroli. `EMBED_MODEL=nomic-embed-text` (post `ollama pull nomic-embed-text`, poste reindeksu) trovas pli bonajn fragmentojn, kaj `CLAUDE=1` donas pli bonajn respondojn.

La Python-skriptoj nomas siajn bibliotekojn ĉe la supro, fiksante ilin (`# /// script`), kaj `uv run` alportas ilin la unua fojo, do nenio estas instalata por la tuta maŝino.

## AI sur la elektita teksto

Elektu iun tekstfragmenton ie ajn, en retejo, retpoŝto, terminalo, kaj premu **Super+i**. Menuo demandas, kion fari kun ĝi:

| Opcio | Kion vi ricevas |
|---|---|
| Demandu pri ĝi | Tipe demandon pri la teksto (aŭ elektu nenion, kaj demandu ion ajn) |
| Korektu | La tekston kun ĝiaj eraroj korektitaj, en la interŝanĝilo |
| Reskribu: pli klara | La sama afero dirita pli klare, en la interŝanĝilo |
| Traduku | En la lingvon, kiun vi elektas, en la interŝanĝilo |
| Klarigu | Kion ĝi signifas; por eraromesaĝo, kiel korekti ĝin |

Kio estas metita en la interŝanĝilon ankaŭ estas montrita en notifo; algluu ĝin, kie vi volas. Korektu ankaŭ listigas, kion ĝi ŝanĝis: malgrandaj modeloj foje "korektas" tion, kio estis ĝusta. Mallonga respondo aperas kiel notifo, pli longa en terminalo (`q` fermas ĝin). La teksto estas tio, kion vi lastfoje markis, eĉ se ĝi ne plu estas markita sur la ekrano; nur kiam ne estas teksto, ĝi uzas tion, kion vi kopiis. La notifo, dum ĝi funkcias, montras la komencoon de la teksto, kiun ĝi prenintis.

Ĝi bezonas `llm` (`vikix ai llm`) kaj lokan modelon. Malgranda modelo prenas kelkajn sekundojn: ĉirkaŭ 10 sekundojn por frazo, por korekti aŭ klarigi.

### Loka aŭ Claude

Por ŝanĝi, elektu *Uzu Claudon anstataŭe* (aŭ *Uzu la lokan modelon anstataŭe*) ĉe la fino de la Super+i-menuo, aŭ tipu `vikix ai use claude` aŭ `vikix ai use local`. Tria opcio, Codex, estas pli sube. La elekto estas konservata en `~/.config/vikix/ai`, kiu komencas kiel:

```sh
use=local          # free, offline, the text stays on this laptop
model=             # empty: llama3.2:3b, or your first local model
languages=English Esperanto French Spanish Arabic Hindi
```

Por pli bonaj respondoj, precipe tradukoj al Esperanto, kiujn malgrandaj modeloj ne sukcesas, uzu Claude. Tiam ĉiu uzo kostas iomete, kaj la teksto, kiun vi elektis, estas sendata al Anthropic, do unue ĝi bezonas vian ŝlosilon: `vikix ai key set anthropic`. Super+i neniam memstare ŝanĝiĝas al Claude, kaj ĝia menuo ĉiam indikas la modelon kaj kie la teksto estos sendata.

### Codex

Se vi havas Codex (`vikix add codex`) kaj estas enŝaltita (`codex login`), ĝi ankaŭ povas respondi al Super+i: `vikix ai use codex`, aŭ *Uzu Codex anstataŭe* ĉe la fino de la menuo. Ĝi uzas la propran enŝaltiĝon de Codex, vian ChatGPT-konton, do ĝi ne bezonas ŝlosilon, kaj la teksto, kiun vi elektis, estas sendata al OpenAI. La modelo estas tiu, al kiu Codex estas agordita (`~/.codex/config.toml`), aŭ tiu, kiun `model=` indikas. Respondo prenas kelkajn dek sekundojn.

Por pli rapidaj respondoj, indiku pli rapidan modelon kaj pli malaltan "penadon" (kiom multe ĝi "pensas") en `~/.config/vikix/ai`. Ili validas nur por Super+i kaj Super+F10, do Codex en la terminalo restas kiel vi agordis ĝin:

```sh
use=codex
model=gpt-6-luna   # Codex's /model lists them
effort=low         # low, medium or high; empty: Codex's own setting
```

Tio ĉi reduktas la respondotempon al kvin aŭ ses sekundoj, kaj eĉ malpli: ĉiu respondo enhavas la proprajn instrukciojn de Codex. `model=` estas unu linio por ĉiuj tri elektoj, do forigu ĝin antaŭ `vikix ai use claude` aŭ `local`; `effort=` estas nur por Codex.

Codex estas agento, ne ĉatmodelo: memstare ĝi ekzekutas komandojn, serĉas en la interreto kaj aliras la programojn ligitajn al via konto de ChatGPT, kiel poŝto kaj GitHub. La teksto, kiun vi elektas, povas veni de iu ajn paĝo, kaj paĝo povas enhavi linion skribitan por agento. Tiel Super+i petas al Codex, kun ĉiuj ĉi tiuj funkcioj malŝaltitaj, nur-leganta, en malplena dosierujo, kaj nenion konservas el la sesio: tia linio ne trovas ion, kun kiu agi. Se pli posta versio de Codex ne plu konas unu el tiuj ŝaltiloj, Super+i diras tion kaj ne donas respondon, ĝis `vikix update` alportas la novan liston.

Super+F10 sekvas, unu demando je la fojo: Codex ne daŭrigas la konversacion. La ĉatoj de la redaktoroj kaj `note` konas nur lokalan modelon kaj Claudon, kaj restas sur la lokala modelo dum Super+i estas sur Codex.

## AI en Neovim

La Neovim de Vikix havas [CodeCompanion](https://codecompanion.olimorris.dev), sub **Space A**:

| Klavoj | Kion ili faras |
|---|---|
| `Space A c` | Ĉato apud via kodo, sur la modelo, kiun Super+i uzas: lokala modelo, aŭ Claude |
| `Space A q` | Petu informojn pri la elekto (aŭ la dosiero), aŭ petu ŝanĝon al ĝi |
| `Space A a` | Aldonu la elekton al la ĉato |
| `Space A g` | Ĉato kun via agento (la agento, kiun Super+a startas), kiu povas legi kaj ŝanĝi viajn dosierojn |
| `Space A t` | Via agento en terminalo ene de Neovim |
| `Space A p` | Ĉio alia, kion CodeCompanion faras |

La ĉato sekvas `vikix ai use`: `local` (modelo sur ĉi tiu komputilo, unue `vikix ai setup`) aŭ `claude` (via ŝlosilo: `vikix ai key set anthropic`). Modelo fiksita per `model=` en `~/.config/vikix/ai` ankaŭ estas uzata ĉi tie. Sur la CPU de komputilo, la unua respondo de lokala modelo prenas minutojn, ĉar ĝi unue legas la instrukciojn de CodeCompanion; Claude respondas en sekundoj. La supra linio de la ĉato diras, kiu respondas, antaŭ ol vi tajpas: la modelo, kaj ĉu ĝi estas sur ĉi tiu komputilo aŭ sendita al Anthropic (aŭ kiu agento). En la ĉato, `ga` ŝanĝas la modelon aŭ la agenton por tiu ĉato.

La agento en `Space A g` estas startita per `vikix agent --acp`, do ĝi estas la sama kiel tiu de Super+a: la gvidilo, sen API-ŝlosiloj, kaj unue estas kreita kopio, do `vikix changes` montras, kion ĝi faris, kaj `vikix undo` malfaros tion. Ĝi ensalutas kun sia propra uzantonomo, tiu, kiun ĝi uzas en terminalo. Claude Code kaj Codex bezonas sian adaptilon, kiun `vikix agent --install claude` aldonas (se vi faras ĝin denove por agento, kiun vi jam havas, ĝi nur aldonas tion, kio mankas). `Space A t` efektive faras `vikix agent`, do Aider ankaŭ funkcios tie.

Nenio komenciĝas aŭ konektiĝas ĝis vi premas klavon. Kiam io mankas (ŝlosilo, Ollama, la agento aŭ ĝia adaptilo), la klavo diras, kion tajpi, kaj nenion alian.

## AI en Emacs

La konfiguracio de Emacs havas [gptel](https://github.com/karthink/gptel) por la ĉato kaj [agent-shell](https://github.com/xenodium/agent-shell) por via agento, kaj Vikix agordas ambaŭ:

| Klavoj | Kion ili faras |
|---|---|
| `C-c g` | Ĉato, sur la modelo, kiun Super+i uzas: lokala modelo, aŭ Claude. Kun elekto, la ĉato komenciĝas de ĝi |
| `C-c G` | La menuo de gptel: alia modelo por ĉi tiu ĉato, kaj kion sendi. Claude kaj viaj lokaj modeloj aperas unue; unu el la propraj modeloj de la konfiguracio (OpenAI, Perplexity) aperas nur se ĝia ŝlosilo estas tie |
| `C-c a` | Ĉato kun via agento (la agento, kiun Super+a startas), kiu povas legi kaj ŝanĝi viajn dosierojn. Ĝi revenas al la ĉato de ĉi tiu projekto, se ekzistas; de dosierujo, kie ne ekzistas, ĝi petas (*New shell* komencas ĉato tie; la aliaj iras al ĉato en alia dosierujo). `C-u C-c a` ĉiam komencas novan |
| `C-c A` | Via agento en terminalo ene de Emacs |

La ĉato sekvas `vikix ai use` kaj `model=`, kiel ĉe Neovim, kaj Emacs re-legas ilin ĉe ĉiu `C-c g`, do ŝanĝo atingas Emacson, kiu jam estas malfermita. Modelo, kiun vi elektas en la menuo, restas ĝis vi ŝanĝas tiun dosieron. La agento startas per `vikix agent --acp`, kun la samaj reguloj kiel en Neovim, supre; `C-c A` efektive faras `vikix agent`, do Aider funkcios tie ankaŭ. Kiam io mankas, la klavo diras, kion tajpi. [Neovim kaj Emacs](editors.md) komparas la du.

## La labortablo kiel iloj (MCP)

MCP estas kiel AI-agento ricevas siajn proprajn ilojn. `vikix mcp register` donas al via agento fiksitan aro da iloj por ĉi tiu labortablo, do ĝi povas rigardi ĝin kaj fari malgrandajn ŝanĝojn sen skribi komandojn.

Kial, kiam la agento ja povas ekzekuti komandojn? Ĉiu komando bezonas vian akcepton. Ĉi tiuj iloj estas malmultaj, kontrolitaj kaj facile malreversigeblaj, do vi povas permesi ilin unufoje: en Claude Code, respondu "permesi ĉiam" por vikix-ilo (aŭ permesi `mcp__vikix__*`). Tiam la agento rigardas la labortablon kaj ŝanĝas temon aŭ fenestron sen peti ĉiufoje, dum ĉiu alia komando ankoraŭ petas.

```sh
vikix mcp register     # for Claude Code and Antigravity CLI, then restart them; it prints the lines for Codex, Gemini CLI and OpenCode
vikix mcp status       # is it on, with which tools, the servers running (and their version), the last calls
vikix mcp tools        # what it offers
vikix mcp unregister   # take it away
```

| Ilo | Kion ĝi faras |
|---|---|
| desktop | La labortaboj kaj iliaj fenestroj (ankaŭ la kolumnoj de [baraĵo](strip.md), en ordo), la ekranoj, la temo |
| keys | Ĉiu klavo, kiun Vikix ligas, kaj kion ĝi faras |
| rules | La reguloj de la labortablo (ĉiu numero, ŝaltita aŭ malŝaltita, kie ĝi estas skribita, kiel ofte ĝi ekzekutiĝis), kaj por fenestro, kiun vi nomas, kiuj reguloj aplikiĝis al ĝi kaj kiuj kongruas kun ĝi sed ne aplikiĝis. Nenio estas ŝanĝita aŭ ekzekutita |
| why | Kion la labortablo faris lastatempe kaj kio kaŭzis tion: klavo kaj ĝia komando, regulo kaj ĝia fenestro, la menuo, agento; ĉiu kun la loko, kie ĝi estas skribita. Por "kial mia fenestro moviĝis?" |
| agents | La agentoj, kiuj funkcias en la labortablo, la agento, kiu demandadas inter ili: la dosierujo, branĉo, nekomunikitaj dosieroj, labortaboj de ĉiu, dum kiom da tempo, kaj kion ĝi faras. Tiel, agento povas vidi, ke alia agento funkcias en dosierujo antaŭ ol ĝi ŝanĝas dosierojn tie |
| handoff, handoff_update | Legas aŭ ĝisdatigas la datumojn pri transdono de la labortablo: tasko, stato, resumeto, sekva, kontrolas per freŝeco, sesioj |
| doctor, history, changes, themes, version | Kion diras `vikix doctor`, `vikix history`, `vikix changes`, `vikix theme` kaj `vikix version` |
| docs_search, docs_read | Trovas kaj legas la dokumentojn en ĉi tiu maŝino, tiujn, kiujn `Super+F2` serĉas: ĉi tiuj gvidiloj, manpaĝoj, la dokumentoj kaj PDF-aj dosieroj de viaj projektoj, viaj notoj, la eniroj de la dokumentaroj de Zeal; kiel ligilo al la interreto, estas donita nur ĝia adreso, neniam ĝi estas ŝarĝata. Tiel, la agento povas respondi de la manpaĝo, ne de la memoro. Viaj propraj dokumentoj (`own=` en `~/.config/vikix/docs`) restas fermitaj por ĝi, kiel ankaŭ por `vikix docs ask`, ekzekutita de agento, krom se linio `agents=` malfermas dosierujon |
| records_search, records_get | Trovas kaj legas, kion viaj kromprogramoj konservas (`vikix records`): flugaj serĉoj, kunvenoj, la uzo de via plano de Claude. Ĝi ne povas aldoni aŭ ŝanĝi datumon |
| file_changes | Ĉiu ŝanĝo farita al viaj dosieroj per Esploro (`vikix add esploro`), la plej novaj unue, en vortoj, kaj ĉu ĝi estis forigita. Por "kie tiu dosiero iris?". Ĉi tie nenio estas forigita: tio restas via, en Esploro, Redakti → Ŝanĝoj… |
| notify | Montras sciigon, markitan kiel apartenan al la agento |
| snapshot | Registras viajn agordojn antaŭ ŝanĝo |
| set_theme, switch_workspace, focus_window | Malgrandaj ŝanĝoj, facile forigeblaj |
| commands | La komandoj de la labortablo, kiujn la agento povas ekzekuti per sia nomo: ŝanĝoj kaj movoj estas rekreitaj tiel facile kiel faritaj (ne ĝenu, nokta lumo, interspacoj, titolaj vidoj, fokuso maldekstre...) |
| run_command | Ekzekutas unu el tiuj, kiel farus ĝia klavo. La labortablo rifuzas ajnan alian komandon, kaj diras kial |
| propose_file_changes | Proponas planon de ŝanĝoj al viaj dosieroj (kopiu, movu, renomu, novaj dosierujoj, la rubujo, etikedoj), kiu atendas vin: unue kontrolite, poste montrita en Esploro kun kialo, kie nur via Apliki ekzekutas ĝin, kaj forigo reigas ĝin. Sen Esploro, ne estas loko por montri ĝin, kaj la ilo diras tion |
| propose_rule | Proponas regulon por la labortablo, kiu atendas vin: unue kontrolita por esti nur regulo (verboj kaj simplaj valoroj, ne Lisp de si mem), poste montrita sub `Super+m` → *Reguloj*, kie vi aldonas ĝin al via `rules.lisp` aŭ forlasas ĝin ([Reguloj](rules.md#regulo-kiun-agento-proponas)) |

Du plu estas neaktivigitaj, krom se vi aktivigas ilin, ĉar ili povas multe ŝanĝi: `vikix mcp register --allow-eval` aldonas **eval** (Lisp en la fenestradministrilo, tra la pordo, sube) kaj **cuis_eval** (Smalltalk en la Cuis-bildo, tra la propra esplorilo de la bildo, sube) kaj `--allow-undo` aldonas **undo** (viaj agordoj reen al unu antaŭa stato). `vikix mcp register` denove, sen ili, forigas ilin. Ili estas komforto, ne ŝloso: agento, kiu povas ekzekuti komandojn, povus ekzekuti `vikix eval` mem, kaj tio ankaŭ pasas tra la pordo.

### La pordo

La Lisp de agento estas kontrolata antaŭ ol ĝi estas ekzekutita. Sendepende de la vojo, kiun ĝi prenas, `vikix eval` en la propra ŝelo de la agento aŭ la `eval` de la MCP-servilo, la formo estas legata sen io ekzekutanta (nenio de `#.`), kaj poste esplorata: ĉiu funkcio, kiun ĝi vokas, estas serĉata en unu listo, de tio, kio legas la labortablon (la fenestroj, la labortaboj, klavo) kaj tio, kio estas rekreita tiel facile kiel farita (ŝanĝo de labortaboj, movo, temo, la komandoj, kiujn `run_command` povas ekzekuti). Formo farita nur el tiuj, ekzekutata. Formo, kiu ekzekutas programon, tuŝas dosieron, difinas aŭ ŝanĝas kodon, agordas tutmondan agordon de la labortablo, atendas eniron aŭ finas la sesion, estas **retenata**: nenio el ĝi estas ekzekutita, la agento estas informita pri la kialo (kaj ke ĝi ne provu alian vojon), kaj sciigo diras, ke agento sendis Lisp, la pordo retenis ĝin. `Super+m` → *Pordo* listigas, kio atendas: elektu unu por vidi ĝin, ekzekutu ĝin kiel vi, aŭ forlasu ĝin. La pordo ankaŭ kalkas, krom la klavoj (`vikix used`): la nomoj sur ĝia listo, la formo, kiun ĝi pasas, la nomo, kiu retenis la formon, kaj ĉu vi poste ekzekutis aŭ forlasis ĝin, nur nomoj kaj neniam la teksto de la formo. `vikix door used` legas la nombron, kaj ĝi estas tio, kio diras, ĉu la listo estas ĝusta: nomo, kiu neniam estis vokata, povas iri, unu, kiu estis retenata ofte kaj ĉiam ekzekutita, estas dezirata. La sama de terminalo:

```sh
vikix door                 # what waits: when, which agent, why, the form
vikix door run 1           # run it, as you
vikix door drop 1          # forget it
vikix door check '(form)'  # would it pass? "ok", or why not
vikix door allowed         # every name a form may call
```

Funkcio en via propra `user.lisp`, kiun agento povas voki, estas lokigita en `~/.config/vikix/door`, unu nomo por linio. Via propra `vikix eval` en terminalo estas por vi kaj ne estas kontrolata; nur skelo sub agento (Claude Code, Codex, OpenCode, Gemini, Aider, Antigravity) estas por la agento, kaj skripto de Vikix, kiun la agento faras (`vikix theme vikix-light`), sendas Lisp-on de Vikix, ne de la agento. Formo, kiu atingas skelon, dosieron, `eval` aŭ la sistemon, ankaŭ estas skribita en `~/.local/state/vikix/errors/`, do `vikix doctor` kaj `vikix debug` konservas la provon. Maksimume dek formoj atendas; post tio, al agento estas rifuzita aliro ĝis vi kontrolis.

La Cuis-bildo havas sian propran "pordon" (`vikix eval --cuis`; la funkcio `cuis`), kaj Smalltalk de agento estas uzata tie same, en la bildo: ĉiu tutmonda variablo, kiun ĝi nomas, kaj ĉiu mesaĝo, kiun ĝi sendas, estas serĉata en la listoj de la "promenanto" (`VikixWalker allowedGlobals` kaj `allowedSelectors` en la bildo; viaj propraj nomoj de la sama `~/.config/vikix/door`), kio atingas programon, dosieron, soketon, la kompililon aŭ la sistemon estas rifuzita, kio difinas kodon, starigas tutmondan variablon aŭ atendas, estas konservita, kaj tiel estas ĉio, kio ne estas en la listoj. Konservita esprimo atendas en la bildo, maksimume dek: en Workspace tie, `VikixServer held` listigas ilin, `VikixServer runHeld: 1` faras unu kiel vi, `VikixServer dropHeld: 1` forgesas ĝin; al la agento estas dirita kial, kaj notifo diras, ke agento sendis Smalltalk-on al la "pordo", kiu estis konservita.

Ĝi funkcias nur por la agento, kiu ĝin lanĉas: nenio aŭskultas en la reto. Ĉio, kion la agento petas de ĝi, unue estas kontrolata (Workspace, kiu ekzistas, temo, kiun vi havas). Sekretoj estas forigitaj el tio, kion ĝi redonas (`changes` montras la diferencojn de viaj dosieroj). Ĉiu voko, inkluzive de tiuj, kiuj estas rifuzitaj, estas skribita en `~/.local/state/vikix/mcp.log`, nur por vi: la ilo, ĉu ĝi funkciis, kaj ĝiaj argumentoj. Ĝiaj notoj komenciĝas per "Agento:". Post `vikix update`, ĝi mem faras la novan version, sen ke la agento rekonektiĝas.

## Diktaĵo

Premu **Super+F9** kaj parolu. Premu **Super+F9** denove, kaj post momento, kion vi diris estas enmetita en la fenestron, en kiu vi estis: du aŭ tri sekundoj por frazo, proksimume dek sekundoj por minuto da parolo. Ĝi ankaŭ estas metita en la interŝanĝon, se tiu fenestro ne akceptis ĝin. Se vi moviĝas al alia fenestro dum ĝi estas skribata, ĝi ne estas enmetita tie: ĝi estas nur metita en la interŝanĝon, kaj notifo diras tion. **Super+Shift+F9** haltigas sen enmeti ion. Dum ĝi aŭskultas, la baro montras **mic**, en ruĝo.

Ĝi estas premado, parolo, premado: StumpWM vidas, ke klavo estas premita, ne levita, do teni la klavon dum vi parolas ne estas ebla (repetoj de tenita klavo estas kalkataj kiel unu premado).

Ĝi aŭskultas maksimume kvin minutojn. Tiam ĝi haltas, diras tion, kaj la sekva **Super+F9** enmetas tion, kion ĝi aŭdis. Post ĉiu diktaĵo aperas spaco, do la sekva ne kunigas kun ĝi.

Por agordi ĝin, unufoje (kelkaj minutoj, sen pasvorto):

```sh
vikix add dictation          # or: vikix dictate setup
```

Tio kompilas [whisper.cpp](https://github.com/ggml-org/whisper.cpp) por ĉi tiu komputilo, en la dosierujon `~/.local/opt/whisper.cpp`, kaj elŝutas ĝian modelon (150 MB) kaj voĉ-detektilon (1 MB) en la dosierujon `~/.local/share/vikix/whisper/`, ĉiu el ili estas kontrolata kontraŭ ĝia publikigita kontrolsumo. Ĉio funkcias sur la portebla komputilo: via voĉo neniam forlasas ĝin, kaj la registrado estas forigita post kiam ĝi estas skribita.

**Angla, aŭ multaj lingvoj.** La modelo, kun kiu ĝi komencas, `base.en`, konas nur la anglan, kaj skribas frazon en ĉirkaŭ unu sekundo. `small` konas multajn lingvojn (franĉa, hispana, araba, hindia kaj aliaj; ne Esperanto) kaj bezonas kelkajn sekundojn:

```sh
vikix dictate models          # which is used
vikix dictate models small    # many languages (490 MB)
vikix dictate models base.en  # back to English
```

**Silento kaj bruo ne estas tajpitaj.** La detektilo de voĉo transdonas nur paroladon al la programo "whisper", kaj la notoj de "whisper" pri sonoj, kiel "(muziko)", estas forlasataj: ĉio, kion ĝi skribas en krampoj, estas forigata, do ankaŭ parolita digresio en krampoj estos forigata. Tre mallonga fragmento (unu aŭ du sekundoj) povas aperi kiel vorto aŭ du, kiujn neniu diris.

**Kio restas poste:** la registrado estas forigata, kiam ĝi estas skribita. La teksto restas tie, kie ĝi estis tajpita, en la interŝimbaŭro (do en sia historio, Super+c), kaj en la notifo "Tajpita" (Super+Shift+n montras la pli malnovajn).

`vikix dictate status` diras, ĉu ĝi estas agordita, kaj kun kiu modelo. `vikix dictate file talk.wav` elprintas, kion registrado, kiun vi jam havas, diras, sen tajpi ĝin ie ajn.

Por forigi ĝin: `vikix remove dictation` (la modeloj restas; `vikix dictate uninstall --models` forigas ilin ankaŭ).

## Parolado kun la AI

Dikta programo tajpas kion vi diras. Voĉo sendas ĝin al la AI anstataŭe, kaj la respondo revenas laŭte.

| Klavo | Kio okazas |
|---|---|
| **Super+F10**, parolu, **Super+F10** | La ĉata modelo respondas: tiu, kiun Super+i uzas (loka, Claude aŭ Codex, kiu prenas ĉiu demandon aparte). Vi aŭdas la respondon kaj vidas ĝin en notifo (longa notifo aperas en terminalo) |
| **Super+F11**, parolu, **Super+F11** | Ĝi iras al la agento, Claude Code, en sia propra terminalo. La respondoj de Claude estas legataj laŭte |
| **Super+Shift+F10** | Halta la paroladon |

**Ĝi memoras la konversacion.** Demandu "Kio estas la ĉefurbo de Francio?", poste "Kaj kiom da homoj loĝas tie?", kaj ĝi scias, ke vi celas Parizon. Post kvin silentaj minutoj la sekva demando komenciĝas freŝe; Super+m → *Voĉo: nova konversacio* faras tion tuj. Kun la agento, ĉiu demando post la unua iras al la sama terminalo, do ĝi daŭrigas tie ankaŭ; fermu tiun terminalon por komenci denove.

**Ĝi haltas la paroladon, kiam vi komencas.** Premante Super+F10 aŭ Super+F11 por paroli, ĝi tuj haltas, do la mikrofono ne aŭdas ĝin.

Por agordi ĝin, unufoje (unu minuto, sen pasvorto):

```sh
vikix add voice            # brings dictation and llm, if they aren't here
```

Tio instalas [Piper](https://github.com/OHF-Voice/piper1-gpl), voĉon, kiu funkcias sur ĉi tiu portebla komputilo, kaj elŝutas voĉon por ĝi (60 MB, kontrolita per ĝia publikigita kontrolsumo).

**Kie viaj vortoj iras.** La aŭskulto estas diktado: sur ĉi tiu portebla komputilo. Demando al Super+F10 sendas la tekston tien, kie Super+i sendas ĝin (neniel, kun loka modelo; al Anthropic, kun Claude; al OpenAI, kun Codex: `vikix ai use`). Demando al Super+F11 sendas la tekston al la kompanio de la agento, kiel kun Super+a. La respondo estas prononcata sur ĉi tiu portebla komputilo.

**Viaj elektoj** troviĝas en `~/.config/vikix/voice`:

```sh
vikix voice voices          # which voice: lessac, amy (American), alan (British)
vikix voice voices alan     # switch (it downloads the voice)
```

Meti `speak=no` tie ĉi, por vidi nur la respondojn, aŭ `idle=` por ŝanĝi la kvintan minuton. `vikix voice say "iu teksto"` legas ajnan tekston laŭte.

Nur la respondoj de Claude Code estas legataj laŭte: kun alia agento (`vikix agent --default`), Super+F11 ankoraŭ sendas vian demandon, kaj la respondo restas sur la ekrano.

Por forigi ĝin: `vikix remove voice` (la voĉoj restas; `vikix voice uninstall --voices` forigas ilin ankaŭ).

## Kiam AI ne funkcias

| Kio okazas | Kion fari |
|---|---|
| Super+a montras mesaĝon kaj "Eniru fermas ĉiun fenestron" | Ĝi diras, kio mankas: agento por instali, ŝlosilo, loka modelo |
| Super+a malfermas terminalon, kiu tuj fermiĝas | Rulu `vikix agent` en terminalo por vidi la mesaĝon |
| La agento petas, ke vi ensalu ĉiufoje | Rulu `claude` unufoje en terminalo kaj finu la ensaligon tie |
| La agento diras, ke ĝi ne povas atingi la labortablon | `vikix doctor`: ĝi kontrolas, ĉu `vikix eval` funkcias |
| Loka modelo ne respondas, aŭ estas malrapida | Vidu [Loka AI ne respondas](fixing.md#loka-ai-ne-respondas) |
| `llm` ne havas modelon, petas ŝlosilon, aŭ ne povas konekti | Vidu [`llm` ne respondas](fixing.md#llm-ne-respondas) |
| Super+i diras "Super+i bezonas llm", "Ankoraŭ ne ekzistas loka modelo" aŭ "Loka AI ne funkcias" | Faru tion, kion ĝi diras: `vikix ai llm`, modelo kun Super+m → *Loka AI: elektu modelon*, aŭ `vikix ai setup` |
| Super+i diras "Unue elektu iom da teksto" | Marku la tekston (aŭ kopiu ĝin), poste premu Super+i denove |
| Super+F9 diras "Dikto ne estas agordita" | `vikix add dictation`, unufoje |
| Super+F10 respondas, sed nenio estas aŭdata | `vikix voice status`; `speak=no` en `~/.config/vikix/voice` malŝaltas la voĉon; kontrolu la volumon kaj la eliron en pavucontrol |
| "Voĉo ne estas agordita" | `vikix add voice`, unufoje |
| Super+F9 diras "Aŭdis nenion" | La mikrofono: `pavucontrol`, *Enigaj aparatoj*, kontrolu, ĉu ĝi ne estas mute kaj moviĝas, kiam vi parolas |
| Super+F9 tajpas en la malĝusta loko | Ĝi tajpas tie, kie estas la fokuso, kiam vi premas la duan Super+F9; la teksto ankaŭ estas en la intertavolo |
| Super+i diras "AI ankoraŭ laboras pri la lasta" | Atendu ĝian respondon: unu post la alia |
| Super+i diras "Vi ne havas la modelon..." | `vikix ai models` akiras ĝin, aŭ lasu `model=` en `~/.config/vikix/ai` malplena |
| Super+i diras "Claude bezonas vian ŝlosilon de Anthropic" | `vikix ai key set anthropic`, aŭ reveni al loka: `vikix ai use local` |
| Super+i diras "AI ne respondis" | La notifo diras, kial; loka modelo: `vikix ai status` |
| Super+i diras "Codex ne estas instalita" aŭ "ne estas ensaligita" | `vikix add codex`, poste `codex login`; aŭ reveni al loka: `vikix ai use local` |
| Super+i diras, ke io en `~/.config/vikix/ai` ŝajnas esti erara | Korektu tiun linion (`use=local`, `use=claude` aŭ `use=codex`; `model=` nomo el `llm models`, aŭ unu el Codex; `effort=` vorto kiel `low`), aŭ forigu la dosieron: la sekva Super+i skribos ĝin denove |
| Super+i prenis la malĝustan tekston | Ĝi prenas la lastan markitan tekston, antaŭ la intertavolo: marku la tekston, kiun vi celas |
| `note` diras "ankoraŭ ne ekzistas dosierujo" aŭ "ankoraŭ ne ekzistas indekso" | `note index ~/Notes` unufoje (via dosierujo; `--skip A,B` forlasas dosierujojn) |
| `note` diras, ke la indekso bezonas lokan AI, aŭ ne povas atingi Ollama | La indekso estas kreata sur ĉi tiu laptopo: `vikix add local-ai`, poste `vikix ai status` |
| `note ask` respondas de la malĝusta notoj | La notoj, kiuj estis donitaj, estas listigitaj sub la respondo. `note ask --claude` respondas pli bone; `embed=nomic-embed-text` en `~/.config/vikix/notes` trovas pli bonajn fragmentojn (post `ollama pull nomic-embed-text`; la sekva `note index` relege ĉiun noton) |
| La agento ne havas vikix-ilojn | `vikix mcp register`, poste restartigu la agenton; `vikix mcp status` diras, ĉu ĝi estas ŝaltita (vidu [Kiam io rompiĝas](fixing.md#la-agento-ne-havas-la-ilojn-de-la-labortablo)) |
| Vi ne ŝatas, kion la agento ŝanĝis | `vikix changes`, poste `vikix undo` |
