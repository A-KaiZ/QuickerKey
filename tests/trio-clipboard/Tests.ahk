RunClipboardProbeTests() {
    sample := "05.11.2026 09:10:11`t123456789`t`t`t`t`t`t`t02:30`t00:10`t`t`tPRIVATE CUSTOMER"
    report := ClipboardProbeSummary(sample)
    ProbeRequire(InStr(report, "Rader med tekst: 1"), "one copied row is counted")
    ProbeRequire(InStr(report, "felt: 13–13"), "empty tab columns are preserved")
    ProbeRequire(InStr(report, "tidsstempelmønster: 1") && InStr(report, "numeriske felt: 1") && InStr(report, "varighetsmønster: 2"), "format counts do not assert column identity")
    ProbeRequire(!InStr(report, "123456789") && !InStr(report, "05.11.2026") && !InStr(report, "PRIVATE CUSTOMER"), "anonymous summary does not disclose copied raw fields")
    report := ClipboardProbeSummary("`t123456789`t`r`n`t`t")
    ProbeRequire(InStr(report, "Rader med tekst: 1") && InStr(report, "felt: 3–3"), "leading and trailing empty columns survive while empty rows are ignored")
    ProbeRequire(InStr(ClipboardProbeSummary(""), "Rader med tekst: 0"), "empty text produces zero text rows without claiming zero tasks")
    ProbeRequire(InStr(ClipboardProbeSummary(StrReplace(Format("{:200001}", "x"), " ", "x")), "For mye tekst"), "large clipboard input is rejected")
    saved := ClipboardAll()
    try {
        A_Clipboard := "SYNTHETIC BEFORE"
        state := {Armed: false, Sequence: 0, Report: ""}, view := {Value: ""}
        ClipboardProbePrepare(state, view)
        ClipboardProbeAnalyze(state, view)
        ProbeRequire(InStr(state.Report, "Ingen endring"), "unchanged old clipboard is not inspected")
        A_Clipboard := sample
        ClipboardProbeAnalyze(state, view)
        ProbeRequire(!state.Armed && InStr(state.Report, "Rader med tekst: 1"), "an explicitly armed fresh copy is summarized once")
        ClipboardProbeCopy(state, view)
        ProbeRequire(A_Clipboard = state.Report && !InStr(A_Clipboard, "123456789"), "copy action publishes only the anonymous report")
    } finally {
        A_Clipboard := saved
    }
    FileAppend "PASS total=10`n", "*", "UTF-8"
    ExitApp 0
}
ProbeRequire(value, label) {
    if !value {
        FileAppend "FAIL " label "`n", "*", "UTF-8"
        ExitApp 1
    }
    FileAppend "PASS " label "`n", "*", "UTF-8"
}
