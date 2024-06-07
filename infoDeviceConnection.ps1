# Leggi il nome del dispositivo dal file config.ini
$ConfigPath = ".\config.ini"
$DeviceName = (Get-Content -Path $ConfigPath | Select-String -Pattern "DeviceName").ToString().Split("=")[1].Trim()

# Controlla se il dispositivo Bluetooth è connesso
$BTDevice = Get-PnpDevice -FriendlyName "*$($DeviceName)*"

if ($BTDevice) {
    $Connected = $false
    foreach ($Device in $BTDevice) {
        $ConnectionProperty = Get-PnpDeviceProperty -InstanceId $Device.InstanceId -KeyName '{83DA6326-97A6-4088-9453-A1923F573B29} 15' |
            Where-Object { $_.Type -ne 'Empty' } |
            Select-Object -ExpandProperty Data

        if ($ConnectionProperty -eq $true) {
            $Connected = $true
            break
        }
    }

    if ($Connected) {
        Write-Output "Connected"
        # Qui puoi fare quello che vuoi fare se il dispositivo è connesso
    }
    else {
        Write-Output "Disconnected"
    }
}
else {
    Write-Output "Bluetooth device not found."
}

# Salva l'output in un file
Out-File -FilePath "tempPSOutput_Connected.txt" -InputObject $Connected
