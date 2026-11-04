# QuickerKeys Statistikk v3.12 — QA og avgrensninger


## RC13 – klassefilter for direkte WinForms-ListView-lesing

**RC12 i faktisk Trio:** Name, Value, LegacyName, LegacyValue og radnavn er tomme BSTR-er; TextPattern er utilgjengelig. Dette bekrefter at de prøvde UIA-kildene ikke gir tidsverdier. Det beviser ikke at native ListView-meldinger er prøvd, fordi denne ruten tidligere krevde eksakt klassenavn `SysListView32`.

**Konkret kodefeil:** Windows Forms superklasser ListView med et registrert navn som `WindowsForms10.SysListView32.app.0...`. Dette ble hoppet over. RC13 godtar det avgrensede klasseformatet og bruker eksisterende AutoHotkey `ListViewGetContent`, som sender ListView-meldinger mot HWND og støtter målprosessens bitbredde. Ingen egen minneskanner eller endring av Trios data.

Native diagnose viser klasse, rad-/kolonneantall, OwnerData-flagg, antall tidsverdier og resultat/feilsteg. En korrekt klassegjenkjenning garanterer ikke at privat/virtuelt lagrede ListView-data kan hentes ut. Hvis ingen native kandidat finnes eller direkte lesing også er tom, må Trios faktiske kontroll undersøkes; flere datoformater hjelper ikke.

### Windows-tester

En faktisk .NET Framework Windows Forms-liste med de 13 observerte Trio-overskriftene kjøres i både 64- og 32-bits Windows PowerShell. Oppgave-ID-kolonnen flyttes visuelt. En testleser gjør alle UIA-cellekilder utilgjengelige. Den native ruten skal fortsatt gi to dagens oppgaver og én annen dag, uten å kalle UIA-celleleseren. Diagnosen skal oppgi WindowsForms-klassen og bare metadata. Tidligere kilde-, kalender-, langlogg- og fokustester beholdes.

### Faktisk Trio-test

Start **3.12-rc13**, vent en syklus og se etter «Native listekandidater» / «Native liste». Hvis dagens data fortsatt ikke leses, er disse linjene avgjørende. **Trios faktisk registrerte klasse og native teksttilgang er ikke bekreftet fra RC12-rapportene. Draft beholdes; ingen merge.**

## RC12 – prøv faktiske tekstkilder når Name/Value er tomme

**Ny brukertest:** 200 kandidater med 13 bladkontroller. 52 hadde plassering for Tidspunkt, men både Name og Value var tomme; dermed ingen gyldige tidsverdier, ingen strukturelle kart og 0 dagens oppgaver. Resten manglet tidsfelt. Dette dokumenterer manglende tekst fra de prøvde egenskapene og avgjør ikke om tomheten skyldes kontrollvalg eller providerens teksteksponering.

- Cellelesing prøver LegacyIAccessible Name (30092), Value (30093) og TextPattern (10014) DocumentRange/GetText etter Name/Value. COM-metoder og egenskaps-ID-er er kontrollert mot Microsofts Windows SDK-header. Kun lesing, maks 512 tegn per TextPattern-cellekall, ingen Select/Scroll/Realize.
- Ved tom/ugyldig celleverdi prøves maksimalt tre foreldre med samme entydige kolonneplassering. List, ListItem, DataItem, Table og DataGrid er grenser og leses aldri som celleinnhold.
- Et radnavn kan bare brukes som tid hvis første kjente kolonne er Tidspunkt og hele radnavnet parses som én gyldig dato/tid. Motstridende gyldige tidsegenskaper avvises og overstyres ikke av radnavnet.
- Diagnose skiller VARIANT-type fra tom BSTR, teller tekstkilder og viser tids-/radnavn bare som maskerte formater. Status sier direkte fra når ingen tidstekst kan leses gjennom de prøvde kildene. Det hentes ikke flere data fra historiske rader enn nødvendig for datofilteret.

### Tester

Tomme Name/Value med gyldig LegacyName, alternativ TextPattern, motstridende Legacy-datoer, wrapper i samme kolonne, avvisning av annen kolonne/hel rad, streng første-kolonne-tid og maskering. Windows-integrasjon prøver standard ListView med Name/Value undertrykt i celleleseren for å teste faktisk Legacy-tilgang, samt faktisk TextPattern COM-lesing fra et separat Windows-tekstfelt. Tidligere langlogg-, dagsfilter-, varighets-, fokus- og dedupliseringstester videreføres.

### Faktisk Trio-QA

Start **3.12-rc12**, vent én syklus og kopier diagnosen dersom ingen dagens oppgaver leses. Se særlig «Tidstekstkilde», «Tid valgt fra» og maskert radnavn. Testene dekker valgte feilsituasjoner og standard Windows-kontroller, men beviser ikke at Trio eksponerer disse tekstkildene. **Draft / ikke merge før fungerende faktisk Trio-test.**

## RC11 – dagens dato først, tidskilde og rader uten plassering

Brukeren bekreftet at Oppgavelogg har historikk tilbake til 12.10.2026 og ba om fokus på kun dagens dato, 03.11.2026. RC10-rapporten viste 52 kandidater med tidsfelt som alle ble avvist på dato/tid; 116 manglet felter. Dermed var historikk alene ikke en forklaring: «Andre dager» var fortsatt 0. Den nøyaktige UIA-tidsverdien er ikke gitt i rapporten.

