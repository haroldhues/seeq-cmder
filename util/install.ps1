$target = '~/bin'
$tmp = '.\tmp'
$seeq_config = '.\config'
$cmder_version = 'v1.3.17'
$cmder_url = "https://github.com/cmderdev/cmder/releases/download/$cmder_version/cmder.zip"
$cmder_download = "$tmp\cmder.zip"
$cmder_install = "$target\Cmder"
$cmder_config = "$cmder_install\config"
$cmder_git_for_windows = "$cmder_install\vendor\git-for-windows"
$bashrc = "~/.bashrc"
$startup_directory = "~"
$pacman_repository = 'http://repo.msys2.org/msys/x86_64'
$pacman_packages = @(
    'zstd-1.4.7-1-x86_64.pkg.tar.xz'          # .zst decompression
    'tree-1.8.0-1-x86_64.pkg.tar.xz'
    'libopenssl-1.1.1.i-1-x86_64.pkg.tar.zst' # Dependency of rsync
    'libxxhash-0.8.0-1-x86_64.pkg.tar.zst'    # Dependency of rsync
    'libzstd-1.4.8-1-x86_64.pkg.tar.zst'      # Dependency of rsync
    'rsync-3.2.3-1-x86_64.pkg.tar.zst'
    'libmetalink-0.1.3-3-x86_64.pkg.tar.zst'  # Dependency of wget
    'libpcre2_8-10.36-1-x86_64.pkg.tar.zst'   # Dependency of wget
    'libgpgme-1.15.1-1-x86_64.pkg.tar.zst'    # Dependency of wget
    'wget-1.20.3-1-x86_64.pkg.tar.xz'
)

function Unix-Style ($path) {
    $path  -replace '\\','/' -replace '//','/' -replace ' ','\\ '
}

function Install-AllPacmanPackages {
    $pacman_packages | foreach {
        Install-PacmanPackage $_
    }
}

function Install-PacmanPackage($package) {
    $package_url = "$pacman_repository/$package"
    $package_download = "$tmp/$package"
    Write-Output "Downloading $package_url..."
    # https://stackoverflow.com/a/41618979/2899390
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $package_url -OutFile $package_download -ErrorAction Stop

    # A pacman package is a mirror of the root filesystem with some metadata files. Extract
    # to the git for windows root file system and delete the metadata files
    & "$cmder_git_for_windows\bin\bash.exe" -c "tar xf $(Unix-Style $package_download) -C $(Unix-Style $cmder_git_for_windows)"
    Remove-Item -Force "$cmder_git_for_windows/.PKGINFO" -ErrorAction Ignore
    Remove-Item -Force "$cmder_git_for_windows/.BUILDINFO" -ErrorAction Ignore
    Remove-Item -Force "$cmder_git_for_windows/.MTREE" -ErrorAction Ignore
    Remove-Item -Force "$cmder_git_for_windows/.INSTALL" -ErrorAction Ignore
}

function Get-YesNoQuestion($prompt) {
    $confirmation = ''
    do {
        $confirmation = Read-Host "> $prompt [y/n]"
    } while (($confirmation -ne "y") -and ($confirmation -ne "n"));
    $confirmation -eq "y"
}

function Get-PathFromPrompt($prompt) {
    $path = ''
    do {
        $path = Read-Host "> $prompt"
    } while (!(Test-Path $path));
    $path
}

New-Item -Path $tmp -ItemType Directory -Force | Out-Null
New-Item -Path $target -ItemType Directory -Force | Out-Null

if (Test-Path $cmder_install) {
    if (!(Get-YesNoQuestion "Cmder is already installed at $cmder_install; Continue configuring? (to update Cmder answer no and relocate that directory)")) {
        exit
    }
} else {
    Write-Output "Downloading Cmder $cmder_version..."
    # https://stackoverflow.com/a/41618979/2899390
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $cmder_url -OutFile $cmder_download -ErrorAction Stop

    Write-Output "Unpacking cmder.zip..."
    Expand-Archive -LiteralPath $cmder_download -DestinationPath $cmder_install -ErrorAction Stop

    
    if (Get-YesNoQuestion "Install extra tools like rsync, tree, wget?") {
        Install-AllPacmanPackages
    }
}
Write-Output ''

