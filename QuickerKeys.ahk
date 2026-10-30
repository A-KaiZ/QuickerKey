#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent
SetTitleMatchMode 2
DetectHiddenText true
SendMode "Input"

; =====================================================================
;  QuickerKeys – alle verktøyene samlet i ett program
; ---------------------------------------------------------------------
;  • Bare start denne filen. Alt annet lages automatisk i undermapper:
;      Innstillinger\QuickerKeys.ini – innstillinger for alle verktøy
;      Tekstflyt\Tekstflyt.xlsx     – kodene til Tekstflyt
;      Logg\ÅÅÅÅ-MM-DD.log          – én loggfil per dag (30 dager tilbake)
;  • Alle verktøy kjører i bakgrunnen, også når vinduet er lukket.
;    Åpne igjen fra ikonet ved klokka eller med Ctrl+Alt+M.
;  • Nytt verktøy? Lag en klasse som «extends VT_Base» (se malen helt
;    nederst) og legg den til i VerktoyListe() rett under her.
; =====================================================================

VerktoyListe() => [
    VT_Tekstflyt(),
    VT_SMKontakt(),
    VT_TrioSnarveier(),
    VT_Vindusbytter()
]

OnError(FeilFanger)          ; feil havner i Logg i stedet for som feilvindu

global APP_NAVN    := "QuickerKeys"
global APP_VERSJON := "3.8"
global TEMA := {bg: "0F1E3A", kort: "16294D", nav: "0B1730", aksent: "2F7BEA", aksent2: "24497F", tekst: "E8EEF9", dempet: "8FA3C7", paa: "1FA97A", av: "56637D", linje: "1E3560"}
global DATA_MAPPE  := FinnDataMappe()                    ; programmets hovedmappe for data
global INNST_MAPPE := DATA_MAPPE "\Innstillinger"
global TEKST_MAPPE := DATA_MAPPE "\Tekstflyt"
global LOGG_MAPPE  := DATA_MAPPE "\Logg"
global INI_FIL     := INNST_MAPPE "\QuickerKeys.ini"
global HOVED := "", APP_B := 700, APP_H := 560, INNHOLD_X := 184, INNHOLD_B := 492
global PANELER := Map(), NAVKNAPPER := Map(), OVERSIKT := Map(), APP_KTRL := Map()
global VIS_VILKAR := Map()                   ; controls shown only when context needs them
global LOGG_LINJER := [], VERKTOY_LISTE := [], VIS_TAST := ""

; ---------------- Oppstart ----------------
global FLYTTET := LagMappestruktur()
SikreIni()
TEMA := TemaPalett(Innst("App", "Tema", "Midnatt"))
RyddGamleLogger()
lukketListe := LukkGamleSkript()
Hotstring("EndChars", " `n")                 ; bare Mellomrom og Enter utløser en tekstkode
VERKTOY_LISTE := VerktoyListe()
ByggHovedvindu()
ByggTrayMeny()
Logg(APP_NAVN " " APP_VERSJON " startet  –  mappe: " DATA_MAPPE)
for linje in FLYTTET
    Logg(linje)
for navn in lukketListe
    Logg("Lukket gammelt skript: " navn)
for vt in VERKTOY_LISTE
    SettAktiv(vt, Innst(vt.Id, "Aktiv", "1") = "1", false)
SettVisTast(Innst("App", "VisTast", "^!m"))
VisPanel("Oversikt")
if (Innst("App", "StartSkjult", "0") = "1")
    Logg("Startet skjult – åpne med ikonet ved klokka eller hurtigtasten")
else
    VisHoved()


; =====================================================================
;  RAMMEVERK – grunnklassen alle verktøy bygger på
; =====================================================================
class VT_Base {
    Navn := "Verktøy"
    Beskrivelse := ""
    Aktiv := false
    StatusTekst := ""
    StatusKtrl := ""
    PanelToggle := ""

    Id => RegExReplace(this.Navn, "[^A-Za-z0-9]", "")

    ; Lag kontrollene til verktøyets side. x/y = øverste venstre hjørne, b = bredde.
    ByggPanel(gui, x, y, b) {
    }
    Start() {
    }
    Stopp() {
    }

    ; Teksten som vises når man trykker «?» på verktøyets side
    Hjelp() => this.Beskrivelse

    Hent(nokkel, std := "") => IniRead(INI_FIL, this.Id, nokkel, std)
    Lagre(nokkel, verdi) => IniWrite(verdi, INI_FIL, this.Id, nokkel)
    Leg(ktrl) => Reg(this.Navn, ktrl)

    SettStatus(tekst) {
        this.StatusTekst := tekst
        try this.StatusKtrl.Text := tekst
        OppdaterOversikt(this)
    }
}


; =====================================================================
;  OPPSTART / FILER
; =====================================================================
FinnDataMappe() {
    ; Fast, isolert datamappe uavhengig av hvor QuickerKeys.ahk kjøres fra.
    ; Import fra gamle QuickKey skal aldri flytte programmets datamappe.
    mappe := A_AppData "\QuickerKeys"
    if !DirExist(mappe)
        DirCreate mappe
    return mappe
}

; Oppretter datamappene og importerer tidligere oppsett uten å slette originalfilene.
; Støtter både gammel flat struktur (v2.8) og undermapper (v2.9), også fra gammel AppData-mappe.
LagMappestruktur() {
    meldinger := []
    for mappe in [INNST_MAPPE, TEKST_MAPPE, LOGG_MAPPE] {
        if !DirExist(mappe)
            DirCreate mappe
    }

    gamleMapper := [DATA_MAPPE]
    if (StrLower(A_ScriptDir) != StrLower(DATA_MAPPE))
        gamleMapper.Push(A_ScriptDir)
    gammelAppData := A_AppData "\MAAUNI Verktoy"
    if (StrLower(gammelAppData) != StrLower(DATA_MAPPE) && DirExist(gammelAppData))
        gamleMapper.Push(gammelAppData)

    if !FileExist(INI_FIL) {
        for mappe in gamleMapper {
            for gammelIni in [mappe "\Innstillinger\QuickerKeys.ini", mappe "\QuickerKeys.ini"
                , mappe "\Innstillinger\MAAUNI.ini", mappe "\MAAUNI.ini"] {
                if !FileExist(gammelIni)
                    continue
                try {
                    FileCopy gammelIni, INI_FIL
                    meldinger.Push("Importerte tidligere innstillinger til QuickerKeys.ini")
                } catch as feil {
                    meldinger.Push("FEIL: kunne ikke kopiere innstillinger: " feil.Message)
                }
                if FileExist(INI_FIL)
                    break
            }
            if FileExist(INI_FIL)
                break
        }
    }

    nyXlsx := TEKST_MAPPE "\Tekstflyt.xlsx"
    if !FileExist(nyXlsx) {
        for mappe in gamleMapper {
            for gammelXlsx in [mappe "\Tekstflyt\Tekstflyt.xlsx", mappe "\Tekstflyt.xlsx"] {
                if (StrLower(gammelXlsx) = StrLower(nyXlsx) || !FileExist(gammelXlsx))
                    continue
                try {
                    FileCopy gammelXlsx, nyXlsx
                    meldinger.Push("Importerte tidligere Tekstflyt.xlsx")
                } catch as feil {
                    meldinger.Push("FEIL: kunne ikke kopiere Tekstflyt.xlsx: " feil.Message)
                }
                if FileExist(nyXlsx)
                    break
            }
            if FileExist(nyXlsx)
                break
        }
    }

    ; Oppdater kun den gamle standardstien; egendefinerte Excel-stier beholdes.
    if (FileExist(INI_FIL) && FileExist(nyXlsx)) {
        valgtFil := IniRead(INI_FIL, "Tekstflyt", "ExcelFil", "")
        for mappe in gamleMapper {
            if (StrLower(valgtFil) = StrLower(mappe "\Tekstflyt.xlsx")
                || StrLower(valgtFil) = StrLower(mappe "\Tekstflyt\Tekstflyt.xlsx")) {
                if (StrLower(valgtFil) != StrLower(nyXlsx)) {
                    try {
                        IniWrite nyXlsx, INI_FIL, "Tekstflyt", "ExcelFil"
                        meldinger.Push("Oppdaterte standardstien til Tekstflyt.xlsx")
                    } catch as feil {
                        meldinger.Push("FEIL: kunne ikke oppdatere Excel-stien: " feil.Message)
                    }
                }
                break
            }
        }
    }
    return meldinger
}

LoggFil() => LOGG_MAPPE "\" FormatTime(, "yyyy-MM-dd") ".log"

; Sletter loggfiler som er eldre enn 30 dager
RyddGamleLogger() {
    grense := DateAdd(A_Now, -30, "Days")
    loop files LOGG_MAPPE "\*.log" {
        if (A_LoopFileTimeModified < grense)
            try FileDelete A_LoopFileFullPath
    }
}

SikreIni() {
    if !FileExist(INI_FIL)
        FileOpen(INI_FIL, "w", "UTF-16").Close()     ; UTF-16 så æøå lagres riktig
}

Innst(seksjon, nokkel, std := "") => IniRead(INI_FIL, seksjon, nokkel, std)
SettInnst(seksjon, nokkel, verdi) => IniWrite(verdi, INI_FIL, seksjon, nokkel)

LukkGamleSkript() {
    lukket := []
    forrige := A_DetectHiddenWindows
    DetectHiddenWindows true
    try {
        for hwnd in WinGetList("ahk_class AutoHotkey") {
            if (hwnd = A_ScriptHwnd)
                continue
            try {
                tittel := WinGetTitle(hwnd)
            } catch {
                continue
            }
            if RegExMatch(tittel, "i)([^\\]*(Tekstflyt|SM[ _-]?Kontakt|Auto[ _-]?(å|a)pner|Vindu[ _-]?(bytter|åpner))[^\\]*\.(ahk|exe))", &treff) {
                try {
                    WinClose hwnd
                    lukket.Push(treff[1])
                }
            }
        }
    }
    DetectHiddenWindows forrige
    return lukket
}

FeilFanger(feil, modus) {
    static siste := ""
    melding := ""
    try melding := feil.Message
    try {
        if (feil.Extra != "")
            melding .= " – " feil.Extra
    }
    try melding .= "  (linje " feil.Line ")"
    if (melding != siste) {
        siste := melding
        try Logg("FEIL: " melding)
        try FileAppend "          " StrReplace(Trim(feil.Stack, "`r`n"), "`n", "`n          ") "`n", LoggFil(), "UTF-8"
    }
    return true
}


; =====================================================================
;  HOVEDVINDU
; =====================================================================
ByggHovedvindu() {
    global HOVED, APP_H
    antall := VERKTOY_LISTE.Length
    navValg := ["Oversikt"]
    for vt in VERKTOY_LISTE
        navValg.Push(vt.Navn)
    navValg.Push("Logg", "Innstillinger")
    APP_H := Max(560, 156 + antall * 96 + 24, 84 + navValg.Length * 44 + 40)

    HOVED := Gui("-MaximizeBox", APP_NAVN)
    HOVED.BackColor := TEMA.bg
    HOVED.MarginX := 0, HOVED.MarginY := 0
    HOVED.OnEvent("Close", HovedLukk)
    HOVED.OnEvent("Escape", (*) => HOVED.Hide())

    ; --- Topp ---
    Skrift(HOVED, "s16 bold c" TEMA.tekst)
    HOVED.AddText("x0 y0 w" (APP_B - 240) " h64 +0x200 Background" TEMA.kort, "   " APP_NAVN)
    Skrift(HOVED, "s9 norm c" TEMA.dempet)
    HOVED.AddText("x" (APP_B - 240) " y0 w240 h64 +0x200 Right Background" TEMA.kort
        , antall " verktøy  ·  v" APP_VERSJON "   ")

    ; --- Meny til venstre ---
    Skrift(HOVED, "s10 norm c" TEMA.tekst)
    HOVED.AddText("x0 y64 w160 h20 Background" TEMA.nav)
    for i, navn in navValg {
        knapp := HOVED.AddText("x0 y" (84 + (i - 1) * 44) " w160 h44 +0x200 Background" TEMA.nav, "    " navn)
        knapp.OnEvent("Click", VisPanel.Bind(navn))
        NAVKNAPPER[navn] := knapp
    }
    bunnY := 84 + navValg.Length * 44
    HOVED.AddText("x0 y" bunnY " w160 h" (APP_H - bunnY) " Background" TEMA.nav)

    ByggOversikt()
    for vt in VERKTOY_LISTE
        ByggVerktoyPanel(vt)
    ByggLoggPanel()
    ByggInnstillingerPanel()
}

ByggOversikt() {
    pn := "Oversikt", x := INNHOLD_X, b := INNHOLD_B
    PanelTittel(pn, "Oversikt")
    Skrift(HOVED, "s10 bold c" TEMA.tekst)
    Reg(pn, Knapp(HOVED, "x" (x+b-195) " y87 w195 h34", "Start QuickerKeys", StartQuickerKeys))
    for i, vt in VERKTOY_LISTE {
        y := 132 + (i - 1) * 96
        Skrift(HOVED, "s12 bold c" TEMA.tekst)
        navnK := Reg(pn, HOVED.AddText("x" x " y" y " w" (b - 240) " h26 Background" TEMA.bg, vt.Navn))
        navnK.OnEvent("Click", VisPanel.Bind(vt.Navn))
        Skrift(HOVED, "s9 norm c" TEMA.dempet)
        statusK := Reg(pn, HOVED.AddText("x" x " y" (y + 28) " w" (b - 240) " h56 Background" TEMA.bg, vt.Beskrivelse))
        Skrift(HOVED, "s10 bold c" TEMA.tekst)
        toggleK := Reg(pn, Knapp(HOVED, "x" (x + b - 226) " y" (y + 20) " w100 h34", "", VekslVerktoy.Bind(vt)))
        Skrift(HOVED, "s10 norm c" TEMA.tekst)
        Reg(pn, Knapp(HOVED, "x" (x + b - 116) " y" (y + 20) " w116 h34", "Åpne  →", VisPanel.Bind(vt.Navn), TEMA.aksent2))
        Reg(pn, HOVED.AddText("x" x " y" (y + 88) " w" b " h1 Background" TEMA.linje))
        OVERSIKT[vt.Id] := {status: statusK, toggle: toggleK}
    }
}

ByggVerktoyPanel(vt) {
    pn := vt.Navn, x := INNHOLD_X, b := INNHOLD_B
    PanelTittel(pn, vt.Navn, true)
    Skrift(HOVED, "s10 bold c" TEMA.tekst)
    vt.PanelToggle := Reg(pn, Knapp(HOVED, "x" (x + b - 110) " y86 w110 h30", "", VekslVerktoy.Bind(vt)))
    Skrift(HOVED, "s10 norm c" TEMA.tekst)
    vt.StatusKtrl := Reg(pn, HOVED.AddText("x" x " y124 w" b " h22 Background" TEMA.bg, ""))
    try {
        vt.ByggPanel(HOVED, x, 156, b)
    } catch as feil {
        Logg("Klarte ikke å bygge siden for " vt.Navn ": " feil.Message)
    }
}

ByggLoggPanel() {
    pn := "Logg", x := INNHOLD_X, b := INNHOLD_B
    PanelTittel(pn, "Logg")
    Skrift(HOVED, "s9 norm c" TEMA.tekst, "Consolas")
    APP_KTRL["Logg"] := Reg(pn, HOVED.AddEdit("x" x " y124 w" b " h" (APP_H - 194) " ReadOnly -E0x200 Background" TEMA.kort, ""))
    Skrift(HOVED, "s9 norm c" TEMA.tekst)
    Reg(pn, Knapp(HOVED, "x" x " y" (APP_H - 56) " w170 h32", "Åpne loggmappen", (*) => Run('"' LOGG_MAPPE '"'), TEMA.aksent2))
    Reg(pn, Knapp(HOVED, "x" (x + b - 110) " y" (APP_H - 56) " w110 h32", "Tøm visningen", TomLogg, TEMA.aksent2))
    OppdaterLoggFelt()
}

ByggInnstillingerPanel() {
    pn := "Innstillinger", x := INNHOLD_X, b := INNHOLD_B
    PanelTittel(pn, "Innstillinger")

    rader := [
        ["Autostart", "Start automatisk når Windows starter", VekslAutostart],
        ["Skjult",    "Start skjult (bare ikonet ved klokka vises)", VekslStartSkjult]
    ]
    for i, rad in rader {
        y := 128 + (i - 1) * 48
        Skrift(HOVED, "s10 norm c" TEMA.tekst)
        Reg(pn, HOVED.AddText("x" x " y" y " w" (b - 130) " h34 +0x200 Background" TEMA.bg, rad[2]))
        Skrift(HOVED, "s10 bold c" TEMA.tekst)
        APP_KTRL[rad[1]] := Reg(pn, Knapp(HOVED, "x" (x + b - 110) " y" y " w110 h34", "", rad[3]))
    }
    OppdaterToggle(APP_KTRL["Autostart"], FileExist(AutostartLnk()) != "")
    OppdaterToggle(APP_KTRL["Skjult"], Innst("App", "StartSkjult", "0") = "1")

    y := 128 + rader.Length * 48 + 8
    Skrift(HOVED, "s10 norm c" TEMA.tekst)
    Reg(pn, HOVED.AddText("x" x " y" y " w" (b - 290) " h30 +0x200 Background" TEMA.bg, "Vis / skjul vinduet med:"))
    Skrift(HOVED, "s10 norm c000000")
    APP_KTRL["VisTast"] := Reg(pn, HOVED.AddHotkey("x" (x + b - 280) " y" (y + 2) " w160 h26", Innst("App", "VisTast", "^!m")))
    Skrift(HOVED, "s10 bold c" TEMA.tekst)
    Reg(pn, Knapp(HOVED, "x" (x + b - 110) " y" y " w110 h30", "Bruk", LagreVisTast))

    y += 64
    Skrift(HOVED, "s10 norm c" TEMA.tekst)
    Reg(pn, Knapp(HOVED, "x" x " y" y " w180 h34", "Åpne datamappen", (*) => Run('"' DATA_MAPPE '"'), TEMA.aksent2))
    Reg(pn, Knapp(HOVED, "x" (x + 192) " y" y " w180 h34", "Avslutt programmet", (*) => ExitApp(), TEMA.av))

    y += 52
    Skrift(HOVED, "s9 bold c" TEMA.tekst)
    Reg(pn, Knapp(HOVED, "x" x " y" y " w188 h34", "Importer konfigurasjon…", ImporterKonfigurasjon, TEMA.aksent))
    Reg(pn, Knapp(HOVED, "x" (x + 198) " y" y " w132 h34", "Themes…", VisTemaer, TEMA.aksent2))
    Reg(pn, Knapp(HOVED, "x" (x + 340) " y" y " w152 h34", "Last inn på nytt", (*) => Reload(), TEMA.aksent2))

    ; Utviklerkreditering nederst på Innstillinger-siden.
    Skrift(HOVED, "s9 bold c" TEMA.dempet)
    Reg(pn, HOVED.AddText("x" x " y" (APP_H - 108) " w" b " h22 Background" TEMA.bg, "Developers"))
    Skrift(HOVED, "s10 norm c" TEMA.tekst)
    Reg(pn, HOVED.AddText("x" x " y" (APP_H - 82) " w" b " h26 Background" TEMA.bg, "MAUUNI  ·  KAISAD"))
}

; Sidetittel med «?»-knapp. medToggle = siden har PÅ/AV-knapp oppe til høyre.
PanelTittel(pn, tekst, medToggle := false) {
    Skrift(HOVED, "s14 bold c" TEMA.tekst)
    tittel := Reg(pn, HOVED.AddText("x" INNHOLD_X " y84 w" (INNHOLD_B - 170) " h32 +0x200 Background" TEMA.bg, tekst))
    Skrift(HOVED, "s12 bold c" TEMA.tekst)
    hx := medToggle ? INNHOLD_X + INNHOLD_B - 110 - 44 : INNHOLD_X + INNHOLD_B - 34
    Reg(pn, Knapp(HOVED, "x" hx " y86 w34 h30", "?", VisHjelp.Bind(pn), TEMA.aksent2))
    return tittel
}

; ---- Hjelp («?») ----
VisHjelp(side, *) {
    static hv := ""
    if IsObject(hv)
        try hv.Destroy()
    tekst := HjelpTekst(side)
    linjer := 0
    for linje in StrSplit(tekst, "`n")
        linjer += 1 + StrLen(linje) // 72
    h := Max(60, linjer * 21 + 10)
    hv := Gui("+Owner" HOVED.Hwnd " -MinimizeBox", "Hjelp – " side)
    hv.BackColor := TEMA.bg
    Skrift(hv, "s14 bold c" TEMA.tekst)
    hv.AddText("x20 y16 w520 Background" TEMA.bg, side)
    Skrift(hv, "s10 c" TEMA.tekst)
    felt := hv.AddEdit("x20 y54 w540 h" h " ReadOnly -TabStop -E0x200 -VScroll Multi Background" TEMA.bg, StrReplace(tekst, "`n", "`r`n"))
    Skrift(hv, "s10 bold c" TEMA.tekst)
    Knapp(hv, "x440 y" (h + 66) " w120 h36", "Lukk", (*) => hv.Destroy())
    hv.OnEvent("Escape", (*) => hv.Destroy())
    hv.Show("w580 h" (h + 118))
    try SendMessage(0xB1, 0, 0, felt)
}

HjelpTekst(side) {
    for vt in VERKTOY_LISTE
        if (vt.Navn = side)
            return vt.Hjelp()
    switch side {
        case "Oversikt":
            return "•  «Start QuickerKeys» leser inn hurtigtekster og bekrefter aktive hurtigtaster.`n"
                . "•  PÅ / AV slår et verktøy av eller på.`n"
                . "•  «Åpne →» viser verktøyets side.`n"
                . "•  Alt kjører i bakgrunnen. Åpne vinduet igjen fra ikonet ved klokka."
        case "Logg":
            return "•  Viser hva programmet har gjort i dag – nyeste øverst.`n"
                . "•  Alt lagres også i mappen Logg, én fil per dag (30 dager tilbake).`n"
                . "•  Feil er merket med FEIL. Noe galt? Send loggfila fra den dagen."
        case "Innstillinger":
            return "•  Velg om programmet skal starte med Windows, og om det skal starte skjult.`n"
                . "•  Hurtigtast: klikk i feltet, trykk tastene, trykk «Bruk».`n"
                . "•  «Importer konfigurasjon» støtter ny INI og eldre QuickKey-vindussnarveier.`n"
                . "•  «Themes» velger farger; programmet starter på nytt ved bytte.`n"
                . "•  «Last inn på nytt» aktiverer endringer du har gjort direkte i INI-filen.`n"
                . "•  Data: " DATA_MAPPE
    }
    return ""
}

Skrift(gui, spesifikasjon, skriftnavn := "Segoe UI") {
    gui.SetFont("norm " spesifikasjon, skriftnavn)
}

Reg(panel, ktrl) {
    if !PANELER.Has(panel)
        PANELER[panel] := []
    PANELER[panel].Push(ktrl)
    ktrl.Visible := false
    return ktrl
}

; Flat, farget «knapp» (en Text-kontroll som kan klikkes)
Knapp(gui, opt, tekst, callback, bakgrunn := "") {
    if (bakgrunn = "")
        bakgrunn := TEMA.aksent
    ktrl := gui.AddText(opt " Center +0x200 Background" bakgrunn, tekst)
    ktrl.OnEvent("Click", callback)
    return ktrl
}

OppdaterToggle(ktrl, paa) {
    if !IsObject(ktrl)
        return
    ktrl.Text := paa ? "●  PÅ" : "○  AV"
    ktrl.Opt("Background" (paa ? TEMA.paa : TEMA.av))
    ktrl.Redraw()
}

VisPanel(navn, *) {
    for panelNavn, liste in PANELER
        for ktrl in liste
            ktrl.Visible := (panelNavn = navn) && (!VIS_VILKAR.Has(ktrl) || VIS_VILKAR[ktrl]())
    for knappNavn, knapp in NAVKNAPPER {
        knapp.Opt("Background" (knappNavn = navn ? TEMA.aksent : TEMA.nav))
        knapp.Redraw()
    }
}

VisHoved(*) {
    static vistFor := false
    if !vistFor {
        vistFor := true
        HOVED.Show("w" APP_B " h" APP_H)
    } else {
        HOVED.Show()
    }
    try WinActivate "ahk_id " HOVED.Hwnd
}

VisSkjul(*) {
    if WinActive("ahk_id " HOVED.Hwnd)
        HOVED.Hide()
    else
        VisHoved()
}

HovedLukk(*) {
    static vist := false
    if !vist {
        vist := true
        TrayTip "Kjører videre i bakgrunnen. Åpne igjen fra ikonet ved klokka.", APP_NAVN
    }
    ; ingen retur -> vinduet skjules, alt fortsetter å kjøre
}

