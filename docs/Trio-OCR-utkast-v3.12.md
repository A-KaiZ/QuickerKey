# Utkast: automatisk Trio-statistikk med lokal OCR

Dato: 04.11.2026. Status: **P0-fangstprøve implementert separat; OCR-import fortsatt et løsningsutkast**. Gjelder PR #9 og grenen `feature/statistikk-v3.12`, med RC14 (`52c0875`) som appgrunnlag. Ingen ny appversjon eller merge til main inngår. [Kjørbar P0-prøve, kildekode og fremgangsmåte](../tools/trio-capture/README.md).

## 1. Målet

QuickerKeys skal hente statistikk fra dagens oppgaver i Trio Oppgavelogg, uten gjentatt manuell import. Oppgavelogg skal kunne ligge bak andre vinduer mens brukeren arbeider. Dagens dato kommer fra lokal Windows-dato; 04.11.2026 er bare datoen for undersøkelsen.

Første målbare leveranse er korrekt automatisk telling av observerte oppgaver, behandlingstid og køtid. Full dekning av dagens innlastede logg er en egen egenskap som må kontrolleres. Statistikken skal aldri presentere manglende innlesing som null utførte oppgaver.

## 2. Hva vi faktisk har bevist

| Undersøkelse | Resultat | Praktisk grense |
| --- | --- | --- |
| RC14 i faktisk Trio | SysListView32, 200 rader, 13 kolonner. Prøvde UIA-tekstkilder er tomme. Fire Unicode- og fire ANSI-prøver returnerer tomt uten registrerte API-feil. | Strukturtilgang er bekreftet; teksttilgang gjennom disse metodene er ikke tilgjengelig i testen. Årsaken er ikke endelig identifisert. |
| OCR på mobilfoto | Noe dato-/tidsinnhold gjenkjennes, men felt mangler eller feilleses. | Ikke grunnlag for pålitelig radimport. |
| OCR på direkte PNG-skjermbilde | 12 synlige rader fra 04.11.2026. Dato/tid, oppgave-ID, behandlingstid og køtid samsvarte med manuelt avlest referanse: 48 av 48 kontrollerte felt. Første rad fra 03.11 ble også lest korrekt. | Ett bilde med manuelt avgrensede kolonner. Ikke en test av Windows-fangst, automatisk layoutgjenkjenning, hele historikken eller ytelse i QuickerKeys. |

OCR-prøven brukte Tesseract 5.3.4 på Linux, engelsk språkmodell, fire ganger oppskalering, hvit rand og `--psm 6`, med én OpenMP-tråd per prosess. Resultatet ble kontrollert uten å rette OCR-verdier. Motor og modell må versjonsfestes og prøves på Windows; samme resultat der er ennå ikke bevist. De innsendte bildene og deres rå celleverdier skal ikke legges i git eller CI-artefakter.

## 3. Foreslåtte tekniske valg

| Del | Valg for prototypen | Begrunnelse |
| --- | --- | --- |
| App og statistikk | Behold AHK v2, `StatistikkModul`, dagsskifte og summering. | Det er datakilden som trenger en ny rute. |
| Vindu og kolonner | Bruk HWND, klasse, overskriftsalias og vist kolonnerekkefølge som metadata. Legg til et eget lag for bildekoordinater. | Kolonneoverskriftene er lesbare selv om cellene er tomme via UIA. RC14s native hovedrute gir ikke nødvendigvis kolonnerektangler. |
| Første fangstprøve | `PrintWindow` i en separat, kortlivet Windows-hjelpeprosess. | Dokumentert Win32-rute som lar målprogrammet tegne innhold. Egnet som en avgrenset kompatibilitetsprøve mot den observerte Win32-listen. |
| Alternativ fangstprøve | Windows Graphics Capture, rettet mot kjent HWND med `CreateForWindow`. | Aktuelt dersom PrintWindow ikke gir brukbart innhold. Krever minst Windows 10 1903; dette alene garanterer ikke funksjon i Trio. |
| OCR | Lokal Tesseract med versjonsfestet motor og modell. | Motoren har gitt et korrekt resultat på det direkte skjermbildet. Ingen skytjeneste inngår. |
| Windows.Media.Ocr | Ikke standardvalg for den eksisterende løse AHK-distribusjonen. | Microsoft dokumenterer støttet desktopbruk med package identity. Vi skal ikke basere løsningen på at API-et likevel virker i et upakket script. |
| Første OCR-felt | Tidspunkt, Oppgave-ID, Behandl.tid og Køtid. | Disse fire feltene er undersøkt. Koblet og Kommentar/IM trenger egne tester. |

