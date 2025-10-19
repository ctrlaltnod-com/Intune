# ============================================================================
# Script de désinstallation FortiClient VPN 7.4.3.1790 pour Microsoft Intune
# Auteur: ctrlaltnod.com
# Date: 19 octobre 2025
# Version: 1.0
# Description: Désinstallation complète de FortiClient VPN et suppression
#              des profils VPN configurés
# ============================================================================

# Vérification et redémarrage en PowerShell 64-bit si nécessaire
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
$LogPath = "C:\Windows\Temp\FortiClientVPN_Uninstall.log"
Function Write-Log {
    Param ([string]$Message)
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$TimeStamp - $Message" | Out-File -FilePath $LogPath -Append
    Write-Host $Message
}

Write-Log "=========================================="
Write-Log "Début de la désinstallation de FortiClient VPN"
Write-Log "=========================================="

# ============================================================================
# SECTION 1: ARRÊT DU PROCESSUS FORTICLIENT
# ============================================================================

Write-Log "Arrêt du processus FortiClient en cours d'exécution..."

Try {
    # Arrêt du processus FortiClient s'il est en cours d'exécution
    $FortiClientProcess = Get-Process -Name "FortiClient" -ErrorAction SilentlyContinue
    
    If ($FortiClientProcess) {
        Write-Log "Processus FortiClient détecté (PID: $($FortiClientProcess.Id))"
        Stop-Process -Name "FortiClient" -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
        Write-Log "Processus FortiClient arrêté."
    }
    Else {
        Write-Log "Aucun processus FortiClient en cours d'exécution."
    }
    
    # Arrêt d'autres processus FortiClient potentiels
    $FortiServices = @("FortiTray", "FortiSSLVPNdaemon", "FortiESNAC")
    
    ForEach ($ServiceName in $FortiServices) {
        $Process = Get-Process -Name $ServiceName -ErrorAction SilentlyContinue
        If ($Process) {
            Write-Log "Arrêt du processus: $ServiceName"
            Stop-Process -Name $ServiceName -Force -ErrorAction SilentlyContinue
        }
    }
    
    Start-Sleep -Seconds 2
}
Catch {
    Write-Log "AVERTISSEMENT lors de l'arrêt des processus: $($_.Exception.Message)"
    # On continue même si l'arrêt échoue
}

# ============================================================================
# SECTION 2: DÉTECTION DU PRODUCT CODE
# ============================================================================

Write-Log "Recherche du Product Code de FortiClient VPN..."

# Méthode 1: Recherche via Win32_Product (plus lente mais fiable)
Try {
    $FortiClientProduct = Get-WmiObject -Class Win32_Product | Where-Object { 
        $_.Name -like "*FortiClient*VPN*" 
    } | Select-Object -First 1
    
    If ($FortiClientProduct) {
        $ProductCode = $FortiClientProduct.IdentifyingNumber
        $ProductName = $FortiClientProduct.Name
        $ProductVersion = $FortiClientProduct.Version
        
        Write-Log "FortiClient détecté via WMI:"
        Write-Log "  - Nom: $ProductName"
        Write-Log "  - Version: $ProductVersion"
        Write-Log "  - Product Code: $ProductCode"
    }
}
Catch {
    Write-Log "AVERTISSEMENT: Échec de la recherche WMI: $($_.Exception.Message)"
}

# Méthode 2: Recherche dans le registre (plus rapide)
If (-Not $ProductCode) {
    Write-Log "Recherche du Product Code dans le registre..."
    
    $UninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    ForEach ($Path in $UninstallPaths) {
        Try {
            $Apps = Get-ItemProperty $Path -ErrorAction SilentlyContinue
            
            ForEach ($App in $Apps) {
                If ($App.DisplayName -like "*FortiClient*VPN*") {
                    # Extraction du GUID depuis PSPath
                    If ($App.PSChildName -match '\{[A-F0-9\-]+\}') {
                        $ProductCode = $Matches[0]
                        Write-Log "Product Code trouvé dans le registre: $ProductCode"
                        Write-Log "  - Nom: $($App.DisplayName)"
                        Write-Log "  - Version: $($App.DisplayVersion)"
                        Break
                    }
                }
            }
            
            If ($ProductCode) { Break }
        }
        Catch {
            Continue
        }
    }
}

