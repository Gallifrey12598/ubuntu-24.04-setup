# ubuntu-24.04-setup

This repository contains tools, scripts, and configuration files I’ve developed while transitioning a workforce to **Ubuntu Desktop 24.04** in my role as a Sr. Systems Engineer.  

Through discussions with staff, I identified required software and workflows, and created resources to make the migration as seamless as possible.

---

## 🚀 Quick Start

### 1. Automated Installation with `autoinstall.yaml`
Use this configuration to preload accounts, install required software, and enforce password resets on first login.

```bash
# During ISO customization, place autoinstall.yaml under:
# /cdrom/autoinstall/autoinstall.yaml
```

For password hashes, generate one with:

```bash
mkpasswd --method=SHA-512 --rounds=4096 'YourPassword'
```

Replace the placeholder in `autoinstall.yaml` with your hash.

---

### 2. Install VMware Workstation
Fetch and run the installation script:

```bash
curl -fsSL http://your-server/ubuntu/install-vmware.sh | sudo bash
```

- Make sure to set the password inside the script:
  ```bash
  FIXED_MOK_PASSWORD="your-password-here"
  ```
- After installation, **reboot** the system.
- On reboot, follow the prompts to enroll the **MOK certificate** using the password provided.

---

## autoinstall.yaml

To simplify deployments, I leverage Ubuntu’s **autoinstall** functionality with a customized `autoinstall.yaml` file. This file I have hosted on a web page. During ubuntu's installation you can specify where the autoinstall.yaml file is in advanced setup. For my use case it was something like:

```
# http://{SERVER-IP}/ubuntu/autoinstall.yaml
```

This file includes:
- Preloading of **administrator** and **user accounts**
- Passwords defined with **hashed values** (required for compatibility)
- User password expiration on first login, forcing a reset
- Automatic installation of requested packages:
  - `curl`  
  - `gnupg`  
  - `lsb-release`  
  - `python3-pip`  
  - `tailscale`  
  - `git`  
  - `vim`  
  - `libreoffice`  
  - `chromium-browser`  
  - `wireshark`  
  - `screen`  
  - `okular`  
  - `dmidecode`  

Additionally, I use the `late-commands:` directive to dynamically set each device’s hostname based on company structure.  
Using `dmidecode`, the script reads the device’s **serial number** and appends it to the hostname in the format:  
```
XYZ-{DEVICE_SERIAL_NUMBER}
```

---

## install-vmware.sh

This script is intended for **end-user execution** and should be hosted on an accessible web server. Users can fetch and run it with `curl`.  

### Purpose
The script installs **VMware Workstation 17** on Ubuntu. During manual installations, I encountered issues with missing modules due to **Secure Boot** restrictions (unsigned kernel modules).  

This script automates the process by:
1. Creating and signing **MOK certificates**  
2. Ensuring VMware modules load properly under Secure Boot  

### Usage
- Set the variable:
  ```bash
  FIXED_MOK_PASSWORD="your-password-here"
  ```
  > **Note:** While the password could be randomized during execution, for my use case I use a static password to prevent user error.
- After the script completes, make sure to pay attention to the password the script will echo to the end user. This will be needed to enroll the MOK certificates
- Reboot the Machine
- In the MOK Manager, enroll the certificates using the password from ealier.
- When the device boots back into Ubuntu you can no use VMWare Workstation with no issue

The Script is designed to give the End User clear instructions. That can be seen here
```
    echo
    echo "===================================================================="
    echo " Secure Boot: MOK enrollment scheduled."
    echo " 1) REBOOT the machine."
    echo " 2) In the blue 'MOK Manager', choose: Enroll MOK → Continue → Yes"
    echo " 3) Enter the password shown below (also saved to $MOKDIR/mok_password.txt)."
    echo "    PASSWORD: $FIXED_MOK_PASSWORD"
    echo " 4) After reboot, modules will be finalized automatically."
    echo "    (Manual helper: /usr/local/sbin/vmware-finalize.sh)"
    echo "===================================================================="
```

> **Note:** The use of these scripts are done at your own risk. I do not make any gurantees or accept responsibility for use of the contents of this repo. I urge everyone to do their own research and make sure you tailor anything here for your specific use case.
