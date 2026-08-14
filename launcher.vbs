' ============================================================
' dsh-edge-app 无窗口启动器
' 点击 "DeepSeek Harness" 快捷方式后:
'   1) 若 dsh web 未运行 -> 无窗口后台启动 (hidden cmd)
'   2) 等待服务就绪 (最多 90 秒)
'   3) 以 Edge 独立应用窗口打开 (--app, 非标签页)
' 全部无控制台窗口，日志写入本文件所在目录
' ============================================================
Option Explicit

Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")
Dim shell : Set shell = CreateObject("WScript.Shell")
Dim ScriptDir : ScriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
Dim Url : Url = "http://127.0.0.1:3080"
Dim OutLog : OutLog = ScriptDir & "\dsh-web.log"
Dim ErrLog : ErrLog = ScriptDir & "\dsh-web.err.log"

' ---- 检查 dsh web 是否已就绪 ----
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

' ---- 查找 msedge.exe ----
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

' ---- 主流程 ----
Dim edge : edge = FindEdge()
If edge = "" Then
    MsgBox "Microsoft Edge not found. Please install it first: https://www.microsoft.com/edge", vbExclamation, "DeepSeek Harness"
    WScript.Quit 1
End If

If Not IsWebUp() Then
    ' 无窗口后台启动 dsh web（隐藏 cmd，输出重定向到日志）
    Dim cmd : cmd = "cmd /c dsh web >> """ & OutLog & """ 2>> """ & ErrLog & """"
    shell.Run cmd, 0, False

    ' 等待服务就绪（最多 90 秒）
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

' 打开 Edge 独立应用窗口（无地址栏/标签栏）
shell.Run """" & edge & """ --app=" & Url, 1, False