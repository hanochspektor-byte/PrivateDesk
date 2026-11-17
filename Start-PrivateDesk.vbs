
Option Explicit

Dim shell, fso, folder, serverPath, adbWatcherPath
Dim command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

folder = fso.GetParentFolderName(WScript.ScriptFullName)

serverPath = folder & "\PrivateDesk-Bridge-CPU-Fix.ps1"
adbWatcherPath = folder & "\Watch-PrivateDesk-ADB.ps1"

If Not fso.FileExists(serverPath) Then
    MsgBox "PrivateDesk server script not found.", 16
    WScript.Quit
End If

If Not fso.FileExists(adbWatcherPath) Then
    MsgBox "ADB watcher script not found.", 16
    WScript.Quit
End If

shell.CurrentDirectory = folder

' Start the PrivateDesk server.
command = "powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File """ & serverPath & """"
shell.Run command, 0, False

' Start the USB connection watcher.
command = "powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File """ & adbWatcherPath & """"
shell.Run command, 0, False