- **Dagens dato er dynamisk:** nytt filter per lesing fra Windows, ikke hardkodet til 03.11.2026. Ved identifiserbare UIA-rader leses tidspunkt først. Gyldig annen dato krever ingen øvrige data og hopper over resten. Ulesbar dato avvises; den gjøres aldri om til dagens dato.
- **Tidsrepresentasjon:** normalisering av formattegn/mellomrom og eksakt `Tidspunkt:`-etikett. Kildevalg mellom Name og Value baseres på gyldig dato. To forskjellige gyldige datoer avvises. Diagnose viser maskerte formatstrenger som `dd.dd.dddd dd:dd:dd`, og antall valg fra hver kilde.
- **Eksponerte rader uten koordinater:** et cellekart kan utledes fra komplette rader med gyldig tidsfelt og entydig geometri for alle kjente kolonner. Samme antall, relative bladbaner og kontrolltyper kreves, og motstridende kart sperres. Kartet gjelder bare den aktuelle skanningen. Kun allerede eksponert tekst leses; ingen scrolling, tastetrykk eller VirtualizedItem.Realize.
- **Full historikk garanteres ikke:** UIA-kontrollen kan skjule helt urealiserte rader. Tid-/nodegrenser gjelder fortsatt og rapporteres. Dagens tall er observerte oppgaver, ikke attestert samtalestatistikk.

### Tester

Eksakt tidligere observert tidsformat `02.11.2026 09:40:38`, etikett/Unicode-format, Name mot ugyldig Value, motstridende tidsverdier og maskering. Datofilteret testes med 12.10, 02.11, 03.11 og 04.11, samt overgang til ny datodag. Motstridende strukturelle cellekart skal aldri brukes. En syntetisk lang Windows-logg med 178 historiske og to dagens oppgaver prøves gjennom UIA; cellekoordinater fjernes etter de to første radene. Leseren skal hente dagens to oppgaver uten å endre listescrollingen. Dette bekrefter eksponert tekst uten koordinater, ikke ekte leverandørvirtualisering.

### Trio-test

Start **3.12-rc11**, vent én automatisk syklus, og sjekk at «Dagens datofilter» viser dagens faktiske dato. Sammenlign observerte oppgaver med dagens synlige Trio-oppgaver. Hvis «dato/tid» fortsatt øker uten validerte rader, del **Kopier diagnose** med de maskerte tidsformatene. Ingen rå tids-, kunde- eller telefonverdier behøves. **Draft beholdes; faktisk Trio er ikke tilgjengelig i utviklingsmiljøet.**

## RC10 – behandlingstidskolonnen skal ikke stoppe oppgavetelling

**Brukerrapport 03.11.2026:** 13 HeaderItem med lesbar plassering. Tidspunkt, Oppgave-ID, Køtid, Koblet og Kommentar/IM koblet; bare Behandlingstid manglet/var tvetydig. 0 kandidatrader og 0 UIA-noder fordi RC9 avbrøt før radlesingen. Dette beviser en sperre i skjemaet, ikke manglende oppgaver. Den eksakte UIA-overskriften er ennå ikke sett.

**Endret:** Overskriftsnormalisering fjerner Unicode-formattegn, NBSP, linjeskift og mnemonic-tegn. Eksakte forkortelser «Behandl. tid» / «Beh. tid» støttes. Identitet er tidspunkt + oppgave-ID; behandlingstid er nå uavhengig av oppgavetelling. Ukjent behandlingstid holdes utenfor summer, og feltdekning vises. Diagnosen viser HeaderItem-etikettene (aldri radverdier), med skjulte tegn synliggjort som `[U+....]`. Ingen plassbasert gjetting når overskriften er ukjent.

### Verifikasjon

- Automatiserte AHK-tester for myk bindestrek, nullbredde, NBSP, `&`, forkortelser og synliggjøring av skjulte tegn. «Tid» og «Køtid» må ikke tolkes som behandlingstid.
- Syntetisk Windows ListView gjennom både Win32 og UIA: usynlige tegn i faktisk header, forkortet header med flyttede kolonner og fullstendig ukjent behandlingsoverskrift.
- Ukjent behandlingsoverskrift skal fortsatt gi to oppgaver fra i dag, men ingen kjent behandlingstid. «00:00» skal derimot være kjent nulltid. Aggregatoren testes mot samme parserdata som dashboardet bruker.
- Faktisk Trio-QA: start **3.12-rc10**, vent én automatisk syklus og åpne Visualiseringer. Sammenlign observerte oppgaver og kjent behandlingstid med Trio. Hvis oppgavene fortsatt ikke kan leses, kopier diagnosen med overskriftene og avvisningsgrunnene.

## RC9 (historikk; RC10 endrer krav til behandlingstid)

## RC9 – innlesing etter kolonnenavn og konkret feltdiagnose

**Feilen rapportert fra RC8:** UIA fant List og listeelementer, men 150 kandidater ga 0 validerte oppgaver. RC8 krevde 13 felter og faste posisjoner. Rapporten skilte ikke felt-/formatfeil fra oppgaver fra andre dager. Dette dokumenterer at RC8 ikke kunne lese brukerens data; den eksakte klientstrukturen er fortsatt ubekreftet.

