; --------------------------------------------------
; | Script by fenchai made in September/07/2019|
; --------------------------------------------------
#SingleInstance Force
#Persistent
#NoEnv
Setbatchlines, -1
SetWorkingDir %A_ScriptDir%

; https://docs.microsoft.com/en-us/windows/win32/cimwin32prov/win32-process

AppWindow := "Task Manager with Filter | come on Microsoft, if I could do it..."

LogFile := A_ScriptDir "\TaskManager.ini"

Read_Log()

IsProcessElevated := IsProcessElevated(DllCall("GetCurrentProcessId"))

colHeadersArr := ["Process Name","PID","Creation Time","CPU","RAM (MB)","File Path","Executable Path"]

if !(IsProcessElevated) {
    colHeadersArr.removeAt(4)
}

colHeaders := ""
for k, v in colHeadersArr
{
    colHeaders .= "|" . v
}
; trim the leading |
colHeaders := LTrim(colHeaders, "|")

; Build Tray Menu
Menu, Tray, NoStandard
Menu, Tray, Icon, imageres.dll, 23
Menu, Tray, Add, % AppWindow, Show
Menu, Tray, Icon, % AppWindow, imageres.dll, 23
Menu, Tray, Default, % AppWindow
Menu, Tray, Add
Menu, Tray, Add, Reset Position, ResetPosition
Menu, Tray, Add
Menu, Tray, Add, Edit, Edit
Menu, Tray, Add, Reload, Reload
Menu, Tray, Add, Exit, Exit

; Build GUI
Gui, +AlwaysOnTop +Resize
Gui, Add, Edit, w300 Section vYouTyped
Gui, Add, Button, ys w50 gClear vClearBtn, Clear
Gui, Add, Button, ys gEnter_Redirector vUpdateBtn default, Update
Gui, Add, Button, ys gKill vEndTaskBtn, End Process (es)
;~ Gui, Add, Button, ys gjk, Kill Them All
Gui, Add, Edit, ys w20 Number vTypedRefreshPeriod
Gui, Add, Text, ys yp+3, Refresh Period (s)
Gui, font, cGreen w700
Gui, Add, Text, Section xs vCpu, CPU Load: 00 `%
Gui, Add, Text, ys vRam, Used RAM: 00 `%
Gui, font, cBlack w400
Gui, Add, Checkbox, ys vShowSystemProcesses gFill_LVP, Show System
Gui, Add, Text, ys vCount, Preparing data...
Gui, Add, ListView, Section xs w480 r25 vLVP hwndLVP gLVP_Events +AltSubmit, % colHeaders
Gui, Add, StatusBar,, Select an item to see the file path
SetWindowTheme(LVP)
; Fill GUI
gosub, Fill_LVP

; Show GUI
;~ MsgBox, 4096, catching coordinates, x=%GX% y=%GY% h%GH% w=%GW%
GH -= 39
GW -= 15
Gui, Show, x%GX% y%GY% h%GH% w%GW%, % AppWindow

; Timers and other stuffs after GUI is built

; tracks mouse move
OnMessage(0x0200, "WM_MOUSEMOVE")

; set timer for cpu, ram updates periodically
settimer, UpdateStats, 500

; read the .ini to get the refre period
Iniread, TypedRefreshPeriod, %LogFile%, Preferences, RefreshPeriod
; change visually Edit2 field
GuiControl, Text, TypedRefreshPeriod, % TypedRefreshPeriod ? TypedRefreshPeriod : 0
; set the refresh period manually
setRefreshPeriod()

return

UpdateStats:
    GuiControl, text, Cpu, % "CPU Load: " cpuload() "%"
    GuiControl, text, Ram, % "Used RAM: " memoryload() "%"
return

Format_Columns:
    if (IsProcessElevated) {
        LV_ModifyCol(1, (A_GuiWidth*(150/701)))
        LV_ModifyCol(2, (A_GuiWidth*(50/701)) " integer")
        LV_ModifyCol(3, (A_GuiWidth*(70/701)) " integer SortDesc")
        LV_ModifyCol(4, (A_GuiWidth*(50/701)) " integer")
        LV_ModifyCol(5, (A_GuiWidth*(60/701)) " Integer")
        LV_ModifyCol(6, (A_GuiWidth*(315/701)) " Auto")
        LV_ModifyCol(7, (A_GuiWidth*(315/701)))
    } else {
        LV_ModifyCol(1, (A_GuiWidth*(150/701)))
        LV_ModifyCol(2, (A_GuiWidth*(50/701)) " integer")
        LV_ModifyCol(3, (A_GuiWidth*(70/701)) " integer SortDesc")
        LV_ModifyCol(4, (A_GuiWidth*(60/701)) " Integer")
        LV_ModifyCol(5, (A_GuiWidth*(315/701)) " Auto")
        LV_ModifyCol(6, (A_GuiWidth*(315/701)))
    }
