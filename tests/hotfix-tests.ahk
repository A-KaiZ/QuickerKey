; Runs against a temporary copy of the complete app, before production startup.
HotfixAssert(ok, label) {
    if !ok
        throw Error("FAIL " label)
    FileAppend("PASS " label "`n", "*", "UTF-8")
}

; Send at a physical-input level so actual hotstring hooks receive the keys.
HotfixType(tekst, hwnd, expected) {
    ControlSetText "", "Edit1", "ahk_id " hwnd
    WinActivate "ahk_id " hwnd
    WinWaitActive "ahk_id " hwnd, , 2
    ControlFocus "Edit1", "ahk_id " hwnd
    Hotstring("Reset")
    SendLevel 1
    SendEvent "{Text}" StrReplace(tekst, "{Enter}")
    if InStr(tekst, "{Enter}")
        SendEvent "{Enter}"
    SendLevel 0
    deadline := A_TickCount + 3000
    while (A_TickCount < deadline) {
        Sleep 30
        if (ControlGetText("Edit1", "ahk_id " hwnd) == expected)
            return true
    }
    FileAppend("Expected [" expected "] actual [" ControlGetText("Edit1", "ahk_id " hwnd) "]`n", "*", "UTF-8")
    return false
}

RunHotfixTests() {
    global INI_FIL := A_ScriptDir "\test.ini", TEKST_MAPPE := A_ScriptDir
    global LOGG_MAPPE := A_ScriptDir, LOGG_LINJER := [], APP_KTRL := Map(), OVERSIKT := Map()
    global APP_NAVN := "QuickerKeys", DIPS_INI_FIL := A_ScriptDir "\DIPS.ini"
    fixturePid := 0, tf := "", dlg := "", code := 0
    try {
        HotfixAssert(TekstflytSignatur("#dwa", "TEST", "", "20261104120000") == "(test) 041126", "signature without clipboard")
        HotfixAssert(TekstflytSignatur("#DWA", "TEST", "123456789", "20261104120000") == "(test) 041126 123456789", "nine characters and case insensitive code")
        for klipp in ["12345678", "1234567890", ""]
            HotfixAssert(TekstflytSignatur("#dwa", "TEST", klipp, "20261104120000") == "(test) 041126", "other clipboard lengths omitted")
        HotfixAssert(TekstflytSignatur("#dwr", "TEST", "123456789", "20260101000100") == "(test) 010126 D2358", "dwr fixed suffix and current date formatting")
        HotfixAssert(TekstflytSignatur("#dwa", "TeSt", "ABcd12345", "20261104120000") == "(test) 041126 ABcd12345", "mixed-case initials lowercased and clipboard case preserved")
        rejected := false
        try TekstflytSignatur("#dwa", "", "")
        catch
            rejected := true
        HotfixAssert(rejected, "empty initials rejected")
        Hotstring("EndChars", " `n")
        tf := VT_Tekstflyt()
        HotfixAssert(tf.SignaturBruker() == StrLower(A_UserName), "Windows username fallback")
        IniWrite "LEGACY", INI_FIL, "User", "Username"
        HotfixAssert(tf.SignaturBruker() == StrLower(A_UserName), "legacy imported identity cannot override Windows account")
        tf.Lagre("Initialer", "OLDINI")
        HotfixAssert(tf.SignaturBruker() == StrLower(A_UserName), "legacy Tekstflyt identity cannot override Windows account")
        RunDipsProfileTests()
        DipsLagreProfil("TEST", "D2358")
        HotfixAssert(tf.SignaturBruker() == "test", "account-bound DIPS username selected")
        tf.Aktiv := true
        tf.ExcelFil := A_ScriptDir "\missing.xlsx"
        tf.Start()
        HotfixAssert(tf.Koder.Count = 0, "missing workbook does not create replacement")
        Run '"' A_AhkPath '" "' A_ScriptDir '\hotfix-fixture.ahk"', , , &fixturePid
        hwnd := WinWait("QuickerKeys synthetic editor ahk_pid " fixturePid, , 5)
        HotfixAssert(hwnd, "external editor fixture started")
        A_Clipboard := "123456789"
        HotfixAssert(HotfixType("#dwa ", hwnd, "(test) " FormatTime(, "ddMMyy") " 123456789"), "actual dwa hotstring without workbook")
        Sleep 400
        HotfixAssert(A_Clipboard = "123456789", "clipboard text restored after paste")
        HotfixAssert(HotfixType("#dwr{Enter}", hwnd, "(test) " FormatTime(, "ddMMyy") " D2358"), "actual dwr hotstring with Enter")
        DipsLagreProfil("NEXT", "D2358")
        A_Clipboard := "short"
        HotfixAssert(HotfixType("#DWA ", hwnd, "(next) " FormatTime(, "ddMMyy")), "initials update immediately and uppercase trigger works")
        DipsLagreProfil("NEXT", "Avd7")
        HotfixAssert(HotfixType("#dwr ", hwnd, "(next) " FormatTime(, "ddMMyy") " Avd7"), "dwr uses personal suffix without changing case")
        DipsLagreProfil("NEXT", "")
        HotfixAssert(HotfixType("#dwr ", hwnd, "(next) " FormatTime(, "ddMMyy")), "empty personal suffix leaves no trailing space")
        DipsLagreProfil("NEXT", "D2358")
        tf.ExcelFil := A_ScriptDir "\codes.xlsx"
        XlsxSkriv(tf.ExcelFil, [["#dwa", "WRONG"], ["#hello", "hello"]])
        HotfixAssert(tf.Sync(), "workbook loaded alongside signatures")
        HotfixAssert(HotfixType("#hello ", hwnd, "hello"), "ordinary Excel expansion unchanged")
        HotfixAssert(HotfixType("#dwa ", hwnd, "(next) " FormatTime(, "ddMMyy")), "Excel cannot override signature")
        XlsxSkriv(tf.ExcelFil, [["#hello", "hello"]])
        HotfixAssert(tf.Sync(), "workbook signature row removed")
        HotfixAssert(HotfixType("#dwa ", hwnd, "(next) " FormatTime(, "ddMMyy")), "removing Excel row cannot disable signature")
        tf.Aktiv := false
        HotfixAssert(HotfixType("#dwa ", hwnd, "#dwa "), "Tekstflyt off disables builtins")
        tf.Stopp()

        for label in ["5 minutter", "5 min", "5 minutt", "00:05:00", "05:00", "Etterarbeid: 5 min"]
            HotfixAssert(TrioErFemMinutter(label), "five minute label " label)
        for label in ["15 minutter", "50 min", "5 sekunder", "00:05", "5", "Etterarbeid"]
            HotfixAssert(!TrioErFemMinutter(label), "unrelated duration rejected " label)
        dlg := Gui(, "Synthetic duration")
        cb := dlg.AddDropDownList("w200", ["1 min", "15 minutter", "5 minutter", "10 min"])
        cb.Choose(1)
        dlg.Show()
        WinActivate "ahk_id " dlg.Hwnd
        WinWaitActive "ahk_id " dlg.Hwnd, , 2
        HotfixAssert(TrioVelgFemMinutter(dlg.Hwnd) && cb.Value = 3, "native duration choice found by text, not position")
        extra := dlg.AddListBox("w200", ["5 minutter"])
        cb.Choose(1)
        HotfixAssert(!TrioVelgFemMinutter(dlg.Hwnd) && cb.Value = 1, "ambiguous five minute choice leaves original selection")
        dlg.Destroy()
        dlg := Gui(, "Synthetic no five minute option")
        dlg.AddDropDownList("w200", ["1 min", "15 minutter"])
        dlg.Show()
        WinActivate "ahk_id " dlg.Hwnd
        WinWaitActive "ahk_id " dlg.Hwnd, , 2
        HotfixAssert(!TrioVelgFemMinutter(dlg.Hwnd), "missing five minute choice not guessed")
        dlg.Destroy()
        trio := VT_TrioSnarveier()
        HotfixAssert(trio.Hent("HKetterarbeid5") = "!F3" && trio.Hent("EnabledHKetterarbeid5") = "on", "Alt F3 default enabled")
        trio.Lagre("HKetterarbeid5", "!F4")
        trio.Lagre("EnabledHKetterarbeid5", "off")
        trio := VT_TrioSnarveier()
        HotfixAssert(trio.Hent("HKetterarbeid5") = "!F4" && trio.Hent("EnabledHKetterarbeid5") = "off", "saved shortcut and disabled state preserved")
        IniDelete INI_FIL, "TrioSnarveier", "HKetterarbeid5"
        IniWrite "!F3", INI_FIL, "App", "VisTast"
        trio := VT_TrioSnarveier()
        HotfixAssert(trio.Hent("EnabledHKetterarbeid5") = "off", "default shortcut conflict does not displace existing key")
        RunDipsUiTests()
    } catch as feil {
        FileAppend(feil.Message " at line " feil.Line "`n" feil.Stack "`n", "*", "UTF-8")
        code := 1
    } finally {
        if IsObject(tf)
            tf.Stopp()
        if IsObject(dlg)
            try dlg.Destroy()
        if fixturePid
            try ProcessClose fixturePid
    }
    ExitApp code
}


