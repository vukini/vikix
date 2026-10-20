# Neovim kaj Emacs

Vikix havas du tekstredaktilojn, Neovim kaj Emacs, ĉiu kun prefere agordita versio, la lingvaj servoj por la lingvoj, kiujn vi aldonis, kaj AI: ĉatilo bazita sur la modelo Super+i, kaj via asisto (kiun Super+a lanĉas) apud via kodo. Neniu el ili estas instalita ĝis vi petas tion:

```sh
vikix add neovim        # or: vikix add emacs; the developer bundle brings both
vikix remove emacs      # takes it away again; your files stay
```

`essentials` alportas Emacs; `developer` kaj `everything` alportas ambaŭ. `$EDITOR` estas `nvim`, krom se vi agordas alian.

## Kiel komenci ilin

| Tipo aŭ premu | Kio malfermiĝas |
|---|---|
| `v FILE` | Neovim, en ĉi tiu terminalo |
| `Super+x` | Fenestro de Emacs |
| `e FILE` | La dosiero en nova fenestro de Emacs (la terminalo atendas ĝis vi fermas ĝin) |
| `eg FILE` | La sama, sed la terminalo estas tuj libera |
| `ec FILE` | Emacs ene de ĉi tiu terminalo |
| `eq` | Emacs sen ajna agordo: por trovi ĉu la agordo estas la problemo |
| `emacs-restart` | Nova Emacs, post kiam vi ŝanĝis ĝian agordon (ĝi rifuzas dum dosiero ne estas konservita, kaj demandos antaŭ fini aktivajn dialogojn) |

Emacs funkcias kiel servilo ekde la momento kiam vi ensalutas, do `Super+x` kaj `e` malfermas fenestron tuj. La unua fojo, kiam Emacs startas sur nova aparato, ĝi elŝutas siajn pakojn en la fono: donu al ĝi kelkajn minutojn antaŭ la unua `e`.

## Kiu posedas kion

La agordo de Neovim estas propra de Vikix, dividita en du kiel la agordo de la labortablo:

| Kie | Kiu | Kio |
|---|---|---|
| `~/.local/share/vikix/nvim` | De Vikix | AstroNvim kaj la kromprogramoj de Vikix. Ligo al `~/vikix`: `vikix update` tenas ĝin aktualigita, do ne redaktu ĝin |
| `~/.config/nvim` | Via | `init.lua` (viaj agordoj iras en ĝian finon), viaj kromprogramoj en `lua/plugins/`, kaj `lazy-lock.json`, la versioj de la kromprogramoj |

