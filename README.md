# QuickerKeys

AutoHotkey v2-verktøy for arbeidsflyt i Trio Attendant, Trio Agent og Service Manager.

## Verktøy

- **Tekstflyt:** Personlige tekstsnarveier fra Excel, synkronisert ved oppstart og via «Start QuickerKeys».
- **SM Kontakt:** Overfører brukernavn/kundenummer fra Trio til Service Manager.
- **Trio Snarveier:** Menykommandoer inne i **Trio Attendant** (ny i v3.0).
- **Vindusbytter:** Opptil fire vanlige programmer/vinduer og nettleserfaner.
- **Nettverk (valgfritt):** MAC Import for å generere endepunkt-CSV til Cisco ISE.
- **Statistikk (PR #9):** Automatisk, foreløpig innlesing fra Trio Oppgavelogg til eget dashboard, manuell skriftlig tid og UIA-diagnostikk.

## v3.12-rc10 – Statistikk + Trio Oppgavelogg (PR #9)

En egen **Statistikk**-fane gir manuelle samtaletellere og skriftlig tid. Ved **Siste registreringer i dag** er det en liten rød **🗑**-knapp med bekreftelse. Den sletter kun dagens fullførte manuelle CSV-statistikk etter eksplisitt Ja, og blokkeres hvis en samtale eller skriftlig tid fortsatt pågår. Den nye **Trio Oppgavelogg / UIA…**-knappen åpner en konfigurasjonsdialog for automatisk innlesing og skrivebeskyttet diagnose av **Trio Attendant 10.1.35**.

| Innstilling | Standard |
| --- | --- |
| Åpne Oppgavelogg automatisk | På |
| Legg ny Oppgavelogg bak andre vinduer (uten å minimere) | På |
| Poll-/diagnoseintervall | 30 sekunder |
| Vis feilstatus i Statistikk | På |

**Oppførsel:** Når Trio er startet og det har gått minst fire sekunder uten fysisk input (uavhengig av hvilket vindu som er aktivt, og hvor musepekeren er), forsøker QuickerKeys `Vis → Oppgavelogg` via standard Win32-meny, **uten** `WinActivate`, `Click` eller `Send`. Et nytt separat Oppgavelogg-vindu gjenkjennes i Trios prosess eller samme exe, og flyttes **bak andre vinduer med `WinMoveBottom`**, uten å minimeres. Ved manuell bruk får Oppgavelogg stå i fred; RC6 legger det bakerst igjen etter en kort pause når brukeren går videre. Fokuset forsøkes ikke flyttet tilbake. En kort synlig åpning er fortsatt mulig når Trio selv oppretter vinduet.

Hvis standardmenyen ikke er tilgjengelig, loggen har en annen prosess-ID, eller vinduet ikke gjenkjennes, vises status. For å unngå gjentatte popup-vinduer blir et mislykket automatisk åpningsforsøk ikke gjentatt i samme Trio-prosess før omstart.

**Innlesing og diagnose (RC10):** Hvert 30. sekund leses tilgjengelige oppgaver. Oppgaver identifiseres fra **Tidspunkt** og **Oppgave / Oppgave-ID**. Behandlingstid er en separat, valgfri måling. Ingen fast antakelse om 13 kolonner eller behandlingstid i kolonne 9. Standard Win32 ListView leses kolonnevis med kobling mellom vist og logisk kolonnerekkefølge; egendefinert UIA-liste leses via HeaderItem og cellenes plassering. Tomme felt bevarer sin plass. Nested ListItem-celler behandles innen raden; ListItem-per-celle kan samles når de har identisk vertikal radplassering. Ingen glidende sammenslåing på tvers av rader. Tvetydig kolonnemapping eller motstridende celleverdier avvises.

**RC10 etter brukertest:** RC9 fant 13 kolonner, men behandlingstid var den eneste ukoblede nøkkelkolonnen. Den tidlige sperren ga derfor 0 kandidatrader. RC10 normaliserer usynlige Unicode-formateringstegn (inkludert myk bindestrek og nullbredde), NBSP, linjeskift og `&` i overskrifter, og støtter de eksakte forkortelsene «Behandl. tid» og «Beh. tid». Ingen generell/fuzzy tolkning av «Tid» som behandlingstid.

**Oppgavetelling fortsetter uten behandlingstid:** En gyldig oppgave-ID og et gyldig tidspunkt fra i dag er tilstrekkelig for observert antall og timegraf. Manglende/ugyldig behandlingstid blir **ukjent**, ikke 0, og tas ikke med i summen. Kortet «Behandling (kjent min)» viser «—» hvis ingen tider er kjent; status viser dekningen. Tidligere kjente tider i samme dagsbuffer beholdes ved en senere ufullstendig skanning. Diagnosen viser nå de faktiske **HeaderItem-overskriftene**, med usynlige tegn skrevet som `[U+....]`, slik at et ukjent kolonnenavn kan identifiseres uten rad-/kundedata. «8 av 12» er erstattet av et aliasantall i strukturutvalget, siden dette aldri var en kontroll av 12 faktiske kolonner.

**Status betyr faktisk innlesing:** «UIA-struktur funnet» alene er ikke en vellykket import. Både hovedstatus, dashboard og **Kopier diagnose** viser resultatet av feltlesingen: nødvendige/valgfrie felt koblet eller manglende, kandidatrader, validerte oppgaver fra i dag, andre dager og separate avvisningsgrunner (manglende felt, dato/tid, ID-format, behandlingstid, motstridende celler). Radstruktur rapporteres som antall bladkontroller og lesemetode. Ingen rå celleverdier eksporteres. Oppdatering skjer automatisk; **Oppdater nå** er kun en reserve.

**Delvis tilgjengelige felt:** Køtid, Koblet og Kommentar/IM er valgfrie og skal ikke blokkere oppgavetelling. Dashboardet viser «—» hvis Koblet eller Kommentar ikke kunne leses for noen oppgaver, og oppgir dekning for disse feltene. «Med Koblet-verdi» er en indikasjon, **ikke bekreftet videresending**. Ukjent køtid tas ikke med i gjennomsnittet. Kun statistikkfelter og midlertidig ID/tid-nøkkel holdes i RAM. Manuell CSV er separat.

**Test:** Windows-testene i `tests/run-trio-tests.ps1` laster hele den faktiske AHK-kilden, men avslutter før vanlig oppstart, slik at appinnstillinger og manuell CSV ikke berøres. Testene dekker parser, avvisningsgrunner, duplikater og en syntetisk ListView i en separat prosess via Win32 og UIA. Workflowen **Trio reader (Windows)** kjører dette ved kildekodeendringer. En syntetisk test beviser ikke at Trio 10.1.35 eksponerer samme layout; faktisk Trio-test kreves fortsatt før merge.

**Viktig:** Brukertesten 03.11.2026 bekreftet at UIA **ikke** kan lese tabell/listestruktur når Trio 10.1.35 Oppgavelogg er minimert (0 lister, 0 rader), men at den gjør det i normalt vindu (1 List, 68 listeelementer, 8 kjente overskrifter). Dette er ikke 68 bekreftede samtaler. **RC5 bruker derfor bakgrunnsmodus som standard**. Den nye konfigurasjonsnøkkelen `TrioBakgrunn=1` erstatter gamle `TrioAutoMinimer`; minimering anbefales ikke og utføres ikke lenger automatisk. RC6 og senere forsøker også å gjenopprette manuelt minimerte loggvinduer uten aktivering etter 15 sekunder og minst fire sekunder fysisk inaktivitet. Vi har ennå ikke bekreftet at `WinMoveBottom` fungerer uten synlig glimt/fokusendring i brukerens Trio-miljø. Fra og med RC8 forsøker QuickerKeys **automatisk innlesing av dagens validerte oppgaver**, men resultatet er foreløpig og kan være ufullstendig fordi Trio-lister kan være virtualisert. Kjør [QA-statistikk-v3.12](docs/QA-statistikk-v3.12.md) i faktisk Trio-miljø før merge. Innstillingene lagres under `[Statistikk]` i `Innstillinger\QuickerKeys.ini`.

### RC6 – Oppgavelogg styrer seg selv uten flere knapper

- **Automatisk drift:** QuickerKeys oppdager Oppgavelogg og åpner den ved behov uten å kreve Trio i forgrunnen. Første åpning krever minst 4 sekunder uten fysisk input for å redusere forstyrrelser.
- **Manuell bruk:** Når du åpner/aktiverer Oppgavelogg, lar QuickerKeys deg jobbe der uten å flytte vinduet. Etter at du bytter til et annet vindu, legges Oppgavelogg bakerst igjen etter ca. **15 sekunder**, uten å minimere.
- **Lang inaktivitet:** Hvis Oppgavelogg fortsatt er aktivt, men mus og tastatur har vært helt i ro i minst **60 sekunder**, legger QuickerKeys vinduet bakerst.
- **Manuell minimering:** Etter ca. 15 sekunder forsøker QuickerKeys å gjenopprette vinduet med Win32 `ShowWindowAsync(..., SW_SHOWNOACTIVATE=4)` og flytte det bakerst. Gjenoppretting krever også minst 4 sekunder uten fysisk input og er ikke testet i Trio ennå. Dette er nødvendig fordi UIA-tabellen ikke er synlig for UIA når Oppgavelogg er minimert.
- **Manuell lukking:** Hvis du lukker et Oppgavelogg-vindu som QuickerKeys har oppdaget, venter programmet minst **30 sekunder** før det igjen forsøker å åpne det automatisk. Gjenåpning skjer først etter minst 4 sekunder fysisk inaktivitet.
- **Ingen nye kontroller:** RC5-innstillingene beholdes, men ingen egne Pause/Gjenoppta-knapper er lagt til. De 30 sekundene i innstillingene er fortsatt **UIA-diagnoseintervallet**, ikke tiden før vinduet legges bakerst.
- **RC6-historikk:** På dette stadiet var automatisk statistikkimport ennå ikke implementert. Dette ble senere endret i RC8.

**Forbehold:** Trio/Windows kan vise et kort vindusglimt ved åpning eller gjenoppretting. `ShowWindowAsync` og `WinMoveBottom` kan oppføre seg annerledes i den faktiske Trio-klienten. Test før merge.
### RC7 (historikk) – Første datatest og visuell oversikt

- Ny **Visualiseringer**-knapp øverst i Statistikk åpner et separat mørkt dashboard. De fire nøkkeltallene og timegrafen (08–18) bruker **kun faktiske manuelle registreringer fra dagens CSV**; ingen eksempeldata vises i programmet.
- Ny knapp **Test Trio-rader (uten lagring)** inne i dashboardet. Den leser kontrollert opptil 12 ListItem/DataItem-rader fra **det ene** UIA-List-elementet i Oppgavelogg.
- Testen undersøker om radene eksponerer 13 Text-underkontroller og validerer **kun format**, ikke verdi, for tidspunkt (kol. 1), numerisk oppgave-ID (kol. 2), behandlingstid (kol. 9) og køtid (kol. 10). Den rapporterer også hvor mange i det avgrensede utvalget som har dagens dato.
- Rapporten viser **kun aggregerte antall gjenkjente felter**, aldri telefonnummer, kundenummer, rå oppgave-ID, IM-tekst eller kommentar. Raw UIA-strenger behandles midlertidig i minnet og skrives ikke til disk. Det er ingen automatisk eksport eller import av Trio-historikk.
- **Kopier testresultat** sender kun den anonymiserte formatrapporten til utklippstavlen. Dette er innhentingstest, **ikke** en statistikk over alle samtaler. UIA-virtualisering kan gjøre at historiske rader ikke er tilgjengelige.

**RC7-historikk:** Dette var det første utkastet basert på manuelle CSV-data. RC8 erstatter visningen med foreløpig Trio-data og gjør innlesing automatisk. Ikke bland Trio-data med manuelle timer før samsvar er bekreftet.
### RC8 (historikk, erstattet av RC9) – første automatiske radleser

- **Automatikk:** Den allerede eksisterende 30-sekunders UIA-syklusen undersøker nå også faktiske felter fra tilgjengelige rader i Trio Oppgavelogg. Brukeren trenger normalt ikke å klikke for å lese nye data.
- **Valgfri handling:** Knappen i Visualiseringer heter **Oppdater nå** og kjører den samme lesesyklusen umiddelbart. Den er tiltenkt første test og feilsøking, ikke rutinedrift.
- **Dagsdashboard fra Trio:** Øverst vises foreløpig antall observerte oppgaver, antall med «Koblet», antall med IM-referanse i Kommentar, samlet behandlingstid og en timegraf. Ikke bland disse tallene med de manuelle CSV-registreringene.
- **Lesemetode:** Foretrekker AutoHotkey v2 `ListViewGetContent` for `SysListView32` med 13 kolonner; ved egendefinert liste forsøkes UIA `List`/`ListItem`/`DataItem`. En liste som ikke eksponerer nøyaktig 13 felter i forventet rekkefølge, blir **ikke** tolket som en samtale.
- **Validering:** Kode kontrollerer dato/tid (kolonne 1), numerisk oppgave-ID (2) og behandlingstid (9). Køtid (10) brukes dersom gyldig, `Koblet` (11) indikerer mulig videresending, og en IM-mønsterkontroll på Kommentar (13) gir kun en boolsk tilstedeværelse. Telefonnumre/kundenummer/kommentar- eller IM-tekst kopieres ikke til filer eller GUI.
- **Deduplisering:** Oppgave-ID og tidspunkt brukes som midlertidig nøkkel i RAM. Nye og endrede observerte oppgaver fra flere skanninger overskriver samme nøkkel. Dagsbufferen nullstilles ved ny dato. Ingenting importeres til manuell CSV.
- **Datakvalitet:** Dashboardet er **foreløpig** og viser observerte oppgaver, ikke et bekreftet fullstendig dagsantall eller nødvendigvis bare besvarte samtaler. Virtualiserte lister kan vise færre oppgaver enn hele historikken. Ved ingen validerte rader vises «—» og forklarende status, ikke oppdiktede tall.
- **Feilsøking uten skjermbilder:** Eksisterende «Kopier diagnose»-knapp inkluderer nå en anonym oppsummering av innlesingsstatus, kilde, vurderte rader og antall observerte oppgaver. Ingen rå oppgave-ID, telefonnummer, kundenummer eller IM-referanser deles.

**Viktig:** Kun statisk kodekontroll er utført i utviklingsmiljøet. RC8 må verifiseres mot den virkelige Trio Attendant 10.1.35 UIA-strukturen før tallene kan regnes som komplette. Ingen endring i Trio, ingen automatisk saksoppretting og ingen merge til `main`.
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