# Méthode 3: Product Code par défaut pour la version 7.4.3.1790
# IMPORTANT: Ce GUID peut varier selon les versions. Vérifiez le vôtre!
If (-Not $ProductCode) {
    Write-Log "AVERTISSEMENT: Product Code non trouvé automatiquement."
    Write-Log "Utilisation d'un Product Code générique (peut ne pas fonctionner)."
    
    # Ce GUID est un exemple et doit être vérifié pour votre version spécifique
    # Pour trouver le bon GUID:
    # 1. Installez FortiClient manuellement sur un poste de test
    # 2. Ouvrez regedit et allez dans HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall
    # 3. Cherchez l'entrée FortiClient VPN et copiez le GUID
    $ProductCode = "15C7B361-A0B2-4E79-93E0-868B5000BA3F}"
    
    Write-Log "Product Code utilisé: $ProductCode"
    Write-Log "ATTENTION: Vérifiez que ce GUID correspond à votre installation!"
}

# ============================================================================
# SECTION 3: DÉSINSTALLATION DU MSI
# ============================================================================

If ($ProductCode -and $ProductCode -notmatch "^{X+") {
    Write-Log "Lancement de la désinstallation MSI..."
    
    # Arguments de désinstallation
    # /x           = Désinstallation
    # /qn          = Mode silencieux complet
    # /norestart   = Pas de redémarrage automatique
    # REBOOT=ReallySuppress = Suppression du redémarrage
    
    $UninstallArguments = @(
        "/x"
        $ProductCode
        "/qn"
        "/norestart"
        "REBOOT=ReallySuppress"
        "/L*v"
        "C:\Windows\Temp\FortiClientVPN_MSI_Uninstall.log"
    )
    
    Try {
        $UninstallProcess = Start-Process -FilePath "msiexec.exe" -ArgumentList $UninstallArguments -Wait -PassThru -NoNewWindow
        
        If ($UninstallProcess.ExitCode -eq 0) {
            Write-Log "Désinstallation MSI terminée avec succès (Code de sortie: 0)"
        }
        ElseIf ($UninstallProcess.ExitCode -eq 3010) {
            Write-Log "Désinstallation MSI terminée, redémarrage requis (Code de sortie: 3010)"
        }
        ElseIf ($UninstallProcess.ExitCode -eq 1605) {
            Write-Log "INFORMATION: Le produit n'est pas installé ou déjà désinstallé (Code: 1605)"
        }
        Else {
            Write-Log "AVERTISSEMENT: Désinstallation terminée avec le code: $($UninstallProcess.ExitCode)"
        }
    }
    Catch {
        Write-Log "ERREUR lors de la désinstallation: $($_.Exception.Message)"
        # On continue pour nettoyer le registre même si la désinstallation échoue
    }
    
    # Attendre que la désinstallation se finalise
    Write-Log "Attente de finalisation de la désinstallation (10 secondes)..."
    Start-Sleep -Seconds 10
}
Else {
    Write-Log "ERREUR: Product Code invalide ou non trouvé. Impossible de désinstaller via MSI."
    Write-Log "La désinstallation se poursuivra avec le nettoyage du registre."
}

# ============================================================================
# SECTION 4: NETTOYAGE DU REGISTRE
# ============================================================================

Write-Log "Nettoyage des clés de registre FortiClient..."

# Liste des clés de registre à supprimer
$RegistryKeysToRemove = @(
    "HKLM:\SOFTWARE\Fortinet\FortiClient",
    "HKLM:\SOFTWARE\WOW6432Node\Fortinet\FortiClient",
    "HKCU:\SOFTWARE\Fortinet\FortiClient"
)

