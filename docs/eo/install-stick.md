# Instalo de Vikix per USB-memorilo

La USB-memorilo de Vikix instalis Void kaj Vikix kune: vi respondas kelkajn demandojn, ĝi forigas unu diskan, kaj dudek minutoj post la unua ensaluto vi estas ĉe la labortablo. Ĝi estas la plej facila maniero, kaj sur nova portebla komputilo ofte la sola, kiu funkcias: la propra bildo de Void estas de februaro 2025 (kernversio 6.12), kaj porteblaj komputiloj produktitaj post tio bezonas pli novan kernon kaj programaron por ilia Wi-Fi, sono kaj grafiko. La USB-memorilo enhavas la aktualajn versiojn de Void. [Instalado de Void por Vikix](install-void.md) estas la alia maniero, la instalilo de Void fare de la uzanto, poste Vikix.

**La tuta disko estas forigata, inkluzive de Windows.** La USB-memorilo ne instalis apud alia sistemo. Kopiu ĉiun aferon, kiun vi volas konservi, antaŭe.

Vi bezonas:

- 64-bita PC aŭ portebla komputilo (x86_64), kiu funkcias kun UEFI, kun 30 GB da diska spaco aŭ pli,
- USB-memorilo de 2 GB aŭ pli, kiu ankaŭ estos forigata,
- la reton: Wi-Fi aŭ kablo. La USB-memorilo instalis la aktualajn pakojn de Void, ne siajn proprajn.

## Kreo de la USB-memorilo

La bildo estas kreata de ĉi tiu deponejo per `installer/build-image.sh`, kun la propra ilo de Void por ĝiaj vivaj bildoj (void-mklive). Sur maŝino Vikix aŭ Void:

```sh
cd ~/vikix
sudo installer/build-image.sh
```

Ĉirkaŭ dek kvin minutoj kaj 4 GB da memoro la unua fojo; ĝi lasas la dosieron `vikix-VERSION-DATE-x86_64.iso` kaj ĝian kontrolsumon en la dosierujo, de kie vi lanĉis ĝin. La bildo estas ĉirkaŭ 1,3 GB, plejparte firmvaro.

Gravu ĝin sur la USB-memorstikon. Trovu la nomon de la memorstiko per la komando `lsblk` (ĉi tie `/dev/sdX`; se vi uzas la malĝustan nomon, ĝi forigos la malĝustan diskon), kaj poste:

