# QuickerKeys 3.13 sandbox · lokal Trio OCR-test P1.0

Denne pakken bygger på den offisielle QuickerKeys 3.12.0-utgaven. Pakk ut hele ZIP-filen og start **Start-QuickerKeys.cmd**, velg **Trio OCR-test** i sidemenyen og trykk **Åpne Trio OCR-test**. Hjelpeprogrammer, OCR-motor og en versjonsfestet AutoHotkey v2-runtime følger med; ingen installasjon er nødvendig. OCR-programmene krever Windows x64 og .NET Framework 4.8.

Sandboxen bruker egen datamappe (`AppData\Roaming\QuickerKeysSandbox313`) og egen autostartsnarvei. Den importerer ikke ordinære profiler automatisk. Avslutt den vanlige QuickerKeys mens du tester, slik at to utgaver ikke konkurrerer om de samme hurtigtastene. Den offisielle 3.12-utgaven og dens datamappe beholdes.

## Startfil og Windows-varsler

**Start-QuickerKeys.cmd** er startfilen: den velger pakkens mappe og starter `Runtime\AutoHotkey64.exe` med `QuickerKeys.ahk`. Selve CMD-filen installerer ingenting, laster ikke ned noe og endrer ikke sikkerhetsinnstillinger. Den er ment å startes, ikke redigeres.

`TrioOcrProbe.exe` og `TrioCaptureProbe.exe` i denne prototypen er ikke Authenticode-signert. Nye/usignerte programmer kan gi SmartScreen-varsel eller bli blokkert av virksomhetens programkontroll. En SHA-256-kontroll bekrefter filintegritet, ikke at programmet er godkjent av virksomheten. For jobbbruk må pakken vurderes og distribueres gjennom virksomhetens vanlige ordning, med godkjent signering og/eller regler fra IT etter deres policy. Signering alene garanterer ikke at SmartScreen aldri viser varsel. Hele pakken, inkludert tredjepartsmotoren, inngår i vurderingen.

Feil ved oppstart viser Windows-feilkoden når den er tilgjengelig. En slik oppstartsfeil er ikke en kontroll av Windows-arkitektur eller installert .NET-versjon.

## Prøv på jobb

1. Åpne Trio Oppgavelogg uten å minimere vinduet.
2. Åpne OCR-testen fra QuickerKeys og trykk **Finn Oppgavelogg**.
3. Trykk **Les utsnitt (5 s)**. I nedtellingen kan loggen dekkes av et annet vindu. Ikke scroll eller endre kolonner mens prøven pågår.
4. Se resultatet for dagens synlige rader: formatvaliderte oppgaver, behandlingstid, køtid og antall avviste/ukjente felt.
5. Trykk **Kopier anonym diagnose** og del teksten. Diagnosen inneholder ikke bilder eller rå celleverdier.

**Test bildehenting** åpner den tidligere P0-prøven med forhåndsbilde og manuell kontroll av lesbarhet/ferskhet. Bruk den dersom OCR ikke finner data, eller for å sammenligne synlig og dekket logg. Hvis Trio blir tregt under fangst, avbryt forsøket.

## Hva P1 gjør

- Henter ett nytt bilde og layout i en avgrenset worker. UIA brukes bare for kolonneoverskrifter og radrektangler, aldri for radtekst. Win32-meldinger leser bare kolonnerekkefølge og full kolonnebredde, fordi UIA kan oppgi et smalere område rundt overskriftsteksten.
- Krever en uendret layout før og etter fangst. Kolonner kobles etter navn og plassering, ikke faste koordinater fra et skjermbilde.
- Leser bare tidspunkt, oppgave-ID, behandlingstid og køtid optisk. Andre bildefelt sendes ikke til Tesseract. Etter datolesingen hvitmaskeres historiske/avviste rader før ID- og tidskolonnene behandles.
- Bruker lokal Tesseract 5.5.0 med medfølgende engelsk modell. Pakkens motor kommer fra en versjons- og SHA-256-festet upstream-utgave; ingen installasjon eller nedlasting skjer ved bruk.
- Normaliserer radbakgrunnen fra den vanligste lysverdien og fjerner kanttilknyttede fokusrammer før OCR. Tegn som berører kanten blir ikke rekonstruert.
- Kobler tekst til én rad og én kolonne ut fra geometrien. Tekst som krysser grenser gir konflikt, ikke sammenslåing med naboceller.
- Krever hele `dd.MM.yyyy HH:mm:ss` og ni sifre i ID, i samsvar med oppsettet vi har observert. Uleselige varigheter blir ukjente; faktisk `00:00` er kjent null.
- Konfidens under 60 avvises i denne eksperimentelle profilen. Dette er et avvisningsfilter, ikke en sannsynlighet for at teksten er riktig. Formatvaliderte tall kan fortsatt inneholde systematiske OCR-feil.
- Dedupliserer innen bildet og setter motstridende duplikater i karantene. To forskjellige ID-er med samme tidsstempel kan være to oppgaver.

## Status og avgrensning

Resultatet gjelder **bare det aktuelle bildeutsnittet**. Det er ikke bekreftet mot to uavhengige fangster, ikke dagens fullstendige total og ikke importert til et automatisk dashboard. Ingen 30-sekunders timer, historikkscrolling, Koblet-/IM-telling eller samtaletypeklassifisering inngår.

Faktisk Trio-bakgrunnsfangst og OCR er fortsatt uavklart frem til brukertest. De grønne testene bruker syntetiske data. Ved manglende/klippet kolonne, utilgjengelige radrektangler eller endret layout stoppes forsøket fremfor å gjette. Ingen tall presenteres som null aktivitet når innlesingen mislykkes.

Hele vindusbildet kan inneholde kundeopplysninger kortvarig i RAM. Bildet, rå OCR-tekst og ID-er skrives ikke til filer eller logger og sendes ikke til nettverkstjenester. Motoren får PNG gjennom standard inn og leverer TSV gjennom standard ut; bare den anonyme oppsummeringen kan kopieres. Ordinær prosessminnehåndtering i Windows gjelder. PrintWindow er synkron i målprogrammet; avsluttet worker garanterer ikke at alt arbeid i Trio avbrytes.

Fangst med layout har sju sekunders foreldrefrist og åtte sekunders worker-frist. Hvert Tesseract-kall har seks sekunders frist og avbrudd. P0 beholder sine tidligere frister. Dato kontrolleres på nytt før resultatet vises.

## Bygg

`tools/trio-ocr/build.ps1` bygger OCR- og fangstverktøyene. `prepare-engine.ps1` pakker ut den låste Tesseract-utgaven på byggmaskinen uten å installere den. `build-sandbox.ps1` lager hele QuickerKeys-testpakken. Kildekode, byggeoppskrifter, motorens proveniens og SHA-256 følger med.

Kilder:

- [Tesseract 5.5.0, inkludert Windows-utgaven](https://github.com/tesseract-ocr/tesseract/releases/tag/5.5.0)
- [Tesseract – TSV og kommandolinje](https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html)
- [Microsoft – UIA og MTA-tråder](https://learn.microsoft.com/en-us/windows/win32/winauto/uiauto-threading)
- [Microsoft – PrintWindow](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-printwindow)
