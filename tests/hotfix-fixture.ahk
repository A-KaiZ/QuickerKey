#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent
g := Gui(, "QuickerKeys synthetic editor")
editor := g.AddEdit("w500 h180 Multi")
g.OnEvent("Close", (*) => ExitApp())
g.Show()
