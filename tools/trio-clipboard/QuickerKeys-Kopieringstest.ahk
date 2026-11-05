#Requires AutoHotkey v2.0
#SingleInstance Force

; CLIPBOARD_PROBE_START
ClipboardProbeMain()

ClipboardProbeMain() {
    global CLIPBOARD_PROBE_GUI
    state := {Armed: false, Sequence: 0, Report: "Ingen prøve kjørt."}
    g := Gui(, "QuickerKeys – kopieringstest")
    CLIPBOARD_PROBE_GUI := g
    g.SetFont("s10", "Segoe UI")
    g.AddText("w660 h112", "Avslutt vanlig QuickerKeys fra ikonet ved klokka under prøven.`n1. Trykk Klargjør. Marker én rad i Trio Oppgavelogg og trykk Ctrl+C.`n2. Gå tilbake hit og trykk Analyser kopiering.`n3. Kopier bare den anonyme diagnosen.`nDette tester utklippsformat, ikke import eller statistikk. Kilden bekreftes ikke automatisk.")
    prepare := g.AddButton("w150 h34", "Klargjør")
    analyze := g.AddButton("x+10 w190 h34", "Analyser kopiering")
    copy := g.AddButton("x+10 w220 h34", "Kopier anonym diagnose")
    view := g.AddEdit("xm y+14 w660 h270 ReadOnly -Wrap", state.Report)
    prepare.OnEvent("Click", ClipboardProbePrepare.Bind(state, view))
    analyze.OnEvent("Click", ClipboardProbeAnalyze.Bind(state, view))
    copy.OnEvent("Click", ClipboardProbeCopy.Bind(state, view))
    g.OnEvent("Close", (*) => ExitApp())
    g.OnEvent("Escape", (*) => ExitApp())
    g.Show()
}

ClipboardProbePrepare(state, view, *) {
    state.Sequence := DllCall("user32\GetClipboardSequenceNumber", "UInt")
    state.Armed := state.Sequence != 0
    state.Report := state.Armed
        ? "Klar. Marker én rad i Oppgavelogg og trykk Ctrl+C. Gå deretter tilbake og analyser."
        : "Utklippets sekvensnummer er utilgjengelig. Ingen tekst er lest."
    view.Value := state.Report
}

ClipboardProbeAnalyze(state, view, *) {
    if !state.Armed {
        state.Report := "Trykk Klargjør før en ny prøve."
        view.Value := state.Report
        return
    }
    sequence := DllCall("user32\GetClipboardSequenceNumber", "UInt")
    if (sequence = state.Sequence) {
        state.Report := "Ingen endring i utklippet registrert etter klargjøring. Ingen tekst er lest."
        view.Value := state.Report
        return
    }
    state.Armed := false
    try {
        if !(DllCall("user32\IsClipboardFormatAvailable", "UInt", 13)
            || DllCall("user32\IsClipboardFormatAvailable", "UInt", 1)) {
            state.Report := "Utklippet ble endret, men ingen ren tekst er tilgjengelig. Ingen celleverdier er lest."
        } else {
            text := A_Clipboard
            state.Report := sequence = DllCall("user32\GetClipboardSequenceNumber", "UInt")
                ? ClipboardProbeSummary(text) : "Utklippet endret seg under lesing. Klargjør og prøv igjen."
            text := ""
        }
    } catch {
        state.Report := "Utklippet kunne ikke leses. Årsaken er ukjent. Klargjør og prøv igjen."
    }
    view.Value := state.Report
}

ClipboardProbeSummary(text) {
    prefix := "QuickerKeys – anonym kopieringstest P0.1`r`n"
    if (StrLen(text) > 200000)
        return prefix "For mye tekst for denne prøven. Kopier bare én rad. Ingen innholdsanalyse utført."
    lines := StrSplit(Trim(StrReplace(text, "`r", ""), "`n"), "`n")
    if (lines.Length > 200)
        return prefix "For mange linjer for denne prøven. Kopier bare én rad. Ingen innholdsanalyse utført."
    rows := 0, smallest := 0, largest := 0, timestamps := 0, numbers := 0, durations := 0
    for line in lines {
        if (Trim(line, " `t") = "")
            continue
        fields := StrSplit(line, "`t")
        rows++
        smallest := smallest = 0 ? fields.Length : Min(smallest, fields.Length)
        largest := Max(largest, fields.Length)
        for field in fields {
            value := Trim(field, " ")
            timestamps += RegExMatch(value, "^[0-9]{2}\.[0-9]{2}\.[0-9]{4} +[0-9]{2}:[0-9]{2}:[0-9]{2}$") ? 1 : 0
            numbers += RegExMatch(value, "^[0-9]{9}$") ? 1 : 0
            durations += RegExMatch(value, "^(?:[0-9]{1,3}:)?[0-9]{2}:[0-5][0-9]$") ? 1 : 0
        }
    }
    return prefix "Ny tekst registrert etter klargjøring: ja"
        . "`r`nRader med tekst: " rows
        . "`r`nTab-felt per rad, inkludert tomme felt: " smallest "–" largest
        . "`r`nFelt med tidsstempelmønster: " timestamps
        . "`r`nNi-sifrede numeriske felt: " numbers
        . "`r`nFelt med varighetsmønster: " durations
        . "`r`nBare format og antall. Ingen datoer, ID-er eller rå celleverdier i rapporten."
        . "`r`nIngen oppgaver validert eller importert. Kilde og kolonnebetydning er ikke bekreftet."
}

ClipboardProbeCopy(state, view, *) {
    try A_Clipboard := state.Report
    catch {
        view.Value := state.Report "`r`nDiagnosen kunne ikke kopieres akkurat nå."
    }
}
