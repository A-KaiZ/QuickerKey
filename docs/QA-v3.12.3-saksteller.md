# Saksteller og MAC Formater – QuickerKeys v3.12.3

## Formål
Oppdater QuickerKeys fra offisiell v3.12.0 og inkluder den manuelle sakstelleren og MAC Formater-funksjonen i egen PR. Endringen skal ikke hente Trio Oppgavelogg eller OCR automatisk.

## Saksteller
- Egen side **Saksteller** i venstre meny.
- **+1 løst**, **−1 Angre**, **+5 saker** og bekreftet **Nullstill i dag**.
- Dagens antall, siste 7 kalenderdager og total registrert beholdning.
- Per-dato lagring: `%AppData%\QuickerKeys\Innstillinger\Saksteller.ini`, seksjon `[Dager]`, nøkler i `YYYY-MM-DD`.
- Telleren er **manuell**, ikke basert på Trio, og lagrer ingen saksnumre, personnavn eller innhold.
- Hurtigvalg i systemstatusfeltet: `✓ Løst sak (+1)`.
- Dato byttes automatisk, også når programmet kjører over midnatt.

## MAC Formater
- Nettverk aktiveres fortsatt under Innstillinger → Avansert.
- Normaliserer MAC-adresser til `aabbcc112233` og viser liste, kopistatus og avkrysning.
- `Ctrl+Alt+N` kopierer neste ikke-avkryssede MAC-adresse.
- Ingen Cisco ISE-endringer utføres. MAC-listen er sesjonsbasert og slettes ved lukking.

## Testplan
1. Start scriptet med virksomhetens administrerte AutoHotkey v2-runtime.
2. Åpne Saksteller, trykk +1, +5 og −1, og sjekk 5.
3. Restart appen og sjekk at dagens tall er 5.
4. Trykk Nullstill i dag og bekreft; kontrollér 0 for i dag, andre dager beholdes.
5. Kjør Windows-testene via GitHub Actions og sjekk parser, DIPS, Trio-snarveier og tellertester.
6. Aktiver Nettverk og test MAC Formater: input med duplikater, ugyldige adresser, kopier neste, marker ferdig.
7. Test at `Ctrl+Alt+N` ikke forstyrrer egne snarveier.

## Viktig avgrensning
Brukerens innlimte kilde var v3.12.3, men repoets main var v3.12.0. PR-en porter den identifiserte MAC Formater-funksjonen og legger til sakstelleren. Det er ikke en byte-for-byte synkronisering av hele innlimte filen. Reviewer må derfor kontrollere øvrige forskjeller før release. Ikke bland denne PR-en med den eksperimentelle Trio OCR-draften.
