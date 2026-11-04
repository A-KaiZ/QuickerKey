# Trio vindusfangst P0.1

Et selvstendig forsøk på å hente et bilde av Trio Oppgavelogg gjennom Windows `PrintWindow`. Dette er første trinn i [OCR-utkastet](https://github.com/A-KaiZ/QuickerKey/blob/feature/statistikk-v3.12/docs/Trio-OCR-utkast-v3.12.md), før OCR og statistikkimport kobles på. QuickerKeys-appen endres ikke av at verktøyet kjøres.

## Kjørbar prøve

Windows x64 med .NET Framework 4.8. Last ned CI-artefakten **TrioCaptureProbe-P0-Windows-x64** fra den grønne kjøringen av «Trio capture probe (Windows)», pakk ut ZIP-filen og start `TrioCaptureProbe.exe` med vanlige brukerrettigheter. Artefakten inneholder hele kildekoden og SHA-256 for EXE-filen.

Verktøyet søker etter ett synlig Oppgavelogg-vindu fra en prosess med Trio/Attendant i navnet og nøyaktig én native/Windows Forms ListView. Ved null eller flere kandidater starter det ingen fangst. Dersom din klient ikke blir gjenkjent, er det et separat funn; verktøyet lar ikke et vilkårlig vindu velges som reserve.

## Tre prøver i faktisk Trio

1. Åpne Trio Oppgavelogg uten minimering. Start prøveverktøyet og trykk **Finn Oppgavelogg**.
2. Trykk **1 · Synlig logg (5 s)**. Bruk nedtellingen til å la loggens tabellområde være synlig. Gå tilbake til prøveverktøyet etter fangsten. Se at dato/tid, ID og tidskolonnene faktisk er lesbare i bildet, og kryss av bekreftelsen nederst. Forhåndsvisningen er i original størrelse og kan rulles i prøveverktøyet; dette ruller ikke Trio-listen.
3. Trykk **2 · Dekket logg (5 s)**. Dekk hele Oppgavelogg med et annet vindu før nedtellingen er ferdig. Ikke minimer den. Gå tilbake til prøveverktøyet etter fangsten og kontroller tekstinnholdet på samme måte.
4. Når en ny oppgave faktisk er dukket opp i loggen, trykk **3 · Etter ny oppgave (5 s)** og dekk loggen igjen. Kontroller at den nye oppgaven finnes i det innhentede bildet. Kryss av både lesbarhet og at den nye oppgaven er synlig. Uten en faktisk ny oppgave er ferskhet fortsatt uavklart.
5. Trykk **Kopier anonym diagnose**. Denne teksten kan deles i PR/chat. Den inneholder bare prøveutfall, størrelser, antall, varighet og bekreftelser. Bildet inngår ikke.

Det trengs ikke flere like RC14 UIA-diagnoser for denne prøven. Det avgjørende er om prøve 2 gir lesbar tekst og prøve 3 viser den nye oppgaven. Like bilder når loggen ikke har endret seg er normalt. Et endret bilde alene beviser heller ikke ny oppgave; fokusmarkeringer kan endre piksler.

Verktøyet tar ingen skjermbilder automatisk hvert 30. sekund. Hver knapp starter én fangst etter fem sekunder. **Avbryt** stopper nedtellingen eller worker-ventingen. Lukking av verktøyet avbryter en pågående prøve. Det aktiverer, gjenoppretter, ruller eller flytter ikke Oppgavelogg.

## Hva resultatene betyr

| Utfall | Betydning |
| --- | --- |
| Image | En komplett bildeflate ble mottatt. Det er ikke en automatisk bekreftelse på lesbar tabelltekst. |
| Bildevariasjon: ja | Flere grove fargeverdier finnes. Dette beviser verken tekst eller riktig innhold. Lesbarhet vurderes i forhåndsvisningen. |
| Bildevariasjon: nei | Bildet kan være tomt/ensartet. Det klassifiseres ikke som vellykket tekstlesing. |
| TargetChanged | HWND, prosessidentitet, tittel eller listestruktur passer ikke lenger. Finn vinduet på nytt. |
| Minimized | Vinduet er minimert og ble hoppet over uten gjenoppretting. |
| SessionUnavailable | Aktiv, tilgjengelig skrivebordsøkt kunne ikke bekreftes. Ingen fangst brukes. |
| LayoutChanged | Vindusgeometri, rad-/kolonneantall eller øverste rad endret seg under prøven. Bildet forkastes. |
| NativeFailure | Windows-fangsten mislyktes. Ingen reservefangst av skrivebordet utføres. |
| Timeout / Cancelled | Worker-ventingen ble avbrutt, og workeren avsluttes. Ingen gamle bilder brukes som nytt resultat. |
| ProtocolError / InternalError / InvalidSize | Svaret kunne ikke brukes. Bare feilkategori og eventuelt et numerisk Windows-feilnummer rapporteres. |

Fokusindikatoren sammenligner forgrunnsvindu før og etter fangsten. Utvalgsindikatoren sammenligner antall og første valgte rad; den beviser ikke identiteten til alle elementer i et flervalg. Endring kan også skyldes brukerhandling under prøven. Verktøyet sender ingen kommandoer for å endre disse tilstandene.

## Avgrensninger og databehandling

- Hele mål-vinduet fanges til et bitmap i RAM, inkludert eventuelle kundeopplysninger som vises der. Programmet skriver ingen bilder, celleverdier, bildesignaturer eller rå unntak til disk, app-logg eller utklippstavle. Det bruker ingen nettverkstjeneste.
- Bare ett bilde vises om gangen. Bildet og rå buffer frigjøres når neste prøve begynner eller verktøyet lukkes. Dette er vanlig prosessminne, ikke en garanti mot Windows sin ordinære minnehåndtering, sideveksling eller systemdumpermiljø.
- PrintWindow kjører i en separat worker; forelderen har en 3,5-sekunders ventefrist og workeren en 5-sekunders egenfristsikring. Windows-forespørselen er synkron i målprogrammet. Det å drepe workeren garanterer ikke at alt arbeid i Trio avbrytes. **Hvis Trio blir tregt eller henger under prøven, avslutt PrintWindow-sporet og rapporter det.**
- Bakgrunnsfangst, ferskhet og lesbarhet i faktisk Trio er fortsatt uavklart til denne prøven er gjennomført. Suksess mot testkontroller er ikke bevis på Trio-støtte.
- Verktøyet leser bare det vinduet kan tegne i aktuell visning. Ingen rader utenfor visningen hentes, og ingen oppgaver telles. WGC, OCR, automatisk innlesing og historikkjobb er senere trinn.
- Eksisterende QuickerKeys kan fortsette sin normale vindusbetjening. For en entydig prøve bør Oppgavelogg være åpen og ikke i ferd med å endre størrelse eller scrolles mens fangsten foregår.

## Bygg og syntetiske tester

Fra repoet på Windows x64:

```powershell
./tools/trio-capture/build.ps1 -OutputDirectory "$env:TEMP/TrioCaptureProbe"
./tests/trio-capture/run-tests.ps1 -Probe "$env:TEMP/TrioCaptureProbe/TrioCaptureProbe.exe"
```

Bygget bruker Windows sin .NET Framework-kompilator, uten NuGet-pakker eller runtime-nedlasting. CI bygger den samme EXE-filen og prøver separate 32-/64-bits Windows Forms-mål: faktisk ListView, privat tegnet innhold, full dekking med annen farge, endret privat innhold bak dekking, feil/gammel prosessidentitet, minimering, lukket vindu, tomt vellykket svar, heng, avbrudd og ugyldige/trunkerte protokollsvar. Bare syntetiske data brukes. Ingen testbilder publiseres.

Primærkilder:

- [Microsoft: PrintWindow og synkron målbehandling](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-printwindow)
- [Microsoft: CreateDIBSection og bitmap i minne](https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-createdibsection)
- [Microsoft: OpenInputDesktop, inkludert frakoblet økt](https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-openinputdesktop)
- [Microsoft: WTSQuerySessionInformation](https://learn.microsoft.com/en-us/windows/win32/api/wtsapi32/nf-wtsapi32-wtsquerysessioninformationw)
