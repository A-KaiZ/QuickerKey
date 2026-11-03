# QA – QuickerKeys v3.11 (Nettverk + UIA)

> **Status:** Integrert i feature-branch. Kun statisk gjennomgang, **ingen Windows-/Trio-/Service Manager-/Cisco ISE-runtime-test**. PR skal være draft til manuell QA er gjennomført.

## Nettverk / MAC Import
- [ ] Ny installasjon: Nettverk er skjult, ingen uventede endringer i gamle moduler.
- [ ] Innstillinger → **Nettverksgeni?**: animasjon, omstart, Nettverk vises nederst til venstre.
- [ ] Nettverk → MAC Import og ← Nettverk: menymarkering og skjuling av andre paneler.
- [ ] Deaktiver Nettverk og restart: Nettverk forsvinner, data og snarveier beholdes.
- [ ] Test med `aa:bb:cc:dd:ee:ff`, `AA-BB-CC-DD-EE-FF`, `AABBCCDDEEFF`, flere sammenhengende 12-hex-MAC-er.
- [ ] Bland gyldige, ugyldige og dubletter: antall, rød feilstatus og avvisning.
- [ ] Test skilletegn : og -; se at bare MAC-innhold formateres.
- [ ] Tom Identity Group avvises. Komma, sitattegn og linjeskift avvises.
- [ ] Bekreftelsesdialog: korrekt gruppe, antall MAC-er; Nei skal ikke opprette fil.
- [ ] CSV: nøyaktig **31 kolonner**, komma, én MAC per rad, kun MACAddress og IdentityGroup utfylt, UTF-8 uten BOM.
- [ ] Test fil i Cisco ISE import-forhåndsvisning mot lokal godkjent `Ren_mal.csv`; **ikke importer i produksjon** før formatet er verifisert.
- [ ] Test ved 100 %, 125 %, 150 % Windows-skalering, alle temaer.

## SM Kontakt – UIA
- [ ] Test innlæring av riktig Service Manager 02-fane, ikke annen Edge-fane.
- [ ] Under læring: gjenkjenn tekstfelt / combobox via ControlType + Name eller AutomationId.
- [ ] Ukjent eller ikke-unikt felt → avbryt, ikke gjett koordinater.
- [ ] UIA-felt flyttes etter nettleserzoom og endret vindusstørrelse: finn riktig felt på nytt.
- [ ] Eldre konfig uten UIA-signatur: eksisterende sikre klikkkoordinater fungerer fortsatt.
- [ ] Feltinnfylling: Kontakt + **Tab + Enter**, med riktig sak/fane og uten annet overliggende vindu.
- [ ] Verifiser manuelt at SM faktisk aksepterer verdien. Logg sier at taster er sendt, ikke at saken er lagret.
- [ ] Test Trio Web og Trio Attendant, enkel/dobbel kopiering, 2. linje, IM og telefonnummer uten at det blir brukernavn.

## Trio Snarveier – IM Search
- [ ] «Lær oppsett» i bekreftet SM-fane lagrer UIA-feltsignatur, ikke bare skjermkoordinater.
- [ ] Search lukket → vent høyst 30 sekunder; ingen innskriving i annen fane.
- [ ] Search åpnet → IM-nummer søkes; ingen påstand om at IM-saken faktisk er ferdig åpnet.
- [ ] Endre vindusstørrelse/zoom og prøv igjen; UIA-søk følger feltet.
- [ ] Gammel konfig uten UIA-feltmodus: trygg koordinatfallback, aldri blind skriving.
- [ ] Konflikt mellom SM Kontakts og IM Search sin læring av museklikk.
- [ ] Avbryt/stoppe verktøy mens et IM-søk venter.
- [ ] Trio: kopi av Kommentar / A-nr og korrekt gjenoppretting av innstillingen «Parameter».

## Regresjon
- [ ] Tekstflyt: Excel-lasting og hurtigtekster uendret.
- [ ] Vindusbytter: egne snarveier fungerer.
- [ ] Ingen utilsiktet deaktivering av andres hurtigtaster ved validering.
- [ ] Ctrl+Alt+M / tray / Oversikt / Logg / Innstillinger.
- [ ] Import av tidligere QuickKey/QuickerKeys-konfig og isolert datamappe.
- [ ] Ingen person- eller saksdata i offentlige feillogger, skjermbilder eller PR.

## Spesifikk portering
v3.11 er portert fra innlimt kildekode til eksisterende v3.8-baseline. Den forrige v3.8-sikringen for `GyldigHurtigtast()` beholdes med vilje: tastvalidering skal ikke deaktivere et allerede registrert hotkey.
