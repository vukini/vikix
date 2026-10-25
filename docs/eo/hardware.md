# Vikix sur realaj maŝinoj

Kion faras portebla komputilo sur la kerno de Void, laŭ Vikix: kiuj partoj funkcias kiel instalitaj, kion oni devas agordi post la unua ensaluto, kaj kio ankoraŭ estas solvitenda.
Unu sekcio por ĉiu maŝino. Ĉiu komenciĝas de la **raporto pri la aparataro** de la maŝino,
kiun la instalilo de la USB-stango konservas en via hejmdosierujo kiel `~/vikix-hardware-DATO.txt`
kaj kiun `vikix-hwreport` elprintas sur ajna instalita maŝino (ĝi estas en
`~/.local/bin` ekde 0.72.100; `sudo vikix-hwreport` montras la mesaĝojn de la kerno sur maŝino, kie `dmesg` estas por la supera uzanto).

## Legado de raporto

La raporto havas sekcion por la maŝino (modelo, BIOS, kerno, memoro,
Secura Ekfunkciigo), la PCI-aparatoj kun la ŝoforo, kiun ĉiu ricevis, la USB-aparatoj,
la reto, la sonkartoj, la ekranoj, la enaj aparatoj (tuŝo, stilo,
klavaro, tuŝplato), energio (akumulatoro, dormaj statoj, la platforma profilo)
kaj, lasta, **la programilo, kiun la kerno petis kaj ne trovis, kaj aliaj
problemoj**. Legu tiun lastan sekcion unue: aparato kun ŝoforo sed
sen programilo estas la kutima kialo, ke mankas Wi-Fi aŭ sono, kaj la linio
nomas la dosieron. `regulatory.db failed` tie signifas, ke la Wi-Fi-radio
estas en la zorgegaj mondaj agordoj kaj eble forlasas iujn 5 kaj 6 GHz
kanaloĉojn: la paketo `wireless-regdb` enhavas la dosieron, kaj ĝi estas en la baza instalado de Vikix ekde 0.72.100 (`vikix update` aldonas ĝin al maŝino instalita antaŭe).

## ASUS ROG Flow Z13 (2025), GZ302EA

Instalita de la USB-stango de Vikix (0.72.97) la 2026-10-18: kerno 6.18.57,
linux-firmware 20260810, BIOS 311 de aŭgusto 2025, Secura Ekfunkciigo malŝaltita. Tablo kun forigebla klavaro: AMD Ryzen AI Max+ 395, 128 GB da memoro
kunhavita de la procesoro kaj la grafika karto, 13,4-cola 2560×1600 tuŝekrano.