```sh
sudo dd if=vikix-VERSION-DATE-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Sur Windows, Rufus transkribas ĝin (elektu la *reĝimon DD-bildo* kiam ĝi demandos).

## Antaŭ ol komenci kun ĝi

**Malŝaltu la sekuran启动** en la firmware-agordoj de la komputilo. La kerno de Void ne estas subskribita por ĝi, do kun ĝi ŝaltita, la stikaĵo povas starti, sed la instalita sistemo ne. La instalilo kontrolas kaj haltas kun ĉi tiu konsilo se ĝi estas ŝaltita.

- Sur portebla komputilo ASUS (inkluzive de ROG Flow Z13): tenu **F2** dum la starto por aliri la agordojn; la sekura启动 estas sub *Sekureco*. Konservu kaj eliru. **Esc** dum la starto estas la starta menuo, por elekti la stikaĵon.
- Sur ThinkPad: **F1** por la agordoj (*Sekureco* → *Sekura启动*), **F12** por la starta menuo.
- Aliloke, la klavoj estas ofte F2, Del, F10, F11 aŭ F12.

## La demandoj

Startu de la stikaĵo: ĝia unua ero en la menuo komencas ĝin. La unua ekrano reĝistriĝas mem kaj la instalilo komenciĝas. Sagoj movas, Enter elektas, Tab movas al la butonoj, kaj **Esc haltas** ĉiu punkto: nenio estas ŝanĝita ĝis la lasta demando.

1. **Reto**, nur se ankoraŭ ne ekzistas: elektu *Konekti al Wi-Fi*, poste vian reton kaj ĝian pasvorton. La konekto estas kopiata al la instalita sistemo, do ĝia unua starto ankaŭ estos enreta.
2. **Disko**: tiu, kiun vi volas formati. La stikaĵo mem ne estas proponita.
3. **Vi**: via nomo, mallonga reĝistriĝa nomo kaj via pasvorto (ankaŭ tiu, kiun `sudo` petas). `root` ne havas pasvorton; `sudo` estas la maniero eniri.
4. **Komputilo**: nomo por ĝi.
5. **Ĉifrado**: jes estas la defaŭlta kaj la konsilo por portebla komputilo. Pasfrazo estas petata ĉe ĉiu starto; via reĝistriĝa pasvorto povas esti ĝi. Vi ne rimarkos la koston: la procesoro ĉifras en la aparataro, preskaŭ tiel rapide kiel la disko povas legi.
6. **Tempozono** kaj **klaviataro** (por la tekstaj ekranoj; la aranĝaĵo de la labortablo estas en la bonveniga ekrano de Vikix).
7. **Kiom da Vikix**: nur la labortablo, aŭ kun la *nehaveblaĵoj* (Emacs, C, Python, Lisp), *programisto* (ambau redaktoroj, ĉiuj lingvoj) aŭ *ĉio* (ankaŭ LibreOffice kaj presado). Ĉio, kio estas forlasita, estas `vikix add` poste.
8. **Lasta ŝanco**: ĝi montras, kion ĝi faros. Tipe `erase` por daŭrigi.

Tiam ĝi laboras mem por kelkaj minutoj: la disko, Void, la starta ŝarĝilo, kopio de Vikix ĝisdatigita de GitHub. Fine, ĝi diras, kio venos poste, kaj ĝi reŝargas. Foriru la stikaĵon.

## La unua starto

1. Tipe la pasvorton de la disko, se vi elektis ĉifradon.
2. Reĝistriĝu kiel vi sur la unua ekrano.
3. La propra instalado de Vikix aŭtomate funkcias: ĝi petas vian pasvorton unufoje, poste ĝi elŝutas la labortablon kaj konstruas la fenestran administrilon, dudek minutoj aŭ pli.
4. La reŝarĝo komenciĝas, kaj la sekva reĝistriĝo estas la labortablo. [Via unua horo](first-hour.md) estas la sekva paĝo.

Se ĝi haltas, la mesaĝo nomas la fazon. Rulu `~/vikix/install.sh` denove (ĉiu fazo povas esti rulfita denove), aŭ eliru kaj reeniru sur la unua ekrano, kio re-komencas ĝin. [Kiam io rompiĝas](fixing.md#la-instalado-haltis) diras pli.

## Kion la stikaĵo vidis

Antaŭ la instalado, la stikaĵo povas diri al vi, kion ĝi opinias pri la maŝino: ŝanĝu al la dua ekrano (**Alt+F2**), reĝistriĝu kiel `anon` (pasvorto `voidlinux`), kaj rulu `vikix-hwreport | less`. Ĝi listigas la maŝinon, la kernon, ĉiun aparato kun ĝia stirilo, la reton, sonaj kartoj, ekranoj, tuŝo kaj plumo, la akumulatoron, kaj la firmware, kiun la kerno petis kaj ne trovis. La instalilo konservas la saman raporton en via hejmo, `~/vikix-hardware-DATUMO.txt`, por kiam io ne funkcios poste.

## Kiel la disko estas aranĝita

Du partoj, sur GPT-tabelo:

| Parto | Grandeco | Kio | Muntas ĉe |
|---|---|---|---|
| 1 | 1 GiB | EFI-sistemo, vfat: GRUB, la kerno kaj initramfs | `/boot` |
| 2 | la resto | LUKS2 (se ĉifrante), poste ext4 | `/` |

Nur la startaj dosieroj restas neĉifritaj, do GRUB komenciĝas sen sia propra pasfrazo, kaj la initramfs petas la diskon. La ĉifrado uzas la defaŭltojn de LUKS2 (AES-XTS, Argon2id por la pasfrazo), kun TRIM pasigita kaj la kromaj vicoj de dm-crypt estas malŝaltitaj, kio sur rapida NVMe-disko nur kaŭzas prokraston; ĉiuj tri estas konservitaj en la kapo de LUKS. La nova sistemo komenciĝas kun NetworkManager (la reto de Vikix) anstataŭ la dhcpcd de Void.

## Kiel ĝi estis testita

`installer/qemu-test.py` komencas la stikaĵon en QEMU sub UEFI, instalias sur malplenan virtualan diskon kun ĉifrado de dosiero de respondoj, poste komencas tiun diskon sole, tipas la pasvorton kaj kontrolas la rezulton: la kerno, LUKS2 kaj ĝiaj agordoj, `/boot`, la servoj, la reto, `~/vikix` kaj la unua-starta paŝo. `tests/installer.sh`, en la kutimaj testoj, kontrolas la paŝojn de la instalilo en "seka" rulado kaj la unua-startan paŝon kun anstataŭaĵoj. Neniu el ili ruligas la propran instalon de Vikix, kiun la aliaj testoj kovras.