**Endret:** Kolonneoverskrifter og celleplassering erstatter 13-feltsgjettingen. Tomme felt beholdes; ingen glidende gruppering av tekst på tvers av rader. Nøkkelfelt er tidspunkt, oppgave-ID og behandlingstid. Valgfrie felt kan mangle uten å stoppe tellingen. Gyldig faktisk kalenderdato og norsk/ISO-dato med minutter eller sekunder støttes. Rapporten gir bare feltnavn, formatutfall og antall. Status viser innlesingsresultat, ikke kun strukturfunn. «Satt videre» er endret til «Med Koblet-verdi» fordi tolkningen ikke er bekreftet.

### Automatisert Windows-verifikasjon

Kjør `./tests/run-trio-tests.ps1 -AutoHotkey <sti-til-AutoHotkey64.exe>`, eller se GitHub Actions → **Trio reader (Windows)**. AHK v2.0.19 er versjons- og SHA256-låst i workflowen. Testkopien kjører testene og avslutter **før** appens normale initialisering. Ingen ekte Trio-data eller produksjonsinnstillinger brukes.

Testene undersøker den faktiske parseren, ikke en kopi på et annet språk: norske og ISO-tidspunkter, ugyldige kalenderdatoer, varigheter, semantiske kolonnenavn, geometri, manglende felt, separate avvisningsgrunner, duplikater, gårsdato, valgfrie felt, og fravær av rå verdier i diagnosen. En separat prosess lager en ekte syntetisk Win32 ListView med 7 kolonner, tom symbolkolonne og omordnet kolonnerekkefølge. Begge backender må gi samme oppgaver og varigheter. Testen kontrollerer også gjentatt skanning, fokus og minimering. Dette erstatter ikke QA i den faktiske Trio-klienten.

### Kort test i Trio 10.1.35

- [ ] Start **3.12-rc9**, behold Oppgavelogg åpen bakerst, vent én automatisk syklus (30 sekunder).
- [ ] Åpne Statistikk → Visualiseringer. Sammenlign observerte oppgaver og behandlingstid med dagens synlige rader i Trio. Ingen manuell registrering er nødvendig.
- [ ] Ved manglende tall: bruk eksisterende **Trio Oppgavelogg / UIA → Kopier diagnose**. Rapporten skal vise hvilke nøkkelfelt som kunne kobles, avvisningsgrunner, andre dager og radstruktur. Ingen skjermbilder eller rå kundedata trengs.
- [ ] Kontroller at ukjente Koblet-/Kommentar-felt vises som «—», og at dekning oppgis. Manglende køtid må ikke bli 0 sekunder i gjennomsnittet.
- [ ] Kontroller gjentatt synkronisering: samme oppgaver skal ikke øke totalen. Ny/endret oppgave skal oppdateres ved neste automatiske syklus.
- [ ] Kontroller fokus i Service Manager under lesing, og tidligere vinduslivssyklus (åpning, bakgrunnsplassering, manuell bruk og minimering).
- [ ] Verifiser SM Kontakt, Trio Snarveier og manuell statistikk separat før merge.

**Grenser:** Kun tilgjengelige oppgaver observeres; UIA-virtualisering, horisontal skjuling av nødvendige kolonner eller alternative radrepresentasjoner kan fremdeles hindre lesing. Skanningen har 4 sekunders kooperativ grense, 6000 besøkte UIA-noder og opptil 2000 rader. En enkelt COM-/ListView-operasjon kan ta lengre tid; grensen er ikke en hard timeout. Ingen automatisk scrolling. ID og tidspunkt er volatile RAM-nøkler; ingen varig dagsbuffer. Oppgaver er ikke det samme som dokumenterte besvarte samtaler. **Draft beholdes; ikke merge før faktisk Trio-QA.**

## Historikk RC1–RC8

Seksjonene nedenfor beskriver tidligere utkast og er ikke spesifikasjonen for RC9.

## Funksjoner i dette utkastet
- Egen side **Statistikk** i venstremenyen. Oppdatert hver sekund mens siden vises.
- Manuell start/stopp for **mottatt samtale** og **utgående samtale**; varighet fra lokal start-/sluttid.
- Merk en pågående **mottatt** samtale som **satt videre**; oppsummering etter at samtalen avsluttes.
- Egen start/stopp for **skriftlig tid**, også samtidig som man ringer ut.
- Dagsoversikt: mottatte/utgående, overførte, total samtaletid, gjennomsnittlig mottatt samtaletid, skriftlig tid, siste 4 registreringer.
- Fullførte økter til `%APPDATA%\QuickerKeys\Statistikk\YYYY-MM-DD.csv`; pågående økter i samme mappes `Aktiv.ini`.
- Innholder **ikke** kundens navn, telefonnummer, brukernavn, IM-nummer eller saksbeskrivelse. Dette er likevel personlige aktivitetsdata dersom de knyttes til en ansatt, og må behandles i tråd med interne retningslinjer.

