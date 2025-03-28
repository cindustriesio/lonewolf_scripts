# lonewolf_scripts

These scripts are stand alone and are designed to be that way.
They are made for Proxmox!

They are open and available for review, everything is as simple as they need to be to run successfully. I try to make comments on every section within a code block, in order to make it easier to follow for less technical users.

## Basic Run Commands
Run LXC or VM Creation with: ```bash -c "$(wget -qLO - https://lonewolfscripts.com)"```

Run Install scripts alone with: ```wget -qO- "https://lonewolfscripts.com" | bash -s -- <LXC_ID>```


These are very much in early development, and I am not responsible for anything breaking. Use at your own risk!

## Currently Available:

### Installs:
Run these to make a highly customizable vm/lxc on Proxmox.

#### AllInstaller:
```
https://raw.githubusercontent.com/cindustriesio/lonewolf_scripts/refs/heads/main/proxmox/ultra_scripts/enhanced_vm_lxc_install.sh
```

#### Debian:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/cindustriesio/lonewolf_scripts/refs/heads/main/proxmox/lxc/debian_lxc_git.sh)"
```

#### Ubuntu:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/cindustriesio/lonewolf_scripts/refs/heads/main/proxmox/lxc/ubuntu_lxc_git.sh)"
```

You can inject whatever script at the end to install applications into the newly created LXC. Just copy paste the github install script into it.

I have a few available in this repository for testing.

### LXC update:
This an update script to select multiple LXCs at once for updating.
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/cindustriesio/lonewolf_scripts/refs/heads/main/proxmox/lxc/lxc_update_selectable.sh)"
```

Any questions or comments just ask! I am new to git, and this is a learning experience while trying to help the community.

#### Contribute
I welcome more contributors, this is becoming a large scope project...
If you want to help out with alternative methods, consider a [donation](https://ko-fi.com/technaut951)! I work on these when I have time, so updates will come out sproadically.
