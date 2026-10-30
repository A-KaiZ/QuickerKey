# QuickerKeys v3.6 – testplan og integrasjonsnotater

**Kilde:** Oppdateringen brukeren sendte som v3.6, integrert videre på `feature/v3.4-trio-copy-workflow`. Ingen egen v3.5-branch/PR ble funnet i GitHub-søket. **Ingen Windows-/Trio-funksjonstest er utført.**

## Nytt i v3.6

1. Kopitast leses automatisk fra `Hurtigkopiering` i Trios Innstillinger: prøver `msctls_hotkey32` via `HKM_GETHOTKEY`, ellers synlige Edit-felt med tekst som `Ctrl + |`.
2. `HKCopy` og `HKCopyKilde` lagres i INI. Ved mislykket lesing tilbyr UI **Velg tast…** som reserve; manuell tast kan overstyres ved senere vellykket Trio-lesing.
3. Tast-opptak støtter midtre-/sideknapper og Ctrl/Alt-kombinasjoner med venstre-/høyreklikk. Opptaks-hookene skal slås av etterpå.
4. Vindusbytter bruker samme opptak, men krever Ctrl/Alt for musknapper.
5. `TastTekst` viser menneskevennlige musknappnavn og `vkXX`-koder; `SendTast` oversetter enkelttegn til virtuelle tastkoder når mulig.
6. Panelkontroller kan vises betinget gjennom `VIS_VILKAR`.
7. **Beholdt fra v3.4:** gjennomsiktig Trio-dialog, fallback til hovedvinduet når kopiering med dialogen åpen feiler, automatisk gjenoppretting av Parameter, ignorering av merkede IM-/telefonkopier i SM Kontakt.
8. **Beholdt fra v3.1:** `GyldigHurtigtast` validerer uten å registrere/deaktivere eksisterende hotkeys. Dette er et bevisst avvik fra den innlimte v3.6-koden, som bruker `Hotkey tast, TomHandling, "Off"`.

## Akseptansetest – syntetiske data

- [ ] Oppstart i AutoHotkey **v2** uten syntaksfeil; tidligere INI og Excel fungerer.
- [ ] Test **Ctrl + |** og en funksjonstast i Trio → Hurtigkopiering. Bekreft at `HKCopyKilde=Trio` og at «Kopitast i Trio» viser riktig tast.
- [ ] Test fallback når Windows Hotkey-kontroll ikke finnes / Edit-felt ikke kan leses. «Velg tast…» skal vises, lagring av `HKCopyKilde=manuell` skal fungere.
- [ ] Test at ukjent/tom kopitast **ikke** sender en tilfeldig tast.
- [ ] Test IM-/telefonkopiering både med Innstillinger-vinduet åpent og lukket. `KopiModus=lukket` skal huskes når fallback virker.
- [ ] Etter hver kopiering og feil: Trio → Hurtigkopiering → Parameter er tilbake til forventet verdi, og dialogen er lukket.
- [ ] SM Kontakt skal ikke tolke IM eller telefon som et brukernavn / fylle inn feil Kontakt.
- [ ] Test opptak av `MButton`, `XButton1`, `XButton2`, `Ctrl+XButton1`, `Ctrl+LButton` og vanlig tegn. Prøv å skrive/klikke **utenfor Trio** for å bekrefte kontekst.
- [ ] Forsøk `LButton` og `RButton` uten Ctrl/Alt: opptak skal avbrytes i stedet for å overstyre vanlig klikking.
- [ ] Vindusbytter skal nekte musknapp alene, men godta Ctrl/Alt + musknapp.
- [ ] Test at opptak og validering ikke slår av QuickerKeys, SM Kontakt eller allerede registrerte snarveier.
- [ ] Test om musknapp-opptak påvirker brukerens klikk eller fokustilstand uventet.
- [ ] Regressjonstest Tekstflyt, vindusbytter, Trio-menyhandlinger og innlæring av Service Manager.

## Merknader

- Ingen test ble utført i Trio/Service Manager. Statisk kodesjekk er ikke det samme som kjøring.
- `GetKeyVK("|")` kan variere med norsk tastaturoppsett / AltGr. Test faktisk tegn/tast mot Trios egen hurtigkopiering.
- `ControlClick` i transparent dialog bruker ikke `NA`, og kan påvirke fokus. Observer dette i test.
- Ved mislykket gjenoppretting av Parameter logges feil. Kontroller parameteren manuelt ved slik feil.
- Logger kan inneholde kopierte brukernavn/IM/telefonnummer. Ikke del rålogger med reelle personopplysninger i GitHub.
- Denne v3.6-PR-en er ment å **erstatte PR #5** som mergevalg; den inkluderer alle umergede endringer fra v3.1 og v3.4.