## Viktige avgrensninger
- Denne første versjonen teller **bare manuelle** registreringer. Verken SM Kontakt eller UIA gir foreløpig et verifisert signal for besvart/avsluttet/overført samtale.
- Varighet er tiden mellom knappetrykk, **ikke** attestert samtaletid fra Trio.
- En aktiv økt som aldri avsluttes, teller ikke i fullført statistikk. Bruk «Forkast pågående økter» ved feiltelling.
- Økter som krysser midnatt bokføres på datoen de avsluttes. Skriftlig tid og utgående samtale kan overlappe, så tidsmålene må ikke summeres som unike arbeidstimer.
- Ved Reload/omstart lastes aktive økter fra `Aktiv.ini`; avslutt eller forkast dem manuelt.
- Ingen automatisk rapportering til arbeidsgiver, nettverkskall eller skjult personregistrering.

## Windows-test før merge
- [ ] Åpne QuickerKeys og Statistikk-siden; sjekk at ingen feil logges ved oppstart.
- [ ] Start mottatt samtale, vent 10 sek, merk som satt videre og avslutt: mottatt=1, videre=1, varighet omtrent 10 sek.
- [ ] Start mottatt samtale på nytt, forsøk å starte ring-ut samtidig: avvises uten dobbeltregistrering.
- [ ] Start ring-ut, avslutt: ring-ut=1; kontrollér snitt mottatt og samlet samtaletid.
- [ ] Start skriftlig tid, start og avslutt en utgående samtale, stopp skriftlig tid; kontrollér begge tall og at overlapp er tillatt.
- [ ] Start aktiv økt og trykk Last inn på nytt: samme pågående økt skal gjenopprettes.
- [ ] Forkast en pågående økt: den må ikke øke dagstellerne.
- [ ] Sjekk CSV-format, æ/ø/å-UI, sortering og at det ikke lagres sensitivt innhold.
- [ ] Test kryssing av midnatt og at økten bokføres på sluttdato.
- [ ] Verifiser at SM Kontakt med UIA, Trio Snarveier, Tekstflyt, Vindusbytter og MAC Import fungerer uendret.

## Neste fase: Trio-telemetri
1. Kartlegg Trio Web/Attendant med **anonymiserte** UIA-tilstandsutdrag for `Ringing`, `Connected`, `Ended`, `Transferred`.
2. Bruk en eksplisitt tilstandsmaskin og stabil samtale-ID før auto-logging. Start ved bekreftet svar, avslutt ved bekreftet slutt.
3. Koble manuell og automatisk hendelse med deduplisering; aldri anta at kontaktfelt-utfylling = besvart anrop.
4. Test med syntetiske scenarier og velg opt-in for automatisk logging.

## Avklaring med Trio-ansvarlig
Enghouse Trio har egne statistikk-/rapporteringsfunksjoner. Produktdokumentasjon for Trio 9.3 beskriver også en valgfri, lisensiert modul **Enterprise Call Data Export** (P005110) som eksporterer Agent/Attendant-data med blant annet samtalestart, svar og viderekobling. Avklar først hvilken Trio-versjon og rapport-/eksporttilgang organisasjonen har. En godkjent eksport kan gi mer presise tall enn polling av UIA.

## v3.12-rc2: Trio Oppgavelogg – skrivebeskyttet diagnostikk

**Standardoppsett:** `TrioAutoApne=1`, `TrioAutoMinimer=1`, `TrioIntervallSek=30`, `TrioVisFeil=1` i seksjon `[Statistikk]`.

**Sikkerhetsgrenser:** Ingen automatisk oppgaveimport, ingen lagring av radtekst eller UIA Value. Det er ikke bevist at Oppgavelogg kan leses minimert. Den gjenkjennes kun i **samme PID som Trio Attendant** med vindustittel som inneholder `Oppgavelogg`. Hvis Trio bruker en annen prosess eller ikke-standard menylinje, rapporteres dette som en begrensning, ikke omgås med tastetrykk.

**Fokus:** Ved ny åpning brukes `MenuSelect` direkte mot Trio bare når Trio er aktivt og mus/tastatur har vært i ro i minst 4 sekunder. `WinActivate`, `Send`, `Click` og gjenoppretting av andres vinduer er bevisst utelatt. Trio kan selv vise et kort vindusglimt. Bare et *nyopprettet* loggvindu minimeres. Ved mislykket åpning gjøres bare ett automatisk forsøk for samme Trio-prosess; etterpå må brukeren åpne loggen manuelt eller starte QuickerKeys på nytt.

