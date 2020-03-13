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
Gui, Add, Button, ys w50 gClear default, Clear
Gui, Add, Button, ys gFill_LVP default, Update
Gui, Add, Button, ys gKill, End Task
Gui, Add, Button, ys gjk, Kill Them All
Gui, font, cGreen w700
Gui, Add, Text, Section xs vCpu, CPU Load: 00 `%
Gui, Add, Text, ys vRam, Used RAM: 00 `%
Gui, font, cBlack w400
Gui, Add, Checkbox, ys vShowSystemProcesses gFill_LVP, Show System
Gui, Add, Text, ys vCount, Preparing data...
Gui, Add, ListView, Section xs w480 r25 vLVP hwndLVP gLVP_Events +AltSubmit, Process Name|PID|Creation Time|RAM (MB)|Executable Path
SetWindowTheme(LVP)
; Fill GUI
gosub, Fill_LVP

; Show GUI
; MsgBox, 4096, catching coordinates, x=%GX% y=%GY% h%GH% w=%GW%
GH -= 39
GW -= 15
Gui, Show, x%GX% y%GY% h%GH% w%GW%, % AppWindow

settimer, UpdateStats, 500

return

UpdateStats:
	GuiControl, text, Cpu, % "CPU Load: " cpuload() "%"
	GuiControl, text, Ram, % "Used RAM: " memoryload() "%"
	return

Format_Columns:
	
	LV_ModifyCol(1, (A_GuiWidth*(150/701)))
	LV_ModifyCol(2, (A_GuiWidth*(50/701)) " integer")
	LV_ModifyCol(3, (A_GuiWidth*(70/701)) " integer")
	LV_ModifyCol(4, (A_GuiWidth*(75/701)) " Integer SortDesc")
	LV_ModifyCol(5, (A_GuiWidth*(315/701)))
	return
	
Clear:
	GuiControl, Text, YouTyped,
	GuiControl, Focus, YouTyped
	gosub, Fill_LVP
	return

Fill_LVP:

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
			LV_Add("Icon" A_Index, process.Name, process.processId, ProcessCreationTime(process.processId), Round(process.WorkingSetSize / 1000000, 2), process.ExecutablePath)
			count++
		} Else {
			if (process.ExecutablePath = "")
				Continue
			If (InStr(process.Name, YouTyped)) {
				LV_Add("Icon" A_Index, process.Name, process.processId, ProcessCreationTime(process.processId), Round(process.WorkingSetSize / 1000000, 2), process.ExecutablePath)
				count++
			}
		}
    }
	
	GuiControl, text, Count, % count " Processes"
	GuiControl, +Redraw, LVP
	
	LV_ModifyCol(4, " Integer SortDesc") ; make it sort by RAM usage

	return

kill:
	LV_GetText(pid,(LV_GetNext(0, "Focused")),2)
	LV_GetText(pname,(LV_GetNext(0, "Focused")),1)
	MsgBox, 4131, , Pid: %pid%`nName: %pname%`n`nEnd process?
	IfMsgBox, Yes
	{
		Process, Close, %pid%
		gosub, Fill_LVP
	}
	return

LVP_Events:
    If (A_GuiEvent = "DoubleClick") {
		gosub, kill
        ; LV_GetText(xPid, A_EventInfo, 1)
        ; LV_GetText(xNam, A_EventInfo, 2)
        ; MsgBox % "Pid`t" xpid "`nName`t" xNam
    }
Return

jk:
	MsgBox, 4096, % "Kill Them All?", "lol jk, are u insane?"
	return
	
GuiClose:
GuiEscape:
	Write_Log()
	;~ ExitApp
	Gui, hide
	return

Show:
	Gui, show
	return

#If WinActive(AppWindow)

Del::
	Send, ^a{Del}
	gosub, Fill_LVP
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
	GuiControl, -Redraw, LVP
	LVwidth := A_GuiWidth - 15
	LVheight := A_GuiHeight - 80

	GuiControl, move, LVP, w%LVwidth% h%LVheight%
	GuiControl, move, LVP, w%LVwidth% h%LVheight%
	
	gosub Format_Columns
	GuiControl, +Redraw, LVP
	return
	

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Excerpt from htopmini v0.8.3
; by jNizM
; http://ahkscript.org/boards/viewtopic.php?f=6&t=254
; https://github.com/jNizM/htopmini/blob/master/src/htopmini.ahk
UpdateMemory:
GMSEx := GlobalMemoryStatusEx()
GMSExM01 := Round(GMSEx[2] / 1024**2, 1)            ; Total Physical Memory in MB
GMSExM02 := Round(GMSEx[3] / 1024**2, 1)            ; Available Physical Memory in MB
GMSExM03 := Round(GMSExM01 - GMSExM02, 1)           ; Used Physical Memory in MB
GMSExM04 := Round(GMSExM03 / GMSExM01 * 100, 1)     ; Used Physical Memory in %
GMSExS01 := Round(GMSEx[4] / 1024**2, 1)            ; Total PageFile in MB
GMSExS02 := Round(GMSEx[5] / 1024**2, 1)            ; Available PageFile in MB
GMSExS03 := Round(GMSExS01 - GMSExS02, 1)           ; Used PageFile in MB
GMSExS04 := Round(GMSExS03 / GMSExS01 * 100, 1)     ; Used PageFile in %
UsedRAM := GMSExM04                                 ; save used RAM
UsedPage := GMSExS04                                ; save used Page
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
Static PIT, PKT, PUT                           ; http://ahkscript.org/boards/viewtopic.php?p=17166#p17166
  IfEqual, PIT,, Return 0, DllCall( "GetSystemTimes", "Int64P",PIT, "Int64P",PKT, "Int64P",PUT )

  DllCall( "GetSystemTimes", "Int64P",CIT, "Int64P",CKT, "Int64P",CUT )
, IdleTime := PIT - CIT,    KernelTime := PKT - CKT,    UserTime := PUT - CUT
, SystemTime := KernelTime + UserTime 

Return ( ( SystemTime - IdleTime ) * 100 ) // SystemTime,    PIT := CIT,    PKT := CKT,    PUT := CUT 
}


AutoStart:
If A_IsCompiled {
	IfNotExist, %A_Startup%\MemoryHogs.lnk
	{
		FileCreateShortcut, %A_ScriptFullPath%, %A_Startup%\MemoryHogs.lnk
		Menu,Tray,Check,AutoStart
        MsgBox,,,Added to Startup,1
		AutoStart := 1
		IniWrite,%AutoStart%,MemoryHogs.ini,Settings,AutoStart
	}
	else 
		gosub, RemoveFromStartup
}
return

;remove startup item
RemoveFromStartup:
If A_IsCompiled {
	IfExist, %A_Startup%\Exercises.lnk
	{
		FileDelete, %A_Startup%\MemoryHogs.lnk
		Menu,Tray,UnCheck,AutoStart
		MsgBox,,,Removed from Startup,1
		AutoStart := 0
		IniWrite,%AutoStart%,MemoryHogs.ini,Settings,AutoStart
	}
}
return

SetWindowTheme(handle)                                          ; https://msdn.microsoft.com/en-us/library/bb759827(v=vs.85).aspx
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