ForEach ($RegKey in $RegistryKeysToRemove) {
    Try {
        If (Test-Path $RegKey) {
            Remove-Item -Path $RegKey -Recurse -Force -ErrorAction Stop
            Write-Log "Clé de registre supprimée: $RegKey"
        }
        Else {
            Write-Log "Clé de registre non trouvée (déjà supprimée): $RegKey"
        }
    }
    Catch {
        Write-Log "AVERTISSEMENT: Impossible de supprimer $RegKey : $($_.Exception.Message)"
    }
}

# ============================================================================
# SECTION 5: SUPPRESSION DES FICHIERS RESTANTS
# ============================================================================

Write-Log "Suppression des fichiers et dossiers résiduels..."

$FoldersToRemove = @(
    "$Env:ProgramFiles\Fortinet\FortiClient",
    "$Env:ProgramFiles(x86)\Fortinet\FortiClient",
    "$Env:ProgramData\Fortinet\FortiClient",
    "$Env:LOCALAPPDATA\Fortinet\FortiClient",
    "$Env:APPDATA\Fortinet\FortiClient"
)

ForEach ($Folder in $FoldersToRemove) {
    Try {
        If (Test-Path $Folder) {
            Remove-Item -Path $Folder -Recurse -Force -ErrorAction Stop
            Write-Log "Dossier supprimé: $Folder"
        }
        Else {
            Write-Log "Dossier non trouvé: $Folder"
        }
    }
    Catch {
        Write-Log "AVERTISSEMENT: Impossible de supprimer $Folder : $($_.Exception.Message)"
    }
}

# ============================================================================
# SECTION 6: SUPPRESSION DES RACCOURCIS
# ============================================================================

Write-Log "Suppression des raccourcis du menu Démarrer et du bureau..."

$ShortcutLocations = @(
    "$Env:PUBLIC\Desktop\FortiClient.lnk",
    "$Env:USERPROFILE\Desktop\FortiClient.lnk",
    "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\FortiClient",
    "$Env:APPDATA\Microsoft\Windows\Start Menu\Programs\FortiClient"
)

ForEach ($Shortcut in $ShortcutLocations) {
    Try {
        If (Test-Path $Shortcut) {
            Remove-Item -Path $Shortcut -Recurse -Force -ErrorAction Stop
            Write-Log "Raccourci supprimé: $Shortcut"
        }
    }
    Catch {
        Write-Log "AVERTISSEMENT: Impossible de supprimer $Shortcut : $($_.Exception.Message)"
    }
}

# ============================================================================
# SECTION 7: VÉRIFICATION DE LA DÉSINSTALLATION
# ============================================================================

Write-Log "Vérification de la désinstallation..."

$FortiClientExe = "$Env:ProgramFiles\Fortinet\FortiClient\FortiClient.exe"

If (-Not (Test-Path $FortiClientExe)) {
    Write-Log "FortiClient.exe introuvable - Désinstallation réussie."
}
Else {
    Write-Log "AVERTISSEMENT: FortiClient.exe encore présent: $FortiClientExe"
}

$RegistryCheck = Test-Path "HKLM:\SOFTWARE\Fortinet\FortiClient"
If (-Not $RegistryCheck) {
    Write-Log "Clés de registre supprimées avec succès."
}
Else {
    Write-Log "AVERTISSEMENT: Des clés de registre FortiClient sont toujours présentes."
}

# ============================================================================
# FINALISATION
# ============================================================================

Write-Log "=========================================="
Write-Log "Désinstallation de FortiClient VPN terminée."
Write-Log "=========================================="
Write-Log ""
Write-Log "NOTE IMPORTANTE:"
Write-Log "Si le Product Code était invalide, vous devrez peut-être:"
Write-Log "1. Installer FortiClient manuellement sur un poste de test"
Write-Log "2. Récupérer le bon GUID depuis le registre"
Write-Log "3. Mettre à jour ce script avec le bon Product Code"
Write-Log ""
Write-Log "Journal de désinstallation: $LogPath"

Exit 0