Write-Output "Configuring Cmder..."
Copy-Item $seeq_config\* $cmder_config -Recurse -Force -ErrorAction Stop
Write-Output ''

Write-Output "Setup $bashrc..."
$source_bashrc = '. "${CMDER_ROOT}/config/bashrc.sh"'
$source_bashrc_user = '. "${HOME}/.config/bashrc.sh"'
if ((Test-Path $bashrc) -and (@( Get-Content $bashrc | Where-Object { $_.Contains($source_bashrc) } ).Count -gt 0)) {
    Write-Output "$bashrc already configured"
} else {
    if (Test-Path $bashrc) {
        $bashrc_user = "~\.config\bashrc.sh"
        New-Item -Path "~\.config" -ItemType Directory -Force | Out-Null
        if (Test-Path $bashrc_user) {
            Write-Output "bashrc_user already exists; not proceeding"
            exit
        }
        Write-Output "Moving existing $bashrc to $bashrc_user"
        Move-Item $bashrc $bashrc_user
        Write-Output "Creating new $bashrc"
        Set-Content -Value $source_bashrc -Path $bashrc
        Add-Content -Value $source_bashrc_user -Path $bashrc
    } else {
        Write-Output "Creating new $bashrc"
        Set-Content -Value $source_bashrc -Path $bashrc
    }
    Write-Output ""
    
    Write-Output "NOTE: You can add or remove this by adding or removing "
    Write-Output "      'fancy_seeq_prompt' from ~/.bashrc . For more infromation"
    Write-Output "      see $cmder_config/bashrc.sh"
    if (Get-YesNoQuestion "Enable Cody Ray's 'Fancy Seeq Prompt'?") {
        Add-Content -Value 'fancy_seeq_prompt' -Path $bashrc
    }
    Write-Output ""
    
    Write-Output "NOTE: You can add or remove this by adding or removing "
    Write-Output "      'enable_sq_helpers' from ~/.bashrc . For more infromation"
    Write-Output "      see $cmder_config/bashrc.sh"
    if (Get-YesNoQuestion "Enable Cody Ray's 'Sq Helpers Aliases' (i.e., sqe)?") {
        Add-Content -Value 'enable_sq_helpers' -Path $bashrc
    }
}
Write-Output ''

if (Get-YesNoQuestion "Would you like to configure the startup directory of Cmder? (default is $startup_directory)") {        
    $startup_directory = Get-PathFromPrompt("Where should Cmder start at (ex: ~\seeq\crab)?")
}
Write-Output ''

$startup_directory = "$(Resolve-Path $startup_directory)"

$command = "'$cmder_install\Cmder.exe' /UNREGISTER USER"
Invoke-Expression "& $command"
if (Get-YesNoQuestion "Enable 'Cmder Here' from context menu?") {        
    Write-Output ''
    Write-Output "Registering Right Click Menu..."
    $command = "'$cmder_install\Cmder.exe' /REGISTER USER /SINGLE"
    Invoke-Expression "& $command"
}
Write-Output ''

$shortcut_path = "$(Resolve-Path '~\Desktop\')\Cmder.lnk"
if (Test-Path $shortcut_path) {
    Remove-Item -Path $shortcut_path -Force | Out-Null
}
Write-Output "NOTE: If you want to ultimatly pin Cmder, then create the shortcut"
Write-Output "      and then right click on the shortcut and 'Pin to Taskbar'"
Write-Output "      so that it starts in the correct directory"
if (Get-YesNoQuestion "Create a Desktop shortcut? (highly recomended)") {
    Write-Output ''
    Write-Output "Registering Right Click Menu..."
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcut_path)
    $Shortcut.TargetPath = "$(Resolve-Path $cmder_install\Cmder.exe)"
    $Shortcut.Arguments = "/SINGLE"
    $Shortcut.WorkingDirectory    = "$startup_directory"
    $Shortcut.Save()
}
Write-Output ""

Write-Output "Launching Cmder..."
$command = "'$cmder_install\Cmder.exe' /SINGLE /START '$startup_directory'"
Invoke-Expression "& $command"