ByggTrayMeny() {
    A_IconTip := APP_NAVN
    meny := A_TrayMenu
    meny.Delete()
    meny.Add("Åpne " APP_NAVN, VisHoved)
    meny.Add()
    for vt in VERKTOY_LISTE
        meny.Add(vt.Navn, VekslVerktoy.Bind(vt))
    meny.Add()
    meny.Add("Avslutt", (*) => ExitApp())
    meny.Default := "Åpne " APP_NAVN
    meny.ClickCount := 1
}

; ---- Av/på for verktøy ----
VekslVerktoy(vt, *) {
    SettAktiv(vt, !vt.Aktiv)
}

SettAktiv(vt, paa, lagre := true) {
    vt.Aktiv := paa
    try {
        if paa
            vt.Start()
        else
            vt.Stopp()
    } catch as feil {
        Logg(vt.Navn ": " feil.Message)
    }
    if !paa
        vt.SettStatus("Slått av")
    if lagre {
        SettInnst(vt.Id, "Aktiv", paa ? "1" : "0")
        Logg(vt.Navn " " (paa ? "slått på" : "slått av"))
    }
    OppdaterToggle(vt.PanelToggle, paa)
    if OVERSIKT.Has(vt.Id)
        OppdaterToggle(OVERSIKT[vt.Id].toggle, paa)
    try {
        if paa
            A_TrayMenu.Check(vt.Navn)
        else
            A_TrayMenu.Uncheck(vt.Navn)
    }
    OppdaterOversikt(vt)
}

OppdaterOversikt(vt) {
    if !OVERSIKT.Has(vt.Id)
        return
    status := vt.Aktiv ? vt.StatusTekst : "Slått av"
    OVERSIKT[vt.Id].status.Text := vt.Beskrivelse "`n" (status != "" ? "• " status : "")
}

; Fire paletter. Tema leses fra INI ved oppstart, og endringer trer i kraft etter Reload().
TemaNavn() => ["Midnatt", "Grafitt", "Skog", "Lys"]

TemaPalett(navn) {
    switch navn {
        case "Grafitt":
            return {bg:"191B22", kort:"282B35", nav:"111319", aksent:"655DD6", aksent2:"42435F"
                , tekst:"F2F3F7", dempet:"AEB5C3", paa:"279D76", av:"566071", linje:"39404D"}
        case "Skog":
            return {bg:"10251F", kort:"1A362D", nav:"0B1C18", aksent:"267E6B", aksent2:"285D50"
                , tekst:"F0F8F2", dempet:"A4C2B5", paa:"259D77", av:"546D64", linje:"33594A"}
        case "Lys":
            return {bg:"F1F5F9", kort:"E2EAF3", nav:"CBD9EA", aksent:"A7D4FF", aksent2:"D2E4F5"
                , tekst:"12243D", dempet:"405E7A", paa:"B9E6D0", av:"C6D0DD", linje:"ADBED2"}
        default:
            return {bg:"0F1E3A", kort:"16294D", nav:"0B1730", aksent:"2F7BEA", aksent2:"24497F"
                , tekst:"E8EEF9", dempet:"8FA3C7", paa:"1FA97A", av:"56637D", linje:"1E3560"}
    }
}

VisTemaer(*) {
    g := Gui("+Owner" HOVED.Hwnd " -MinimizeBox", "Themes – " APP_NAVN)
    g.BackColor := TEMA.bg
    Skrift(g, "s13 bold c" TEMA.tekst)
    g.AddText("x20 y15 w360 h28 Background" TEMA.bg, "Velg tema")
    Skrift(g, "s9 c" TEMA.dempet)
    g.AddText("x20 y54 w360 h24 Background" TEMA.bg, "Temaet brukes etter en automatisk omstart.")
    Skrift(g, "s10 c000000")
    liste := g.AddDropDownList("x20 y85 w360 R4", TemaNavn())
    for i, navn in TemaNavn()
        if (navn = Innst("App", "Tema", "Midnatt"))
            liste.Choose(i)
    Skrift(g, "s10 bold c" TEMA.tekst)
    Knapp(g, "x20 y137 w175 h36", "Bruk tema", (*) => LagreTema(g, liste.Text))
    Knapp(g, "x205 y137 w175 h36", "Avbryt", (*) => g.Destroy(), TEMA.aksent2)
    g.OnEvent("Escape", (*) => g.Destroy())
    g.Show("w400 h190")
}

LagreTema(vindu, navn) {
    if !InStr("|" StrJoinTemaer() "|", "|" navn "|")
        return
    try {
        SettInnst("App", "Tema", navn)
        Logg("Endret tema til " navn)
        vindu.Destroy()
        Reload()
    } catch as feil {
        MsgBox "Kunne ikke lagre tema: " feil.Message, APP_NAVN, "Icon!"
    }
}

StrJoinTemaer() {
    resultat := ""
    for navn in TemaNavn()
        resultat .= (resultat = "" ? "" : "|") navn
    return resultat
}

; Import fra eksternt valgt fil. Leser kilden, men flytter aldri QuickerKeys-datamappen.
ImporterKonfigurasjon(*) {
    fil := FileSelect(1, INNST_MAPPE, "Velg konfigurasjonsfil", "INI-filer (*.ini)")
    if (fil = "")
        return
    if (StrLower(fil) = StrLower(INI_FIL)) {
        MsgBox "Du redigerer allerede aktiv QuickerKeys.ini. Trykk «Last inn på nytt» for å aktivere endringene.", APP_NAVN
        return
    }
    try innhold := FileRead(fil)
    catch as feil {
        MsgBox "Kunne ikke lese INI-filen:`n" feil.Message, APP_NAVN, "Icon!"
        return
    }
    if RegExMatch(innhold, "im)^\s*\[Shortcuts\]\s*$") {
        ImporterGammelQuickKey(fil)
        return
    }
    if !RegExMatch(innhold, "im)^\s*\[(App|SMKontakt|Vindusbytter|Tekstflyt|TrioSnarveier)\]\s*$") {
        MsgBox "Ukjent konfigurasjonsformat. Forventet QuickerKeys/MAAUNI eller gamle QuickKey [Shortcuts].", APP_NAVN, "Icon!"
        return
    }
    ; Kun anerkjente nøkkelverdier importeres: eksterne filstier og programmappe beholdes lokale.
    seksjoner := Map(
        "App", ["StartSkjult", "VisTast", "Tema"],
        "Tekstflyt", ["Aktiv"],
        "SMKontakt", ["Aktiv", "TrioKilde", "WebVindu", "WebEtikett", "TrioVindu", "Etikett"
            , "AndreLinjeRegex", "ManuellTast", "TrioKontroll", "SMVindu"
            , "KontaktX", "KontaktY", "KnappX", "KnappY"],
        "Vindusbytter", ["Aktiv"],
        "TrioSnarveier", ["Aktiv", "HKCopy"]
    )
    loop 4 {
        i := A_Index
        for k in ["Vindu", "Navn", "Tast"]
            seksjoner["Vindusbytter"].Push(k i)
    }
    for k in ["HKAgentvindu", "HkTjenestevindu", "HKetterarbeid", "HKcopyIM", "HKcopyTLF"]
        seksjoner["TrioSnarveier"].Push(k, "Enabled" k)

    endringer := []
    for seksjon, nokler in seksjoner
        for nokkel in nokler {
            verdi := IniRead(fil, seksjon, nokkel, "{QUICKERKEYS_MISSING}")
            if (verdi != "{QUICKERKEYS_MISSING}")
                endringer.Push({seksjon:seksjon, nokkel:nokkel, verdi:verdi})
        }
    if !endringer.Length {
        MsgBox "Ingen støttede innstillinger ble funnet.", APP_NAVN, "Icon!"
        return
    }
    valg := MsgBox("Fant " endringer.Length " støttede innstillinger. Importere dem til QuickerKeys?"
        . "`n`nAktiv datamappe beholdes: " DATA_MAPPE
        . "`nExcelFil og andre eksterne filstier endres ikke."
        . "`nEksisterende INI sikkerhetskopieres før oppdatering.", APP_NAVN, "YesNo Icon?")
    if (valg != "Yes")
        return
    try {
        SikkerhetskopierIni()
        for entry in endringer
            SettInnst(entry.seksjon, entry.nokkel, entry.verdi)
        Logg("Importerte " endringer.Length " INI-verdier fra ekstern fil")
        Reload()
    } catch as feil {
        MsgBox "Import feilet:`n" feil.Message, APP_NAVN, "Icon!"
    }
}

SikkerhetskopierIni() {
    if FileExist(INI_FIL) {
        backup := INNST_MAPPE "\QuickerKeys-backup-" FormatTime(, "yyyyMMdd-HHmmss") "-" A_TickCount ".ini"
        FileCopy INI_FIL, backup
        return backup
    }
    return ""
}

; Gammel QuickKey v1.05 bruker Trio Attendant-menyer, IKKE vindusbytte.
; Kilden blir aldri endret; støttede hurtigtaster importeres til [TrioSnarveier].
ImporterGammelQuickKey(fil) {
    oppgaver := TrioOppgaver()
    importerte := []
    ignorert := []
    tastMap := Map()
    for op in oppgaver {
        tast := Trim(StrReplace(IniRead(fil, "Shortcuts", op.key, ""), '"', ""), " `t`r`n")
        aktiv := StrLower(Trim(IniRead(fil, "Enabled", op.key, "off")))
        if (tast = "")
            continue
        if !RegExMatch(tast, "^[!^+#]*[A-Za-z0-9]+$") {
            ignorert.Push(op.key ": ukjent hurtigtast (" tast ")")
            continue
        }
        paa := aktiv = "on" || aktiv = "1"
        if paa {
            konflikt := ""
            if (tast = Innst("App", "VisTast", "^!m")
                || tast = Innst("SMKontakt", "ManuellTast", "^!k"))
                konflikt := "hurtigtasten brukes av QuickerKeys/SM Kontakt"
            loop 4 {
                ; Opprydning fra feil v3.0-import utføres under lagring nedenfor.
                gammelFeil := (A_Index = 1 && IniRead(INI_FIL, "Vindusbytter", "Vindu1", "") = "Trio Agent ahk_exe msedge.exe"
                    && tast = IniRead(INI_FIL, "Vindusbytter", "Tast1", ""))
                    || (A_Index = 2 && IniRead(INI_FIL, "Vindusbytter", "Vindu2", "") = "Service Manager ahk_exe msedge.exe"
                    && tast = IniRead(INI_FIL, "Vindusbytter", "Tast2", ""))
                if (tast = Innst("Vindusbytter", "Tast" A_Index, "") && !gammelFeil)
                    konflikt := "brukes av Vindusbytter " A_Index
            }
            if tastMap.Has(tast)
                konflikt := "også brukt av " tastMap[tast]
            if (konflikt != "") {
                ignorert.Push(op.key ": " konflikt)
                continue
            }
            tastMap[tast] := op.navn
        }
        importerte.Push({key:op.key, navn:op.navn, tast:tast, paa:paa})
    }

    kopitast := Trim(StrReplace(IniRead(fil, "Shortcuts", "HKCopy", ""), '"', ""), " `t`r`n")
    if (kopitast != "" && !RegExMatch(kopitast, "^[!^+#]*\S+$")) {
        ignorert.Push("HKCopy: ugyldig kopitast " kopitast)
        kopitast := ""
    }
    ikkeStottet := []
    for key in ["HKLagreUtklipp", "HKCopyService", "HKHurtigtekst"]
        if (IniRead(fil, "Shortcuts", key, "") != "")
            ikkeStottet.Push(key)

    rapport := "QuickKey v1.05 funnet (Trio Attendant).`n`n"
    for item in importerte
        rapport .= (item.paa ? "PÅ: " : "AV: ") item.navn "  —  " item.tast "`n"
    if (kopitast != "")
        rapport .= "Kopitast i Trio (HKCopy): " kopitast "`n"
    if ikkeStottet.Length {
        rapport .= "`nIkke støttet i QuickerKeys v3.0:`n"
        for key in ikkeStottet
            rapport .= "• " key "`n"
    }
    if ignorert.Length {
        rapport .= "`nHoppet over pga. ugyldig tast eller konflikt:`n"
        for feil in ignorert
            rapport .= "• " feil "`n"
    }
    if (!importerte.Length && kopitast = "") {
        MsgBox rapport "`nIngen støttede innstillinger å importere.", APP_NAVN, "Icon!"
        return
    }
    rapport .= "`nDet opprettes lokal sikkerhetskopi av QuickerKeys.ini."
        . "`nQuickKey sin config.ini og programmappe blir ikke endret."
        . "`n`nVil du importere de støttede innstillingene?"
    if (MsgBox(rapport, APP_NAVN, "YesNo Icon?") != "Yes")
        return
    try {
        SikkerhetskopierIni()
        ; Fjern KUN de to feilaktige Edge-mappingene fra den tidligere v3.0-importen.
        feilId := ["Trio Agent ahk_exe msedge.exe", "Service Manager ahk_exe msedge.exe"]
        for i, id in feilId {
            if (IniRead(INI_FIL, "Vindusbytter", "Vindu" i, "") = id) {
                for k in ["Vindu", "Navn", "Tast"]
                    SettInnst("Vindusbytter", k i, "")
            }
        }
        for item in importerte {
            SettInnst("TrioSnarveier", item.key, item.tast)
            SettInnst("TrioSnarveier", "Enabled" item.key, item.paa ? "on" : "off")
        }
        if (kopitast != "")
            SettInnst("TrioSnarveier", "HKCopy", kopitast)
        SettInnst("TrioSnarveier", "Aktiv", "1")
        Logg("QuickKey v1.05: importerte " importerte.Length " Trio-snarveier; kildefil beholdt")
        Reload()
    } catch as feil {
        MsgBox "Import feilet:`n" feil.Message, APP_NAVN, "Icon!"
    }
}

; Gir samme tydelige bekreftelse som gamle QuickKey «Start hurtigtekst».
; Respekterer PÅ/AV-valgene; aktiverer ikke verktøy brukeren har slått av.
StartQuickerKeys(*) {
    meldinger := []
    aktive := 0
    for vt in VERKTOY_LISTE {
        if !vt.Aktiv
            continue
        aktive++
        if (vt is VT_Tekstflyt) {
            if vt.Sync(false)
                meldinger.Push("Tekstflyt: " vt.Koder.Count " hurtigtekster importert og klare.")
            else
                meldinger.Push("Tekstflyt: feil ved lasting – se Logg.")
        } else if (vt is VT_TrioSnarveier) {
            vt.Start()
            meldinger.Push("Trio Snarveier: " vt.Registrerte.Count " taster registrert.")
        } else if (vt is VT_Vindusbytter) {
            vt.Registrer()
            meldinger.Push("Vindusbytter: " vt.StatusTekst)
        } else if (vt is VT_SMKontakt) {
            meldinger.Push("SM Kontakt: " (vt.ErLart() ? "oppsett funnet" : "må læres opp først"))
        }
    }
    rapport := "QuickerKeys " APP_VERSJON " er startet.`n"
        . aktive " av " VERKTOY_LISTE.Length " verktøy er slått på.`n`n"
    for melding in meldinger
        rapport .= "• " melding "`n"
    MsgBox rapport, APP_NAVN, "Iconi"
}

; ---- App-innstillinger ----
AutostartLnk() => A_Startup "\" APP_NAVN ".lnk"

VekslAutostart(*) {
    lnk := AutostartLnk()
    if FileExist(lnk)
        FileDelete lnk
    else
        FileCreateShortcut A_ScriptFullPath, lnk, A_ScriptDir
    OppdaterToggle(APP_KTRL["Autostart"], FileExist(lnk) != "")
}

VekslStartSkjult(*) {
    paa := Innst("App", "StartSkjult", "0") != "1"
    SettInnst("App", "StartSkjult", paa ? "1" : "0")
    OppdaterToggle(APP_KTRL["Skjult"], paa)
}

SettVisTast(tast) {
    global VIS_TAST
    if (VIS_TAST != "")
        try Hotkey VIS_TAST, "Off"
    VIS_TAST := ""
    if (tast = "")
        return
    try {
        Hotkey tast, VisSkjul, "On"
        VIS_TAST := tast
    } catch as feil {
        Logg("Kunne ikke bruke hurtigtasten «" tast "»: " feil.Message)
    }
}

LagreVisTast(*) {
    tast := APP_KTRL["VisTast"].Value
    SettVisTast(tast)
    SettInnst("App", "VisTast", tast)
    Tip(tast = "" ? "Hurtigtast fjernet" : "Hurtigtast lagret")
}

; ---- Logg ----
Logg(melding) {
    try FileAppend FormatTime(, "HH:mm:ss") "  " melding "`n", LoggFil(), "UTF-8"
    LOGG_LINJER.InsertAt(1, FormatTime(, "HH:mm:ss") "   " melding)
    if (LOGG_LINJER.Length > 300)
        LOGG_LINJER.Pop()
    OppdaterLoggFelt()
}

OppdaterLoggFelt() {
    if !APP_KTRL.Has("Logg")
        return
    tekst := ""
    for linje in LOGG_LINJER
        tekst .= linje "`r`n"
    APP_KTRL["Logg"].Value := tekst
}

TomLogg(*) {
    LOGG_LINJER.Length := 0
    OppdaterLoggFelt()
}

Tip(melding, ms := 1800) {
    ToolTip melding
    SetTimer () => ToolTip(), -ms
}


; =====================================================================
;  VERKTØY: TEKSTFLYT
; =====================================================================
class VT_Tekstflyt extends VT_Base {
    static Instans := ""
    Navn := "Tekstflyt"
    Beskrivelse := "Skriv en kode (f.eks. #løst) + Mellomrom/Enter – så settes teksten inn."
    Koder := Map()
    SistEndret := ""
    SisteFeil := ""
    Editor := ""
    EkVindu := ""
    EkValgt := ""

    __New() {
        VT_Tekstflyt.Instans := this
        this.Koder.CaseSense := "Off"
        ; Respekter valgt Excel-fil selv hvis den er midlertidig utilgjengelig.
        ; Aldri overstyr valget med en eksempel-/standardfil uten brukerens samtykke.
        valgt := this.Hent("ExcelFil", "")
        this.ExcelFil := valgt != "" ? valgt : TEKST_MAPPE "\Tekstflyt.xlsx"
        this.SjekkCb := ObjBindMethod(this, "SjekkEndring")
    }

    ByggPanel(gui, x, y, b) {
        kb := (b - 24) // 3
        Skrift(gui, "s8 c" TEMA.dempet)
        this.FilK := this.Leg(gui.AddText("x" x " y" y " w" b " h18 +0x8000 Background" TEMA.bg, this.ExcelFil))
        Skrift(gui, "s10 bold c" TEMA.tekst)
        this.Leg(Knapp(gui, "x" x " y" (y + 28) " w" kb " h40", "Åpne Excel", ObjBindMethod(this, "ApneExcel")))
        this.SyncK := this.Leg(Knapp(gui, "x" (x + kb + 12) " y" (y + 28) " w" kb " h40", "Synkroniser", ObjBindMethod(this, "Sync", true)))
        this.Leg(Knapp(gui, "x" (x + 2 * (kb + 12)) " y" (y + 28) " w" kb " h40", "Teksteditor", ObjBindMethod(this, "VisEditor")))
        Skrift(gui, "s9 c" TEMA.tekst)
        this.Leg(Knapp(gui, "x" x " y" (y + 80) " w" (kb + 90) " h32", "Importer / velg Excel…", ObjBindMethod(this, "VelgFil"), TEMA.aksent2))
    }

    Hjelp() {
        return "•  Skriv en kode, f.eks. #løst, og trykk Mellomrom eller Enter.`n"
            . "•  Ny kode: «Teksteditor» → skriv kode og tekst → «Lagre i Excel».`n"
            . "•  «Importer / velg Excel»: Ja = lag en lokal kopi, Nei = bruk filen der den ligger.`n"
            . "•  Valgt fil beholdes ved omstart. Mangler den, får du feilmelding i stedet for at en annen fil lastes.`n"
            . "•  Rediger koder: «Teksteditor» → «Eksisterende tekster…».`n"
            . "•  Slett koder: «Åpne Excel». Endringer hentes automatisk."
    }

    Start() {
        this.Sync(false)
        SetTimer this.SjekkCb, 5000
    }

    Stopp() {
        SetTimer this.SjekkCb, 0
    }

    ; Lag kun eksempelregneark for en ny, tom installasjon.
    ; Mangler en eksplisitt valgt fil, så IKKE lag en tom kopi eller bytt filsti.
    SikreFil() {
        if FileExist(this.ExcelFil)
            return true
        std := TEKST_MAPPE "\Tekstflyt.xlsx"
        if (StrLower(this.ExcelFil) != StrLower(std)) {
            this.SettStatus("Valgt Excel-fil finnes ikke – velg en gyldig fil")
            Logg("Tekstflyt: valgt Excel-fil mangler: " this.ExcelFil)
            return false
        }
        if (this.Hent("ExcelFil", "") != "" && !FileExist(std)) {
            this.SettStatus("Lagret Excel-fil mangler – importer den på nytt")
            Logg("Tekstflyt: lagret standardfil mangler: " std)
            return false
        }
        try {
            XlsxSkriv(std, [
                ["#løst", "Hei!`n`nSaken er nå løst. Ta gjerne kontakt igjen hvis problemet kommer tilbake.`n`nMvh"],
                ["#brannmur", "Henvendelsen er sendt videre til brannmur-gruppen for vurdering."]
            ])
            Logg("Opprettet eksempelfil ved førstegangsoppstart: " std)
            return true
        } catch as feil {
            Logg("Tekstflyt: kunne ikke opprette eksempelfil: " feil.Message)
            this.SettStatus("Kunne ikke opprette eksempelfil – se Logg")
            return false
        }
    }

    SettFil(fil) {
        if !FileExist(fil)
            throw Error("Excel-filen finnes ikke: " fil)
        ; Prøv å lese filen FØR lagring, så en ugyldig fil ikke blir permanent valgt.
        LesKoder(fil)
        forrige := this.ExcelFil
        this.ExcelFil := fil
        try {
            if !this.Sync(false)
                throw Error("Klarte ikke å laste hurtigtekstene")
            this.Lagre("ExcelFil", fil)
            try this.FilK.Text := fil
            Logg("Tekstflyt: ny Excel-fil aktiv: " fil)
        } catch as feil {
            this.ExcelFil := forrige
            this.Sync(false)
            throw feil
        }
    }

    Sync(visMelding := false, *) {
        if !this.SikreFil() {
            if visMelding
                MsgBox "Den valgte Excel-filen ble ikke funnet:`n" this.ExcelFil
                    . "`n`nBruk «Importer / velg Excel» og velg riktig fil.", APP_NAVN, "Icon!"
            return false
        }
        try {
            nye := LesKoder(this.ExcelFil)
        } catch as feil {
            this.SettStatus("Klarte ikke å lese Excel-filen – se Logg")
            if (feil.Message != this.SisteFeil)
                Logg("Tekstflyt: " feil.Message)
            this.SisteFeil := feil.Message
            if visMelding
                MsgBox "Klarte ikke å lese Excel-filen.`n`n" feil.Message, APP_NAVN, "Icon!"
            return false
        }
        this.SisteFeil := ""

        HotIf TekstflytKrit
        for kode in this.Koder
            if !nye.Has(kode)
                try Hotstring(":XC1:" kode, , false)
        feilet := 0
        for kode, tekst in nye {
            try Hotstring(":XC1:" kode, TekstflytSettInn, true)
            catch as feil {
                feilet++
                Logg("Tekstflyt: kunne ikke lage koden " kode ": " feil.Message)
            }
        }
        HotIf
        this.Koder := nye
        try this.SistEndret := FileGetTime(this.ExcelFil, "M")
        this.SettStatus(nye.Count " koder lastet  ·  synkronisert " FormatTime(, "HH:mm"))
        Logg("Tekstflyt: synkronisert " nye.Count " koder fra " this.ExcelFil (feilet ? " (" feilet " feilet)" : ""))
        if visMelding {
            knapp := this.SyncK
            knapp.Text := "Synkronisert!"
            SetTimer () => knapp.Text := "Synkroniser", -1500
        }
        return feilet = 0
    }

    SjekkEndring() {
        if (this.SistEndret = "" || !FileExist(this.ExcelFil))
            return
        try endret := FileGetTime(this.ExcelFil, "M")
        catch
            return
        if (endret != this.SistEndret)
            this.Sync(false)
    }

    ApneExcel(*) {
        if !this.SikreFil()
            return MsgBox("Den valgte Excel-filen finnes ikke. Bruk «Importer / velg Excel».", APP_NAVN, "Icon!")
        try Run '"' this.ExcelFil '"'
        catch as feil
            MsgBox "Klarte ikke å åpne filen:`n" this.ExcelFil "`n`n" feil.Message, APP_NAVN, "Icon!"
    }

