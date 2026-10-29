# QuickerKeys v3.1 – testplan og review

> **Status:** Statisk gjennomgang utført. Endringene er **ikke** kjørt i Windows med Trio/Service Manager. Ikke merge før akseptansetest. Magnus sin innsendte kilde sa `APP_VERSJON := "3.3"`; PR benytter **3.1** i tråd med ønsket versjon og branchnavn.

## Omfang

- Tekstflyt: oversikt over eksisterende koder med søk, forhåndsvisning, redigering og omdøping.
- Tekstflyt: sikkerhetskopi ved intern XLSX-omskriving (uten Excel COM).
- Trio Snarveier: opptak av taster og mulighet til å slette tastvalg.
- Ett-tegns hurtigtaster gjelder kun når Trio Attendant er aktivt.
- Trio kopiering: merking av IM/telefonnummer slik at de ikke sendes som brukernavn til SM Kontakt.
- Bedre melding ved kopiering, deteksjon av rene telefonnumre, normalisert sendesekvens.
- **Beholdt fungerende Trio-/SM-baseline fra `main`** framfor å erstatte hele motoren med Magnus sin uprøvde variant. Dette er en *tilpasset* implementering av de relevante v3.1-funksjonene, ikke en byte-for-byte kopi av innsendt v3.3-fil.

## Akseptansetest i Windows (med syntetiske data)

- [ ] AutoHotkey v2 starter uten syntaksfeil, feilvarsler eller dubletter.
- [ ] Sammenlign antall aktive snarveier før/etter oppstart. Eksisterende hurtigtaster må fortsatt virke.
- [ ] Test Agentvindu, Tjenestevindu og Etterarbeid i Trio Attendant.
- [ ] Test IM/Kommentar og A-nr. Kontrollér at verdien kopieres, at kopifeltet gjenopprettes, og at det **ikke** fylles ut Kontakt ved telefonkopi.
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
4. **Personvern:** Noen eksisterende logglinjer i `main` kan inneholde brukernavn/kundenumre og en diagnosefunksjon kan kopiere skjermtekst. Ikke del slike logger eller diagnoseutklipp eksternt. Vurder dataminimering i neste patch.
5. **Ikke automatisk fokusflytting:** SM Kontakt har beholdt eksisterende sikring og skal ikke bla gjennom urelaterte Edge-faner.

## Beslutning

PR kan gjennomgås og testes, men ikke merge til `main` før de kritiske testene for Trio/Service Manager og Excel er bekreftet på arbeidsmaskin. All testing skal gjøres uten ekte pasient- eller kundedata.
