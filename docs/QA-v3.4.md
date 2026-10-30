# QuickerKeys v3.4 – akseptansetest

> Status: kode oppdatert og statisk inspisert. Ikke kjørt i AutoHotkey v2 / Trio Attendant / Service Manager på Windows.

## Endringer fra v3.1-branch

- **v3.4** som visningsversjon.
- Trio Snarveier: ny `KopiModus` gjør at IM/telefon først forsøkes kopiert mens den transparente Trio-dialogen står åpen. Hvis kopiering ikke skjer, lukkes dialogen og kopiering forsøkes fra Trio-hovedvinduet. Vellykket fallback huskes som `lukket` for resten av programøkten.
- `ApneInnstillinger`, `VelgParameter`, `TrykkKopi`, `TilTrio`, `LukkMedOk` og `LukkInnstillinger` er innført. Parameteren forsøkes alltid gjenopprettet i `finally`.
- Kopivarsel og kopi-logg utføres direkte i Trio Snarveier. SM Kontakt ignorerer merkede IM-/telefonkopier.
- `SetWinDelay -1` og `SetControlDelay -1` i Trio-kopiflyten for lav ventetid.
- Eldre forbedringer fra v3.1-branchen er beholdt. Spesielt **ikke** bruk `Hotkey tast, TomHandling, "Off"` til validering: dette kan slå av en allerede registrert snarvei.

## Test på Windows / Trio Attendant – kun syntetiske data

- [ ] Start QuickerKeys uten syntaksfeil; ingen eksisterende moduler forsvinner.
- [ ] Kopier IM/Kommentar med Trio sitt innstillingsvindu skjult; kontroller kopiinnhold, toast/logg og at musepekeren ikke forflyttes.
- [ ] Kopier A-nr tilsvarende. Verifiser at kopiert telefonnummer **ikke** utløser innfylling i Service Manager.
- [ ] Test **begge kopimetoder**: en Trio-versjon hvor kopiering virker med dialogen åpen og en der den krever at dialogen lukkes. Bekreft at `KopiModus` husker lukket-varianten ved gjentatt bruk.
- [ ] Kontroller at dialogen ikke henger igjen, selv ved feil kopitast, tidsavbrudd, manglende Trio-vindu eller flere raske triggere.
- [ ] Kontroller at Hurtigkopiering → Parameter gjenopprettes (normal verdi eller IDM Username iht. implementasjonen) etter hver kopiering og ved feil.
- [ ] Se om kontrollklikk i usynlig dialog gir fokusendring/musepekereffekt; v3.4 bruker vanlig `ControlClick`, ikke `NA`-varianten fra v3.1.
- [ ] Test Trio → Vis → Agentvinduet/Tjenestevindu og Sett inn → Etterarbeid.
- [ ] Test hurtigkopiering av IDM Username og SM Kontakt med et testbrukernavn. Bekreft ingen dobbeltrigger og at feil nettleserfane ikke mottar tastetrykk.
- [ ] Test tekstutvidelse via Excel, redigering, konfliktkontroll og at enkelttegn snarveier er kontekstbegrenset til Trio.
- [ ] Test eksisterende INI og Excel etter restart; ikke bruk ekte pasient-/kundedata.

## Risiko / merknader

1. Ingen automatisk funksjonstest i arbeidssystemene er kjørt. Ikke merge uten å kontrollere Trio.
2. Den nye fallbacken kan sende en kopisnarvei mens dialogen er aktiv. Verifiser at dette ikke utløser andre handlinger.
3. Transparens gjør ikke nødvendigvis at `ControlClick` unngår fokus eller musepåvirkning. Sammenlign mot v3.1 i samme miljø.
4. Gjenoppretting av Parameter er *best-effort* og vil logge feil dersom Trio ikke tillater det.
5. Koden er **ikke** en byteidentisk kopi av den innlimte v3.4-filen; v3.4-kopiflyten er integrert oppå forrige featurebranch for å beholde eksisterende korrigeringer.
6. v3.4-PR-en inneholder de **umergete** v3.1-endringene og bør brukes **i stedet for** PR #4, ikke merges etter at PR #4 er merget uten ny diff-sjekk.
