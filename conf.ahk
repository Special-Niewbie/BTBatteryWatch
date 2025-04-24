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
jsonFile := A_ScriptDir . "\conf.json"
iconsPath := A_ScriptDir . "\icons"

if (!FileExist(mainexe)) {
    MsgBox, 16, Error, Missing Software files: `nPlease reinstall the software or if the problem persist contact the Developer.
    ExitApp
}

; If the JSON file does not exist, create it with default
if (!FileExist(jsonFile)) {
    ; Create an empty device array
    defaultDevices := []
    
    Loop, 4 {
        deviceObj := {}
        deviceObj.device := A_Index
        deviceObj.name := ""
        deviceObj.iconTheme := ""
        deviceObj.enabled := false
        defaultDevices[A_Index] := deviceObj
    }
    
    ; Using CreateCustomJSON to generate formatted JSON text
    jsonText := CreateCustomJSON(defaultDevices)
    
    FileEncoding, UTF-8
    FileAppend, %jsonText%, %jsonFile%
    
    if (ErrorLevel) {
        MsgBox, 16, Error, Failed to create default JSON file.
        ExitApp
    }
}


Gui +hWndhMainWnd
Gui Font, s9, Segoe UI
Gui Font
Gui Font, s12 cBlack, Segoe UI
Gui Add, Button, hWndhBtnSearch gSearch x80 y30 w922 h56, &Search

Gui Font
Gui Font, s9, Segoe UI
Gui Add, Button, hWndhBtnCancel3 gCancel x41 y600 w145 h50, &Close / Cancel
Gui Font
Gui Font, s9, Segoe UI
Gui, Add, Text, x22 y110 w400 h20, Choose the available Bluetooth registered Device from your computer:

; Device Blocks 1 → 4
Loop, 4 {
    idx := A_Index
    xPos := 22 + ((idx - 1) * 265)
    Gui, Add, Text, x%xPos% y140 w260 h20 +Center, Device %idx%

    Gui, Add, ListBox, vDevice%idx% x%xPos% y160 w260 h320,
    Gui, Add, DropDownList, vTheme%idx% x%xPos% y490 w260,
    Gui, Add, Button, gDisable%idx% x%xPos% y525 w125 h30, Disable
    Gui, Add, Button, gApply%idx% x+5 y525 w125 h30, Apply
}

Gui Show, w1100 h677, BT Battery Watch Settings

; Populate DropDownLists with subfolders from \icons
Gosub, LoadThemes

; Load existing device settings to UI
Gosub, LoadDeviceSettings

Return

LoadDeviceSettings:
    try {
        FileEncoding, UTF-8
        FileRead, jsonContent, %jsonFile%
        
        if (jsonContent != "") {
            json := JSON.Load(jsonContent)
            
            if (IsObject(json) && IsObject(json.devices)) {
                Loop, % json.devices.Length() {
                    currentDevice := json.devices[A_Index]
                    deviceIdx := currentDevice.device
                    deviceName := currentDevice.name
                    deviceTheme := currentDevice.iconTheme
                    
                    if (deviceName) {
                        GuiControl, ChooseString, Device%deviceIdx%, %deviceName%
                    }
                    
                    if (deviceTheme) {
                        GuiControl, ChooseString, Theme%deviceIdx%, %deviceTheme%
                    }
                }
            }
        }
    } catch e {
        ; Silent failure - Will use default values ​​if JSON is invalid
    }
Return

GuiEscape:
GuiClose:
    ExitApp

Search:
    RunWait, powershell.exe -Command "Get-PnpDevice -Class Bluetooth | Select-Object -ExpandProperty FriendlyName | Out-File -FilePath '%A_ScriptDir%\devices.txt' -Encoding utf8", , Hide
    FileRead, devices, %A_ScriptDir%\devices.txt
    StringReplace, devices, devices, `r`n, `n, All
    StringReplace, devices, devices, `n, |, All
    Loop, 4 {
        GuiControl,, Device%A_Index%, |%devices%
    }
Return

; Function to create custom JSON content
CreateCustomJSON(devices) {
    ; Use a real newline character instead of \r\n
    json := "{" . "`r`n" . "  ""devices"": [" . "`r`n"
    
    for i, device in devices {
        json .= "    {" . "`r`n"
        json .= "      ""device"": """ . device.device . """," . "`r`n"
        json .= "      ""name"": """ . device.name . """," . "`r`n"
        json .= "      ""iconTheme"": """ . device.iconTheme . """," . "`r`n"
        json .= "      ""enabled"": " . (device.enabled ? "true" : "false") . "`r`n"
        json .= "    }" . (i < devices.Length() ? "," . "`r`n" : "`r`n")
    }
    
    json .= "  ]" . "`r`n" . "}"
    
    return json
}

LoadThemes:
    themeList := ""
    Loop, Files, %iconsPath%\*.*, D
    if FileExist(A_LoopFileFullPath "\BT1.ico")
        themeList .= A_LoopFileName "|"

    themeList := RTrim(themeList, "|")
    Loop, 4 {
        GuiControl,, Theme%A_Index%, |%themeList%
    }
Return

; Dynamic APPLY functions
Apply1:
Apply2:
Apply3:
Apply4:
    StringTrimLeft, idx, A_ThisLabel, 5
    GuiControlGet, dev,, Device%idx%
    GuiControlGet, theme,, Theme%idx%

    if (!dev || !theme) {
        MsgBox, 48, Warning, Please select both device and theme for Device %idx%..
        Return
    }

    ; Read current settings from devices
    devices := []

    ; Initialize devices with empty values
    Loop, 4 {
        device := {}
        device.device := A_Index
        device.name := ""
        device.iconTheme := ""
        device.enabled := false
        devices[A_Index] := device
    }

    ; Read existing JSON file if present
    if (FileExist(jsonFile)) {
        FileEncoding, UTF-8
        FileRead, jsonContent, %jsonFile%

        if (jsonContent != "") {
            ; Extract values ​​from existing devices
            deviceData := ParseCustomJSON(jsonContent)
            if (deviceData) {
                devices := deviceData
            }
        }
    }

    ; Update the selected device
    devices[idx].name := dev
    devices[idx].iconTheme := theme
    devices[idx].enabled := true

    ; Create and save the new JSON content
    newJsonContent := CreateCustomJSON(devices)

    ; Save the file
    FileDelete, %jsonFile%
    FileEncoding, UTF-8
    FileAppend, %newJsonContent%, %jsonFile%

    if (ErrorLevel) {
        MsgBox, 16, Error, Failed to write to JSON file.
        Return
    }

    MsgBox, 64, Success, Device %idx% settings have been saved!

    ; Restart the main application
    Gosub, restartBTBatteryWatch
Return


Disable1:
Disable2:
Disable3:
Disable4:
    StringTrimLeft, idx, A_ThisLabel, 7
    
    ; Read current settings from devices
    devices := []
    
    ; Initialize devices with empty values
    Loop, 4 {
        device := {}
        device.device := A_Index
        device.name := ""
        device.iconTheme := ""
        device.enabled := false
        devices[A_Index] := device
    }
    
    ; Read existing JSON file if present
    if (FileExist(jsonFile)) {
        FileEncoding, UTF-8
        FileRead, jsonContent, %jsonFile%
        
        if (jsonContent != "") {
            ; Extract values ​​from existing devices
            deviceData := ParseCustomJSON(jsonContent)
            if (deviceData) {
                devices := deviceData
            }
        }
    }
    
    ; Disable the selected device
    devices[idx].enabled := false
    
    ; Create and save the new JSON content
    newJsonContent := CreateCustomJSON(devices)
    
    ; Save the file
    FileDelete, %jsonFile%
    FileEncoding, UTF-8
    FileAppend, %newJsonContent%, %jsonFile%
    
    if (ErrorLevel) {
        MsgBox, 16, Error, Failed to write to JSON file.
        Return
    }
    
    MsgBox, 64, Info, Device %idx% has been disabled.
    
    ; Restart the main application
    Gosub, restartBTBatteryWatch
Return

; Function to parse custom JSON content
ParseCustomJSON(jsonContent) {
    devices := []

    ; Find the "devices" array section: [...]
    arrayPattern := "s)""devices""\s*:\s*\[(.*?)\]"
    if RegExMatch(jsonContent, arrayPattern, arrayMatch) {
        deviceList := arrayMatch1

        ; Manually split individual JSON objects in array
		; Will split by each }, followed by comma or end
        objectList := StrSplit(deviceList, "},")
        for index, obj in objectList {
            obj := Trim(obj)
            if (SubStr(obj, 0) != "}")  ; if it doesn't end with }, add it
                obj .= "}"
            if (SubStr(obj, 1, 1) != "{") ; if it doesn't start with {, add it
                obj := "{" . obj

            ; Extract individual fields with regex
            device := {}

            if RegExMatch(obj, """device""\s*:\s*""?(\d+)""?", m)
                device.device := m1

            if RegExMatch(obj, """name""\s*:\s*""(.*?)""", m)
                device.name := m1
            else
                device.name := ""

            if RegExMatch(obj, """iconTheme""\s*:\s*""(.*?)""", m)
                device.iconTheme := m1
            else
                device.iconTheme := ""

            if RegExMatch(obj, """enabled""\s*:\s*(true|false)", m)
                device.enabled := (m1 = "true")
            else
                device.enabled := false

            ; Insert in correct position (avoid overwriting)
            if (device.device != "")
                devices[device.device] := device
        }
    }

    ; If a device is not present (for example, when it was not found in the JSON), initialize it
    for i, device in devices {
        if (!device.name) {
            device.name := ""
        }
        if (!device.iconTheme) {
            device.iconTheme := ""
        }
        if (!device.enabled) {
            device.enabled := false
        }
    }

    return devices
}


Cancel:
    ExitApp
Return

FileReadText(path) {
    FileEncoding, UTF-8
    FileRead, out, %path%
    return out
}

restartBTBatteryWatch:
    ; Check if the process is running
    Process, Exist, BTBatteryWatch.exe
    if (ErrorLevel) {
        ; If running, terminate it
        Process, Close, BTBatteryWatch.exe
    }
    ; Start the process
    Run, %mainexe%
Return