' ============================================================
' dsh-edge-app windowless launcher
' Clicking the "DeepSeek Harness" shortcut:
'   0) silent auto-update check for @deepseek-ai/dsh (throttled 24h)
'   1) if dsh web is not running -> start it in a hidden window
'   2) wait until the service is ready (max 90 seconds)
'   3) open Edge standalone app window (--app, not a tab)
' No console windows at all; logs are written next to this file
' ============================================================
Option Explicit

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim shell : Set shell = CreateObject("WScript.Shell")
Dim ScriptDir : ScriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
Dim Url : Url = "http://127.0.0.1:3080"
Dim OutLog : OutLog = ScriptDir & "\dsh-web.log"
Dim ErrLog : ErrLog = ScriptDir & "\dsh-web.err.log"

' ---- check whether dsh web is already up ----
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

' ---- locate msedge.exe ----
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

' ---- main flow ----
Dim edge : edge = FindEdge()
If edge = "" Then
    MsgBox "Microsoft Edge not found. Please install it first: https://www.microsoft.com/edge", vbExclamation, "DeepSeek Harness"
    WScript.Quit 1
End If

' 0) silent auto-update check (throttled 24h, no window; auto-updates if newer)
Dim UpdatePs1 : UpdatePs1 = ScriptDir & "\update-dsh.ps1"
If fso.FileExists(UpdatePs1) Then
    shell.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & UpdatePs1 & """", 0, True
End If

' 1) make sure dsh web is running
If Not IsWebUp() Then
    ' start dsh web in a hidden window, redirect output to logs
    Dim cmd : cmd = "cmd /c dsh web >> """ & OutLog & """ 2>> """ & ErrLog & """"
    shell.Run cmd, 0, False

    ' 2) wait until ready (max 90 seconds)
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