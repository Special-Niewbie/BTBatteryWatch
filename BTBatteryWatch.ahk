/*
BTBatteryWatch

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
#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#Persistent

; Check whether the config.ini file exists
configFile := A_ScriptDir . "\config.ini"
if (!FileExist(configFile)) {
    MsgBox, 64, Info, The config.ini file was not found. Please create the file configuration in the same folder as the executable.
    Run, %A_ScriptDir%\conf.exe
    ExitApp
}

; Verifica la versione del programma all'avvio
CheckForUpdates()

Menu, Tray, NoStandard

; Menu System Tray
Menu, Tray, Add, Settings, OpenSettings
Menu, Tray, Tip, Bluetooth Battery Level Checker
Menu, Tray, Add, , Separator
Menu, Tray, Add, Reload, ReloadScript
Menu, Tray, Add, , Separator
Menu, Tray, Add, Updates / Donate, OpenSite
Menu, Tray, Add, Show Version, ShowVersionInfo
Menu, Tray, Add, , Separator
Menu, Tray, Add, Exit, ExitApp

; Read the device name from the .ini file
IniRead, deviceName, %configFile%, Settings, DeviceName, Error
if (deviceName = "Error") {
    MsgBox, 16, Error, Unable to read device name from config.ini file. Verify that the file contains a [Settings] section with a DeviceName entry.
    ExitApp
}

SetTimer, UpdateBatteryIcon, 600000 ; Imposta un timer per aggiornare l'icona ogni ora (600000 ms = 10 minutes)
SetTimer, InitialUpdate, -3000 ; Esegui l'aggiornamento dell'icona 3 secondi dopo l'avvio

UpdateBatteryIcon() {
    global deviceName
    isDeviceConnected := IsDeviceConnected(deviceName)
    if (!isDeviceConnected) {
        Menu, Tray, Icon, %A_ScriptDir%\icons\BTNA.ico
        Menu, Tray, Tip, Bluetooth Device not connected
        return
    }
    
    batteryLevel := GetBatteryLevel(deviceName)
    iconFile := GetBatteryIconFile(batteryLevel)
    Menu, Tray, Icon, %iconFile%
    Menu, Tray, Tip, Battery Level: %batteryLevel%`%
}

IsDeviceConnected(deviceName) {

	; Check if the infoDeviceConnection.ps1 file exists
    psFile := A_ScriptDir . "\infoDeviceConnection.ps1"
    if (!FileExist(psFile)) {
        MsgBox, 16, Error, Missing configurations file: `nPlease reinstall the software or if the problem persist contact the Developer.
        ExitApp
    }

	; Run the PowerShell script and generate an output file
	RunWait, powershell.exe -NoProfile -ExecutionPolicy Bypass -File infoDeviceConnection.ps1 > "%OutputFile%", , Hide
	Sleep 2500
    RunPowerShellForStatus(PowerShellCommandOutput, FirstOutputVar)
    return FirstOutputVar
}

RunPowerShellForStatus(Command, ByRef FirstOutputVar) {

	tempFile := A_ScriptDir . "\tempPSOutput_Connected.txt"
	; Debugging: Write PowerShell command to a file
    ;FileAppend, %PowerShellCommandOutput%, %A_ScriptDir%\debugPSCommand_Connected.txt

    ; Run the PowerShell command and save the output to a temporary file
    RunWait % "powershell.exe -NoProfile -Command " . Chr(34) . Command . " | Out-File -FilePath " . Chr(34) . tempFile . Chr(34) . Chr(34),, Hide ; Esegui in modalità visibile
	
    ; Debugging: Check if the temporary file was created
    ;if (!FileExist(tempFile)) {
        ;MsgBox, 16, Error, temporary file was not created: %tempFile%
        ;return false
    ;}
    
    ; Read the output of the temporary file
    FileRead, FirstOutputVar, %tempFile%
	
    ; Debugging: Write PowerShell output to a debug file
    ;FileAppend, %FirstOutputVar%, %A_ScriptDir%\debugPSOutput_Connected.txt

    ; Delete the temporary file
    FileDelete, %tempFile%

    ; Clean and analyze the output
    FirstOutputVar := Trim(FirstOutputVar)
    StringReplace, FirstOutputVar, FirstOutputVar, `r`n, , All

    ; Debug: Show the read result
    ;MsgBox, Result from RunPowerShellForStatus: %FirstOutputVar%
}



GetBatteryLevel(deviceName) {
    PowerShellCommand := "
    (
        $BatteryLevel = (Get-PnpDevice -FriendlyName '*" . deviceName . "*' | ForEach-Object { Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName '{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2' | Where-Object { $_.Type -ne 'Empty' } | Select-Object -ExpandProperty Data })
        $BatteryLevel -join ''
    )"
	; pause
    RunPowerShell(PowerShellCommand, OutputVar)
    return OutputVar
}

RunPowerShell(Command, ByRef OutputVar) {
    tempFile := A_ScriptDir . "\tempPSOutput.txt"
    RunWait % "powershell.exe -NoProfile -WindowStyle Hidden -Command " . Chr(34) . Command . " | Out-File -FilePath " . Chr(34) . tempFile . Chr(34) . Chr(34),, Hide
    FileRead, OutputVar, %tempFile%
    FileDelete, %tempFile%
    OutputVar := Trim(OutputVar) ; Remove any whitespace at the beginning and end
    StringReplace, OutputVar, OutputVar, `r`n, , All ; Remove any carriage returns
}

GetBatteryIconFile(batteryLevel) {
    batteryLevel := Round(batteryLevel)
    if (batteryLevel >= 97) {
        return A_ScriptDir . "\icons\BT100.ico"
    } else if (batteryLevel >= 92) {
        return A_ScriptDir . "\icons\BT95.ico"
    } else if (batteryLevel >= 87) {
        return A_ScriptDir . "\icons\BT90.ico"
    } else if (batteryLevel >= 82) {
        return A_ScriptDir . "\icons\BT85.ico"
    } else if (batteryLevel >= 77) {
        return A_ScriptDir . "\icons\BT80.ico"
    } else if (batteryLevel >= 72) {
        return A_ScriptDir . "\icons\BT75.ico"
    } else if (batteryLevel >= 67) {
        return A_ScriptDir . "\icons\BT70.ico"
    } else if (batteryLevel >= 62) {
        return A_ScriptDir . "\icons\BT65.ico"
    } else if (batteryLevel >= 57) {
        return A_ScriptDir . "\icons\BT60.ico"
    } else if (batteryLevel >= 52) {
        return A_ScriptDir . "\icons\BT55.ico"
    } else if (batteryLevel >= 47) {
        return A_ScriptDir . "\icons\BT50.ico"
    } else if (batteryLevel >= 42) {
        return A_ScriptDir . "\icons\BT45.ico"
    } else if (batteryLevel >= 37) {
        return A_ScriptDir . "\icons\BT40.ico"
    } else if (batteryLevel >= 32) {
        return A_ScriptDir . "\icons\BT35.ico"
    } else if (batteryLevel >= 27) {
        return A_ScriptDir . "\icons\BT30.ico"
    } else if (batteryLevel >= 22) {
        return A_ScriptDir . "\icons\BT25.ico"
    } else if (batteryLevel >= 17) {
        return A_ScriptDir . "\icons\BT20.ico"
    } else if (batteryLevel >= 12) {
        return A_ScriptDir . "\icons\BT15.ico"
    } else if (batteryLevel >= 7) {
        return A_ScriptDir . "\icons\BT10.ico"
    } else if (batteryLevel >= 4) {
        return A_ScriptDir . "\icons\BT5.ico"
    } else if (batteryLevel >= 2) {
        return A_ScriptDir . "\icons\BT3.ico"
    } else {
        return A_ScriptDir . "\icons\BT1.ico"
    }
}

ShowBatteryLevel() {
    global deviceName
    ; Leggi il nome del dispositivo dal file config.ini
    configFile := A_ScriptDir . "\config.ini"
    IniRead, deviceName, %configFile%, Settings, DeviceName, Error
    if (deviceName = "Error") {
        MsgBox, 64, Info, The config.ini file was not found or is incorrect. Please check the configuration.
        ExitApp
    }

    batteryLevel := GetBatteryLevel(deviceName)
    TrayTip, %deviceName%, % "Battery Level: " batteryLevel "%"
    Sleep, 5000
    TrayTip
}

InitialUpdate() {
    UpdateBatteryIcon()
}

; Hotkey buttons Windows+Space
#Space::ShowBatteryLevel()

; Start the timer immediately when the script starts
UpdateBatteryIcon()
return

; Function to open the settings window
OpenSettings:
    Run, %A_ScriptDir%\conf.exe
return

ReloadScript:
    Reload
return

OpenSite() {
    Run, https://github.com/Special-Niewbie/BTBatteryWatch
}

CheckForUpdates() {
    localVersionFile := A_ScriptDir . "\version"
    if (!FileExist(localVersionFile)) {
        MsgBox, 16, Error, The version file was not found.
        ExitApp
    }

    FileRead, localVersion, %localVersionFile%
    localVersion := Trim(localVersion)

    url := "https://raw.githubusercontent.com/Special-Niewbie/BTBatteryWatch/main/version"
    latestVersionFile := A_ScriptDir . "\latest_version"
    
    ; Download the latest version file
    UrlDownloadToFile, %url%, %latestVersionFile%

    ; Checks whether the latest version file exists and contains valid data
    if (FileExist(latestVersionFile)) {
        FileRead, latestVersion, %latestVersionFile%
        latestVersion := Trim(latestVersion)
        FileDelete, %latestVersionFile%

        ; Check if the downloaded content is not an HTTP error (ex. 404: Not Found)
        if (InStr(latestVersion, "404: Not Found") = 0 && localVersion != latestVersion) {
            MsgBox, 64, Update Available, A new version is available: %latestVersion%`n`nYou are currently using version: %localVersion%`n`nWould you like to visit the project page on GitHub to Download it?
            ifMsgBox, OK
                Run, https://github.com/Special-Niewbie/BTBatteryWatch
        }
    }
}

; Function to show version information
ShowVersionInfo:
    versionFile := A_ScriptDir . "\version"
    if (!FileExist(versionFile)) {
        MsgBox, 16, Error, The version file was not found.
        ExitApp
    }
    FileRead, currentVersion, %versionFile%
    MsgBox, 64, Version Info, Script Version: %currentVersion% `n`nAuthor: Special-Niewbie Softwares `nCopyright(C) 2024 Special-Niewbie Softwares
return

ExitApp:
ExitApp