| Parto | Sur 6.18 de Void |
|---|---|
| Procesoro kaj memoro | Funkcias; 121 GiB vidata de la kerno |
| Grafika karto (Radeon 8060S, `amdgpu`) | Funkcias: 2560×1600 je 180 Hz, 40 komputaj unuoj, videodekodado. La programilo rezervas 4 GB kiel grafika memoro kaj la resto (62 GB) estas kunhavata laŭ bezono, la duono de la kerno; `vikix ai share most` permesas al la ĉipo preni ĉion krom 16 GB de la sekva ekfunkciigo |
| Wi-Fi 7 (MediaTek MT7925, `mt7925e`) | Funkcias, programilo de junio 2026. Bezonas `wireless-regdb` por ĉiu kanalo (vidu supre) |
| Bluetooth (MediaTek, `btusb`) | Vidata kun sia ŝoforo; ankoraŭ ne provita |
| Laŭtparoliloj (du Cirrus CS35L41-amplifiloj) | Funkcias: ambaŭ amplifiloj ŝargas sian programilon (`cs35l41-hda`, gajno 15). Pli malfortaj ol sub Windows, kiel raportas aliaj posedantoj; aŭdikoj funkcias |
| Kamera (ASUS 5M, `uvcvideo`) | Vidata kun sia ŝoforo; ankoraŭ ne provita |
| Tuŝekrano kaj stilo (ELAN 9008) | Tuŝo funkcias en X; la stilo estas vidata. Turnado de la ekrano: ankoraŭ ne (TODO 59) |
| Klavaro kaj tuŝplato (forigeblaj) | Funkcias, kun tuŝo por klaki kaj natura ruliĝo de la bazo. F6 montras bildon de "transprenilo" sed sendas simplan F6 en Linux; Vikix faras ĝin Print (la ŝlosila dosiero de udev, `55-hardware`, de 0.72.102), do F6 faras ekranfotografon, Shift+F6 konservas ĝin kiel dosieron, Ctrl+F6 la fenestron, Super+F6 la ekranon |
| Suspensigo | Moderna atenta reĝimo (`s2idle`) nur. Premitaj ŝlosoj dum dormo ne vekis ĝin (provita 2026-10-19), do ne bezonas suspendigan kaptopunton en ĉi tiu kerno |
| Akumulatoro kaj ŝargado | Vidata (BAT0, du USB-C-fontoj) |
| Ventililo kaj energiaj reĝimoj | La kerno ofertas `quiet`, `balanced` kaj `performance` en `/sys/firmware/acpi/platform_profile`; Void ne havas asusctl. Elekto de Super+m estas TODO 63 |
| USB4 | Funkcias: Corsair EX400U SSD (20 Gb/s) estas aŭtorizita kiam ĝi alvenas kaj muntiĝas kiel memorbastono, per la Thunderbolt-regulo de udev (`55-hardware`, vidu "USB drives" en la README). Antaŭ la regulo la disko tute ne aperis: USB4-SSD ne estas USB-memoro, kaj la kerno lasas novan Thunderbolt-aparaton atendi permeson |
| SD-legilo | Ŝoforo ligita; ankoraŭ ne provita |
| NPU (AMD XDNA) | Neniu ŝoforo ligita en 6.18; nenio en Vikix uzas ĝin |
| Fingruĵdetektilo | Neniu en ĉi tiu modelo |

Senprezaj linioj en la lasta sekcio de la raporto: kvar `ACPI Error: AE_ALREADY_EXISTS`
dum la ekfunkciigo kaj `BIOS _OSI(Linux) query ignored` (de la programilo), `asus_wmi:
fan_curve_get_factory_default ... failed: -19` (ne havas la fabrikajn agordojn de la ventililo por legi), kaj `GPT: Use GNU Parted to correct GPT errors` dum la USB-stango ankoraŭ estas konektita.

### Post la instalado

- **Grando de la teksto.** La ekrano estas 226 pikseloj por colo, do ĉe la agordoj de X ĉio estas tre malgranda. En `~/.Xresources` (via; la komenca programo klarigas la elektojn) agordu `Xft.dpi: 192` kaj `Xcursor.size: 48`, poste eliru kaj eniru.
  Tio estas duoble pli granda, taŭga por 13,4 coloj; `160` se ĝi ŝajnas tro granda.
- **Wi-Fi-kanaloj.** `wireless-regdb` venas kun la baza instalado nun; sur maŝino instalita de la USB-stango 0.72.97, `vikix update` aldonas ĝin.
- **Laŭtparoliloj.** Se ili estas tro malfortaj, `alsamixer` (F6 por la dua karto) montras la proprajn balancigilojn de la amplifiloj krom la ĉefa; la plafono estas en la agordoj de la programilo de la amplifiloj kaj ankoraŭ estas solvitenda.

### Ankoraŭ solvitenda

Turnado de la ekrano per la mano kaj per si mem (TODO 59), la plej granda parto de la memoro por modeloj (TODO 60), Ollama sur ĝia grafika karto (61), kaj trankvila aŭ plena potenco de Super+m kun la baro dirante kio estas (63): `TODO.md`, sub *La ROG Flow Z13*.

## Via maŝino

Kreu raporton (`vikix-hwreport > ~/vikix-hardware-$(date +%F).txt`, kun `sudo` kie `dmesg` bezonas ĝin), legu ĝian lastan sekcion kaj aldonu sekcion kiel la antaŭa al ĉi tiu paĝo en peto por ŝanĝoj, aŭ sendu la raporton kun peto pri problemo: github.com/vukini/vikix.