Fangstadapter velges først etter den faktiske prøven. Ingen av fangstmetodene skal automatisk falle tilbake til opptak av hele skrivebordet, aktivere vinduet eller omgå sperret fangst. En positiv API-retur er ikke tilstrekkelig; tabellinnholdet må kunne leses og følge faktiske endringer.

### Prosessgrense og avhengigheter

AHK beholder GUI og planlegging i den planlagte integrasjonen. P0 er nå et separat C#-/Windows Forms-verktøy for Windows x64 og .NET Framework 4.8, med GUI og kortlivet worker i samme EXE. Det bygges med Windows sin .NET Framework-kompilator og trenger ikke Python eller NuGet. Kjørbar fil, full kildekode og SHA-256 pakkes som CI-artefakt. P0 inneholder ingen OCR; motoren og integrasjonen kommer først etter godkjent faktisk fangstprøve.

Bildedata sendes i minnet til OCR, og resultatet sendes tilbake gjennom lokal IPC. Tesseracts dokumenterte TSV-format gir tekst, plassering og konfidens. Ingen midlertidige PNG-/TSV-filer skal være nødvendig i normal drift. Versjoner, språkmodell, lisensinformasjon og integritetskontroll inngår i leveransen. Manglende motor gir en tydelig status, uten automatisk nedlasting eller installasjon.

Det tillates én aktiv worker. P0 har en 3,5-sekunders ventefrist i forelderen og en 5-sekunders egenfristsikring i workeren. Selve PrintWindow-tiden rapporteres separat; dette er ikke samme mål som total oppstart/overføring. Budsjett for senere fangst og OCR fastsettes etter målingene. **PrintWindow er synkron og involverer også målprogrammets vindusbehandling; det å avslutte workeren garanterer ikke at alt arbeid i Trio avbrytes.** En prøve som gjør Trio tregt eller uresponsivt diskvalifiserer denne fangstruten.

## 4. Første port: fersk bakgrunnsfangst

Den isolerte fangstprøven P0.1 er implementert uten statistikkimport eller endring av dagens automatiske leser. Følgende faktiske Trio-prøve gjenstår; syntetiske Windows-tester kan ikke erstatte den.

1. Finn nøyaktig ett Oppgavelogg-vindu i den identifiserte Trio-prosessen. Registrer PID, HWND, listetype, klientområde, DPI, vindustilstand og metadata for kolonnene.
2. Hent et bilde mens loggen er synlig. Bruk bilde-/OCR-kontroll til å bekrefte identitetskolonner og lesbare rader. En lys bakgrunn eller et ikke-tomt bitmap alene beviser ingenting.
3. Gjenta med loggen helt dekket av et annet vindu. Ikke endre fokus, utvalg eller vindusrekkefølge.
4. Kontroller at en faktisk endring i loggen kommer med i neste fangst mens loggen er dekket. Dette prøves først med en syntetisk kontroll, deretter når en ny oppgave faktisk dukker opp i Trio. Like bilder uten nye oppgaver er normalt og beviser ikke foreldet fangst.
5. Minimering, låst skjerm, lukket vindu og HWND som tilhører en ny prosess skal gi venting/avbrudd, ikke gamle data med nytt lesetidspunkt.

Godkjent port krever lesbart og oppdatert innhold i faktisk Trio bak et annet vindu, med uendret fokus og utvalg. Hvis begge fangstrutene svikter der, er automatisk bakgrunns-OCR blokkert. Import av et manuelt skjermbilde kan være nyttig separat, men oppfyller ikke bakgrunnsmålet.

## 5. Fra bilde til validerte oppgaver

Foreslått ny adapter heter `TrioOcrLeser`. Den leverer kandidater til de eksisterende dato-/varighetsfunksjonene og `VurderRader` først etter at OCR-spesifikke krav er oppfylt.

### Layout og samme rad

