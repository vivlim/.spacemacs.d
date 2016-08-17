#Requires -RunAsAdministrator

param (
    [switch] $dontRunAgain,
    [switch] $choco
)

function Expand-Zip($file, $destination)
{
    if (Get-Command "Expand-Archive" --errorAction SilentlyContinue)
    {
        Expand-Archive $file -dest $destination
    }
    else
    {
        $shell = New-Object -com shell.application
        $zip = $shell.NameSpace($file)
        foreach ($item in $zip.items())
        {
            $shell.NameSpace($destination).copyhere($item)
        }
    }
}

function Update-Chocolatey-Packages()
{
    if (!(Get-Command "choco.exe" -ErrorAction SilentlyContinue))
    {
        echo "Installing Chocolatey"
        iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
        refreshenv
    }

    echo "Installing/Updating Chocolatey packages"
    choco upgrade pt -y
    choco upgrade emacs64 -y
    choco upgrade git -y -params '"/GitAndUnixToolsOnPath"'
    choco upgrade -y everything
    choco upgrade -y nodejs
    choco upgrade -y gitextensions
    choco upgrade -y kdiff3
    choco upgrade -y 7zip
    choco upgrade -y git-credential-manager-for-windows
    choco upgrade -y windirstat
    choco upgrade -y win32-openssh -params '"/SSHServerFeature"'
    choco upgrade -y sysinternals
    choco upgrade -y vim
    choco upgrade -y ctags
    choco upgrade -y sudo

    echo "Setting up hs"
    choco upgrade -y heatseeker
    if (!(Get-Command "Install-Package")){
        echo "Install-Package not found. Installing package management."
        choco upgrade -y powershell-packagemanagement
        refreshenv
    }

    if (!(Get-Command "PSReadline" -ErrorAction SilentlyContinue)){
        echo "PSReadline not found. Trying to install it."
        Install-Package PSReadline
    }
}

function AddPsProfile()
{
    if (!(Get-Content $profile | Select-String "spacemacs" -Quiet))
    {
        echo "Powershell profile doesn't call my profile script, adding to $profile and running it"
        Add-Content $profile ". $home\.spacemacs.d\scripts\psprofile.ps1"
        . $home\.spacemacs.d\scripts\psprofile.ps1
    }
    else
    {
        echo "Powershell profile calls my profile script."
    }
}

# Update choco packages on initial run
if (!$dontRunAgain -and $choco)
{
    Update-Chocolatey-Packages
}

AddPsProfile

if (!$env:HOME) # emacs looks here to pull in the spacemacs config.
{
    echo "Setting HOME environment variable to $env:USERPROFILE"
    [Environment]::SetEnvironmentVariable("HOME", $env:USERPROFILE, "Machine")
}
else
{
    echo "HOME environment variable already exists and is $env:HOME"
}

if (Get-Command "git.exe" -ErrorAction SilentlyContinue)
{
    echo "This machine has git. Configuring for performance on Windows."
    git config --global core.preloadindex true
    git config --global core.fscache true
    git config --global gc.auto 256

    if (Test-path $env:USERPROFILE/.spacemacs.d/)
    {
        echo ".spacemacs.d exists. updating it..."
        pushd $env:USERPROFILE/.spacemacs.d
        git pull origin master
        popd
    }
    else
    {
        echo ".spacemacs.d doesn't exist. cloning from my github"
        pushd $env:USERPROFILE
        git clone git@github.com:mjlim/.spacemacs.d.git
        if (!(Test-path $env:USERPROFILE/.spacemacs.d/))
        {
            echo "cloning failed. falling back to https clone"
            git clone https://github.com/mjlim/.spacemacs.d.git
        }
        popd
    }

    if (Test-path $env:USERPROFILE/.emacs.d/)
    {
        echo ".emacs.d exists (spacemacs is installed). checking for updates"
        pushd $env:USERPROFILE/.emacs.d
        git pull
        popd
    }
    else
    {
        echo ".emacs.d doesn't exist, cloning spacemacs."
        pushd $env:USERPROFILE
        git clone https://github.com/syl20bnr/spacemacs .emacs.d
        popd
    }
}
else
{
    echo "This machine doesn't have git."
    if (Test-Path "c:\msys64\usr\bin\git.exe")
    {
        echo "But git.exe was found in msys2. Adding msys2 bin to path..."
        [Environment]::SetEnvironmentVariable("Path", $Env:Path + ";c:\msys64\usr\bin\", "Machine")
        echo "Run this script again. (tl;dr: lazy scripting)"
    }
    else
    {
        echo "Please rerun with -choco flag to install git (and other things)"
    }
    Exit
}

# check regkey to turn off scaling
$layerspath = "hklm:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers\"
# create it if it doesn't exist.
if(!(Test-Path $layerspath))
{
    echo "This machine doesn't have the AppCompatFlags\Layers key, creating it."
    New-Item -Path $layerspath -Force
}

$layers = Get-Item $layerspath

if ($layers.GetValueNames().Contains("c:\programdata\chocolatey\lib\emacs64\tools\emacs\bin\emacs.exe"))
{
    echo "This machine has the highdpi aware registry flags set on the emacs exes."
}
else
{
    echo "This machine doesn't have the highdpi aware registry flags set on the emacs exes, setting them..."
    $layers | New-ItemProperty -name "c:\programdata\chocolatey\lib\emacs64\tools\emacs\bin\emacs.exe" -value "~ HIGHDPIAWARE"
    $layers | New-ItemProperty -name "c:\programdata\chocolatey\bin\emacs.exe" -value "~ HIGHDPIAWARE"
    $layers | New-ItemProperty -name "c:\programdata\chocolatey\bin\runemacs.exe" -value "~ HIGHDPIAWARE"
    echo "if that failed, try again as admin."
}

if (Get-Command "e.bat" -ErrorAction SilentlyContinue)
{
    echo "This machine has e.bat in the path"
}
else
{
    echo "Adding scripts to path"
    [Environment]::SetEnvironmentVariable("Path", $Env:Path + ";" + $env:USERPROFILE + "\.spacemacs.d\scripts\", "Machine")
}

if (Test-Path $env:USERPROFILE\bin\)
{
    echo "This machine has a local bin directory in the path"
}
else
{
    echo "This machine does not have a local bin directory in the path. Creating & adding to path."
    mkdir $env:USERPROFILE\bin\
    [Environment]::SetEnvironmentVariable("Path", $Env:Path + ";" + $env:USERPROFILE + "\bin\", "Machine")
}

# fix emacs.d/server identity for the hell of it (could be broken on some machines)
$serverpath = "$env:USERPROFILE/.emacs.d/server"
if (Test-Path $serverpath)
{
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $acl = Get-ACL $serverpath
    $acl.SetOwner($user.User)
    Set-Acl -Path $serverpath -AclObject $acl
}

echo "Refreshing PATH"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

if (!$dontRunAgain)
{
    echo "~*~*~ Running again ~*~*~"
    Invoke-Expression "eupdate.ps1 -dontRunAgain"
}
else
{
    echo "Remember to use -choco if you want packages to update!"
}