    VelgFil(*) {
        valgt := FileSelect(1, this.ExcelFil, "Importer eller velg Excel-fil", "Excel (*.xlsx; *.xlsm)")
        if (valgt = "")
            return
        try antall := LesKoder(valgt).Count
        catch as feil {
            MsgBox "Kunne ikke lese Excel-filen:`n" feil.Message, APP_NAVN, "Icon!"
            return
        }
        valg := MsgBox("Fant " antall " tekstkoder i:`n" valgt
            . "`n`nJA: Importer en egen kopi til QuickerKeys under AppData."
            . "`nNEI: Behold filen på den valgte plasseringen og bruk den direkte."
            . "`nAVBRYT: Ikke gjør endringer.", APP_NAVN, "YesNoCancel Icon?")
        if (valg = "Cancel")
            return
        maal := valgt
        if (valg = "Yes") {
            SplitPath valgt, , , &ext
            maal := TEKST_MAPPE "\Tekstflyt-importert-" FormatTime(, "yyyyMMdd-HHmmss") "-" A_TickCount "." ext
            try FileCopy valgt, maal
            catch as feil {
                MsgBox "Kunne ikke kopiere Excel-filen:`n" feil.Message, APP_NAVN, "Icon!"
                return
            }
        }
        try {
            this.SettFil(maal)
            Tip("Tekstflyt: " antall " koder lastet ✓", 2500)
        } catch as feil {
            MsgBox "Filen ble ikke aktivert:`n" feil.Message, APP_NAVN, "Icon!"
        }
    }

    ; Legger til / oppdaterer en kode i Excel-filen. Returnerer true hvis ny.
    LeggTil(kode, tekst) => this.Endre(kode, kode, tekst)

    ; Støtter redigering og omdøping av eksisterende koder.
    Endre(gammel, kode, tekst) {
        if !this.SikreFil()
            throw Error("Excel-filen finnes ikke eller kunne ikke åpnes.")
        if (gammel != kode && this.Koder.Has(kode))
            throw Error("Koden finnes allerede: " kode)
        try {
            return LeggTilViaExcel(this.ExcelFil, kode, tekst, gammel)
        } catch as feil {
            if (feil.Message != "INGEN_EXCEL")
                throw feil
        }
        rader := []
        ny := true
        for par in XlsxLesRader(this.ExcelFil) {
            if (Trim(par[1]) = "" || Trim(par[1]) = "Kode")
                continue
            if (ny && Trim(par[1]) = gammel) {
                par[1] := kode
                par[2] := tekst
                ny := false
            }
            rader.Push(par)
        }
        if ny
            rader.Push([kode, tekst])
        ; Makrobaserte filer må redigeres via Excel COM; den interne skriveren
        ; ville erstattet .xlsm med en vanlig .xlsx og fjernet makroene.
        if RegExMatch(this.ExcelFil, "i)\.xlsm$")
            throw Error("En .xlsm-fil krever Excel for sikker redigering.")
        ; Den interne XLSX-skriveren gjenskaper ark 1. Behold alltid originalen.
        backup := this.ExcelFil ".backup-" FormatTime(, "yyyyMMdd-HHmmss") "-" A_TickCount ".xlsx"
        FileCopy this.ExcelFil, backup
        XlsxSkriv(this.ExcelFil, rader)
        return ny
    }

    ; ---- Teksteditor ----
    VisEditor(*) {
        if IsObject(this.Editor) {
            this.Editor.Show()
            return
        }
        eg := Gui(, "Teksteditor – " APP_NAVN)
        this.Editor := eg
        eg.BackColor := TEMA.bg
        Skrift(eg, "s9 c" TEMA.dempet)
        eg.AddText("x16 y14 w220 Background" TEMA.bg, "Kode (f.eks. #løst)")
        Skrift(eg, "s11 c" TEMA.tekst)
        this.EdKode := eg.AddEdit("x16 y34 w220 h28 Background" TEMA.kort)
        Skrift(eg, "s9 c" TEMA.dempet)
        eg.AddText("x16 y74 w400 Background" TEMA.bg, "Tekst")
        Skrift(eg, "s10 c" TEMA.tekst)
        this.EdTekst := eg.AddEdit("x16 y94 w608 h320 Multi WantTab Background" TEMA.kort)
        Skrift(eg, "s11 bold c" TEMA.tekst)
        this.EdLagreK := Knapp(eg, "x16 y428 w220 h42", "Lagre i Excel", ObjBindMethod(this, "EdLagre"))
        Skrift(eg, "s10 c" TEMA.tekst)
        Knapp(eg, "x248 y428 w120 h42", "Tøm", ObjBindMethod(this, "EdTom"), TEMA.aksent2)
        Knapp(eg, "x380 y428 w244 h42", "Eksisterende tekster…", ObjBindMethod(this, "VisEksisterende"), TEMA.aksent2)
        Skrift(eg, "s10 bold c" TEMA.tekst)
        this.EdStatus := eg.AddText("x16 y482 w608 h22 Background" TEMA.bg, "")
        eg.Show("w640 h516")
    }

    ; Grønn (ok) eller rød (feil) linje nederst i teksteditoren
    EdMelding(tekst, ok := true) {
        this.EdStatus.SetFont("c" (ok ? TEMA.paa : "FF6B6B"))
        this.EdStatus.Text := tekst
    }

    EdLagre(*) {
        kode := Trim(this.EdKode.Value)
        tekst := StrReplace(this.EdTekst.Value, "`r`n", "`n")
        if (kode = "" || Trim(tekst) = "")
            return this.EdMelding("✗  Fyll inn både kode og tekst.", false)
        if RegExMatch(kode, "\s")
            return this.EdMelding("✗  Koden kan ikke inneholde mellomrom.", false)
        knapp := this.EdLagreK
        knapp.Text := "Lagrer…"
        this.EdMelding("")
        try {
            ny := this.LeggTil(kode, tekst)
        } catch as feil {
            knapp.Text := "Lagre i Excel"
            return this.EdMelding("✗  Ble ikke lagret: " feil.Message " – er filen åpen i Excel? Lagre/lukk den og prøv igjen.", false)
        }
        this.Sync(false)
        knapp.Text := ny ? "✓  Lagt til" : "✓  Oppdatert"
        knapp.Opt("Background" TEMA.paa)
        knapp.Redraw()
        this.EdMelding("✓  «" kode "» er " (ny ? "lagt til" : "oppdatert") " i Excel – klar til bruk.")
        SetTimer () => (knapp.Text := "Lagre i Excel", knapp.Opt("Background" TEMA.aksent), knapp.Redraw()), -2500
    }

    EdTom(*) {
        this.EdKode.Value := ""
        this.EdTekst.Value := ""
        this.EdMelding("")
        this.EdKode.Focus()
    }
    ; Velg en eksisterende kode, søk i kode/tekst, rediger og lagre.
    VisEksisterende(*) {
        if !this.Sync(false)
            return MsgBox("Kunne ikke lese Excel-filen. Se Logg.", APP_NAVN, "Icon!")
        if IsObject(this.EkVindu) {
            this.EkFyllListe()
            this.EkVindu.Show()
            return
        }
        ev := Gui("+Owner" this.Editor.Hwnd, "Eksisterende tekster – " APP_NAVN)
        this.EkVindu := ev
        ev.BackColor := TEMA.bg
        Skrift(ev, "s9 c" TEMA.dempet)
        ev.AddText("x16 y14 w400 Background" TEMA.bg, "Søk i kode eller tekst")
        Skrift(ev, "s11 c" TEMA.tekst)
        this.EkSok := ev.AddEdit("x16 y34 w688 h28 Background" TEMA.kort)
        this.EkSok.OnEvent("Change", (*) => this.EkFyllListe())
        Skrift(ev, "s10 c" TEMA.tekst)
        this.EkLV := ev.AddListView("x16 y72 w688 h200 -Multi Background" TEMA.kort, ["Kode", "Tekst"])
        this.EkLV.OnEvent("ItemSelect", ObjBindMethod(this, "EkVelg"))
        Skrift(ev, "s9 c" TEMA.dempet)
        ev.AddText("x16 y286 w220 Background" TEMA.bg, "Kode")
        Skrift(ev, "s11 c" TEMA.tekst)
        this.EkKode := ev.AddEdit("x16 y306 w220 h28 Background" TEMA.kort)
        Skrift(ev, "s9 c" TEMA.dempet)
        ev.AddText("x16 y344 w400 Background" TEMA.bg, "Tekst")
        Skrift(ev, "s10 c" TEMA.tekst)
        this.EkTekst := ev.AddEdit("x16 y364 w688 h220 Multi WantTab Background" TEMA.kort)
        Skrift(ev, "s11 bold c" TEMA.tekst)
        this.EkLagreK := Knapp(ev, "x16 y598 w220 h42", "Lagre endring", ObjBindMethod(this, "EkLagre"))
        Skrift(ev, "s10 bold c" TEMA.tekst)
        this.EkStatus := ev.AddText("x16 y652 w688 h22 Background" TEMA.bg, "")
        this.EkFyllListe()
        ev.Show("w720 h686")
        this.EkSok.Focus()
    }

    EkMelding(tekst, ok := true) {
        this.EkStatus.SetFont("c" (ok ? TEMA.paa : "FF6B6B"))
        this.EkStatus.Text := tekst
    }

    EkFyllListe(velg := "") {
        sok := Trim(this.EkSok.Value)
        lv := this.EkLV
        lv.Opt("-Redraw")
        lv.Delete()
        valgtRad := 0
        for kode, tekst in this.Koder {
            if (sok != "" && !InStr(kode, sok) && !InStr(tekst, sok))
                continue
            rad := lv.Add(, kode, KortVerdi(tekst, 110))
            if (kode = velg)
                valgtRad := rad
        }
        lv.ModifyCol(1, 170)
        lv.ModifyCol(2, 500)
        lv.Opt("+Redraw")
        if valgtRad
            lv.Modify(valgtRad, "Select Focus Vis")
        else
            this.EkMelding(lv.GetCount() " av " this.Koder.Count " tekster")
    }

    EkVelg(lv, rad, valgt) {
        if (!valgt || !rad)
            return
        kode := lv.GetText(rad, 1)
        if !this.Koder.Has(kode)
            return
        this.EkValgt := kode
        this.EkKode.Value := kode
        this.EkTekst.Value := StrReplace(this.Koder[kode], "`n", "`r`n")
    }

    EkLagre(*) {
        gammel := this.EkValgt
        kode := Trim(this.EkKode.Value)
        tekst := StrReplace(this.EkTekst.Value, "`r`n", "`n")
        if (gammel = "")
            return this.EkMelding("Velg en eksisterende kode først.", false)
        if (kode = "" || Trim(tekst) = "" || RegExMatch(kode, "\s"))
            return this.EkMelding("Koden/teksten er tom eller koden har mellomrom.", false)
        if (kode != gammel && this.Koder.Has(kode))
            return this.EkMelding("Koden eksisterer allerede: " kode, false)
        try {
            this.Endre(gammel, kode, tekst)
            if !this.Sync(false)
                throw Error("Lagret, men synkronisering feilet.")
            this.EkValgt := kode
            this.EkFyllListe(kode)
            this.EkMelding("Lagret og synkronisert: " kode)
            Logg("Tekstflyt: redigerte kode " gammel (kode != gammel ? " til " kode : ""))
        } catch as feil {
            this.EkMelding("Feil ved lagring: " feil.Message, false)
        }
    }

}

; Kalles når en kode er skrevet. Koden + Mellomrom/Enter er allerede fjernet.
; Teksten limes inn på én gang i akkurat det vinduet (og feltet) koden ble skrevet i.
TekstflytSettInn(hotstringNavn) {
    Critical                                   ; ingen andre verktøy får avbryte innsettingen
    tf := VT_Tekstflyt.Instans
    kode := RegExReplace(hotstringNavn, "^:[^:]*:")
    if !IsObject(tf) || !tf.Koder.Has(kode)
        return
    LimInnTekst(tf.Koder[kode], WinExist("A"))
}

LimInnTekst(tekst, hwnd) {
    tekst := StrReplace(tekst, "`n", "`r`n")
    lagret := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := tekst
    if !ClipWait(1) {                          ; utklippstavlen er opptatt – skriv teksten i stedet
        A_Clipboard := lagret
        SendText tekst
        return
    }
    if (hwnd && !WinActive("ahk_id " hwnd)) {  ; fokus har flyttet seg – tilbake til riktig vindu
        WinActivate "ahk_id " hwnd
        WinWaitActive "ahk_id " hwnd, , 1
    }
    Send "^v"
    Sleep 300                                  ; la programmet hente teksten før utklippstavlen settes tilbake
    A_Clipboard := lagret
}

; Kodene virker overalt unntatt i dette programmets egne vinduer
TekstflytKrit(*) {
    tf := VT_Tekstflyt.Instans
    return IsObject(tf) && tf.Aktiv && !WinActive("ahk_pid " DllCall("GetCurrentProcessId"))
}

LesKoder(fil) {
    res := Map()
    res.CaseSense := "Off"
    for par in XlsxLesRader(fil) {
        kode := Trim(par[1])
        tekst := StrReplace(StrReplace(par[2], "`r`n", "`n"), "`r", "`n")
        if (kode = "" || Trim(tekst) = "" || kode = "Kode" || RegExMatch(kode, "\s"))
            continue
        res[kode] := tekst
    }
    return res
}

; Skriver direkte i Excel hvis Excel finnes (og helst i en allerede åpen bok). Ellers kastes INGEN_EXCEL.
LeggTilViaExcel(fil, kode, tekst, gammel := "") {
    if (gammel = "")
        gammel := kode
    bok := "", xl := "", egen := false
    try {
        for b in ComObjActive("Excel.Application").Workbooks
            if (b.FullName = fil) {
                bok := b
                break
            }
    }
    if !IsObject(bok) {
        try {
            xl := ComObject("Excel.Application")
        } catch {
            throw Error("INGEN_EXCEL")
        }
        xl.DisplayAlerts := false
        bok := xl.Workbooks.Open(fil)
        egen := true
        if bok.ReadOnly {
            bok.Close(false)
            xl.Quit()
            throw Error("Excel-filen er låst (åpen et annet sted).")
        }
    }
    try {
        ark := bok.Worksheets(1)
        sist := ark.Cells(ark.Rows.Count, 1).End(-4162).Row     ; -4162 = xlUp
        rad := 0
        loop sist
            if (Trim(ark.Cells(A_Index, 1).Text) = gammel) {
                rad := A_Index
                break
            }
        ny := !rad
        if ny
            rad := sist + 1
        ark.Cells(rad, 1).Value := kode
        ark.Cells(rad, 2).Value := tekst
        ark.Cells(rad, 2).WrapText := true
        bok.Save()
    } finally {
        if egen {
            bok.Close(false)
            xl.Quit()
        }
    }
    return ny
}


; =====================================================================
;  VERKTØY: SM KONTAKT
;  Leser kundenummer (Trio Web) eller brukernavn (Trio Attendant) og
;  fyller det inn i Kontakt i Service Manager – én gang per samtale.
; =====================================================================
class VT_SMKontakt extends VT_Base {
    Navn := "SM Kontakt"
    Beskrivelse := "Fyller Kontakt i Service Manager når en samtale kommer inn i Trio (ikke 2. linje)."
    LaerSteg := 0
    AttMetode := ""
    SistFullSok := 0
    StarPa := ""
    AvansertVindu := ""
    AvansertFelt := ""
    TestVindu := ""
    DobbelTid := 700                     ; Trio Attendant: to kopieringer innen denne tiden = «fyll inn igjen» (ms)
    Ventetid := 10000                    ; Trio Web: maks ventetid på kundenummer etter at samtalen startet (ms)

    static Standard := Map(
        "TrioKilde",       "auto",
        "WebVindu",        "Trio Agent ahk_exe msedge.exe",
        "WebEtikett",      "Kundenummer",
        "TrioVindu",       "Trio Attendant",
        "Etikett",         "Brukernavn|Windows brukernavn",
        "AndreLinjeRegex", "i)(2\.?\s*linje|andrelinje|2nd\s*line)",
        "ManuellTast",     "^!k"
    )
    static Lart := ["TrioKontroll", "SMVindu", "KontaktX", "KontaktY", "KnappX", "KnappY"]
    static Moduser := [["auto", "Automatisk"], ["web", "Trio Web"], ["attendant", "Trio Attendant"]]
    static MetodeNavn := Map("kontroll", "feltet du klikket på", "html", "HTML-panelet", "vindu", "vindusteksten", "uia", "UI Automation")

    __New() {
        this.Cfg := Map()
        for nokkel, verdi in VT_SMKontakt.Standard
            this.Cfg[nokkel] := this.Hent(nokkel, verdi)
        for nokkel in VT_SMKontakt.Lart
            this.Cfg[nokkel] := this.Hent(nokkel, "")
        this.SjekkCb := ObjBindMethod(this, "Sjekk")
        this.ManuellCb := ObjBindMethod(this, "ManuellFyll")
        this.KlikkCb := ObjBindMethod(this, "MusKlikk")
        this.KopiCb := ObjBindMethod(this, "KopiFerdig")
        this.Ventende := ""
        this.KlippTid := 0
        OnClipboardChange(ObjBindMethod(this, "KlippEndret"))
        this.AvbrytCb := ObjBindMethod(this, "LaerEsc")
        this.TipsCb := ObjBindMethod(this, "LaerTips")
        this.AktivTast := ""
        this.ModusK := Map()
        this.NullstillTilstand()
    }

    NullstillTilstand() {
        this.Tilst := Map()
        for kilde in ["web", "attendant"]
            this.Tilst[kilde] := {SistNokkel: "", ForrigeHandtert: "", SistTid: 0, TomSiden: 0, ForsteSjekk: true
                , Tekst: "venter på samtale", SistSak: "", SakSett: "", SakTid: 0, TekstFor: "", SisteTekst: ""
                , FokusForsok: 0, SisteFokus: 0, ForrigeVerdi: "", GittOpp: "", Fylt: false
                , SistKopiert: "", KopiertTid: 0, TekstTid: 0, Samtale: -1, ForrigeSamtale: -1}
    }

    SettCfg(nokkel, verdi) {
        this.Cfg[nokkel] := verdi
        this.Lagre(nokkel, verdi)
    }

    Status(tekst) {
        if (tekst != this.StatusTekst)
            this.SettStatus(tekst)
    }

    static KildeTittel(kilde) => kilde = "web" ? "Trio Web" : "Trio Attendant"
    VerdiNavn(kilde) => StrSplit(this.Cfg[kilde = "web" ? "WebEtikett" : "Etikett"], "|")[1]

    AktiveKilder() {
        switch this.Cfg["TrioKilde"] {
            case "web":       return ["web"]
            case "attendant": return ["attendant"]
        }
        return ["web", "attendant"]
    }

    ; ---------------- Siden i hovedvinduet ----------------
    ByggPanel(gui, x, y, b) {
        Skrift(gui, "s10 c" TEMA.tekst)
        this.Leg(gui.AddText("x" x " y" y " w80 h30 +0x200 Background" TEMA.bg, "Les fra:"))
        mb := (b - 80 - 16) // 3
        for i, par in VT_SMKontakt.Moduser
            this.ModusK[par[1]] := this.Leg(Knapp(gui, "x" (x + 80 + (i - 1) * (mb + 8)) " y" y " w" mb " h30", par[2], ObjBindMethod(this, "VelgModus", par[1]), TEMA.aksent2))
        this.OppdaterModusKnapper()

        ; Live-kort: hva programmet leser fra Trio akkurat nå
        ky := y + 42
        this.Leg(gui.AddText("x" x " y" ky " w" b " h104 Background" TEMA.kort))
        Skrift(gui, "s9 bold c" TEMA.dempet)
        this.LiveKilde := this.Leg(gui.AddText("x" (x + 14) " y" (ky + 10) " w" (b - 28) " h18 Background" TEMA.kort, ""))
        Skrift(gui, "s18 bold c" TEMA.dempet)
        this.LiveVerdi := this.Leg(gui.AddText("x" (x + 14) " y" (ky + 30) " w" (b - 28) " h36 +0x200 Background" TEMA.kort, "—"))
        Skrift(gui, "s9 c" TEMA.dempet)
        this.LiveInfo := this.Leg(gui.AddText("x" (x + 14) " y" (ky + 70) " w" (b - 28) " h30 Background" TEMA.kort, ""))

        Skrift(gui, "s11 bold c" TEMA.tekst)
        this.Leg(Knapp(gui, "x" x " y" (ky + 116) " w" (b - 130) " h44", "Lær oppsett", ObjBindMethod(this, "Laer")))
        Skrift(gui, "s9 c" TEMA.tekst)
        this.Leg(Knapp(gui, "x" (x + b - 120) " y" (ky + 116) " w120 h44", "Avansert…", ObjBindMethod(this, "VisAvansert"), TEMA.aksent2))
        Skrift(gui, "s9 c" TEMA.dempet)
        this.OppsettK := this.Leg(gui.AddText("x" x " y" (ky + 170) " w" b " h48 Background" TEMA.bg, ""))
        this.OppdaterTekster()
        this.VisLive(Map())
    }

    OppdaterModusKnapper() {
        for nokkel, ktrl in this.ModusK {
            ktrl.Opt("Background" (nokkel = this.Cfg["TrioKilde"] ? TEMA.aksent : TEMA.aksent2))
            ktrl.Redraw()
        }
    }

    VelgModus(modus, *) {
        this.SettCfg("TrioKilde", modus)
        this.NullstillTilstand()
        this.StarPa := ""
        this.OppdaterModusKnapper()
        this.OppdaterMusKrok()
        for par in VT_SMKontakt.Moduser
            if (par[1] = modus)
                Logg("SM Kontakt: leser nå fra " par[2])
        this.Sjekk()                                   ; vis med en gang hva som leses
    }

    ErLart() => this.Cfg["SMVindu"] != "" && InStr(this.Cfg["SMVindu"], "Service Manager") && this.Cfg["KontaktX"] != ""

    OppdaterTekster() {
        sm := this.Cfg["KontaktX"] != "" ? VennligNavn(this.Cfg["SMVindu"]) (this.Cfg["KnappX"] != "" ? "  ·  knapp lært" : "  ·  ingen knapp") : "ikke lært ennå – trykk «Lær oppsett»"
        try this.OppsettK.Text := "Service Manager:  " sm
            . "`nTrio Web:  " VennligNavn(this.Cfg["WebVindu"]) "     ·     Trio Attendant:  hurtigkopiering"
    }

    ; Live-kortet: hvilken Trio programmet står på og hva det leser
    VisLive(resultater) {
        if !this.HasOwnProp("LiveVerdi")
            return
        kilder := this.AktiveKilder()
        apne := []
        for k in kilder
            if (resultater.Has(k) && resultater[k].hwnd)
                apne.Push(k)

        ; Hvilken Trio står vi på?  Den som har en verdi / en pågående samtale, ellers den som er åpen.
        valgt := ""
        for k in apne
            if (resultater[k].bruker != "" || this.Tilst[k].Fylt) {
                valgt := k
                break
            }
        if (valgt = "")
            for k in apne
                if (resultater[k].sak != "" && resultater[k].sak != this.Tilst[k].SistSak) {
                    valgt := k
                    break
                }
        if (valgt = "" && this.StarPa != "")
            for k in apne
                if (k = this.StarPa)
                    valgt := k
        if (valgt = "" && apne.Length)
            valgt := apne[1]
        this.StarPa := valgt

        auto := this.Cfg["TrioKilde"] = "auto"
        if (valgt = "") {
            this.LiveKilde.Text := auto ? "FINNER INGEN TRIO" : StrUpper(VT_SMKontakt.KildeTittel(kilder[1])) "  –  IKKE FUNNET"
            this.SettLiveVerdi("—", false)
            this.LiveInfo.Text := auto
                ? "Åpne Trio Web (Trio Agent i Edge) eller Trio Attendant – programmet finner selv den som er åpen."
                : "Fant ikke " VennligNavn(this.Cfg[kilder[1] = "web" ? "WebVindu" : "TrioVindu"])
                    . (kilder[1] = "web" ? ". Trio Agent må være aktiv fane, helst i eget Edge-vindu." : ".")
            return
        }
        les := resultater[valgt], st := this.Tilst[valgt]
        andre := ""
        if auto {
            for k in ["web", "attendant"]
                if (k != valgt)
                    andre := "`n" VT_SMKontakt.KildeTittel(k) ": " (resultater.Has(k) && resultater[k].hwnd ? "åpen" : "ikke åpen")
        }
        this.LiveKilde.Text := (auto ? "STÅR PÅ:  " : "") StrUpper(VT_SMKontakt.KildeTittel(valgt)) "  ●   " StrUpper(this.VerdiNavn(valgt))
        if (les.bruker != "")
            this.SettLiveVerdi(les.bruker, true)
        else
            this.SettLiveVerdi("—", false)
        info := st.Tekst
        if !this.Aktiv
            info := "SM Kontakt er AV – dette er et øyeblikksbilde. Slå på for automatikk."
        else if (!this.ErLart() && valgt = "web")
            info := "Leser fra Trio, men Kontakt-feltet er ikke lært ennå – trykk «Lær oppsett»."
        this.LiveInfo.Text := StrUpper(SubStr(info, 1, 1)) SubStr(info, 2) andre
    }

    SettLiveVerdi(tekst, funnet) {
        this.LiveVerdi.SetFont("c" (funnet ? TEMA.paa : TEMA.dempet))
        this.LiveVerdi.Text := tekst
    }

