# Day 01 — Linux Filesystem Deep Dive
linux-mastery

---

## Why This Matters

Every infrastructure decision you make — containers, CI/CD pipelines, Kubernetes volumes, observability agents — lives inside the Linux filesystem. Understanding it at the inode level separates engineers who debug fast from those who guess.

---

## 1. The Filesystem Hierarchy Standard (FHS)

Linux follows a tree structure rooted at `/`. Every file, device, and process lives here.

```
/
├── etc/       # System-wide configuration files
├── var/       # Variable data (logs, caches, spools)
├── proc/      # Virtual FS: kernel & process info (live)
├── sys/       # Virtual FS: hardware & driver info (live)
├── home/      # User home directories
├── bin/       # Essential user binaries
├── sbin/      # System binaries (root use)
├── usr/       # Secondary hierarchy (apps, libraries)
├── tmp/       # Temporary files (cleared on reboot)
├── dev/       # Device files
├── mnt/       # Temporary mount points
└── opt/       # Optional/third-party software
```

---

## 2. The Critical Directories

### /etc — The Configuration Brain
Everything that tells Linux *how to behave*.

```bash
/etc/
├── passwd          # User accounts (not actual passwords)
├── shadow          # Hashed passwords (root only)
├── hosts           # Static hostname-to-IP mappings
├── fstab           # Filesystem mount table (auto-mount on boot)
├── resolv.conf     # DNS resolver config
├── cron.d/         # Scheduled tasks
├── ssh/            # SSH daemon config
├── nginx/          # Nginx config (if installed)
└── systemd/        # Systemd service definitions
```

**Key commands:**
```bash
cat /etc/fstab              # View all auto-mounted filesystems
cat /etc/os-release         # Distro info
ls /etc/systemd/system/     # Active systemd services
```

---

### /var — The Living Data Directory
Data that *changes* at runtime — logs, mail spools, package databases.

```bash
/var/
├── log/            # System & application logs
│   ├── syslog      # General system events (Debian/Ubuntu)
│   ├── messages    # General events (RHEL/CentOS)
│   ├── auth.log    # Authentication logs
│   └── nginx/      # App-specific logs
├── cache/          # Package manager & app caches
├── lib/            # Persistent app state (databases, etc.)
├── spool/          # Print queues, mail queues
└── run/            # Runtime data (PIDs, sockets)
```

**Key commands:**
```bash
tail -f /var/log/syslog         # Live log tailing
journalctl -u nginx --since today   # Systemd journal for nginx
du -sh /var/log/*               # Log sizes
```

---

### /proc — The Kernel's Window
A *virtual filesystem* — nothing is on disk. The kernel generates this in memory dynamically. It's how you talk to the running kernel.

```bash
/proc/
├── cpuinfo         # CPU model, cores, flags
├── meminfo         # RAM usage breakdown
├── loadavg         # System load (1/5/15 min averages)
├── uptime          # System uptime in seconds
├── version         # Kernel version
├── mounts          # Currently mounted filesystems
├── net/            # Network stats (interfaces, connections)
├── sys/            # Tunable kernel parameters
└── <PID>/          # Per-process directory
    ├── cmdline     # How the process was launched
    ├── status      # Memory, UID, state
    ├── fd/         # Open file descriptors
    └── maps        # Memory mappings
```

**Key commands:**
```bash
cat /proc/cpuinfo               # CPU details
cat /proc/meminfo               # Memory breakdown
cat /proc/$(pgrep nginx)/status # Nginx process status
ls /proc/$(pgrep nginx)/fd      # Open files of nginx
cat /proc/loadavg               # Load averages
```

---

### /sys — The Hardware Interface
Another virtual filesystem. Maps kernel objects to a browseable tree. Used to inspect and configure hardware, drivers, and kernel subsystems.

```bash
/sys/
├── block/          # Block devices (disks, partitions)
├── bus/            # Hardware bus types (PCI, USB)
├── class/          # Device classes (net, input)
│   └── net/        # Network interfaces
├── devices/        # Device tree
└── kernel/         # Core kernel parameters
```