- Kartlegg overskriftene entydig og hent aktuelle kolonnegrenser i samme koordinatsystem som bildet. Gjenbruk aliasnormalisering; ikke hardkod x-posisjonene eller 17-pikslers radhøyde fra testbildet.
- Avgrens OCR til de fire valgte datakolonnene og synlig tabellområde. Navn, telefon, e-post og kundenummer skal ikke OCR-behandles av denne ruten.
- Dann radbånd fra den aktuelle layouten og tekstplasseringene. Knytt et felt til en rad bare når både kolonne og vertikal plassering er entydige. En manglende celle skal ikke skyve neste rads verdi oppover.
- Klippede rader og skjulte, avkuttede eller overlappende identitetskolonner avvises. Manglende valgfrie tidskolonner gir ukjente målinger. Ved flytting, størrelse-/DPI-endring, horisontal scrolling eller kolonneendring forkastes gammelt koordinatkart og kandidater som bygger på det.
- Behold klokkeslett og ID fra samme bilde/radbånd. Ikke kombiner en dato fra ett bilde med en ID fra et annet.

### Validering og usikkerhet

| Felt | Foreslått regel |
| --- | --- |
| Tidspunkt | OCR-profilen for det observerte oppsettet krever hele `dd.MM.yyyy HH:mm:ss`, inkludert sekunder, før eksisterende kalenderparser brukes. En avkortet verdi skal ikke godtas ved å fylle inn manglende deler. Sammenlignes med lokal dato fanget ved syklusstart. Historiske rader teller ikke i dagens statistikk. |
| Oppgave-ID | Bare sifre, med eksisterende parser som yttergrense. Ni sifre er det observerte formatet i dette miljøet; OCR-profilen skal kontrollere dette, uten å anta at alle Trio-installasjoner alltid bruker ni sifre. |
| Behandlingstid og køtid | Eksisterende varighetsparser. Uleselig, avkortet eller manglende verdi blir ukjent. En faktisk lest `00:00` er en egen gyldig verdi. |
| OCR-konfidens | Brukes som avvisningssignal sammen med layout og format. Høy konfidens er ikke bevis for korrekt tekst. Terskler bestemmes med fasitprøver, ikke et tilfeldig prosenttall. |
| Gjentatt observasjon | Første automatiske prototype krever samsvarende ID/tid fra to separate fangster, uten layoutendring. Uenige målinger settes til ukjent/avventer. Gjentakelse reduserer tilfeldig støy, men utelukker ikke systematiske OCR-feil. |
| Motstrid | Konflikt i identitet eller feltplassering fører til karantene og et diagnostisk antall. Ingen automatisk retting av for eksempel O til 0 i en ID. |

RAM-nøkkelen for en oppgave forblir oppgave-ID + normalisert tidsstempel. En ny avlesning av samme nøkkel skal ikke øke antallet. Eksisterende kjent/ukjent-logikk videreføres, men en OCR-oppdatering får ikke stille overskrive en kjent verdi med en motstridende verdi. Konflikter trenger et eget feltstatuslag før de flettes inn i `TrioOppgaver`.

## 6. Hva som menes med dagens dekning

Første prototype leser bare det aktuelle synlige utsnittet. Det er tilstrekkelig til å begynne å samle observerte oppgaver, men fanger ikke nødvendigvis opp tidlige oppgaver før QuickerKeys startet, rader som aldri var synlige eller oppgaver som er falt ut av klienthistorikken.

| Dekningsstatus | Betydning |
| --- | --- |
| Ingen bekreftet innlesing | Ingen oppgaver er godkjent. Vis «Ingen lesbare data» eller konkret årsak, ikke null aktivitet. |
| Observerte oppgaver | Validerte, unike oppgaver fra ett eller flere utsnitt. Dagens total er ukjent. |
| Dagens innlastede logg kontrollert | En sammenhengende gjennomgang fra bekreftet første rad til datogrensen eller slutten av den innlastede listen er gjennomført uten hull/konflikter. |
| Kontroll avbrutt / ufullstendig | Endring i layout, brukerinteraksjon, sortering, lastede rader eller en tidsgrense hindret full gjennomgang. Allerede godkjente oppgaver beholdes. |

Selv «dagens innlastede logg kontrollert» er ikke et bevis på at klienten inneholder alle serveroppgaver. De 200 radene i diagnosen kan være en klientgrense; dette må avklares før UI bruker uttrykk som «alle dagens oppgaver». Dekning trenger et eget tidspunkt og nullstilles ved dato-/kildeskifte og når en ny rad eller kildeendring gjør den tidligere kontrollen utdatert.