### Test i Trio Attendant 10.1.35
- [ ] Start med Trio lukket: ingen åpning eller fokusbytte, «Trio er ikke startet» i status.
- [ ] Åpne Trio, la det være aktivt og la tastatur/mus være i ro i minst fire sekunder, til neste 30-sekunders kontroll. Oppgavelogg bør åpnes **én** gang og minimeres.
- [ ] Test samtidig arbeid i SM eller annet vindu: QuickerKeys skal **ikke** hente Trio frem eller åpne nytt Oppgavelogg-vindu mens brukeren arbeider.
- [ ] Hvis Oppgavelogg er åpnet manuelt, skal QuickerKeys **ikke** minimere eller flytte det.
- [ ] Test ikke-standard Vis-meny eller ukjent loggvindutittel: feilstatus vises, ingen gjentatte åpninger for samme Trio-PID.
- [ ] Trykk «Trio Oppgavelogg / UIA…» → «Kjør UIA-test nå». Bekreft at rapporten bare inneholder struktur og kjente kolonneoverskrifter, ikke samtale- eller kundeinnhold.
- [ ] Sammenlign diagnose med Oppgavelogg åpen normalt, deretter minimert. Noter DataGrid/Table/List-tilgang, radtypeforekomster og tidsforbruk. **Ikke anta fullstendig radinnhenting** ut fra et ikke-null antall.
- [ ] Hvis minimert vindu returnerer 0 tabeller eller rader: vis tydelig status, ikke restore eller scroll automatisk.
- [ ] «Kopier diagnose» gir bare aggregerte felter og sikker tekst. Kontroller manuelt at person-, telefon-, kundenummer og IM ikke finnes.
- [ ] Endre intervall 15 → 30 → 60 og feilstatus på/av, lagre og restart; innstillingene må beholdes.
- [ ] Legg inn ugyldig `TrioIntervallSek=abc` i INI: ingen oppstartskrasj; fallback skal være 30.
- [ ] Test at SM Kontakt, Trio Snarveier, Tekstflyt, Vindusbytter og MAC Import fungerer uendret mens diagnosetimeren er aktiv.
- [ ] Feilsøk UIA-treghet / vinduer med mange oppgaver; automatisk skanning er begrenset til 140 kontrollnoder.

### Akseptkriterier før automatisk import
1. Bekreftet UIA-struktur både i normal og minimert tilstand, eller dokumentert fallback til rapport/eksport.
2. Bekreftet at radene inneholder **oppgave-ID, tidspunkt, behandlingstid, køtid, tjeneste, Koblet og Kommentar** som egne lesbare felter.
3. Bekreftet semantikk for telefonsymbol/retning og at `Koblet` betyr faktisk viderekobling.
4. Deduplisering på oppgave-ID og oppdatering ved endret Koblet/Kommentar – **først da** automatisk beregning av statistikk.
5. Godkjent lokal dataminimering og personvern – ikke logg rå telefonnumre eller IM-kommentarer i det offentlige repoet.

## RC3 – feilretting etter test i Trio 10.1.35
**Rapportert feil fra RC2:** `Feil under UIA-diagnose (ingen data importert).` Automatisk åpning skjedde ikke etter fire sekunders inaktivitet, og «Kjør UIA-test nå» ga ingen diagnostisk informasjon.

**Rettet i RC3:**
- Autoåpning er skilt fra strukturdiagnostikken: lett vindussjekk hvert **2,5 sekund** når Trio er aktivt, åpner først når fysisk inaktivitet har vart minst **4 sekunder**. UIA-kartlegging beholdes på 30-sekunders intervall. Det er ikke et løfte om åpning nøyaktig 4 sekunder etter oppstart.
- Trio-hovedvinduet gjenkjennes via tidligere konfigurert vindu eller en entydig kandidat med Trio/Attendant i tittel/prosessnavn. Oppgavelogg kan være i samme PID eller en annen prosess med samme .exe-fil.
- Manuell «Kjør UIA-test nå» leser **et allerede åpent** vindu uavhengig av om QuickerKeys eller Trio har fokus. Den åpner ikke Oppgavelogg.
- Feilrapporten viser **feilsteg, AHK-feiltype, kort feilmelding og linjenummer** uten rå UIA-verdier, kundenummer, telefonnummer eller IM-tekst.
- COM-failures fra `ElementFromHandle` og `ControlViewWalker` returnerer nå en lesbar teknisk feilmelding.

**Retestprosedyre uten skjermbilder:**
1. Start RC3 på Windows og åpne Trio Attendant 10.1.35.
2. **Manuell kontroll først:** Velg Trio → Vis → Oppgavelogg. La vinduet være åpent. Gå tilbake til QuickerKeys → Statistikk → Trio Oppgavelogg / UIA → Kjør UIA-test nå → Kopier diagnose. Kontroller at resultatet nå sier hva som feiler (eventuelt viser DataGrid/Table/List-tall).
3. Minimer Oppgavelogg manuelt og kjør samme UIA-test. Sammenlign resultater.
4. **Autoåpning etterpå:** Lukk Oppgavelogg. Ha Trio-hovedvinduet i forgrunnen, la tastatur/mus være i ro minst 4 sekunder, og kontroller om loggen åpnes/minimeres innen neste 2,5-sekunders sjekk.
5. Hvis autoåpning ikke fungerer, kopier diagnose og kontroller melding `menyfeil`, `ikke-funnet`, `Finn Trio` eller `Finn Oppgavelogg`; ikke slå på fokusbyttende tastetrykk som reserve.
6. Verifiser at SM Kontakt ikke påvirkes når UIA-diagnosen kjører.

## RC4 – Feilretting og trygg sletting (etter brukerens RC3-test)

**Bekreftet i Trio 10.1.35:** Automatisk åpning og minimering fungerer når Trio er aktivt. UIA finner `List: 1`, `DataItem/ListItem: 68` og `8 av 12` gjenkjente kolonneoverskrifter. Dette er **kontroller/elementer**, ikke bekreftet antall samtaler.

**Årsak til `MethodError: This value of type "Integer" has no method named "Call"`:** Lokal variabel `logg` i `TrioSjekk()` kolliderte med funksjonen `Logg()` (AHK-navn er ikke case-sensitive). Selv vellykket UIA-lesing kunne derfor gi feil etterpå ved statuslogging. RC4 kaller vindusvariabelen `loggHwnd` i stedet.

