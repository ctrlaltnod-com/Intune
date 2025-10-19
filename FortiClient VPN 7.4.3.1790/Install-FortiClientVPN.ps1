# ============================================================================
# Script d'installation FortiClient VPN 7.4.3.1790 pour Microsoft Intune
# Auteur: ctrlaltnod.com
# Date: 19 octobre 2025
# Version: 1.0
# Description: Installation silencieuse de FortiClient VPN avec configuration
#              du profil VPN via les clés de registre
# ============================================================================

# Vérification et redémarrage en PowerShell 64-bit si nécessaire
# Cette section est CRITIQUE pour que les clés de registre soient créées
# au bon endroit (HKLM:\SOFTWARE au lieu de WOW6432Node)
If ($ENV:PROCESSOR_ARCHITEW6432 -eq "AMD64") {
    Try {
        &"$ENV:WINDIR\SysNative\WindowsPowershell\v1.0\PowerShell.exe" -File $PSCOMMANDPATH
    }
    Catch {
        Throw "Échec du redémarrage du script en mode 64-bit: $($_.Exception.Message)"
    }
    Exit
}

# Journalisation
$LogPath = "C:\Windows\Temp\FortiClientVPN_Install.log"
Function Write-Log {
    Param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogPath -Append
    Write-Host $Message
}

Write-Log "=========================================="
Write-Log "Début de l'installation de FortiClient VPN 7.4.3.1790"
Write-Log "=========================================="

# ============================================================================
# SECTION 1: INSTALLATION DE FORTICLIENT VPN
# ============================================================================

# Chemin du fichier MSI (doit être dans le même dossier que ce script)
$MsiPath = ".\FortiClientVPN.msi"

# Vérification de la présence du fichier MSI
If (-Not (Test-Path $MsiPath)) {
    Write-Log "ERREUR: Le fichier FortiClientVPN.msi est introuvable dans le dossier du script."
    Exit 1
}

Write-Log "Fichier MSI trouvé: $MsiPath"

# Installation silencieuse du MSI FortiClient VPN
# Paramètres:
# /i           = Installation
# /qn          = Mode silencieux complet (pas d'interface)
# /norestart   = Pas de redémarrage automatique
# REBOOT=ReallySuppress = Suppression du redémarrage (doublon de sécurité)

Write-Log "Lancement de l'installation MSI..."

