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

; Build Tray Menu
Menu, Tray, NoStandard

Menu, Tray, Icon, imageres.dll, 23

Menu, Tray, Add, % AppWindow, Show
Menu, Tray, Icon, % AppWindow, imageres.dll, 23
Menu, Tray, Default, % AppWindow
Menu, Tray, Add
Menu, Tray, Add, Edit, Edit
Menu, Tray, Add, Reload, Reload
Menu, Tray, Add, Exit, Exit

; Build GUI
Gui, +AlwaysOnTop +Resize +ToolWindow
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
Gui, Add, ListView, Section xs w480 r25 vLVP hwndLVP gLVP_Events +AltSubmit, Process Name|PID|Creation Time|CPU|RAM (MB)|File Path|Executable Path
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

; tracks window move
OnMessage(0x03, "WN_MOVE")

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
    
    LV_ModifyCol(1, (A_GuiWidth*(150/701)))
    LV_ModifyCol(2, (A_GuiWidth*(50/701)) " integer")
    LV_ModifyCol(3, (A_GuiWidth*(70/701)) " integer")
    LV_ModifyCol(4, (A_GuiWidth*(50/701)) " integer")
    LV_ModifyCol(5, (A_GuiWidth*(75/701)) " Integer SortDesc")
    LV_ModifyCol(6, (A_GuiWidth*(315/701)))
    LV_ModifyCol(7, (A_GuiWidth*(315/701)))
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
    
    ; might get more cpu usages
    setSeDebugPrivilege()
    
    GuiControl, -Redraw, LVP
    
    Gui, Submit, NoHide
    
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
            LV_Add("Icon" A_Index, process.Name, process.processId, ProcessCreationTime(process.processId), Round(getProcessTimes(ProcessCreationTime(process.processId)), 2), Round(process.WorkingSetSize / 1000000, 2), process.CommandLine, process.ExecutablePath)
            count++
        } Else {
            if (process.ExecutablePath = "")
                Continue
            If (InStr(process.Name, YouTyped) || InStr(process.ExecutablePath, YouTyped)) {
                LV_Add("Icon" A_Index, process.Name, process.processId, ProcessCreationTime(process.processId), Round(getProcessTimes(ProcessCreationTime(process.processId)), 2), Round(process.WorkingSetSize / 1000000, 2), process.CommandLine, process.ExecutablePath)
                count++
            }
        }
    }
    
    GuiControl, text, Count, % count " Processes"
    GuiControl, +Redraw, LVP
    
    LV_ModifyCol(4, " Integer SortDesc") ; make it sort by RAM usage
    
return

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
        doubleClickEvt()
    } else if (A_GuiEvent == "Normal" || A_GuiEvent == "K") {
        LV_GetText(fPath, LV_GetNext(), 6)
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
    Menu, LVPMenu, Add
    Menu, LVPMenu, Add, % "End " (selected.count() > 1 ? selected.count() " Processes" : "Process"), kill
        Menu, LVPMenu, Icon, % "End " (selected.count() > 1 ? selected.count() " Processes" : "Process"), % A_ScriptDir "\res\end.ico"
    Menu, LVPMenu, Add, % "Restart " (selected.count() > 1 ? selected.count() " Processes" : "Process"), restartProcesses
        Menu, LVPMenu, Icon, % "Restart " (selected.count() > 1 ? selected.count() " Processes" : "Process"), % A_ScriptDir "\res\restart.ico"
    Menu, LVPMenu, Add, % "Open " (selected.count() > 1 ? selected.count() " Directories" : "Directory"), openFileLocation
        Menu, LVPMenu, Icon, % "Open " (selected.count() > 1 ? selected.count() " Directories" : "Directory"), % A_ScriptDir "\res\dir.ico"
    if (x = 0 && y = 0) {
        MouseGetPos, MenuXpos, MenuYpos
        Menu, LVPMenu, Show, % (MenuXpos + 10), % (MenuYpos + 0)
    } else 
        Menu, LVPMenu, Show, % x, % y
}

doubleClickEvt() {
    filePathList := []
    
    LV_GetText(Name, LV_GetNext(), 1)
    
    for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process WHERE Name='" Name "'")
    {
        filePathList[process["processId"]] := process["CommandLine"]
    }
    
    SeeAllProcessesFilePaths(Name, filePathList)
}

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
        LV_GetText(fPath, RowNumber, 7)
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