### Historikk som krever scrolling: egen, senere leveranse

Vanlig 30-sekunders polling skal ikke scrolle eller ta fokus. En eventuell historikkjobb må derfor være en separat, eksplisitt startet operasjon, for eksempel «Hent dagens historikk», frem til bakgrunnsbetjeningen er prøvd og kan vurderes på nytt.

For SysListView32 kan `LVM_GETTOPINDEX` gi øverste synlige indeks, og `LVM_ENSUREVISIBLE` er en dokumentert måte å gjøre en rad synlig ved å scrolle listen. Dette beviser ikke at Trio vil oppdatere bildet korrekt i bakgrunnen eller beholde brukerens arbeidsflyt.

En slik jobb må lagre utgangsposisjon og utvalg, starte ved bekreftet topp og bruke overlappende utsnitt. ID/tid i overlappet må stemme. Datoorden skal undersøkes; man kan bare stoppe ved første eldre rad når fallende rekkefølge og sammenheng er bekreftet. Nye rader eller sortering underveis ugyldiggjør dekningskontrollen til den er kontrollert på nytt. Ved brukerinteraksjon avbrytes jobben uten å overstyre brukerens nye posisjon eller utvalg. Ellers gjenopprettes visningen og verifiseres. Tids-/sidegrense eller manglende fremdrift gir ufullstendig status, aldri full dekning.

## 7. Integrasjon i dagens kode

| Eksisterende sted | Foreslått endring ved implementering |
| --- | --- |
| `TrioOppgaveloggDiagnose` | Behold den gamle ruten for diagnostikk. Skill vindu-/kolonnemetadata fra tekstlesing, så tom UIA-tekst ikke blokkerer en uavhengig OCR-adapter. |
| Ny `TrioOcrLeser` og worker | Fangst, layoutkontroll, OCR, bekreftelse og kandidater. Eget resultat med kilde, feltkvalitet og dekningsstatus. |
| `StatistikkModul.OppdaterTrioData` | Hent fra den eksplisitt valgte datakilden, flett godkjente kandidater og håndter feltkonflikter. Ikke kjør den mislykkede native/UIA-tekstruten før hver OCR-syklus. |
| `TrioSummering` og visualisering | Behold summering, men vis hvor mange oppgaver som har kjent behandlingstid/køtid. Felt som OCR-prototypen ikke leser, skal vises som ukjent. |
| Polling, datobytte og avslutning | Én jobb om gangen, 30 sekunder som normalintervall. Ugyldiggjør utestående svar ved dagsskifte, kilde-/vindusskifte og avslutning. Gamle worker-svar kan ikke fylle neste dags RAM. |

Et worker-resultat trenger minst protokollversjon, forespørsels-ID, kilde-/layoutgenerasjon, PID/HWND, lokal datonøkkel, fangsttidspunkt, status, kandidater med feltkvalitet og rene diagnostiske antall. Prosessretur, størrelse og format valideres før svaret brukes. Bare svar til aktuell forespørsel og kilde kan godtas.

**Første OCR-leveranse skal ikke telle «Koblet» som videresending eller tolke manglende Kommentar som «ingen IM».** Disse feltene er uprøvd og utelates fra kandidaten slik at eksisterende kjent-flagg blir falske. Å telle samtaletyper fra telefonikonene er også utenfor den første leveransen; telleren heter oppgaver.

## 8. Visning og lagring

Foreslått normaltekst: «12 oppgaver observert i dag · siste vellykkede lesing 10:47 · dekning ikke kontrollert». Eksempelteksten er ikke et faktisk synkresultat. Ved feil beholdes tidligere godkjente tall med dato, siste vellykkede lesing og aktuell feilstatus. Ikke flytt «sist vellykket lest» bare fordi en worker ble startet.

Ved midnatt tømmes dagens volatile buffer som i dagens løsning. Omstart krever ny innlesing. Manuell CSV forblir separat og summeres ikke automatisk med OCR-data, fordi dobbelttelling da ikke kan utelukkes.

Hele vindusbildet kan inneholde kundeopplysninger mens det ligger kortvarig i RAM. Derfor er «ingen kundedata lest» ikke en korrekt beskrivelse av selve bildebehandlingen. Normal drift skal ikke skrive bilder, rå OCR-tekst, kunde-/telefon-/IM-verdier eller oppgave-ID-er til disk, app-logg, diagnosekopi eller skytjeneste. Oppgave-ID/tid og nødvendige statistikkfelt brukes bare i dagens RAM-buffer. Workerens standardutdata, feilutdata og automatisk feillogging må følge samme regel; ikke dump et resultat ved parsefeil.