return

Clear:
    GuiControl, Text, YouTyped,
    GuiControl, Focus, YouTyped
    gosub, Fill_LVP
return

Enter_Redirector:
    ControlGetFocus, currFocus, % AppWindow
    
    ; ToolTip, % currFocus
    
    if (currFocus = "Edit1" || currFocus = "Button2") {
        gosub Fill_LVP
    } else if (currFocus == "Edit2") {
        setRefreshPeriod()
    } else if (currFocus == "SysListView321") {
        gosub, CustomFilter
    }
    
return

Fill_LVP:
    
    Gui, Default
    ; GuiControl, -Redraw, LVP
    Gui, Submit, NoHide
    
    if (IsProcessElevated) {
        ; might get more cpu usages
        setSeDebugPrivilege()
    }
    
    LV_Delete()
    IL_Destroy(ImageList)
    ImageList := IL_Create()
    LV_SetImageList(ImageList)
    
    count := 0
    
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process") {
        ; Add Icons to the list
        if !(IL_Add(ImageList, ProcessPath(process.Name)))
            IL_Add(ImageList, A_WinDir "\explorer.exe")
        
        ; Fill the list
        If (InStr(process.Name, YouTyped) && ShowSystemProcesses = 1) {
            LVAdd(process, "withCPU")
            count++
        } Else {
            if (process.ExecutablePath = "")
                Continue
            If (InStr(process.Name, YouTyped) || InStr(process.ExecutablePath, YouTyped)) {
                LVAdd(process, "whatever")
                count++
            }
        }
    }
    
    GuiControl, text, Count, % count " Processes"
    
    LV_ModifyCol(3, " integer SortDesc") ; sorts by Creation Time after reload
    
    ; GuiControl, +Redraw, LVP
return

LVAdd(process, addType := "withCPU") {
    if (addType = "withCPU") {
        LV_Add("Icon" A_Index
        , process.Name
        , process.processId
        , ProcessCreationTime(process.processId)
        , Round(getProcessTimes(ProcessCreationTime(process.processId)), 2)
        , Round(process.WorkingSetSize / 1000000, 2)
        , process.CommandLine, process.ExecutablePath)
    } else {
        LV_Add("Icon" A_Index
        , process.Name
        , process.processId
        , ProcessCreationTime(process.processId)
        , Round(process.WorkingSetSize / 1000000, 2)
        , process.CommandLine, process.ExecutablePath)
    }
}

getRowName() {
    LV_GetText(RowName, LV_GetNext())
return RowName
}

setRefreshPeriod() {
    global LogFile
    
    GuiControlGet, TypedRefreshPeriod, , TypedRefreshPeriod
    if (TypedRefreshPeriod > 0) {
        SetTimer, AppRefreshPeriod, % (TypedRefreshPeriod * 1000)
    } else {
        SetTimer, AppRefreshPeriod, Off
    }
    ; modify the refresh period on .ini
    IniWrite, % TypedRefreshPeriod ? TypedRefreshPeriod : 0, %LogFile%, Preferences, RefreshPeriod
}

AppRefreshPeriod:
    gosub, Fill_LVP
return

return

LVP_Events:
    ;~ ToolTip % A_GuiEvent
    If (A_GuiEvent == "RightClick") {
        rightClickEvt()
} else if (A_GuiEvent == "DoubleClick") {
gosub, kill
} else if (A_GuiEvent == "Normal" || A_GuiEvent == "K") {
LV_GetText(fPath, LV_GetNext(), IsProcessElevated ? 6 : 5)
SB_SetText(fPath)
}
Return