**Key commands:**
```bash
ls /sys/class/net/                    # All network interfaces
cat /sys/block/sda/queue/scheduler    # I/O scheduler for sda
cat /sys/class/net/eth0/speed         # NIC speed (Mbps)
```

---

## 3. Mount Points

A **mount point** is a directory where a filesystem is attached to the tree. The kernel maps device → directory.

```bash
# View all mounts
mount
cat /proc/mounts

# Mount a device
mount /dev/sdb1 /mnt/data

# Mount with options
mount -o ro,noexec /dev/sdb1 /mnt/backup

# Unmount
umount /mnt/data

# Auto-mount via /etc/fstab
# <device>          <mountpoint>  <type>  <options>    <dump> <pass>
UUID=abc123...      /             ext4    defaults      1      1
/dev/sdb1           /data         xfs     defaults      0      2
tmpfs               /tmp          tmpfs   size=1G       0      0
```

**Common mount options:**
| Option | Meaning |
|--------|---------|
| `ro` | Read-only |
| `rw` | Read-write (default) |
| `noexec` | Prevent execution of binaries |
| `nosuid` | Ignore setUID bits |
| `nodev` | Ignore device files |
| `defaults` | rw, suid, dev, exec, auto, nouser, async |

---

## 4. Inodes — The Filesystem's DNA

An **inode** stores metadata about a file — everything *except* the filename and the file's actual data.

**What an inode contains:**
- File type (regular, directory, symlink, device...)
- Owner (UID) and group (GID)
- Permissions (rwxrwxrwx)
- Timestamps: atime (last accessed), mtime (last modified), ctime (last changed)
- File size
- Number of hard links
- Pointers to data blocks on disk

**The filename lives in the directory entry, not the inode.**

```bash
# View inode number
ls -i /etc/hosts
stat /etc/hosts         # Full inode details

# Count free inodes (can run out before disk space!)
df -i
```

**Pro tip for DevOps:** Disk can show space available but still fail writes if inodes are exhausted. Always monitor both with `df -h` AND `df -i`.

---

## 5. Hard Links vs Soft Links

### Hard Links
- Points **directly to the same inode**
- Deleting the original doesn't delete the data (until all hard links removed)
- Cannot span filesystems
- Cannot link to directories

```bash
ln /etc/hosts /tmp/hosts-hardlink
ls -li /etc/hosts /tmp/hosts-hardlink   # Same inode number!
```

### Soft Links (Symlinks)
- A file that **stores the path** to another file
- If original is deleted → dangling symlink (broken)
- Can span filesystems and link to directories
- Used everywhere in Linux (version management, Kubernetes config, etc.)

```bash
ln -s /etc/nginx/nginx.conf /tmp/nginx-link
ls -la /tmp/nginx-link                  # Shows -> target
readlink /tmp/nginx-link                # Print target path
find /etc -type l                       # Find all symlinks
```

**Visual:**
```
Hard link:   filename-A ─┐
                          ├─► INODE → Data blocks
             filename-B ─┘

Soft link:   filename-A ─── INODE-A → "path/to/filename-B"
                                              │
             filename-B ──────── INODE-B ◄───┘
```

---

## 6. Permission Bits

### The Permission Model
```
-  rw-  r--  r--
│   │    │    │
│   │    │    └── Other (everyone else)
│   │    └─────── Group
│   └──────────── User (owner)
└──────────────── File type (- file, d dir, l link, b block, c char)
```

### Numeric Notation
| Symbolic | Numeric | Meaning |
|----------|---------|---------|
| `rwx` | 7 | Read + Write + Execute |
| `rw-` | 6 | Read + Write |
| `r-x` | 5 | Read + Execute |
| `r--` | 4 | Read only |
| `---` | 0 | No permissions |

