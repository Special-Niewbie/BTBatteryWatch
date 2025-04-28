/*
BTBatteryWatch Incubator - Device 2

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
#SingleInstance Force
SendMode Input
SetWorkingDir %A_ScriptDir%\..
#Include %A_ScriptDir%\..\libs\Gdip_All.ahk

global deviceNumber := 2  ; <-- variable for every DeviceX.ahk
stateFileBatteryWarningMessage := A_ScriptDir . "\LowBatterySettings_2"
global connectionCheckStartTime := A_TickCount
global deviceConnectionChecks := {}

; Number Variables
global showOnlyIconNumbers := 0
global stateFileIconNumbers := A_ScriptDir . "\ShowNumbersState_2"

settingsFile := A_WorkingDir . "\conf.json"
FileEncoding, UTF-8
FileRead, jsonText, %settingsFile%
if (!jsonText) {
    MsgBox, 16, Error, Failed to read conf.json
    ExitApp
}

; Check if BTBatteryWatch.exe is running
Sleep, 2000 ; wait 2 secondi (2000 ms)
Process, Exist, BTBatteryWatch.exe
if (!ErrorLevel) {
    MsgBox, 16, Warning, BTBatteryWatch.exe is not running. Device2.exe will be closed.
    ExitApp
}

; If the file does not exist, it creates it and sets "Enabled=1" by default
if (!FileExist(stateFileBatteryWarningMessage)) {
    IniWrite, 1, %stateFileBatteryWarningMessage%, BatteryWarning, Enabled
}

; If the file does not exist, create it with the default setting of 0 (disabled)
if (!FileExist(stateFileIconNumbers))
    FileAppend, 0, %stateFileIconNumbers%

; Read the initial state from the file that deals with the numbered icons
FileRead, showOnlyIconNumbers, %stateFileIconNumbers%
showOnlyIconNumbers := Trim(showOnlyIconNumbers)

; Read initial state from RAW file
IniRead, batteryWarningMessageToggleState, %stateFileBatteryWarningMessage%, BatteryWarning, Enabled, 1

; --- Custom function to read only the specified device ---
GetDeviceFromJSON(jsonContent, deviceNumber) {
    devicePattern := "i)""device"":\s*""(" . deviceNumber . ")""[^{]*""name"":\s*""([^""]*?)""[^{]*""iconTheme"":\s*""([^""]*?)""[^{]*""enabled"":\s*(true|false)"
    
    if RegExMatch(jsonContent, devicePattern, match) {
        device := {}
        device.device := deviceNumber
        device.name := match2
        device.iconTheme := match3
        device.enabled := (match4 = "true")
        return device
    } else {
        return ""
    }
}

; --- Retrieve only the specified device ---
device := GetDeviceFromJSON(jsonText, deviceNumber)

if (!IsObject(device) || !device.name || !device.iconTheme) {
    MsgBox, 16, Error, Device data not found or incomplete for device %deviceNumber%
    ExitApp
}

deviceName := device.name
global monitoredDevice := device.name
iconTheme := device.iconTheme
iconThemePath := A_WorkingDir . "\icons\" . iconTheme

; Debug
; MsgBox, deviceName: %deviceName%`niconTheme: %iconTheme%

iconDisconnectedPath := A_WorkingDir . "\icons\"

; Setup the tray icon and menu
Menu, Tray, NoStandard
Menu, Tray, Add, 👉 >>> Device 2 Menu <<<, TitleLabel
Menu, Tray, Icon, 👉 >>> Device 2 Menu <<<, % A_WorkingDir . "\asset\bt_batterywatch.ico"
Menu, Tray, Disable, 👉 >>> Device 2 Menu <<<

Menu, Tray, Add, , Separator
Menu, Tray, Add, , Separator
Menu, Tray, Add, Settings, OpenSettings
Menu, Tray, Icon, Settings, % A_WorkingDir . "\asset\settings.ico"
Menu, Tray, Add, , Separator
Menu, Tray, Add, Project Site, OpenProjectSite
Menu, Tray, Icon, Project Site, % A_WorkingDir . "\asset\github.ico"
Menu, Tray, Add, Donate, OpenDonationSite
Menu, Tray, Icon, Donate, % A_WorkingDir . "\asset\donate.ico"
Menu, Tray, Add, , Separator
Menu, Tray, Tip, %deviceName% - Battery Monitor
Menu, Tray, Add, Show Battery Level, ShowBatteryLevel
Menu, Tray, Icon, Show Battery Level, % A_WorkingDir . "\asset\battery.ico"
Menu, Tray, Add, , Separator
Menu, Tray, Add, ON/OFF Low Battery Message Warning, ToggleBatteryWarning
Menu, Tray, Add, ON/OFF Show Only Icon Numbers, ToggleIconNumbers
Menu, Tray, Add, Exit, ExitApp

; Initialize the device connection checks
deviceConnectionChecks[deviceNumber] := {name: deviceName, lastCheck: 0, connected: false}

; Set timer for battery icon updates
SetTimer, UpdateBatteryIcon, 600000  ; Check every 10 minutes
SetTimer, InitialUpdate, -3000  ; Initial update after 3 seconds

; Set timer for frequent connection checking (during the first 3 minutes)
SetTimer, CheckPendingConnections, 30000  ; Check every 30 seconds

UpdateTrayMenuIconBatteryWarningMessage()
UpdateTrayMenuIconNumbers()


UpdateBatteryIcon() {
    global monitoredDevice, iconThemePath, iconDisconnectedPath, deviceNumber
    isConnected := IsDeviceConnected(monitoredDevice, deviceNumber)
    if (!isConnected) {
        Menu, Tray, Icon, %iconDisconnectedPath%\BTdisco.ico
        Menu, Tray, Tip, %monitoredDevice% - Not connected
        return
    }
    level := GetBatteryLevel(monitoredDevice, deviceNumber)
    iconFile := GetBatteryIconFile(level, iconThemePath)
    
    ; Check if we are using a direct HICON
    if (SubStr(iconFile, 1, 6) = "HICON:") {
        Menu, Tray, Icon, %iconFile%
        
        ; Important: destroy the icon AFTER it has been set
        hIcon := SubStr(iconFile, 7)
        SetTimer, DestroyIconTimer, -100  ; Destroy the icon after a short delay
    }
    else {
        Menu, Tray, Icon, %iconFile%
    }
    
    Menu, Tray, Tip, %monitoredDevice% - Battery: %level%`%
}

; Timer to safely destroy the icon
DestroyIconTimer:
    global lastIconHandle
    if (lastIconHandle) {
        DestroyIcon(lastIconHandle)
        lastIconHandle := 0
    }
return

CheckPendingConnections() {
    global connectionCheckStartTime, deviceConnectionChecks, deviceNumber, deviceName
    
    ; Check if more than 3 minutes (180000 ms) have passed since startup
    elapsedTime := A_TickCount - connectionCheckStartTime
    if (elapsedTime > 180000) {
        ; Disable this timer after 3 minutes
        SetTimer, CheckPendingConnections, Off
        return
    }
    
    ; Check if our device is connected now
    if (!deviceConnectionChecks[deviceNumber].connected) {
        isConnected := IsDeviceConnected(deviceName, deviceNumber)
        
        if (isConnected) {
            ; Device connected, update status
            deviceConnectionChecks[deviceNumber].connected := true
            UpdateBatteryIcon()  ; Update icon immediately
            
            ; If device is connected, we can disable the timer
            SetTimer, CheckPendingConnections, Off
        }
    }
}

IsDeviceConnected(name, deviceNumber) {
	global deviceConnectionChecks
	
    ps1 := A_WorkingDir . "\Device" . deviceNumber . ".ps1"
    if (!FileExist(ps1)) {
        MsgBox, 16, Error, Missing Device%deviceNumber%.ps1
        ExitApp
    }
    
    ; Debug log
    ;logFile := A_WorkingDir . "\device" . deviceNumber . "_connection_log.txt"
    ;FileAppend, % "Checking connection for: " . name . "`n", %logFile%
    
    temp := A_WorkingDir . "\tempPSOutput_Connected_" . deviceNumber . ".txt"
    
    ; Full debug command
    cmdLine := "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ . ps1 . """ """ . name . """"
    ;FileAppend, % "Command: " . cmdLine . "`n", %logFile%
    
    ; Executing the command
    RunWait, %cmdLine%, , Hide
    Sleep, 1000
    
    if (!FileExist(temp)) {
        ;FileAppend, "Output file not created!`n", %logFile%
        return false
    }
    
    FileRead, status, %temp%
    FileDelete, %temp%
    
    status := Trim(status)
    ;FileAppend, % "Status output: " . status . "`n", %logFile%
	
	isConnected := (status = "Connected" || InStr(status, "Connected") > 0 && !InStr(status, "Disconnected"))
    
    ; Update connection status in our tracking dictionary
    if (deviceConnectionChecks.HasKey(deviceNumber)) {
        deviceConnectionChecks[deviceNumber].connected := isConnected
    }
    
    return isConnected
}

GetBatteryLevel(name, deviceNumber) {
    PowerShellCommand := "
	(
	$BatteryLevel = (Get-PnpDevice -FriendlyName '*" . name . "*' | ForEach-Object { Get-PnpDeviceProperty -InstanceId $_.InstanceId -KeyName '{104EA319-6EE2-4701-BD47-8DDBF425BBE5} 2' | Where-Object { $_.Type -ne 'Empty' } | Select-Object -ExpandProperty Data })
	$BatteryLevel -join ''
    )"
    RunPowerShell(PowerShellCommand, output)
    return output
}

RunPowerShell(cmd, ByRef out) {
    temp := A_WorkingDir . "\tempPSOutput_" . deviceNumber . ".txt"
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
            ; Set a timer to reset the warning after a certain period
            SetTimer, ResetLowBatteryWarning, -1800000  ; 30 minutes
        }
    }
    
    ; If numeric mode is active, use number icons generated with GDI+
    if (showOnlyIconNumbers = "1") {
        ; Verify that GDI+ has been initialized
        if (!pToken) {
            if (!InitGDIPlus()) {
                ; If GDI+ cannot be initialized, fallback to standard icon
                return GetStandardBatteryIcon(level, themePath)
            }
        }
        
        ; Create an HICON and return it as "HICON:handle"
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
    ; Create a bitmap for the icon (32x32 pixels - standard size for ICO)
    pBitmap := Gdip_CreateBitmap(32, 32, 0x00000000) ; PixelFormat32bppARGB (transparent background)
    G := Gdip_GraphicsFromImage(pBitmap)
    
    ; Set high quality rendering
    Gdip_SetSmoothingMode(G, 4)
    Gdip_SetTextRenderingHint(G, 4)
    
    ; Create a larger font for the percentage text
    hFamily := Gdip_FontFamilyCreate("Segoe UI")
    
    ; Adjust the font size based on the number of digits
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
    
    ; Return the handle of the icon
    return hIcon
}

; Function to show low battery warning
ShowLowBatteryWarning(level) {
	global device, deviceNumber
	Sleep, 7000
	
    ; Custom GUI for the alert with the same style as ShowAllBatteryLevels
    Gui, LowBattery:New
    Gui, LowBattery:+AlwaysOnTop +ToolWindow -Caption +Border
    ; Gui, LowBattery:Color, FFFF00 Yellow ; OLD for Test with background
	Gui, LowBattery:Color, 000000 
    Gui, LowBattery:Font, s16 bold, UI Emoji, Segoe UI
    
	; I add the warning text directly (no loop needed like Device1)
    batteryLevel := GetBatteryLevel(device.name, deviceNumber)
    display := Chr(0x26A0) . " " . device.name " LOW BATTERY: " batteryLevel "%"
    Gui, LowBattery:Add, Text, x10 y10 w400 Center cFF0000, %display%
    
    ; Message to connect to charger
    Gui, LowBattery:Font, s14 bold, Segoe UI
    Gui, LowBattery:Add, Text, x10 y40 w400 Center cFFFF00, Please connect the device to the charger
	
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
    
	/*
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

ShowBatteryLevel(){
    global settingsFile, deviceNumber, device
    batteryLevel := GetBatteryLevel(device.name, device.device)
	
    tip := % device.name ": " batteryLevel "%"
    TrayTip, % "Device " device.device, %tip%

    Sleep, 3000
    ; Hide the traytip after 3 seconds
    TrayTip
}

OpenProjectSite() {
    Run, https://github.com/Special-Niewbie/BTBatteryWatch
}

OpenDonationSite() {
	global

	imagePath := A_WorkingDir . "\asset\QRProject.png"

	if !FileExist(imagePath) {
		MsgBox, 16, Error, QR image not found at:`n%imagePath%
		return
	}

	; GUI
	Gui, DonationQR:New
	Gui, DonationQR:+AlwaysOnTop +ToolWindow -Caption +Border
	Gui, DonationQR:Color, Black
	Gui, DonationQR:Font, s12 Bold, Segoe UI

	; Header text
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
        Menu, Tray, Icon, ON/OFF Low Battery Message Warning, imageres.dll, 229  ; ACTIVE icon
    } else {
        Menu, Tray, Icon, ON/OFF Low Battery Message Warning, imageres.dll, 231  ; OFF icon
    }
}

UpdateTrayMenuIconNumbers() {
    global showOnlyIconNumbers
    
    if (showOnlyIconNumbers = "1") {
        Menu, Tray, Icon, ON/OFF Show Only Icon Numbers, imageres.dll, 229  ; ACTIVE icon
    } else {
        Menu, Tray, Icon, ON/OFF Show Only Icon Numbers, imageres.dll, 231  ; OFF icon
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

TitleLabel:
return

InitialUpdate:
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

OpenPayPalLink:
	Run, https://www.paypal.com/ncp/payment/WYU4A2HTRTVHG
return

CloseDonationQR:
	Gui, DonationQR:Destroy
return

OpenSettings:
    Run, %A_WorkingDir%\conf.exe
return

ExitApp:
    ExitApp
return
