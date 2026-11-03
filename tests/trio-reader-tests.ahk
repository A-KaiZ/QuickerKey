; Appended to a temporary copy of the complete application by run-trio-tests.ps1.
; Execution exits before app startup: no production settings, CSV or timers.
TrioAssert(ok, label) {
    if !ok
        throw Error("Test failed: " label)
    FileAppend("PASS " label "`n", "*", "UTF-8")
}

TrioTestRad(dato := "03.11.2026 09:12:34", id := "9876543210", tid := "02:30") {
    return {felt:Map("tidspunkt",dato,"oppgave",id,"behandling",tid), konflikt:false}
}

RunTrioTests() {
    fixturePid := 0, exitCode := 0
    try {
        r := TrioOppgaveloggDiagnose()
        TrioAssert(r.KolonneKey("Oppgave-ID") = "oppgave", "header alias")
        TrioAssert(r.KolonneKey("Kundenummer") = "", "customer column is not an ID source")
        TrioAssert(r.Tidsstempel("3.11.2026 9:12") = "20261103091200", "Norwegian minute precision")
        TrioAssert(r.Tidsstempel("2026-11-03T09:12:34") = "20261103091234", "ISO timestamp")
        TrioAssert(r.Tidsstempel("31.02.2026 09:12:34") = "", "impossible date rejected")
        TrioAssert(r.Tidsstempel("03.11.2026 24:00:00") = "", "invalid hour rejected")
        TrioAssert(r.VarighetSekunder("01:02:03") = 3723, "hour duration")
        TrioAssert(r.VarighetSekunder("12:60") = -1, "invalid duration rejected")
        schema := {kolonner:[{key:"oppgave",l:0,r:80},{key:"",l:80,r:100}
            ,{key:"behandling",l:100,r:180}], kart:Map("oppgave",true,"behandling",true)}
        TrioAssert(r.CelleKolonne({l:105,r:170},schema) = "behandling", "cell aligns with named header")
        TrioAssert(r.CelleKolonne({l:0,r:180},schema) = "", "whole row is not one cell")
        TrioAssert(r.CelleKolonne({l:82,r:98},schema) = "", "icon column ignored")
        rad := TrioTestRad()
        rad.felt["ko"] := "00:10"
        rad.felt["koblet"] := "Nei"
        rad.felt["kommentar"] := "Synthetic-private-text IM99887766"
        out := r.NyLesing()
        r.VurderRader([rad,rad,TrioTestRad("02.11.2026 09:12:34")],out,"20261103")
        TrioAssert(out.sett.Count = 1 && out.andreDager = 1, "duplicate and previous-day filtering")
        for key, post in out.sett {
            TrioAssert(post.sek = 150 && post.koSek = 10 && post.im && !post.videre,
                "minimal summary and negative Koblet value")
        }
        r.AvsluttLesing(out)
        TrioAssert(!InStr(out.detaljer,"9876543210") && !InStr(out.detaljer,"IM99887766")
            && !InStr(out.detaljer,"Synthetic-private-text"), "diagnostic contains no raw values")
        mangler := TrioTestRad()
        mangler.felt.Delete("behandling")
        konflikt := TrioTestRad()
        r.SettFelt(konflikt,"oppgave","1234567")
        out := r.NyLesing()
        r.VurderRader([mangler,TrioTestRad("bad date"),TrioTestRad(,"not-an-id")
            ,TrioTestRad(,,"N/A"),konflikt],out,"20261103")
        TrioAssert(out.avvist = 5 && out.grunner["felt"] = 1 && out.grunner["dato"] = 1
            && out.grunner["id"] = 1 && out.grunner["tid"] = 1 && out.grunner["konflikt"] = 1,
            "separate rejection reasons")
        a := {felt:Map("oppgave","42"),konflikt:false}
        b := {felt:Map("tidspunkt","03.11.2026 09:00:00","behandling","01:00"),konflikt:false}
        r.FlettFelt(a,b)
        TrioAssert(r.HarNokkelfelt(a.felt) && !a.konflikt, "same-row cell merge")
        ; Exercise the real Win32 and UIA backends in a second process.
        Run('"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptDir '\trio-fixture.ahk"',,, &fixturePid)
        hwnd := WinWait("QuickerKeys synthetic Trio fixture ahk_pid " fixturePid,,10)
        TrioAssert(hwnd != 0,"synthetic ListView opened")
        Sleep 500
        before := WinExist("A")
        native := r.HentDagensData(hwnd)
        FileAppend(native.status "`n" native.detaljer "`n", "*", "UTF-8")
        TrioAssert(native.ok && native.sett.Count = 2 && native.andreDager = 1
            && InStr(native.kilde,"Win32"), "native non-13-column named mapping")
        uia := r.HentDagensData(hwnd,true)
        FileAppend(uia.status "`n" uia.detaljer "`n", "*", "UTF-8")
        TrioAssert(uia.ok && uia.sett.Count = 2 && InStr(uia.kilde,"UIA"), "real UIA ListItem cell mapping")
        TrioAssert(WinExist("A") = before,"background read preserves focus")
        again := r.HentDagensData(hwnd,true)
        TrioAssert(again.sett.Count = uia.sett.Count,"repeated UIA scan is stable")
        for key, post in native.sett {
            TrioAssert(uia.sett.Has(key) && uia.sett[key].sek = post.sek
                && uia.sett[key].im = post.im,"native/UIA summaries agree")
        }
        WinMinimize "ahk_id " hwnd
        minimized := r.HentDagensData(hwnd)
        TrioAssert(!minimized.ok && InStr(minimized.status,"minimert"),"minimized window is not read")
        ProcessClose fixturePid
        ProcessWaitClose fixturePid, 5
        Run('"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptDir '\trio-fixture.ahk" reordered',,, &fixturePid)
        hwnd := WinWait("QuickerKeys synthetic Trio fixture ahk_pid " fixturePid,,10)
        TrioAssert(hwnd != 0,"reordered fixture opened")
        Sleep 500
        native := r.HentDagensData(hwnd)
        uia := r.HentDagensData(hwnd,true)
        FileAppend(uia.status "`n" uia.detaljer "`n", "*", "UTF-8")
        TrioAssert(native.ok && uia.ok && native.sett.Count = 2 && uia.sett.Count = 2,
            "visual column reorder supported by both backends")
        for key, post in native.sett
            TrioAssert(uia.sett.Has(key) && uia.sett[key].sek = post.sek,
                "native/UIA agree after visual reorder")
        FileAppend("ALL TRIO TESTS PASSED`n", "*", "UTF-8")
    } catch as err {
        FileAppend("FAIL " err.Message " (line " err.Line ")`n", "**", "UTF-8")
        exitCode := 1
    } finally {
        if fixturePid && ProcessExist(fixturePid) {
            ProcessClose fixturePid
            ProcessWaitClose fixturePid, 5
        }
    }
    ExitApp exitCode
}
