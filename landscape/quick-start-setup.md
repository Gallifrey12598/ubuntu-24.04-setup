# Minimum Requirements
- **Operating System:** Ubuntu 22.04 LTS (Jammy Jellyfish) or Ubuntu 24.04 LTS (Noble Numbat)
- **Hardware:** A dual-core 2 GHz processor, 4 GB of RAM, and 20 GB of disk space
- **Networking:** An IP address and FQDN with TCP communication allowed for:
  - SSH (typically port 22)  
  - HTTP (port 80)  
  - HTTPS (port 443)  
- **SSL Certificates:** If you plan to use Let's Encrypt, you’ll need DNS administration access for the hostname used to access Landscape.

# My Use Case
For my use case in the current environment, we are utilizing Google Cloud Workspace. I have implemented the following:

```sh
Instance Type
- General Purpose E2 (e2-standard-4) 4 vCPU, 2 Core, 16 GB memory
- Storage 250 GB Balanced persistance disk
- Ubuntu 24.04 LTS Minimal
- Networking: Allow HTTP, HTTPS and gave it a persistant Private and Public IP
```

I also attached it to a private VPC network and updated firewall rules to allow specified traffic to the internet.  
I highly recommend utilizing a VPC along with granular firewall rules if this is deployed in a cloud environment.  
Make sure to secure the service if it can be accessed from the public internet.  

## Set up the Server

### Install prerequisites

```bash

sudo apt update && sudo apt install -y ca-certificates software-properties-common

```

**Set Enviroment Variables**

```bash

HOST_NAME={HOST_NAME}
DOMAIN={DOMAIN_NAME}
FQDN=$HOST_NAME.$DOMAIN

```
**Set Machine Hostname**

```bash

sudo hostnamectl set-hostname "$FQDN"

```

**Install landscape-server-quickstart**

```bash

sudo add-apt-repository -y ppa:landscape/self-hosted-24.04
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y landscape-server-quickstart

```