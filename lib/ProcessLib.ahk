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

IsProcessElevated(ProcessID)
{
    if !(hProcess := DllCall("OpenProcess", "uint", 0x1000, "int", 0, "uint", ProcessID, "ptr"))
        throw Exception("OpenProcess failed", -1)
    if !(DllCall("advapi32\OpenProcessToken", "ptr", hProcess, "uint", 0x0008, "ptr*", hToken))
        throw Exception("OpenProcessToken failed", -1), DllCall("CloseHandle", "ptr", hProcess)
    if !(DllCall("advapi32\GetTokenInformation", "ptr", hToken, "int", 20, "uint*", IsElevated, "uint", 4, "uint*", size))
        throw Exception("GetTokenInformation failed", -1), DllCall("CloseHandle", "ptr", hToken) && DllCall("CloseHandle", "ptr", hProcess)
    return IsElevated, DllCall("CloseHandle", "ptr", hToken) && DllCall("CloseHandle", "ptr", hProcess)
}