**Fokusfri automatisk åpning:** Sjekk hvert 2,5. sekund når Trio finnes og fysisk inaktivitet har vart minst fire sekunder, *uten* krav om `WinActive(Trio)` eller musepeker over Trio. `MenuSelect` kan adressere et standard Win32-menylinje-vindu uten å aktivere det, men fungerer ikke for alle egendefinerte menyer og kan feile når hovedvinduet er minimert. Kun et nyopprettet Oppgavelogg-vindu minimeres. Et kort vindusglimt fra Trio selv kan fortsatt forekomme.

**Søppelknapp:** Liten rød `🗑` til høyre for «Siste registreringer i dag». Klikk gir `YesNo Icon! Default2` med «Nei» som standard; «Ja» sletter kun `Statistikk/YYYY-MM-DD.csv` for dagens dato. Krever at ingen manuell samtale eller skriftlig tidsøkt pågår. Beholder tidligere datoer, `Aktiv.ini`, QuickerKeys-INI, logger og selve Trio Oppgavelogg.

### RC4 retester
- [ ] Åpne Trio, men arbeid i Service Manager eller et annet program. Hold mus/tastatur i ro minst 4 sekunder. Oppgavelogg åpnes/minimeres én gang, uten at du klikker på Trio.
- [ ] Kontroller at muspekerens posisjon er irrelevant.
- [ ] Test med Trio minimert: enten korrekt bakgrunnsåpning eller tydelig status, ingen uønsket fokusendring.
- [ ] Kjør manuell UIA-test med Oppgavelogg synlig, så minimert. Det skal ikke komme `Integer has no method named Call`.
- [ ] Åpne dagens Statistikk; klikk 🗑, velg **Nei**: CSV/tellere uendret.
- [ ] Klikk 🗑, velg **Ja**: dagens CSV fjernes og dagsoversikt nullstilles. Historiske filer og Trio er uendret.
- [ ] Start en manuell samtale eller skriftlig tid og klikk 🗑: sletting blir avvist til aktiv økt er avsluttet/forkastet.
- [ ] Test 🗑 uten eksisterende CSV: vis kort status, ingen filendring.
- [ ] Utfør regresjonstest på SM Kontakt, Trio Snarveier og Nettverk etter oppdateringen.

## RC5 – Bekreftet begrensning ved minimert Oppgavelogg (03.11.2026)

Brukertest av Trio Attendant 10.1.35:

| Tilstand | UIA-kontrollnoder (av maks 140) | List | DataItem/ListItem | Gjenkjente overskrifter |
| --- | ---: | ---: | ---: | ---: |
| Minimert | 9 | 0 | 0 | 0 |
| Åpent, ikke minimert | 140 | 1 | 68 | 8 |

**Konklusjon:** Minimering fjerner den lesbare UIA-listestrukturen i Trio 10.1.35. Det er ikke verifisert at 68 listeelementer tilsvarer 68 samtaler eller at alle historiske rader er tilgjengelige.

**RC5-endring:** Automatisk opprettet Oppgavelogg flyttes med AutoHotkey v2-funksjonen `WinMoveBottom` (nederst i Z-rekkefølgen) **uten å minimere**. Dette er ny standard `TrioBakgrunn=1` under `[Statistikk]`. Den gamle nøkkelen `TrioAutoMinimer` er avviklet; gamle INI-er bevares, men styrer ikke lenger vindushåndteringen. Velg ny checkbox «Legg Oppgavelogg bak andre vinduer (ikke minimer)» i Innstillinger. Autoåpning og 30-sekunders diagnoseintervall beholdes. Ingen nye oppgavedata importeres.

**Merknad:** `WinMoveBottom` påvirker vindusrekkefølgen, ikke aktivt vindu direkte. Trio kan likevel selv vise et vindu kort under `MenuSelect`, og eide/always-on-top-vinduer kan oppføre seg spesielt. Dette må funksjonstestes. Eget minimert loggvindu fra RC4 gjenopprettes **ikke automatisk**; bruker kan gjenopprette manuelt eller lukke det og la RC5 åpne nytt.

### RC5 QA
- [ ] Gjenopprett eksisterende Oppgavelogg manuelt eller lukk det før autoåpningstest. Kontroller at `TrioBakgrunn` er på.
- [ ] Med Trio åpent og Service Manager i forgrunnen: la tastatur/mus være i ro minst 4 sekunder. Verifiser at nytt Oppgavelogg legges bak andre vinduer, **ikke** minimeres.
- [ ] Kontroller at Service Manager forblir aktivt; noter eventuelt glimt/fokusbytte fra Trio.
- [ ] Vent én full 30-sekunders UIA-periode. Verifiser `List ≥ 1` og gjenkjente kolonner selv om Oppgavelogg ligger bak Service Manager.
- [ ] Gjenta med QuickerKeys-vinduet aktivt og Oppgavelogg bak, uten å gjenopprette loggen.
- [ ] Åpne Oppgavelogg manuelt før QuickerKeys starter; kontroller at eksisterende vindu **ikke** flyttes eller minimeres.
- [ ] Bekreft at knappen «Kjør UIA-test nå» fortsatt ikke leser celleverdier eller lagrer kunde/IM/oppgave-ID.
- [ ] Bekreft at rød søppelknapp med «Nei»/«Ja» fortsatt virker, og at SM Kontakt/Trio Snarveier ikke påvirkes.
- [ ] Hvis `WinMoveBottom` ikke skjuler loggen slik vi ønsker, ikke bytt til `WinHide` eller `WinSetTransparent` uten egen UIA-kompatibilitetstest.