rightClickEvt() {
    ;~ Row := A_EventInfo
    ;~ LV_GetText(LVItem, Row, 1) ; gets the Text from Specific Row and Column
    
    RowNumber := 0 ; This causes the first loop iteration to start the search at the top of the list.
    selected := {}
    Loop
    {
        RowNumber := LV_GetNext(RowNumber) ; Resume the search at the row after that found by the previous iteration.
        if not RowNumber ; The above returned zero, so there are no more selected rows.
            break
        LV_GetText(pid, RowNumber, 2)
        LV_GetText(pname, RowNumber, 1)
        selected.Insert(RowNumber " ) " pname, pid)
    }
    
    LV_GetText(SelectedName, A_EventInfo, 1)
    
    LVItem := selected.count() = 1 ? SelectedName : selected.count() " Processes Selected"
    
    Menu, LVPMenu, UseErrorlevel ; to prevent error to pop up when there is nothing to delete
    Menu, LVPMenu, DeleteAll
    Menu, LVPMenu, Add, % LVItem, dummyLabel
    Menu, LVPMenu, Icon, % LVItem, % A_ScriptDir "\res\win.ico"
    Menu, LVPMenu, Add
    Menu, LVPMenu, Add, % "Search for " SelectedName, CustomFilter
    Menu, LVPMenu, Icon, % "Search for " SelectedName, % A_ScriptDir "\res\find.ico"
    Menu, LVPMenu, Add, % "Show All " SelectedName, showAllRelatedProcesses
    Menu, LVPMenu, Icon, % "Show All " SelectedName, % A_ScriptDir "\res\all.ico"
    Menu, LVPMenu, Add
    Menu, LVPMenu, Add, % "End " (selected.count() > 1 ? selected.count() " Processes" : "Process"), kill
    Menu, LVPMenu, Icon, % "End " (selected.count() > 1 ? selected.count() " Processes" : "Process"), % A_ScriptDir "\res\end.ico"
    Menu, LVPMenu, Add, % "Restart " (selected.count() > 1 ? selected.count() " Processes" : "Process"), restartProcesses
    Menu, LVPMenu, Icon, % "Restart " (selected.count() > 1 ? selected.count() " Processes" : "Process"), % A_ScriptDir "\res\restart.ico"
    Menu, LVPMenu, Add, % "Open " (selected.count() > 1 ? selected.count() " Directories" : "Directory"), openFileLocation
    Menu, LVPMenu, Icon, % "Open " (selected.count() > 1 ? selected.count() " Directories" : "Directory"), % A_ScriptDir "\res\dir.ico"
    
    MouseGetPos, MenuXpos, MenuYpos
    Menu, LVPMenu, Show, % (MenuXpos + 10), % (MenuYpos + 0)
    
}

showAllRelatedProcesses:
    filePathList := []
    
    LV_GetText(Name, LV_GetNext(), 1)
    
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process WHERE Name='" Name "'")
    {
        filePathList[process["processId"]] := process["CommandLine"]
    }
    
    SeeAllProcessesFilePaths(Name, filePathList)
return

SeeAllProcessesFilePaths(Name, filePathList) {
    dGuiWidth := 900
    dGuiHeight := 400
    Gui, d: Destroy
    Gui, d: +AlwaysOnTop +Resize +ToolWindow
    Gui, d: add, ListView, % "AltSubmit hwndLVD " "w" (dGuiWidth - 20) " h" (dGuiHeight - 20), % "Index|PID|" Name
    SetWindowTheme(LVD)
    Gui, d: show, w%dGuiWidth% h%dGuiHeight%, % AppTitle
    Gui, d: Default
    for k, v in filePathList {
        LV_Add(, 1, k, v)
    }
    LV_ModifyCol(1, "AutoHdr Integer")
    LV_ModifyCol(2, "AutoHdr Integer")
    LV_ModifyCol(3, "AutoHdr Text")
}

CustomFilter:
    GuiControl, Text, YouTyped, % getRowName()
    gosub Fill_LVP
return

openFileLocation:
    RowNumber := 0 ; This causes the first loop iteration to start the search at the top of the list.
    selected := {}
    Loop
    {
        RowNumber := LV_GetNext(RowNumber) ; Resume the search at the row after that found by the previous iteration.
        if not RowNumber ; The above returned zero, so there are no more selected rows.
            break
        LV_GetText(pid, RowNumber, 2)
        LV_GetText(fPath, RowNumber, (IsProcessElevated) ? 6 : 5)
        selected.Insert(pid, fPath)
    }
    
    for k, v in selected {
        SplitPath, v, , directory
        Run, % directory
    }
return

kill:
    RowNumber := 0 ; This causes the first loop iteration to start the search at the top of the list.
    selected := {}
    Loop
    {
        RowNumber := LV_GetNext(RowNumber) ; Resume the search at the row after that found by the previous iteration.
        if not RowNumber ; The above returned zero, so there are no more selected rows.
            break
        LV_GetText(pid, RowNumber, 2)
        LV_GetText(pname, RowNumber, 1)
        selected.Insert(RowNumber " ) " pname, pid)
    }
    
    selected_parsed := "Kill " selected.count() " Item" (selected.count() > 1 ? "s?" : "?") "`n"
    
    for k, v in selected
    {
        selected_parsed .= k " : " v "`n"
    }
    
    if (selected.count() <= 0) {
        MsgBox, 4160, , Nothing to Kill -_-, 1
        return
    }
    
    MsgBox, 4131, , % selected_parsed
    IfMsgBox, Yes
    {
        for k, v in selected
        {
            Process, Close, % v
        }
        ; refresh after killing all
        gosub, Fill_LVP
    }