```bash
chmod 755 script.sh     # rwxr-xr-x
chmod 644 config.yml    # rw-r--r--
chmod +x deploy.sh      # Add execute for all
chmod u+x,g-w file      # Add exec for owner, remove write for group

chown user:group file   # Change owner and group
chown -R www-data:www-data /var/www/  # Recursive

# View permissions
ls -la /etc/shadow      # -rw-r----- (640)
stat --format="%a %n" /etc/shadow   # Show octal
```

### Special Bits
| Bit | Octal | Effect |
|-----|-------|--------|
| SetUID (SUID) | 4000 | Executes as file owner |
| SetGID (SGID) | 2000 | Executes as group owner |
| Sticky bit | 1000 | Only owner can delete (e.g., /tmp) |

```bash
chmod u+s /usr/bin/passwd   # SUID: runs as root
chmod g+s /shared/dir/      # SGID: new files inherit group
chmod +t /tmp               # Sticky: only owner deletes
ls -la /tmp                 # Shows drwxrwxrwt
```

---

## 7. Essential Tools

### df — Disk Filesystem Usage
```bash
df -h                   # Human-readable disk space
df -hT                  # Include filesystem type
df -i                   # Inode usage (critical!)
df -h /var/log          # Specific path
```

### du — Disk Usage (Files & Dirs)
```bash
du -sh /var/log/        # Summary of directory
du -sh /var/log/*       # Each item in directory
du -sh /* 2>/dev/null   # Top-level usage
du -ah /etc/ | sort -rh | head -20  # Top 20 largest files
```

### lsblk — List Block Devices
```bash
lsblk                   # Tree view of all block devices
lsblk -f                # Include filesystem type and UUID
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE
```

### fdisk — Partition Management
```bash
fdisk -l                # List all partitions
fdisk /dev/sdb          # Interactive partition editor
# Commands inside fdisk: p (print), n (new), d (delete), w (write), q (quit)

# Modern alternative
parted -l               # List with more info
gdisk /dev/sdb          # GPT partition editor
```

### mount
```bash
mount                   # Show all mounts
mount | grep ext4       # Filter by type
mount -t tmpfs tmpfs /mnt/ramdisk -o size=512M  # Create ramdisk
```

---

## 8. DevOps Real-World Scenarios

### Scenario 1: "Disk is full but df shows space"
```bash
df -i               # Inodes exhausted!
find / -xdev -printf '%h\n' | sort | uniq -c | sort -k 1 -rn | head   # Most files in dir
```

### Scenario 2: Container volume debugging
```bash
lsblk -f            # Find the backing device
mount | grep overlay    # Docker uses overlay2
ls /proc/mounts     # What's actually mounted
```

### Scenario 3: Log rotation not working
```bash
ls -la /var/log/nginx/          # Check symlinks and permissions
stat /var/log/nginx/access.log  # Check inode & timestamps
du -sh /var/log/                # How much space logs use
```

### Scenario 4: Permission denied in CI/CD
```bash
ls -la /path/to/file    # Check permission bits
stat /path/to/file      # Full details
id                      # Who am I?
groups                  # What groups?
namei -l /path/to/file  # Permission check on every path segment
```

---

## 9. Summary Cheatsheet

| Tool | Use Case |
|------|----------|
| `df -h` | Disk space by filesystem |
| `df -i` | Inode usage |
| `du -sh *` | Size of each item |
| `lsblk -f` | Block devices + filesystems |
| `mount` | View/add mounts |
| `fdisk -l` | Partition layout |
| `stat` | Full file metadata |
| `ls -li` | Show inodes |
| `ln` / `ln -s` | Hard / soft links |
| `chmod` / `chown` | Permissions / ownership |
| `namei -l` | Trace path permissions |
| `cat /proc/mounts` | Kernel-level mount view |

---

## Resources
- `man hier` — Linux filesystem hierarchy manual
- `man fstab` — fstab format reference
- `man inode` — Inode internals

---

*Day 01/365 — linux-mastery*
