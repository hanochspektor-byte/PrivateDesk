
Option Explicit

Dim wmi, processes, proc
Dim commandLine, stopped, result

stopped = 0

Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set processes = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name='powershell.exe'")

For Each proc In processes
    commandLine = proc.CommandLine

    If Not IsNull(commandLine) Then
        If InStr(1, commandLine, "PrivateDesk-Bridge-CPU-Fix.ps1", vbTextCompare) > 0 _
        Or InStr(1, commandLine, "Watch-PrivateDesk-ADB.ps1", vbTextCompare) > 0 Then

            result = proc.Terminate()
            If result = 0 Then stopped = stopped + 1
        End If
    End If
Next

MsgBox "PrivateDesk stopped." & vbCrLf & _
       "Processes stopped: " & stopped, _
       64, "PrivateDesk"
