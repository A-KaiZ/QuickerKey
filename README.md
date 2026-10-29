# QuickerKeys

AutoHotkey v2-verktøy for arbeidsflyt i Trio Attendant, Trio Agent og Service Manager.

## Verktøy

- **Tekstflyt:** Personlige tekstsnarveier fra Excel, synkronisert ved oppstart og via «Start QuickerKeys».
- **SM Kontakt:** Overfører brukernavn/kundenummer fra Trio til Service Manager.
- **Trio Snarveier:** Menykommandoer inne i **Trio Attendant** (ny i v3.0).
- **Vindusbytter:** Opptil fire vanlige programmer/vinduer og nettleserfaner.

## v3.0 – testversjon

**QuickKey v1.05 og QuickerKeys er forskjellige programmer.** Gammel QuickKey `HKAgentvindu=!Numpad5` åpnet `Trio Attendant → Vis → Agentvinduet`. Det er **ikke** en snarvei til Edge-fanen «Trio Agent». Tilsvarende gjelder `HkTjenestevindu=!Numpad4` som åpner `Trio Attendant → Vis → Tjenestevindu`.

**Importer konfigurasjon…** under Innstillinger støtter:
- Eldre QuickKey `[Shortcuts]` + `[Enabled]`: importerer fem Trio Attendant-handlinger (`HKAgentvindu`, `HkTjenestevindu`, `HKetterarbeid`, `HKcopyIM`, `HKcopyTLF`) og kopitasten `HKCopy`. Bruker de gamle menykommandoene, men må testes i jobbmiljøet.
- Andre gamle QuickKey-kommandoer (`HKLagreUtklipp`, `HKCopyService`, `HKHurtigtekst`) importeres **ikke** som aktive funksjoner. Ny **Tekstflyt** dekker tekstutvidelser, men den gamle «Hurtigtekst»-GUI-en er ikke kopiert.
- Ny QuickerKeys-INI: importerer bare kjente innstillingsnøkler, ikke hele kildemappen eller eksterne filstier.

**Start QuickerKeys** på Oversikt bekrefter antall aktive verktøy, registrerte Trio-snarveier og lastede hurtigtekster. Programmet starter fortsatt tilgjengelige, aktiverte verktøy ved vanlig oppstart.

**Themes…** tilbyr Midnatt, Grafitt, Skog og Lys. **Last inn på nytt** laster manuelt redigerte INI-verdier.

**Edge/Service Manager:** UI Automation forsøker å aktivere riktig fane og verifiserer fanetittelen før innskriving. Ingen garanti mot alle UI-endringer; se QA-testene.

## Mapper og konfigurasjon

QuickerKeys legger alltid egne data i `%AppData%\QuickerKeys` (normalt `C:\Users\<bruker>\AppData\Roaming\QuickerKeys`), med:
- `Innstillinger\QuickerKeys.ini`
- `Tekstflyt\Tekstflyt.xlsx`
- `Logg\YYYY-MM-DD.log`

Gamle filer fra skriptmappen eller gammel MAAUNI-AppData kan kopieres ved første oppstart. Import fra QuickKey **endrer aldri** den gamle `data\config.ini` eller programplasseringen. Aktiv QuickerKeys-INI sikkerhetskopieres lokalt før import.

## Utviklere

MAUUNI og KAISAD.

> Dette er en uprøvd v3.0-utviklingsbranch. Test mot syntetiske data og se [QA-planen](docs/QA-v3.0.md) før merge. Ikke legg personlige konfigurasjoner, brukernavn, interne logger eller pasientopplysninger i det offentlige repoet.
