# Steam

Steam lanĉas ludojn, kaj per Proton ankaŭ plej el la ludoj por Windows. Sur simpla sistemo Void Linux, ĝi estas problemo: Steam estas 32-bita programo, kaj Void tenas siajn 32-bitajn bibliotekojn en aparta deponejo (multilib), kiu estas malŝaltita kiel defaŭlto, kaj la ĝustaj bibliotekoj dependas de via grafika karto. Se mankas unu biblioteko, la programo ne funkcios; la sekva biblioteko malfunkciigos la unuan ludon. Vikix faras ĉion per unu komando.

## Aldonado

```sh
vikix add steam
```

Aŭ elektu ĝin en la bonveniga ekrano (Super+m → Aldoni programon). Ĝi petas vian pasvorton unufoje, kaj poste:

- **aktivigas la multilib-deponejojn** (kaj multilib-nonfree, por proprieta NVIDIA-ovila stirilo), kaj celdirektas ĝin al la spegulla servo, kiun Vikix elektis por vi;
- **instalas Steam** el la ne-libera deponejo de Void, kun la 32-bitaj bibliotekoj, kiujn ĉiu grafika karto bezonas, kaj la Vulkan-ŝargilo, en ambaŭ versioj (`packages/optional/steam.list`; `vikix update` konservas ilin);
- **elprenas informojn pri via grafika karto** el `/sys/class/drm` kaj instalas ĝian Vulkan-ovilon en ambaŭ versioj: Intel (`mesa-vulkan-intel`), AMD (`mesa-vulkan-radeon`), NVIDIA kun la malferma ovilo (`mesa-vulkan-nouveau`), aŭ kun la proprieta ovilo, kaj la 32-bitaj bibliotekoj de la paketo `nvidia`, kiun vi havas;
- **pliiĝigas vian limon pri malfermaj dosieroj** al 524288 en `/etc/security/limits.d/50-vikix-steam.conf`. La funkcio esync de Proton malfermas dosieron por ĉiu objekto, kiun ludoj de Windows generas, kaj la limo de 4096 de Void estas tro malgranda. Ĝi ekvalidiĝas ĉe via sekva ensaluto.

Ludiloj ne bezonas ion: la reguloj de udev de Steam tagas ilin por via sesio, kaj elogind transdonas ilin al vi kiam vi enŝovas unu.

Karteto, kiun la instalado ne konas (ekzemple, virtuala maŝino), ankoraŭ ricevas Steam, kun averto: ludoj, kiuj bezonas Vulkan, ne funkcios tie.

## Ludado

Super+m → Aplikoj → Ludoj (Steam), aŭ tajpu `steam`. La unua lanĉo elŝutas la propran klienton de Steam, ĉirkaŭ 500 MB, en `~/.local/share/Steam`; viaj ludoj ankaŭ iras tien. Ensalutu kaj instalu ludon.

Por ludoj de Windows, unufoje, en Steam: Agordoj → Kongruemo → **Aktivu Steam Play por ĉiuj aliaj titoloj**. Steam tiam lanĉas ilin per Proton, sia propra Wine. Ĉu ludo funkcias, vi povas kontroli ĉe [protondb.com](https://www.protondb.com); tiuj, kiuj ne funkcias, estas plejparte tiuj, kies kontraŭ-pirata sistemo rifuzas Linux.

Ludo en ekrana reĝimo okupas la ekranon kiel ajna fenestro; Super+Tab kaj la klavoj de la labortablo ankoraŭ funkcias. Ludo, kiu volas fenestron de sia propra grandeco, flosas, se vi petas: regulo kiel `(when-window (:class "steam_app_12345") (float))`, la klaso de `xprop` aŭ Super+Alt+? sur la fenestro.

## Vidi, kio estas tie

```sh
vikix steam status
```

diras, linio post linio, ĉu la deponejo estas aktiva, ĉu Steam kaj ĝiaj bibliotekoj estas instalitaj, kiu grafikkarto estis trovita kaj ĉu ĝia stirilo estas tie, kia estas la limo de malfermitaj dosieroj, kaj kiom da spaco okupas la dosierujo de Steam. `vikix doctor` kontrolas la samon, kiam Steam estas unu el viaj funkcioj.

## Kiam ĝi ne funkcias

- **Steam ne funkcias, aŭ ludo ne funkcias.** Unue, uzu `vikix steam status`: linio komencanta per `--` indikas, ke io mankas, kaj `vikix steam setup` metos ĝin reen. Poste, lanĉu Steam el la terminalo, `steam`, kaj legu kion ĝi diras: linio kiel `error while loading shared libraries: libXXX.so` identigas 32-bitan bibliotekon, kiu ne estas tie; `xbps-query -Rs XXX-32bit` trovas ĝian paketon.
- **Ludoj de Windows kraŝas kun la mesaĝo "eventfd: Tro multaj malfermitaj dosieroj".** Vi ne refaris la eniron post la instalado: `ulimit -Hn` devus montri 524288.
- **Neniu Vulkan, do ludoj de Proton malsukĉesas.** `vikix steam status` montras la karton kaj ĝiajn pakojn. Sur aparato kun du kartoj (ekzemple Intel kaj NVIDIA), ambaŭ estas agorditaj; ludo tiam funkcias sur la karto, kiun la sistemo asignas al ĝi.
- **Neniu sono en ludo.** Steam komunikas kun PulseAudio, al kiu PipeWire respondas en Vikix (`pipewire-pulse`). `pactl info` devus montri ĝin. Neniu 32-bita komponanto estas bezonata por la sono: Steam alportas sian propran.
- **Kontrolilo ne estas detektata.** Enŝovu ĝin post eniro, kaj kontrolu ĉu `loginctl` listigas vian sesion: elogind donas la aparatojn de la seĝo al la uzanto, kiu eniris.

## Forigante ĝin

```sh
vikix remove steam
```

Forigas Steam kaj la 32-bitajn bibliotekojn, kun la 32-bita ovurilo de la grafikkarto kaj la limo pri malfermaj dosieroj. La 64-bita Vulkan-ovurilo de la grafikkarto restas, ĉar ajna programo, kiu uzas Vulkan por rendero, povas uzi ĝin, kaj tiel faras la multlib-depotrepo (`sudo xbps-remove void-repo-multilib` malŝaltas ĝin). La kliento kaj viaj ludoj, en `~/.local/share/Steam` kaj `~/.steam`, estas via kaj restas: forigu la dosierojn mem por liberigi spacon sur la disko.
