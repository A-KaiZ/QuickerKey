# QuickerKeys v3.0 – Windows QA (AutoHotkey v2)

**Status:** Statisk kodegjennomgang gjennomført. Må kjøres i Windows før merge.

## 1. Oppstart, filstruktur og tema
- [ ] Kjør v3.0 fra en kopi av den **gamle QuickKey-mappen**. Bekreft at nye filer **kun** skrives under `%AppData%\QuickerKeys`, ikke inn i gammel `QuickKey\data`.
- [ ] Verifiser at `QuickKey\data\config.ini` er uendret etter import.
- [ ] Verifiser `Innstillinger\QuickerKeys.ini` under AppData, og en lokal backup før import.
- [ ] Test at eldre QuickerKeys.ini i skriptmappen kopieres ved første oppstart dersom ny aktiv INI mangler.
- [ ] Under Oversikt: **Start QuickerKeys** viser faktisk antall lastede hurtigtekster og aktive funksjoner.
- [ ] Test **Midnatt**, **Grafitt**, **Skog** og **Lys** uten overlapp i GUI. Test manuell redigering i INI og «Last inn på nytt».

## 2. Gammel QuickKey v1.05
Bruk testkopi av den gamle configen; ingen ekte brukeridentiteter.

```ini
[User]
Username=testbruker
[Shortcuts]
HKetterarbeid=!F1
HKcopyIM=^q
HKcopyTLF=!F2
HKCopy=^d
HkTjenestevindu=!Numpad4
HKAgentvindu=!Numpad5
[Enabled]
HKetterarbeid=on
HKcopyIM=on
HKcopyTLF=on
HkTjenestevindu=on
HKAgentvindu=on
```

- [ ] Bruk Innstillinger → **Importer konfigurasjon…**. Bekreft at forhåndsvisning viser **Trio Snarveier**, ikke Vindusbytter.
- [ ] Bekreft at `[User] Username` ikke importeres automatisk.
- [ ] Bekreft at `HKCopy` lagres som den underliggende kopitasten (`^d`), ikke registreres som selvstendig handling.
- [ ] Bekreft at avkryssede `on/off`-verdier samsvarer med aktive taster.
- [ ] Test `Alt+Numpad5`: **Trio Attendant → Vis → Agentvinduet**, selv om Edge/YouTube er aktivt.
- [ ] Test `Alt+Numpad4`: **Trio Attendant → Vis → Tjenestevindu**, selv om Edge/YouTube er aktivt.
- [ ] Test `Alt+F1`: Meny **Sett inn → Etterarbeid** utfører korrekt valg og gjenoppretter tidligere vindu.
- [ ] Test `Ctrl+Q`: Kopier Kommentar, og kontroller at Trio går tilbake til **IDM Username**.
- [ ] Test `Alt+F2`: Kopier A-nr, og kontroller at Trio går tilbake til **IDM Username**.
- [ ] Bekreft at `HKLagreUtklipp`, `HKCopyService` og `HKHurtigtekst` vises som **ikke støttet**.
- [ ] Hvis dere tidligere importerte feil Edge-mapping i PR #3-utkastet, kjør import på nytt og kontroller at feilaktige Vindusbytter-rader fjernes uten å berøre egne vinduer.
- [ ] Sjekk at originale QuickKey-filer ikke blir flyttet eller skrevet over.

## 3. Ny QuickerKeys-INI
- [ ] Importer egen `.ini` fra annet sted. Bekreft at støttede nøkler oppdateres, mens `ExcelFil`/eksterne filstier ikke overskrives.
- [ ] Avbryt import og bekreft at aktiv fil ikke endres.
- [ ] Test to snarveier med identisk tast. Konflikten skal vises, ikke overstyre en annen funksjon.
- [ ] Slå av ett Trio-verktøy: hurtigtasten skal opphøre. Slå på igjen: den skal registreres.

## 4. Edge, Trio Web og Service Manager
- [ ] YouTube aktiv i Edge, Trio Agent i ett vindu, Service Manager i et annet: verifiser at riktig SM-fane får testdata.
- [ ] YouTube og SM i samme Edge-vindu: verifiser at riktig fane velges.
- [ ] Test flere Edge-profiler og minimert SM-vindu.
- [ ] Endre/fjern SM-fanetittel. Automatiseringen skal avbryte, ikke skrive i feil fane.
- [ ] Verifiser feltet visuelt, ikke bare en loggmelding.

## Merge-kriterier
Ingen runtime-/syntax-feil. Gammel QuickKey oppfører seg uendret. De fem Trio Attendant-snarveiene fungerer. Import rører ikke QuickKey-datamappen. Ingen automatisk skriving i feil Edge-fane. Hvis dette feiler: behold PR som Draft.

## 5. Regresjonstester etter rapporterte feil 29.10.2026

**Kjør testene i denne rekkefølgen; bruk syntetiske verdier, ikke pasientopplysninger.**

- [ ] **Sjekk aktiv datamappe:** Start fra `Downloads\quickerkey-test`. Åpne *Innstillinger → Åpne datamappen*. Kontroller at aktiv INI ligger under `%AppData%\QuickerKeys\Innstillinger`.
- [ ] **Excel – kopi:** Velg gammel fungerende `.xlsx` og svar *Ja* i importdialogen. Kontroller at originalfilen fortsatt finnes, en tidsstemplet kopi er opprettet under AppData, og riktig antall koder lastes etter omstart.
- [ ] **Excel – direkte fil:** Velg en annen testfil og svar *Nei*. Kontroller at den opprinnelige stien bevares ved omstart og at ingen ny AppData-kopi blir brukt.
- [ ] **Excel – mangler:** Velg direkte fil, stopp programmet og flytt/gi nytt navn til testfilen. Start igjen. Programmet skal vise «valgt Excel-fil mangler» – **ingen erstatningsfil skal opprettes på den gamle stien**.
- [ ] **SM identifikator:** Åpne Edge med en Service Manager 02-fane og en YouTube-fane. Utfør *Lær oppsett*; bekreft at programmet lagrer `Service Manager ahk_exe msedge.exe`, ikke en tilfeldig tittel som `! W$`.
- [ ] **SM negativ test:** Prøv å lære på et annet Edge-nettsted. Programmet skal avvise det før det lagrer kontaktkoordinatene.
- [ ] **SM Test:** Bruk syntetisk verdi. Programmet skal velge Service Manager-fanen uten å Ctrl+Tab gjennom andre faner. Hvis det ikke finner riktig fane, må det avbryte **uten å skrive**.
- [ ] **Trio Web bakgrunn:** La Trio Agent stå i et eget Edge-vindu bak et annet program; bekreft at UIA-lesing fortsatt fungerer uten at Trio trekkes frem.
- [ ] **Fokusbytte:** Sjekk at `[SMKontakt] TillatTrioFokus` ikke er satt til `1`. La en video spille mens SM Kontakt forsøker å lese; faneblading må ikke skje bare fordi UIA-lesingen er treg.
- [ ] **Trio Attendant regresjon:** Bekreft igjen at Agentvindu, Tjenestevindu, Etterarbeid, Kopier IM og Kopier A-nr fungerer.
- [ ] **Oppstart på ny maskin:** Bruk testprofil uten QuickerKeys.ini og Excel-fil. Første oppstart skal lage standard eksempelkoder, men ikke overskrive noen eksisterende arbeidsbøker.

**Før merge:** Magnus og KAISAD bekrefter at SM Kontakt og Tekstflyt fungerer på minst én relevant Windows-klient. Hvis UIA velger feil fane eller skjermen overtas uventet, behold PR som Draft.
