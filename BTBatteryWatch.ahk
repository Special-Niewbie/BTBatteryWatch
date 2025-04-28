/*
BT Battery Watch

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
#Persistent
#NoEnv
SendMode Input
SetWorkingDir %A_ScriptDir%
#Include %A_ScriptDir%\libs\Gdip_All.ahk

; Paths
jsonFile := A_ScriptDir . "\conf.json"
incubatorPath := A_ScriptDir . "\incubators"
stateFile := "BatteryToggleState"  ; Save as 0(OFF) o 1(ON)
customIconsRepo := "https://api.github.com/repos/Special-Niewbie/BTBatteryWatch/contents/Custom_Icons"
iconCustomThemePath := A_ScriptDir . "\icons\"
stateFileBatteryWarningMessage := A_ScriptDir . "\LowBatterySettings"
iconDisconnectedPath := A_ScriptDir . "\icons\"
global updateCheckPerformed := false
global connectionCheckStartTime := A_TickCount
global deviceConnectionChecks := {}

; Number Variables
global showOnlyIconNumbers := 0
global stateFileIconNumbers := A_ScriptDir . "\ShowNumbersState"



; Load JSON configuration
if (!FileExist(jsonFile)) {
    MsgBox, 16, Error, Missing conf.json file. Open conf.exe and configure at least one device.
    Run, %A_ScriptDir%\conf.exe
    ExitApp
}

if (!FileExist(iconCustomThemePath)) {
    MsgBox, 16, Error, Missing `icons` folder. Creating...
	; Create icon folder if it does not exist
	FileCreateDir, %iconCustomThemePath%
}

if (!FileExist(stateFile))
    FileAppend, 1, %stateFile%
	
; If the file does not exist, it creates it and sets "Enabled=1" by default
if (!FileExist(stateFileBatteryWarningMessage)) {
    IniWrite, 1, %stateFileBatteryWarningMessage%, BatteryWarning, Enabled
}

; If the file does not exist, create it with the default setting of 0 (disabled)
if (!FileExist(stateFileIconNumbers))
    FileAppend, 0, %stateFileIconNumbers%

FileRead, batteryToggleState, %stateFile%
batteryToggleState := Trim(batteryToggleState)

FileRead, showOnlyIconNumbers, %stateFileIconNumbers%
showOnlyIconNumbers := Trim(showOnlyIconNumbers)

; Read initial state from RAW file
IniRead, batteryWarningMessageToggleState, %stateFileBatteryWarningMessage%, BatteryWarning, Enabled, 1

; Custom JSON parsing function (similar to conf.ahk)
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

            ; Insert in the correct position
            if (device.device != "")
                devices[device.device] := device
        }
    }

    return devices
}


; Read and parse JSON file
FileEncoding, UTF-8
FileRead, jsonContent, %jsonFile%
config := ParseCustomJSON(jsonContent)

; Check for program updates at startup
CheckForUpdates()

Menu, Tray, NoStandard

; System Tray Menu
Menu, Tray, Add, 👉 >>> BT Battery Watch Menu <<<, TitleLabel
Menu, Tray, Icon, 👉 >>> BT Battery Watch Menu <<<, % A_ScriptDir . "\asset\bt_batterywatch.ico"
Menu, Tray, Disable, 👉 >>> BT Battery Watch Menu <<<
Menu, Tray, Add, , Separator
Menu, Tray, Add, , Separator
Menu, Tray, Add, New Custom Icons, DownloadNewIcons
Menu, Tray, Icon, New Custom Icons, % A_ScriptDir . "\asset\download.ico"
Menu, Tray, Disable, New Custom Icons
Menu, Tray, Add, , Separator
Menu, Tray, Add, Settings, OpenSettings
Menu, Tray, Icon, Settings, % A_ScriptDir . "\asset\settings.ico"
Menu, Tray, Tip, Bluetooth Battery Level Checker
Menu, Tray, Add, , Separator
Menu, Tray, Add, Reload, ReloadScript
Menu, Tray, Add, , Separator
Menu, Tray, Add, Project Site, OpenProjectSite
Menu, Tray, Icon, Project Site, % A_ScriptDir . "\asset\github.ico"
Menu, Tray, Add, Donate, OpenDonationSite
Menu, Tray, Icon, Donate, % A_ScriptDir . "\asset\donate.ico"
Menu, Tray, Add, Show Version, ShowVersionInfo
Menu, Tray, Add, Show All Battery Levels, ShowAllBatteryLevels
Menu, Tray, Icon, Show All Battery Levels, % A_ScriptDir . "\asset\batteries.ico"
Menu, Tray, Add, , Separator
Menu, Tray, Add, ON/OFF Battery Monitor ShortKeys, ToggleBatteryMonitor
Menu, Tray, Add, ON/OFF Low Battery Message Warning, ToggleBatteryWarning
Menu, Tray, Add, ON/OFF Show Only Icon Numbers, ToggleIconNumbers
Menu, Tray, Add, Exit, ExitApp

; Cycle on each device
for index, dev in config {
	;Debug
    ; MsgBox, 64, Device Cycle, % "Device: " dev.device "`nEnabled: " dev.enabled 
    
    if (dev.enabled) {
        if (dev.device = 1) {
			;Debug
            ;MsgBox, 64, Start Monitor, Direct Start Monitor for Device 1
            StartDeviceMonitor(dev)
        } else {
            incubator := incubatorPath . "\Device" . dev.device . ".exe"
			;Debug
            ;MsgBox, 64, Incubator Control, % "Incubator Path: " incubator

            if (FileExist(incubator)) {
				;Debug
                ;MsgBox, 64, Incubator Startup, % "Device Startup" dev.device ".exe..."

                ; Log
                ;logFile := A_ScriptDir . "\incubator_log.txt"
				;Debug
                ;FileAppend, % "Starting incubator for Device " . dev.device . "`n", %logFile%

                ; Run
                ; Run, "%A_AhkPath%" "%incubator%", , Hide ;THIS FOR .AHK FILES
				
				; Run the .exe file directly instead of passing it to the AHK interpreter
				Run, "%incubator%", , Hide				

                ;if (ErrorLevel) {
                    ;MsgBox, 48, Error Run, % "Device Startup Error" dev.device ".ahk → ErrorLevel: " ErrorLevel
					;Debug
                    ;FileAppend, % "Startup error: " . ErrorLevel . "`n", %logFile%
                ;} else {
					;Debug
                    ;FileAppend, % "Incubator successfully launched`n", %logFile%
                    ;MsgBox, 64, Success, % "Device" dev.device ".ahk started successfully!"

                ;}
            } else {
                MsgBox, 48, File is missing, % "File not found: " incubator
            }
        }
    } else {
       ;MsgBox, 48, Disabled, % "Device " dev.device " is not enabled (`""enabled`"": false)"

    }
}

; Update program settings based on the settings files.
CheckForNewIconThemes()
UpdateTrayMenuIcon()
UpdateTrayMenuIconBatteryWarningMessage()
UpdateTrayMenuIconNumbers()

; This function should check for new themes and enable the menu item if needed
CheckForNewIconThemes() {
    global customIconsRepo, iconCustomThemePath
    
    ; Debug Create log
    ; logFile := A_ScriptDir . "\icon_check_log.txt"
    ; FileAppend, `n---- Checking for new themes: %A_Now% ----`n, %logFile%
    
    ; Get remote themes list
    tempRepoList := A_ScriptDir . "\temp_repo_list.json"
    ; FileAppend, Downloading from: %customIconsRepo%`n, %logFile%  DEBUG
    UrlDownloadToFile, %customIconsRepo%, %tempRepoList%
    if ErrorLevel {
        ; FileAppend, Error downloading icon list from GitHub`n, %logFile%
        return
    }
    
    FileRead, json, %tempRepoList%
    FileDelete, %tempRepoList%
    
    ; Get local themes
    localThemes := {}
    Loop, Files, %iconCustomThemePath%\*, D
    {
        localThemes[A_LoopFileName] := true
        ; FileAppend, Found local theme: %A_LoopFileName%`n, %logFile%
    }
    
    ; JSON with regex
    newThemesFound := false
    newThemesArray := []  ; I use an array instead of a concatenated string
    
    ; More robust regex for finding directories
    pattern := """name""[ \t]*:[ \t]*""([^""]+)""(?:[^{}]*?)""type""[ \t]*:[ \t]*""dir"""
    pos := 1
    
    ; FileAppend, Starting JSON scan`n, %logFile%
    
    while (pos := RegExMatch(json, pattern, match, pos)) {
        themeName := match1
        ; FileAppend, Found directory in JSON: %themeName%`n, %logFile%
        
        ; Check if this folder already exists locally
        if (!localThemes[themeName]) {
            ; FileAppend, New theme found: %themeName%`n, %logFile%
            newThemesFound := true
            newThemesArray.Push(themeName)  ; Add to array
        } else {
            ; FileAppend, Theme already exists locally: %themeName%`n, %logFile%
        }
        
        ; Advance your position for the next search
        pos += StrLen(match)
    }
    
    ; Build the final string after finding all the themes
    newThemes := ""
    for index, theme in newThemesArray {
        newThemes .= (newThemes = "" ? "" : "|") . theme
    }
    
    ; FileAppend, Final list of new themes: %newThemes%`n, %logFile%
    
    if (newThemesFound) {
        ; FileAppend, Enabling New Custom Icons menu`n, %logFile%
        Menu, Tray, Enable, New Custom Icons
        
        ; Save list of new themes to download
        IniWrite, %newThemes%, %A_ScriptDir%\BTBatteryWatch.ini, Icons, NewFolders
        
        ; Verify that it is written correctly
        IniRead, verifyThemes, %A_ScriptDir%\BTBatteryWatch.ini, Icons, NewFolders
        ; FileAppend, Verified INI content: %verifyThemes%`n, %logFile%
        
        ; Show TrayTip message
        title := "BT Battery Watch"
        message := "New Custom Icons Themes have been found!"
        TrayTip, %title%, %message%, 1, 17
    } else {
        ; FileAppend, No new themes found`n, %logFile%
        Menu, Tray, Disable, New Custom Icons
        
        ; Make sure the NewFolders key does not contain residual values
        IniDelete, %A_ScriptDir%\BTBatteryWatch.ini, Icons, NewFolders
    }
}

StartDeviceMonitor(dev) {
    global monitoredDevice, iconThemePath, connectionCheckStartTime, deviceConnectionChecks
    
    monitoredDevice := dev.name
    iconThemePath := A_ScriptDir . "\icons\" . dev.iconTheme
    
    ; Add device to watch list
    deviceConnectionChecks[dev.device] := {name: dev.name, lastCheck: 0, connected: false}
    
    ; Set normal timers
    SetTimer, UpdateBatteryIcon, 600000
    SetTimer, InitialUpdate, -3000
    
    ; Set timer for frequent connection check
    SetTimer, CheckPendingConnections, 30000  ; Check every 30 seconds
}

UpdateBatteryIcon() {
    global monitoredDevice, iconThemePath, iconDisconnectedPath
    isConnected := IsDeviceConnected(monitoredDevice)
    if (!isConnected) {
        Menu, Tray, Icon, %iconDisconnectedPath%\BTdisco.ico
        Menu, Tray, Tip, %monitoredDevice% - Not connected
        return
    }
    level := GetBatteryLevel(monitoredDevice)
    iconFile := GetBatteryIconFile(level, iconThemePath)
    
	; Let's check if we are using a direct HICON
    if (SubStr(iconFile, 1, 6) = "HICON:") {
        Menu, Tray, Icon, %iconFile%
        
        ; Important: destroyIcon AFTER the icon has been set
        hIcon := SubStr(iconFile, 7)
        SetTimer, DestroyIconTimer, -100  ; Destroy the icon after a short delay
    }
    else {
        Menu, Tray, Icon, %iconFile%
    }
    
    Menu, Tray, Tip, %monitoredDevice% - Battery: %level%`%
}

; Timer to destroy icon safely
DestroyIconTimer:
    global lastIconHandle
    if (lastIconHandle) {
        DestroyIcon(lastIconHandle)
        lastIconHandle := 0
    }
return

CheckPendingConnections() {
    global connectionCheckStartTime, deviceConnectionChecks
    
    ; Check if more than 3 minutes (180000 ms) have passed since start
    elapsedTime := A_TickCount - connectionCheckStartTime
    if (elapsedTime > 180000) {
        ; Disable this timer after 3 minutes
        SetTimer, CheckPendingConnections, Off
        return
    }
    
    ; Check each device not yet connected
    for deviceID, deviceInfo in deviceConnectionChecks {
        if (!deviceInfo.connected) {
            ; Check if it is connected now
            isConnected := IsDeviceConnected(deviceInfo.name)
            
            if (isConnected) {
                ; Device connected, update status
                deviceConnectionChecks[deviceID].connected := true
                UpdateBatteryIcon()  ; Immediately update the icon
                
                ; Check if all devices are connected
                allConnected := true
                for _, info in deviceConnectionChecks {
                    if (!info.connected) {
                        allConnected := false
                        break
                    }
                }
                
                ; If all devices are connected, disable the timer
                if (allConnected) {
                    SetTimer, CheckPendingConnections, Off
                }
            }
        }
    }
}

IsDeviceConnected(name) {
global deviceConnectionChecks

    ps1 := A_ScriptDir . "\Device1.ps1"
    if (!FileExist(ps1)) {
        MsgBox, 16, Error, Missing Device1.ps1
        ExitApp
    }
    
    ; Debug
    ; logFile := A_ScriptDir . "\connection_log.txt"
    ; FileAppend, % "`n=== Verifica connessione: " . A_Now . " ===`n", %logFile%
    ; FileAppend, % "Controllo connessione per: " . name . "`n", %logFile%
    
    temp := A_ScriptDir . "\tempPSOutput_Connected.txt"
    cmdLine := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ . ps1 . """ """ . name . """"
    
    ; FileAppend, % "Comando: " . cmdLine . "`n", %logFile%
    
    RunWait, %cmdLine%, , Hide
    Sleep, 1000
    
    if (!FileExist(temp)) {
        ; FileAppend, "Output file non creato!`n", %logFile%
        return false
    }
    
    FileRead, status, %temp%
    FileDelete, %temp%
    
    status := Trim(status)
    ; FileAppend, % "Status output: " . status . "`n", %logFile%
    
    ; Exact string verification, not partial
	isConnected := (status = "Connected" || InStr(status, "Connected") > 0 && !InStr(status, "Disconnected"))
    ; FileAppend, % "Verification result: " . (isConnected ? "Connected" : "Disconnected") . "`n", %logFile%
    
    for deviceID, deviceInfo in deviceConnectionChecks {
        if (deviceInfo.name = name) {
            deviceConnectionChecks[deviceID].connected := isConnected
            break
        }
    }
    
    return isConnected
}


GetBatteryLevel(name) {
    PowerShellCommand := "
	(
	$BatteryLevel = (Get-PnpDevice -FriendlyName '*" . name . "*' | ForEach-Object { Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName '{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2' | Where-Object { $_.Type -ne 'Empty' } | Select-Object -ExpandProperty Data })
	$BatteryLevel -join ''
    )"
    RunPowerShell(PowerShellCommand, output)
    return output
}

RunPowerShell(cmd, ByRef out) {
    temp := A_ScriptDir . "\tempPSOutput.txt"
    RunWait, powershell.exe -NoProfile -WindowStyle Hidden -Command "%cmd% | Out-File -FilePath '%temp%'", , Hide
    FileRead, out, %temp%
    FileDelete, %temp%
    out := Trim(out)
    StringReplace, out, out, `r`n, , All
}

GetBatteryIconFile(level, themePath) {
    global showOnlyIconNumbers, pToken
    
    ; Round the level
    level := Round(level)
    
    ; Check for battery at 20% or less
    if (level <= 20) {
        global LowBatteryWarningShown, batteryWarningMessageToggleState
        if (!LowBatteryWarningShown && batteryWarningMessageToggleState = "1") {
            LowBatteryWarningShown := true
            ShowLowBatteryWarning(level)
            ; Set a timer to reset the warning after a certain amount
            SetTimer, ResetLowBatteryWarning, -1800000  ; 30 minutes
        }
    }
    
    ; if numbers mode is enabled, use GDI+ generated numeric icons
    if (showOnlyIconNumbers = "1") {
        ; Check if GDI+ has been initialized
        if (!pToken) {
            if (!InitGDIPlus()) {
                ; If GDI+ cannot be initialized, revert to standard icon
                return GetStandardBatteryIcon(level, themePath)
            }
        }
        
        ; Create a HICON and return it as "HICON:handle"
        hIcon := CreateNumberIconHICON(level)
        return "HICON:" . hIcon
    } else {
        ; Standard icon mode
        return GetStandardBatteryIcon(level, themePath)
    }
}

GetStandardBatteryIcon(level, themePath) {
    level := Round(level)
	; Check if the battery is at 20% or less
    if (level <= 20) {
        ; Create a new global variable to avoid repeated messages
        global LowBatteryWarningShown, batteryWarningMessageToggleState
		if (!LowBatteryWarningShown && batteryWarningMessageToggleState = "1") {
			LowBatteryWarningShown := true
			ShowLowBatteryWarning(level)
            ; Set a timer to reset the alert after a certain amount of time
            SetTimer, ResetLowBatteryWarning, -1800000  ; 30 minutes
        }
    }
	
    if (level >= 97) {
        return themePath . "\BT100.ico"
    } else if (level >= 92) {
        return themePath . "\BT95.ico"
    } else if (level >= 87) {
		return themePath . "\BT90.ico"
    } else if (level >= 82) {
		return themePath . "\BT85.ico"
    } else if (level >= 77) {
		return themePath . "\BT80.ico"
    } else if (level >= 72) {
		return themePath . "\BT75.ico"
    } else if (level >= 67) {
		return themePath . "\BT70.ico"
    } else if (level >= 62) {
		return themePath . "\BT65.ico"
    } else if (level >= 57) {
		return themePath . "\BT60.ico"
    } else if (level >= 52) {
		return themePath . "\BT55.ico"
    } else if (level >= 47) {
		return themePath . "\BT50.ico"
    } else if (level >= 42) {
		return themePath . "\BT45.ico"
    } else if (level >= 37) {
		return themePath . "\BT40.ico"
    } else if (level >= 32) {
		return themePath . "\BT35.ico"
    } else if (level >= 27) {
		return themePath . "\BT30.ico"
    } else if (level >= 22) {
		return themePath . "\BT25.ico"
    } else if (level >= 17) {
		return themePath . "\BT20.ico"
    } else if (level >= 12) {
		return themePath . "\BT15.ico"
    } else if (level >= 7) {
		return themePath . "\BT10.ico"
    } else if (level >= 4) {
		return themePath . "\BT5.ico"
    } else if (level >= 2) {
		return themePath . "\BT3.ico"
    } else {
		return themePath . "\BT1.ico"
    }
}

; Initialize GDI+ at program startup (add this where initialization happens)
InitGDIPlus() {
    global pToken
    
    ; Start GDI+
    If !pToken := Gdip_Startup()
    {
        MsgBox, 48, GDI+ Error, GDI+ failed to start. Please ensure you have GDI+ installed.
        return false
    }
    return true
}

; Create a numeric icon using GDI+
CreateNumberIconHICON(percentage) {
    ; Create a bitmap for the icon (32x32 pixels - standard ICO size)
    pBitmap := Gdip_CreateBitmap(32, 32, 0x00000000) ; PixelFormat32bppARGB (transparent background)
    G := Gdip_GraphicsFromImage(pBitmap)
    
    ; Set high quality rendering
    Gdip_SetSmoothingMode(G, 4)
    Gdip_SetTextRenderingHint(G, 4)
    
    ; Create a larger font for the percentage text
    hFamily := Gdip_FontFamilyCreate("Segoe UI")
    
    ; Adjust font size based on the number of digits
    fontSize := (percentage < 10) ? 22 : ((percentage < 100) ? 21 : 18)
    hFont := Gdip_FontCreate(hFamily, fontSize, 1)
    Gdip_DeleteFontFamily(hFamily)
    
    ; Format for centered alignment
    hFormat := Gdip_StringFormatCreate(0x1)
    Gdip_SetStringFormatAlign(hFormat, 1)
    Gdip_SetStringFormatLineAlign(hFormat, 1)
    
    ; Determine text color based on percentage (gradient from green to red)
    red := 255 - (percentage * 2.55)
    green := percentage * 2.55
    textColor := Format("0xFF{:02X}{:02X}FF", Round(red), Round(green))
    
    ; Create a brush for the text
    pBrush := Gdip_BrushCreateSolid(textColor)
    
    ; Text to display the percentage
    percentText := percentage
    
    ; Create a rectangle for text positioning
    VarSetCapacity(RC, 16)
    NumPut(0, RC, 0, "float"), NumPut(0, RC, 4, "float")
    NumPut(32, RC, 8, "float"), NumPut(32, RC, 12, "float")
    Gdip_DrawString(G, percentText, hFont, hFormat, pBrush, RC)
    
    ; Clean up resources
    Gdip_DeleteBrush(pBrush)
    Gdip_DeleteStringFormat(hFormat)
    Gdip_DeleteFont(hFont)
    
    ; Create an HICON from the bitmap
    hIcon := Gdip_CreateHICONFromBitmap(pBitmap)
    
    ; Clean up GDI+ resources
    Gdip_DeleteGraphics(G)
    Gdip_DisposeImage(pBitmap)
    
    ; Return the handle to the icon
    return hIcon
}

; Function to show low battery warning
ShowLowBatteryWarning(level) {	
	global jsonFile

	FileEncoding, UTF-8
    FileRead, jsonContent, %jsonFile%
    config := ParseCustomJSON(jsonContent)
	
    ; Create a custom GUI for the alert with the same style as ShowAllBatteryLevels
    Gui, LowBattery:New
    Gui, LowBattery:+AlwaysOnTop +ToolWindow -Caption +Border
    ; Gui, LowBattery:Color, FFFF00 Yellow ; OLD for Test with background
	Gui, LowBattery:Color, 000000 
    Gui, LowBattery:Font, s16 bold, UI Emoji, Segoe UI 
    
	; Search only Device 1
    for index, device in config {
        if (device.enabled && device.device = 1) {  ; Check if it is Device 1
            batteryLevel := GetBatteryLevel(device.name)
            display := Chr(0x26A0) . " " . device.name " LOW BATTERY: " batteryLevel "%"
            Gui, LowBattery:Add, Text, x10 y10 w400 Center cFF0000, %display%
            
            ; Message to connect the device to the charger
            Gui, LowBattery:Font, s14 bold, Segoe UI
            Gui, LowBattery:Add, Text, x10 y40 w400 Center cFFFF00, Please connect the device to the charger
            
            ; Exit the loop after finding Device 1
            break
        }
    }
	
    ; Add text with proper margins ; OLD Below GUI for testing
    ;Gui, LowBattery:Add, Text, x10 y10 w400 Center cFF0000, ⚠️ LOW BATTERY: %level%`% ⚠️  Experimental Implementation
    ;Gui, LowBattery:Font, s14 bold, Segoe UI
    ;Gui, LowBattery:Add, Text, x10 y40 w400 Center cFFFF00, Please connect the device to the charger
    
    ; Use AutoSize to automatically size the window
    Gui, LowBattery:Show, AutoSize Center, Low Battery Warning
    
    ; Get window handle
    WinGet, hWnd, ID, A
    
    ; Get real GUI size
    WinGetPos, X, Y, Width, Height, ahk_id %hWnd%
    
	/* OLD for testing
    ; Crea regione con angoli arrotondati
    radius := 40  ; Puoi aumentare o diminuire il raggio
    hRgn := DllCall("CreateRoundRectRgn"
        , "Int", 0
        , "Int", 0
        , "Int", Width
        , "Int", Height
        , "Int", radius
        , "Int", radius
        , "Ptr")
    
    ; Applica regione alla finestra
    DllCall("SetWindowRgn", "Ptr", hWnd, "Ptr", hRgn, "Int", true)
	*/
    
    ; OPTION 1: Transparency of the entire window (text and background) for testing
    ; WinSet, Transparent, 100, A  ; Valore da 0 (invisibile) a 255 (opaco), 180 è un buon compromesso
    
    ; OPTION 2: Transparency of the background only (only if you prefer this effect)
    WinSet, TransColor, 000000 255, A  ; The value 255 is the transparency threshold (from 0-255)
    
    ; I set a timer to automatically close the alert
    SetTimer, CloseLowBatteryWarning, -6000  ; Closes after 6 seconds
}


