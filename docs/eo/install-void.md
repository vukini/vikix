# Instali Void por Vikix

Vikix funkcias sur ordinara Void Linux, do la unua paŝo estas instali Void. Ĉi tiu paĝo montras la instalilon paŝo post paŝo, kun la respondoj, kiujn Vikix bezonas; la bildoj estas de reala instalado, farita por ĉi tiu paĝo. Ĝi daŭras ĉirkaŭ duonhoro, plejparte atendante.

Ekzistas pli rapida maniero: [Vikix-a disko](install-stick.md) instalas Void kaj Vikix kune post kelkaj demandoj, kun pli nova kerno ol la propra bildo de Void, kion eble bezonas portebla komputilo produktita post 2025.

**La instalado forigas la diskon, kiun vi elektas.** Kopiu ĉion, kion vi volas konservi, antaŭe.

Vi bezonas:

- 64-bita komputilo aŭ portebla komputilo (x86_64), kun 30 GB da disko aŭ pli,
- USB-disko de 2 GB aŭ pli, kiu ankaŭ estos forigita,
- la reto: kablo estas la plej facila; Wi-Fi ankaŭ funkcias.

## La Void-bildo sur USB-disko

Elŝutu la vivan bildon de [voidlinux.org/download](https://voidlinux.org/download/): **x86_64, glibc, base**, dosiero nomata kiel `void-live-x86_64-20250202-base.iso`. Vikix bezonas la **glibc** version, ne musl. La baza versio sufiĉas, ĉar Vikix alportas la grafikan interfacon; la xfce-bildo ankaŭ funkcias, sed alportas grafikan interfacon, kiun vi ne uzos.

De la sama paĝo, prenu `sha256sum.txt` kaj kontrolu la bildon, por ke vi sciu, ke ĝi alvenis tute:

```sh
sha256sum -c --ignore-missing sha256sum.txt
```

Skribu ĝin al la USB-memorilo. En Linux, trovu la nomon de la USB-memorilo per la komando `lsblk` (ĉi tie `/dev/sdX`; la malĝusta nomo detruigos la malĝustan diskelon), poste:

```sh
sudo dd if=void-live-x86_64-20250202-base.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

En Windows, Rufus skribas ĝin (elektu *reĝimon DD* kiam ĝi petas); en Mac, balenaEtcher.

## Komencu per la stiketo

Enŝovu la stiketon kaj startigu la komputilon per ĝia ŝarga menuo-klavo, ofte F12, F11, F9 aŭ Esc (ThinkPad: F12), kaj elektu la stiketon. Se ĝi rifuzas starti, malŝaltu **Secure Boot** en la agordoj de la ĉefprogramo: la bildo de Void ne estas subskribita por ĝi.

La unua ero startigas la vivan sistemon:

![Ŝarga menuo de Void, la unua elektita ero](shots/void-boot-menu.png)

## Startigu la instalilon

La viva sistemo diras al vi, kiel eniri. Eniru kiel `root`, pasvorto `voidlinux`, kaj startigu la instalilon:

```sh
void-installer
```

![La ekranmueno de ensalĝo de la aktiva sistemo, kiu montras la uzantojn kaj la instalilon](shots/void-live-login.png)

Post bonvenigo, ĝia menuo listigas ĉiun paŝon laŭvice. Iru tra ĝi de la supro; post ĉiu paŝo, ĝi mem pasas al la sekva. Sagoj moviĝas, Enter elektas, Tab ŝanĝas inter la listo kaj la butonoj, Spacbaro markas kupron, kaj tajpi leteron saltas al la eniroj, kiuj komenciĝas per ĝi.

![La menuo de la instalilo, de Klavaro ĝis Instali](shots/void-installer-menu.png)

## La menuo, paŝo post paŝo

### Klavaro

La klaviatara aranĝo de via klaviatura, por la tekstaj ekranaj: `us` por la plej multaj anglaj klaviaroj, `uk`, `de`, `fr` kaj simile. (La aranĝo de la komputila medio estas aparte agordita, en la bonveniga ekrano de Vikix.)

![La listo de klaviataroj, `us` elektita](shots/void-keyboard.png)

### Reto

Elektu la retaparaton. Kablo estas `eth0` aŭ nomo kiel `enp0s31f6`: respondu **Jes** al DHCP. Wi-Fi estas `wlan0` aŭ `wlp…`: la instalilo petas la nomon kaj pasvorton de la reto, kaj poste la saman demandon pri DHCP. Ĝi diras *La reto funkcias bone!* kiam ĝi funkcias.

### Fonto

**Reto**: la aktualaj pakaĵoj, rekte de Void. *Lokala* instas la pakaĵojn, kiuj estas sur la disko, kiuj povas esti monatojn malnovaj; ĝi ankaŭ funkcias, kaj la instalado de Vikix denove ĝisdatigas ilin, sed Reto forigas tiun paŝon.

![Lokala aŭ Reto, Reto elektita](shots/void-source.png)

### Spegulo

Elektu **Defaŭlta** kaj konfirmu. La instalado de Vikix mem trovas la spegulojn de Void kaj uzas la plej rapidan, do ne estas bezono elekti unu ĉi tie.

![La regionoj de la speguloj, Defaŭlta elektita](shots/void-mirror.png)

### Komputilnomo, Lingvo, Horzono

La nomo de la komputilo (`mylaptop`, io mallonga), la lingvo kaj formatoj (`en_US.UTF-8`; la listo estas ordigita laŭ la nomo de la lingvo, do la angla estas sub E), kaj via regiono kaj urbo.

![La listo de lingvoj, `en_US.UTF-8` elektita](shots/void-locale.png)

### Radpasvorto

Pasvorto por `root`, dufoje. Vi malofte uzos ĝin: ĉiutage, via propra pasvorto kaj `sudo` faras la laboron.

### Uzantkonto

Via ensalĝa nomo (mallonga, minuskla: `alex`), la nomo montrata por ĝi (`Alex`), kaj via pasvorto, dufoje. Poste la grupoj: **tenu `wheel` markita**. Ĝi jam estas markita, kun `audio`, `video` kaj kelkaj pliaj; `wheel` estas tiu, kiu permesas al vi uzi `sudo`, kaj la instalado de Vikix bezonas ĝin. Vikix aldonas la aliajn grupojn, kiujn ĝi bezonas mem.

![La grupoj por la nova uzanto, `wheel` markita](shots/void-user-groups.png)

### Ŝarga Iniciigilo

La disko, sur kiu Void estos instalita, kaj poste **Jes** al grafika terminalo por la ŝarga menuo. Sur laptopo, la disko estas `/dev/nvme0n1` aŭ `/dev/sda`; en ĉi tiuj bildoj, ĝi estas VM, `/dev/vda`.

![La disko por la ŝarga iniciigilo](shots/void-bootloader.png)

### Particio

Elektu la saman diskon, poste **cfdisk**. La instalilo klarigas, kion ĝi bezonas: sur komputilo kun UEFI, kiu estas preskaŭ ĉiu el la lastaj dek jaroj, du particioj sur **gpt** tabelo. Se cfdisk petas la tipon de etikedo, la disko estas malplena: elektu **gpt**.

![cfdisk petas la tipon de etikedo, gpt elektita](shots/void-cfdisk-label.png)

1. Forigu la particiojn, kiuj estas tie, se ekzistas (*Forigu* ĉe ĉiu): ĉi tio estas la forigo.
2. **Nova**, grandeco `512M`, poste **Tipo**: *EFI-sistemo* (la unua en la listo).
3. Ĝis la libera spaco, **Nova**, kaj prenu la grandecon, kiun ĝi ofertas: la resto de la disko, tipo *Linuksa dosarsistemo*.
4. **Skribu**, tajpu `jes`, poste **Eliru**.

![La du particioj: 512M EFI-sistemo, kaj la resto Linuksa dosarsistemo](shots/void-cfdisk-table.png)

Malnova komputilo sen UEFI (ĝi ne havas EFI-agordojn, nur "BIOS"): elektu *dos*, anstataŭe, faru unu particion de tipo *Linukso*, kaj marku ĝin ŝargebla. La [manlibro de Void](https://docs.voidlinux.org/installation/live-images/partitions.html) havas la detalojn.

### Dosarsistemoj

Ĉiu particio ricevas formaton kaj lokon:

- la 512M-a: **vfat**, monta punkto `/boot/efi`, kaj Jes al nova dosarsistemo;
- la granda: **ext4**, monta punkto `/`, kaj Jes.

ext4 estas la sekura elekto kaj tio, sur kio Vikix estas testita. Poste **Fara**.

![La tipoj de dosarsistemoj, ext4 elektita](shots/void-fs-type.png)

![Ambaŭ particioj agorditaj: vfat kaj ext4](shots/void-filesystems.png)

### Instali

La instalilo montras, kion ĝi faros. **Ĉi tio estas la momento, kiam la disko estos forigita**; la antaŭaj paŝoj nur notis viajn respondojn. Kontrolu, ke ĝi estas la disko, kiun vi celas, kaj poste **Jes**.

![La resumilo antaŭ la instalado, kun la averto, ke la datumoj estos detruitaj](shots/void-install-confirm.png)

Ĝi elŝutas kaj instas la bazan sistemon: kelkajn minutojn. Poste ĝi petas, kiujn servojn komenci ĉe la ŝarga procezo. **Lasu ĝin kiel estas**: `dhcpcd`, kiu estas markita, donas al la nova sistemo la reton ĉe la unua starto, kion la instalado de Vikix bezonas. (Vikix transdonas la reton al NetworkManager poste, kaj mem forŝaltas `dhcpcd`.)

![La servoj, kiuj estos aktivigitaj, dhcpcd markita](shots/void-services.png)

Laste: *Void Linux estis sukcese instalita!* Respondu **Jes** por rekomenci, kaj forigu la diskon, kiam la ekrano malheliĝas. (Ne antaŭe: la instalilo funkcias de la disko ĝis tiam.)

![Void Linux estis sukcese instalita](shots/void-installed.png)

## La unua starto, poste Vikix

La nova Void startas sur sia propra disko kaj petas, ke vi ensalĝu. Ensalĝu kiel **vi mem**, ne kiel rad.

![La nova ensalĝa ekrano de la sistemo](shots/void-first-boot.png)

Freta Void ne havas nek `curl` nek `git`, sed ĝi havas `xbps-fetch`, kiu elŝutas dosieron. Elŝutu la instalilon de Vikix, legu ĝin, se vi volas (ĝi estas mallonga), kaj ruligu ĝin:

```sh
xbps-fetch -o vikix-install https://vikix.dev/install
less vikix-install          # q leaves
bash vikix-install
```

Ĝi petas vian pasvorton unufoje, instaldas Git, metas Vikix en `~/vikix`, kaj komencas la instalon. De tie ĝi funkcias memstare dum dudek minutoj aŭ pli: ĝi elŝutas la grafikan interfacon kaj konstruas la fenestran administrilon.

![La komenco de la instalado de Vikix, petante la pasvordon](shots/vikix-install-start.png)

Kiam ĝi diras, ke ĝi finis kaj montras, kion fari poste, rekomencu:

![La fino de la instalado de Vikix: Vikix estas instalita, kaj kio sekvos](shots/vikix-installed.png)

```sh
sudo reboot
```

Reenigu al la unua ekrano, kaj la labortablo estos lanĉita. [Via unua horo](first-hour.md) estas la sekva paĝo.

Se la instalado haltas pro eraro, la mesaĝo indikas la etapojn, kie okazis la problemo; [Kiam io funkciigas](fixing.md#la-instalado-haltis) diras, kion fari.