restartProcesses:
    RowNumber := 0 ; This causes the first loop iteration to start the search at the top of the list.
    selected := {}
    Loop
    {
        RowNumber := LV_GetNext(RowNumber) ; Resume the search at the row after that found by the previous iteration.
        if not RowNumber ; The above returned zero, so there are no more selected rows.
            break
        LV_GetText(pid, RowNumber, 2)
        LV_GetText(fPath, RowNumber, 7)
        selected.Insert(pid, fPath)
    }
    
    for k, v in selected {
        Process, Close, % k
        Run, % v
    }

dummyLabel:
return

jk:
    MsgBox, 4096, % "Kill Them All?", "lol jk, are u insane?"
return

GuiClose:
GuiEscape:
    Write_Log()
    FFTooltip() ; remove FFTooltips
    Gui, hide
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
    
ProcessExist(ProcessName) {
    Process, Exist, %ProcessName%
return ErrorLevel
}

ProcessPath(ProcessName) {
    ProcessId := InStr(ProcessName, ".")?ProcessExist(ProcessName):ProcessName
    , hProcess := DllCall("Kernel32.dll\OpenProcess", "UInt", 0x0400|0x0010, "UInt", 0, "UInt", ProcessId)
    , FileNameSize := VarSetCapacity(ModuleFileName, (260 + 1) * 2, 0) / 2
    if !(DllCall("Psapi.dll\GetModuleFileNameExW", "Ptr", hProcess, "Ptr", 0, "Str", ModuleFileName, "UInt", FileNameSize))
        if !(DllCall("Kernel32.dll\K32GetModuleFileNameExW", "Ptr", hProcess, "Ptr", 0, "Str", ModuleFileName, "UInt", FileNameSize))
        DllCall("Kernel32.dll\QueryFullProcessImageNameW", "Ptr", hProcess, "UInt", 1, "Str", ModuleFileName, "UIntP", FileNameSize)
return ModuleFileName, DllCall("Kernel32.dll\CloseHandle", "Ptr", hProcess)
}

ProcessCreationTime( PID ) { 
    hPr := DllCall( "OpenProcess", UInt,1040, Int,0, Int,PID )
    DllCall( "GetProcessTimes", UInt,hPr, Int64P,UTC, Int,0, Int,0, Int,0 )
    DllCall( "CloseHandle", Int,hPr)
    DllCall( "FileTimeToLocalFileTime", Int64P,UTC, Int64P,Local ), AT := 1601
    AT += % Local//10000000, S
    FormatTime, AT, % AT, hh:mm:ss yy-MM-dd
Return AT
}

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

GUISize:
    ; GuiControl, -Redraw, LVP
    LVwidth := A_GuiWidth - 15
    LVheight := A_GuiHeight - 80

    GuiControl, move, LVP, w%LVwidth% h%LVheight%
    GuiControl, move, LVP, w%LVwidth% h%LVheight%

    gosub Format_Columns
    Write_Log()
    ; GuiControl, +Redraw, LVP
return

WN_MOVE(wParam, lParam) {
    ; write log on window move
    Write_Log()
}

