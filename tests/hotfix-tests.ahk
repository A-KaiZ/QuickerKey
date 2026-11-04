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
    SendLevel 1
    SendEvent tekst
    SendLevel 0
    deadline := A_TickCount + 3000
    while (A_TickCount < deadline) {
        Sleep 30
        if (ControlGetText("Edit1", "ahk_id " hwnd) = expected)
            return true
    }
    return false
}

RunHotfixTests() {
    global INI_FIL := A_ScriptDir "\test.ini", TEKST_MAPPE := A_ScriptDir
    global LOGG_MAPPE := A_ScriptDir, LOGG_LINJER := [], APP_KTRL := Map(), OVERSIKT := Map()
    global APP_NAVN := "QuickerKeys tests"
    fixturePid := 0, tf := "", dlg := "", code := 0
    try {
        HotfixAssert(TekstflytSignatur("#dwa", "TEST", "", "20261104120000") = "(TEST) 041126", "signature without clipboard")
        HotfixAssert(TekstflytSignatur("#DWA", "TEST", "123456789", "20261104120000") = "(TEST) 041126 123456789", "nine characters and case insensitive code")
        for klipp in ["12345678", "1234567890", ""]
            HotfixAssert(TekstflytSignatur("#dwa", "TEST", klipp, "20261104120000") = "(TEST) 041126", "other clipboard lengths omitted")
        HotfixAssert(TekstflytSignatur("#dwr", "TEST", "123456789", "20260101000100") = "(TEST) 010126 D2358", "dwr fixed suffix and current date formatting")
        rejected := false
        try TekstflytSignatur("#dwa", "", "")
        catch
            rejected := true
        HotfixAssert(rejected, "empty initials rejected")
        Hotstring("EndChars", " `n")
        tf := VT_Tekstflyt()
        HotfixAssert(tf.SignaturBruker() = A_UserName, "Windows username fallback")
        IniWrite "LEGACY", INI_FIL, "User", "Username"
        HotfixAssert(tf.SignaturBruker() = "LEGACY", "legacy User Username supported")
        tf.Lagre("Initialer", "TEST")
        HotfixAssert(tf.SignaturBruker() = "TEST", "saved initials take priority")
        tf.Aktiv := true
        tf.ExcelFil := A_ScriptDir "\missing.xlsx"
        tf.Start()
        HotfixAssert(tf.Koder.Count = 0, "missing workbook does not create replacement")
        Run '"' A_AhkPath '" "' A_ScriptDir '\hotfix-fixture.ahk"', , , &fixturePid
        hwnd := WinWait("QuickerKeys synthetic editor ahk_pid " fixturePid, , 5)
        HotfixAssert(hwnd, "external editor fixture started")
        A_Clipboard := "123456789"
        HotfixAssert(HotfixType("#dwa ", hwnd, "(TEST) " FormatTime(, "ddMMyy") " 123456789"), "actual dwa hotstring without workbook")
        Sleep 400
        HotfixAssert(A_Clipboard = "123456789", "clipboard text restored after paste")
        HotfixAssert(HotfixType("#dwr{Enter}", hwnd, "(TEST) " FormatTime(, "ddMMyy") " D2358"), "actual dwr hotstring with Enter")
        tf.Lagre("Initialer", "NEXT")
        A_Clipboard := "short"
        HotfixAssert(HotfixType("#DWA ", hwnd, "(NEXT) " FormatTime(, "ddMMyy")), "initials update immediately and uppercase trigger works")
        tf.ExcelFil := A_ScriptDir "\codes.xlsx"
        XlsxSkriv(tf.ExcelFil, [["#dwa", "WRONG"], ["#hello", "hello"]])
        HotfixAssert(tf.Sync(), "workbook loaded alongside signatures")
        HotfixAssert(HotfixType("#hello ", hwnd, "hello"), "ordinary Excel expansion unchanged")
        HotfixAssert(HotfixType("#dwa ", hwnd, "(NEXT) " FormatTime(, "ddMMyy")), "Excel cannot override signature")
        XlsxSkriv(tf.ExcelFil, [["#hello", "hello"]])
        HotfixAssert(tf.Sync(), "workbook signature row removed")
        HotfixAssert(HotfixType("#dwa ", hwnd, "(NEXT) " FormatTime(, "ddMMyy")), "removing Excel row cannot disable signature")
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