RunDipsProfileTests() {
    global DIPS_INI_FIL
    DipsLagreProfil("MiXeD", "Avd7")
    profil := DipsHentProfil()
    HotfixAssert(profil.bruker == "mixed" && profil.tillegg == "Avd7", "DIPS profile preserves suffix and lowercases username")
    HotfixAssert(IniRead(DIPS_INI_FIL, "Signatur", "Konto") = DipsKonto(), "profile bound to current Windows account")
    for konto in ["OTHERDOMAIN\OTHERUSER", ""] {
        IniWrite konto, DIPS_INI_FIL, "Signatur", "Konto"
        profil := DipsHentProfil()
        HotfixAssert(profil.fremmed && profil.bruker == StrLower(A_UserName) && profil.tillegg == "D2358"
            , "foreign or unowned profile is not reused")
    }
    DipsLagreProfil("", "")
    profil := DipsHentProfil()
    HotfixAssert(profil.eget = "" && profil.bruker == StrLower(A_UserName) && profil.tillegg = "", "automatic account name and empty suffix persist")
    DipsLagreProfil("LOCAL", "Local7")
    original := FileRead(DIPS_INI_FIL)
    rejected := false
    try DipsLagreProfil("two names", "Other")
    catch
        rejected := true
    HotfixAssert(rejected && FileRead(DIPS_INI_FIL) == original, "invalid username cannot replace saved profile")
    rejected := false
    try DipsLagreProfil("LOCAL", "line1`nline2")
    catch
        rejected := true
    HotfixAssert(rejected && FileRead(DIPS_INI_FIL) == original, "multiline suffix cannot replace saved profile")
    fil := A_ScriptDir "\shared.ini"
    FileAppend "[App]`nTema=Grafitt`n[Tekstflyt]`nInitialer=FOREIGN`nExcelFil=C:\foreign.xlsx`n[User]`nUsername=FOREIGN`n[DIPS]`nBrukernavn=FOREIGN`n[Signatur]`nKonto=OTHER`nBrukernavn=FOREIGN`nTillegg=OTHER`n", fil
    endringer := HentImporterbareEndringer(fil)
    HotfixAssert(endringer.Length = 1 && endringer[1].seksjon = "App" && endringer[1].nokkel = "Tema"
        , "configuration import keeps general settings and excludes all personal identity fields")
    HotfixAssert(FileRead(DIPS_INI_FIL) == original, "configuration import reader leaves DIPS profile untouched")
}

