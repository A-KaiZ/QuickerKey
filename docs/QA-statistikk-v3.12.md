# QuickerKeys Statistikk v3.12-rc1 — QA og avgrensninger

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
