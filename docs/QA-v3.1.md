# QuickerKeys v3.1 – testplan og review

> **Status:** Statisk gjennomgang utført. Endringene er **ikke** kjørt i Windows med Trio/Service Manager. Ikke merge før akseptansetest. Magnus sin innsendte kilde sa `APP_VERSJON := "3.3"`; PR benytter **3.1** i tråd med ønsket versjon og branchnavn.

## Omfang

- Tekstflyt: oversikt over eksisterende koder med søk, forhåndsvisning, redigering og omdøping.
- Tekstflyt: sikkerhetskopi ved intern XLSX-omskriving (uten Excel COM).
- Trio Snarveier: opptak av taster og mulighet til å slette tastvalg.
- Ett-tegns hurtigtaster gjelder kun når Trio Attendant er aktivt.
- Trio kopiering: merking av IM/telefonnummer slik at de ikke sendes som brukernavn til SM Kontakt.
- Bedre melding ved kopiering, deteksjon av rene telefonnumre, normalisert sendesekvens.
- **Magnus sin skjulte Trio-innstillingsvariant er nå integrert** i `KopierMedFelt()`, `SettParameter()` og `LukkInnstillinger()`: `WinSetTransparent 0`, kontrollklikk med `NA`, PID-avgrenset dialog, opprinnelig Parameter lest før endring og gjenoppretting i `finally`.
- Resten av den etablerte SM Kontakt-/Edge-sikkerheten fra `main` er beholdt. Dette er fortsatt en tilpasset integrasjon, ikke en byte-for-byte kopi av hele innsendte fil.

## Akseptansetest i Windows (med syntetiske data)

- [ ] AutoHotkey v2 starter uten syntaksfeil, feilvarsler eller dubletter.
- [ ] Sammenlign antall aktive snarveier før/etter oppstart. Eksisterende hurtigtaster må fortsatt virke.
- [ ] Test Agentvindu, Tjenestevindu og Etterarbeid i Trio Attendant.
- [ ] Test IM/Kommentar og A-nr. Kontrollér at verdien kopieres, at kopifeltet gjenopprettes, og at det **ikke** fylles ut Kontakt ved telefonkopi.
- [ ] **Skjult Trio-innstilling:** test at `Fil → Innstillinger` ikke blinker/forstyrrer, musepekeren ikke flytter seg, og ingen vinduer blir hengende åpne etter gjentatte kopieringer.
- [ ] **Gjenoppretting:** velg en annen legitim Hurtigkopiering-Parameter før testen, gjennomfør IM/telefon-kopi og bekreft at den opprinnelige verdien er tilbake etterpå. Som i Magnus sin implementasjon settes tidligere `Kommentar`/`A-nr` tilbake til `IDM Username`.
- [ ] **Feilsituasjoner:** test med kopitast feil konfigurert, låst/ufokusert Trio og avbrutt kopiering. Kontroller logg, lukking av innstillingsvindu, og at Parameter ikke blir stående i `Kommentar`/`A-nr`.
- [ ] Test IDM Username som før. Brukernavn fylles inn i rett Service Manager-fane, uten at YouTube/andre Edge-faner får tastetrykk.
- [ ] Test én-tegns hurtigtast, f.eks. `-`: den utløses i Trio, men skriver ordinært `-` i Notisblokk og Edge.
- [ ] Test tastopptak (Ctrl+Alt, Numpad, `æ`), Esc/avbryt, lagring og gjenstart.
- [ ] Test at konflikt mot QuickerKeys vis/skjul, SM Kontakt og Vindusbytter meldes.
- [ ] Åpne eksisterende Excel fra AppData. Søk etter kode og fritekst, rediger tekst og gi kode nytt navn. Verifiser i Excel og ved faktisk ekspansjon.
- [ ] Forsøk å endre kode til en eksisterende kode. Ingen data må overskrives.
- [ ] Test på egen kopi av en arbeidsbok med formatering og evt. flere ark. **Den interne XLSX-skriveren rekonstruerer første ark med to kolonner og kan fjerne formatering, ekstra kolonner, ark og metadata.** Sørg for at sikkerhetskopi finnes og ikke bruk den modusen på originaler med flere ark.
- [ ] Start fra forskjellige mapper; innstillinger og Excel-fil skal fortsatt leses fra valgt sted / %AppData%\\QuickerKeys.
- [ ] Restart, aktivér/deaktivér modul, temaendring og import gammel config. Bekreft at stier og data beholdes.

## Funn og gjenstående risiko

1. **Unngå `Hotkey tast, TomHandling, "Off"` for validering.** Det kan deaktivere eksisterende binding. Her brukes sideeffektfri syntaktisk validering; den faktiske registreringen har fremdeles feilhåndtering.
2. **XLSX uten Excel:** Fallback-omskriving er ikke tapsfri. Backup er innført, men fremtidig forbedring bør bevare øvrige ark/celler eller sperre kompleks Excel-redigering uten Excel.
3. **Clipboard-tilordning:** Merket er tidsbegrenset. Test variasjoner i Trio-versjoner og eventuelle kopieringsforsinkelser.
6. **Skjult dialog er ikke ferdig verifisert:** `WinSetTransparent 0` og `ControlClick` med `NA` er implementert etter Magnus sitt mønster, men vindus- og museoppførsel kan bare verifiseres i faktisk Trio på Windows. Ved feil under gjenoppretting gis advarsel i loggen og brukerbeskjed om å kontrollere Parameter manuelt.
4. **Personvern:** Noen eksisterende logglinjer i `main` kan inneholde brukernavn/kundenumre og en diagnosefunksjon kan kopiere skjermtekst. Ikke del slike logger eller diagnoseutklipp eksternt. Vurder dataminimering i neste patch.
5. **Ikke automatisk fokusflytting:** SM Kontakt har beholdt eksisterende sikring og skal ikke bla gjennom urelaterte Edge-faner.

## Beslutning

PR kan gjennomgås og testes, men ikke merge til `main` før de kritiske testene for Trio/Service Manager og Excel er bekreftet på arbeidsmaskin. All testing skal gjøres uten ekte pasient- eller kundedata.
