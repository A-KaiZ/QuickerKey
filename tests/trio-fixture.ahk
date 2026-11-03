#Requires AutoHotkey v2.0
#SingleInstance Off
v := Gui(, "QuickerKeys synthetic Trio fixture")
; Seven columns, changed order, unnamed icon and empty optional fields.
lv := v.AddListView("w950 h220", ["Oppgave-ID","", "Behandlingstid","Tidspunkt","Kommentar (IM)","Køtid","Koblet"])
lv.Add(,"9876543210","","02:30",FormatTime(,"dd.MM.yyyy") " 09:12:34","Synthetic-private-text IM99887766","00:10","")
lv.Add(,"9876543211","","01:00",FormatTime(,"dd.MM.yyyy") " 10:00:00","","","")
lv.Add(,"9876543212","","01:00",FormatTime(DateAdd(A_Now,-1,"Days"),"dd.MM.yyyy") " 10:00:00","","","")
for i, width in [120,30,130,190,220,70,90]
    lv.ModifyCol(i,width)
v.OnEvent("Close", (*) => ExitApp())
v.Show()
