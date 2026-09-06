# Enable required system components
```ps1
dism.exe /English /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
```
```ps1
dism.exe /English /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```
Reboot PC

> [!WARNING]
> If you don't have any of these components - reinstall Windows from [official ISO](https://www.microsoft.com/en-us/software-download/windows11) or select builder from [UUP dump](https://git.uupdump.net/uup-dump/misc/src/branch/master/FAQ.md): <br>
> [Windows 10 22H2 (19045.6691)](https://uupdump.net/selectlang.php?id=6610e6e9-928d-4315-aa8e-2775f07d5014) / [Windows 11](https://uupdump.net/fetchupd.php?arch=amd64&ring=retail)

# Install WSL2

### Download [.msi](https://learn.microsoft.com/en-us/windows/win32/msi/overview-of-windows-installer) package for yours CPU architecture from latest stable release 
https://github.com/microsoft/WSL/releases/latest

Then just open `.msi` installer

> [!IMPORTANT]
> The `.msi` installer can automatically enable the necessary components, but I've noticed that after it attempts to enable them and prompts you to reboot the system, you might find that the components remain disabled.
> 
> Therefore, it's best to first manually enable the components and reboot the machine. Then run the `.msi` installer and perform a final reboot.

### Set default WSL version
```bat
wsl --set-default-version 2
```

# Install distro

### List available distros
```bat
wsl --list --online
wsl -l -o
```

### List local available distros (installed)
```bat
wsl --list
wsl -l
```

### Verbose list output
```bat
wsl --list --verbose
wsl -l -v
```

### Install distro
```bat
wsl --install <DistroName> --web-download
```
Example:
```bat
wsl --install archlinux --web-download
```

> [!NOTE]
> The `--web-download` parameter downloads the distribution from the Internet instead of the [Microsoft Store](https://apps.microsoft.com/related/9pdxgncfsczv?hl=en-US), using the download URL specified in [DistributionInfo.json](https://raw.githubusercontent.com/microsoft/WSL/refs/heads/master/distributions/DistributionInfo.json)

<br>

or if you have one locally:
```bat
wsl --import <DistroName> <InstallLocation> <FileName>
```
```bat
wsl --install --from-file <FileName> --location <InstallLocation> --name <DistroName>
```
Example:
```bat
wsl --import ubuntu "C:\WSL\ubuntu" "C:\Users\admin\Desktop\WSL\ubuntu-26.04.1-wsl-amd64.tar"
wsl --import arch "C:\WSL\archlinux" "C:\Users\admin\Desktop\WSL\archlinux-26.09.01.wsl"
```
```bat
wsl --install --from-file "C:\Users\admin\Desktop\ubuntu-26.04.1-wsl-amd64.tar" --location "C:\WSL\ubuntu" --name ubuntu --fixed-vhd --vhd-size 85899345920 --no-launch
wsl --install --from-file "C:\Users\admin\Desktop\archlinux-26.09.01.wsl" --location "C:\WSL\archlinux" --name arch --fixed-vhd --vhd-size 85899345920 --no-launch
```
> [!NOTE]
> Without specifying the `--name` parameter during a local installation, the distribution will be named as specified in the `/etc/wsl-distribution.conf` file within the rootfs of the installed distribution with the value `defaultName = `.
>
> Example:
> ```bash
> [oobe]
> defaultName = archlinux

### Set default distro
```bat
wsl --set-default <DistroName>
```
Example:
```bat
wsl --set-default archlinux
```

## Start WSL environment

### If default distro is configured or you have only one distro
```bat
wsl
```

### Specify distro
```bat
wsl --distribution <DistroName>
wsl -d <DistroName>
```
Example:
```bat
wsl -d archlinux
```

> [!IMPORTANT]
> On Ubuntu first run you need launch WSL this:
> ```bat
> wsl -d ubuntu -u root
> ```
> then inside WSL environment:
> ```bash
> sudo passwd root
> ```

## Remove distro
```bat
wsl --unregister <DistroName>
```
Example:
```bat
wsl --unregister ubuntu
```

## References:

[WSL install manual](https://learn.microsoft.com/en-us/windows/wsl/install-manual)

[WSL basic commands](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)

[WSL2 linux kernel](https://github.com/microsoft/WSL2-Linux-Kernel)
