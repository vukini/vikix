# La Retoficejo

`vikix network`, aŭ **Super+m → System → Retoficejo**, malfermas grafikon de
la nuna loka reto en aparta Emacs-fenestro. Elektu aparaton por
ekzameni ĝiajn oftajn TCP-havenojn, malfermu retinterfacon, komencu SSH, aŭ esploru ĝiajn
dosierojn per Emacs. Emacs jam devas esti funkcianta kun ĝia servilo aktivigita;
la lanĉilo neniam komencas duan Emacs-ekzempleron. Aldonu ĝin per `vikix add emacs` se
necese. Nmap venas kun la reto-pakaĵoj de Vikix.

## Malkovro estas via elekto

Nekonata reto komencas en **manuala** modo. La Oficejo komence montras nur
tion, kion la komputilo jam scias: ĝian propran adreson, la pordon kaj la
najbaran kaŝon de la kerno. Ĉi tiuj observoj ne pruvas, ke ĉiu aparato
ankoraŭ respondas. **Malkovru aparatojn**, aŭ `d`, petas de Nmap respondojn pri
la rekte konektitaj IPv4-subreto. Elektu aparaton kaj premu `p` por ekzameni
ĝiajn oftajn TCP-havenojn.

**Prefero pri malkovro**, aŭ `c`, memoras unu elekton por ĉi tiu reto:

| Elekto | Kio okazas dum aliĝo |
|---|---|
| `manual` | Montru lokajn informojn; malkovru aparatojn kaj kontrolu havenojn nur kiam petite |
| `discover` | Aŭtomate malkovru aparatojn; kontrolu havenojn kiam petite |
| `ports` | Malkovru aparatojn, poste kontrolu oftajn TCP-havenojn sur la aparatoj, kiuj respondas |

Ŝanĝi la elekton efikas dum la sekva refreŝigo, dum dek sekundoj
dum la Oficejo estas malfermita. La enirsesio ankaŭ observas retojn, kiuj aliĝas, do
ŝparitaj elektoj funkcias dum la Oficejo estas fermita. Ĝi anoncas novobservitan
reton sen malfermi fenestron. Post la ĝisdatigo, kiu aldonas ĉi tiun funkcion,
reeniru por komenci tiun observanton; malfermi la Oficejon funkcias tuj.
Aŭtomata malkovro okazas unufoje por ĉiu aliĝo aŭ ŝanĝita prefero, ne
daŭre. **Malkovru aparatojn** por fari ĝin denove laŭ peto.

Ŝparita elekto apartenas al la konekto de NetworkManager, ĝiaj lokaj subreto,
kaj la observita porda IP-adreso kaj MAC-adresoj. Nur Wi-Fi-nomo neniam
aktivigas skanon. Manko de pruvo pri pordo igas aŭtomatan malkovron
neebla: malkovru unufoje kaj refreŝigu, poste elektu preferon. Ŝanĝita
pordo aŭ subreto komencas denove en Manuala modo. Ĉi tiu identeco malhelpas
akcidentan reutiligon de preferoj; ĝi ne aŭtentigas reton kontraŭ falsigo.

## Legi la grafikon

La branĉoj de la grafiko signifas **en ĉi tiu loka reto**. Ili ne asertas, ke
unu aparato estas fizike konektita al alia. La pordo estas identigita
el la tabulo de rutiĝo; alie neidentigita komputilo, servilo, presilo
aŭ aparato estas etiketita kiel Aparato kiam neniu nomo estas konata. La
detala panelo donas ĝian IP-adreson, MAC se konata, kaj kiel ĝi estis
observita. Elektu alian konektitan reton super
la grafiko kiam kaj Ethernet kaj Wi-Fi estas uzataj.

Premu Tab por moviĝi inter butonoj kaj Enter por aktivigi unu, aŭ klaku
aparaton. Kun subteno por SVG, la branĉoj estas desegnita kiel grafikaj kartoj;
alie la samaj butonoj formas arbon de teksto. `g` refreŝigas, `s` haltigas
la aktualan peton de la Oficejo, kaj `q` fermas ĝian fenestron. Fermi ĝin
finas ĝian propran peton; la sesia observanto ankoraŭ sekvas ŝparitajn
elektojn. Agordu Manualon por haltigi
aŭtomatan malkovron en tiu reto.

## Nomoj kaj identigo

Malkovro petas de DNS aparatojn. Kiam DNS ne havas nomon, ĝi ankaŭ provos
la mDNS/DNS-serĉon de Avahi se `avahi-resolve-address` estas instalita kaj
ĝia demono estas disponebla. Ĉiu provo daŭras maksimume unu sekundon, kun
dek sekundoj entute por la aro. Mankaj nomoj ne kaŝas aparatojn. `status` kaj
Manuala refreŝigo ankoraŭ legas nur lokajn informojn; serĉado de nomoj
okazas dum la malkovro aŭ ekzameno. Malkovrita nomo aperas apud la IP en la
arbo, kaj la detaloj montras, kie ĝi venis.

