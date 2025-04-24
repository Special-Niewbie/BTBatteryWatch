param (
    [string]$DeviceName = $null
)

# Se non è stato fornito un nome dispositivo come parametro, prova a leggere dal conf.json
if ([string]::IsNullOrEmpty($DeviceName)) {
    $JsonPath = ".\conf.json"
    if (Test-Path $JsonPath) {
        try {
            $jsonContent = Get-Content -Path $JsonPath -Raw
            
            # Estrai il nome del dispositivo dal JSON (device 2)
            if ($jsonContent -match '"device":\s*"3"[^{]*"name":\s*"([^"]*?)"') {
                $DeviceName = $matches[1]
            }
            
            if ([string]::IsNullOrEmpty($DeviceName)) {
                Write-Host "Disconnected"
                $Connected = $false
            }
        }
        catch {
            Write-Host "Disconnected"
            $Connected = $false
        }
    } else {
        Write-Host "Disconnected"
        $Connected = $false
    }
}

# Debug output
Write-Host "Cercando dispositivo: $DeviceName" -ForegroundColor Yellow

# Controlla se il dispositivo Bluetooth è connesso
$BTDevice = Get-PnpDevice -FriendlyName "*$($DeviceName)*" -ErrorAction SilentlyContinue
$Connected = $false

if ($BTDevice) {
    foreach ($Device in $BTDevice) {
        # Debug output
        Write-Host "Dispositivo trovato: $($Device.FriendlyName), ID: $($Device.InstanceId)" -ForegroundColor Cyan
        
        try {
            $ConnectionProperty = Get-PnpDeviceProperty -InstanceId $Device.InstanceId -KeyName '{83DA6326-97A6-4088-9453-A1923F573B29} 15' -ErrorAction SilentlyContinue |
                Where-Object { $_.Type -ne 'Empty' } |
                Select-Object -ExpandProperty Data -ErrorAction SilentlyContinue
            
            Write-Host "Stato connessione: $ConnectionProperty" -ForegroundColor Cyan
            
            if ($ConnectionProperty -eq $true) {
                $Connected = $true
                break
            }
        }
        catch {
            Write-Host "Errore lettura proprietà: $_" -ForegroundColor Red
        }
    }

    if ($Connected) {
        Write-Host "Connected"
    }
    else {
        Write-Host "Disconnected"
    }
}
else {
    Write-Host "Nessun dispositivo Bluetooth trovato con nome: $DeviceName" -ForegroundColor Red
    Write-Host "Disconnected"
}

# Salva l'output in un file temporaneo
$outputPath = Join-Path -Path $PSScriptRoot -ChildPath "tempPSOutput_Connected_3.txt"
$output = if ($Connected) { "Connected" } else { "Disconnected" }
Out-File -FilePath $outputPath -InputObject $output