Anonym diagnose inneholder motorversjon, metode, fangsttilstand, varighet, layoutstatus, antall undersøkte/godkjente/avviste rader og feiltype. Ingen rå celleverdier eller bildedumper. CI bruker bare syntetiske oppgaver.

## 9. Implementeringsrekkefølge og ferdigkriterier

| Trinn | Konkret leveranse | Før vi går videre |
| --- | --- | --- |
| P0: fangst | Isolert Windows-worker med eksplisitt HWND, lesbarhetskontroll og anonym diagnose. PrintWindow først, WGC ved konkret behov. Ingen statistikkimport. | Ferske, lesbare bilder av faktisk Trio bak et annet vindu, uten påvirket fokus, utvalg eller respons. Hvis dette feiler, stopp bakgrunnssporet. |
| P1: OCR-adapter | Dynamisk kolonnemapping, geometrisk radkobling og validering av de fire feltene. Syntetiske fasitbilder og prøver uten lagring av brukerbildene. | Ingen falskt godkjente oppgaver i prøvesettet; usikre rader avvises og rapporteres. Dårlige bilder skal ikke «reddes» med gjetting. |
| P2: automatisk utsnitt | Koble adapter til RAM-buffer, deduplisering, dato-/kildegenerasjon, feltstatus og 30-sekunders polling. Tydelig «observerte oppgaver». | Gjentatte sykluser teller ikke dobbelt; ferske oppgaver kommer med; gammel dag/svar kommer ikke tilbake; arbeid i andre vinduer forstyrres ikke. Faktisk Trio-QA kreves. |
| P3: dagens historikk | Separat, avbrytbar jobb med overlapp, datogrense og dokumentert dekningsstatus. | Flere skjermhøyder med dagens oppgaver, eldre historikk og brukerinteraksjon håndteres uten hull eller uriktig fullstendighetsmerking. |
| P4: ekstra felt | Egen vurdering av Koblet, Kommentar/IM og eventuelle samtaletyper. | Betydning, lesbarhet og kjent/ukjent må være bevist før nye statistikkmål vises. |

Nødvendige prøver omfatter 100/125/150/200 % skalering, flyttede/skjulte kolonner, endret størrelse, valgt blå rad, røde rader, klipping, tomme celler, nesten like sifre, to oppgaver med samme tidsstempel, motstrid mellom fangster, omstart, midnatt, lukket/gjenåpnet vindu og fastlåst worker. «OCR gjentar samme feil» må behandles som en mulig systematisk feil, ikke som et bevis på korrekthet. Test på faktisk Trio må sammenligne uavhengig fasit for telling og tidsverdier; grønne syntetiske tester alene er ikke ferdigkriteriet.

## 10. Kilder og uavklarte forhold

Primærkilder for API-egenskaper og motorvalg:

- [Microsoft: PrintWindow, returverdi og synkron vindusbehandling](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-printwindow)
- [Microsoft: Windows Graphics Capture CreateForWindow og OS-krav](https://learn.microsoft.com/en-us/windows/win32/api/windows.graphics.capture.interop/nf-windows-graphics-capture-interop-igraphicscaptureiteminterop-createforwindow)
- [Microsoft: Windows.Media.Ocr og package identity](https://learn.microsoft.com/en-us/uwp/api/windows.media.ocr)
- [Microsoft: LVM_GETTOPINDEX](https://learn.microsoft.com/en-us/windows/win32/controls/lvm-gettopindex)
- [Microsoft: LVM_ENSUREVISIBLE](https://learn.microsoft.com/en-us/windows/win32/controls/lvm-ensurevisible)
- [Tesseract: kommandolinje, TSV og segmentering](https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html)
- [Tesseract: bildekvalitet og tabellgjenkjenning](https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html)

Uavklart i det faktiske miljøet: brukbar bakgrunnsfangst, ferskhet når loggen er dekket, installert Windows-versjon og støtte for helper-distribusjonen, automatisk oppdatering av loggen, klientens historikkgrense og trygg bakgrunnsscrolling. Utkastet lover ikke at noen av disse allerede er løst.
