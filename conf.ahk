/*
BT Battery Watch Settings

Copyright(C) 2024 Special-Niewbie Softwares

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation version 3.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/
#SingleInstance Force
#NoEnv
SetWorkingDir %A_ScriptDir%
SetBatchLines -1

mainexe := A_ScriptDir . "\BTBatteryWatch.exe"
if (!FileExist(mainexe)) {
    MsgBox, 16, Error, Missing Software files: `nPlease reinstall the software or if the problem persist contact the Developer.
    ExitApp
}

Gui +hWndhMainWnd
Gui Font, s9, Segoe UI
Gui Font
Gui Font, s12 cBlack, Segoe UI
Gui Add, Button, hWndhBtnSearch gSearch x80 y30 w922 h56, &Search
Gui Font
Gui Font, s9, Segoe UI
Gui Font
Gui Font, s9, Segoe UI
Gui Add, Button, hWndhBtnCancel3 gCancel x41 y800 w145 h50, &Close / Cancel
Gui Font
Gui Font, s9, Segoe UI
Gui, Add, Text, x22 y110 w400 h20, Choose the available Bluetooth registered Device from your computer:
Gui Font
Gui Font, s9, Segoe UI
Gui Add, ListBox, hWndhLbxItems vLbxItems x22 y128 w1040 h629,
Gui Font
Gui Font, s9, Segoe UI
Gui Add, Button, hWndhBtnApply4 gApply x890 y800 w145 h50, &Apply
Gui Font

Gui Show, w1080 h877, BT Battery Watch Settings
Return

GuiEscape:
GuiClose:
    ExitApp

Search:
    RunWait, powershell.exe -Command "Get-PnpDevice -Class Bluetooth | Select-Object -ExpandProperty FriendlyName | Out-File -FilePath '%A_ScriptDir%\devices.txt' -Encoding utf8", , Hide
    FileRead, devices, %A_ScriptDir%\devices.txt
    StringReplace, devices, devices, `r`n, `n, All
    StringReplace, devices, devices, `n, |, All
    GuiControl,, LbxItems, |%devices%
Return

Apply:
    GuiControlGet, selectedDevice,, LbxItems
    if (selectedDevice) {
        iniFile := A_ScriptDir . "\config.ini"
        ; Check if the file exists
        if (FileExist(iniFile)) {
            ; Try to write to the file
            try {
                IniWrite, %selectedDevice%, %iniFile%, Settings, DeviceName
                MsgBox, 64, Success, Settings have been updated.
                restartBTBatteryWatch()
            } catch {
                MsgBox, 16, Error, Failed to update settings.
            }
        } else {
            ; Try to create the file
            try {
                IniWrite, %selectedDevice%, %iniFile%, Settings, DeviceName
                MsgBox, 64, Success, The file 'config.ini' has been created successfully.
                restartBTBatteryWatch()
            } catch {
                MsgBox, 16, Error, Failed to create the file 'config.ini'.
            }
        }
    }
Return

Cancel:
    ExitApp
Return

restartBTBatteryWatch() {
    global mainexe
    ; Check if the process is running
    Process, Exist, BTBatteryWatch.exe
    if (ErrorLevel) {
        ; If running, terminate it
        Process, Close, BTBatteryWatch.exe
    }
    ; Start the process
    Run, %mainexe%
}