$MsiArguments = @(
    "/i"
    "`"$MsiPath`""
    "/qn"
    "/norestart"
    "REBOOT=ReallySuppress"
    "/L*v"
    "C:\Windows\Temp\FortiClientVPN_MSI_Install.log"
)

Try {
    $InstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $MsiArguments -Wait -PassThru -NoNewWindow
    
    If ($InstallProcess.ExitCode -eq 0) {
        Write-Log "Installation MSI terminée avec succès (Code de sortie: 0)"
    }
    ElseIf ($InstallProcess.ExitCode -eq 3010) {
        Write-Log "Installation MSI terminée avec succès, redémarrage requis (Code de sortie: 3010)"
    }
    Else {
        Write-Log "ERREUR: L'installation a échoué avec le code de sortie: $($InstallProcess.ExitCode)"
        Exit $InstallProcess.ExitCode
    }
}
Catch {
    Write-Log "ERREUR lors de l'installation: $($_.Exception.Message)"
    Exit 1
}

# Attendre que l'installation se finalise complètement
Write-Log "Attente de finalisation de l'installation (10 secondes)..."
Start-Sleep -Seconds 10

# ============================================================================
# SECTION 2: CONFIGURATION DU PROFIL VPN
# ============================================================================

Write-Log "Début de la configuration du profil VPN..."

# *** PERSONNALISEZ CES VALEURS SELON VOTRE ENVIRONNEMENT ***
$VpnProfileName = "CTRLALTNOD"
$VpnDescription = "Connexion VPN pour ctrlaltnod"
$VpnServerAddress = "vpn.votreentreprise.com:4443"

# Chemin de la clé de registre pour les profils SSL VPN
$RegistryBasePath = "HKLM:\SOFTWARE\Fortinet\FortiClient\Sslvpn"
$VpnTunnelPath = "$RegistryBasePath\Tunnels\$VpnProfileName"

# Vérification et création de la structure de registre
Write-Log "Création de la structure de registre pour le profil VPN..."

Try {
    # Création du chemin de base si nécessaire
    If (-Not (Test-Path $RegistryBasePath)) {
        New-Item -Path $RegistryBasePath -Force | Out-Null
        Write-Log "Clé de base créée: $RegistryBasePath"
    }
    
    If (-Not (Test-Path "$RegistryBasePath\Tunnels")) {
        New-Item -Path "$RegistryBasePath\Tunnels" -Force | Out-Null
        Write-Log "Dossier Tunnels créé: $RegistryBasePath\Tunnels"
    }
    
    # Création du profil VPN
    If (-Not (Test-Path $VpnTunnelPath)) {
        New-Item -Path $VpnTunnelPath -Force | Out-Null
        Write-Log "Profil VPN créé: $VpnTunnelPath"
    }
    
    # Configuration des propriétés du profil VPN
    Write-Log "Configuration des propriétés du profil VPN..."
    
    # Description du profil
    New-ItemProperty -Path $VpnTunnelPath -Name "Description" -Value $VpnDescription -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "  - Description: $VpnDescription"
    
    # Adresse du serveur VPN avec port
    New-ItemProperty -Path $VpnTunnelPath -Name "Server" -Value $VpnServerAddress -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "  - Serveur: $VpnServerAddress"
    
    # Demander le nom d'utilisateur à chaque connexion (1=Oui, 0=Non)
    New-ItemProperty -Path $VpnTunnelPath -Name "promptusername" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "  - Prompt Username: Activé"
    
    # Demander le mot de passe à chaque connexion (1=Oui, 0=Non)
    New-ItemProperty -Path $VpnTunnelPath -Name "promptpassword" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "  - Prompt Password: Activé"
    
    # Ne pas utiliser l'authentification par certificat (0=Désactivé, 1=Activé)
    New-ItemProperty -Path $VpnTunnelPath -Name "promptcertificate" -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "  - Prompt Certificate: Désactivé"
    
    # Validation du certificat serveur (1=Validé, 0=Ignoré - NE PAS UTILISER 0 EN PRODUCTION)
    New-ItemProperty -Path $VpnTunnelPath -Name "ServerCert" -Value "1" -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "  - Validation certificat serveur: Activée"
    
    # Avertir en cas de certificat invalide (1=Oui)
    New-ItemProperty -Path $VpnTunnelPath -Name "warn_invalid_server_cert" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "  - Avertissement certificat invalide: Activé"
    
    # Conserver le profil après déconnexion (1=Oui)
    New-ItemProperty -Path $VpnTunnelPath -Name "keep_alive" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "  - Keep Alive: Activé"
    
    Write-Log "Configuration du profil VPN terminée avec succès."
}
Catch {
    Write-Log "ERREUR lors de la configuration du registre: $($_.Exception.Message)"
    Exit 1
}

# ============================================================================
# SECTION 3: SUPPRESSION DU MESSAGE DE BIENVENUE (DISCLAIMER)
# ============================================================================

Write-Log "Configuration pour supprimer le disclaimer de bienvenue..."

# Cette clé accepte automatiquement le disclaimer au premier lancement
$FortiClientVersion = "7.4.3.1790"
$DisclaimerPath = "HKLM:\SOFTWARE\Fortinet\FortiClient\FA_UI"

Try {
    If (-Not (Test-Path $DisclaimerPath)) {
        New-Item -Path $DisclaimerPath -Force | Out-Null
    }
    
    # Acceptation automatique du disclaimer pour cette version
    New-ItemProperty -Path $DisclaimerPath -Name "DisclaimerAccepted_$FortiClientVersion" -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
    Write-Log "Disclaimer automatiquement accepté pour la version $FortiClientVersion"
}
Catch {
    Write-Log "AVERTISSEMENT: Impossible de configurer l'acceptation du disclaimer: $($_.Exception.Message)"
    # Ce n'est pas une erreur critique, on continue
}

# ============================================================================
# SECTION 4: VÉRIFICATION DE L'INSTALLATION
# ============================================================================

Write-Log "Vérification de l'installation..."

# Vérification de la présence du fichier exécutable
$FortiClientExe = "$Env:ProgramFiles\Fortinet\FortiClient\FortiClient.exe"

If (Test-Path $FortiClientExe) {
    $FileVersion = (Get-Item $FortiClientExe).VersionInfo.FileVersion
    Write-Log "FortiClient.exe trouvé avec la version: $FileVersion"
    
    # Vérification de la version
    If ($FileVersion -match "7\.4\.3") {
        Write-Log "Version correcte installée."
    }
    Else {
        Write-Log "AVERTISSEMENT: La version installée ($FileVersion) ne correspond pas à 7.4.3.1790"
    }
}
Else {
    Write-Log "ERREUR: FortiClient.exe introuvable à l'emplacement attendu: $FortiClientExe"
    Exit 1
}

# Vérification de la présence du profil VPN dans le registre
If (Test-Path $VpnTunnelPath) {
    Write-Log "Profil VPN '$VpnProfileName' créé avec succès dans le registre."
    
    # Affichage des valeurs configurées pour vérification
    $ServerValue = (Get-ItemProperty -Path $VpnTunnelPath -Name "Server" -ErrorAction SilentlyContinue).Server
    Write-Log "Valeur serveur configurée: $ServerValue"
}
Else {
    Write-Log "ERREUR: Le profil VPN n'a pas été créé dans le registre."
    Exit 1
}

# ============================================================================
# FINALISATION
# ============================================================================

Write-Log "=========================================="
Write-Log "Installation et configuration terminées avec succès!"
Write-Log "=========================================="
Write-Log "Le profil VPN '$VpnProfileName' est maintenant disponible dans FortiClient."
Write-Log "Les utilisateurs peuvent se connecter en ouvrant FortiClient et en sélectionnant le profil VPN."

Exit 0
