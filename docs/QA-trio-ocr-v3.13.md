# QuickerKeys 3.13 sandbox1 – Trio OCR P1

Grunnlag: offisiell 3.12.0, main-commit `021e335e4b1a8a66a188b5a1f2be4a04d2707cc0` (PR #13). Den ordinære utgaven er ikke endret av dette sandboxarbeidet. P0-koden fra PR #9 er videreført separat; eldre UIA-statistikk fra RC14 er ikke aktivert i denne pakken.

## Testbar leveranse

Pakk ut hele ZIP-filen og åpne **QuickerKeys.ahk** med den vanlige administrerte AutoHotkey v2-løsningen. Velg **Trio OCR-test → Åpne Trio OCR-test → Finn Oppgavelogg → Les utsnitt (5 s)**. Loggen må være åpen og ikke minimert. Knappen starter én avlesning; ingen automatisk polling eller scrolling inngår.

Sandboxen har egen datamappe, egen autostartsnarvei og automatisk profilimport er slått av. Avslutt vanlig QuickerKeys før prøven for å unngå overlappende hurtigtaster. Full kode, Tesseract-motor og veiledning følger pakken.

## Det som må bevises

| Område | Kontroll |
| --- | --- |
| Appgrunnlag | Hele AHK-filen skal parses, og eksisterende DIPS-/snarveiregresjoner skal bestå mot 3.12-grunnlaget med sandboxendringene. |
| Fangst P0 | Tidligere 44 kontroller mot 32-/64-bits testvinduer beholdes. Faktisk Trio-fangst er fortsatt ikke bekreftet av disse testene. |
| Motor | Tesseract 5.5.0 fra den offisielle release-asseten, installer-SHA256 `f3fc4236425b690c8be756f35793f77394ee004be0a6460a440c754d892f68bc`. Pakkes ut på byggmaskinen; installeres ikke hos brukeren. |
| P1-fasit | Syntetiske bilder med 100/125/150/200 % skala, flyttede kolonner, markert blå rad, rød tekst og eldre dato. Godkjente verdier må samsvare med fasiten; usikre verdier kan avvises. Ingen falskt godkjente rader tillates i dette prøvesettet. |
| Virkelig kontroll | Ekte Windows Forms ListView i både 32 og 64 bit: UIA henter bare overskrifter og radplassering, PrintWindow leverer bildet, og faktisk medfølgende Tesseract leser de fire feltene. |
| Cellekobling | Manglende felt låner aldri tekst fra neste rad. Grenser, overlapp, identitetskonflikter og lav konfidens må gi avvisning/ukjent. |
| Feltsemantikk | ID/tid bestemmer oppgaven. Manglende behandlingstid blir ukjent, faktisk 00:00 blir null. Historiske rader utelukkes før de andre kolonnene OCR-behandles. |
| Diagnose | Bare statuser, formatutfall, summer og antall. Ingen bilder, rå ID-/tidsstempelverdier eller kundedata i rapport/logg. |

## Faktisk Trio-QA

Gjenstår. Sammenlign synlig og dekket logg, lesbarhet og en ny oppgave. Kontroller telling og tidsverdier uavhengig mot loggen, og del bare anonym diagnose. Ved manglende resultat brukes **Test bildehenting** for P0-forhåndsbildet. Ikke minimer loggen.

P1-oppsummeringen gjelder ett bildeutsnitt. Den er verken bekreftet mot gjentatte fangster, dagens komplette total eller integrert i automatisk dashboard. «Koblet», Kommentar/IM og telefonikoner brukes ikke. Et grønt Windows-bygg erstatter ikke faktisk Trio-QA.

Se [full veiledning og avgrensninger](../tools/trio-ocr/README.md). PR skal forbli Draft; ingen merge til main før faktisk innlesing fungerer.
