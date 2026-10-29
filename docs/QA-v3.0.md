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