HotfixCapture(hwnd, navn) {
    path := A_ScriptDir "\" navn ".png"
    result := RunWait('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' A_ScriptDir '\hotfix-capture.ps1" -Hwnd ' hwnd ' -Path "' path '"', , "Hide")
    HotfixAssert(result = 0 && FileExist(path), "native UI capture " navn)
}

RunDipsUiTests() {
    global HOVED, TEMA := TemaPalett("Midnatt"), DATA_MAPPE := A_ScriptDir, INNST_MAPPE := A_ScriptDir
    global APP_VERSJON := "3.11.3", APP_B := 700, APP_H := 560, INNHOLD_X := 184, INNHOLD_B := 492
    global PANELER := Map(), NAVKNAPPER := Map(), VIS_VILKAR := Map(), NAV_FOR := Map(), NETT_PAA := false
    global VERKTOY_LISTE := VerktoyListe(), DIPS_INI_FIL
    global STATS_MAPPE := A_ScriptDir "\Statistikk", STATS
    DirCreate STATS_MAPPE
    STATS := StatistikkModul() ; Match the combined app's panel setup without starting Trio timers.
    ByggHovedvindu()
    VisPanel("Innstillinger")
    HOVED.Show("w" APP_B " h" APP_H)
    Sleep 200
    dipsKnapp := "", nettKnapp := ""
    for ctrl in PANELER["Innstillinger"] {
        ctrl.GetPos(&x, &y, &w, &h)
        HotfixAssert(y + h <= APP_H, "settings control remains inside window")
        if (ctrl.Text = "DIPS-innstillinger")
            dipsKnapp := ctrl
        if (ctrl.Text = "Aktiver Nettverk")
            nettKnapp := ctrl
    }
    HotfixAssert(IsObject(dipsKnapp) && IsObject(nettKnapp), "settings has DIPS and neutral network actions")
    HotfixAssert(!InStr(WinGetText("ahk_id " HOVED.Hwnd), "Nettverksgeni"), "professional settings labels")
    HotfixCapture(HOVED.Hwnd, "ui-settings")
    DipsLagreProfil("demobruker", "D2358")
    ui := DipsSignaturDialog()
    ui.Vindu.Show("w500 h528")
    Sleep 200
    HotfixAssert(!ui.Auto.Value && ui.Bruker.Enabled, "custom username mode loads into dialog")
    ui.Bruker.Value := "MiXeD"
    ui.Tillegg.Value := "Avd7"
    ui.OppdaterForhandsvisning()
    HotfixAssert(StrReplace(ui.Forhandsvisning.Value, "`r`n", "`n") == "#dwa  (mixed) " FormatTime(, "ddMMyy") "`n#dwr  (mixed) " FormatTime(, "ddMMyy") " Avd7"
        , "live preview matches actual signatures")
    ui.Auto.Value := 1
    ui.VekslAutomatisk()
    HotfixAssert(!ui.Bruker.Enabled && InStr(ui.Forhandsvisning.Value, "(" StrLower(A_UserName) ")"), "automatic mode disables custom field and previews Windows account")
    ui.Auto.Value := 0
    ui.VekslAutomatisk()
    original := FileRead(DIPS_INI_FIL)
    ui.Bruker.Value := ""
    ui.Lagre()
    HotfixAssert(FileRead(DIPS_INI_FIL) == original && WinExist("ahk_id " ui.Vindu.Hwnd), "empty custom username is rejected without saving or closing")
    ui.Bruker.Value := "demobruker"
    ui.Tillegg.Value := "D2358"
    ui.OppdaterForhandsvisning()
    HotfixCapture(ui.Vindu.Hwnd, "ui-dips")
    ui.Lagre()
    profil := DipsHentProfil()
    HotfixAssert(profil.bruker == "demobruker" && profil.tillegg == "D2358", "DIPS dialog saves personal settings")
    HOVED.Destroy()
}
