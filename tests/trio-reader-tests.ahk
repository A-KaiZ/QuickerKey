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

; Remove cell rectangles after the first two complete rows. The source
; still exposes their text, mirroring offscreen-but-realized provider items.
class TrioOffscreenTestLeser extends TrioOppgaveloggDiagnose {
    TextBesok := 0
    Rektangel(el) {
        if (UiaTall(el,30003) = 50020) {
            this.TextBesok++
            if (this.TextBesok > 14)
                return ""
        }
        return super.Rektangel(el)
    }
}

class TrioSourceTestLeser extends TrioOppgaveloggDiagnose {
    CelleEgenskap(el, id) => el.HasOwnProp("props") && el.props.Has(id)
        ? {tekst:el.props[id],vt:8} : {tekst:"",vt:13}
    CelleTextPattern(el, maks := 512) => el.HasOwnProp("text")
        ? {tekst:el.text,stottet:true} : {tekst:"",stottet:false}
    CelleForelder(el) => el.HasOwnProp("parent") ? el.parent : ""
    CelleKontrolltype(el) => el.HasOwnProp("type") ? el.type : 50020
    Rektangel(el) => el.HasOwnProp("rect") ? el.rect : ""
}

; Exercise the real Windows LegacyIAccessible backend with primary cell
; Name/Value deliberately suppressed, without changing HeaderItem reads.
class TrioLegacyOnlyLeser extends TrioOppgaveloggDiagnose {
    CelleEgenskap(el,id) {
        if (id = 30005 || id = 30045)
            return {tekst:"",vt:8}
        return super.CelleEgenskap(el,id)
    }
}

