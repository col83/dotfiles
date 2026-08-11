# Enable required system components
```bat
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```
Reboot PC

> [!NOTE]
> If you don't have any of these components - reinstall Windows from official ISO or select builder from [UUP dump](https://git.uupdump.net/uup-dump/misc/src/branch/master/FAQ.md): <br>
> [Windows 10 22H2 (19045.6691)](https://uupdump.net/selectlang.php?id=fb2dd074-7442-4f21-8486-312e4966e476) <br>
> [Windows 11](https://uupdump.net/fetchupd.php?arch=amd64&ring=retail)

# Install WSL2

### Download .msi package for yours CPU architecture from latest tag 
https://github.com/microsoft/WSL/tags

Then just open `.msi` installer

> [!WARNING]
> The .msi installer can automatically enable the necessary components, but I've noticed that after it attempts to enable them and prompts you to reboot the system, you might find that the components remain disabled. <br>
> Therefore, it's best to first manually enable the components and reboot the machine. <br>
> Then run the `.msi` installer and perform a final reboot.

### Set default wsl version
```bat
wsl --set-default-version 2
```

# Install distro

### List available distros
```bat
wsl --list --online
```
or
```bat
wsl -l -o
```

### List local available distros (downloaded)
```bat
wsl --list
```
or
```bat
wsl -l
```

### Verbose list output
```bat
wsl --list --verbose
```
or
```bat
wsl -l -v
```

## Install distro
```bat
wsl --install <distroname>
```
Example:
```bat
wsl --install archlinux
```

or if you have one locally
```bat
wsl --import <Distro> <InstallLocation> <FileName>
```
Example:
```bat
wsl --import ubuntu "C:\WSL\Ubuntu" "C:\Users\admin\Desktop\WSL\ubuntu-26.04-wsl-amd64.tar"
wsl --import arch "C:\WSL\Archlinux" "C:\Users\admin\Desktop\WSL\archlinux-26.08.01.wsl"
```

### Set default distro
```bat
wsl --set-default <distroname>
```
Example:
```bat
wsl --set-default archlinux
```

## Start WSL enviroment

### If default distro is configured or you have only one distro
```bat
wsl
```

### Specify distro
```bat
wsl -d <distroname>
```
Example:
```bat
wsl -d archlinux
```

> [!NOTE]
> On Ubuntu first run you need launch wsl this:

```bat
wsl -d Ubuntu -u root

sudo passwd root
```

# References:

[WSL install manual](https://learn.microsoft.com/en-us/windows/wsl/install-manual)

[WSL basic commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)

[WSL2 linux kernel](https://github.com/microsoft/WSL2-Linux-Kernel)
