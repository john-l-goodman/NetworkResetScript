"Script started at $(Get-Date)" | Out-File -FilePath "C:\Scripts\DebugLog.txt" -Append
$adapterName = (Get-NetAdapter | Where-Object {$_.Status -eq "Up"} | Select-Object -First 1).Name
$logFile = "C:\Scripts\ResetLog.txt"
Clear-Content -Path $logFile


$maxRetries = 3
$retryDelay = 5  # seconds
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Adapter detected: $adapterName" | Out-File -FilePath $logFile -Append
# Log the wake event
"[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Reset triggered after wake" | Out-File -FilePath $logFile -Append

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
    try {
        if (-not $adapterName) {
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] No active adapter found. Skipping reset." | Out-File -FilePath $logFile -Append
            return
        }
        Disable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 3
        Enable-NetAdapter -Name $adapterName -Confirm:$false -ErrorAction Stop
        Start-Sleep -Seconds 5
# Wait up to 30 seconds for adapter to get a valid IP
$maxWait = 30
$elapsed = 0
while ($elapsed -lt $maxWait) {
    $ip = (Get-NetIPAddress -InterfaceAlias $adapterName -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object {$_.IPAddress -ne "169.254.0.0"}).IPAddress
    if ($ip) {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Adapter has IP: $ip" | Out-File -FilePath $logFile -Append
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
}

if (-not $ip) {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Adapter failed to acquire IP after $maxWait seconds." | Out-File -FilePath $logFile -Append
}
if (Test-Connection -ComputerName 192.168.12.1 -Count 2 -Quiet) {
    "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Attempt ${attempt}: Network check SUCCESS" | Out-File -FilePath $logFile -Append

    # Play success sound
    $player = New-Object System.Media.SoundPlayer "C:\Scripts\Sounds\Windows Logon.wav"
    $player.Play()

    break
} else {
    throw "Ping failed"
}
    } catch {
        "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Attempt ${attempt}: FAILED - $_" | Out-File -FilePath $logFile -Append
        if ($attempt -lt $maxRetries) {
            Start-Sleep -Seconds $retryDelay
        } else {
            "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] All $maxRetries attempts failed." | Out-File -FilePath $logFile -Append
        }
    }
}