RunTrioTests() {
    fixturePid := 0, exitCode := 0
    try {
        r := TrioOppgaveloggDiagnose()
        sourceReader := TrioSourceTestLeser()
        sourceOut := sourceReader.NyLesing()
        datum := FormatTime(,"dd.MM.yyyy") " 09:40:38"
        legacyCell := {props:Map(30005,"",30045,"",30092,datum)}
        TrioAssert(sourceReader.LesCelleVerdi(legacyCell,"tidspunkt",sourceOut) = datum
            && sourceOut.valgteTidskilder.Has("celle LegacyName"), "empty Name/Value recovered from LegacyName")
        textCell := {props:Map(),text:datum}
        TrioAssert(sourceReader.LesCelleVerdi(textCell,"tidspunkt",sourceOut) = datum
            && sourceOut.valgteTidskilder.Has("celle TextPattern"), "empty properties recovered from TextPattern")
        conflictCell := {props:Map(30092,"03.11.2026 09:00:00",30093,"02.11.2026 09:00:00")}
        TrioAssert(sourceReader.LesCelleVerdi(conflictCell,"tidspunkt",sourceOut) = "", "conflicting Legacy timestamps rejected")
        sourceOut.kolonner := [{key:"tidspunkt",navn:"Tidspunkt",l:0,r:100}]
        sourceOut.kart := Map("tidspunkt",true)
        wrapper := {props:Map(30005,datum),type:50033,rect:{l:0,r:100,t:0,b:20}}
        nested := {props:Map(),parent:wrapper}
        TrioAssert(sourceReader.LesCelleVerdi(nested,"tidspunkt",sourceOut) = datum
            && sourceOut.valgteTidskilder.Has("celleforelder Name"), "same-column parent text recovered")
        otherColumn := {props:Map(30005,datum),type:50033,rect:{l:100,r:200,t:0,b:20}}
        TrioAssert(sourceReader.LesCelleVerdi({props:Map(),parent:otherColumn},"tidspunkt",sourceOut) = "",
            "parent from another column is not read")
        wholeRow := {props:Map(30005,datum),type:50007,rect:{l:0,r:100,t:0,b:20}}
        TrioAssert(sourceReader.LesCelleVerdi({props:Map(),parent:wholeRow},"tidspunkt",sourceOut) = "",
            "whole-row parent is not interpreted as cell text")
        sourceReader.AvsluttLesing(sourceOut)
        TrioAssert(!InStr(sourceOut.detaljer,"09:40:38") && InStr(sourceOut.detaljer,"TextPattern"),
            "text-source diagnostic masks timestamps")
        rowHint := {felt:Map(),konflikt:false,blader:[{props:Map()},{props:Map(30092,"9876543210")}]
            ,radTid:datum}
        sourceReader.LesKartlagteFelt(rowHint,Map(1,"tidspunkt",2,"oppgave"),sourceOut)
        TrioAssert(rowHint.felt["tidspunkt"] = datum && rowHint.felt["oppgave"] = "9876543210",
            "strict first-column row timestamp hint supports empty leaf")
        TrioAssert(r.KolonneKey("Oppgave-ID") = "oppgave", "header alias")
        TrioAssert(r.KolonneKey("Behand" Chr(0xAD) "lingstid") = "behandling", "soft hyphen in duration header")
        TrioAssert(r.KolonneKey("Behandlings" Chr(0x200B) "tid") = "behandling", "zero-width duration header")
        TrioAssert(r.KolonneKey("&Behandling" Chr(0xA0) "stid") = "behandling", "mnemonic and NBSP in header")
        TrioAssert(r.KolonneKey("Behandl. tid") = "behandling" && r.KolonneKey("Beh. tid") = "behandling", "duration abbreviations")
        TrioAssert(r.KolonneKey("Tid") = "" && r.KolonneKey("Køtid") = "ko", "unrelated time is not treatment duration")
        TrioAssert(r.OverskriftTilDiagnose("Behand" Chr(0xAD) "lingstid") = "Behand[U+00AD]lingstid", "diagnostic exposes invisible header characters")
        TrioAssert(r.KolonneKey("Kundenummer") = "", "customer column is not an ID source")
        TrioAssert(r.Tidsstempel("3.11.2026 9:12") = "20261103091200", "Norwegian minute precision")
        TrioAssert(r.Tidsstempel("02.11.2026 09:40:38") = "20261102094038", "observed Trio timestamp example")
        TrioAssert(r.Tidsstempel("Tidspunkt: " Chr(0x200E) "03.11.2026" Chr(0xA0) "09:40:38") = "20261103094038", "timestamp label and invisible characters")
        timeOut := r.NyLesing()
        chosen := r.VelgTidsverdi("03.11.2026 09:40:38","unparseable-provider-value",timeOut)
        TrioAssert(chosen = "03.11.2026 09:40:38" && timeOut.tidFraName = 1, "valid Name beats unusable Value")
        TrioAssert(r.VelgTidsverdi("03.11.2026 09:40:38","02.11.2026 09:40:38",timeOut) = "", "conflicting valid dates rejected")
        TrioAssert(!InStr(r.MaskertFormat("03.11.2026 09:40:38"),"2026") && r.MaskertFormat("03.11.2026 09:40:38") = "dd.dd.dddd dd:dd:dd", "timestamp diagnostic contains format only")
        days := r.NyLesing()
        r.VurderRader([{felt:Map("tidspunkt","12.10.2026 09:00:00"),konflikt:false}
            ,{felt:Map("tidspunkt","02.11.2026 09:00:00"),konflikt:false}
            ,TrioTestRad(),TrioTestRad("04.11.2026 09:00:00")],days,"20261103")
        TrioAssert(days.sett.Count = 1 && days.andreDager = 3 && days.avvist = 0, "only 03.11.2026 retained across multi-day history")
        nextDay := r.NyLesing()
        r.VurderRader([TrioTestRad(),TrioTestRad("04.11.2026 09:00:00")],nextDay,"20261104")
        TrioAssert(nextDay.sett.Count = 1 && nextDay.andreDager = 1, "date filter advances without a hardcoded date")
        proofSchema := {kolonner:[1,2,3],kart:Map("tidspunkt",true,"oppgave",true)}
        proofA := {felt:Map("tidspunkt",FormatTime(,"dd.MM.yyyy") " 09:00:00"),konflikt:false
            ,blader:[1,2,3],form:"same-shape",feltindeks:Map(1,"tidspunkt",2,"oppgave")}
        proofB := {felt:Map("tidspunkt",FormatTime(,"dd.MM.yyyy") " 10:00:00"),konflikt:false
            ,blader:[1,2,3],form:"same-shape",feltindeks:Map(1,"oppgave",2,"tidspunkt")}
        unmapped := {felt:Map(),konflikt:false,blader:[1,2,3],form:"same-shape",feltindeks:Map()}
        proofOut := r.NyLesing()
        r.SupplerUtenPlassering([proofA,proofB,unmapped],proofSchema,proofOut,A_TickCount+1000)
        TrioAssert(proofOut.bekreftedeKart = 0 && unmapped.felt.Count = 0, "contradictory observed cell maps never used")


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
        mangler.felt.Delete("oppgave")
        konflikt := TrioTestRad()
        r.SettFelt(konflikt,"oppgave","1234567")
        out := r.NyLesing()
        r.VurderRader([mangler,TrioTestRad("bad date"),TrioTestRad(,"not-an-id")
            ,TrioTestRad(,,"N/A"),konflikt],out,"20261103")
        TrioAssert(out.avvist = 4 && out.grunner["felt"] = 1 && out.grunner["dato"] = 1
            && out.grunner["id"] = 1 && out.grunner["konflikt"] = 1 && out.sett.Count = 1
            && out.behandlingUgyldig = 1, "identity rejection reasons and independent unknown duration")
        noDuration := TrioTestRad()
        noDuration.felt.Delete("behandling")
        out := r.NyLesing()
        r.VurderRader([noDuration],out,"20261103")
        TrioAssert(out.ok && out.sett.Count = 1 && out.behandlingMangler = 1, "count tasks without duration header")
        sum := StatistikkModul.Prototype.TrioSummering.Call({TrioOppgaver:out.sett})
        TrioAssert(sum.antall = 1 && sum.behandlingN = 0 && sum.sek = 0, "unknown duration excluded from time totals")
        zeroDuration := TrioTestRad(,,"00:00")
        out := r.NyLesing()
        r.VurderRader([zeroDuration],out,"20261103")
        sum := StatistikkModul.Prototype.TrioSummering.Call({TrioOppgaver:out.sett})
        TrioAssert(sum.behandlingN = 1 && sum.sek = 0, "real zero duration remains known")
        a := {felt:Map("oppgave","42"),konflikt:false}
        b := {felt:Map("tidspunkt","03.11.2026 09:00:00","behandling","01:00"),konflikt:false}
        r.FlettFelt(a,b)
        TrioAssert(r.HarIdentitetsfelt(a.felt) && !a.konflikt, "same-row cell merge")
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
        legacyOnly := TrioLegacyOnlyLeser().HentDagensData(hwnd,true)
        FileAppend(legacyOnly.status "`n" legacyOnly.detaljer "`n","*","UTF-8")
        TrioAssert(legacyOnly.ok && legacyOnly.sett.Count = 2 && legacyOnly.andreDager = 1,
            "real UIA Legacy fallback with empty primary Name/Value")
        editEl := UiaFraVindu(ControlGetHwnd("Edit1","ahk_id " hwnd))
        patternText := r.CelleTextPattern(editEl)
        TrioAssert(patternText.stottet && InStr(patternText.tekst,"09:40:38"),
            "actual Windows TextPattern COM read")

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
        FileAppend(native.status "`n" native.detaljer "`n", "*", "UTF-8")
        uia := r.HentDagensData(hwnd,true)
        FileAppend(uia.status "`n" uia.detaljer "`n", "*", "UTF-8")
        TrioAssert(native.ok && uia.ok && native.sett.Count = 2 && uia.sett.Count = 2,
            "visual column reorder supported by both backends")
        for key, post in native.sett
            TrioAssert(uia.sett.Has(key) && uia.sett[key].sek = post.sek,
                "native/UIA agree after visual reorder")
        ProcessClose fixturePid
        ProcessWaitClose fixturePid, 5
        Run('"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptDir '\trio-fixture.ahk" missing-duration',,, &fixturePid)
        hwnd := WinWait("QuickerKeys synthetic Trio fixture ahk_pid " fixturePid,,10)
        TrioAssert(hwnd != 0,"unknown duration header fixture opened")
        Sleep 500
        for onlyUia in [false,true] {
            missing := r.HentDagensData(hwnd,onlyUia)
            FileAppend(missing.status "`n" missing.detaljer "`n", "*", "UTF-8")
            TrioAssert(missing.ok && missing.sett.Count = 2 && !missing.kart.Has("behandling"),
                "unknown duration header does not block backend task counting")
            sum := StatistikkModul.Prototype.TrioSummering.Call({TrioOppgaver:missing.sett})
            TrioAssert(sum.antall = 2 && sum.behandlingN = 0 && sum.sek = 0,
                "backend keeps unknown treatment duration out of totals")
            TrioAssert(InStr(missing.detaljer,"Ukjent varighet") && !InStr(missing.detaljer,"IM99887766"),
                "unknown header label reported without row values")
        }
        ProcessClose fixturePid
        ProcessWaitClose fixturePid, 5
        Run('"' A_AhkPath '" /ErrorStdOut=UTF-8 "' A_ScriptDir '\trio-fixture.ahk" long-history',,, &fixturePid)
        hwnd := WinWait("QuickerKeys synthetic Trio fixture ahk_pid " fixturePid,,10)
        TrioAssert(hwnd != 0,"long multi-day log fixture opened")
        Sleep 500
        lvHwnd := ControlGetHwnd("SysListView321","ahk_id " hwnd)
        topBefore := SendMessage(0x1027,0,0,lvHwnd)
        longReader := TrioOffscreenTestLeser()
        longResult := longReader.HentDagensData(hwnd,true)
        FileAppend(longResult.status "`n" longResult.detaljer "`n","*","UTF-8")
        TrioAssert(longResult.ok && longResult.sett.Count = 2 && longResult.andreDager = 178,
            "today found beyond visible rows in long history")
        TrioAssert(longResult.utenPlassering > 0 && longResult.bekreftedeKart > 0,
            "offscreen exposed text uses verified structural map")
        TrioAssert(SendMessage(0x1027,0,0,lvHwnd) = topBefore,"long-log read does not scroll")
        TrioAssert(!InStr(longResult.detaljer,"9876543210") && !InStr(longResult.detaljer,"09:40:38"),
            "long-log diagnostic masks row data except explicit daily filter")
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
