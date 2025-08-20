# Ubuntu 24.04 Baseline

This repository contains tools, scripts, and configuration files I’ve developed while transitioning a workforce to **Ubuntu Desktop 24.04** in my role as a Sr. Systems Engineer.  

Through discussions with staff, I identified required software and workflows, and created resources to make the migration as seamless as possible.

---
# Prerequisites
This  repo and its files assumes you are running a webserver to host these files. As configured they do assume the following structure.
```
http://{SERVER_IP}/ubuntu
-> baseline.sh
-> autoinstall.yaml
-> headscale
  --> install-tailscale.sh
  --> .env
-> sshkey
  --> install-sshkey.sh
  --> .env
-> vmware
  --> install-vmware.sh
  --> VMware-Workstation17-install.bundle

```
Although these scripts are configured in a way to make sure your repos are updated, it is good practice to run
```
$sudo apt-get update
$sudo apt-get upgrade
```
---
# Running the Baseline
As stated before, this script is meant to be run on the host machine to *baseline* the machine. On the end user device simply invoke the script by running:
```
$curl http://{SERVER_IP}/ubuntu/baseline.sh
```
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

Make sure on the server hosting the script you run the command:
```
sudo perl -pi -e 's/\r$//' /PATH/TO/BUNDLE_FILE.bundle
```
- Set the variables:
  ```bash
  FIXED_MOK_PASSWORD="your-password-here"
  BUNDLE_URL="URL-Where-VMWARE.bundle File Resides"
  ```
  > **Note:** While the password could be randomized during execution, for my use case I use a static password to prevent user error.
- Have the end user run the script with the command:
  ```
  curl -fsSL http://{SERVER_IP}/directory/install-vmware.sh | sudo -E bash
  ```
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
# Install Tailescale and Pre-auth to self hosted Headscale
This script will automate the process of installing tailscale on and Ubuntu device and connect to your self hosted headscale server. This is meant to be ran by the End user using the curl command.

**Example:**
```
curl http://{SERVER_IP/directory/tailscale-install.sh}
```
The script is meant to be paired with the .evn file where your Enviroment Variables need to be set. The required parameters are:
- HEADSCALE_URL=""
- AUTH_KEY=""
- USE_EXIT_NODE="false"
- SHIELDS_UP="false"
- ACCEPT_ROUTES="false"

This script also assumes you have the .env hosted at *http://{SERVER_IP}/directory/.env*
These can be updated based on your needs.


---
# Installation of SSH key(s)
Since our deployment relies heavily on Ansible for Linux administration, it is essential that the Ansible server’s public SSH key be imported into client devices. This ensures that Ansible can connect to those devices for management without requiring manual intervention.

Under normal circumstances, initiating an SSH session requires entering the password of the remote account. However, Ansible does not store these credentials. To enable passwordless authentication, we configure each client machine by placing the Ansible server’s public SSH key into the target user’s ~/.ssh/authorized_keys file. This allows Ansible to authenticate seamlessly without prompting for a password.

This process is straightforward if you have direct access to the Ansible server. However, our end users do not. Instead, we use Tailscale/Headscale to provide a secure overlay network for administration. While Ansible can reach devices across this network, end users cannot directly interact with Ansible itself.

On the Ansible server, the following command could be used:
```
sudo ssh-copy-id user@ip
```
This copies the Ansible server’s public key (id_rsa.pub) into the specified user’s authorized_keys file on the remote system. However, this approach requires the operator to know each client’s IP address and to repeat the process manually for every machine. To streamline deployment, we decided to handle this step during initial machine configuration.

For this purpose, we created the install-sshkey.sh script, designed to run locally on client machines. The script checks the ~/.ssh/authorized_keys file for the presence of the key defined in the .env variable SSH_KEY. If the key is not already present, it appends the key to the file, ensuring Ansible has the necessary access.

***IMPORTANT***: Make sure the following variables are set based upon your specifications

*Script*
```
ENV_URL=
USER_NAME=
```
*.env*
```
SSH_KEY=
```


# 📜 License & Disclaimer

This repository is licensed under the terms of the **GNU General Public License v3.0 (GPLv3)**.  
You are free to use, modify, and distribute this code, provided that any derivative works are also licensed under the GPLv3.  

See the [LICENSE](LICENSE) file for the complete license text.

---

> ⚠️ **Disclaimer**  
> The scripts and configurations provided in this repository are offered **as-is** with no guarantees or warranties, express or implied. Use of these materials is entirely at your own risk.  
>   
> The author assumes no responsibility or liability for any issues, damages, or unintended consequences that may arise from using the contents of this repository.  
>   
> Before implementing anything here, you should:  
> - Review and understand the code thoroughly.  
> - Test in a **non-production** environment.  
> - Tailor all configurations and scripts to your **specific environment, security requirements, and use cases**.  
>   
> By using these materials, you acknowledge that you are solely responsible for any outcomes, including system changes, data loss, or security implications.
