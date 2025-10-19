# ============================================================================
# Script de détection alternatif FortiClient VPN 7.4.3.1790
# Auteur: ctrlaltnod.com
# Date: 19 octobre 2025
# Version: 1.0
# Description: Détection basée sur le registre (plus rapide)
# ============================================================================

# Version requise
$RequiredVersion = "7.4.3.1790"

# Chemins de registre à vérifier
$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$FortiClientFound = $false

ForEach ($Path in $UninstallPaths) {
    Try {
        $Apps = Get-ItemProperty $Path -ErrorAction SilentlyContinue
        
        ForEach ($App in $Apps) {
            If ($App.DisplayName -like "*FortiClient*VPN*") {
                $InstalledVersion = $App.DisplayVersion
                
                # Comparaison de version
                If ([Version]$InstalledVersion -ge [Version]$RequiredVersion) {
                    Write-Host "FortiClient VPN détecté via registre: $($App.DisplayName)"
                    Write-Host "Version: $InstalledVersion (Conforme)"
                    $FortiClientFound = $true
                    Exit 0
                }
                Else {
                    Write-Host "FortiClient VPN détecté mais version obsolète: $InstalledVersion"
                    Exit 1
                }
            }
        }
    }
    Catch {
        Continue
    }
}

If (-Not $FortiClientFound) {
    Write-Host "FortiClient VPN non détecté dans le registre"
    Exit 1
}
