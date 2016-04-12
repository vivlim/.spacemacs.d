#Requires -RunAsAdministrator

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

function Msys2-Install-Package-If-File-Missing($package, $file)
{
    if (Test-Path "c:\msys64\usr\bin\$file")
    {
        echo "msys2 has $package installed"
    }
    else
    {
        echo "msys2 doesn't have $package installed, installing package using pacman."
        C:\msys64\usr\bin\bash.exe --login -c "pacman -S --noconfirm $package"
    }
}

if (!$env:HOME) # emacs looks here to pull in the spacemacs config.
{
    echo "Setting HOME environment variable to $env:USERPROFILE"
    [Environment]::SetEnvironmentVariable("HOME", $env:USERPROFILE, "Machine")
}
else
{
    echo "HOME environment variable already exists and is $env:HOME"
}

if (Test-Path c:\msys64)
{
    echo "This machine has msys2 installed in c:\msys64"
}
else
{
    echo "This machine doesn't have msys2 installed in c:\msys64, getting the installer"
    wget http://repo.msys2.org/distrib/x86_64/msys2-x86_64-20160205.exe -outfile $env:temp\msys2.exe
    Start-Process -FilePath "$env:temp\msys2.exe"
}

if (Test-Path c:\msys64)
{
    echo "Since msys2 is installed, making sure it has all the packages needed."
    Msys2-Install-Package-If-File-Missing "cscope" "cscope.exe";
    Msys2-Install-Package-If-File-Missing "openssh" "ssh.exe";
    Msys2-Install-Package-If-File-Missing "dos2unix" "dos2unix.exe";
    Msys2-Install-Package-If-File-Missing "git" "git.exe";

    if (!(Test-Path c:\msys64\etc\nsswitch.conf.bak))
    {
        echo "Patching mysys2/etc/nsswitch.conf so ssh can use profile/.ssh"
        Copy-Item c:\msys64\etc\nsswitch.conf c:\msys64\etc\nsswitch.conf.bak
        Get-Content c:\msys64\etc\nsswitch.conf.bak | Foreach-Object {$_ -replace '^db_home.*$', "db_home: windows cygwin desc"} | Out-File c:\msys64\etc\nsswitch.conf
        C:\msys64\usr\bin\dos2unix.exe c:\msys64\etc\nsswitch.conf
    }
}
else
{
    echo "Not doing anything with msys2 packages since it doesn't appear to be installed at this time."
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
        echo ".emacs.d exists (spacemacs is installed)"
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
        echo "Install git from somewhere & make sure it's in the path."
    }
    Exit
}

# check that emacs is on this pc
if (Test-Path c:\emacs)
{
    #ok
    echo "This machine has emacs installed."
}
else
{
    echo "This machine doesn't have emacs installed; getting it & installing to c:\emacs"
    wget http://d.mjlim.net/~mikel/emacs.zip -outfile $env:temp\emacs.zip
    Expand-Zip $env:temp\emacs.zip c:\
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

if ($layers.GetValueNames().Contains("c:\emacs\bin\emacs.exe"))
{
    echo "This machine has the highdpi aware registry flags set on the emacs exes."
}
else
{
    echo "This machine doesn't have the highdpi aware registry flags set on the emacs exes, setting them..."
    $layers | New-ItemProperty -name "c:\emacs\bin\emacs.exe" -value "~ HIGHDPIAWARE"
    $layers | New-ItemProperty -name "c:\emacs\bin\runemacs.exe" -value "~ HIGHDPIAWARE"
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

if (Get-Command "pt.exe" -ErrorAction SilentlyContinue)
{
    echo "This machine has pt.exe in the path"
}
else
{
    echo "This machine doesn't have pt.exe, getting it."
    wget https://github.com/monochromegane/the_platinum_searcher/releases/download/v2.1.1/pt_windows_amd64.zip -outfile $env:temp\pt.zip
    Expand-Zip $env:temp\pt.zip $env:USERPROFILE\bin\
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


# finally start emacs to update packages.
# if (Test-path $env:USERPROFILE/.spacemacs.d/scripts/e.bat)
# {
#     # load runemacs.exe since for some reason that makes windows start honoring the dpi flag regkeys???
#     Start-Process -FilePath "c:\emacs\bin\runemacs.exe"
#     # & $env:USERPROFILE/.spacemacs.d/scripts/e.bat
# }
