# 📘 AppBuilder Proxmox CT Deployment Script (ZFS/LVM Safe)

This script creates a Debian CT on Proxmox with **Docker** pre-installed and an optional user (SSH key or password). It supports both **ZFS (ZPool1)** and **LVM-thin (local-lvm)** safely.

---

## ⚠️ ZFS Rule (Important)
When using ZFS, pass the root disk size as a **plain integer** (no `G`). The script does this by calling:

```bash
pct create ... -storage ZPool1 -rootfs 100   # 100 GiB on ZFS
```

Proxmox will auto-create the correct `subvol-<VMID>-disk-0` dataset. Do **not** pass `100G`, dataset names, or `size=` with ZFS in `pct create`.

For LVM-thin, the same integer form is accepted and interpreted as GiB.

---

## 🚀 Quick Start

Run on your Proxmox host:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/tonyfitzs/proxmox-appbuilder-scripts/main/create-debian-ct.sh)"
```

You will be prompted to:
1) Pick a profile (resources + disk size)  
2) Choose storage (ZPool1 or local-lvm)  
3) Optionally create a user (SSH key or password)  

---

## ✅ After It Runs

- CT is created on the chosen storage.  
- Docker + Compose are installed.  
- Enter the CT with:
  ```bash
  pct enter <VMID>
  ```
  or SSH to your created user:
  ```bash
  ssh <user>@<CT-IP>
  ```

---

## 🧪 Manual ZFS Sanity Test

If you want to test the creation manually, this is the working ZFS form:
```bash
VMID=$(pvesh get /cluster/nextid)
pct create $VMID local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst       -storage ZPool1 -rootfs 100       -cores 2 -memory 2048       -net0 name=eth0,bridge=vmbr0,ip=dhcp       -hostname testzfs -password changeme
```
