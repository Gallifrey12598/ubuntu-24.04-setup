# Setting Up a Windows 11 Virtual Machine in VMware Workstation on Ubuntu

To get started, download the **Windows 11 ISO** file hosted on the FTP server.

## 1. Download the Windows 11 ISO
Open a terminal window and navigate to the directory where you want to save the ISO.  
In this example, we’ll use the user’s **Documents** folder:

```bash
cd /home/instructor/Documents
curl http://{SERVER-IP}/windows/windows11.iso -o windows11.iso
```

> **Note:** Keep track of the location where you saved the ISO — you’ll need it later.

---

## 2. Create a New Virtual Machine
1. Open **VMware Workstation**.  
2. Go to **File > New Virtual Machine**.  
3. Select **Typical (recommended)** and click **Next**.  
4. Choose **Use ISO image file**.  
5. Click **Browse**, navigate to where you saved the `windows11.iso`, select it, and click **Open**.  
6. Click **Next**.

---

## 3. Configure the Virtual Machine
1. Enter a name for your virtual machine.  
2. Keep the default location and click **Next**.  
3. When prompted for TPM (Trusted Platform Module), set a **password**, confirm it, and click **Next**.  
4. Set the **disk size** to **64 GB**, and ensure **Split virtual disk into multiple files** is checked.  
5. Click **Next**.

---

## 4. Adjust Hardware Settings
Before finishing, customize the hardware as follows:

```
Memory: 8192 MB (8 GB)
Processors: 1 processor, 4 cores
Network Adapter: Ensure this option is NOT set to "Connect at power on" or "Connected"
```

> The VM should not have access to the internet until after the initial setup has been completed.

Click **Finish** to create the virtual machine.

---

## 5. Power On and Install Windows 11
- The virtual machine should power on automatically.  
  If not, right-click the VM → **Power** → **Start Up Guest**.  
- Proceed through the normal Windows 11 installation steps:
  - When prompted for a product key, select **“I don’t have a product key.”**
  - Choose **Windows 11 Pro for Workstations** as the version.
  - On the drive selection screen, highlight **Disk 0** and click **Next**.
  - On the “Ready to Install” screen, click **Install**.

---

The installation process will begin. This may take some time, and the virtual machine will reboot automatically several times during setup.

---

## 6. Post-Installation Instructions
Once the installation is complete, you’ll be prompted with the Windows initial setup. While mostly self-explanatory, follow the additional steps below for local account setup.

1. On **“Is this the right country or region?”**, select **United States** and click **Yes**.  
2. For your keyboard layout, select your preferred layout and click **Yes**.  
3. Click **Skip** on **“Want to add a second keyboard layout?”**  
4. When prompted with **“Let’s connect you to a network”**, perform the following:

```
Hold down Shift + F10 (use the fn key if necessary)
Type: start ms-cxh:localonly
Press Enter
This will open the Local Account Setup dialog.
Set a username and password.
Choose and answer your security questions.
Click Next.
Windows 11 setup will continue.
```

5. Under **“Choose privacy settings for your device”**, set all options to **No** and click **Accept**.  
6. You should now arrive at the Windows desktop as your new local user. You can now safely connect the device to the internet.

---

## 7. Connect the Network Adapter
1. In VMware Workstation, right-click your virtual machine and select **Settings**.  
2. In the pop-up window, click **Network Adapter**.  
3. Under **Device Status**, check both **Connected** and **Connect at power on**.  
4. Click **Save**.

---

Your Windows 11 virtual machine setup is now complete and ready for use.
