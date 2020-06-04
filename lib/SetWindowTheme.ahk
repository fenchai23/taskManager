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