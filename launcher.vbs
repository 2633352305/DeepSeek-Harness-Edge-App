' dsh-edge-app windowless launcher (shortcut target: wscript.exe)
' click: bg auto-update check -> start dsh web hidden -> open Edge standalone app window
Option Explicit

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim shell : Set shell = CreateObject("WScript.Shell")
Dim ScriptDir : ScriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
Dim Url : Url = "http://127.0.0.1:3080"
Dim OutLog : OutLog = ScriptDir & "\dsh-web.log"
Dim ErrLog : ErrLog = ScriptDir & "\dsh-web.err.log"

Function IsWebUp()
    IsWebUp = False
    On Error Resume Next
    Dim http : Set http = CreateObject("WinHttp.WinHttpRequest.5.1")
    http.Open "GET", Url, False
    http.SetTimeouts 1500, 1500, 1500, 1500
    http.Send
    If Err.Number = 0 Then IsWebUp = True
    On Error GoTo 0
End Function

Function FindEdge()
    Dim p, cands, i
    On Error Resume Next
    p = shell.RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\msedge.exe\")
    On Error GoTo 0
    If p <> "" And fso.FileExists(p) Then
        FindEdge = p
        Exit Function
    End If
    cands = Array( _
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe", _
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe", _
        shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Microsoft\Edge\Application\msedge.exe")
    For i = 0 To UBound(cands)
        If fso.FileExists(cands(i)) Then
            FindEdge = cands(i)
            Exit Function
        End If
    Next
    FindEdge = ""
End Function

Dim edge : edge = FindEdge()
If edge = "" Then
    MsgBox "Microsoft Edge not found. Please install it first: https://www.microsoft.com/edge", vbExclamation, "DeepSeek Harness"
    WScript.Quit 1
End If

' 0) make sure the desktop shortcut exists, recreate it if missing
Dim DesktopLnk : DesktopLnk = shell.SpecialFolders("Desktop") & "\DeepSeek Harness.lnk"
If Not fso.FileExists(DesktopLnk) Then
    Dim sc
    Set sc = shell.CreateShortcut(DesktopLnk)
    sc.TargetPath = shell.ExpandEnvironmentStrings("%WINDIR%") & "\System32\wscript.exe"
    sc.Arguments = """" & WScript.ScriptFullName & """"
    sc.IconLocation = ScriptDir & "\deepseek.ico"
    sc.Description = "DeepSeek Harness"
    sc.Save()
End If

' 1) background auto-update check (async, checks on every open, does not block)
Dim UpdatePs1 : UpdatePs1 = ScriptDir & "\install.ps1"
If fso.FileExists(UpdatePs1) Then
    shell.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & UpdatePs1 & """ -UpdateCheck", 0, False
End If

' 2) start dsh web hidden if not running, wait until ready (max 90s)
If Not IsWebUp() Then
    shell.Run "cmd /c dsh web >> """ & OutLog & """ 2>> """ & ErrLog & """", 0, False
    Dim i
    For i = 1 To 90
        WScript.Sleep 1000
        If IsWebUp() Then Exit For
    Next
    If Not IsWebUp() Then
        MsgBox "dsh web failed to start within 90s." & vbCrLf & "Log: " & ErrLog, vbExclamation, "DeepSeek Harness"
        WScript.Quit 1
    End If
End If

' 3) open Edge standalone app window (no tabs, no address bar)
shell.Run """" & edge & """ --app=" & Url, 1, False