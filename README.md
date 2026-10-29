# QuickerKeys

AutoHotkey v2-verktøy for å forenkle arbeidsflyt mellom Trio og Service Manager.

## Verktøy
- **Tekstflyt:** Personlige tekstsnarveier lagret i Excel.
- **SM Kontakt:** Overføring av brukernavn/kundenummer fra Trio til Service Manager.
- **Vindusbytter:** Hurtigtaster for opptil fire vinduer, inkludert Edge-faner.

## Nytt i v3.0 (testversjon)
- **Innstillinger → Importer konfigurasjon…:** Importerer eksisterende QuickerKeys-/MAAUNI-INI, eller oversetter de to vindussnarveiene `HKAgentvindu` og `HkTjenestevindu` fra gamle QuickKey-filer til Vindusbytter. Andre gamle QuickKey-snarveier er **ikke implementert**, og vises i importdialogen som ikke støttet.
- **Innstillinger → Themes…:** Midnatt, Grafitt, Skog eller Lys. Programmet starter på nytt når tema velges.
- **Innstillinger → Last inn på nytt:** Leser INI-filen på nytt etter manuelle endringer i Notisblokk.
- **Edge-fanenavigasjon:** Prøver UI Automation TabItem for å finne riktig fane, med Ctrl+Tab som reserve. SM Kontakt kontrollerer aktiv fanetittel før innskriving.

### Konfigurasjon og sikkerhetskopi
Aktiv fil: `Innstillinger/QuickerKeys.ini`. Excel-filer ligger normalt under `Tekstflyt/`, og programlogger under `Logg/`. Importen lager en lokal `QuickerKeys-backup-*.ini` før den overskriver dagens oppsett. Den opprinnelige filen beholdes.

**Viktig:** `[Shortcuts]` / `[Enabled]` fra gamle QuickKey er **ikke** gyldige seksjoner for direkte aktivering av alle hurtigtaster i QuickerKeys. Bruk importdialogen. `[User] Username` brukes ikke av det nye programmet.

**Developers:** MAUUNI og KAISAD

> Prosjektet er under utvikling. Test v3.0 på en test-PC med syntetiske brukernavn før bruk mot reelle Trio/SM-arbeidsflater. Se [v3.0-testplanen](docs/QA-v3.0.md).
>
> Ikke legg brukernavn, pasientopplysninger, interne logger eller personlige konfigurasjonsfiler i det offentlige GitHub-repoet.