    Hjelp() {
        modus := this.Cfg["TrioKilde"], tast := this.Cfg["ManuellTast"]
        t := "1.  Trykk «Lær oppsett» og følg stegene. Trykk «Test», så «Lagre».`n"
        if (modus = "web")
            t .= "2.  Ta telefonen i Trio Web – Kontakt fylles inn automatisk.`n"
                . "•  Trio Agent må ligge i et eget Edge-vindu.`n"
        else if (modus = "attendant")
            t .= "2.  Trykk hurtigkopiering (IDM username) i Trio – Kontakt fylles inn.`n"
                . "•  Trykk to ganger raskt for å fylle inn samme navn igjen.`n"
        else
            t .= "2.  Trio Web: fylles inn automatisk når du tar telefonen.`n"
                . "     Trio Attendant: trykk hurtigkopiering i Trio (to ganger raskt = igjen).`n"
        return t "•  " tast " = fyll inn manuelt."
    }

    Start() {
        this.NullstillTilstand()
        SetTimer this.SjekkCb, 500
        this.AktiverTast()
        this.OppdaterMusKrok()
        this.Status(this.ErLart() ? "Venter på samtale i Trio" : "Trykk «Lær oppsett» for å komme i gang")
    }

    Stopp() {
        SetTimer this.SjekkCb, 0
        if (this.AktivTast != "")
            try Hotkey this.AktivTast, "Off"
        this.AktivTast := ""
        this.LaerFerdig()
        this.OppdaterMusKrok()
    }

    ; Museklikk fanges bare under læring (Trio Web, Kontakt-felt og knapp)
    ; Museklikk fanges bare under læring (Trio Web, Kontakt-felt og knapp)
    OppdaterMusKrok() {
        trengs := this.LaerSteg = 1 || this.LaerSteg = 3 || this.LaerSteg = 4
        try Hotkey "~LButton", this.KlikkCb, trengs ? "On" : "Off"
    }

    MusKlikk(*) {
        if (this.LaerSteg >= 1 && this.LaerSteg <= 4)
            this.LaerKlikk()
    }

    ; ---------------- Trio Attendant: hurtigkopiering ----------------
    ; Kalles hver gang utklippstavlen endres. Er det Trio som kopierte, startes automatikken
    ; (etter et lite øyeblikk, for å se om det ble trykket to ganger raskt).
    KlippEndret(type, *) {
        this.KlippTid := A_TickCount
        if (type != 1)                                 ; bare tekst
            return
        pid := KlippEierPid()
        if (pid && pid = ProcessExist())               ; vår egen kopi (f.eks. Tekstflyt) – ignorer
            return
        if (this.LaerSteg = 1)
            return this.LaerKopi(pid)
        ; IM / telefonnummer fra Trio Snarveier skal ikke tolkes som brukernavn.
        ; v3.4 viser varselet direkte fra KopierMedFelt().
        if (TrioKopiMerke() != "")
            return
        if (!this.Aktiv || this.Cfg["TrioKilde"] = "web" || this.LaerSteg)
            return
        if !this.ErFraTrio(pid)
            return
        if (IsObject(this.Ventende) && A_TickCount - this.Ventende.tid <= this.DobbelTid) {
            this.Ventende.dobbel := true               ; andre trykk raskt etter det første
            return
        }
        this.Ventende := {tid: A_TickCount, dobbel: false}
        SetTimer this.KopiCb, -this.DobbelTid
    }

    ; Kom kopien fra Trio Attendant?
    ErFraTrio(pid) {
        exe := this.TrioExe()
        if (exe = "")
            return false
        if pid {
            navn := ""
            try navn := ProcessGetName(pid)
            return navn = exe
        }
        return WinActive("ahk_exe " exe) != 0          ; ukjent eier: godta hvis Trio er det aktive vinduet
    }

    TrioExe() {
        if RegExMatch(this.Cfg["TrioVindu"], "i)ahk_exe\s+(\S+)", &m)
            return m[1]
        hwnd := FinnVindu(this.Cfg["TrioVindu"])
        try return hwnd ? WinGetProcessName("ahk_id " hwnd) : ""
        return ""
    }

    KopiFerdig() {
        v := this.Ventende
        if !IsObject(v)
            return
        this.Ventende := ""
        st := this.Tilst["attendant"]
        st.TekstTid := A_TickCount                     ; meldingen blir stående en stund på siden
        verdi := ""
        try verdi := Trim(A_Clipboard, " `t`r`n")
        if ErTelefonnummer(verdi) {
            st.Tekst := "telefonnummer kopiert – ikke fylt inn", st.KopiertTid := 0
            Varsel("Trio Attendant · Telefonnummer", KortVerdi(verdi), "Telefonnummer kopiert – ikke fylt inn", false)
            return this.Sjekk()
        }
        if !ErBrukernavn(verdi) {
            st.Tekst := "kopiert verdi er ikke et brukernavn – ikke fylt inn", st.KopiertTid := 0
            Varsel("Trio Attendant", "—", "Det som ble kopiert er ikke et brukernavn", false)
            return this.Sjekk()
        }
        if (verdi = st.SistKopiert && !v.dobbel) {     ; samme brukernavn i samme samtale – bare én gang
            st.KopiertTid := A_TickCount
            st.Tekst := "allerede fylt inn (trykk to ganger raskt = fyll inn igjen)"
            Varsel("Trio Attendant", verdi, "Allerede fylt inn  (trykk 2 ganger raskt = igjen)", false)
            return this.Sjekk()
        }
        st.SistKopiert := verdi, st.KopiertTid := A_TickCount
        if !this.ErLart() {
            st.Tekst := "Kontakt-feltet er ikke lært – trykk «Lær oppsett»"
            Varsel("Trio Attendant", verdi, "Kontakt-feltet er ikke lært – «Lær oppsett»", false)
            return this.Sjekk()
        }
        Logg("SM Kontakt: hurtigkopiering i Trio Attendant – " verdi (v.dobbel ? " (to trykk – fyller inn igjen)" : ""))
        Varsel("Trio Attendant", verdi, "→ fylles inn i Service Manager")
        ok := this.Fyll(verdi, "attendant")
        st.Fylt := ok
        st.Tekst := ok ? "fylt inn i Service Manager " FormatTime(, "HH:mm:ss") " ✓" : "innfylling feilet – se Logg"
        this.Sjekk()
    }


    ; IM og telefonnummer hører til Trio Snarveier, ikke SM Kontakt.
    ; Trio Attendant: sist kopierte brukernavn vises til et nytt kopieres, eller i maks 10 minutter 

    LesAttendantKopi() {
        st := this.Tilst["attendant"]
        vis := st.SistKopiert != "" && A_TickCount - st.KopiertTid < 600000
        return {kilde: "attendant", bruker: vis ? st.SistKopiert : "", tekst: "", nokkel: "", sak: "", tomSide: false
            , hwnd: FinnVindu(this.Cfg["TrioVindu"]), metode: "hurtigkopiering"}
    }

    ; Varsel om Trio Web-innfylling (samme lille vindu som for Attendant)
    VarselWeb(verdi) => Varsel("Trio Web", verdi, "→ fylles inn i Service Manager")

    AktiverTast() {
        if (this.AktivTast != "")
            try Hotkey this.AktivTast, "Off"
        this.AktivTast := ""
        tast := this.Cfg["ManuellTast"]
        if (tast = "")
            return
        try {
            Hotkey tast, this.ManuellCb, "On"
            this.AktivTast := tast
        } catch as feil {
            Logg("SM Kontakt: kan ikke bruke tasten «" tast "»: " feil.Message)
        }
    }

    ; ---------------- Lese Trio ----------------
    LesKilde(kilde, alle := false) => kilde = "web" ? this.LesWeb() : this.LesAttendantKopi()

    ; Trio Web (Trio Agent i Edge): leser nettsiden via UI Automation – virker også når vinduet ligger bak andre
    LesWeb() {
        res := {kilde: "web", bruker: "", tekst: "", nokkel: "", hwnd: 0, sak: "", tomSide: true, metode: "nettsiden"}
        hwnd := FinnVindu(this.Cfg["WebVindu"], false)
        res.hwnd := hwnd
        if !hwnd
            return res
        try res.sak := WebSak(UiaAdresse(hwnd))
        tekst := ""
        try tekst := UiaDokTekst(hwnd)
        res.tekst := tekst
        res.tomSide := StrLen(Trim(tekst, " `t`r`n")) < 20
        bruker := FinnBrukernavn(tekst, this.Cfg["WebEtikett"])
        if (bruker = "")
            return res
        res.bruker := bruker
        res.nokkel := bruker "|" (res.sak != "" ? res.sak : FinnTlf(tekst))
        return res
    }

    ; Trio Web: hent Trio-vinduet kort fram og les igjen (når siden ikke kan leses i bakgrunnen)
    LesWebMedFokus(hwnd) {
        forrige := WinExist("A")
        try {
            WinActivate "ahk_id " hwnd
            WinWaitActive "ahk_id " hwnd, , 1
        }
        Sleep 500
        les := this.LesWeb()
        if (les.bruker = "" && forrige && forrige != hwnd)
            try WinActivate "ahk_id " forrige
        return les
    }

    ; Trio Attendant (program): prøver flere lesemåter og husker den som virket
    LesAttendant(alle := false) {
        res := {kilde: "attendant", bruker: "", tekst: "", nokkel: "", hwnd: 0, sak: "", tomSide: false, metode: ""}
        hwnd := FinnVindu(this.Cfg["TrioVindu"])
        res.hwnd := hwnd
        if !hwnd
            return res
        metoder := ["kontroll", "html", "vindu", "uia"]
        if (this.AttMetode != "") {
            sortert := [this.AttMetode]
            for m in metoder
                if (m != this.AttMetode)
                    sortert.Push(m)
            metoder := sortert
        }
        for metode in metoder {
            if (metode = "uia" && !alle && this.AttMetode != "uia") {      ; tregeste metode – maks hvert 4. sekund
                if (A_TickCount - this.SistFullSok < 4000)
                    continue
                this.SistFullSok := A_TickCount
            }
            tekst := ""
            try tekst := this.LesMetode(metode, hwnd)
            if (Trim(tekst, " `t`r`n") = "")
                continue
            bruker := FinnBrukernavn(tekst, this.Cfg["Etikett"])
            if (bruker = "")
                continue
            this.AttMetode := metode
            res.bruker := bruker, res.tekst := tekst, res.metode := VT_SMKontakt.MetodeNavn[metode]
            res.nokkel := bruker "|" FinnTlf(tekst)
            return res
        }
        return res
    }

    LesMetode(metode, hwnd) {
        switch metode {
            case "kontroll":
                if (this.Cfg["TrioKontroll"] = "")
                    return ""
                chwnd := 0
                try chwnd := ControlGetHwnd(this.Cfg["TrioKontroll"], "ahk_id " hwnd)
                return chwnd ? KontrollTekst(chwnd) : ""
            case "html":
                tekst := ""
                for c in WinGetControlsHwnd("ahk_id " hwnd)
                    if InStr(KlasseNavn(c), "Internet Explorer_Server")
                        tekst .= IeTekst(c) "`n"
                return tekst
            case "vindu":
                return WinGetText("ahk_id " hwnd)
            case "uia":
                return UiaTekst(hwnd)
        }
        return ""
    }

    ErAndreLinje(les) {
        uttrykk := this.Cfg["AndreLinjeRegex"]
        if (uttrykk = "")
            return false
        alt := les.tekst
        try alt .= "`n" WinGetTitle("ahk_id " les.hwnd)
        if (les.kilde = "attendant")
            try alt .= "`n" WinGetText("ahk_id " les.hwnd)
        return ProvRegex(alt, uttrykk)
    }

    ; ---------------- Automatikken ----------------
    ; Kjører to ganger i sekundet. Hver Trio-kilde har sin egen tilstand, så samme samtale håndteres bare én gang.
    Sjekk() {
        if this.LaerSteg
            return
        kanFylle := this.Aktiv && this.ErLart()
        resultater := Map()
        for kilde in this.AktiveKilder() {
            st := this.Tilst[kilde]
            if (kilde = "attendant") {                 ; Trio Attendant: startes av hurtigkopiering (se KlippEndret)
                if (st.SistKopiert != "" && A_TickCount - st.KopiertTid > 600000)
                    st.SistKopiert := "", st.Fylt := false         ; glem navnet etter 10 min
                les := this.LesAttendantKopi()
                resultater[kilde] := les
                if (les.hwnd && les.bruker = "" && A_TickCount - st.TekstTid > 8000)
                    st.Tekst := "trykk hurtigkopiering i Trio for å fylle inn", st.Fylt := false
                continue
            }
            les := this.LesKilde(kilde)
            if !les.hwnd {
                resultater[kilde] := les
                continue
            }
            handling := this.Vurder(kilde, st, &les)
            resultater[kilde] := les
            if (handling = "fyll") {
                if kanFylle {
                    Logg("SM Kontakt: ny samtale i " VT_SMKontakt.KildeTittel(kilde) " – " this.VerdiNavn(kilde) " " les.bruker)
                    this.VarselWeb(les.bruker)
                    ok := this.Fyll(les.bruker, kilde)
                    st.Fylt := ok
                    st.Tekst := ok ? "fylt inn i Service Manager " FormatTime(, "HH:mm:ss") " ✓" : "innfylling feilet – se Logg"
                } else {
                    st.Tekst := "lest – fylles ikke inn (" (this.Aktiv ? "Kontakt-feltet er ikke lært" : "SM Kontakt er AV") ")"
                }
            }
        }
        this.VisLive(resultater)
        if (this.StarPa = "" || !resultater.Has(this.StarPa)) {
            this.Status(this.Cfg["TrioKilde"] = "auto" ? "Finner ingen Trio" : VT_SMKontakt.KildeTittel(this.AktiveKilder()[1]) ": ikke åpen")
            return
        }
        les := resultater[this.StarPa], st := this.Tilst[this.StarPa]
        this.Status(VT_SMKontakt.KildeTittel(this.StarPa) ": " (les.bruker != "" ? les.bruker " – " : "") st.Tekst)
    }

