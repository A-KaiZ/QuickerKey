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