ToggleBatteryMonitor() {
    global batteryToggleState, stateFile
    batteryToggleState := (batteryToggleState = "1") ? "0" : "1"
    FileDelete, %stateFile%
    FileAppend, %batteryToggleState%, %stateFile%
    UpdateTrayMenuIcon()
}

UpdateTrayMenuIcon() {
    global batteryToggleState

    if (batteryToggleState = "1") {
        Menu, Tray, Icon, ON/OFF Battery Monitor ShortKeys, imageres.dll, 229  ; icon for ACTIVE
    } else {
        Menu, Tray, Icon, ON/OFF Battery Monitor ShortKeys, imageres.dll, 231 ; icon for OFF
    }
}

; === FUNCTION: Show or hide the warning ===
ToggleBatteryWarning() {
    global batteryWarningMessageToggleState, stateFileBatteryWarningMessage
    batteryWarningMessageToggleState := (batteryWarningMessageToggleState = "1") ? "0" : "1"
    IniWrite, %batteryWarningMessageToggleState%, %stateFileBatteryWarningMessage%, BatteryWarning, Enabled
    UpdateTrayMenuIconBatteryWarningMessage()
}

; === FUNCTION: Refresh tray menu icon ===
UpdateTrayMenuIconBatteryWarningMessage() {
    global batteryWarningMessageToggleState
    if (batteryWarningMessageToggleState = "1") {
        Menu, Tray, Icon, ON/OFF Low Battery Message Warning, imageres.dll, 229  ; icon for ACTIVE
    } else {
        Menu, Tray, Icon, ON/OFF Low Battery Message Warning, imageres.dll, 231  ; icon for OFF
    }
}