WM_MOUSEMOVE(wParam, lParam, Msg, Hwnd) {
    TT := ""
   ; LVM_HITTEST   -> docs.microsoft.com/en-us/windows/desktop/Controls/lvm-hittest
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
   
   ;~ If A_GuiControl In Btn1,Btn2,Btn3
      ;~ GuiControlGet, TT, , %A_GuiControl%
   ;~ Else If (A_GuiControl = "LVP") {
      ;~ VarSetCapacity(LVHTI, 24, 0) ; LVHITTESTINFO
      ;~ , NumPut(lParam & 0xFFFF, LVHTI, 0, "Int")
      ;~ , NumPut((lParam >> 16) & 0xFFFF, LVHTI, 4, "Int")
      ;~ , Item := DllCall("SendMessage", "Ptr", Hwnd, "UInt", 0x1012, "Ptr", 0, "Ptr", &LVHTI, "Int") ; LVM_HITTEST
      ;~ If (Item >= 0) && (NumGet(LVHTI, 8, "UInt") & 0x0E) { ; LVHT_ONITEM
        ;~ Gui, ListView, %A_GuiControl%
        ;~ LV_GetText(pName, Item + 1, 1)
        ;~ LV_GetText(fPath, Item + 1, 6)
        ;~ pName .= ": "
      ;~ }
   ;~ } else {
        ;~ FFTooltip()
    ;~ }
   
   ;~ TT := pName fPath
   
   FFTooltip(TT)
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Excerpt from htopmini v0.8.3
; by jNizM
; http://ahkscript.org/boards/viewtopic.php?f=6&t=254
; https://github.com/jNizM/htopmini/blob/master/src/htopmini.ahk
UpdateMemory:
    GMSEx := GlobalMemoryStatusEx()
    GMSExM01 := Round(GMSEx[2] / 1024**2, 1) ; Total Physical Memory in MB
    GMSExM02 := Round(GMSEx[3] / 1024**2, 1) ; Available Physical Memory in MB
    GMSExM03 := Round(GMSExM01 - GMSExM02, 1) ; Used Physical Memory in MB
    GMSExM04 := Round(GMSExM03 / GMSExM01 * 100, 1) ; Used Physical Memory in %
    GMSExS01 := Round(GMSEx[4] / 1024**2, 1) ; Total PageFile in MB
    GMSExS02 := Round(GMSEx[5] / 1024**2, 1) ; Available PageFile in MB
    GMSExS03 := Round(GMSExS01 - GMSExS02, 1) ; Used PageFile in MB
    GMSExS04 := Round(GMSExS03 / GMSExS01 * 100, 1) ; Used PageFile in %
    UsedRAM := GMSExM04 ; save used RAM
    UsedPage := GMSExS04 ; save used Page
    GuiControl,,UsedRAMPercentage,[Used RAM: %GMSExM04%`%]
    GuiControl,,UsedPageFilePercentage,[Used Page: %GMSExS04%`%]
return

GlobalMemoryStatusEx() {
    static MEMORYSTATUSEX, init := VarSetCapacity(MEMORYSTATUSEX, 64, 0) && NumPut(64, MEMORYSTATUSEX, "UInt")
    if (DllCall("Kernel32.dll\GlobalMemoryStatusEx", "Ptr", &MEMORYSTATUSEX))
    {
        return { 2 : NumGet(MEMORYSTATUSEX, 8, "UInt64")
            , 3 : NumGet(MEMORYSTATUSEX, 16, "UInt64")
            , 4 : NumGet(MEMORYSTATUSEX, 24, "UInt64")
        , 5 : NumGet(MEMORYSTATUSEX, 32, "UInt64") }
    }
}

MemoryLoad()
{
    static MEMORYSTATUSEX, init := NumPut(VarSetCapacity(MEMORYSTATUSEX, 64, 0), MEMORYSTATUSEX, "uint")
    if !(DllCall("GlobalMemoryStatusEx", "ptr", &MEMORYSTATUSEX))
        throw Exception("Call to GlobalMemoryStatusEx failed: " A_LastError, -1)
return NumGet(MEMORYSTATUSEX, 4, "UInt")
}

CPULoad() { ; By SKAN, CD:22-Apr-2014 / MD:05-May-2014. Thanks to ejor, Codeproject: http://goo.gl/epYnkO
    Static PIT, PKT, PUT ; http://ahkscript.org/boards/viewtopic.php?p=17166#p17166
IfEqual, PIT,, Return 0, DllCall( "GetSystemTimes", "Int64P",PIT, "Int64P",PKT, "Int64P",PUT )

DllCall( "GetSystemTimes", "Int64P",CIT, "Int64P",CKT, "Int64P",CUT )
, IdleTime := PIT - CIT, KernelTime := PKT - CKT, UserTime := PUT - CUT
, SystemTime := KernelTime + UserTime 

Return ( ( SystemTime - IdleTime ) * 100 ) // SystemTime, PIT := CIT, PKT := CKT, PUT := CUT 
}

; -1 on first run 
; -2 if process doesn't exist or you don't have access to it
; Process cpu usage as percent of total CPU

;~ https://autohotkey.com/board/topic/113942-solved-get-cpu-usage-in/
getProcessTimes(PID) 
{
    static aPIDs := [], hasSetDebug
    ; If called too frequently, will get mostly 0%, so it's better to just return the previous usage 
    if aPIDs.HasKey(PID) && A_TickCount - aPIDs[PID, "tickPrior"] < 250
        return aPIDs[PID, "usagePrior"] 
    ; Open a handle with PROCESS_QUERY_LIMITED_INFORMATION access
    if !hProc := DllCall("OpenProcess", "UInt", 0x1000, "Int", 0, "Ptr", pid, "Ptr")
        return -2, aPIDs.HasKey(PID) ? aPIDs.Remove(PID, "") : "" ; Process doesn't exist anymore or don't have access to it.
    
    DllCall("GetProcessTimes", "Ptr", hProc, "Int64*", lpCreationTime, "Int64*", lpExitTime, "Int64*", lpKernelTimeProcess, "Int64*", lpUserTimeProcess)
    DllCall("CloseHandle", "Ptr", hProc)
    DllCall("GetSystemTimes", "Int64*", lpIdleTimeSystem, "Int64*", lpKernelTimeSystem, "Int64*", lpUserTimeSystem)
    
    if aPIDs.HasKey(PID) ; check if previously run
    {
        ; find the total system run time delta between the two calls
        systemKernelDelta := lpKernelTimeSystem - aPIDs[PID, "lpKernelTimeSystem"] ;lpKernelTimeSystemOld
        systemUserDelta := lpUserTimeSystem - aPIDs[PID, "lpUserTimeSystem"] ; lpUserTimeSystemOld
        ; get the total process run time delta between the two calls 
        procKernalDelta := lpKernelTimeProcess - aPIDs[PID, "lpKernelTimeProcess"] ; lpKernelTimeProcessOld
        procUserDelta := lpUserTimeProcess - aPIDs[PID, "lpUserTimeProcess"] ;lpUserTimeProcessOld
        ; sum the kernal + user time
        totalSystem := systemKernelDelta + systemUserDelta
        totalProcess := procKernalDelta + procUserDelta
        ; The result is simply the process delta run time as a percent of system delta run time
        result := 100 * totalProcess / totalSystem
    }
    else result := -1
        
    aPIDs[PID, "lpKernelTimeSystem"] := lpKernelTimeSystem
    aPIDs[PID, "lpKernelTimeSystem"] := lpKernelTimeSystem
    aPIDs[PID, "lpUserTimeSystem"] := lpUserTimeSystem
    aPIDs[PID, "lpKernelTimeProcess"] := lpKernelTimeProcess
    aPIDs[PID, "lpUserTimeProcess"] := lpUserTimeProcess
    aPIDs[PID, "tickPrior"] := A_TickCount
return aPIDs[PID, "usagePrior"] := result 
}

setSeDebugPrivilege(enable := True)
{
    h := DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", DllCall("GetCurrentProcessId"), "Ptr")
    ; Open an adjustable access token with this process (TOKEN_ADJUST_PRIVILEGES = 32)
    DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "PtrP", t)
    VarSetCapacity(ti, 16, 0) ; structure of privileges
    NumPut(1, ti, 0, "UInt") ; one entry in the privileges array...
    ; Retrieves the locally unique identifier of the debug privilege:
    DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeDebugPrivilege", "Int64P", luid)
    NumPut(luid, ti, 4, "Int64")
    if enable
        NumPut(2, ti, 12, "UInt") ; enable this privilege: SE_PRIVILEGE_ENABLED = 2
    ; Update the privileges of this process with the new access token:
    r := DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", &ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
    DllCall("CloseHandle", "Ptr", t) ; close this access token handle to save memory
    DllCall("CloseHandle", "Ptr", h) ; close this process handle to save memory
return r
}