**Neste fase:** Før automatisk telling må vi undersøke ListItem-innhold via godkjent, dataminimert parser (oppgave-ID, tidspunkt, behandlingstid, køtid, Koblet og tilstedeværelse av IM, uten å logge rå kundedata). Bekreft også listevirtualisering og duplikatkontroll.

## RC6 – Automatisk vinduslivssyklus uten pause-/gjenoppta-knapper

Brukeren ønsker at QuickerKeys alltid skal drifte Oppgavelogg i bakgrunnen, men uten å hindre manuell inspeksjon. RC6 legger ikke til noen GUI-knapper eller nye valg.

**Logikk:** 2,5-sekunders lett kontroll av vindustilstand, 30-sekunders separat skrivebeskyttet UIA-diagnose. Når Oppgavelogg er aktiv og bruker beveger mus/skriver, røres ikke vinduet. Når brukeren går videre (Alt+Tab/klikk på SM), sendes loggvinduet bakerst etter ca. 15 sekunder. Dersom Oppgavelogg står aktivt med 60 sekunders fysisk inaktivitet, sendes det også bakerst. Minimering håndteres med `ShowWindowAsync(SW_SHOWNOACTIVATE=4)` etter 15 sekunder, med 4 sekunders fysisk inaktivitet som ekstra vilkår. Dersom kjent loggvindu lukkes, venter QuickerKeys 30 sekunder før neste forsiktige autoåpning. En ny Trio-oppstart nullstiller vindusstatus. Feil ved restore/plassering begrenses til ett forsøk pr. 60 sekunder; etter vellykket flytting nullstilles sperren.

### RC6 QA i Windows/Trio 10.1.35
- [ ] Start Trio og RC6, med Oppgavelogg lukket. Etter minst fire sekunder uten input åpnes loggen automatisk og legges bak andre vinduer.
- [ ] Åpne Oppgavelogg manuelt og jobb aktivt i den i 2+ minutter. QuickerKeys må ikke flytte den mens mus/tastatur brukes.
- [ ] Bytt via Alt+Tab til Service Manager, og jobb videre. Etter ca. 15 sekunder må Oppgavelogg ligge bakerst uten minimering, uten at fokus tas fra SM.
- [ ] Ha Oppgavelogg aktiv uten fysisk input i minst 60 sekunder. Vurder om automatisk flytting er akseptabelt og ikke forstyrrer pågående lesing.
- [ ] Minimer Oppgavelogg manuelt; etter minst 15 sekunder og fire sekunder uten input skal den gjenopprettes uten aktivering og legges bakerst. Bekreft at UIA finner `List >= 1` ved neste intervall.
- [ ] Lukk Oppgavelogg manuelt. Ingen umiddelbar gjenåpning; etter minst 30 sekunder og fire sekunder uten input forsøkes ny åpning.
- [ ] Under manuell bruk: kjør UIA-diagnose med vinduet synlig og etter at det er lagt bak. Kontroller at ingen kundenummer/IM-tekst leses i rapporten.
- [ ] Valgfri nettverk/SM-regresjon: bruk SM Kontakt, Trio Snarveier, tekstflyt og rød søppelknapp; de skal fungere uendret.
- [ ] Feiltest: hvis Trio-vinduet ikke kan gjenopprettes, ikke gjør gjentatte raske forsøk; vis anonymisert status.

**Kjent risiko:** Det er ikke utført Windows-runtime-test av RC6. `SW_SHOWNOACTIVATE` er dokumentert for ikke å aktivere vinduet, men applikasjonen selv kan reagere på Windows-hendelsen. Kontrollér faktisk fokusoppførsel før merge.

## RC7 – Verifiser Trio-radstruktur fra dagens Oppgavelogg

**Bakgrunn:** Brukeren har bekreftet at oppgaveloggen kan stå åpen bak andre vinduer med UIA-tilgang. Tidligere diagnostikk viste `List: 1`, 68 ListItem/DataItem-elementer og åtte gjenkjente kolonneoverskrifter. Det **beviser ikke** at alle 68 er samtaler.

**Implementert:** En ny «Visualiseringer»-knapp i Statistikk åpner et separat GUI med fire nøkkeltall og horisontale timegrafer hentet utelukkende fra lokale **manuelle** CSV-hendelser. Nederst finnes «Test Trio-rader (uten lagring)» og «Kopier testresultat». Ingen rå data legges i clipboard, programlogg, QA eller GitHub.

