# Boxctl server

Open and self-hosted deployment solution for node apps.

## Installation

Boxctl needs a clear ubuntu server 22.04 or 24.04 with a user with sudo access. Some VPS providers directly give you a user with sudo access, but some gives you only a root user. In that case, you can create a new user and add it to sudoers.

### prerequisites

```bash
# Create a new user boxadmin
useradd -m -s /bin/bash -G sudo boxadmin
passwd boxadmin

# Setup ssh for new user
mkdir -p /home/boxadmin/.ssh
cp /root/.ssh/authorized_keys /home/boxadmin/.ssh/authorized_keys
chown -R boxadmin:boxadmin /home/boxadmin/.ssh
chmod 700 /home/boxadmin/.ssh
chmod 600 /home/boxadmin/.ssh/authorized_keys
```

### install

```bash
curl "https://raw.githubusercontent.com/boxctl/server/refs/heads/main/install.sh" | bash
```
