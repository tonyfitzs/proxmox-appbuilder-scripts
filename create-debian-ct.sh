#!/bin/bash
# Proxmox Debian CT creation script (ZFS/LVM safe) with Docker and optional user
set -e

echo "Choose profile:"
echo "1) Minimum (2 vCPU, 4GB RAM, 50GB disk)"
echo "2) Comfortable (4 vCPU, 8GB RAM, 100GB disk)"
echo "3) Production-Ready (8 vCPU, 16GB RAM, 500GB disk)"
read -p "Enter choice [1-3]: " choice
case $choice in
  1) CPUS=2; RAM=4096;  DISK=50;  PROFILE="Minimum" ;;
  2) CPUS=4; RAM=8192;  DISK=100; PROFILE="Comfortable" ;;
  3) CPUS=8; RAM=16384; DISK=500; PROFILE="Production-Ready" ;;
  *) echo "Invalid choice."; exit 1 ;;
esac

echo "Choose rootfs storage:"
echo "1) ZPool1 (ZFS, huge space)  [default]"
echo "2) local-lvm (LVM-thin, small tests only)"
read -p "Enter choice [1-2]: " storage_choice
case $storage_choice in
  1|"") STORAGE="ZPool1" ;;
  2)      STORAGE="local-lvm" ;;
  *)      STORAGE="ZPool1" ;;
esac

read -p "Create a non-root user? (y/n): " CREATEUSER
if [[ $CREATEUSER =~ ^[yY]$ ]]; then
  read -p "Username: " NEWUSER
  echo "Login method:"
  echo "1) Public key (recommended)"
  echo "2) Username + password"
  read -p "Enter choice [1-2]: " LOGINMETHOD
fi

VMID=$(pvesh get /cluster/nextid)
echo "Creating Debian CT ($PROFILE) on $STORAGE as VMID $VMID..."

# IMPORTANT: For ZFS use integer size so Proxmox auto-creates subvol;
# for LVM this is also accepted and interpreted as GiB.
pct create "$VMID" local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst       -cores "$CPUS"       -memory "$RAM"       -swap 512       -storage "$STORAGE"       -rootfs "$DISK"       -hostname debian-appbuilder       -net0 name=eth0,bridge=vmbr0,ip=dhcp       -password changeme

pct start "$VMID"

pct exec "$VMID" -- bash <<'EOF'
set -e
apt update
apt install -y ca-certificates curl wget git gnupg lsb-release sudo
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
EOF

if [[ $CREATEUSER =~ ^[yY]$ ]]; then
  if [[ "$LOGINMETHOD" == "1" ]]; then
    read -p "Paste SSH public key: " PUBKEY
    pct exec "$VMID" -- bash -c "
      adduser --disabled-password --gecos \"\" $NEWUSER &&
      usermod -aG docker,sudo $NEWUSER &&
      mkdir -p /home/$NEWUSER/.ssh &&
      echo \"$PUBKEY\" > /home/$NEWUSER/.ssh/authorized_keys &&
      chmod 700 /home/$NEWUSER/.ssh &&
      chmod 600 /home/$NEWUSER/.ssh/authorized_keys &&
      chown -R $NEWUSER:$NEWUSER /home/$NEWUSER/.ssh
    "
    echo "✅ User '$NEWUSER' created with SSH key login."
  else
    read -s -p "Password for $NEWUSER: " USERPASS; echo
    pct exec "$VMID" -- bash -c "
      adduser --gecos \"\" $NEWUSER &&
      echo \"$NEWUSER:$USERPASS\" | chpasswd &&
      usermod -aG docker,sudo $NEWUSER
    "
    echo "✅ User '$NEWUSER' created with password login."
  fi
fi

echo "✅ CT $VMID ready. To enter: pct enter $VMID"
