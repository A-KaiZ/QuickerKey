# QuickerKeys 3.8 – QA og merge-sjekkliste

Denne endringen bygger direkte på `main`, som allerede har v3.6. Ingen opprydding eller endringer fra v3.7 er antatt. Kilden er v3.8-koden delt av prosjektet. **Ingen Windows-/Trio-/Service Manager-kjøring er utført av assistenten.**

## Implementert

- Ekstra valg under **Trio Snarveier**: «Åpne IM-en i Service Manager», «Lær oppsett», «Test».
- Lærer et Search-inputfelt i en bekreftet Service Manager-fane, og lagrer `IMVindu`, `IMX`, `IMY`, `IMNavn`, `ApneIM`.
- Gjenbruker `KopierMedFelt("Kommentar")` og det eksisterende `Kjor`-løpet. Etter en gyldig kopiering og aktivt valg åpnes IM-nummeret via `Etter`, først **etter** opprinnelig fokus er gjenopprettet.
- Gjenkjenner IM-formatet `IM` + minst fire sifre og ignorerer tekst uten slikt nummer.
- Søker bare i verifisert Service Manager/Search. Hvis Search er lukket, varsles brukeren og det sjekkes hvert 500 ms i maks 30 sekunder.
- Test-dialog med manuelt skrevet IM-nummer.
- UIA-hjelpefunksjon `UiaTall` for kontrolltype `50004` (Edit).
- Ved avslag, deaktivering eller stopp: avbryter ventende IM-søk.
- SM Kontakt og IM Search kan ikke samtidig være i læringsmodus; IM Search bruker `~*LButton` i stedet for SM Kontakts `~LButton`.
- Beholder tidligere retting: `GyldigHurtigtast` oppretter **ikke** `Hotkey ... Off` for å validere snarveier.

## Test før merge

- [ ] Start med AutoHotkey v2 og bekreft ingen oppstarts-/kompileringsfeil.
- [ ] Åpne Trio Snarveier; bekreft at nye kontrollene passer innenfor GUI-panelet og at innstillingene beholdes ved omstart.
- [ ] «Lær oppsett»: klikk i korrekt Search-input i Service Manager. Test at vanlig Edge, Smart Search-ikon og andre ikke-Edit-elementer avvises.
- [ ] Test innlæring med åpent Search-felt, både maksimerte og vanlige vinduer.
- [ ] Kryss av/på «Åpne IM-en»; prøv slå på uten lært felt (skal avvises).
- [ ] Kopier testtekst `Kommentar: IM1234567` fra Trio med gyldig test-IM. Bekreft at Parameter gjenopprettes og IM-søket utføres i Service Manager etter kopieringen.
- [ ] Prøv tekst uten IM-nummer og telefonnummerkopiering: ingen IM-søk.
- [ ] Test med Search-panel lukket: bruker får beskjed, programmet skriver ingenting før du åpner Search i Service Manager innen 30 sekunder.
- [ ] La 30 sekunder løpe ut: ikke skriv i andre programmer, og ventende søk skal slettes.
- [ ] Slå av IM-valget eller Trio Snarveier mens søket venter: ventende søk skal avbrytes.
- [ ] Test med en annen Edge-fane aktiv (f.eks. eksempel.net): ingen feil skriving/Enter.
- [ ] Forsøk å lære IM samtidig som SM Kontakt er i læringsmodus og omvendt: ingen kolliderende muse-/Esc-hooks.
- [ ] Bruk «Test» med et gyldig testnummer, og med ugyldig tekst.
- [ ] Regressjon: Tekstflyt, Trio kopi IM/tlf, kopitast fra Hurtigkopiering, SM Kontakt, Vindusbytter, og eksisterende museknappsnarveier.

## Bevisste avvik fra innsendt 3.8

- Beholder ikke-mutativ hurtigtastvalidering fra tidligere PR, i stedet for `Hotkey tast, TomHandling, "Off"`.
- Unik muse-hook og gjensidig sperre mot samtidig læring for å unngå at SM Kontakt og IM Search overstyrer hverandres snarveier.
- Deaktivering/stopp nullstiller ventende IM-søk og et eventuelt etterarbeid.
- Ekstra kontroll av Search og aktiv Service Manager-fane umiddelbart før skriving og Enter.
- Ved suksess meldes **IM-søk startet**, ikke at sak faktisk ble åpnet; det bekreftes først av Service Manager.

**Merk:** Bruk test-IM og anonymiser eventuelle logger før deling. **PR-en merger ikke til `main` automatisk.**
