<powershell>

function run-once-on-login ($taskname, $action) {
    $trigger = New-ScheduledTaskTrigger -AtLogon -RandomDelay $(New-TimeSpan -seconds 30)
    $trigger.Delay = "PT30S"
    $selfDestruct = New-ScheduledTaskAction -Execute powershell.exe -Argument "-WindowStyle Hidden -Command `"Disable-ScheduledTask -TaskName $taskname`""
    Register-ScheduledTask -TaskName $taskname -Trigger $trigger -Action $action,$selfDestruct -RunLevel Highest
}

function install-chocolatey {
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    choco feature enable -n allowGlobalConfirmation
}

function install-parsec-cloud-preparation-tool {
    # https://github.com/jamesstringerparsec/Parsec-Cloud-Preparation-Tool
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $downloadPath = "C:\Parsec-Cloud-Preparation-Tool.zip"
    $extractPath = "C:\Parsec-Cloud-Preparation-Tool"
    $repoPath = Join-Path $extractPath "Parsec-Cloud-Preparation-Tool-master"
    $copyPath = Join-Path $desktopPath "ParsecTemp"
    $scriptEntrypoint = Join-Path $repoPath "PostInstall\PostInstall.ps1"

    if (!(Test-Path -Path $extractPath)) {
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        (New-Object System.Net.WebClient).DownloadFile("https://github.com/jamesstringerparsec/Parsec-Cloud-Preparation-Tool/archive/master.zip", $downloadPath)
        New-Item -Path $extractPath -ItemType Directory
        Expand-Archive $downloadPath -DestinationPath $extractPath
        Remove-Item $downloadPath

        New-Item -Path $copyPath -ItemType Directory
        Copy-Item $repoPath/* $copyPath -Recurse -Container

        # Setup scheduled task to run Parsec-Cloud-Preparation-Tool once at logon
        $action = New-ScheduledTaskAction -Execute powershell.exe -WorkingDirectory $repoPath -Argument "-Command `"$scriptEntrypoint -DontPromptPasswordUpdateGPU`""
        run-once-on-login "Parsec-Cloud-Preparation-Tool" $action
    }
}

function install-admin-password {
    $password = (Get-SSMParameter -WithDecryption $true -Name '${password_ssm_parameter}').Value
    net user Administrator "$password"
}

function install-autologin {
    Install-Module -Name DSCR_AutoLogon -Force
    Import-Module -Name DSCR_AutoLogon
    $password = (Get-SSMParameter -WithDecryption $true -Name '${password_ssm_parameter}').Value
    $regPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
    [microsoft.win32.registry]::SetValue($regPath, "AutoAdminLogon", "1")
    [microsoft.win32.registry]::SetValue($regPath, "DefaultUserName", "Administrator")
    Remove-ItemProperty -Path $regPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
    (New-Object PInvoke.LSAUtil.LSAutil -ArgumentList "DefaultPassword").SetSecret($password)
}

function disable-lock-on-rdp-disconnect {
    # Prevent screen from locking when RDP session disconnects (fixes Parsec showing lock screen)
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "NoLockScreen" -Value 1 -Type DWord

    # Disable lock screen on session disconnect
    $regPath2 = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
    Set-ItemProperty -Path $regPath2 -Name "fDisableCam" -Value 1 -Type DWord

    # Disable screensaver
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveActive" -Value "0"
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaverIsSecure" -Value "0"

    # Disable require password on wake/resume
    powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
    powercfg /setactive SCHEME_CURRENT
}

