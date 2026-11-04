# QuickerKeys

AutoHotkey v2-verktøy for arbeidsflyt i Trio Attendant, Trio Agent og Service Manager.

## Verktøy

- **Tekstflyt:** Personlige tekstsnarveier fra Excel, synkronisert ved oppstart og via «Start QuickerKeys».
- **SM Kontakt:** Overfører brukernavn/kundenummer fra Trio til Service Manager.
- **Trio Snarveier:** Menykommandoer inne i **Trio Attendant** (ny i v3.0).
- **Vindusbytter:** Opptil fire vanlige programmer/vinduer og nettleserfaner.
- **Nettverk (valgfritt):** MAC Import for å generere endepunkt-CSV til Cisco ISE.

## v3.12.0 – offisiell stabil versjonslinje (4. november 2026)

Denne release-grenen er uavhengig av den åpne eksperimentelle Trio-oppgavelogg-grenen.

- Oppdatert programversjon til `3.12.0`.
- Ny oversikt med kort, ikoner og status for aktive verktøy.
- Navigasjon og innstillinger er reorganisert med eget Avansert-vindu.
- Oppstart støtter introduksjon første gang, valgfri oppstartslogo og stille omstart.
- Autostart-snarvei oppdateres til aktiv skriptbane.
- Beholder personlige DIPS-profiler, `#dwa`/`#dwr`, Alt+F3 og eksisterende Trio-/Service Manager-funksjoner fra main.

**Avgrensning:** Ingen kode for oppgavelogg, dashboard, statistikk, OCR eller bakgrunnsfangst inngår. Dette arbeidet fortsetter i separat forsøksgren og kan bli v3.13 etter verifisert funksjon.

**QA:** Kjør Windows AutoHotkey v2-parsing og eksisterende hotfix-tester i GitHub Actions. Verifiser GUI, autostart, signaturer og Trio-snarveier på arbeidsmaskinen før produksjonsbruk.

## v3.11.3 – personlige DIPS-innstillinger og ryddigere grensesnitt

**Innstillinger → DIPS-innstillinger** samler brukernavn, valgfritt tillegg for `#dwr` og en forhåndsvisning av begge signaturene. Samme dialog kan åpnes fra Tekstflyt.

- **Automatisk brukernavn:** bruker den innloggede Windows-kontoen, med små bokstaver.
- **Eget brukernavn:** fjern krysset for automatisk brukernavn og lagre ønsket verdi.
- **Tillegg for `#dwr`:** `D2358` er standard. Tillegget kan endres eller tømmes. Store/små bokstaver beholdes i tillegget og utklippstavleteksten.
- **Personlig profil:** lagres separat i `Innstillinger\DIPS.ini` og knyttes til Windows-kontoen. En profil uten kontotilknytning eller fra en annen konto brukes ikke; standarden blir den innloggede Windows-brukeren.
- **Konfigurasjonsimport:** importerer generelle programinnstillinger og snarveier. Den endrer ikke DIPS-profilen, og importerer verken eldre `[User] Username`, `[Tekstflyt] Initialer` eller nye personlige signaturverdier. Ved overgang fra v3.11.1/v3.11.2 brukes Windows-brukernavnet; et eventuelt eget signaturnavn settes på nytt i DIPS-innstillingene.

«Aktiver Nettverk» / «Deaktiver Nettverk» erstatter «Nettverksgeni?». Fyrverkerianimasjonen er fjernet. Innstillinger har norsk temavelger, DIPS-knapp og samlet utviklerkreditering. Meldinger og statuslinjer bruker nøytral ordlyd uten dekorative bekreftelsessymboler.

Windows-testene dekker full AHK-parsing, kontoavgrensning, importfiltrering, lagring, validering, faktiske tekstutvidelser med eget/tomt signaturtillegg og forhåndsvisning i den native DIPS-dialogen. Skjermbilder av Innstillinger og DIPS-dialogen lagres som CI-artefakter for visuell kontroll. Faktisk Trio/Citrix må fortsatt prøves i jobbmiljøet.

## Historisk: v3.11.2 – små bokstaver i signaturen

Initialene i `#dwa` og `#dwr` settes alltid inn med små bokstaver, også når de lagrede initialene eller Windows-brukernavnet har store bokstaver. Eksempel: `(TOENGV) 041126` blir `(toengv) 041126`. Utklippstavlens tekst og `D2358` beholder sin opprinnelige skrivemåte.

## Historisk: v3.11.1 – signaturer og fem minutter etterarbeid

- **`#dwa` + Mellomrom/Enter:** `(initialer) ddMMyy`. Utklippstavlens tekst legges til når den inneholder nøyaktig ni tegn, som i den gamle egendefinerte koden.
- **`#dwr` + Mellomrom/Enter:** `(initialer) ddMMyy D2358`.
- Begge signaturer er innebygd i Tekstflyt og virker også når Excel-filen mangler. De følger Tekstflyt PÅ/AV. Excel-rader med samme navn overstyres uten å endre arbeidsboken.
- Sett egne initialer under **Tekstflyt → Initialer / signatur → Lagre initialer**. Windows-brukernavnet brukes som standard. Eldre `[User] Username` støttes i aktiv INI og via **Importer konfigurasjon**; en eksplisitt `[Tekstflyt] Initialer` har prioritet.
- **Alt+F3:** nytt alternativ **Etterarbeid – 5 minutter** under Trio Snarveier. Standardtasten er aktiv hvis den ikke har konflikt med andre lagrede QuickerKeys-snarveier. Eksisterende snarvei for etterarbeid beholdes. Tasten kan endres eller slås av.
- Femminuttersvalget finner en entydig, lesbar varighet i en ComboBox/ListBox i Trios «Sett inn»-dialog, velger og verifiserer den før Ctrl+Enter. Uleselig eller tvetydig valg lar dialogen stå åpen for manuelt valg. Det brukes ingen antakelse om antall piltrykk.

**Verifikasjon:** Windows-testene parser hele programmet og tester signaturer, faktiske tekstutvidelser i et separat testvindu, Excel-synkronisering, PÅ/AV, utklippstavle og varighetsvalg i native testkontroller. Faktisk Trio/Citrix må fortsatt prøves i jobbmiljøet. Hvis Trio bruker en annen kontrolltype, kan Alt+F3 åpne dialogen uten å bekrefte automatisk.

## v3.11 – Nettverk og UIA-feltgjenkjenning (feature branch)

Denne oppdateringen bygger videre på v3.8 i `main`.

- **Nettverk:** Valgfri side via Innstillinger → «Aktiver Nettverk», av som standard.
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

**Tema…** tilbyr Midnatt, Grafitt, Skog og Lys. **Last inn på nytt** laster manuelt redigerte INI-verdier.

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
- `Innstillinger\DIPS.ini` (personlig signaturprofil)
- `Tekstflyt\Tekstflyt.xlsx`
- `Logg\YYYY-MM-DD.log`

Gamle filer fra skriptmappen eller gammel MAAUNI-AppData kan kopieres ved første oppstart. Import fra QuickKey **endrer aldri** den gamle `data\config.ini` eller programplasseringen. Aktiv QuickerKeys-INI sikkerhetskopieres lokalt før import.

## Utviklere

MAUUNI og KAISAD.

> Dette er en uprøvd v3.0-utviklingsbranch. Test mot syntetiske data og se [QA-planen](docs/QA-v3.0.md) før merge. Ikke legg personlige konfigurasjoner, brukernavn, interne logger eller pasientopplysninger i det offentlige repoet.
