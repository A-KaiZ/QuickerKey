# QuickerKeys v3.0 – manuell testplan (AutoHotkey v2, Windows)

**Mål:** Verifisere import, temaer og pålitelig mål-fane før utrulling. Kjør først med testkontoer/syntetiske data.

## A. Oppstart og UI
- [ ] Start `QuickerKeys.ahk`. Vindustittel og tray viser **QuickerKeys 3.0**.
- [ ] Åpne **Innstillinger**. Alle tre knappene (Importer konfigurasjon, Themes, Last inn på nytt) og Developers-visningen er synlige, uten overlapp.
- [ ] Velg etter tur **Midnatt**, **Grafitt**, **Skog**, **Lys** under Themes. Appen starter på nytt og bevarer valget i `[App] Tema=`.
- [ ] Endre tema manuelt i aktiv INI, trykk **Last inn på nytt** og bekreft at nytt tema brukes.

## B. Eldre QuickKey-konfigurasjon
Bruk en lokal testfil (ikke commit i repo):
```ini
[User]
Username=testbruker
[Shortcuts]
HKAgentvindu=!Numpad5
HkTjenestevindu=!Numpad4
HKcopyIM=^q
[Enabled]
HKAgentvindu=on
HkTjenestevindu=on
HKcopyIM=on
```

- [ ] Velg **Importer konfigurasjon…**, velg testfilen, les forhåndsvisningen.
- [ ] Forhåndsvisning varsler at `HKcopyIM` ikke er implementert.
- [ ] Bekreft import. Etter omstart er Vindusbytter rad 1 (Trio Agent, Alt+Num5) og rad 2 (Service Manager, Alt+Num4) aktive.
- [ ] Kontroller at `[User] Username` ikke tolkes som en SM-/Trio-innstilling.
- [ ] Gjenta med `HKAgentvindu=off` under `[Enabled]`: deaktivert snarvei skal ikke importeres.
- [ ] Gjenta med en konflikthurtigtast: importen skal rapportere konflikten.
- [ ] Kontroller at det finnes en lokal `QuickerKeys-backup-*.ini`, og at original importfil ikke er endret.

## C. QuickerKeys-konfigurasjon
- [ ] Importer en annen gyldig QuickerKeys.ini med `[App]` og `[Vindusbytter]`. Appen skal bruke verdiene etter omstart.
- [ ] Avbryt en import – gjeldende innstillinger skal være uendret.
- [ ] Gjør en manuell endring i aktiv INI, lagre i Notisblokk og trykk **Last inn på nytt**.
- [ ] Verifiser at gamle Tekstflyt- og SM Kontakt-innstillinger ikke forsvinner ved **legacy** QuickKey-import.

## D. Edge / Trio / Service Manager
- [ ] Åpne **YouTube** i Edge, **Trio Agent** i eget Edge-vindu og **Service Manager 02** i annet vindu. La YouTube være aktivt.
- [ ] Trigger en test-samtale eller en simulert manuell innfylling fra Trio. Kontroller at programmet fokuserer **Service Manager**, ikke YouTube.
- [ ] Ha YouTube og Service Manager som ulike faner i **samme Edge-vindu**, med YouTube aktiv før triggering. Kontroller at riktig fane velges.
- [ ] Test med Service Manager-vindu minimert, og med flere Edge-vinduer.
- [ ] Fjern/endre fanetittelen for Service Manager: automatiseringen skal **avbryte** i stedet for å skrive i feil fane.
- [ ] Kontroller at korrekt felt i Service Manager får testbrukernavn. Ikke stol på bare melding i loggen – sjekk selve feltet.
- [ ] Test at Vindusbytter fortsatt aktiverer de riktige vinduene/hurtigtastene.
- [ ] Test med Trio og SM i samme Edge-vindu: merk at bakgrunnslesing fra Trio fortsatt kan kreve et eget vindu.

## E. Begrensninger
- UIA fungerer forskjellig på Edge-versjoner, profiler og fanestruktur; `Ctrl+Tab`-fallback er en reservemekanisme og ikke garanti for å finne målet.
- Etter fanebytte er vindustittel et grunnleggende sikkerhetsfilter, men det beviser **ikke** at korrekt inputelement har fokus.
- Ikke test ekte pasient- eller brukeridentiteter, og ikke del logger fra produksjon i offentlige issues.

## Kriterier før merge
Programmet skal starte uten AHK-syntaks-/runtime-feil, alle fire temaer må fungere, begge formatene må importeres korrekt, og ingen test må skrive til en urelatert fane. Hvis en Edge-test feiler, la PR-en bli stående som Draft og registrer feilsituasjonen uten sensitive data.
