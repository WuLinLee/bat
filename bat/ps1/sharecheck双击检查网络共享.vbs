Option Explicit

Dim Shell
Dim FSO
Dim FolderPath
Dim ScriptPath
Dim Args

Set Shell = CreateObject("Shell.Application")
Set FSO = CreateObject("Scripting.FileSystemObject")

FolderPath = FSO.GetParentFolderName(WScript.ScriptFullName)
ScriptPath = FSO.BuildPath(FolderPath, "sharecheck.ps1")

If Not FSO.FileExists(ScriptPath) Then

    MsgBox "sharecheck.ps1 not found:" & vbCrLf & ScriptPath, _
           16, _
           "Network Share Check"

    WScript.Quit 1
End If

Args = "-NoLogo -NoProfile -ExecutionPolicy Bypass -NoExit -File " _
     & Chr(34) & ScriptPath & Chr(34)

Shell.ShellExecute _
    "powershell.exe", _
    Args, _
    FolderPath, _
    "runas", _
    1