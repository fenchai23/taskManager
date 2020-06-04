; ===============================================================================================================================
; FFToolTip(Text:="", X:="", Y:="", WhichToolTip:=1)
; Function: Creates a tooltip window anywhere on the screen. Unlike the built-in ToolTip command, calling this function
; repeatedly will not cause the tooltip window to flicker. Otherwise, it behaves the same way. Use this function
; without the first three parameters, i.e. FFToolTip(), in order to hide the tooltip.
; Parameters: Text - The text to display in the tooltip. To create a multi-line tooltip, use the linefeed character (`n) in
; between each line, e.g. Line1`nLine2. If blank or omitted, the existing tooltip will be hidden.
; X - The x position of the tooltip. This position is relative to the active window, the active window's client
; area, or the entire screen depending on the coordinate mode (see the CoordMode command). In the default
; mode, the coordinates that are relative to the active window.
; Y - The y position of the tooltip. See the above X parameter for more information. If both the X and Y
; coordinates are omitted, the tooltip will be shown near the mouse cursor.
; WhichToolTip - A number between 1 and 20 to indicate which tooltip window to operate upon. If unspecified, the
; default is 1.
; Return values: None
; Global vars: None
; Dependencies: None
; Tested with: AHK 1.1.30.01 (A32/U32/U64)
; Tested on: Win 7 (x64)
; Written by: iPhilip
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
    
    if (Text = "") { ; Hide the tooltip
        ToolTip, , , , WhichToolTip
        ID.Delete(WhichToolTip)
    } else if not ID[WhichToolTip] { ; First call
        ToolTip, %Text%, X, Y, WhichToolTip
        ID[WhichToolTip] := WinExist("ahk_class tooltips_class32 ahk_pid " PID)
        WinGetPos, , , W, H, % "ahk_id " ID[WhichToolTip]
        SavedText := Text
    } else if (Text != SavedText) { ; The tooltip text changed
        ToolTip, %Text%, X, Y, WhichToolTip
        WinGetPos, , , W, H, % "ahk_id " ID[WhichToolTip]
        SavedText := Text
    } else { ; The tooltip is being repositioned
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
        } else { ; A_CoordModeToolTip = "Screen"
            X := X = "" ? MouseX + 16 : X
            Y := Y = "" ? MouseY + 16 : Y
        }
        ;
        ; Deal with the bottom and right edges of the screen
        ;
        if Flag {
            X := X + W >= A_ScreenWidth ? A_ScreenWidth - W - 1 : X
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