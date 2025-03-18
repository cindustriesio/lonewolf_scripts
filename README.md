# stand_alone_scripts

These scripts are stand alone and are designed to be that way.
They are made for Proxmox!

They are open and available for review, everything is as simple as they need to be to run successfully. I try to make comments on every section within a code block, in order to make it easier to follow for less technical users.

Run Everything with: bash -c "$(wget -qLO - https://whatevertheurlisongithub.com)"

These are very much in early development, and I am not responsible for anything breaking. Use at your own risk!

## Currently Available:

### LXC installs:

Debian:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/cindustriesio/stand_alone_scripts/refs/heads/main/proxmox/lxc/debian_lxc_git.sh)"
```

Ubuntu:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/cindustriesio/stand_alone_scripts/refs/heads/main/proxmox/lxc/ubuntu_lxc_git.sh)"
```

You can inject whatever script at the end to install applications into the newly created LXC. Just copy past the github install script into it.

Any questions or comments just ask! I am new to git, and this is a learning experience while trying to help the community.