    ; Avgjør om automatikken skal starte for denne lesingen. Returnerer "fyll" eller "".
    Vurder(kilde, st, &les) {
        naa := A_TickCount
        navn := this.VerdiNavn(kilde)
        tast := this.Cfg["ManuellTast"]

        ; Trio Web: ny samtale (ny sak i adressen) – husk når den startet og hvordan siden så ut rett før
        if (les.sak != "" && les.sak != st.SakSett) {
            st.SakSett := les.sak, st.SakTid := naa, st.TekstFor := st.SisteTekst
            st.FokusForsok := 0, st.SisteFokus := 0, st.Fylt := false
        }
        nySak := (kilde = "web" && les.sak != "" && les.sak != st.SistSak && !st.ForsteSjekk)
        alder := naa - st.SakTid

        if nySak {
            ; Les normalt Trio Web i bakgrunnen slik v2.8 gjorde.
            ; Ikke stjel fokus fra video/bruker automatisk; fallback må eksplisitt tillates i INI.
            if (this.Hent("TillatTrioFokus", "0") = "1"
                && this.WebUtdatert(st, les) && alder <= this.Ventetid && alder > 1200
                && st.FokusForsok < 3 && naa - st.SisteFokus > 2500) {
                st.FokusForsok += 1, st.SisteFokus := naa
                ny := this.LesWebMedFokus(les.hwnd)
                Logg("SM Kontakt: Trio Web var ikke lesbar i bakgrunnen – hentet vinduet fram kort (forsøk " st.FokusForsok ")"
                    . (ny.bruker != "" ? " – fant " ny.bruker : ""))
                if (ny.hwnd && !this.WebUtdatert(st, ny))
                    les := ny
            }
            if this.WebUtdatert(st, les)
                les.bruker := ""                       ; ikke stol på en side som ikke er oppdatert
        }
        st.SisteTekst := les.tekst

        if (les.bruker = "") {                         ; ingen verdi = ingen automatikk
            if nySak {
                if (alder <= this.Ventetid) {
                    st.Tekst := "samtale startet – venter på " navn "…"
                } else {
                    if (st.GittOpp != les.sak) {
                        st.GittOpp := les.sak
                        Logg("SM Kontakt: ingen " navn " innen " this.Ventetid // 1000 " sek – ikke fylt inn")
                    }
                    st.Tekst := "ingen " navn " innen " this.Ventetid // 1000 " sek – ikke fylt inn (" tast " fyller inn)"
                }
                return ""
            }
            if !st.TomSiden
                st.TomSiden := naa
            else if (naa - st.TomSiden > 3000)
                st.SistNokkel := ""
            st.ForsteSjekk := false
            if !(kilde = "web" && les.sak != "" && les.sak = st.SistSak)
                st.Tekst := "venter på samtale", st.Fylt := false
            return ""
        }
        st.TomSiden := 0
        if st.ForsteSjekk {                            ; samtalen pågikk allerede da verktøyet startet
            st.ForsteSjekk := false
            st.SistNokkel := les.nokkel, st.ForrigeHandtert := les.nokkel, st.SistTid := naa
            st.SistSak := les.sak, st.ForrigeVerdi := les.bruker
            st.Tekst := "samtalen pågikk allerede – ikke fylt inn (" tast " fyller inn)"
            return ""
        }
        if (les.nokkel = st.SistNokkel)                ; samme samtale – allerede håndtert
            return ""
        if (kilde = "web" && les.sak != "" && les.sak = st.SistSak)
            return ""                                  ; Trio Web: denne samtalen er allerede håndtert – aldri to ganger
        if (nySak && alder > this.Ventetid) {          ; kom for sent – ikke dra brukeren ut av samtalen
            st.SistNokkel := les.nokkel, st.SistSak := les.sak
            st.Tekst := navn " kom etter " this.Ventetid // 1000 " sek – ikke fylt inn (" tast " fyller inn)"
            Logg("SM Kontakt: " navn " " les.bruker " kom etter " this.Ventetid // 1000 " sek – ikke fylt inn")
            return ""
        }
        st.SistNokkel := les.nokkel
        if (les.nokkel = st.ForrigeHandtert && naa - st.SistTid < 20000)
            return ""
        st.ForrigeHandtert := les.nokkel, st.SistTid := naa, st.SistSak := les.sak, st.ForrigeVerdi := les.bruker
        if this.ErAndreLinje(les) {
            st.Tekst := "2. linje – ikke fylt inn"
            Logg("SM Kontakt: 2. linje-samtale – hoppet over " les.bruker)
            return ""
        }
        return "fyll"
    }

    ; Trio Web-siden er ikke til å stole på: tom, eller uendret fra før samtalen med forrige samtales verdi
    WebUtdatert(st, les) => les.tomSide || (les.bruker != "" && les.bruker = st.ForrigeVerdi && les.tekst == st.TekstFor)

    ; ---------------- Fylle inn i Service Manager ----------------
    ; Fyller inn Kontakt i Service Manager.
    ; SIKKERHET: klikker og skriver bare når Service Manager er aktivt OG ligger under musa.
    ; Aldri mens Trio er aktivt. Ellers avbrytes alt, uten at noe er klikket eller skrevet.
    Fyll(bruker, kilde := "") {
        bruker := Trim(bruker)
        if (bruker = "")                               ; aldri fyll inn en tom verdi
            return false
        if (this.Cfg["KontaktX"] = "")
            return false
        Critical
        VentTasterSluppet(2000)                        ; tastene fra hurtigkopieringen må være sluppet
        trioHwnd := (kilde = "web") ? FinnVindu(this.Cfg["WebVindu"], false) : 0
        CoordMode "Mouse", "Screen"
        MouseGetPos &mx, &my

        smHwnd := 0
        loop 3 {                                       ; Trio kan ta fokus – prøv opptil 3 ganger
            h := AktiverFane(this.Cfg["SMVindu"], false)  ; SM Kontakt skal aldri bla gjennom urelaterte Edge-faner
            if h {
                Sleep 300
                if this.ErTrygt(h) {
                    smHwnd := h
                    break
                }
            }
            Logg("SM Kontakt: fyll – Service Manager ble ikke aktiv (forsøk " A_Index "), aktivt vindu: " AktivtVinduNavn())
            Sleep 400
        }
        if !smHwnd
            return this.FyllAvbrutt(bruker, "fant ikke Service Manager, eller et annet vindu tok fokus")
        Logg("SM Kontakt: fyll – Service Manager er aktiv")
        if (trioHwnd && smHwnd = trioHwnd) {
            Logg("SM Kontakt: Trio Agent og Service Manager er i samme Edge-vindu – flytt Trio Agent til et eget vindu, ellers kan ikke Trio leses i bakgrunnen")
            Tip("Tips: Dra Trio Agent-fanen ut i et eget Edge-vindu,`nså kan programmet lese den i bakgrunnen.", 5000)
        }

        if !this.TryggKlikk(smHwnd, this.Cfg["KontaktX"], this.Cfg["KontaktY"])
            return this.FyllAvbrutt(bruker, "før klikk i Kontakt-feltet")
        Logg("SM Kontakt: fyll – klikket i Kontakt-feltet")
        Sleep 150
        if !this.ErTrygt(smHwnd)
            return this.FyllAvbrutt(bruker, "før Ctrl+A")
        Send "^a"
        Sleep 50
        if !this.ErTrygt(smHwnd)
            return this.FyllAvbrutt(bruker, "før brukernavnet ble skrevet")
        SendText bruker
        Logg("SM Kontakt: fyll – skrev " bruker)
        if (this.Cfg["KnappX"] != "") {
            Sleep 200
            if !this.TryggKlikk(smHwnd, this.Cfg["KnappX"], this.Cfg["KnappY"])
                return this.FyllAvbrutt(bruker, "før klikk på knappen ved siden av Kontakt")
            Logg("SM Kontakt: fyll – klikket knappen ved siden av Kontakt")
        }
        CoordMode "Mouse", "Screen"
        MouseMove mx, my, 0
        Logg("SM Kontakt: fylte inn " bruker)
        return true
    }

    ; Trygt å klikke/skrive?  Service Manager må være aktivt, og Trio må IKKE være aktivt.
    ErTrygt(smHwnd) {
        if !WinActive("ahk_id " smHwnd)
            return false
        ; Riktig Edge-vindu er ikke nok: avbryt hvis aktiv fane er f.eks. YouTube.
        if RegExMatch(this.Cfg["SMVindu"], "i)^(.*?)\s+ahk_exe\s+(msedge|chrome|firefox|brave|opera)\.exe", &sm) {
            if (!InStr(Trim(sm[1]), "Service Manager")
                || !NettleserFaneBekreftet(smHwnd, Trim(sm[1])))
                return false
        }
        exe := this.TrioExe()
        if (exe != "" && WinActive("ahk_exe " exe))
            return false
        return true
    }

    ; Klikker på et punkt i Service Manager – bare hvis det er Service Manager som ligger under punktet
    TryggKlikk(smHwnd, kx, ky) {
        if !this.ErTrygt(smHwnd)
            return false
        WinGetClientPos &wx, &wy, , , "ahk_id " smHwnd
        sx := wx + kx, sy := wy + ky
        under := DllCall("WindowFromPoint", "Int64", (sy << 32) | (sx & 0xFFFFFFFF), "Ptr")
        rot := under ? DllCall("GetAncestor", "Ptr", under, "UInt", 2, "Ptr") : 0     ; GA_ROOT
        if (rot != smHwnd) {
            navn := ""
            try navn := WinGetTitle("ahk_id " rot) " (" WinGetProcessName("ahk_id " rot) ")"
            Logg("SM Kontakt: fyll – et annet vindu ligger over Service Manager der det skal klikkes: " navn)
            return false
        }
        CoordMode "Mouse", "Screen"
        Click sx, sy
        return true
    }

    FyllAvbrutt(bruker, hvor) {
        CoordMode "Mouse", "Screen"
        Logg("SM Kontakt: AVBRUTT – " hvor ". Ingenting ble klikket eller skrevet videre. Aktivt vindu: " AktivtVinduNavn())
        Varsel("Avbrutt", bruker, "Service Manager var ikke aktiv – ingenting ble klikket", false)
        return false
    }

    ManuellFyll(*) {
        bruker := "", kilde := ""
        for k in this.AktiveKilder() {
            les := this.LesKilde(k, true)
            if (les.bruker != "") {
                bruker := les.bruker, kilde := k
                break
            }
        }
        if (bruker = "") {
            klipp := Trim(A_Clipboard)
            if (klipp != "" && !RegExMatch(klipp, "\s") && StrLen(klipp) <= 60)
                bruker := klipp
        }
        if (bruker = "")
            return Tip("Fant ikke kundenummer/brukernavn i Trio eller på utklippstavlen")
        if !this.ErLart()
            return Tip("Kontakt-feltet er ikke lært – trykk «Lær oppsett» først")
        if this.Fyll(bruker, kilde) && kilde != "" {
            this.Tilst[kilde].Fylt := true
            this.Tilst[kilde].Tekst := "fylt inn manuelt " FormatTime(, "HH:mm:ss") " ✓"
        }
    }

    ; ---------------- Lær oppsett ----------------
    ; Steg 1: Trio (Web: klikk på kundenummeret · Attendant: trykk hurtigkopiering)
    ; Steg 3: Kontakt-feltet · Steg 4: knappen ved siden av · Steg 5: Test og Lagre   (steg 2 finnes ikke lenger)
    Laer(*) {
        this.LaerSteg := 1
        this.LaerInfo := ""
        this.LaerKilde := ""
        this.LaerVerdi := ""
        this.Ny := Map()
        this.OppdaterMusKrok()
        Hotkey "Esc", this.AvbrytCb, "On"
        SetTimer this.TipsCb, 100
        Logg("SM Kontakt: læring startet")
    }

    LaerTips() {
        if (this.LaerSteg < 1 || this.LaerSteg > 4)
            return
        modus := this.Cfg["TrioKilde"]
        antall := 3
        nr := this.LaerSteg >= 3 ? this.LaerSteg - 1 : this.LaerSteg
        steg1 := modus = "web" ? "Klikk på KUNDENUMMERET i Trio Web."
            : modus = "attendant" ? "Trykk HURTIGKOPIERING i Trio (IDM username)."
            : "Klikk på KUNDENUMMERET i Trio Web`n– eller trykk HURTIGKOPIERING i Trio Attendant."
        tekster := [
            steg1,
            "",
            "Klikk i KONTAKT-feltet i Service Manager.",
            "Klikk på KNAPPEN ved siden av Kontakt-feltet.`n(Esc = ingen knapp)"
        ]
        ToolTip "Lær oppsett – steg " nr (antall != "" ? " av " antall : "") "`n" tekster[this.LaerSteg]
            . (this.LaerInfo != "" ? "`n`n" this.LaerInfo : "") ((this.LaerSteg = 1 || this.LaerSteg = 3) ? "`n(Esc = avbryt)" : "")
    }

    ; Steg 1 for Trio Attendant: hurtigkopiering ble trykket
    LaerKopi(pid) {
        if (this.Cfg["TrioKilde"] = "web")
            return
        hwnd := 0
        if pid {
            hwnd := WinExist("Trio ahk_pid " pid)
            if !hwnd
                hwnd := WinExist("ahk_pid " pid)
        } else {
            hwnd := WinExist("A")
        }
        if (!hwnd || ErNettleser(hwnd) || WinGetPID("ahk_id " hwnd) = ProcessExist())
            return
        verdi := ""
        try verdi := Trim(A_Clipboard, " `t`r`n")
        this.Ny["TrioVindu"] := VindusId(hwnd)
        this.LaerKilde := "attendant"
        this.LaerVerdi := ErBrukernavn(verdi) ? verdi : ""
        this.LaerInfo := "Trio Attendant: " (this.LaerVerdi != "" ? "fant brukernavn " this.LaerVerdi "  ✔"
            : "kopiert – men ingen brukernavn (greit hvis ingen samtale pågår)")
        this.LaerSteg := 3
        this.OppdaterMusKrok()
    }

    LaerKlikk(*) {
        if (this.LaerSteg < 1 || this.LaerSteg > 4)
            return
        try {
            this.LaerKlikkSteg()
        } catch as feil {
            Logg("SM Kontakt: feil under læring: " feil.Message)
        }
    }

    LaerKlikkSteg() {
        CoordMode "Mouse", "Screen"
        MouseGetPos &sx, &sy, &win
        if (!win || WinGetPID("ahk_id " win) = ProcessExist())
            return                                    ; klikk i dette programmet teller ikke
        WinGetClientPos &cx, &cy, , , "ahk_id " win
        ox := sx - cx, oy := sy - cy

        if (this.LaerSteg = 1) {
            if (!ErNettleser(win) || this.Cfg["TrioKilde"] = "attendant")
                return                                ; Trio Attendant læres med hurtigkopiering (se LaerKopi)
            this.Ny["WebVindu"] := VindusId(win)
            this.LaerKilde := "web"
            this.LaerInfo := "Trio Web: " WinGetTitle("ahk_id " win)
            this.LaerSteg := 3                        ; ingen legg på-knapp for Trio Web
        } else if (this.LaerSteg = 3) {
            ; Bruk en stabil Service Manager-identifikator, ikke Edge sin tilfeldige fanetittel.
            ; Stopper læring hvis det er YouTube eller en annen side som er aktiv.
            if ErNettleser(win) {
                if !NettleserFaneBekreftet(win, "Service Manager") {
                    Logg("SM Kontakt: læring – klikket i Edge, men kunne ikke bekrefte Service Manager-fanen")
                    Tip("Fant ikke bekreftet Service Manager-fane. Åpne SM 02 og klikk i Kontakt-feltet.", 4200)
                    return
                }
                smId := "Service Manager ahk_exe " WinGetProcessName("ahk_id " win)
            } else {
                smId := VindusId(win)
                if !InStr(smId, "Service Manager") {
                    Tip("Dette ser ikke ut som Service Manager. Klikk i riktig Kontakt-felt.", 4000)
                    return
                }
            }
            this.Ny["SMVindu"] := smId, this.Ny["KontaktX"] := ox, this.Ny["KontaktY"] := oy
            this.SmHwnd := win
            this.LaerInfo .= "`nService Manager: " smId
            this.LaerSteg := 4
        } else if (this.LaerSteg = 4) {
            if (win != this.SmHwnd)
                return
            this.Ny["KnappX"] := ox, this.Ny["KnappY"] := oy
            this.LaerTestVindu()
        }
    }

    LaerEsc(*) {
        if (this.LaerSteg = 4) {               ; ingen knapp
            this.Ny["KnappX"] := "", this.Ny["KnappY"] := ""
            this.LaerTestVindu()
        } else {
            this.LaerFerdig()
            Tip("Læring avbrutt – ingenting er endret")
        }
    }

    ; Steg 5: vis hva som er lært og brukernavnet fra Trio – Test, så Lagre
    LaerTestVindu() {
        SetTimer this.TipsCb, 0
        try Hotkey "Esc", "Off"
        ToolTip
        this.LaerSteg := 5
        this.OppdaterMusKrok()
        this.Testet := false

        if (this.LaerKilde = "attendant") {
            lest := {bruker: this.LaerVerdi, hwnd: 1}
        } else {
            lest := this.MedNyttOppsett(() => this.LesKilde(this.LaerKilde, true))
        }
        this.TestVerdi := lest.bruker != "" ? lest.bruker : "test123"
        att := this.LaerKilde = "attendant"

        tv := Gui("+Owner" HOVED.Hwnd " -MinimizeBox", "Lær oppsett – test før du lagrer")
        this.TestVindu := tv
        tv.BackColor := TEMA.bg
        tv.OnEvent("Close", ObjBindMethod(this, "LaerAvbryt"))
        Skrift(tv, "s13 bold c" TEMA.tekst)
        tv.AddText("x20 y16 w520 Background" TEMA.bg, "Test oppsettet før du lagrer")
        Skrift(tv, "s10 c" TEMA.tekst)
        trioLinje := att
            ? "Trio Attendant:   " VennligNavn(this.Ny["TrioVindu"]) "  ·  hurtigkopiering"
            : "Trio Web:   " VennligNavn(this.Ny["WebVindu"])
        tv.AddText("x20 y52 w520 Background" TEMA.bg
            , trioLinje
            . "`nService Manager:   " VennligNavn(this.Ny["SMVindu"])
            . "`nKnapp ved siden av Kontakt:   " (this.Ny["KnappX"] != "" ? "lært" : "ingen"))
        Skrift(tv, "s9 bold c" TEMA.dempet)
        tv.AddText("x20 y132 w520 Background" TEMA.bg, att ? "BRUKERNAVN FRA TRIO" : "LESER " StrUpper(this.VerdiNavn(this.LaerKilde)) " FRA TRIO NÅ")
        Skrift(tv, "s18 bold c" (lest.bruker != "" ? TEMA.paa : TEMA.dempet))
        tv.AddText("x20 y150 w520 h34 Background" TEMA.bg, lest.bruker != "" ? lest.bruker : "—")
        Skrift(tv, "s9 c" TEMA.dempet)
        tv.AddText("x20 y188 w520 h18 Background" TEMA.bg, lest.bruker != ""
            ? "«Test» fyller inn «" lest.bruker "» i Kontakt-feltet i Service Manager."
            : "Ingen verdi fra Trio nå – «Test» fyller inn «test123» i stedet.")
        Skrift(tv, "s11 bold c" TEMA.tekst)
        Knapp(tv, "x20 y238 w160 h42", "Test", ObjBindMethod(this, "LaerTest"))
        this.LagreK := Knapp(tv, "x190 y238 w160 h42", "Lagre", ObjBindMethod(this, "LaerLagre"), TEMA.av)
        Skrift(tv, "s10 c" TEMA.tekst)
        Knapp(tv, "x400 y238 w140 h42", "Avbryt", ObjBindMethod(this, "LaerAvbryt"), TEMA.aksent2)
        Skrift(tv, "s10 bold c" TEMA.dempet)
        this.TestMeldingK := tv.AddText("x20 y292 w520 h40 Background" TEMA.bg, "Trykk «Test» først – «Lagre» blir tilgjengelig etterpå.")
        tv.Show("w560 h344")
    }

    ; Kjører en funksjon med det nye (ulagrede) oppsettet, og setter det gamle tilbake etterpå
    MedNyttOppsett(funksjon) {
        gammel := this.Cfg, gammelMetode := this.AttMetode
        ny := gammel.Clone()
        for nokkel, verdi in this.Ny
            ny[nokkel] := verdi
        this.Cfg := ny, this.AttMetode := ""
        try {
            return funksjon()
        } finally {
            this.Cfg := gammel, this.AttMetode := gammelMetode
        }
    }

    LaerTest(*) {
        this.TestMeldingK.SetFont("c" TEMA.dempet)
        this.TestMeldingK.Text := "Tester…"
        ok := this.MedNyttOppsett(() => this.Fyll(this.TestVerdi))
        try WinActivate "ahk_id " this.TestVindu.Hwnd
        if ok {
            this.Testet := true
            this.LagreK.Opt("Background" TEMA.paa)
            this.LagreK.Redraw()
            this.TestMeldingK.SetFont("c" TEMA.paa)
            this.TestMeldingK.Text := "✓  Testen er kjørt. Står «" this.TestVerdi "» i Kontakt-feltet i Service Manager? Trykk «Lagre»."
        } else {
            this.TestMeldingK.SetFont("c" "FF6B6B")
            this.TestMeldingK.Text := "✗  Fant ikke Service Manager-fanen. Er den åpen i Edge? Trykk «Test» igjen, eller «Avbryt» og lær på nytt."
        }
    }

    LaerLagre(*) {
        if !this.Testet {
            this.TestMeldingK.SetFont("c" "FF6B6B")
            this.TestMeldingK.Text := "Trykk «Test» først, så du vet at det virker."
            return
        }
        for nokkel, verdi in this.Ny
            this.SettCfg(nokkel, verdi)
        try this.TestVindu.Destroy()
        this.TestVindu := ""
        this.AttMetode := ""
        this.LaerSteg := 0
        this.OppdaterTekster()
        this.NullstillTilstand()
        this.OppdaterMusKrok()
        Logg("SM Kontakt: oppsett lært og lagret (SM: " this.Cfg["SMVindu"] ")")
        Tip("Oppsettet er lagret ✓", 2500)
        this.Sjekk()
    }

    LaerAvbryt(*) {
        try this.TestVindu.Destroy()
        this.TestVindu := ""
        this.LaerSteg := 0
        this.OppdaterMusKrok()
        Tip("Læring avbrutt – det gamle oppsettet er beholdt")
    }

    LaerFerdig() {
        if !this.LaerSteg
            return
        this.LaerSteg := 0
        SetTimer this.TipsCb, 0
        try Hotkey "Esc", "Off"
        ToolTip
        if IsObject(this.TestVindu)
            try this.TestVindu.Destroy()
        this.OppdaterMusKrok()
    }

    KopierDiagnose(*) {
        d := APP_NAVN " " APP_VERSJON " – diagnose SM Kontakt`r`n"
        for nokkel in ["TrioKilde", "WebVindu", "WebEtikett", "TrioVindu", "SMVindu"]
            d .= nokkel " = " this.Cfg[nokkel] "`r`n"
        d .= "Trio-program: " this.TrioExe() "`r`n"

        d .= "`r`n===== TRIO WEB =====`r`n"
        hwnd := FinnVindu(this.Cfg["WebVindu"], false)
        if hwnd {
            d .= "Vindu: " WinGetTitle("ahk_id " hwnd) "  |  " WinGetProcessName("ahk_id " hwnd) "`r`n"
            adresse := ""
            try adresse := UiaAdresse(hwnd)
            d .= "Adresse: " adresse "  ->  sak: " WebSak(adresse) "`r`n"
            tekst := ""
            try tekst := UiaDokTekst(hwnd)
            d .= "Kundenummer funnet: «" FinnBrukernavn(tekst, this.Cfg["WebEtikett"]) "»   (" StrLen(tekst) " tegn lest)`r`n"
            d .= SubStr(RegExReplace(tekst, "\d{5,}", "#####"), 1, 2500) "`r`n"
        } else {
            d .= "Fant ikke vinduet. Edge-vinduer: "
            try {
                for w in WinGetList("ahk_exe msedge.exe")
                    if (WinGetTitle("ahk_id " w) != "")
                        d .= "«" WinGetTitle("ahk_id " w) "»  "
            }
            d .= "`r`n"
        }

        d .= "`r`n===== TRIO ATTENDANT =====`r`n"
        hwnd := FinnVindu(this.Cfg["TrioVindu"])
        if hwnd {
            d .= "Vindu: " WinGetTitle("ahk_id " hwnd) "  |  " WinGetProcessName("ahk_id " hwnd) "  |  " WinGetClass("ahk_id " hwnd) "`r`n"
            kontroller := ""
            try {
                for navn in WinGetControls("ahk_id " hwnd) {
                    if (A_Index > 80)
                        break
                    kontroller .= navn ", "
                }
            }
            d .= "Kontroller: " kontroller "`r`n"
            for metode in ["kontroll", "html", "vindu", "uia"] {
                tekst := ""
                try tekst := this.LesMetode(metode, hwnd)
                d .= "----- " metode " (" StrLen(tekst) " tegn) – brukernavn: «" FinnBrukernavn(tekst, this.Cfg["Etikett"]) "» -----`r`n"
                d .= SubStr(RegExReplace(tekst, "\d{5,}", "#####"), 1, 1200) "`r`n"
            }
        } else {
            d .= "Fant ikke vinduet.`r`n"
        }
        A_Clipboard := d
        Tip("Diagnosen er kopiert – lim den inn i chatten.", 3000)
    }

    ; ---------------- Avanserte innstillinger ----------------
    VisAvansert(*) {
        felter := [
            ["WebVindu",        "Trio Web – vindu (tekst i fanens tittel + ahk_exe msedge.exe)"],
            ["WebEtikett",      "Trio Web – ledetekst foran verdien som skal hentes (flere skilles med |)"],
            ["TrioVindu",       "Trio Attendant – vindu (del av vindustittelen)"],
            ["Etikett",         "Trio Attendant – ledetekst foran brukernavnet (flere skilles med |)"],
            ["SMVindu",         "Service Manager-fanen (tekst i fanens tittel + ahk_exe msedge.exe)"],
            ["AndreLinjeRegex", "2. linje kjennes igjen på (regex – da fylles ikke Kontakt)"],
            ["ManuellTast",     "Tast for manuell innfylling (f.eks. F8, ^!k)"]
        ]
        if IsObject(this.AvansertVindu) {
            for par in felter
                this.AvansertFelt[par[1]].Value := this.Cfg[par[1]]
            this.AvansertVindu.Show()
            return
        }
        av := Gui("+Owner" HOVED.Hwnd, "SM Kontakt – avansert")
        this.AvansertVindu := av
        this.AvansertFelt := Map()
        av.BackColor := TEMA.bg
        y := 16
        for par in felter {
            Skrift(av, "s9 c" TEMA.dempet)
            av.AddText("x16 y" y " w520 Background" TEMA.bg, par[2])
            Skrift(av, "s10 c" TEMA.tekst, "Consolas")
            this.AvansertFelt[par[1]] := av.AddEdit("x16 y" (y + 20) " w520 h26 Background" TEMA.kort, this.Cfg[par[1]])
            y += 58
        }
        Skrift(av, "s10 c" TEMA.tekst)
        Knapp(av, "x16 y" (y + 4) " w170 h34", "Tilbakestill standard", ObjBindMethod(this, "AvansertStandard"), TEMA.aksent2)
        Knapp(av, "x196 y" (y + 4) " w170 h34", "Kopier diagnose", ObjBindMethod(this, "KopierDiagnose"), TEMA.aksent2)
        Skrift(av, "s10 bold c" TEMA.tekst)
        Knapp(av, "x386 y" (y + 4) " w150 h34", "Lagre", ObjBindMethod(this, "AvansertLagre"))
        av.Show("w552 h" (y + 54))
    }

    AvansertStandard(*) {
        for nokkel, ktrl in this.AvansertFelt
            if VT_SMKontakt.Standard.Has(nokkel)
                ktrl.Value := VT_SMKontakt.Standard[nokkel]
    }

    AvansertLagre(*) {
        for nokkel, ktrl in this.AvansertFelt {
            if InStr(nokkel, "Regex") && ktrl.Value != "" {
                try {
                    RegExMatch("", ktrl.Value)
                } catch as feil {
                    return MsgBox("Feil i uttrykket for «" nokkel "»:`n" feil.Message, APP_NAVN, "Icon! Owner" this.AvansertVindu.Hwnd)
                }
            }
        }
        for nokkel, ktrl in this.AvansertFelt
            this.SettCfg(nokkel, Trim(ktrl.Value))
        if this.Aktiv
            this.AktiverTast()
        this.AttMetode := ""
        this.OppdaterTekster()
        this.NullstillTilstand()
        this.AvansertVindu.Hide()
        Logg("SM Kontakt: avanserte innstillinger lagret")
    }
}

; Finner verdien etter en ledetekst, f.eks. «Kundenummer: AINAMH» / «Brukernavn: MAKSTO»
; eller ledeteksten med verdien alene på neste linje. Returnerer "" hvis feltet er tomt.
FinnBrukernavn(tekst, etiketter := "Brukernavn") {
    if (tekst = "" || etiketter = "")
        return ""
    tekst := StrReplace(StrReplace(tekst, "`r`n", "`n"), "`r", "`n")
    tekst := StrReplace(tekst, Chr(0xA0), " ")
    for etikett in StrSplit(etiketter, "|") {
        e := RegExReplace(Trim(etikett), "[\\.*?+\[\](){}^$|]", "\$0")
        e := RegExReplace(e, "\s+", "\s+")
        if (e = "")
            continue
        ; verdien på samme linje
        if RegExMatch(tekst, "im)(?:^|[^\p{L}])" e "[ \t]*:?[ \t]*([\p{L}\d._\\-]{2,40})(?![\p{L}\d._\\-]|[ \t]*:)", &m)
            return m[1]
        ; verdien alene på neste linje
        if RegExMatch(tekst, "im)(?:^|[^\p{L}])" e "[ \t]*:?[ \t]*\n[ \t]*([\p{L}\d._\\-]{2,40})[ \t]*$", &m)
            return m[1]
    }
    return ""
}

; Lite vindu nede til høyre i 3 sekunder (vises ikke når hovedvinduet er aktivt)
Varsel(kilde, verdi, linje, ok := true) {
    static vv := ""
    if WinActive("ahk_id " HOVED.Hwnd)
        return
    if IsObject(vv)
        try vv.Destroy()
    vv := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +Owner")
    vv.BackColor := TEMA.kort
    vv.MarginX := 0, vv.MarginY := 0
    vv.AddText("x0 y0 w6 h100 Background" (ok ? TEMA.paa : TEMA.aksent))
    Skrift(vv, "s9 bold c" TEMA.dempet)
    vv.AddText("x20 y10 w320 Background" TEMA.kort, StrUpper(kilde))
    Skrift(vv, "s18 bold c" (ok ? TEMA.paa : TEMA.tekst))
    vv.AddText("x20 y28 w320 h34 Background" TEMA.kort, verdi)
    Skrift(vv, "s9 c" TEMA.tekst)
    vv.AddText("x20 y66 w330 h30 Background" TEMA.kort, linje)
    MonitorGetWorkArea(MonitorGetPrimary(), , , &hoyre, &bunn)
    vv.Show("NoActivate x" (hoyre - 380) " y" (bunn - 120) " w360 h100")
    SetTimer LukkVarsel.Bind(vv), -3000
}

LukkVarsel(vindu) {
    try vindu.Destroy()
}

; Venter (maks ms) til Ctrl, Alt, Shift og Windows-tasten er sluppet
VentTasterSluppet(maks := 2000) {
    slutt := A_TickCount + maks
    while (A_TickCount < slutt) {
        nede := false
        for tast in ["Ctrl", "Alt", "Shift", "LWin", "RWin"]
            if GetKeyState(tast, "P")
                nede := true
        if !nede
            return true
        Sleep 30
    }
    return false
}

AktivtVinduNavn() {
    try return WinGetTitle("A") " (" WinGetProcessName("A") ")"
    return "(ukjent)"
}

; Prosess-ID til programmet som sist la noe på utklippstavlen (0 = ukjent)
KlippEierPid() {
    eier := DllCall("GetClipboardOwner", "Ptr")
    if !eier
        return 0
    pid := 0
    DllCall("GetWindowThreadProcessId", "Ptr", eier, "UInt*", &pid)
    return pid
}

; Ser verdien ut som et brukernavn/kundenummer? (2–60 tegn, ingen mellomrom)
ErBrukernavn(verdi) => RegExMatch(verdi, "^[\p{L}\d._@\\-]{2,60}$")

; Merket gjelder kun neste kopiering. Merket utløper automatisk.
TrioKopiMerke(type?) {
    static merke := "", tid := 0
    if IsSet(type) {
        merke := type, tid := A_TickCount
        return type
    }
    return (merke != "" && A_TickCount - tid < 3000) ? merke : ""
}

ErTelefonnummer(verdi) => RegExMatch(verdi, "^\+?[\d \-()]{5,25}$") && RegExMatch(verdi, "(\d\D*){5}")

KortVerdi(verdi, maks := 22) {
    verdi := Trim(RegExReplace(verdi, "\s+", " "))
    return StrLen(verdi) > maks ? SubStr(verdi, 1, maks - 1) "…" : verdi
}

FinnTlf(tekst) {
    if RegExMatch(tekst, "i)Tlf\.?\s*nr\.?\s*:?\s*(\+?\d[\d ]{4,})", &t)
        return StrReplace(Trim(t[1]), " ")
    if RegExMatch(tekst, "(\+?\d{6,})\s*\(", &t)                  ; «91101319 (IKT_G_OUS)»
        return t[1]
    return ""
}

; Sak-/samtale-ID fra adressen i Trio Web, f.eks. …/TrioAgent/case/97958092
WebSak(adresse) => RegExMatch(adresse, "i)/case/([\w-]+)", &m) ? m[1] : ""

ErNettleser(hwnd) {
    try return RegExMatch(WinGetProcessName("ahk_id " hwnd), "i)^(msedge|chrome|firefox|brave|opera|iexplore)\.exe$")
    return false
}

; Bruk kun aktiv fane eller UIA til å finne målet i SM Kontakt.
; Vindusbytter kan valgfritt fortsatt bruke Ctrl+Tab ved eksplisitt hurtigtast.
NettleserFaneBekreftet(hwnd, nokkelord) {
    if !hwnd
        return false
    try {
        if InStr(WinGetTitle("ahk_id " hwnd), nokkelord)
            return true
        rot := UiaFraVindu(hwnd)
        if !IsObject(rot)
            return false
        for fane in UiaFinnAlle(rot, 50019) {
            if (InStr(UiaStreng(fane, 30005), nokkelord) && UiaBool(fane, 30079))
                return true
        }
    }
    return false
}

AktiverFane(id, tillatFaneblading := true) {
    if (id = "")
        return 0
    nettleser := RegExMatch(id, "i)^(.*?)\s+ahk_exe\s+(msedge|chrome|firefox|brave|opera)\.exe$", &del)
    if !nettleser {
        hwnd := FinnVindu(id, false)
        if !hwnd
            return 0
        try {
            if (WinGetMinMax("ahk_id " hwnd) = -1)
                WinRestore "ahk_id " hwnd
            WinActivate "ahk_id " hwnd
            return WinWaitActive("ahk_id " hwnd, , 2) ? hwnd : 0
        }
        return 0
    }

    nokkelord := Trim(del[1]), exe := del[2] ".exe"
    if (nokkelord = "")
        return 0
    ; SM Kontakt nekter å bruke tilfeldige korte lærte titler (f.eks. "! W$").
    if (!tillatFaneblading && !InStr(nokkelord, "Service Manager")) {
        Logg("SM Kontakt: avviser ugyldig mål-fane. Lær Service Manager på nytt.")
        return 0
    }

    ; 1: Finn vindu med riktig fane allerede valgt – uten å påvirke andre vinduer.
    for hwnd in WinGetList("ahk_exe " exe) {
        if !NettleserFaneBekreftet(hwnd, nokkelord)
            continue
        try {
            if (WinGetMinMax("ahk_id " hwnd) = -1)
                WinRestore "ahk_id " hwnd
            WinActivate "ahk_id " hwnd
            if (WinWaitActive("ahk_id " hwnd, , 2) && NettleserFaneBekreftet(hwnd, nokkelord))
                return hwnd
        }
    }

    ; 2: Finn en kjent UIA-tab uten å endre faner i feil vindu.
    for hwnd in WinGetList("ahk_exe " exe) {
        if !UiaHarFane(hwnd, nokkelord)
            continue
        try {
            if (WinGetMinMax("ahk_id " hwnd) = -1)
                WinRestore "ahk_id " hwnd
            WinActivate "ahk_id " hwnd
            if !WinWaitActive("ahk_id " hwnd, , 2)
                continue
            if UiaVelgFane(hwnd, nokkelord)
                return hwnd
        }
    }

    ; 3: Kun for brukerutløst Vindusbytter. SM Kontakt passerer false.
    if tillatFaneblading {
        for hwnd in WinGetList("ahk_exe " exe) {
            try {
                if (WinGetTitle("ahk_id " hwnd) = "" || !(WinGetStyle("ahk_id " hwnd) & 0x10000000))
                    continue
                if (WinGetMinMax("ahk_id " hwnd) = -1)
                    WinRestore "ahk_id " hwnd
                WinActivate "ahk_id " hwnd
                if !WinWaitActive("ahk_id " hwnd, , 1)
                    continue
                bytter := 0
                loop 30 {
                    if !WinActive("ahk_id " hwnd)
                        break
                    Send "^{Tab}"
                    bytter++
                    Sleep 160
                    if NettleserFaneBekreftet(hwnd, nokkelord)
                        return hwnd
                }
                if WinActive("ahk_id " hwnd) {
                    loop bytter {
                        Send "^+{Tab}"
                        Sleep 35
                    }
                }
            }
        }
    }
    Logg("Vindussøk: finner ikke verifisert fane for " nokkelord " (" exe "). Ingen innskriving utført.")
    return 0
}

UiaHarFane(hwnd, nokkelord) {
    try {
        rot := UiaFraVindu(hwnd)
        if IsObject(rot) {
            for element in UiaFinnAlle(rot, 50019)
                if InStr(UiaStreng(element, 30005), nokkelord)
                    return true
        }
    }
    return false
}

; Microsoft UI Automation: TabItem 50019, SelectionItemPattern 10010.
UiaVelgFane(hwnd, nokkelord) {
    try {
        rot := UiaFraVindu(hwnd)
        if !IsObject(rot)
            return false
        for element in UiaFinnAlle(rot, 50019) {
            if !InStr(UiaStreng(element, 30005), nokkelord)
                continue
            ptr := 0
            ComCall(16, element, "Int", 10010, "Ptr*", &ptr)
            if !ptr
                continue
            valg := ComValue(13, ptr)
            ComCall(3, valg)
            Sleep 180
            if NettleserFaneBekreftet(hwnd, nokkelord)
                return true
        }
    }
    return false
}

; Lager en vindus-ID som finner vinduet igjen senere (også etter omstart):
; første del av tittelen + programfil (+ vindusklasse for vanlige program)
VindusId(hwnd) {
    exe := WinGetProcessName("ahk_id " hwnd)
    tittel := WinGetTitle("ahk_id " hwnd)
    if InStr(tittel, "Service Manager")
        nokkelord := "Service Manager"
    else {
        nokkelord := RegExReplace(tittel, "\s+[-–|]\s.*$")
        nokkelord := RegExReplace(nokkelord, "i)\s+(?:og|and)\s+\d+\s+(?:flere\s+|more\s+)?(?:sider?|pages?|faner?|tabs?)(?:\s+til)?$")
        nokkelord := Trim(SubStr(nokkelord, 1, 40))
    }
    if ErNettleser(hwnd)
        return nokkelord " ahk_exe " exe                  ; nettleser: fanens tittel avgjør
    return Trim(nokkelord " ahk_exe " exe " ahk_class " WinGetClass("ahk_id " hwnd))
}

; «Trio Agent  (msedge.exe)» i stedet for den tekniske vindus-ID-en
VennligNavn(id) {
    if !RegExMatch(id, "^(.*?)\s*ahk_exe\s+(\S+)", &del)
        return id
    return del[1] != "" ? del[1] "  (" del[2] ")" : del[2]
}

; Finner vinduet til en vindus-ID, men aldri dette programmets egne vinduer.
; utenTittel = prøv også uten tittel (for vanlige program der tittelen kan endre seg)
FinnVindu(id, utenTittel := true) {
    if (id = "")
        return 0
    egen := ProcessExist()
    kandidater := [id]
    if (utenTittel && RegExMatch(id, "^(.+?)\s+(ahk_exe\s+\S+\s+ahk_class\s+.+)$", &del))
        kandidater.Push(del[2])
    for k in kandidater {
        try {
            for hwnd in WinGetList(k)
                if (WinGetPID("ahk_id " hwnd) != egen)
                    return hwnd
        }
    }
    return 0
}

KlasseNavn(hwnd) {
    buf := Buffer(512, 0)
    DllCall("GetClassName", "Ptr", hwnd, "Ptr", buf, "Int", 256)
    return StrGet(buf)
}

; Teksten i én kontroll: HTML-panel, vanlig felt eller (som reserve) UI Automation
KontrollTekst(chwnd) {
    if InStr(KlasseNavn(chwnd), "Internet Explorer_Server")
        return IeTekst(chwnd)
    tekst := ""
    try tekst := ControlGetText(chwnd)
    if !RegExMatch(tekst, "i)brukernavn|kundenummer")
        try tekst .= "`n" UiaTekst(chwnd)
    return tekst
}

; All synlig tekst i et innebygd HTML-panel (Internet Explorer_Server)
IeTekst(chwnd) {
    static melding := DllCall("RegisterWindowMessage", "Str", "WM_HTML_GETOBJECT", "UInt")
    static iid := LagGuid("{332C4425-26CB-11D0-B483-00C04FD90119}")      ; IHTMLDocument2
    svar := 0
    try svar := SendMessage(melding, 0, 0, , "ahk_id " chwnd, , , , 1000)
    if !svar
        return ""
    pdoc := 0
    if (DllCall("oleacc\ObjectFromLresult", "Ptr", svar, "Ptr", iid, "Ptr", 0, "Ptr*", &pdoc, "Int") != 0 || !pdoc)
        return ""
    dok := ComValue(9, pdoc)
    tekst := ""
    try tekst := dok.body.innerText
    if (tekst = "")
        try tekst := dok.documentElement.innerText
    return tekst
}

; ---------------- Windows UI Automation ----------------
Uia() {
    static o := ""
    if !IsObject(o) {
        uia := ComObject("{ff48dba4-60ef-4201-aa87-54103eef594e}", "{30cbe57d-d9d0-452a-ab13-7ac5ac4825ee}")
        p := 0
        ComCall(21, uia, "Ptr*", &p)                          ; CreateTrueCondition
        sann := ComValue(13, p)
        p := 0
        ComCall(20, uia, "Ptr*", &p)                          ; CreateCacheRequest
        cache := ComValue(13, p)
        ComCall(3, cache, "Int", 30005)                       ; AddProperty: Name
        ComCall(3, cache, "Int", 30045)                       ; AddProperty: Value
        o := {uia: uia, sann: sann, cache: cache, typer: Map()}
    }
    return o
}

UiaFraVindu(hwnd) {
    p := 0
    ComCall(6, Uia().uia, "Ptr", hwnd, "Ptr*", &p)            ; ElementFromHandle
    return p ? ComValue(13, p) : ""
}

UiaTypeBetingelse(kontrolltype) {                            ; «ControlType = …» (huskes)
    u := Uia()
    if u.typer.Has(kontrolltype)
        return u.typer[kontrolltype]
    variant := Buffer(24, 0)
    NumPut("UShort", 3, variant, 0), NumPut("Int", kontrolltype, variant, 8)    ; VT_I4
    p := 0
    if (A_PtrSize = 8)
        ComCall(23, u.uia, "Int", 30003, "Ptr", variant, "Ptr*", &p)            ; CreatePropertyCondition
    else
        ComCall(23, u.uia, "Int", 30003, "Int64", NumGet(variant, 0, "Int64"), "Int64", NumGet(variant, 8, "Int64"), "Ptr*", &p)
    u.typer[kontrolltype] := ComValue(13, p)
    return u.typer[kontrolltype]
}

; Alle etterkommere av en gitt type (f.eks. 50030 = Document, 50004 = Edit)
UiaFinnAlle(element, kontrolltype) {
    resultat := []
    p := 0
    ComCall(6, element, "Int", 4, "Ptr", UiaTypeBetingelse(kontrolltype), "Ptr*", &p)   ; FindAll
    if !p
        return resultat
    liste := ComValue(13, p)
    antall := 0
    ComCall(3, liste, "Int*", &antall)
    loop antall {
        e := 0
        ComCall(4, liste, "Int", A_Index - 1, "Ptr*", &e)
        if e
            resultat.Push(ComValue(13, e))
    }
    return resultat
}

UiaFraPunkt(sx, sy) {
    p := 0
    ComCall(7, Uia().uia, "Int64", (sy << 32) | (sx & 0xFFFFFFFF), "Ptr*", &p)    ; ElementFromPoint
    return p ? ComValue(13, p) : ""
}

UiaStreng(element, egenskap) {
    variant := Buffer(24, 0)
    ComCall(10, element, "Int", egenskap, "Ptr", variant)     ; GetCurrentPropertyValue
    verdi := ""
    if (NumGet(variant, 0, "UShort") = 8) {
        pv := NumGet(variant, 8, "Ptr")
        verdi := pv ? StrGet(pv, "UTF-16") : ""
    }
    DllCall("oleaut32\VariantClear", "Ptr", variant)
    return verdi
}

UiaTall(element, egenskap) {
    variant := Buffer(24, 0)
    ComCall(10, element, "Int", egenskap, "Ptr", variant)
    verdi := NumGet(variant, 0, "UShort") = 3 ? NumGet(variant, 8, "Int") : 0
    DllCall("oleaut32\VariantClear", "Ptr", variant)
    return verdi
}

UiaBool(element, egenskap) {
    variant := Buffer(24, 0)
    ComCall(10, element, "Int", egenskap, "Ptr", variant)
    verdi := (NumGet(variant, 0, "UShort") = 11) && NumGet(variant, 8, "Short") != 0    ; VT_BOOL
    DllCall("oleaut32\VariantClear", "Ptr", variant)
    return verdi
}

; Første etterkommer der en tekst-egenskap (f.eks. 30005 = Name, 30011 = AutomationId) har en gitt verdi
UiaFinnForsteMed(element, egenskap, tekst) {
    if !IsObject(element)
        return ""
    variant := Buffer(24, 0)
    NumPut("UShort", 8, variant, 0)
    NumPut("Ptr", DllCall("oleaut32\SysAllocString", "WStr", tekst, "Ptr"), variant, 8)
    p := 0
    try {
        if (A_PtrSize = 8)
            ComCall(23, Uia().uia, "Int", egenskap, "Ptr", variant, "Ptr*", &p)          ; CreatePropertyCondition
        else
            ComCall(23, Uia().uia, "Int", egenskap, "Int64", NumGet(variant, 0, "Int64"), "Int64", NumGet(variant, 8, "Int64"), "Ptr*", &p)
    } finally {
        DllCall("oleaut32\VariantClear", "Ptr", variant)
    }
    if !p
        return ""
    betingelse := ComValue(13, p)
    funnet := 0
    ComCall(5, element, "Int", 4, "Ptr", betingelse, "Ptr*", &funnet)                  ; FindFirst
    return funnet ? ComValue(13, funnet) : ""
}

UiaVerdi(element) {
    variant := Buffer(24, 0)
    ComCall(10, element, "Int", 30045, "Ptr", variant)        ; GetCurrentPropertyValue: Value
    verdi := ""
    if (NumGet(variant, 0, "UShort") = 8) {
        pv := NumGet(variant, 8, "Ptr")
        verdi := pv ? StrGet(pv, "UTF-16") : ""
    }
    DllCall("oleaut32\VariantClear", "Ptr", variant)
    return verdi
}

; All tekst (navn + verdier) under et element, i rekkefølge – én linje per element
UiaElementTekst(element, maks := 3000) {
    u := Uia()
    p := 0
    ComCall(8, element, "Int", 4, "Ptr", u.sann, "Ptr", u.cache, "Ptr*", &p)   ; FindAllBuildCache
    if !p
        return ""
    liste := ComValue(13, p)
    antall := 0
    ComCall(3, liste, "Int*", &antall)
    tekst := ""
    variant := Buffer(24, 0)
    loop Min(antall, maks) {
        e := 0
        ComCall(4, liste, "Int", A_Index - 1, "Ptr*", &e)
        if !e
            continue
        linje := ""
        bstr := 0
        try ComCall(55, e, "Ptr*", &bstr)                     ; get_CachedName
        if bstr {
            linje := StrGet(bstr, "UTF-16")
            DllCall("oleaut32\SysFreeString", "Ptr", bstr)
        }
        DllCall("RtlZeroMemory", "Ptr", variant, "UPtr", 24)
        try {
            ComCall(12, e, "Int", 30045, "Ptr", variant)       ; GetCachedPropertyValue: Value
            if (NumGet(variant, 0, "UShort") = 8) {
                pv := NumGet(variant, 8, "Ptr")
                verdi := pv ? StrGet(pv, "UTF-16") : ""
                if (verdi != "" && verdi != linje)
                    linje .= (linje != "" ? "`t" : "") verdi
            }
            DllCall("oleaut32\VariantClear", "Ptr", variant)
        }
        ObjRelease(e)
        if (Trim(linje) != "")
            tekst .= linje "`n"
    }
    return tekst
}

UiaTekst(hwnd) {
    element := UiaFraVindu(hwnd)
    return IsObject(element) ? UiaElementTekst(element) : ""
}

; Teksten på nettsiden i et nettleservindu (aktiv fane). Dokument-elementene huskes per vindu.
UiaDokTekst(hwnd) {
    static dokumenter := Map()
    static sisteFane := Map()
    ; Et Edge-vindu kan bytte mellom Trio, YouTube og Service Manager.
    ; Gjenbruk ikke cached Document-elementer etter at aktiv fane er endret.
    aktivTittel := WinGetTitle("ahk_id " hwnd)
    if (sisteFane.Has(hwnd) && sisteFane[hwnd] != aktivTittel && dokumenter.Has(hwnd))
        dokumenter.Delete(hwnd)
    sisteFane[hwnd] := aktivTittel
    if dokumenter.Has(hwnd) {
        tekst := ""
        for dok in dokumenter[hwnd]
            try tekst .= UiaElementTekst(dok)
        if (StrLen(Trim(tekst, " `t`r`n")) >= 20)
            return tekst
        dokumenter.Delete(hwnd)
    }
    AktiverChromiumTilgjengelighet(hwnd)
    element := UiaFraVindu(hwnd)
    if !IsObject(element)
        return ""
    doker := UiaFinnAlle(element, 50030)                     ; Document
    if !doker.Length
        return ""
    dokumenter[hwnd] := doker
    tekst := ""
    for dok in doker
        try tekst .= UiaElementTekst(dok)
    return tekst
}

; Adressen (URL) i et nettleservindu. Adressefeltet huskes per vindu.
UiaAdresse(hwnd) {
    static felt := Map()
    if felt.Has(hwnd) {
        verdi := ""
        try verdi := UiaVerdi(felt[hwnd])
        if RegExMatch(verdi, "[./]")
            return verdi
        felt.Delete(hwnd)
    }
    element := UiaFraVindu(hwnd)
    if !IsObject(element)
        return ""
    for e in UiaFinnAlle(element, 50004) {                    ; Edit – adressefeltet er det første med en adresse
        if (A_Index > 12)
            break
        verdi := ""
        try verdi := UiaVerdi(e)
        if RegExMatch(verdi, "i)^(https?://)?[\w-]+(\.[\w-]+)+(:\d+)?(/|$)") {
            felt[hwnd] := e
            return verdi
        }
    }
    return ""
}

; Ber Edge/Chrome om å slå på tilgjengelighet for nettsiden (gjøres én gang per vindu)
AktiverChromiumTilgjengelighet(hwnd) {
    static gjort := Map()
    if gjort.Has(hwnd)
        return
    gjort[hwnd] := true
    try SendMessage(0x3D, 0, 1, "Chrome_RenderWidgetHostHWND1", "ahk_id " hwnd, , , , 500)      ; WM_GETOBJECT
}

LagGuid(tekst) {
    buf := Buffer(16)
    DllCall("ole32\CLSIDFromString", "WStr", tekst, "Ptr", buf)
    return buf
}

ProvRegex(tekst, uttrykk) {
    if (uttrykk = "")
        return 0
    try {
        return RegExMatch(tekst, uttrykk)
    }
    return 0
}


; =====================================================================
;  TRIO SNARVEIER – ekte menyhandlinger fra QuickKey v1.05
;  Forskjellig fra Vindusbytter: Agentvinduet og Tjenestevindu er
;  handlinger under "Vis" i Trio Attendant, ikke egne Edge-vinduer.
; =====================================================================
TrioOppgaver() => [
    {key:"HKAgentvindu", navn:"Vis Agentvindu", beskrivelse:"Trio → Vis → Agentvinduet"},
    {key:"HkTjenestevindu", navn:"Vis Tjenestevindu", beskrivelse:"Trio → Vis → Tjenestevindu"},
    {key:"HKetterarbeid", navn:"Legg til etterarbeid", beskrivelse:"Trio → Sett inn → Etterarbeid"},
    {key:"HKcopyIM", navn:"Kopier IM / Kommentar", beskrivelse:"Bytt kopifelt midlertidig til Kommentar"},
    {key:"HKcopyTLF", navn:"Kopier telefonnummer", beskrivelse:"Bytt kopifelt midlertidig til A-nr"}
]

; Registrer ingen hotkey for å validere: 'Hotkey ... Off' kan deaktivere
; allerede registrerte snarveier på brukerens maskin.
GyldigHurtigtast(tast) {
    if (tast = "")
        return false
    return RegExMatch(tast, "i)^[!^+#]{0,4}(?:[\p{L}\d_]+|[-=.,;/]|LButton|RButton|MButton|XButton1|XButton2)$") != 0
}

; Ta opp tastatur og mus. Musknapp-hook fjernes alltid etter opptak.
TaOppEnTast(sekunder := 8) {
    ih := InputHook("L0 T" sekunder)
    ih.KeyOpt("{All}", "E")
    ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")
    mus := ""
    MusTrykk(knapp, *) {
        mods := (GetKeyState("Ctrl") ? "^" : "") (GetKeyState("Alt") ? "!" : "") (GetKeyState("Shift") ? "+" : "")
            . (GetKeyState("LWin") || GetKeyState("RWin") ? "#" : "")
        ; LButton/RButton uten Ctrl/Alt skal ikke kunne overstyre vanlige museklikk.
        mus := (InStr(knapp, "LButton") || InStr(knapp, "RButton")) && !RegExMatch(mods, "[\^!]") ? "-" : mods knapp
        ih.Stop()
    }
    knapper := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
    try {
        for k in knapper
            Hotkey "*" k, MusTrykk.Bind(k), "On"
        ih.Start()
        ih.Wait()
    } finally {
        for k in knapper
            try Hotkey "*" k, "Off"
    }
    if (mus != "")
        return mus = "-" ? "" : mus
    if (ih.EndReason != "EndKey" || ih.EndKey = "Escape")
        return ""
    em := ih.EndMods
    return (InStr(em, "^") ? "^" : "") (InStr(em, "!") ? "!" : "") (InStr(em, "+") ? "+" : "") (InStr(em, "#") ? "#" : "") ih.EndKey
}

ErMusTast(tast) => RegExMatch(tast, "i)^[\^!+#]*(LButton|RButton|MButton|XButton1|XButton2)$") != 0

ErTegnTast(tast) {
    mods := "", tasten := tast
    while (StrLen(tasten) > 1 && InStr("^!+#", SubStr(tasten, 1, 1))) {
        mods .= SubStr(tasten, 1, 1)
        tasten := SubStr(tasten, 2)
    }
    if (InStr(mods, "^") || InStr(mods, "!") || InStr(mods, "#"))
        return false
    return StrLen(tasten) = 1 || RegExMatch(tasten, "i)^(Numpad(\d|Add|Sub|Mult|Div|Dot|Enter)|Space|Tab|Enter|Backspace|MButton|XButton1|XButton2)$")
}

TrioSnarveiKrit(*) {
    hwnd := FinnVindu(Innst("SMKontakt", "TrioVindu", "Trio Attendant"))
    if !hwnd
        hwnd := FinnVindu("Trio Attendant")
    return hwnd && !ErNettleser(hwnd) && WinActive("ahk_id " hwnd)
}

class VT_TrioSnarveier extends VT_Base {
    Navn := "Trio Snarveier"
    Beskrivelse := "QuickKey-funksjoner direkte i Trio Attendant, ikke bare vindusbytte."
    Felt := ""
    Registrerte := ""
    Opptak := false
    KopiModus := ""                    ; "lukket" = Trio kopierer bare fra hovedvinduet (oppdages automatisk)
    Etter := ""                        ; handling etter Trio-snarvei (åpne IM)
    ImVenter := ""                     ; vent på at Search åpnes i Service Manager
    ImLaerer := false
    SistIM := ""

    __New() {
        this.Felt := Map()
        this.Registrerte := Map()
        this.ImPollCb := ObjBindMethod(this, "ImSjekk")
        this.ImKlikkCb := ObjBindMethod(this, "ImLaerKlikk")
        this.ImEscCb := ObjBindMethod(this, "ImLaerAvbryt")
    }

    Hjelp() {
        return "•  Agentvindu og Tjenestevindu åpnes gjennom Vis-menyen i Trio Attendant.`n"
            . "•  Etterarbeid bruker den gamle Trio-menysekvensen.`n"
            . "•  IM og telefonnummer bytter Parameter midlertidig, kopierer og gjenoppretter innstillingene.`n"
            . "•  Kopitasten leses automatisk fra Hurtigkopiering i Trio (f.eks. Ctrl + |).`n"
            . "•  «Velg tast…» for kopitasten vises hvis automatisk lesing feiler.`n"
            . "•  Åpne IM-en (valgfritt): «Lær oppsett» → klikk i Search-feltet i Service Manager.`n"
            . "•  Hvis Search er lukket, venter programmet inntil 30 sekunder på at du åpner det.`n"
            . "•  «Test» prøver et valgfritt IM-nummer med samme automatikk som ved kopiering.`n"
            . "•  Hurtigtaster kan være tastaturkombinasjoner, enkelttegn eller musknapper.`n"
            . "•  Enkelttegn og midtre/sideknapper uten Ctrl/Alt fungerer bare når Trio er aktivt.`n"
            . "•  Kryss av «På» og trykk «Lagre snarveier».`n"
            . "•  Test først med syntetiske data."
    }

    ByggPanel(gui, x, y, b) {
        Skrift(gui, "s9 bold c" TEMA.dempet)
        this.Leg(gui.AddText("x" x " y" y " w230 h22 Background" TEMA.bg, "TRIO-HANDLING"))
        this.Leg(gui.AddText("x" (x+236) " y" y " w145 h22 Background" TEMA.bg, "HURTIGTAST"))
        this.Leg(gui.AddText("x" (x+422) " y" y " w60 h22 Background" TEMA.bg, "AKTIV"))
        for i, op in TrioOppgaver() {
            ry := y + 28 + (i-1)*42
            Skrift(gui, "s9 c" TEMA.tekst)
            this.Leg(gui.AddText("x" x " y" (ry+3) " w225 h28 +0x200 Background" TEMA.bg, op.navn))
            tastKnapp := this.Leg(Knapp(gui, "x" (x+236) " y" ry " w145 h29", "", ObjBindMethod(this, "TaOppTast", op.key), TEMA.aksent2))
            this.Leg(Knapp(gui, "x" (x+386) " y" ry " w28 h29", "✕", ObjBindMethod(this, "FjernTast", op.key), TEMA.av))
            paa := (StrLower(this.Hent("Enabled" op.key, "off")) = "on")
            sjekk := this.Leg(gui.AddCheckBox("x" (x+424) " y" (ry+4) " w60 h23" (paa ? " Checked" : ""), "På"))
            this.Felt[op.key] := {knapp:tastKnapp, sjekk:sjekk, tast:this.Hent(op.key, ""), navn:op.navn}
            this.VisTast(op.key)
        }
        yKnapp := y + 28 + TrioOppgaver().Length * 42 + 6
        Skrift(gui, "s10 bold c" TEMA.tekst)
        this.Leg(Knapp(gui, "x" x " y" yKnapp " w175 h34", "Lagre snarveier", ObjBindMethod(this, "LagreSnarveier")))
        Skrift(gui, "s9 c" TEMA.dempet)
        this.Leg(gui.AddText("x" (x+190) " y" (yKnapp+2) " w" (b-190) " h42 Background" TEMA.bg
            , "Tast, kombinasjon eller musknapp. Enkelttegn eller musknapp alene bare når Trio er aktivt."))
        Skrift(gui, "s9 bold c" TEMA.paa)
        this.MeldingK := this.Leg(gui.AddText("x" x " y" (yKnapp+44) " w" b " h20 Background" TEMA.bg, ""))
        Skrift(gui, "s9 c" TEMA.tekst)
        this.KopiK := this.Leg(gui.AddText("x" x " y" (yKnapp+70) " w" (b-130) " h28 +0x200 Background" TEMA.bg, ""))
        this.KopiKnapp := this.Leg(Knapp(gui, "x" (x+b-120) " y" (yKnapp+70) " w120 h28", "Velg tast…", ObjBindMethod(this, "TaOppKopitast"), TEMA.aksent2))
        Skrift(gui, "s9 c" TEMA.tekst)
        this.ImSjekkK := this.Leg(gui.AddCheckBox("x" x " y" (yKnapp+106) " w" (b-196) " h28"
            . (this.Hent("ApneIM", "0") = "1" ? " Checked" : ""), ""))
        this.ImSjekkK.OnEvent("Click", ObjBindMethod(this, "ImSlaPaAv"))
        this.Leg(Knapp(gui, "x" (x+b-186) " y" (yKnapp+106) " w100 h28", "Lær oppsett", ObjBindMethod(this, "ImLaer"), TEMA.aksent2))
        this.Leg(Knapp(gui, "x" (x+b-80) " y" (yKnapp+106) " w80 h28", "Test", ObjBindMethod(this, "ImTest"), TEMA.aksent2))
        this.ImVisStatus()
        VIS_VILKAR[this.KopiKnapp] := () => this.TrengerKopiKnapp()
        this.VisKopitast()
    }

    VisTast(nokkel) {
        felt := this.Felt[nokkel]
        felt.knapp.Text := felt.tast = "" ? "Velg tast…" : TastTekst(felt.tast)
        felt.knapp.Opt("Background" (felt.tast = "" ? TEMA.aksent2 : TEMA.aksent))
        felt.knapp.Redraw()
    }

    Melding(tekst, ok := true) {
        try {
            this.MeldingK.SetFont("c" (ok ? TEMA.paa : "FF6B6B"))
            this.MeldingK.Text := tekst
        }
    }

    TaOppTast(nokkel, *) {
        if this.Opptak
            return
        this.Opptak := true
        felt := this.Felt[nokkel]
        this.Stopp()
        felt.knapp.Text := "Trykk tast…"
        felt.knapp.Opt("Background" TEMA.aksent), felt.knapp.Redraw()
        this.Melding("Trykk tast, kombinasjon eller musknapp for «" felt.navn "» (Esc = avbryt)")
        tast := TaOppEnTast()
        this.Opptak := false
        if (tast = "") {
            this.Melding("Avbrutt – hurtigtasten er ikke endret", false)
        } else if !GyldigHurtigtast(tast) {
            this.Melding(TastTekst(tast) " kan ikke brukes som hurtigtast – prøv en annen", false)
        } else {
            felt.tast := tast
            felt.sjekk.Value := 1
            this.Melding(TastTekst(tast) " valgt for «" felt.navn "»" (ErTegnTast(tast) ? " (bare når Trio er fremst)" : "")
                . " – trykk «Lagre snarveier»")
        }
        this.VisTast(nokkel)
        if this.Aktiv
            this.Start()
    }

    FjernTast(nokkel, *) {
        felt := this.Felt[nokkel]
        felt.tast := ""
        felt.sjekk.Value := 0
        this.VisTast(nokkel)
        this.Melding("Tast fjernet – trykk Lagre snarveier")
    }

    Konflikt(tast, egen) {
        if (tast = Innst("App", "VisTast", "^!m"))
            return "Vis/skjul QuickerKeys"
        if (tast = Innst("SMKontakt", "ManuellTast", "^!k"))
            return "SM Kontakt"
        loop 4 {
            if (tast = Innst("Vindusbytter", "Tast" A_Index, "") && tast != "")
                return "Vindusbytter " A_Index
        }
        for op in TrioOppgaver()
            if (op.key != egen && StrLower(this.Hent("Enabled" op.key, "off")) = "on"
                && this.Hent(op.key, "") = tast)
                return op.navn
        return ""
    }

    LagreSnarveier(*) {
        sett := Map()
        for op in TrioOppgaver() {
            felt := this.Felt[op.key]
            tast := felt.tast
            paa := felt.sjekk.Value = 1
            if (paa && !GyldigHurtigtast(tast))
                return MsgBox("Ugyldig/manglende hurtigtast for " op.navn, APP_NAVN, "Icon!")
            if paa {
                if sett.Has(tast)
                    return MsgBox("Tasten brukes også av " sett[tast], APP_NAVN, "Icon!")
                sett[tast] := op.navn
                konflikt := this.Konflikt(tast, op.key)
                if (konflikt != "")
                    return MsgBox("Tasten brukes av " konflikt, APP_NAVN, "Icon!")
            }
        }
        try {
            for op in TrioOppgaver() {
                felt := this.Felt[op.key]
                this.Lagre(op.key, felt.tast)
                this.Lagre("Enabled" op.key, felt.sjekk.Value = 1 ? "on" : "off")
            }
            this.Stopp()
            if this.Aktiv
                this.Start()
            this.Melding("Snarveiene er lagret ✓")
            Tip("Trio-snarveiene er lagret", 2000)
        } catch as feil {
            MsgBox "Kunne ikke lagre snarveiene:`n" feil.Message, APP_NAVN, "Icon!"
        }
    }

    Start() {
        this.Stopp()
        antall := 0
        for op in TrioOppgaver() {
            tast := this.Hent(op.key, "")
            if (tast = "" || StrLower(this.Hent("Enabled" op.key, "off")) != "on")
                continue
            konflikt := this.Konflikt(tast, op.key)
            if (konflikt != "") {
                Logg("Trio Snarveier: " op.navn " har konflikt med " konflikt)
                continue
            }
            kunTrio := ErTegnTast(tast)
            try {
                if kunTrio
                    HotIf TrioSnarveiKrit
                Hotkey tast, ObjBindMethod(this, "Kjor", op.key), "On"
                this.Registrerte[op.key] := {tast:tast, kunTrio:kunTrio}
                antall++
            } catch as feil {
                Logg("Trio Snarveier: kunne ikke registrere " op.navn ": " feil.Message)
            } finally {
                HotIf
            }
        }
        this.SettStatus(antall " av " TrioOppgaver().Length " Trio-snarveier aktive")
    }

    Stopp() {
        for key, reg in this.Registrerte {
            if reg.kunTrio
                HotIf TrioSnarveiKrit
            try Hotkey reg.tast, "Off"
            HotIf
        }
        this.Registrerte := Map()
    }

    AktiverTrio() {
        hwnd := FinnVindu(Innst("SMKontakt", "TrioVindu", "Trio Attendant"))
        if !hwnd
            hwnd := FinnVindu("Trio Attendant")
        if (!hwnd || ErNettleser(hwnd))
            throw Error("Fant ikke Trio Attendant (desktop-programmet).")
        if (WinGetMinMax("ahk_id " hwnd) = -1)
            WinRestore "ahk_id " hwnd
        WinActivate "ahk_id " hwnd
        if !WinWaitActive("ahk_id " hwnd, , 2)
            throw Error("Trio Attendant ble ikke aktivt.")
        return hwnd
    }

    Kjor(nokkel, *) {
        SetWinDelay -1
        SetControlDelay -1
        forrige := WinExist("A")
        try {
            hwnd := this.AktiverTrio()
            id := "ahk_id " hwnd
            switch nokkel {
                case "HKAgentvindu":
                    MenuSelect id,, "Vis", "Agentvinduet"
                case "HkTjenestevindu":
                    MenuSelect id,, "Vis", "Tjenestevindu"
                case "HKetterarbeid":
                    MenuSelect id,, "Sett inn", "Etterarbeid"
                    if !WinWaitActive("Sett inn", , 2)
                        throw Error("Vinduet «Sett inn» åpnet seg ikke.")
                    Send "{Down 2}^{Enter}"
                case "HKcopyIM":
                    this.KopierMedFelt("Kommentar", id)
                case "HKcopyTLF":
                    this.KopierMedFelt("A-nr", id)
            }
            Logg("Trio Snarveier: utførte " nokkel)
        } catch as feil {
            Logg("Trio Snarveier: FEIL " nokkel " – " feil.Message)
            Tip("Trio-snarvei feilet – se Logg", 2400)
        } finally {
            if (forrige && WinExist("ahk_id " forrige))
                try WinActivate "ahk_id " forrige
        }
        if IsObject(this.Etter) {
            f := this.Etter, this.Etter := ""
            try f()
            catch as feil
                Logg("Trio Snarveier: FEIL etter " nokkel " – " feil.Message)
        }
    }


    ; v3.6: les kopitasten fra Trios Hurtigkopiering-fane før Parameter endres.
    ; Behold v3.4-fallbacken: åpent dialogvindu -> Trio-hovedvindu.
    KopierMedFelt(felt, trioId) {
        SetWinDelay -1
        SetControlDelay -1
        type := felt = "A-nr" ? "Telefonnummer" : "IM / Kommentar"
        dlg := "Innstillinger ahk_pid " WinGetPID(trioId)
        this.LukkInnstillinger(dlg)
        try {
            this.ApneInnstillinger(trioId, dlg)
            les := this.LesTrioKopitast(dlg)
        } catch as feil {
            this.LukkInnstillinger(dlg)
            throw feil
        }
        if les.ok {
            if (les.tast = "") {
                this.LukkInnstillinger(dlg)
                Logg("Trio Snarveier: Tastekombinasjon under Hurtigkopiering i Trio er tom – ingenting trykket")
                return Varsel("Trio Attendant · " type, "—", "Sett en tastekombinasjon under Hurtigkopiering i Trio", false)
            }
            tast := les.tast
            if (tast != this.Hent("HKCopy", "") || this.Hent("HKCopyKilde", "") != "Trio") {
                this.Lagre("HKCopy", tast), this.Lagre("HKCopyKilde", "Trio")
                Logg("Trio Snarveier: kopitast lest fra Trio: " TastTekst(tast))
                this.VisKopitast()
            }
        } else {
            if (this.Hent("HKCopyKilde", "") != "manuell") {
                this.Lagre("HKCopyKilde", "feilet")
                this.VisKopitast()
            }
            tast := this.Hent("HKCopy", "")
            if (tast = "") {
                this.LukkInnstillinger(dlg)
                Logg("Trio Snarveier: fant ikke kopitasten i Trio, og ingen er valgt manuelt")
                return Varsel("Trio Attendant · " type, "—", "Velg kopitasten på Trio Snarveier-siden", false)
            }
        }
        kopitast := SendTast(tast)
        original := ""
        kopiert := false
        try {
            original := this.VelgParameter(dlg, felt)
            ControlClick "Button3", dlg
            if (this.KopiModus = "lukket" || WinWaitClose(dlg, , 0.1)) {
                this.LukkMedOk(dlg)
                this.TilTrio(trioId)
            }
            kopiert := this.TrykkKopi(kopitast, type)
            if (!kopiert && WinExist(dlg)) {
                this.LukkMedOk(dlg)
                this.TilTrio(trioId)
                if (kopiert := this.TrykkKopi(kopitast, type)) {
                    this.KopiModus := "lukket"
                    Logg("Trio Snarveier: kopierer fra Trio-vinduet (ikke mens Innstillinger er åpent)")
                }
            }
        } finally {
            tilbake := (original = "" || RegExMatch(original, "i)^(Kommentar|A-nr)")) ? "IDM Username" : original
            try {
                if !WinExist(dlg)
                    this.ApneInnstillinger(trioId, dlg)
                this.VelgParameter(dlg, tilbake)
                ControlClick "Button3", dlg
                this.LukkMedOk(dlg)
            } catch as feil {
                Logg("Trio Snarveier: klarte ikke å sette Parameter tilbake til " tilbake ": " feil.Message)
                Tip("Trio: kontroller Hurtigkopiering → Parameter manuelt", 5000)
            }
            this.LukkInnstillinger(dlg)
        }
        if kopiert {
            verdi := ""
            try verdi := Trim(A_Clipboard, " " Chr(9) Chr(13) Chr(10))
            Logg("Trio Snarveier: " type " kopiert – " KortVerdi(verdi, 60))
            Varsel("Trio Attendant · " type, verdi = "" ? "—" : KortVerdi(verdi), type " kopiert")
            if (felt = "Kommentar" && this.Hent("ApneIM", "0") = "1" && RegExMatch(verdi, "i)\bIM\d{4,}\b"))
                this.Etter := ObjBindMethod(this, "ApneIM", verdi)
        } else {
            TrioKopiMerke("")
            Logg("Trio Snarveier: FEIL " type " – ingenting ble kopiert (kopitast " TastTekst(tast) ")")
            Varsel("Trio Attendant · " type, "—", "Ingenting ble kopiert – sjekk kopitasten", false)
        }
    }

    ; Windows standard Hotkey-kontroll: HKM_GETHOTKEY (0x402).
    ; Mangler feltet, prøv tekst av typen "Ctrl + |".
    LesTrioKopitast(dlg) {
        kontroller := []
        try kontroller := WinGetControls(dlg)
        for ktrl in kontroller {
            if !InStr(ktrl, "msctls_hotkey32")
                continue
            try {
                v := SendMessage(0x402, 0, 0, ktrl, dlg)
                vk := v & 0xFF, mods := (v >> 8) & 0xFF
                if !vk
                    return {ok: true, tast: ""}
                return {ok: true, tast: (mods & 2 ? "^" : "") (mods & 4 ? "!" : "") (mods & 1 ? "+" : "")
                    . "vk" Format("{:02X}", vk)}
            }
        }
        for ktrl in kontroller {
            if !InStr(ktrl, "Edit")
                continue
            try {
                if !ControlGetVisible(ktrl, dlg)
                    continue
                tast := TrioTastFraTekst(ControlGetText(ktrl, dlg))
                if (tast != "")
                    return {ok: true, tast: tast}
            }
        }
        return {ok: false, tast: ""}
    }

    VisKopitast() {
        tast := this.Hent("HKCopy", "")
        kilde := this.Hent("HKCopyKilde", "")
        try this.KopiK.Text := "Kopitast i Trio:  " (tast = "" ? "ikke kjent ennå" : TastTekst(tast))
            . (kilde = "feilet" ? " – fant den ikke i Trio, velg den her"
            : tast = "" ? " – leses fra Trio første gang du kopierer IM/telefon"
            : kilde = "Trio" ? " (lest fra Trio)" : " (valgt her)")
        try this.KopiKnapp.Visible := this.KopiK.Visible && this.TrengerKopiKnapp()
    }

    TrengerKopiKnapp() => InStr("|feilet|manuell|", "|" this.Hent("HKCopyKilde", "") "|") > 0

    TaOppKopitast(*) {
        if this.Opptak
            return
        this.Opptak := true
        this.Stopp()
        this.KopiKnapp.Text := "Trykk tast…", this.KopiKnapp.Redraw()
        this.Melding("Trykk samme tast som under Hurtigkopiering i Trio (Esc = avbryt)")
        tast := TaOppEnTast()
        this.Opptak := false
        this.KopiKnapp.Text := "Velg tast…", this.KopiKnapp.Redraw()
        if (tast = "") {
            this.Melding("Avbrutt – kopitasten er ikke endret", false)
        } else if ErMusTast(tast) {
            this.Melding("Kopitasten må være en tast fra tastaturet, ikke en musknapp", false)
        } else if !GyldigHurtigtast(tast) {
            this.Melding("Ugyldig kopitast", false)
        } else {
            this.Lagre("HKCopy", tast), this.Lagre("HKCopyKilde", "manuell")
            this.VisKopitast()
            this.Melding("Kopitast satt til " TastTekst(tast) " (leses fra Trio når det er mulig)")
            Logg("Trio Snarveier: kopitast valgt manuelt: " TastTekst(tast))
        }
        if this.Aktiv
            this.Start()
    }

    ; Trykker Trios kopitast og venter (maks 1 sekund) til utklippstavlen endres.
    TrykkKopi(kopitast, type) {
        TrioKopiMerke(type)
        SetTimer () => TrioKopiMerke(""), -1500
        seq := DllCall("GetClipboardSequenceNumber", "UInt")
        SendInput kopitast
        slutt := A_TickCount + 1000
        while (A_TickCount < slutt) {
            if (DllCall("GetClipboardSequenceNumber", "UInt") != seq) {
                Sleep 20
                return true
            }
            Sleep 10
        }
        return false
    }

    TilTrio(trioId) {
        if WinActive(trioId)
            return
        WinActivate trioId
        WinWaitActive trioId, , 1
    }

    ; Åpner innstillingene transparent, og velger Hurtigkopiering-fanen.
    ApneInnstillinger(trioId, dlg) {
        this.TilTrio(trioId)
        MenuSelect trioId,, "Fil", "Innstillinger..."
        if !WinWait(dlg, , 2)
            throw Error("Trio-innstillingene ble ikke åpnet.")
        try WinSetTransparent 0, dlg
        ControlChooseIndex 3, "SysTabControl321", dlg
    }

    ; Leser tidligere valgt Parameter og velger en midlertidig verdi.
    VelgParameter(dlg, verdi) {
        loop 25 {
            try {
                ControlGetHwnd "ComboBox1", dlg
                break
            }
            Sleep 10
        }
        forrige := ""
        try forrige := ControlGetChoice("ComboBox1", dlg)
        ControlChooseString verdi, "ComboBox1", dlg
        return forrige
    }

    LukkMedOk(dlg) {
        if !WinExist(dlg)
            return
        try ControlClick "OK", dlg
        WinWaitClose dlg, , 1
    }

    LukkInnstillinger(dlg) {
        if !WinExist(dlg)
            return
        try ControlClick "Avbryt", dlg
        if !WinWaitClose(dlg, , 1) {
            try WinClose dlg
            WinWaitClose dlg, , 1
        }
        if WinExist(dlg)
            Logg("Trio Snarveier: Innstillinger-vinduet i Trio lot seg ikke lukke")
    }
}
; F12 -> {F12}, ^d -> ^{d}; fungerer også for navngitte numpad-taster.
SendTast(tast) {
    tast := Trim(tast)
    if (tast = "")
        return ""
    if (InStr(tast, "{") || !RegExMatch(tast, "^([\^!+#<>*~$]*)(.+)$", &m))
        return tast
    tegn := m[2]
    if (StrLen(tegn) = 1 && (vk := GetKeyVK(tegn)))
        tegn := "vk" Format("{:02X}", vk)
    return RegExReplace(m[1], "[<>*~$]") "{" tegn "}"
}

; 'Ctrl + |', 'Ctrl+Shift+F12' til AHK-tast.
TrioTastFraTekst(tekst) {
    tekst := Trim(tekst)
    if !RegExMatch(tekst, "i)^((?:(?:Ctrl|Control|Alt|Shift|Skift|Win)\s*\+\s*)*)(.+)$", &m)
        return ""
    mods := ""
    for navn, tegn in Map("Ctrl", "^", "Control", "^", "Alt", "!", "Shift", "+", "Skift", "+", "Win", "#")
        if RegExMatch(m[1], "i)\b" navn "\b") && !InStr(mods, tegn)
            mods .= tegn
    tast := Trim(m[2])
    if (mods = "" || tast = "")
        return ""
    return GetKeyVK(tast) ? mods tast : ""
}

; =====================================================================
;  VERKTØY: VINDUSBYTTER
;  Opptil fire vinduer, hver med sin egen hurtigtast. Trykk tasten –
;  så kommer vinduet fram (gjenopprettes hvis det er minimert).
; =====================================================================
class VT_Vindusbytter extends VT_Base {
    Navn := "Vindusbytter"
    Beskrivelse := "Hopp rett til et vindu med en hurtigtast – opptil fire vinduer."
    static Antall := 4
    Opptak := false

    __New() {
        this.Rader := []
        loop VT_Vindusbytter.Antall
            this.Rader.Push({id: this.Hent("Vindu" A_Index, ""), navn: this.Hent("Navn" A_Index, "")
                , tast: this.Hent("Tast" A_Index, ""), aktivTast: "", valg: [""], ddl: "", tastK: ""})
        this.ImporterGammel()
    }

    ; Henter oppsettet fra det gamle «Autoåpner»-skriptet (Vinduer.ini) første gang
    ImporterGammel() {
        for r in this.Rader
            if (r.id != "" || r.tast != "")
                return
        for fil in [A_ScriptDir "\Vinduer.ini", DATA_MAPPE "\Vinduer.ini"] {
            if !FileExist(fil)
                continue
            gamle := [[IniRead(fil, "Settings", "Window1", ""), "NumpadAdd"], [IniRead(fil, "Settings", "Window2", ""), "NumpadSub"]]
            for i, par in gamle {
                if (par[1] = "")
                    continue
                r := this.Rader[i]
                r.id := par[1], r.navn := par[1], r.tast := par[2]
                this.Lagre("Vindu" i, r.id), this.Lagre("Navn" i, r.navn), this.Lagre("Tast" i, r.tast)
            }
            this.Importert := fil
            return
        }
    }

    Hjelp() {
        return "1.  Velg et vindu i listen.`n"
            . "2.  Trykk knappen ved siden av og trykk tasten(e) du vil bruke – f.eks. Numpad + eller Ctrl+Alt+1.`n"
            . "3.  Trykk hurtigtasten – vinduet kommer fram.`n"
            . "•  ✕ fjerner en rad. «Oppdater vinduslisten» henter vinduer du har åpnet senere."
    }

    ; ---------------- Siden ----------------
    ByggPanel(gui, x, y, b) {
        Skrift(gui, "s9 bold c" TEMA.dempet)
        this.Leg(gui.AddText("x" (x + 24) " y" y " w280 Background" TEMA.bg, "VINDU"))
        this.Leg(gui.AddText("x" (x + 322) " y" y " w130 Background" TEMA.bg, "HURTIGTAST"))
        for i, r in this.Rader {
            ry := y + 22 + (i - 1) * 46
            Skrift(gui, "s12 bold c" TEMA.tekst)
            this.Leg(gui.AddText("x" x " y" (ry + 3) " w20 Background" TEMA.bg, i))
            Skrift(gui, "s10 c000000")
            r.ddl := this.Leg(gui.AddDropDownList("x" (x + 24) " y" ry " w290 R14"))
            r.ddl.OnEvent("Change", ObjBindMethod(this, "VelgVindu", i))
            Skrift(gui, "s10 bold c" TEMA.tekst)
            r.tastK := this.Leg(Knapp(gui, "x" (x + 322) " y" ry " w130 h28", "", ObjBindMethod(this, "TaOppTast", i), TEMA.aksent2))
            Skrift(gui, "s10 c" TEMA.tekst)
            this.Leg(Knapp(gui, "x" (x + 460) " y" ry " w32 h28", "✕", ObjBindMethod(this, "Fjern", i), TEMA.av))
        }
        by := y + 22 + VT_Vindusbytter.Antall * 46 + 4
        Skrift(gui, "s9 c" TEMA.tekst)
        this.Leg(Knapp(gui, "x" x " y" by " w190 h30", "Oppdater vinduslisten", ObjBindMethod(this, "FyllLister"), TEMA.aksent2))
        Skrift(gui, "s9 bold c" TEMA.paa)
        this.MeldingK := this.Leg(gui.AddText("x" (x + 202) " y" (by + 7) " w" (b - 202) " h20 Background" TEMA.bg, ""))
        this.FyllLister()
        this.OppdaterTastKnapper()
        if this.HasOwnProp("Importert")
            Logg("Vindusbytter: hentet oppsettet fra " this.Importert)
    }

    ; Fyller nedtrekksmenyene med vinduene som er åpne nå
    FyllLister(*) {
        apne := []
        sett := Map()
        egen := ProcessExist()
        for hwnd in WinGetList() {
            try {
                tittel := WinGetTitle("ahk_id " hwnd)
                if (tittel = "" || WinGetPID("ahk_id " hwnd) = egen || tittel = "Program Manager")
                    continue
                if (WinGetExStyle("ahk_id " hwnd) & 0x80)          ; verktøyvinduer
                    continue
                id := VindusId(hwnd)
                if sett.Has(id)
                    continue
                sett[id] := true
                exe := WinGetProcessName("ahk_id " hwnd)
                apne.Push({tekst: (StrLen(tittel) > 55 ? SubStr(tittel, 1, 52) "…" : tittel) "   —   " exe, id: id})
            }
        }
        for i, r in this.Rader {
            elementer := ["(ingen)"], r.valg := [""]
            valgt := 1
            finnId := r.id
            if (r.id != "" && !sett.Has(r.id)) {               ; lagret på en annen måte (f.eks. bare tittel)? finn det åpne vinduet
                hwnd := 0
                try hwnd := FinnVindu(r.id)
                if hwnd
                    try finnId := VindusId(hwnd)
            }
            if (r.id != "" && !sett.Has(finnId)) {             ; lagret vindu som ikke er åpent nå
                elementer.Push("★ " VennligNavn(r.navn != "" ? r.navn : r.id) "   (ikke åpent nå)")
                r.valg.Push(r.id)
                valgt := 2
            }
            for v in apne {
                elementer.Push(v.tekst), r.valg.Push(v.id = finnId ? r.id : v.id)
                if (v.id = finnId)
                    valgt := r.valg.Length
            }
            try {
                r.ddl.Delete()
                r.ddl.Add(elementer)
                r.ddl.Choose(valgt)
            }
        }
        this.Melding("Vinduslisten er oppdatert (" apne.Length " vinduer)")
    }

    Melding(tekst, ok := true) {
        try {
            this.MeldingK.SetFont("c" (ok ? TEMA.paa : "FF6B6B"))
            this.MeldingK.Text := tekst
        }
    }

    VelgVindu(i, *) {
        r := this.Rader[i]
        nr := r.ddl.Value
        if (nr < 1 || nr > r.valg.Length)
            return
        r.id := r.valg[nr]
        r.navn := (nr = 1) ? "" : RegExReplace(r.ddl.Text, "^★ |   \(ikke åpent nå\)$|   —   .*$")
        this.Lagre("Vindu" i, r.id), this.Lagre("Navn" i, r.navn)
        this.Registrer()
        Logg("Vindusbytter: vindu " i " = " (r.id = "" ? "(ingen)" : r.navn))
        this.Melding(r.id = "" ? "Vindu " i " er fjernet" : "Vindu " i " lagret ✓" (r.tast = "" ? " – velg en hurtigtast" : ""))
    }

    ; Tar opp hvilken som helst tast/tastekombinasjon (Esc = avbryt)
    TaOppTast(i, *) {
        if this.Opptak
            return
        this.Opptak := true
        r := this.Rader[i]
        this.Avregistrer()
        r.tastK.Text := "Trykk tast…"
        r.tastK.Opt("Background" TEMA.aksent), r.tastK.Redraw()
        this.Melding("Trykk tast, kombinasjon eller Ctrl/Alt + musknapp for vindu " i " (Esc = avbryt)")
        tast := TaOppEnTast()
        this.Opptak := false
        if (tast = "") {
            this.Melding("Avbrutt – hurtigtasten er ikke endret", false)
        } else if (ErMusTast(tast) && !RegExMatch(tast, "[\^!]")) {
            this.Melding("Bruk Ctrl/Alt + musknapp i Vindusbytter – musknapp alene ville virket overalt", false)
        } else if !GyldigHurtigtast(tast) {
            this.Melding("Ugyldig hurtigtast", false)
        } else if (konflikt := this.Konflikt(tast, i)) {
            this.Melding(TastTekst(tast) " brukes allerede av " konflikt, false)
        } else {
            r.tast := tast
            this.Lagre("Tast" i, tast)
            Logg("Vindusbytter: hurtigtast for vindu " i " = " TastTekst(tast))
            this.Melding("Hurtigtast " TastTekst(tast) " lagret" (r.id = "" ? " – velg et vindu" : ""))
        }
        this.OppdaterTastKnapper()
        this.Registrer()
    }

    ; Er tasten allerede i bruk (annen rad, vis/skjul-tasten eller SM Kontakt)?
    Konflikt(tast, egenRad) {
        for i, r in this.Rader
            if (i != egenRad && r.tast = tast)
                return "vindu " i
        if (tast = VIS_TAST)
            return "«Vis / skjul vinduet»"
        for vt in VERKTOY_LISTE
            if (vt.HasOwnProp("Cfg") && vt.Cfg.Has("ManuellTast") && vt.Cfg["ManuellTast"] = tast)
                return vt.Navn
        return ""
    }

    Fjern(i, *) {
        r := this.Rader[i]
        r.id := "", r.navn := "", r.tast := ""
        for nokkel in ["Vindu", "Navn", "Tast"]
            this.Lagre(nokkel i, "")
        this.Registrer()
        this.FyllLister()
        this.OppdaterTastKnapper()
        Logg("Vindusbytter: vindu " i " fjernet")
        this.Melding("Vindu " i " er fjernet")
    }

    OppdaterTastKnapper() {
        for r in this.Rader {
            try {
                r.tastK.Text := r.tast = "" ? "Velg tast…" : TastTekst(r.tast)
                r.tastK.Opt("Background" (r.tast = "" ? TEMA.aksent2 : TEMA.aksent))
                r.tastK.Redraw()
            }
        }
        this.OppdaterStatus()
    }

    OppdaterStatus() {
        klare := 0
        for r in this.Rader
            if (r.id != "" && r.tast != "")
                klare++
        this.SettStatus(klare = 0 ? "Ingen vinduer satt opp ennå" : klare " av " VT_Vindusbytter.Antall " vinduer klare")
    }

    ; ---------------- Hurtigtastene ----------------
    Start() {
        this.Registrer()
    }

    Stopp() {
        this.Avregistrer()
    }

    Registrer() {
        this.Avregistrer()
        if (!this.Aktiv || this.Opptak)
            return this.OppdaterStatus()
        for i, r in this.Rader {
            if (r.id = "" || r.tast = "")
                continue
            try {
                Hotkey r.tast, ObjBindMethod(this, "Bytt", i), "On"
                r.aktivTast := r.tast
            } catch as feil {
                Logg("Vindusbytter: kan ikke bruke hurtigtasten " TastTekst(r.tast) ": " feil.Message)
                this.Melding("Kan ikke bruke " TastTekst(r.tast) " – velg en annen tast", false)
            }
        }
        this.OppdaterStatus()
    }

    Avregistrer() {
        for r in this.Rader {
            if (r.aktivTast != "")
                try Hotkey r.aktivTast, "Off"
            r.aktivTast := ""
        }
    }

    Bytt(i, *) {
        r := this.Rader[i]
        navn := r.navn != "" ? r.navn : r.id
        if RegExMatch(r.id, "i)ahk_exe\s+(msedge|chrome|firefox|brave|opera)\.exe") {
            hwnd := AktiverFane(r.id)                       ; nettleser: finner også riktig fane
        } else {
            hwnd := FinnVindu(r.id)
            if hwnd {
                if (WinGetMinMax("ahk_id " hwnd) = -1)
                    WinRestore "ahk_id " hwnd
                WinActivate "ahk_id " hwnd
            }
        }
        if !hwnd {
            Tip("Fant ikke vinduet: " navn, 2500)
            Logg("Vindusbytter: fant ikke vindu " i " (" navn ")")
            return
        }
        Logg("Vindusbytter: byttet til vindu " i " (" navn ")")
    }
}

; «^!NumpadAdd» -> «Ctrl+Alt+Numpad +»
TastTekst(tast) {
    if (tast = "")
        return ""
    tekst := ""
    while (StrLen(tast) > 1 && InStr("^!+#", SubStr(tast, 1, 1))) {
        tekst .= Map("^", "Ctrl+", "!", "Alt+", "+", "Shift+", "#", "Win+")[SubStr(tast, 1, 1)]
        tast := SubStr(tast, 2)
    }
    navn := Map("NumpadAdd", "Numpad +", "NumpadSub", "Numpad −", "NumpadMult", "Numpad *", "NumpadDiv", "Numpad /"
        , "NumpadEnter", "Numpad Enter", "NumpadDot", "Numpad ,", "Space", "Mellomrom", "Enter", "Enter"
        , "LButton", "Venstreklikk", "RButton", "Høyreklikk", "MButton", "Midtre musknapp"
        , "XButton1", "Sideknapp 1", "XButton2", "Sideknapp 2")
    if navn.Has(tast)
        return tekst navn[tast]
    if RegExMatch(tast, "^Numpad(\d)$", &m)
        return tekst "Numpad " m[1]
    if RegExMatch(tast, "i)^vk[0-9A-F]{2}$") {
        n := GetKeyName(tast)
        tast := n != "" ? n : tast
    }
    return tekst (StrLen(tast) = 1 ? StrUpper(tast) : tast)
}

; =====================================================================
;  XLSX UTEN AVHENGIGHETER – leser og skriver Excel-filer selv
;  (egen zip- og deflate-kode, trenger verken Excel eller andre program)
; =====================================================================

; Returnerer [[A, B], ...] for første ark, i radrekkefølge
XlsxLesRader(fil) {
    zip := ZipAapne(fil)
    wbXml := ZipTekst(zip, "xl/workbook.xml")
    if (wbXml = "")
        throw Error("Filen ser ikke ut som en gyldig .xlsx")
    relXml := ZipTekst(zip, "xl/_rels/workbook.xml.rels")

    arkSti := "xl/worksheets/sheet1.xml"
    if RegExMatch(wbXml, "<sheet\b[^>]*>", &ark) && RegExMatch(ark[0], 'r:id="([^"]+)"', &rid) {
        pos := 1
        while (pos := RegExMatch(relXml, "<Relationship\b[^>]*>", &rel, pos)) {
            pos += rel.Len
            if InStr(rel[0], 'Id="' rid[1] '"', true) && RegExMatch(rel[0], 'Target="([^"]+)"', &maal) {
                arkSti := (SubStr(maal[1], 1, 1) = "/") ? SubStr(maal[1], 2) : "xl/" maal[1]
                break
            }
        }
    }
    arkXml := ZipTekst(zip, arkSti)
    if (arkXml = "")
        throw Error("Fant ikke arket i Excel-filen")
    ssXml := ZipTekst(zip, "xl/sharedStrings.xml")

    strenger := []
    pos := 1
    while (pos := RegExMatch(ssXml, "s)<si>(.*?)</si>", &si, pos)) {
        pos += si.Len
        strenger.Push(XmlUnescape(SamleT(si[1])))
    }

    radMap := Map()
    pos := 1
    while (pos := RegExMatch(arkXml, "s)<c\b([^>]*?)(?:/>|>(.*?)</c>)", &celle, pos)) {
        pos += celle.Len
        if !RegExMatch(celle[1], 'r="([A-Z]+)(\d+)"', &ref)
            continue
        kol := ref[1]
        if (kol != "A" && kol != "B")
            continue
        radNr := Integer(ref[2])
        celleType := RegExMatch(celle[1], 't="(\w+)"', &tm) ? tm[1] : ""
        innhold := celle[2]
        verdi := ""
        if (celleType = "inlineStr") {
            verdi := XmlUnescape(SamleT(innhold))
        } else if RegExMatch(innhold, "s)<v>(.*?)</v>", &vt) {
            if (celleType = "s") {
                idx := Integer(vt[1]) + 1
                verdi := (idx >= 1 && idx <= strenger.Length) ? strenger[idx] : ""
            } else {
                verdi := XmlUnescape(vt[1])
            }
        }
        if !radMap.Has(radNr)
            radMap[radNr] := ["", ""]
        radMap[radNr][kol = "A" ? 1 : 2] := verdi
    }
    rader := []
    for radNr, par in radMap          ; Map går i stigende radrekkefølge
        rader.Push(par)
    return rader
}

SamleT(xml) {
    tekst := ""
    pos := 1
    while (pos := RegExMatch(xml, "s)<t(?:\s[^>]*)?>(.*?)</t>", &t, pos)) {
        pos += t.Len
        tekst .= t[1]
    }
    return tekst
}

XlsxSkriv(fil, rader) {
    SplitPath fil, , &mappe
    if (mappe != "" && !DirExist(mappe))
        DirCreate mappe
    hode := '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`r`n'
    nsMain := "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    nsRel  := "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
    nsPkg  := "http://schemas.openxmlformats.org/package/2006/relationships"

    radXml := '<row r="1"><c r="A1" s="1" t="inlineStr"><is><t>Kode</t></is></c>'
            . '<c r="B1" s="1" t="inlineStr"><is><t>Tekst</t></is></c></row>'
    for i, par in rader {
        r := i + 1
        radXml .= '<row r="' r '"><c r="A' r '" t="inlineStr"><is><t xml:space="preserve">' XmlEscape(par[1]) '</t></is></c>'
                . '<c r="B' r '" s="2" t="inlineStr"><is><t xml:space="preserve">' XmlEscape(par[2]) '</t></is></c></row>'
    }

    deler := [
        ["[Content_Types].xml", hode
            . '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            . '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            . '<Default Extension="xml" ContentType="application/xml"/>'
            . '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            . '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            . '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
            . '</Types>'],
        ["_rels/.rels", hode
            . '<Relationships xmlns="' nsPkg '">'
            . '<Relationship Id="rId1" Type="' nsRel '/officeDocument" Target="xl/workbook.xml"/>'
            . '</Relationships>'],
        ["xl/workbook.xml", hode
            . '<workbook xmlns="' nsMain '" xmlns:r="' nsRel '">'
            . '<sheets><sheet name="Koder" sheetId="1" r:id="rId1"/></sheets></workbook>'],
        ["xl/_rels/workbook.xml.rels", hode
            . '<Relationships xmlns="' nsPkg '">'
            . '<Relationship Id="rId1" Type="' nsRel '/worksheet" Target="worksheets/sheet1.xml"/>'
            . '<Relationship Id="rId2" Type="' nsRel '/styles" Target="styles.xml"/>'
            . '</Relationships>'],
        ["xl/styles.xml", hode
            . '<styleSheet xmlns="' nsMain '">'
            . '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
            . '<fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills>'
            . '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
            . '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
            . '<cellXfs count="3"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
            . '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
            . '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment wrapText="1" vertical="top"/></xf></cellXfs>'
            . '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
            . '</styleSheet>'],
        ["xl/worksheets/sheet1.xml", hode
            . '<worksheet xmlns="' nsMain '">'
            . '<cols><col min="1" max="1" width="18" customWidth="1"/><col min="2" max="2" width="90" customWidth="1"/></cols>'
            . '<sheetData>' radXml '</sheetData></worksheet>']
    ]
    tmp := fil ".tmp"
    ZipSkriv(tmp, deler)
    FileMove tmp, fil, true
}

XmlEscape(tekst) {
    tekst := RegExReplace(tekst, "[\x00-\x08\x0B\x0C\x0E-\x1F]", "")
    tekst := StrReplace(tekst, "&", "&amp;")
    tekst := StrReplace(tekst, "<", "&lt;")
    tekst := StrReplace(tekst, ">", "&gt;")
    tekst := StrReplace(tekst, '"', "&quot;")
    return tekst
}

XmlUnescape(tekst) {
    tekst := StrReplace(tekst, "_x000D_", "")
    while RegExMatch(tekst, "&#(x?)([0-9A-Fa-f]+);", &ent)
        tekst := StrReplace(tekst, ent[0], Chr(ent[1] != "" ? Integer("0x" ent[2]) : Integer(ent[2])))
    tekst := StrReplace(tekst, "&lt;", "<")
    tekst := StrReplace(tekst, "&gt;", ">")
    tekst := StrReplace(tekst, "&quot;", '"')
    tekst := StrReplace(tekst, "&apos;", "'")
    tekst := StrReplace(tekst, "&amp;", "&")
    return tekst
}

; ---- ZIP ----
ZipAapne(fil) {
    data := FileRead(fil, "RAW")
    str := data.Size
    eocd := -1
    i := str - 22
    stopp := Max(0, str - 22 - 65535)
    while (i >= stopp) {
        if (NumGet(data, i, "UInt") = 0x06054b50) {
            eocd := i
            break
        }
        i--
    }
    if (eocd < 0)
        throw Error("Filen er ikke en gyldig .xlsx (zip)")
    antall := NumGet(data, eocd + 10, "UShort")
    pos := NumGet(data, eocd + 16, "UInt")
    filer := Map()
    loop antall {
        if (NumGet(data, pos, "UInt") != 0x02014b50)
            throw Error("Skadet .xlsx-fil")
        nLen := NumGet(data, pos + 28, "UShort")
        navn := StrGet(data.Ptr + pos + 46, nLen, "UTF-8")
        filer[navn] := {metode: NumGet(data, pos + 10, "UShort")
            , kStr: NumGet(data, pos + 20, "UInt")
            , uStr: NumGet(data, pos + 24, "UInt")
            , lokal: NumGet(data, pos + 42, "UInt")}
        pos += 46 + nLen + NumGet(data, pos + 30, "UShort") + NumGet(data, pos + 32, "UShort")
    }
    return {data: data, filer: filer}
}

ZipTekst(zip, navn) {
    if !zip.filer.Has(navn)
        return ""
    e := zip.filer[navn]
    lh := e.lokal
    start := lh + 30 + NumGet(zip.data, lh + 26, "UShort") + NumGet(zip.data, lh + 28, "UShort")
    if (e.metode = 0)
        return StrGet(zip.data.Ptr + start, e.kStr, "UTF-8")
    if (e.metode = 8) {
        ut := Inflate(zip.data, start, e.kStr, e.uStr)
        return StrGet(ut.buf.Ptr, ut.len, "UTF-8")
    }
    throw Error("Ukjent komprimering (" e.metode ") i " navn)
}

ZipSkriv(fil, deler) {
    f := FileOpen(fil, "w", "UTF-8-RAW")
    sentral := []
    for par in deler {
        navnB := Utf8Buf(par[1])
        dataB := Utf8Buf(par[2])
        crc := DllCall("ntdll\RtlComputeCrc32", "UInt", 0, "Ptr", dataB.buf, "UInt", dataB.len, "UInt")
        offset := f.Pos
        f.WriteUInt(0x04034b50), f.WriteUShort(20), f.WriteUShort(0), f.WriteUShort(0)
        f.WriteUShort(0), f.WriteUShort(0x21)
        f.WriteUInt(crc), f.WriteUInt(dataB.len), f.WriteUInt(dataB.len)
        f.WriteUShort(navnB.len), f.WriteUShort(0)
        f.RawWrite(navnB.buf, navnB.len)
        if dataB.len
            f.RawWrite(dataB.buf, dataB.len)
        sentral.Push({navn: navnB, crc: crc, len: dataB.len, offset: offset})
    }
    cdStart := f.Pos
    for e in sentral {
        f.WriteUInt(0x02014b50), f.WriteUShort(20), f.WriteUShort(20), f.WriteUShort(0), f.WriteUShort(0)
        f.WriteUShort(0), f.WriteUShort(0x21)
        f.WriteUInt(e.crc), f.WriteUInt(e.len), f.WriteUInt(e.len)
        f.WriteUShort(e.navn.len), f.WriteUShort(0), f.WriteUShort(0), f.WriteUShort(0), f.WriteUShort(0)
        f.WriteUInt(0), f.WriteUInt(e.offset)
        f.RawWrite(e.navn.buf, e.navn.len)
    }
    cdStr := f.Pos - cdStart
    f.WriteUInt(0x06054b50), f.WriteUShort(0), f.WriteUShort(0)
    f.WriteUShort(sentral.Length), f.WriteUShort(sentral.Length)
    f.WriteUInt(cdStr), f.WriteUInt(cdStart), f.WriteUShort(0)
    f.Close()
}

Utf8Buf(tekst) {
    lengde := StrPut(tekst, "UTF-8") - 1
    buf := Buffer(lengde + 1, 0)
    StrPut(tekst, buf, "UTF-8")
    return {buf: buf, len: lengde}
}

; ---- DEFLATE-dekoder (RFC 1951) ----
Inflate(kilde, start, kildeLen, utLen) {
    static LBASE := [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258]
    static LEXT  := [0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0]
    static DBASE := [1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,257,385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577]
    static DEXT  := [0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13]
    static CLORD := [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]
    static FAST_LIT := "", FAST_DIST := ""

    ut := Buffer(utLen > 0 ? utLen : 1024)
    o := 0
    p := start
    slutt := start + kildeLen
    bb := 0
    bc := 0

    loop {
        sisteBlokk := Bits(1)
        blokkType := Bits(2)
        if (blokkType = 0) {                 ; ukomprimert
            bb := 0, bc := 0
            n := NumGet(kilde, p, "UShort")
            p += 4
            Plass(n)
            DllCall("RtlMoveMemory", "Ptr", ut.Ptr + o, "Ptr", kilde.Ptr + p, "UPtr", n)
            o += n, p += n
        } else if (blokkType = 1) {          ; faste Huffman-koder
            if !IsObject(FAST_LIT) {
                lengder := []
                loop 288
                    lengder.Push(A_Index <= 144 ? 8 : A_Index <= 256 ? 9 : A_Index <= 280 ? 7 : 8)
                FAST_LIT := LagHuff(lengder)
                lengder := []
                loop 30
                    lengder.Push(5)
                FAST_DIST := LagHuff(lengder)
            }
            Blokk(FAST_LIT, FAST_DIST)
        } else if (blokkType = 2) {          ; dynamiske Huffman-koder
            hlit := Bits(5) + 257
            hdist := Bits(5) + 1
            hclen := Bits(4) + 4
            kl := []
            loop 19
                kl.Push(0)
            loop hclen
                kl[CLORD[A_Index] + 1] := Bits(3)
            klHuff := LagHuff(kl)
            lengder := []
            while (lengder.Length < hlit + hdist) {
                s := Dekod(klHuff)
                if (s < 16) {
                    lengder.Push(s)
                } else if (s = 16) {
                    forrigeL := lengder[lengder.Length]
                    loop 3 + Bits(2)
                        lengder.Push(forrigeL)
                } else if (s = 17) {
                    loop 3 + Bits(3)
                        lengder.Push(0)
                } else {
                    loop 11 + Bits(7)
                        lengder.Push(0)
                }
            }
            litL := [], distL := []
            for idx, l in lengder {
                if (idx <= hlit)
                    litL.Push(l)
                else
                    distL.Push(l)
            }
            Blokk(LagHuff(litL), LagHuff(distL))
        } else {
            throw Error("Ugyldig deflate-data")
        }
        if sisteBlokk
            break
    }
    return {buf: ut, len: o}

    Bits(antallBits) {
        while (bc < antallBits) {
            if (p >= slutt)
                throw Error("Uventet slutt på komprimerte data")
            bb |= NumGet(kilde, p, "UChar") << bc
            p += 1
            bc += 8
        }
        verdi := bb & ((1 << antallBits) - 1)
        bb := bb >> antallBits
        bc -= antallBits
        return verdi
    }

    Dekod(h) {
        kode := 0, forste := 0, indeks := 0
        lengde := 1
        while (lengde <= 15) {
            kode |= Bits(1)
            telling := h.ant[lengde + 1]
            if (kode - telling < forste)
                return h.sym[indeks + (kode - forste) + 1]
            indeks += telling
            forste += telling
            forste <<= 1
            kode <<= 1
            lengde++
        }
        throw Error("Ugyldig Huffman-kode")
    }

    Plass(ekstra) {
        if (o + ekstra > ut.Size)
            ut.Size := Max(ut.Size * 2, o + ekstra)
    }

    Blokk(litH, distH) {
        loop {
            sym := Dekod(litH)
            if (sym < 256) {
                Plass(1)
                NumPut("UChar", sym, ut, o)
                o += 1
            } else if (sym = 256) {
                return
            } else {
                sym -= 257
                if (sym >= 29)
                    throw Error("Ugyldig lengdekode")
                antallByte := LBASE[sym + 1] + Bits(LEXT[sym + 1])
                dsym := Dekod(distH)
                if (dsym >= 30)
                    throw Error("Ugyldig avstandskode")
                avstand := DBASE[dsym + 1] + Bits(DEXT[dsym + 1])
                if (avstand > o)
                    throw Error("Ugyldig avstand")
                Plass(antallByte)
                loop antallByte {
                    NumPut("UChar", NumGet(ut, o - avstand, "UChar"), ut, o)
                    o += 1
                }
            }
        }
    }
}

LagHuff(lengder) {
    ant := []
    loop 16
        ant.Push(0)
    for l in lengder
        ant[l + 1] += 1
    ant[1] := 0
    offs := []
    loop 16
        offs.Push(0)
    loop 14
        offs[A_Index + 2] := offs[A_Index + 1] + ant[A_Index + 1]
    sym := []
    sym.Length := lengder.Length
    for i, l in lengder {
        if l {
            sym[offs[l + 1] + 1] := i - 1
            offs[l + 1] += 1
        }
    }
    return {ant: ant, sym: sym}
}


; =====================================================================
;  MAL FOR NYTT VERKTØY
;  1. Kopier klassen under, fjern semikolonene og gi den et eget navn.
;  2. Legg den til i VerktoyListe() øverst i filen.
;  Den får automatisk egen side, plass i oversikten, PÅ/AV-knapp,
;  egen seksjon i QuickerKeys.ini og en linje i menyen ved klokka.
; =====================================================================
; class VT_MittVerktoy extends VT_Base {
;     Navn := "Mitt verktøy"
;     Beskrivelse := "Kort forklaring av hva verktøyet gjør."
;
;     ByggPanel(gui, x, y, b) {
;         Skrift(gui, "s10 bold c" TEMA.tekst)
;         this.Leg(Knapp(gui, "x" x " y" y " w160 h40", "Gjør noe", ObjBindMethod(this, "GjorNoe")))
;     }
;     Start() {
;         this.SettStatus("Klar")          ; kalles når verktøyet slås PÅ
;     }
;     Stopp() {
;     }                                     ; kalles når verktøyet slås AV
;     GjorNoe(*) {
;         Tip("Hei fra " this.Navn)
;     }
; }
