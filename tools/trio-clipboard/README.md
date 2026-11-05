# Trio – anonym kopieringstest P0.1

Dette er en selvstendig AHK v2-prøve av et alternativ til optisk innlesing. Den starter ingen hjelpe-EXE, leser ikke vindusinnhold, sender ingen taster og endrer ikke sikkerhetsregler. Bruk den eksisterende administrerte AutoHotkey-løsningen; prøven gir ingen ny godkjenning.

1. Avslutt vanlig QuickerKeys fra ikonet ved klokka, slik at kontakt-/utklippsautomatisering ikke påvirker prøven.
2. Åpne `QuickerKeys-Kopieringstest.ahk` og trykk **Klargjør**.
3. Marker én rad i Trio Oppgavelogg og trykk **Ctrl+C**, eventuelt Trios egen kopierhandling dersom en slik finnes.
4. Gå tilbake og trykk **Analyser kopiering**, så **Kopier anonym diagnose**.

Prøven undersøker bare tekst som ble lagt på utklippet etter klargjøring. Den viser linje-/tab-feltantall og antall felt med visse tallmønstre. Den bekrefter ikke at kilden er Trio, at ni sifre er en oppgave-ID, eller at datoer/oppgaver er gyldige. Tomme tab-felt beholdes i tellingen. Det gamle utklippet tømmes ikke ved klargjøring; uendret utklipp leses ikke. Diagnosens kopiknapp erstatter utklippet med den anonyme rapporten.

Ingen bilder tas, og prøven skriver ingen filer, nettverksdata eller logger. Utklippsteksten behandles kortvarig i RAM. Windows' eksisterende innstillinger for utklippshistorikk/synkronisering endres ikke. Del bare den anonyme rapporten. Dette er én manuell kildetest; ingen løpende innsamling eller dashboardimport er implementert.

Hvis kopiering gir en strukturert rad, kan en egen adapter undersøkes videre. Hvis ingenting eller bare ett urelatert felt kopieres, er ikke denne kilden bevist. Det gjenstår også å avklare om en eventuell kopierfunksjon kan brukes uten å forstyrre brukerens fokus/utklipp; automatisk bakgrunnsinnlesing er ikke lovet av denne prøven.