UpdateTrayMenuIconNumbers() {
    global showOnlyIconNumbers
    
    if (showOnlyIconNumbers = "1") {
        Menu, Tray, Icon, ON/OFF Show Only Icon Numbers, imageres.dll, 229  ; icon for ACTIVE
    } else {
        Menu, Tray, Icon, ON/OFF Show Only Icon Numbers, imageres.dll, 231  ; icon for OFF
    }
}

ToggleIconNumbers() {
    global showOnlyIconNumbers, stateFileIconNumbers
    showOnlyIconNumbers := (showOnlyIconNumbers = "1") ? "0" : "1"
    FileDelete, %stateFileIconNumbers%
    FileAppend, %showOnlyIconNumbers%, %stateFileIconNumbers%
    UpdateTrayMenuIconNumbers()
    
    ; Force an immediate icon update to reflect the change
    UpdateBatteryIcon()
}


; Download remote folder list
UrlDownloadToVar(url) {
    HttpObj := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    HttpObj.Open("GET", url)
    HttpObj.Send()
    return HttpObj.ResponseText
}


ShowAllBatteryLevels() {
    global jsonFile
    if (!FileExist(jsonFile)) {
        MsgBox, 16, Error, Missing conf.json file. Cannot show levels.
        return
    }

    FileEncoding, UTF-8
    FileRead, jsonContent, %jsonFile%
    config := ParseCustomJSON(jsonContent)

    Gui, BatteryGUI:New
    Gui, BatteryGUI:+AlwaysOnTop +ToolWindow -Caption +Border
    Gui, BatteryGUI:Color, F9F9F9
    Gui, BatteryGUI:Font, s12 bold, Segoe UI

    Gui, BatteryGUI:Add, Text, x10 y10 w280 Center c007ACC,🔋 Battery Levels
	
	Gui, BatteryGUI:Font, s12 norm, Segoe UI

    yOffset := 40
	yOffsetButton := 110
    foundAny := false
    index := 1

    for index, device in config {
        if (device.enabled) {
            batteryLevel := GetBatteryLevel(device.name)
            display := index ". " device.name ": " batteryLevel "%"
            Gui, BatteryGUI:Add, Text, x20 y%yOffset% w260 Center c333333, %display%
            yOffset += 30
            foundAny := true
        }
    }

    if (!foundAny) {
        Gui, BatteryGUI:Add, Text, x10 y%yOffset% w280 Center cFF0000, No enabled devices found.
        yOffset += 30
    }

    ; Button
    Gui, BatteryGUI:Font, s10 bold, Segoe UI
    Gui, BatteryGUI:Add, Button, x90 y%yOffsetButton%+20 w120 h30 gCloseBatteryGUI, OK
    Gui, BatteryGUI:Show, AutoSize Center, Battery Levels
	
	; ↪ Get window handle
	WinGet, hWnd, ID, A

	; ↪ Get real GUI size
	WinGetPos, X, Y, Width, Height, ahk_id %hWnd%

	; ↪ Create region with rounded corners
	radius := 40  ; Radius
	hRgn := DllCall("CreateRoundRectRgn"
		, "Int", 0
		, "Int", 0
		, "Int", Width
		, "Int", Height
		, "Int", radius
		, "Int", radius
		, "Ptr")

	; ↪ Apply region to window
	DllCall("SetWindowRgn", "Ptr", hWnd, "Ptr", hRgn, "Int", true)
}