La agordo de Emacs estas aparta deponejo, propra de la aŭtoro ([emacs-void](https://github.com/vukini/emacs-void)):

| Kie | Kiu | Kio |
|---|---|---|
| `~/.emacs.d` | Git-klono | La agordo, `config.org`. `vikix update` alportas ĝin; ŝanĝo de vi tie povas haltigi la alporton (la ĝisdatigo diras tion kaj daŭrigas) |
| `~/.local/share/vikix/emacs` | De Vikix | `vikix-ai.el`, la agordo de la AI, `vikix-theme.el`, kiu igas Emacs sekvi la temon `vikix`, kaj `vikix-notes.el`, viaj notoj de Org en `~/Dropbox/notes` sub `C-c n` (la taglibro, la ĵurnalo, la ligoj kaj grafiko de org-roam). Ligo al `~/vikix`, tenita aktualigita de `vikix update`; la agordo ŝargas ilin kiam ili estas tie |

Ambaŭ estas en [kie ĉio estas](map.md), kun la resto de viaj dosieroj.

## Neovim

Neovim estas [AstroNvim](https://astronvim.com) kun kelkaj elektoj de Vikix: Typst kun vivanta antaŭrigardo (`:TypstPreview`), la parametroj de funkcio montrataj dum vi tajpas ĝian vokon, `jk` aŭ `jj` por foriri el la reĝimo de enigo, kaj la AI-klavoj sube. `Space` estas la ĉefa klavo: premu ĝin kaj atendu, kaj aperas menuo montranta kio venos.

Viaj kromprogramoj iras en `~/.config/nvim/lua/plugins/`, unu aŭ pluraj dosieroj kiuj ĉiu revenigas specifojn de kromprogramo. Ili ŝarĝiĝas post tiuj de Vikix, do la viaj venkas. `example.lua` tie montras kromprogramon pli, agordon de AstroNvim, unu el la kromprogramoj de Vikix malaktivigita, kaj alian koloraron. Simpla agordo (`vim.opt.…`) kaj klavoj (`vim.keymap.set(…)`) povas iri en la finon de `~/.config/nvim/init.lua`, post la linio kiu ŝargas la parton de Vikix.

La kromprogramoj estas instalitaj ĉe la versioj, kiujn Vikix testis, kaj `vikix update` movas ilin kiam Vikix testas pli novajn. La kromprogramoj, kiujn vi aldonas, konservas siajn proprajn versiojn. Post via `:Lazy update`, la kromprogramoj de Vikix ankaŭ konservas viajn versiojn: ĝisdatigoj lasas ilin sole kaj diras unufoje kiel preni la versiojn de Vikix reen.

## Emacs

La agordo de Emacs estas organizita en `~/.emacs.d/config.org`, unu sekcio por ĉiu koncerno (kompletigo, Org, Lisp, lingvoj, iloj), kaj ĉiu sekcio klarigas sin. Emacs legas ĝin ĉe la starto. SLIME en ĝi komunikas kun la kuranta fenestromanstro ĉe la pordo 4004 (vidu [Kiel ĝi kunfunkcias](how-it-works.md)).

Por ŝanĝi ĝin, redaktu `config.org` kaj ruligu `emacs-restart`. `vikix update` alportas la novan agordon de la AI de Vikix en Emacs, kiu jam funkcias, kun viaj dialogoj lasitaj malfermaj; Emacs, kiu startis sen ĝi (antaŭ Vikix 0.59), ricevas mesaĝon por restartigi, kaj `vikix doctor` diras, kian vi havas. La klono estas via por ŝanĝi, sed ŝanĝo tie povas haltigi `vikix update` de la alporto de la pli nova versio de la aŭtoro: konservu viajn ŝanĝojn en komito de via propra, aŭ en agordo de via propra (sube).

## Lingvaj servoj

Lingva servo estas kio permesas al la redaktilo kompletigi nomojn, iri al difino kaj sublinia erarojn dum vi tajpas. Ĉiu venas kun sia lingvo, do `vikix add c` alportas la C-on, kaj ambaŭ redaktiloj trovas ilin en PATH:

| Lingvo | Servo | Venas kun |
|---|---|---|
| C, C++ | `ccls`, `clangd` | `vikix add c` |
| Go | `gopls` | `vikix add go` |
| Rust | `rust-analyzer` | `vikix add rust` |
| Zig | `zls` | `vikix add zig` |
| Lua | `lua-language-server` | `vikix add lua` |
| JavaScript, TypeScript | `typescript-language-server` | ajn redaktilo (npm, en `~/.local/bin`) |
| Python | `pyright` | ajn redaktilo (npm) |
| Bash | `bash-language-server` | ajn redaktilo (npm) |
| OCaml | `ocaml-lsp-server` | `opam install ocaml-lsp-server`, post `vikix add ocaml` |

Neovim ankaŭ ricevas `efm-langserver`, kiu ruligas lintilojn kaj formatilojn. En Emacs, eglot startigas la servon kiam vi malfermas C, C++, JavaScript, TypeScript, Python, Zig aŭ Odin-dosieron.

## AI en la redaktiloj

Ambaŭ redaktiloj faras la samajn kvar aferojn, ĉiu sur la agordoj, kiujn vi jam faris por la labortablo:

| | Neovim | Emacs |
|---|---|---|
| Dialogo sur la modelo, kiun `Super+i` uzas | `Space A c` | `C-c g` |
| Demandu pri la elekto, aŭ ŝanĝu ĝin | `Space A q` | `C-c g` kun elekto, aŭ `C-c G` (la menuo de gptel) |
| Dialogo kun via asistanto | `Space A g` | `C-c a` |
| Via asistanto en terminalo | `Space A t` | `C-c A` |

**La dialogo** sekvas `vikix ai use`: `local` por modelo sur ĉi tiu laptopo (`vikix ai setup` unue), aŭ `claude` por Claude (kun via ŝlosilo: `vikix ai key set anthropic`). Modelo agordita kun `model=` en `~/.config/vikix/ai` ankaŭ uzas ĉi tie. Emacs refaras ĉi tiun dosieron ĉe ĉiu `C-c g`, do ŝanĝo atingas Emacs, kiu jam estas malfermita; modelo, kiun vi elektas en la menuo de gptel, restas ĝis la dosiero ŝanĝiĝas. Sur la CPU de laptopo, loka modelo povas preni minutojn por komenci respondi, ĉar ĝi unue legas la instrukciojn de la dialogo (tiuj de Neovim estas longaj); Claude respondas en sekundoj.

**Via asistanto** estas tiu, kiun Super+a startigas (Claude Code krom se vi elektis alian: `vikix agent --default NAME`). La redaktiloj startigas ĝin la same, kun `vikix agent`: ĝi ricevas la gvidilon al Vikix, neniu API-ŝlosiloj aŭ SSH-agento (la redaktiloj havas ilin, la asistanto ne bezonas ilin), kaj antaŭvidon unue, do `vikix changes` montras, kion ĝi faris, kaj `vikix undo` igas ĝin reeniri. Ĝi ensalutas kun sia propra ensaluto, la unu, kiun ĝi uzas en terminalo. En dialogo ĝi komunikas per ACP (la Protokolo de la Kliento de la Asistanto): Claude Code, Codex, Gemini CLI kaj OpenCode parolas ĝin, kaj `vikix agent --install NAME` aldonas unu kun tio, kio estas bezonata (ruligi ĝin denove por asistanto, kiun vi havas, aldonas nur tion, kio mankas). Aider kaj Antigravity CLI ne: ilia loko estas la klavo de la terminalo.

En Emacs, ĉiu transskribaĵo de dialogo de la asistanto estas konservata en `~/.local/state/vikix/agent-shell/`, unu dosiero por ĉiu dialogo, nomita laŭ la projekto, en dosierujo, kiun nur vi povas legi; ne en la projekto, kie agent-shell metas ĝin. Ekranbildoj kaj bildoj, kiujn vi donas al la asistanto, iras en la `.agent-shell/` de la projekto, kiun agent-shell forigas de git.

`C-c a` revenas al la dialogo, kiun ĉi tiu projekto jam havas; en dosierujo sen ĝi, ĝi unue demandos (*Nova ŝelo* startigas unu tie), kaj `C-u C-c a` ĉiam startigas alian. En Neovim, la supra linio de dialogo diras, kiu respondas antaŭ ol vi tajpas.

Nenio startas aŭ konektiĝas ĝis vi premas klavon. Kiam io mankas (klavo, la loka modelo, la asistanto aŭ ĝia adaptilo), la klavo diras, kion tajpi, kaj nenion plu faras. [Laboro kun AI](ai.md) havas la reston: klavoj, lokaj modeloj, kaj elekto de asistanto.

## Via propra agordo

Por uzi vian propran agordon por ajn redaktilo, instalu Vikix kun `VIKIX_NVIM_REPO=` aŭ `VIKIX_EMACS_REPO=` agordita al via deponejo, aŭ metu la vian en la dosierujon: git-klono en `~/.config/nvim` aŭ `~/.emacs.d` estas alportata de ĝisdatigoj, kaj ajn alia dosierujo de vi restas sola.

En via propra agordo de Neovim, la kromprogramoj de Vikix ne estas tie. En via propra agordo de Emacs, la agordo de la AI ankoraŭ povas esti: ŝargu ĝin post via agordo de gptel.

```elisp
(load (expand-file-name "~/.local/share/vikix/emacs/vikix-ai") t t)
```

kaj ligi `vikix-ai-agent` kaj `vikix-ai-agent-terminal` al viaj klavoj. Sur maŝino sen Vikix, la dosiero ne ekzistas, kaj la linio nenion faros.

## Kiam redaktilo ne funkcias

- **La kromprogramoj de Neovim ne instaliĝis:** ilia eligo troviĝas en `~/.local/state/vikix/logs/nvim-plugins.log`. `:Lazy` montras ĉiun kromprogramon, kaj `:checkhealth` montras, kio mankas.
- **Emacs malfermiĝas kun eraroj:** provu `eq`. Se Emacs funkcias bone sen sia konfiguracio, la problemon kaŭzas la konfiguracio: la eraroj troviĝas en `*Messages*` (`C-h e`). Post korekto, `emacs-restart`.
- **Lingva servo ne komenciĝas:** kontrolu, ĉu ĝi ekzistas (`command -v gopls`); la lingva funkcio aldonas ĝin (`vikix add go`).
- **AI-ŝlosilo nenion faras krom elprinti mesaĝon:** faru tion, kion ĝi diras. `vikix doctor` kontrolas la reston, kaj [Kiam io rompiĝas](fixing.md) enhavas pli da informoj.