Elektu aparaton kaj elektu **Identigu aparaton**, aŭ premu `i`, por testi
ĝiajn oftajn TCP-servojn por nomoj kaj versioj. Ĉi tio daŭras ĝis ĉirkaŭ
90 sekundoj, plus la limigita serĉado de nomoj. Ĝi povas malkovri
familion de OS, kiel Linux aŭ Windows. La detaloj etiketigas ĝin kiel **Probabla OS**,
kun la servo, kiu provizis la indicon; ĝi ne estas verigita identeco de OS.
Proksio, ujuj aŭ foraj servoj povas priskribi ion alian ol la gastiganto.
Kiam ne ekzistas indico, la Oficejo diras **OS: nekonata**. Ordinara
malkovro kaj aŭtomataj kontrolitaj havenoj neniam faras ĉi tiun pli profundan
ekzamenon. Ĝi uzas malpezajn testojn de servoj de Nmap, sen `sudo`,
privilegiaj fingropruvoj de OS aŭ skanadoj pri vundeblo.

Elektu **Amika nomo**, aŭ premu `n`, por ŝpari vian propran etikedon, kiel
`Living-room NAS`. Malplena nomo forigas la etikedon. La etikedo priregas
en la arbo; malkovritaj nomoj restas en la detaloj. Nomoj estas ligitaj al
ĉi tiu reto kaj la MAC-adreso de la aparato, do ŝanĝita IP ankoraŭ povas
havi sian nomon, kaj diferenca aparato, kiu prenas la malnovan IP, ne
heredas ĝin. Se la pordo aŭ la MAC de la aparato estas nekonata, malkovru
aŭ ekzamenu la aparaton, poste refreŝigu unue. Ŝanĝita aŭ hazardigita MAC
bezonas novan etikedon. Ĉi tiuj identigiloj ne estas pruvo kontraŭ
falsigo. Etikedoj loĝas apud la preferoj pri malkovro kaj estas inkluzivitaj
en kopioj; ili ne konservas la historion de skanado de aparato.

Rezultoj pri havenoj distingas malfermajn, fermitajn kaj filtritajn havenojn;
havenoj, kiuj ne estis kontrolitaj, restas nekonataj. Nmap povas grupi
fermita aŭ filtrita havenojn en numeron. Servo-nomo apud haveno estas
sugesto el ĝia kutima numero, krom se rezulto de servo-testo estas
montrata; eĉ testrezultoj estas provizoraj. Butonoj por retumilo ofertas
por oftaj havenoj de la reto; SSH-terminalo kaj foraj dosieroj por
haveno 22. SSH petas la uzanton de la fora maŝino kaj
traktas ŝlosilojn de la gastiganto kaj laŭtomatigan aŭtentikigon.
Nenio eniras laŭtempe.

## Limoj kaj dosieroj

Ĉi tiu unua versio malkovras IPv4-retojn kun maksimume 1024 adresoj.
Kontrolado de havenoj ankaŭ povas celi unu lokan IPv4-adreson per la
sekva komando. Malkovro uzas neprivilegiajn TCP-testojn, kiuj povas
preterpasi aparatojn malantaŭ fajrovalo aŭ izolo de Wi-Fi-kliento. Neniu
respondo ne signifas, ke la aparato estas malŝaltita. Skanado de IPv6,
kontrolado de UDP, privilegiaj fingropruvoj de OS kaj plenaj skanadoj
de havenoj ne estas parto de ĉi tiu versio. Kustoma ruliĝo de politiko kaj
interferantaj rutiĝoj tra alia interfaco paŭzas la skanadon. Ŝanĝo de reto
forigas la skanadon kaj forigas ĝian rezulton. Ŝanĝoj en rutiĝo kaj reto
estas kontrolataj inter limigitaj paŭzoj; ili ne estas fajrovalo, kiu
malpermesas ĉiun pakaĵon dum la transito.

Preferoj estas viaj, en `~/.config/vikix/network/preferences.json`
(la `XDG_CONFIG_HOME` estas respektata); la defaŭlta vojo estas inkluzivita
en kopioj. Tamponaj observoj loĝas en
`$XDG_RUNTIME_DIR/vikix-network-UID/`; kiam tiu variablo mankas, la
dosierujo estas sub `/tmp`, privata por via uzanto. Rezultoj eksvalidiĝas
post dek minutoj kaj forlasitaj retoj estas forigitaj dum la observanto
aŭ la Oficejo refreŝiĝas. Neniu historio de aparato aŭ ŝanĝoj inter
vizitoj estas konservata ankoraŭ; nur viaj etikedoj kaj preferoj pri
malkovro daŭras.

Por skriptoj, `vikix network status` eldonas JSON sen skanado. Kopiu la
`id` de reto de ĝi en tiujn komandojn:

```sh
vikix network discover ID
vikix network ports ID 192.0.2.20
vikix network identify ID 192.0.2.20
vikix network name ID 192.0.2.20 "Living-room NAS"
vikix network policy ID manual
```

`vikix network refresh` aplikas konservitajn preferojn pri detektado kaj returnas la saman JSON-daton. Manka komando, malsukcesa procezo de detektado aŭ tempo-limo estas raportata kiel problemo, kaj ne prezentata kiel sukcese detektita malplena reto.
