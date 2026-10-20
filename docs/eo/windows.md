# Fenestroj en fenestro

Kelkaj programoj funkcias nur sur Windows: programo de banko, programaro por kontoj, Windows Outlook. Vikix povas funkcigi Windows 11 en virtuala maŝino (VM): kompleta komputilo Windows ene de fenestro, kiu aperas kiel ajna alia fenestro. Ĝia interŝanĝa areo estas uzata kun via, ĝia ekrano ŝanĝas sian grandecon kun la fenestro, kaj unu el viaj dosieroj estas disko en Windows. Kiam Windows estas instalita, unu el ĝiaj programoj ankaŭ povas havi [proprian fenestron](#unu-programo-en-sia-propra-fenestro), sen la Windows-labortablo ĉirkaŭe.

Ĝi estas opcia, kaj ĝi okupas multe da loko, do nenio estas instalita ĝis vi petas tion.

## Kion vi bezonas

- **Porta komputilo kun 8 GB da memoro aŭ pli.** Windows ricevas 4 GB el tio sur komputilo kun 8 GB, 6 GB sur komputilo kun 16 GB, kaj duonon de la procezorkernoj.
- **40 GB da libera loko**, kie la disko de la VM estos instalita. La disko povas kreski ĝis 64 GB, dum Windows plenigas ĝin.
- **La Windows 11 ISO**, la instalilo kiel unu dosiero, senpage de Microsoft: [microsoft.com/software-download/windows11](https://www.microsoft.com/software-download/windows11). Elektu la diskan bildon (ISO) por x64-aparatoj, kaj vian lingvon.
- **Produkta ŝlosilo, se vi havas.** Sen ĝi, Windows 11 Pro instaliĝas kaj funkcias, kun remembrigilo pri aktivigo.
- **Ĉirkaŭ duona horo**, plejparte atendante.

Via porta komputilo ne devas plenumi la proprajn postulojn de Windows 11: la VM havas la TPM kaj Sekuran Ĝirkon, kiujn ĝi postulas, kaj la kontrolo pri pli nova procesoro estas preterlasita.

## Instalado de Windows

Kvar komandoj, en terminalo.

1. **Unufoje, la partoj kiujn ĝi bezonas** (ĉirkaŭ 250 MB da pakaĵoj, kaj la disko de Windows-stiriloj):

   ```sh
   vikix windows setup
   ```

   Ĝi petas vian pasvorton (sudo) unufoje, por la pakaĵoj kaj la reto de la virtuala maŝino. Por meti la diskan de la virtuala maŝino al alia loko, ekzemple al pli granda disko: `vikix windows setup --disk /path/to/folder`. (`vikix add windows` faras la saman instalon: Windows estas unu el la funkcioj.)

3. **Instalu Vindozon** el la ISO-bildo, kiun vi elŝutis:

   ```sh
   vikix windows create ~/Downloads/Win11_25H2_English_x64.iso
   ```

Uzu la veran nomon de via ISO-bildo (la klavo Tab kompletigas ĝin). Aldonu `--key XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` se vi havas produkta ŝlosilon. Ĝi petos pasvorton por via Vindoza konto, kiu havas la saman nomon kiel via Linuksa konto.

3. **Atendu.** Vindozo instaliĝas: la stiriloj, la disko, via konto (loka konto, Microsoft-konto ne necesas), poste la iloj, kiuj dividas la interŝanĝan areon kaj vian dosierujon. Notifo diras *Vindozo estas preta*, ĉirkaŭ 25 minutoj poste. Por observi, dumtempe, lanĉu `vikix windows`.

4. **Malfermu ĝin:**

   ```sh
   vikix windows
   ```

Aŭ **Super+m** → *Windows (la VM)*. Eniru kun la pasvorto de la 2-a paŝo.

## Ĉiutaga uzo

- **Malfermi ĝin.** `vikix windows` (aŭ *Windows* en Super+m) startigas Windows se ĝi estas malŝaltita kaj malfermas ĝian labortablon. Fermu la fenestron, kaj Windows daŭre funkcios; malfermu ĝin denove laŭ la sama maniero.
- **La indikaĵo** montras **win** dum Windows funkcias, ĉar ĝi uzas memoron kaj baterion.
- **Viaj dosieroj.** `~/Windows` en ĉi tiu portebla komputilo estas la disko **Z:** en Windows. Metu dosierojn tien por uzi ilin en ambaŭ sistemoj. `vikix backup` kovras tiun dosierujon.
- **Kopii kaj glui** funkcias en ambaŭ direktoj.
- **La fenestro** aranĝiĝas kiel ajna alia: dividu la ekranon, movu ĝin, faru ĝin plenskrana per Super+f. Windows ŝanĝas sian ekranan grandon por adaptiĝi.
- **Malŝalti ĝin.** Malŝaltu Windows de sia propra starta menuo, aŭ uzu `vikix windows stop`. Reŝargu kaj malŝaltu en Super+Shift+Escape unue ĝuste malŝaltas Windows. Eliri lasas ĝin funkcii.
- **Ĉu ĝi funkcias?** `vikix windows status` diras, ĉu ĝi estas instalita kaj funkcias, kaj kie estas ĝiaj partoj.
- **Kun la aliaj VM-oj.** **Super+m** → *Aplikoj* → *Virtualaj maŝinoj* (`vikix vm`) listigas ĉiun VM-on, kiun libvirt havas, la vian kaj la sisteman, kun ĝia stato, memoro kaj CPU-oj. Elekti unu ofertas la jenajn opciojn: malfermi ĝian ekranon, startigi, paŭzi (ĝi konservas sian memoron kaj ne uzas procesoron), konservi (ĝia memoro estas stokita en la diskon kaj ĝi malŝaltas; la sekva startigo daŭrigas de tie, kie ĝi estis), malŝalti aŭ tute malŝalti. De la komandlinio: `vikix vm pause windows`, `vikix vm save windows`, `vikix vm start windows`.

## Unu programo, en sia propra fenestro

La tuta labortablo de Windows estas la loko por agordi Windows kaj instali ĝiajn programojn. Por uzi unu el ili ĉiutage, Vikix povas montri tiun programon sole: ĝiaj fenestroj troviĝas inter viaj fenestroj kaj aranĝiĝas kiel ajnaj aliaj, sen labortablo de Windows ĉirkaŭ ili.

```sh
vikix windows apps setup        # once: asks for your Windows password
vikix windows apps              # what Windows has, from its Start menu
vikix windows app excel         # open one ...
vikix windows app excel ~/Documents/report.xlsx   # ... on a file
vikix windows apps add excel    # put it in the launcher (Super+d)
```

- **Agordu, unufoje.** Ĝi dufoje petas la pasvorton de via konto de Windows (tiu, kiun vi elektis ĉe `vikix windows create`) kaj konservas ĝin, por ke la programoj povu memstare ensaluti. Ĝi lanĉas Windows se ĝi estas malŝaltita, kaj instalas FreeRDP, la programon, kiu desegnas la fenestrojn, se vi ankoraŭ ne havas ĝin.
- **Kion Windows havas.** `vikix windows apps` elmontras linion por ĉiu programo en la menuo Start de Windows: mallonga nomo, ĝia plena nomo kaj kie ĝi troviĝas en Windows. La mallonga nomo estas tio, kion la aliaj komandoj uzas; la komenco de ĝi sufiĉas, kiam nur unu programo komenciĝas. Rulu ĝin denove post instalo de programo en Windows.
- **Malfermante unu.** Se Windows estas malŝaltita, ĝi unue estas lanĉita, kaj notifo diras, ke la programo malfermiĝos dum minuto aŭ du.
- **La lanĉilo.** Programo, kiun vi aldonis, troviĝas ĉe `Super+d` sub sia propra nomo, kiel ĉiu alia. `vikix windows apps remove excel` forigas ĝin denove. Vikix konservas la liston de tio, kion vi aldonis (`~/.local/state/vikix/windows-launcher.json`), do eniro, kiu mankas, forigita per erara komando aŭ la instalilo de programo, estas reskribita ĉe la sekva `vikix update`, aŭ tuj per `vikix windows apps restore`.

Kelkaj aferoj, kiujn vi devas scii:

- **Viaj dosieroj.** Windows vidas du el viaj dosierujoj: `~/Windows` kiel disko **Z:**, kaj ekde la agordo, `~/Documents` kiel disko **Y:**. La nova disko aperas post la sekva lanĉo de Windows: `vikix windows stop`, poste malfermu programon denove. Dosiero en ĉiu el tiuj dosierujoj malfermiĝas surloke; iu ajn aliloke estas malakceptita kun mesaĝo, kiu tion diras, ĉar Windows ne povas vidi ĝin.
- **Via pasvorto** estas konservata en `~/.config/vikix/secrets/windows-password`, kiun nur vi povas legi, kaj kiun la historio de viaj dosieroj neniam registras. `vikix windows apps forget` forigas ĝin; la agordo tiam petas ĝin denove.
- **Nenio nova estas malfermita al la reto.** La agordo ŝaltas Foran Desktopon en Windows, per kiu la fenestroj de programo estas sendataj. Windows estas sur sia privata reto (vidu [Kion ĝi povas atingi](#kion-ĝi-povas-atingi)), do nur ĉi tiu laptopo povas konektiĝi al ĝi.
- **Ĝi restas sub la baro.** Maksimigita programo de Windows haltas ĉe la baro, do ĝia propra titolo-baro kaj butono por fermi ne estas kaŝitaj sub ĝi. Kaŝu la baron (`Super+Ctrl+h`), kaj la programo okupos la tutan ekranon la sekvan fojon, kiam ĝi malfermiĝos.
- **Regulo povas lokigi ĝin.** La fenestroj de ĉiu programo havas sian propran klason, `vikix-win-` kaj la mallongan nomon, do `(when-window (:class "vikix-win-excel") (workspace 4))` en via `rules.lisp` sendas Excel-on al labra spaco 4 ([Reguloj por la labra tabulo](rules.md)).
- **La plena labra tabulo kaj programo alterne uzas ĝin.** Windows 11 Pro permesas nur unu sesionon je la sama tempo. Programo malfermita tiel prenas ĝin de la plena labra tabulo (`vikix windows`), kiu montras la ŝirmbildon de Windows ĝis kiam vi revenos al ĝi.

Por la kuriozuloj: ĉi tio estas la RemoteApp de RDP, kiu sendas la fenestrojn de unu programo, kie Fora Desktopo sendus la tutan ekranon. FreeRDP (`xfreerdp3`) desegnas ĉiun kiel ordinaran fenestron de X, kaj StumpWM ordigas ĝin. `lib/windows-apps.py` faras la laboron. Ĉio, kion ĝi ŝanĝas ene de Windows, pasas tra la gastagenta programo de la VM, kiun la instalado metis tie, do neniu retservo de Windows estas fidinda kun ĝi. La pasvorto atingas FreeRDP ĉe ĝia eniro kun la aliaj argumentoj (`/args-from:stdin`), neniam sur komanda linio aŭ en la medio, kie aliaj programoj povus legi ĝin. Kaj la baro: `vikix-publish-workarea` en `modeline.lisp` skribas la ekranon, sen la baro, sur la radika fenestro (`_NET_WORKAREA`, kiel aliaj labraj tabuloj faras), kaj FreeRDP pasigas ĝin al Windows (`/workarea`).

## Kion ĝi povas atingi

Windows atingas la interreton kaj vian hejman aŭ oficejan reton. Ĝi vidas ĉi tiun laptopon nur kiel alian komputilon sur privata reto, ĉe 192.168.122.1. Tio, kion ĉi tiu laptopo tenas por si mem, restas neatengebla: la Lisp-konekto de la fenestra administrilo, la agordoj de la presiloj, loka AI-modelo. Do, malbona elŝuto en Windows ne povas preni la regon de via labra tabulo.

Ne estas kio agordi por ĝi: `vikix windows setup` faras ĝin. Por atingi programon sur ĉi tiu laptopo de Windows intence, rulu tiun programon ĉe 192.168.122.1, ne ĉe 127.0.0.1.

## Ŝanĝante ĝin

Pli da memoro, pli da procesoroj, aŭ USB-aparato donita al Windows: malfermu la administrilon de la VM per

```sh
virt-manager -c qemu:///session
```

kaj malfermu la detalojn de la *Windows* virtuala maŝino. Ŝanĝu la memoron kaj la procesorojn dum Windows estas malŝaltita. USB-aparato estas aldonata laŭ la sama maniero (*Aldoni Aparaton* → *USB-Gastaparato*).

## Forigi ĝin

```sh
vikix windows remove
```

Ĝi unue demandas, poste forigas la VM kaj ĝian diskan, kaj kun ili la pasvorton, kiun ĝi konservas por programoj de Windows, iliajn lanĉilajn enirojn kaj la liston de ili, se vi agordis ilin (`vikix windows apps forget --all` faras tiun parton sole). `~/Windows`, kun viaj dosieroj en ĝi, restas.

## Kiam io malfunkcias

| Kio okazas | Kion fari |
|---|---|
| `create` diras, ke ĝi bezonas 8 GB da memoro | La laptopo havas malpli; Windows 11 ne funkcios bone en VM sur ĝi |
| La instalado ŝajnas haltita | `vikix windows` montras ĝian ekranon. La protokolo de la instalado estas `~/.local/state/vikix/windows-install.log` |
| Post unu horo, ne aperas *Windows pretas* | Malfermu ĝin per `vikix windows` kaj kontrolu: Windows eble atendas respondon al demando |
| La fenestro de Windows ne malfermiĝas | `vikix windows status` diras, kio mankas |
| Notifo diras, ke la VM estas sur sia malnova reto | Restartigu Windows (Start → Restart); `vikix windows status` poste diras, ke ĝi estas sur la privata reto |
| Windows funkcias malrapide | Donu al ĝi pli da memoro aŭ procesoroj (vidu [Ŝanĝante ĝin](#ŝanĝante-ĝin)), kaj fermu tion, kion vi ne bezonas, ĉe ambaŭ flankoj |
| Windows ne ĉesas funkcii | `vikix windows stop --force` malŝaltas ĝin, kiel se oni tiras la ŝtopilon |
| Notifo diras, ke programo de Windows *ne malfermiĝis* | Ĝi montras la lastajn liniojn de FreeRDP; la resto estas en `~/.local/state/vikix/logs/windows-app.log`. Se vi ŝanĝis vian pasvorton de Windows: `vikix windows apps forget`, poste `vikix windows apps setup` |
| `vikix windows app` diras, ke Fora Buruo ne respondas | Rulu `vikix windows apps setup` denove: ĝi reaktivas ĝin |
| Programo de Windows atendas pri fenestro, kiu neniam aperas (fermante FACTS, ĝia gvidilo pri aktivigo) | La fenestro estas desegnita tiel, ke RemoteApp ne povas transdoni ĝin (tavolvinda fenestro kun sia propra travidebleco). Kontrolu en la propraj agordoj de la programo pri senĉefa temo: la menuo Pri Temoj de FACTS agordita al unu desegnas ĝiajn fenestrojn kiel ordinarajn fenestrojn, kaj tio sufiĉas |
| `vikix windows app` diras, ke Windows ne havas tian programon | `vikix windows apps` relege la menun Start, por programo instalita poste |
| La tuta ekrano iĝas nebela dum programo de Windows estas malfermita | Via `~/.config/picom/picom.conf` estas de antaŭ Vikix 0.71.183: aldonu la linion `"class_g ^= 'vikix-win-'"` al ĝia listo `blur-background-exclude` |

La [README](../../README.md#windows-in-a-vm) enhavas, kiel ĝi funkcias interne.