function install-graphic-driver {
    # https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/install-nvidia-driver.html#nvidia-gaming-driver

    if (!(Test-Path -Path "C:\Program Files\NVIDIA Corporation\NVSMI")) {
        $ExtractionPath = "C:\nvidia-driver\driver"
        $Bucket = ""
        $KeyPrefix = ""
        $InstallerFilter = "*.exe"

        # Ensure extraction directory exists
        New-Item -ItemType Directory -Force -Path $ExtractionPath | Out-Null

        %{ if regex("^g[0-9]+", var.instance_type) == "g3" }

        # GRID driver for g3
        $Bucket = "ec2-windows-nvidia-drivers"
        $KeyPrefix = "latest"

        # download driver
        $Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1
        foreach ($Object in $Objects) {
            $LocalFileName = $Object.Key
            if ($LocalFileName -ne '' -and $Object.Size -ne 0) {
                $LocalFilePath = Join-Path $ExtractionPath $LocalFileName
                Copy-S3Object -BucketName $Bucket -Key $Object.Key -LocalFile $LocalFilePath -Region us-east-1
            }
        }

        # disable licencing page in control panel
        New-ItemProperty -Path "HKLM:\SOFTWARE\NVIDIA Corporation\Global\GridLicensing" -Name "NvCplDisableManageLicensePage" -PropertyType "DWord" -Value "1"

        %{ else }
        %{ if regex("^g[0-9]+", var.instance_type) == "g4" }

        # vGaming driver for g4
        $Bucket = "nvidia-gaming"
        $KeyPrefix = "windows/latest"

        # download and extract driver (zip is multi-part, requires 7-Zip)
        choco install 7zip -y
        $Objects = Get-S3Object -BucketName $Bucket -KeyPrefix $KeyPrefix -Region us-east-1
        foreach ($Object in $Objects) {
            if ($Object.Size -ne 0) {
                $LocalFileName = "C:\nvidia-driver\driver.zip"
                Copy-S3Object -BucketName $Bucket -Key $Object.Key -LocalFile $LocalFileName -Region us-east-1
                & "C:\Program Files\7-Zip\7z.exe" x $LocalFileName -o"$ExtractionPath" -y
                break
            }
        }

        # install licence - find the latest cert dynamically
        $CertObjects = Get-S3Object -BucketName $Bucket -KeyPrefix "GridSwCert-Archive" -Region us-east-1
        $LatestCert = ($CertObjects | Where-Object { $_.Key -like "*.cert" } | Sort-Object LastModified -Descending | Select-Object -First 1).Key
        Copy-S3Object -BucketName $Bucket -Key $LatestCert -LocalFile "C:\Users\Public\Documents\GridSwCert.txt" -Region us-east-1
        [microsoft.win32.registry]::SetValue("HKEY_LOCAL_MACHINE\SOFTWARE\NVIDIA Corporation\Global", "vGamingMarketplace", 0x02)

        %{ endif }
        %{ endif }

        $InstallerFile = Get-ChildItem -Path $ExtractionPath -Filter $InstallerFilter -Recurse | Where-Object { $_.Name -notlike "*uninstall*" } | Select-Object -First 1 -ExpandProperty FullName

        if ($InstallerFile) {
            # install driver
            Start-Process -FilePath $InstallerFile -ArgumentList "/s /n" -Wait

            # install task to disable second monitor on login
            $trigger = New-ScheduledTaskTrigger -AtLogon
            $action = New-ScheduledTaskAction -Execute displayswitch.exe -Argument "/internal"
            Register-ScheduledTask -TaskName "disable-second-monitor" -Trigger $trigger -Action $action -RunLevel Highest

            # cleanup
            Remove-Item -Path "C:\nvidia-driver" -Recurse
        }
        else {
            $action = New-ScheduledTaskAction -Execute powershell.exe -Argument "-WindowStyle Hidden -Command `"(New-Object -ComObject Wscript.Shell).Popup('Automatic GPU driver installation is unsupported for this instance type: ${var.instance_type}. Please install them manually.')`""
            run-once-on-login "gpu-driver-warning" $action
        }
    }
}

install-chocolatey
Install-PackageProvider -Name NuGet -Force
choco install awstools.powershell

%{ if var.install_parsec }
install-parsec-cloud-preparation-tool
%{ endif }

install-admin-password

%{ if var.install_auto_login }
install-autologin
%{ endif }

disable-lock-on-rdp-disconnect

%{ if var.install_graphic_card_driver }
install-graphic-driver
%{ endif }

%{ if var.install_steam }
choco install steam
%{ endif }

%{ if var.install_epic_games_launcher }
choco install epicgameslauncher
%{ endif }

</powershell>