SetWindowTheme(handle) ; https://msdn.microsoft.com/en-us/library/bb759827(v=vs.85).aspx
{
    if (DllCall("GetVersion") & 0xff >= 10) {
        VarSetCapacity(ClassName, 1024, 0)
        if (DllCall("user32\GetClassName", "ptr", handle, "str", ClassName, "int", 512, "int"))
            if (ClassName = "SysListView32") || (ClassName = "SysTreeView32")
            if !(DllCall("uxtheme\SetWindowTheme", "ptr", handle, "wstr", "Explorer", "ptr", 0))
            return true
    }
return false
}

; ===============================================================================================================================
; FFToolTip(Text:="", X:="", Y:="", WhichToolTip:=1)
; Function:       Creates a tooltip window anywhere on the screen. Unlike the built-in ToolTip command, calling this function
;                 repeatedly will not cause the tooltip window to flicker. Otherwise, it behaves the same way. Use this function
;                 without the first three parameters, i.e. FFToolTip(), in order to hide the tooltip.
; Parameters:     Text - The text to display in the tooltip. To create a multi-line tooltip, use the linefeed character (`n) in
;                    between each line, e.g. Line1`nLine2. If blank or omitted, the existing tooltip will be hidden.
;                 X - The x position of the tooltip. This position is relative to the active window, the active window's client
;                    area, or the entire screen depending on the coordinate mode (see the CoordMode command). In the default
;                    mode, the coordinates that are relative to the active window.
;                 Y - The y position of the tooltip. See the above X parameter for more information. If both the X and Y
;                    coordinates are omitted, the tooltip will be shown near the mouse cursor.
;                 WhichToolTip - A number between 1 and 20 to indicate which tooltip window to operate upon. If unspecified, the
;                    default is 1.
; Return values:  None
; Global vars:    None
; Dependencies:   None
; Tested with:    AHK 1.1.30.01 (A32/U32/U64)
; Tested on:      Win 7 (x64)
; Written by:     iPhilip
; ===============================================================================================================================
; MSDN Links:
; https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-getcursorpos - GetCursorPos function
; https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-clienttoscreen - ClientToScreen function
; https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-movewindow - MoveWindow function
; ===============================================================================================================================

FFToolTip(Text:="", X:="", Y:="", WhichToolTip:=1) {
   static ID := [], Xo, Yo, W, H, SavedText
        , PID := DllCall("GetCurrentProcessId")
        , _ := VarSetCapacity(Point, 8)
   
   if (Text = "") {  ; Hide the tooltip
      ToolTip, , , , WhichToolTip
      ID.Delete(WhichToolTip)
   } else if not ID[WhichToolTip] {  ; First call
      ToolTip, %Text%, X, Y, WhichToolTip
      ID[WhichToolTip] := WinExist("ahk_class tooltips_class32 ahk_pid " PID)
      WinGetPos, , , W, H, % "ahk_id " ID[WhichToolTip]
      SavedText := Text
   } else if (Text != SavedText) {  ; The tooltip text changed
      ToolTip, %Text%, X, Y, WhichToolTip
      WinGetPos, , , W, H, % "ahk_id " ID[WhichToolTip]
      SavedText := Text
   } else {  ; The tooltip is being repositioned
      if (Flag := X = "" || Y = "") {
         DllCall("GetCursorPos", "Ptr", &Point, "Int")
         MouseX := NumGet(Point, 0, "Int")
         MouseY := NumGet(Point, 4, "Int")
      }
      ;
      ; Convert input coordinates to screen coordinates
      ;
      if (A_CoordModeToolTip = "Window") {
         WinGetPos, WinX, WinY, , , A
         X := X = "" ? MouseX + 16 : X + WinX
         Y := Y = "" ? MouseY + 16 : Y + WinY
      } else if (A_CoordModeToolTip = "Client") {
         NumPut(X, Point, 0, "Int"), NumPut(Y, Point, 4, "Int")
         DllCall("ClientToScreen", "Ptr", WinExist("A"), "Ptr", &Point, "Int")
         X := X = "" ? MouseX + 16 : NumGet(Point, 0, "Int")
         Y := Y = "" ? MouseY + 16 : NumGet(Point, 4, "Int")
      } else {  ; A_CoordModeToolTip = "Screen"
         X := X = "" ? MouseX + 16 : X
         Y := Y = "" ? MouseY + 16 : Y
      }
      ;
      ; Deal with the bottom and right edges of the screen
      ;
      if Flag {
         X := X + W >= A_ScreenWidth  ? A_ScreenWidth  - W - 1 : X
         Y := Y + H >= A_ScreenHeight ? A_ScreenHeight - H - 1 : Y
         if (MouseX >= X && MouseX <= X + W && MouseY >= Y && MouseY <= Y + H)
            X := MouseX - W - 3, Y := MouseY - H - 3
      }
      ;
      ; If necessary, store the coordinates and move the tooltip window
      ;
      if (X != Xo || Y != Yo) {
         Xo := X, Yo := Y
         DllCall("MoveWindow", "Ptr", ID[WhichToolTip], "Int", X, "Int", Y, "Int", W, "Int", H, "Int", false, "Int")
      }
   }
}