return

restartProcesses:
    RowNumber := 0 ; This causes the first loop iteration to start the search at the top of the list.
    selected := {}
    Loop
    {
        RowNumber := LV_GetNext(RowNumber) ; Resume the search at the row after that found by the previous iteration.
        if not RowNumber ; The above returned zero, so there are no more selected rows.
            break
        LV_GetText(pid, RowNumber, 2)
        LV_GetText(fPath, RowNumber, IsProcessElevated ? 6 : 5)
        selected.Insert(pid, fPath)
    }

    selected_parsed := "Restart " selected.count() " Item" (selected.count() > 1 ? "s?" : "?") "`n"
    
    for k, v in selected
    {
        selected_parsed .= k " : " v "`n"
    }
    
    MsgBox, 4131, , % selected_parsed
    IfMsgBox, Yes
    {
        for k, v in selected 
        {
            Process, Close, % k
            Run, % v
        }
    }
    
return

dummyLabel:
return

jk:
    MsgBox, 4096, % "Kill Them All?", "lol jk, are u insane?"
return

GuiClose:
    Write_Log()
    Gui, Hide
    return
GuiEscape:
    Write_Log()
    FFTooltip() ; remove FFTooltips
    Gui, Minimize
    return

Show:
    Gui, show
return

#If WinActive(AppWindow)
    
F5::
    gosub, Fill_LVP
return

Del::
    ControlGetFocus, currFocus, % AppWindow
    
    if (currFocus == "Edit1" || currFocus == "Edit2") {
        Send, ^a{Del}
    } else if (currFocus == "SysListView321") {
        gosub, kill
    }
return

#If
    
Reload:
    Reload
return

Exit:
    ExitApp
return

Edit:
    Edit
return

Read_Log() {
    global
    
    LogConfig=
    (
    [Position]
    LogX=20
    LogY=20
    LogH=600
    LogW=500
    [Preferences]
    RefreshPeriod=0
    )
    
    IfNotExist, %LogFile%
        FileAppend, %LogConfig%, %LogFile%
    
    Iniread, GX, %LogFile%, Position, LogX
    Iniread, GY, %LogFile%, Position, LogY
    Iniread, GH, %LogFile%, Position, LogH
    Iniread, GW, %LogFile%, Position, LogW
}

Write_Log() {
    global

    WinGetPos, GX, GY, GW, GH, %AppWindow%
    IniWrite, %GX%, %LogFile%, Position, LogX
    IniWrite, %GY%, %LogFile%, Position, LogY
    IniWrite, %GH%, %LogFile%, Position, LogH
    IniWrite, %GW%, %LogFile%, Position, LogW
    ; MsgBox, 4096, catching coordinates, x=%GX% y=%GY% h%GH% w=%GW%
}

ResetPosition:
    IniWrite, 20, %LogFile%, Position, LogX
    IniWrite, 20, %LogFile%, Position, LogY
    IniWrite, 800, %LogFile%, Position, LogH
    IniWrite, 500, %LogFile%, Position, LogW

    reload
    return

GUISize:    
    ; do not save if minimized
    if (A_EventInfo == 1)
        return
    ; GuiControl, -Redraw, LVP
    LVwidth := A_GuiWidth - 15
    LVheight := A_GuiHeight - 80

    GuiControl, move, LVP, w%LVwidth% h%LVheight%
    GuiControl, move, LVP, w%LVwidth% h%LVheight%

    gosub Format_Columns
    ; GuiControl, +Redraw, LVP
    return

WM_MOUSEMOVE(wParam, lParam, Msg, Hwnd) {
    TT := ""
    ; LVM_HITTEST -> docs.microsoft.com/en-us/windows/desktop/Controls/lvm-hittest
    ; LVHITTESTINFO -> docs.microsoft.com/en-us/windows/desktop/api/Commctrl/ns-commctrl-taglvhittestinfo
    
    if (A_GuiControl = "UpdateBtn") {
        TT := "F5 to refresh"
    } else if (A_GuiControl = "ClearBtn") {
        TT := "You can also press DEL while typing"
    } else if (A_GuiControl = "EndTaskBtn") {
        TT := "Can end single or Multiple Processes`nPress DEL on item to do the same"
    } else if (A_GuiControl = "TypedRefreshPeriod") {
        TT := "type seconds and press Enter"
    }

    FFTooltip(TT)
}

; INCLUDES

#Include, %A_ScriptDir%\lib\
#Include, ProcessLib.ahk
#Include, FFToolTip.ahk
#Include, SetWindowTheme.ahk