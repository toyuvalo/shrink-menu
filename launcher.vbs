' launcher.vbs v2.1.0 -- Collects ALL selected files from Explorer via COM, then launches shrink
' Bug fix 2026-07-25: the file list was written with FileSystemObject's default
' ASCII/ANSI encoding while shrink.ps1 read it back as UTF-8. Any name with a
' non-ASCII character (smart quote, accent, en-dash) came back with a
' replacement character, the path stopped resolving, and the file was silently
' dropped from the batch. Now written as UTF-8 via ADODB.Stream.
' Bug fix 2026-05-19: previously iterated all Explorer windows and grabbed the
' SelectedItems of the FIRST one with any selection -- which could be the wrong
' window if the user had another Explorer window open. Now matches the right-
' clicked path (%1) against each window's selection.
' Usage: wscript.exe launcher.vbs "%1"

Dim fso, wshShell
Set fso = CreateObject("Scripting.FileSystemObject")
Set wshShell = CreateObject("WScript.Shell")

Dim rightClickedPath
If WScript.Arguments.Count > 0 Then
    rightClickedPath = WScript.Arguments(0)
Else
    rightClickedPath = ""
End If

Dim tempDir, lockFile
tempDir  = wshShell.ExpandEnvironmentStrings("%TEMP%")
lockFile = tempDir & "\shrink_menu.lock"

On Error Resume Next
If fso.FileExists(lockFile) Then
    Dim lockAge
    lockAge = DateDiff("s", fso.GetFile(lockFile).DateLastModified, Now)
    If lockAge < 5 Then
        WScript.Quit
    End If
End If

Dim lockHandle
Set lockHandle = fso.CreateTextFile(lockFile, True)
If Err.Number <> 0 Then
    WScript.Quit
End If
lockHandle.Close
On Error GoTo 0

WScript.Sleep 400

' Find the Explorer window whose selection contains the right-clicked path
Dim shellApp, wnd, selectedItems
Dim files
Set files = CreateObject("Scripting.Dictionary")

On Error Resume Next
Set shellApp = CreateObject("Shell.Application")
For Each wnd In shellApp.Windows
    If InStr(1, TypeName(wnd.Document), "ShellFolderView", vbTextCompare) > 0 Then
        Set selectedItems = wnd.Document.SelectedItems
        If Not selectedItems Is Nothing Then
            If selectedItems.Count > 0 Then
                Dim item, matchFound
                matchFound = False
                For Each item In selectedItems
                    If StrComp(item.Path, rightClickedPath, vbTextCompare) = 0 Then
                        matchFound = True
                        Exit For
                    End If
                Next
                If matchFound Then
                    For Each item In selectedItems
                        If Not files.Exists(item.Path) Then
                            files.Add item.Path, True
                        End If
                    Next
                    Exit For
                End If
            End If
        End If
    End If
Next
On Error GoTo 0

' Fallback: use %1 alone if no window matched
If files.Count = 0 And rightClickedPath <> "" Then
    If fso.FileExists(rightClickedPath) Then
        files.Add rightClickedPath, True
    End If
End If

On Error Resume Next
fso.DeleteFile lockFile, True
On Error GoTo 0

If files.Count = 0 Then WScript.Quit

' Write the list as UTF-8 (with BOM) so non-ASCII file names survive the
' hand-off. ADODB.Stream is the only way to set the encoding from VBS.
Dim collectFile, key, stream, wroteUtf8
collectFile = tempDir & "\shrink_menu_batch.txt"
wroteUtf8 = False

On Error Resume Next
Set stream = CreateObject("ADODB.Stream")
If Err.Number = 0 Then
    stream.Type = 2                  ' adTypeText
    stream.Charset = "utf-8"
    stream.Open
    For Each key In files.Keys
        stream.WriteText key & vbCrLf
    Next
    stream.SaveToFile collectFile, 2 ' adSaveCreateOverWrite
    stream.Close
    If Err.Number = 0 Then wroteUtf8 = True
End If
Err.Clear
On Error GoTo 0

' Fallback if ADODB is unavailable -- ASCII-named files still work.
If Not wroteUtf8 Then
    Dim cf
    Set cf = fso.CreateTextFile(collectFile, True)
    For Each key In files.Keys
        cf.WriteLine key
    Next
    cf.Close
End If

Dim scriptPath, cmd
scriptPath = fso.GetParentFolderName(WScript.ScriptFullName) & "\shrink.ps1"
cmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File """ & scriptPath & """ -ListFile """ & collectFile & """"
wshShell.Run cmd, 0, False