### Windows-test med faktiske Trio-oppgaver
- [ ] Åpne QuickerKeys RC7 og sjekk at Visualiseringer åpner uten AHK-feil. Dersom ingen manuelle registreringer finnes, skal dashboardet vise 0 – ikke diktede Trio-tall.
- [ ] Registrer én manuell testsamtale; åpne Visualiseringer på nytt. Totaltall og timegraf for riktig klokkeslett skal øke med én. Slett dagens manuelle tester med eksisterende søppelknapp etterpå hvis ønskelig.
- [ ] Med Trio Oppgavelogg åpen i bakgrunnen og dagens faktiske oppgaver tilgjengelige: Visualiseringer → «Test Trio-rader (uten lagring)». Se etter «ListItem tilgjengelig», «Text-kontroller per rad», «Rader med 13 Text-felter», «Dato/tid i kolonne 1» og «Komplett validerte rader». Testen undersøker maks 12 elementer.
- [ ] Kopier den anonymiserte rapporten og kontroller selv at ingen rå telefonnummer, kundenummer, IM-nummer, oppgave-ID eller kommentar følger med før den deles.
- [ ] Test på nytt med Oppgavelogg manuelt minimert. Den skal avvise lesing fremfor å aktivere vinduet.
- [ ] Dersom Text-kontrollene ikke er nøyaktig 13, skal testen melde «Radformat er ennå ikke verifisert», ikke telle noe som samtale eller endre dagens CSV.
- [ ] Med mange historiske oppgaver, sammenlign tilgjengelige ListItem-tall med synlige rader. Eventuell virtualisering må håndteres separat etter godkjenning.
- [ ] Bekreft at 30-sekunders UIA-status, automatisk vindushåndtering, SM Kontakt og manuelt CSV-oppsett fungerer uendret.

### Begrensninger
1. UIA-prøven kan se rå tekst i minne under validering, men eksporterer kun formatstatistikk og gjenkjenningsantall.
2. 12 rader er bare et begrenset utvalg; ikke bruk dette som faktisk dagsstatistikk.
3. Ikke ta i bruk automatisk registrering, IM-telling, overføringsklassifisering eller diagrammer basert på Trio før kolonneindekser og oppgave-ID-deduplisering er validert.
4. Ingen Windows-runtime-test er utført av utviklingsmiljøet; RC7 må prøves i faktisk Trio 10.1.35.

## RC8 – Automatisk innlesing og frivillig «Oppdater nå»

Brukeren ønsker ingen manuell registrering av telefoner når Trio allerede har loggen. RC8 bruker 30-sekunders syklusen til å forsøke å parse dagens oppgaver fra de tilgjengelige radene, med samme funksjon bak den frivillige **Oppdater nå**-knappen i Visualiseringer.

### Test med dagens oppgavelogg i Trio 10.1.35
- [ ] Start RC8 med Trio Oppgavelogg åpen i bakgrunnen. Vent én 30-sekunders synkronisering og åpne **Statistikk → Visualiseringer** uten å trykke noen oppdateringsknapp.
- [ ] Kontroller at dashboardet viser **Trio** som kilde. Hvis ingen rader kan valideres, vises «—» og en forklaring, ikke manuelle eller hypotetiske tall.
- [ ] Trykk **Oppdater nå** én gang for å teste umiddelbar lesing. Samme parser og samme dagsbuffer brukes som ved automatisk synkronisering.
- [ ] Kopier eksisterende UIA-diagnose og inspiser den anonymiserte innlesingsstatusen: antall tilgjengelige kandidatrader og unike observerte oppgaver. Del aldri rå klient- eller IM-informasjon.
- [ ] Sammenlign et utvalg av dagens manuelt synlige Trio-oppgaver med dashboardet: riktig dato, tidspunkt, behandlingstid og tegn på Koblet/IM.
- [ ] Test samme oppgavelogg flere ganger. Antall skal ikke øke bare fordi de samme oppgave-ID-ene blir lest igjen (deduplisering på ID + tidspunkt).
- [ ] Legg til/oppdater en reell oppgave i Trio. Innen neste synkronisering skal ny eller endret oppgave gi oppdaterte foreløpige tall dersom raden er lesbar via UIA.
- [ ] Kontroller at oppgaver fra i går ikke teller på dagens dashboard, og at dagsbufferen nullstilles ved datobytte.
- [ ] Test med Oppgavelogg minimert: eksisterende foreløpige totaler beholdes i RAM, men ingen nye rader kan innleses; status skal ikke hevde fullstendig dekning.
- [ ] Verifiser at ingen rå telefonnumre, kundenummer, oppgave-ID-er eller IM-strenger havner i QuickerKeys-logg, kopi-rapport eller dagens manuelle CSV.
- [ ] Bekreft at automatisk flytting av Oppgavelogg og SM Kontakt fortsatt fungerer.

**Begrensninger og akseptkriterier:**
1. UIA-kildestrukturen kan være ListItem-per-celle, ListItem-per-rad eller en virtualisert tilpasset liste. Bare eksakte 13-kolonners kandidater som valideres tolkes. Manglende tall betyr at parseren ennå ikke passer klienten, ikke at det ikke finnes oppgaver.
2. Antall er observerte validerte **oppgaver**, ikke dokumentert antall mottatte/besvarte samtaler (telefonsymbolets retning er ikke dekodet).
3. En aktiv dagsbuffer i RAM dedupliserer innen samme QuickerKeys-økt; den lagres ikke på disk og kan derfor ikke garantere komplett dagshistorikk etter restart hvis Trio virtualiserer eldre rader.
4. Før produksjonsmerking må dashboardet sammenholdes med en fullstendig, autorisert Trio-statistikkrapport eller et manuelt bekreftet antall.
5. RC8 er ikke kjørt i Windows under utviklingen; bekreft både parser og GUI før PR-merging.
