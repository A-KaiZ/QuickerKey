# QuickerKeys

AutoHotkey v2-verktøy for arbeidsflyt i Trio Attendant, Trio Agent og Service Manager.

## Verktøy

- **Tekstflyt:** Personlige tekstsnarveier fra Excel, synkronisert ved oppstart og via «Start QuickerKeys».
- **SM Kontakt:** Overfører brukernavn/kundenummer fra Trio til Service Manager.
- **Trio Snarveier:** Menykommandoer inne i **Trio Attendant** (ny i v3.0).
- **Vindusbytter:** Opptil fire vanlige programmer/vinduer og nettleserfaner.
- **Nettverk (valgfritt):** MAC Import for å generere endepunkt-CSV til Cisco ISE.
- **Statistikk (PR #9):** Manuelle samtaletellere, skriftlig tid og skrivebeskyttet UIA-diagnose for Trio Oppgavelogg.

## v3.12-rc5 – Statistikk + Trio Oppgavelogg (PR #9)

En egen **Statistikk**-fane gir manuelle samtaletellere og skriftlig tid. Ved **Siste registreringer i dag** er det en liten rød **🗑**-knapp med bekreftelse. Den sletter kun dagens fullførte manuelle CSV-statistikk etter eksplisitt Ja, og blokkeres hvis en samtale eller skriftlig tid fortsatt pågår. Den nye **Trio Oppgavelogg / UIA…**-knappen åpner en konfigurasjonsdialog for skrivebeskyttet diagnose av **Trio Attendant 10.1.35**.

| Innstilling | Standard |
| --- | --- |
| Åpne Oppgavelogg automatisk | På |
| Legg ny Oppgavelogg bak andre vinduer (uten å minimere) | På |
| Poll-/diagnoseintervall | 30 sekunder |
| Vis feilstatus i Statistikk | På |

**Oppførsel:** Når Trio er startet og det har gått minst fire sekunder uten fysisk input (uavhengig av hvilket vindu som er aktivt, og hvor musepekeren er), forsøker QuickerKeys `Vis → Oppgavelogg` via standard Win32-meny, **uten** `WinActivate`, `Click` eller `Send`. Et nytt separat Oppgavelogg-vindu gjenkjennes i Trios prosess eller samme exe, og flyttes **bak andre vinduer med `WinMoveBottom`**, uten å minimeres. Vinduer brukeren allerede har åpnet, flyttes ikke av automatikken. Fokuset forsøkes ikke flyttet tilbake. En kort synlig åpning er fortsatt mulig når Trio selv oppretter vinduet.

Hvis standardmenyen ikke er tilgjengelig, loggen har en annen prosess-ID, eller vinduet ikke gjenkjennes, vises status. For å unngå gjentatte popup-vinduer blir et mislykket automatisk åpningsforsøk ikke gjentatt i samme Trio-prosess før omstart.

**Diagnose:** Automatisk åpningskontroll kjører hvert 2,5 sekund og UIA-diagnose hvert 30. sekund. Manuell «Kjør UIA-test nå» undersøker bare en allerede åpen Oppgavelogg, uavhengig av fokus. Ved feil vises stegnavn, kort AHK-feil og linjenummer. RC4 retter også navnekollisjonen mellom lokal `logg` (HWND) og funksjonen `Logg()`, som tidligere kunne gi `Integer has no method named Call` etter en vellykket UIA-lesing. UIA bruker `ElementFromHandle` og en begrenset `ControlViewWalker` (maks 140 registrerte noder og dybde 5). Den rapporterer bare kontrolltyper (DataGrid, Table, List, DataItem/ListItem), et antall gjenkjente standardoverskrifter, minimeringsstatus og tidsforbruk. Ingen celleverdier, kundenumre, telefonnumre, IM-referanser eller kommentarer eksporteres. Brukeren kan kopiere en anonym statusrapport.

**Viktig:** Brukertesten 03.11.2026 bekreftet at UIA **ikke** kan lese tabell/listestruktur når Trio 10.1.35 Oppgavelogg er minimert (0 lister, 0 rader), men at den gjør det i normalt vindu (1 List, 68 listeelementer, 8 kjente overskrifter). Dette er ikke 68 bekreftede samtaler. **RC5 bruker derfor bakgrunnsmodus som standard**. Den nye konfigurasjonsnøkkelen `TrioBakgrunn=1` erstatter gamle `TrioAutoMinimer`; minimering anbefales ikke og utføres ikke lenger automatisk. Har du et *allerede minimert* Oppgavelogg-vindu fra RC4, må du manuelt gjenopprette det eller lukke det og la RC5 åpne et nytt. Vi har ennå ikke bekreftet at `WinMoveBottom` fungerer uten synlig glimt/fokusendring i brukerens Trio-miljø. Det finnes **ingen automatisk dataimport eller samtaletelling fra Trio** i denne PR-en. Kjør [QA-statistikk-v3.12](docs/QA-statistikk-v3.12.md) i faktisk Trio-miljø før merge. Innstillingene lagres under `[Statistikk]` i `Innstillinger\QuickerKeys.ini`.

## v3.11 – Nettverk og UIA-feltgjenkjenning (nå i main)

Denne oppdateringen bygger videre på v3.8 i `main`.

- **Nettverk:** Valgfri side via Innstillinger → «Nettverksgeni?», av som standard.
- **MAC Import:** Bygger CSV for Cisco ISE-endepunkter med 31 kolonner, MAC-parsing, duplikatfjerning, validering og eksplisitt bekreftelse. Skriver fil lokalt; gjør ingen endringer i ISE.
- **SM Kontakt:** Lærer UIA-signaturer for Kontakt-feltet (ControlType, Name, AutomationId og ClassName). Finner feltet på nytt ved kjøring og bruker Tab + Enter. Eldre oppsett med trygge koordinater beholdes.
- **Trio Snarveier:** IM Search kan identifiseres med UIA-signatur, med koordinatfallback for eldre konfig.
- **Regresjonsvern:** Fane- og vindusverifisering før innskriving, og ikke-mutativ hurtigtastvalidering fra v3.8 beholdes.

**Status:** Kun statisk integrert. Ingen Windows-/Trio-/Service Manager-/Cisco ISE-test er utført. Ikke merge før [QA-v3.11](docs/QA-v3.11.md) er godkjent. Bruk testdata, ikke personsensitive opplysninger.

## Historisk: v3.0 – testversjon

**QuickKey v1.05 og QuickerKeys er forskjellige programmer.** Gammel QuickKey `HKAgentvindu=!Numpad5` åpnet `Trio Attendant → Vis → Agentvinduet`. Det er **ikke** en snarvei til Edge-fanen «Trio Agent». Tilsvarende gjelder `HkTjenestevindu=!Numpad4` som åpner `Trio Attendant → Vis → Tjenestevindu`.

**Importer konfigurasjon…** under Innstillinger støtter:
- Eldre QuickKey `[Shortcuts]` + `[Enabled]`: importerer fem Trio Attendant-handlinger (`HKAgentvindu`, `HkTjenestevindu`, `HKetterarbeid`, `HKcopyIM`, `HKcopyTLF`) og kopitasten `HKCopy`. Bruker de gamle menykommandoene, men må testes i jobbmiljøet.
- Andre gamle QuickKey-kommandoer (`HKLagreUtklipp`, `HKCopyService`, `HKHurtigtekst`) importeres **ikke** som aktive funksjoner. Ny **Tekstflyt** dekker tekstutvidelser, men den gamle «Hurtigtekst»-GUI-en er ikke kopiert.
- Ny QuickerKeys-INI: importerer bare kjente innstillingsnøkler, ikke hele kildemappen eller eksterne filstier.

**Start QuickerKeys** på Oversikt bekrefter antall aktive verktøy, registrerte Trio-snarveier og lastede hurtigtekster. Programmet starter fortsatt tilgjengelige, aktiverte verktøy ved vanlig oppstart.

**Themes…** tilbyr Midnatt, Grafitt, Skog og Lys. **Last inn på nytt** laster manuelt redigerte INI-verdier.

**Edge/Service Manager:** UI Automation forsøker å aktivere riktig fane og verifiserer fanetittelen før innskriving. Ingen garanti mot alle UI-endringer; se QA-testene.

## Regresjonsrettelser: SM Kontakt og Tekstflyt (2026-10-29)

**Hvor er filene?** v3.0 bruker som standard `%AppData%\QuickerKeys`, selv når `QuickerKeys.ahk` ligger under `Downloads\quickerkey-test`. Dette er bevisst for å beholde personlige innstillinger mellom kodeoppdateringer, men krever at testere bruker appens **Åpne datamappen**-knapp og ikke redigerer en gammel INI i Downloads. Ikke flytt hele QuickKey-mappen.

**Excel-valg:** Tekstflyt → **Importer / velg Excel…** åpner en eksisterende Excel-fil. Dialogen tilbyr **Ja = kopier en ny, tidsstemplet fil til AppData**, **Nei = bruk eksisterende fil på opprinnelig sted**, **Avbryt = ingen endring**. Filen prøveleses før ny sti lagres. Ved manglende valgt fil vises feil; programmet bytter ikke automatisk til eksempelkoder.

**SM Kontakt:** Opplæring godtar bare en bekreftet Service Manager-fane; lagret `SMVindu` får stabilt navn som `Service Manager ahk_exe msedge.exe`. Eldre oppsett med ugyldig navn (f.eks. `! W$ ahk_exe msedge.exe`) må læres på nytt. Under automatisk innfylling velges fanen uten å bla gjennom Edge-fanene med Ctrl+Tab; feil mål gir avbrudd fremfor innskriving i feil fane.

**Trio Web i bakgrunnen:** Den eksisterende UIA-lesingen beholdes. Nødvarianten som fremhever Trio ved ulesbar side er slått **av** som standard; kan ved behov aktiveres eksplisitt i `[SMKontakt]` med `TillatTrioFokus=1`. Dette bør kun gjøres når brukeren aksepterer fokusbytte.

**Begrensning:** Vi har ikke kjørt denne koden i HSØ-/Trio-miljøet. UI Automation av Edge-faner og skjermkoordinater må testes på Windows før merge.

## Mapper og konfigurasjon

QuickerKeys legger alltid egne data i `%AppData%\QuickerKeys` (normalt `C:\Users\<bruker>\AppData\Roaming\QuickerKeys`), med:
- `Innstillinger\QuickerKeys.ini`
- `Tekstflyt\Tekstflyt.xlsx`
- `Logg\YYYY-MM-DD.log`

Gamle filer fra skriptmappen eller gammel MAAUNI-AppData kan kopieres ved første oppstart. Import fra QuickKey **endrer aldri** den gamle `data\config.ini` eller programplasseringen. Aktiv QuickerKeys-INI sikkerhetskopieres lokalt før import.

## Utviklere

MAAUNI og KAISAD.

> Dette er en uprøvd v3.0-utviklingsbranch. Test mot syntetiske data og se [QA-planen](docs/QA-v3.0.md) før merge. Ikke legg personlige konfigurasjoner, brukernavn, interne logger eller pasientopplysninger i det offentlige repoet.