InitialUpdate() {
    UpdateBatteryIcon()
}


#Space::
if (batteryToggleState = "1")
    ShowAllBatteryLevels()
return

; Start the timer immediately when the script starts
UpdateBatteryIcon()
return

; Function to close the warning GUI
CloseLowBatteryWarning:
    Gui, LowBattery:Destroy
return

; Function to reset the warning after a while
ResetLowBatteryWarning:
    global LowBatteryWarningShown
    LowBatteryWarningShown := false
return

; Title
TitleLabel:
return


; === DOWNLOAD FUNCTION ===

; This handles downloading individual icons as other tests it doesn't work
DownloadNewIcons:
    IniRead, foldersToDownload, %A_ScriptDir%\BTBatteryWatch.ini, Icons, NewFolders
    ; downloadLog := A_ScriptDir . "\icon_download_log.txt"
    ; FileAppend, `n---- Download Started: %A_Now% ----`n, %downloadLog%
    ; FileAppend, Read from INI: %foldersToDownload%`n, %downloadLog%
    
    if (foldersToDownload = "ERROR" || foldersToDownload = "") {
        MsgBox, 16, Error, No new icon themes to download.
        return
    }
    
    ; Create an array from the folders to download
    folders := StrSplit(foldersToDownload, "|")
    totalFolders := folders.MaxIndex()
    
    ; Debug: elenca tutte le cartelle
    ; FileAppend, Found %totalFolders% folders to download:`n, %downloadLog%
    ; for index, folder in folders {
        ; FileAppend, %index%: %folder%`n, %downloadLog%
    ; }
    
    ; Chiedi conferma
    MsgBox, 4, Download All, Do you want to download all %totalFolders% icon packs at once?
    IfMsgBox, No
        return
        
    ; Crea GUI per progresso
    Gui, Progress:New, +AlwaysOnTop
    Gui, Progress:Add, Text, x10 y10 w300 vProgressText, Preparing downloads...
    Gui, Progress:Add, Progress, x10 y30 w300 h20 vFolderProgress Range0-%totalFolders%, 0
    Gui, Progress:Add, Text, x10 y60 w300 vCurrentFolder, 
    Gui, Progress:Add, Progress, x10 y80 w300 h20 vIconProgress Range0-100, 0
    Gui, Progress:Add, Text, x10 y110 w300 vCurrentIcon,
    Gui, Progress:Show, w320 h140, Downloading Icon Themes
    
    downloadedAny := false
    
    ; Using a numeric loop instead of for-each for greater robustness
    Loop, %totalFolders%
    {
        folderIndex := A_Index
        folderName := folders[A_Index]
        
        ; FileAppend, Processing folder %folderIndex%/%totalFolders%: %folderName%`n, %downloadLog%
        
        GuiControl, Progress:, FolderProgress, %folderIndex%
        GuiControl, Progress:, ProgressText, Folder %folderIndex% of %totalFolders%
        GuiControl, Progress:, CurrentFolder, Current Theme: %folderName%
        GuiControl, Progress:, IconProgress, 0
        GuiControl, Progress:, CurrentIcon, Preparing...
        
        ; Create theme folder
        themeFolder := iconCustomThemePath . folderName . "\"
        if (!FileExist(themeFolder)) {
            FileCreateDir, %themeFolder%
            ; FileAppend, Created directory: %themeFolder%`n, %downloadLog%
        }
        
        ; Get theme contents
        themeUrl := customIconsRepo . "/" . folderName
        ; FileAppend, Downloading theme list: %folderName% from %themeUrl%`n, %downloadLog%
        
        tempThemeJson := A_ScriptDir . "\temp_theme_" . folderName . ".json"
        UrlDownloadToFile, %themeUrl%, %tempThemeJson%
        
        if (ErrorLevel) {
            ; FileAppend, Error downloading theme list for %folderName%`n, %downloadLog%
            continue
        }
        
        FileRead, themeJson, %tempThemeJson%
        FileDelete, %tempThemeJson%
        
        ; Parse JSON more carefully to find icons
        iconCount := 0
        iconFiles := []
        iconUrls := []
        
        ; FileAppend, Scanning theme JSON for %folderName%`n, %downloadLog%
        
        ; More robust regex for icons
        pattern := """name""[ \t]*:[ \t]*""([^""]+\.ico)""(?:[^{}]*?)""download_url""[ \t]*:[ \t]*""([^""]+)"""
        pos := 1
        
        while (pos := RegExMatch(themeJson, pattern, match, pos)) {
            iconName := match1
            iconUrl := match2
            
            ; FileAppend, Found icon: %iconName% at %iconUrl%`n, %downloadLog%
            
            ; Add to download lists
            iconFiles.Push(iconName)
            iconUrls.Push(iconUrl)
            
            ; Advance position
            pos += StrLen(match)
        }
        
        ; Now download all the identified icons
        totalIcons := iconFiles.MaxIndex()
        if (totalIcons > 0) {
            ; FileAppend, Starting download of %totalIcons% icons for %folderName%`n, %downloadLog%
            
            Loop, %totalIcons%
            {
                i := A_Index
                iconName := iconFiles[i]
                iconUrl := iconUrls[i]
                localPath := themeFolder . iconName
                
                ; Calcola percentuale
                iconProgress := Round((i / totalIcons) * 100)
                GuiControl, Progress:, IconProgress, %iconProgress%
                GuiControl, Progress:, CurrentIcon, Icon %i%/%totalIcons%: %iconName%
                
                ; FileAppend, Downloading: %iconName%`n, %downloadLog%
                UrlDownloadToFile, %iconUrl%, %localPath%
                
                if (ErrorLevel) {
                    ; FileAppend, Error downloading %iconName%`n, %downloadLog%
                } else {
                    ; FileAppend, Downloaded: %iconName% -> %folderName%`n, %downloadLog%
                    iconCount++
                }
                
                Sleep, 50  ; Pausa breve
            }
            
            downloadedAny := true
            ; FileAppend, Completed %iconCount% of %totalIcons% icons for theme "%folderName%"`n, %downloadLog%
        } else {
            ; FileAppend, No icons found in theme "%folderName%"`n, %downloadLog%
        }
        
        ; Complete bar for this folder
        GuiControl, Progress:, IconProgress, 100
        GuiControl, Progress:, CurrentIcon, Completed %iconCount% icons
        Sleep, 500
    }
    
    ; Close GUI
    Gui, Progress:Destroy
    
    if (downloadedAny) {
        IniDelete, %A_ScriptDir%\BTBatteryWatch.ini, Icons, NewFolders
        Menu, Tray, Disable, New Custom Icons
        MsgBox, 64, Download Complete, All icon themes have been downloaded successfully!
    } else {
        MsgBox, 48, Download Failed, No icons were downloaded. Check the log for details.
    }
return

OpenProjectSite() {
    Run, https://github.com/Special-Niewbie/BTBatteryWatch
}

OpenDonationSite() {
	global

	imagePath := A_ScriptDir . "\asset\QRProject.png"

	if !FileExist(imagePath) {
		MsgBox, 16, Error, QR image not found at:`n%imagePath%
		return
	}

	; Window
	Gui, DonationQR:New
	Gui, DonationQR:+AlwaysOnTop +ToolWindow -Caption +Border
	Gui, DonationQR:Color, Black
	Gui, DonationQR:Font, s12 Bold, Segoe UI

	; Title
	Gui, DonationQR:Add, Text, x5 y10 w440 Center cWhite, Support the project with a donation!

	; Immagine (416x561)
	Gui, DonationQR:Add, Picture, x12 y40 w416 h561, %imagePath%

	; Buttons Y position
	btnY := 615

	; Button "Close" left
	Gui, DonationQR:Add, Button, x50 y%btnY% w120 h30 gCloseDonationQR, Close

	; Button "Open PayPal Link" right
	Gui, DonationQR:Add, Button, x230 y%btnY% w160 h30 gOpenPayPalLink, Open PayPal Link

	; Show Window
	Gui, DonationQR:Show, w440 h660 Center, PayPal Donation
}

OpenPayPalLink:
	Run, https://www.paypal.com/ncp/payment/WYU4A2HTRTVHG
return

CloseDonationQR:
	Gui, DonationQR:Destroy
return

; Function to open the settings window
OpenSettings:
    Run, %A_ScriptDir%\conf.exe 
return

ReloadScript:
    Reload
return


CheckForUpdates() {
	global updateCheckPerformed
	
	; Only check once per session
    if (updateCheckPerformed)
        return
    
    updateCheckPerformed := true
	
    localVersionFile := A_ScriptDir . "\version"
    if (!FileExist(localVersionFile)) {
        MsgBox, 16, Error, The version file was not found.
        ExitApp
    }
    FileRead, localVersion, %localVersionFile%
    localVersion := Trim(localVersion)
    versionUrl := "https://raw.githubusercontent.com/Special-Niewbie/BTBatteryWatch/main/version"
    latestVersionFile := A_ScriptDir . "\latest_version"
    
    ; Download the latest version file
    UrlDownloadToFile, %versionUrl%, %latestVersionFile%
    ; Checks whether the latest version file exists and contains valid data
    if (FileExist(latestVersionFile)) {
        FileRead, latestVersion, %latestVersionFile%
        latestVersion := Trim(latestVersion)
        FileDelete, %latestVersionFile%
        ; Check if the downloaded content is not an HTTP error (ex. 404: Not Found)
        if (InStr(latestVersion, "404: Not Found") = 0 && localVersion != latestVersion) {
            MsgBox, 4, Update Available, A new version is available: %latestVersion%`n`nYou are currently using version: %localVersion%`n`nWould you like to download the latest version?
            ifMsgBox, Yes
            {
                ; GitHub API to get latest release info
                apiUrl := "https://api.github.com/repos/Special-Niewbie/BTBatteryWatch/releases/latest"
                jsonFile := A_Temp . "\github_release.json"
                
                ; Set up a MSXML2.XMLHTTP object for API request
                whr := ComObjCreate("MSXML2.XMLHTTP")
                whr.Open("GET", apiUrl, false)
                whr.SetRequestHeader("User-Agent", "AutoHotkey Update Checker")
                whr.Send()
                
                ; Save response to file
                FileDelete, %jsonFile%
                FileAppend, % whr.ResponseText, %jsonFile%
                FileRead, jsonContent, %jsonFile%
                FileDelete, %jsonFile%
                
                ; Parse JSON to find setup file
                setupFileUrl := ""
                
                ; Look for assets section
                if (RegExMatch(jsonContent, "U)""assets"":\s*\[(.*)\]", assets)) {
                    ; Find the BTBatteryWatchsetup file in assets
                    RegExMatch(jsonContent, "U)""browser_download_url"":\s*""([^""]*BTBatteryWatchsetup[^""]*\.exe)""", fileUrlMatch)
                    if (fileUrlMatch1) {
                        setupFileUrl := fileUrlMatch1
                        SplitPath, setupFileUrl, setupFileName
                        
                        ; Ask user where to save the file
                        FileSelectFile, downloadPath, S16, %setupFileName%, Save Update File, Executable Files (*.exe)
                        if (downloadPath != "") {
                            ; Show download progress
                            Progress, B W200, Downloading update..., Please wait
                            
                            ; Download the file
                            UrlDownloadToFile, %setupFileUrl%, %downloadPath%
                            
                            ; Close progress window
                            Progress, Off
                            
                            ; Check if download was successful
                            if (FileExist(downloadPath)) {
                                MsgBox, 4, Download Complete, Update has been successfully downloaded to:`n%downloadPath%`n`nDo you want to exit BTBatteryWatch to install the update?
								IfMsgBox, Yes
								{
									ExitApp
								}
                            } else {
                                MsgBox, 16, Download Failed, Failed to download the update. Please try again or visit the GitHub page manually.
                            }
                        }
                    } else {
                        MsgBox, 16, Error, Could not find the BTBatteryWatchsetup file in the latest release.
                        Run, https://github.com/Special-Niewbie/BTBatteryWatch/releases
                    }
                } else {
                    MsgBox, 16, Error, Could not parse the release information.
                    Run, https://github.com/Special-Niewbie/BTBatteryWatch/releases
                }
            }
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

CloseBatteryGUI:
    Gui, BatteryGUI:Destroy
return

ExitApp:
    ; Close all compiled incubator scripts (exe) first
    Loop, 4 {
        if (A_Index > 1) {  ; Skip Device1 which is handled directly in the main script
            exeName := "Device" . A_Index . ".exe"
            
            ; Check if the process is running
            Process, Exist, %exeName%
            if (ErrorLevel) {
                ; If it's running, get the PID
                pid := ErrorLevel
                ; Finish the process
                Process, Close, %pid%
                ; Log dell'operazione (opzionale)
                ; FileAppend, % "Chiuso processo: " . exeName . " (PID: " . pid . ")`n", %A_ScriptDir%\exit_log.txt DEBUG
            } else {
                ; Log se il processo non è stato trovato (opzionale)
                ; FileAppend, % "Processo non trovato: " . exeName . "`n", %A_ScriptDir%\exit_log.txt DEBUG
            }
        }
    }
	
	; Chiudi GDI+ se è stato inizializzato
    global pToken
    if (pToken)
        Gdip_Shutdown(pToken)
    
    ; Short delay to ensure processes are terminated
    Sleep, 500

    ExitApp
