# ============================================================================
# Script d'installation FortiClient VPN 7.4.3.1790 pour Microsoft Intune
# Auteur: ctrlaltnod.com
# Date: 19 octobre 2025
# Version: 1.1
# Description: Installation silencieuse de FortiClient VPN avec configuration
#              du profil VPN via les clés de registre
# ============================================================================

# -------------------------------
# Redémarrage en PowerShell 64-bit si nécessaire
# -------------------------------
if ($ENV:PROCESSOR_ARCHITEW6432) {
    Write-Host "Redémarrage du script en PowerShell 64-bit..."
    &"$ENV:WINDIR\SysNative\WindowsPowerShell\v1.0\PowerShell.exe" -ExecutionPolicy Bypass -NoProfile -File $PSCommandPath
    Exit
}

# -------------------------------
# Journalisation
# -------------------------------
$LogPath = "C:\Windows\Temp\FortiClientVPN_Install.log"
function Write-Log {
    param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogPath -Append
    Write-Host $Message
}

Write-Log "=========================================="
Write-Log "Début de l'installation de FortiClient VPN 7.4.3.1790"
Write-Log "=========================================="

# -------------------------------
# SECTION 1: Chemin absolu du MSI
# -------------------------------
$ScriptDir = Split-Path -Parent $PSCommandPath
$MsiPath = Join-Path $ScriptDir "FortiClientVPN.msi"

if (-Not (Test-Path $MsiPath)) {
    Write-Log "ERREUR: Le fichier MSI est introuvable: $MsiPath"
    Exit 1
}

Write-Log "Fichier MSI trouvé: $MsiPath"

# -------------------------------
# SECTION 2: Installation silencieuse du MSI
# -------------------------------
$MsiArguments = "/i `"$MsiPath`" /qn /norestart REBOOT=ReallySuppress /L*v `"C:\Windows\Temp\FortiClientVPN_MSI_Install.log`""

Write-Log "Lancement de l'installation MSI..."
try {
    $InstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $MsiArguments -Wait -PassThru -NoNewWindow
    switch ($InstallProcess.ExitCode) {
        0 { Write-Log "Installation MSI terminée avec succès (Code 0)" }
        3010 { Write-Log "Installation MSI terminée avec succès, redémarrage requis (Code 3010)" }
        default { 
            Write-Log "ERREUR: Installation échouée avec le code: $($InstallProcess.ExitCode)"
            Exit $InstallProcess.ExitCode
        }
    }
}
catch {
    Write-Log "ERREUR lors de l'installation: $($_.Exception.Message)"
    Exit 1
}

Start-Sleep -Seconds 10

# -------------------------------
# SECTION 3: Configuration du profil VPN
# -------------------------------
Write-Log "Début de la configuration du profil VPN..."

$VpnProfileName = "CTRLALTNOD"
$VpnDescription = "Connexion VPN pour ctrlaltnod"
$VpnServerAddress = "vpn.votreentreprise.com:4443"

$RegistryBasePath = "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn"
$VpnTunnelPath = "$RegistryBasePath\Tunnels\$VpnProfileName"

try {
    if (-Not (Test-Path $RegistryBasePath)) { New-Item -Path $RegistryBasePath -Force | Out-Null }
    if (-Not (Test-Path "$RegistryBasePath\Tunnels")) { New-Item -Path "$RegistryBasePath\Tunnels" -Force | Out-Null }
    if (-Not (Test-Path $VpnTunnelPath)) { New-Item -Path $VpnTunnelPath -Force | Out-Null }

    New-ItemProperty -Path $VpnTunnelPath -Name "Description" -Value $VpnDescription -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $VpnTunnelPath -Name "Server" -Value $VpnServerAddress -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $VpnTunnelPath -Name "promptusername" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $VpnTunnelPath -Name "promptpassword" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $VpnTunnelPath -Name "promptcertificate" -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $VpnTunnelPath -Name "ServerCert" -Value "1" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $VpnTunnelPath -Name "warn_invalid_server_cert" -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $VpnTunnelPath -Name "keep_alive" -Value 1 -PropertyType DWord -Force | Out-Null

    Write-Log "Profil VPN configuré avec succès: $VpnTunnelPath"
}
catch {
    Write-Log "ERREUR lors de la configuration du registre: $($_.Exception.Message)"
    Exit 1
}

# -------------------------------
# SECTION 4: Suppression du disclaimer
# -------------------------------
$FortiClientVersion = "7.4.3.1790"
$DisclaimerPath = "HKLM:\SOFTWARE\Fortinet\FortiClient\FA_UI"

try {
    if (-Not (Test-Path $DisclaimerPath)) { New-Item -Path $DisclaimerPath -Force | Out-Null }
    New-ItemProperty -Path $DisclaimerPath -Name "DisclaimerAccepted_$FortiClientVersion" -Value 1 -PropertyType DWord -Force | Out-Null
    Write-Log "Disclaimer automatiquement accepté pour la version $FortiClientVersion"
}
catch {
    Write-Log "AVERTISSEMENT: Impossible de configurer le disclaimer: $($_.Exception.Message)"
}

# -------------------------------
# SECTION 5: Vérification finale
# -------------------------------
$FortiClientExe = "$Env:ProgramFiles\Fortinet\FortiClient\FortiClient.exe"

if (Test-Path $FortiClientExe) {
    $FileVersion = (Get-Item $FortiClientExe).VersionInfo.FileVersion
    Write-Log "FortiClient.exe trouvé, version: $FileVersion"
} else {
    Write-Log "ERREUR: FortiClient.exe introuvable!"
    Exit 1
}

if (Test-Path $VpnTunnelPath) {
    Write-Log "Profil VPN '$VpnProfileName' présent dans le registre."
} else {
    Write-Log "ERREUR: Profil VPN non créé."
    Exit 1
}

Write-Log "=========================================="
Write-Log "Installation et configuration terminées avec succès!"
Write-Log "=========================================="
Exit 0
