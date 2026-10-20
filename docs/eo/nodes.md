# Viaj aliaj komputiloj, kiel nodoj

**Nodo** estas alia via komputilo, kiun ĉi tiu Vikix konas laŭ nomo: malmultekosta VPS, kiu ĉiam estas ŝaltita, komputilo hejme, komputilo por kompilado. La ideo (la desegno estas `plans/DESIGN-cloud.md`) estas, ke via komputilo ne finiĝas ĉe via portebla komputilo: la nodo estas parto de la ununura sistemo, ne servilo, al kiu vi ensendas. Ĉi tiu unua paŝo estas la parto, kiu pruvas tion: la nodo estas nomita, vidita kaj atingita. Sendante projekton tien kaj alportante ĝin reen, taskoj, kiuj daŭras dum la portebla komputilo estas fermita, kaj `--on NAME` por la aliaj komandoj venos poste.

Nodo estas **Void Linux** komputilo (runit, xbps), kutime sen ekrano, atingita per **nur SSH**, kiel vi, per ŝlosilo. Nenio el Vikix estas instalita sur ĝi, kaj `ssh atlas` estas la sama komputilo: ĉion, kion Vikix faras ĉi tie, vi povas fari per ssh mane.

## Aldonante unu

```sh
vikix node add atlas vid@atlas.example.com
vikix node add forge forge-build --port 2222 --kind build
```

La nomo konsistas el minusklaj literoj, ciferoj kaj strekoj. La gastigilo estas tio, kion vi donus al `ssh`: `user@host`, aŭ nomo el via `~/.ssh/config`. Vikix atingas la maŝinon unufoje, tiam, uzante la proprajn mesaĝojn de `ssh`, do la **ŝlosila identigaĵo estas via, kaj vi devas konfirmi ĝin**: rigardu la identigan valoron, kiel vi farus por ajna nova maŝino. De tiam la ŝlosilo estas konata, kaj ŝanĝita ŝlosilo estos malakceptata. Se `ssh` petas pasvorton ĉi tie, ankoraŭ ne ekzistas via ŝlosilo sur la maŝino: `add` diras tion ĉe la fino, kaj `ssh-copy-id vid@atlas.example.com` metas unu tien. Vikix neniam konservas aŭ petas pasvorton post tio: ĉiu posta konekto uzas nur ŝlosilojn, sen ajna mesaĝo.

Maŝino, kiu ne estas Void, estas konservata, kun averto: tio, kio venos poste (la servoj, la taskoj), estas kreita por runit kaj xbps.

La nodo estas via dosiero, `~/.config/vikix/nodes/atlas`:

```
host=vid@atlas.example.com
port=22
kind=cloud
added=2026-10-12
```

Redaktu ĝin, aŭ `vikix node remove atlas` forgesas ĝin (la dosieron kaj la lastan
respondon); la maŝino mem neniam estas tuŝata. Aldonoj kaj forigoj estas notitaj en
`~/.local/state/vikix/nodes/log`.

## Vidi ilin

```
$ vikix nodes
NAME   KIND   STATUS   SYSTEM           WHAT RUNS
x1     local  online   Void / StumpWM   up 3d 4h, load 0.42, vikix 0.72.62
atlas  cloud  online   Void / headless  up 41d 2h, load 0.03
forge  build  offline  Void / headless  up 2d 1h, load 1.20
```

Ĉi tiu maŝino estas la plej grava. Ĉiu nodo estas demandata samtempe, kun kelkaj sekundoj por respondi (`VIKIX_NODE_TIMEOUT`, 8 laŭ defaŭlto); se nodo ne respondas, ĝi estas *sen konekto*, kaj la lasta respondo restas en sia linio. `vikix nodes --last` montras la lastajn respondojn sen demandi iu ajn, kaj indikas kiom da tempo pasis ekde ĉiu respondo. La respondoj estas stokitaj en `~/.local/state/vikix/nodes/NOMO`.

`vikix node status atlas` estas la kompleta respondo: la sistemo kaj ĝia iniciatigo, la kerno, la aktiva tempo kaj la ŝarĝo, la memoro kaj la disko, Vikix en `~/vikix` (se ekzistas), la aktivigitaj runit-servoj, kaj la programoj, kiuj funkcias kiel vi. Kion oni demandas al nodo estas mallonga POSIX-skripto, kiu legas `/proc`, `/etc` kaj `df`; ĝi ne bezonas ajnan instalon.

## Ŝelo, komando

```sh
vikix node shell atlas
vikix node run atlas uname -a
vikix node run atlas 'cd ~/src/vikix && tests/run.sh --quick'
```

`shell` estas `ssh -t` en ĉi tiu terminalo. `run` faras, ke la komandoj estas ekzekutataj tie kiel per `ssh`: ĝi citas la ŝelon de la nodo, kiel vi farus por `ssh`. Via enigo pasas (per kanalo, kiu funkcias), kaj la elira stato de la komando estas redonata kiel la propra de `vikix node run`; nodo, al kiu ne eblas aliri, estas mesaĝo kaj 1.

## Kion ĝi ne faras

- **Neniu sinkronigo.** Nenio el via hejma dosierujo estos sendita al nodo, krom se vi sendas ĝin. Projekto estas sendita per `git`, la resto per `rsync` aŭ `scp`, nune mane; komando por tio estos la sekva paŝo en la dezajno.
- **Neniu agento, neniu servo, neniu tasko** sur nodo ankoraŭ. `vikix node run` estas la sola afero, kiu io ajn faras tie.
- **Neniu reto.** Al nodo oni aliras per la adreso, kiun vi donis al ĝi; Tailscale (TODO 16) aperos poste kaj ne estos bezonata.
- **Agento neniam aldonas nodon.** `add` estas intence interaga, do la gastiga ŝlosilo estas konfirmita de vi; la paĝo de la agento diras tion.
