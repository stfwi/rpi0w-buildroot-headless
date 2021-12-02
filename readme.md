
## Lightweight Buildroot Headless System for Raspberry Pi Zero W

This small project is a boiler plate to build a self-made linux operating system tailored to your
application. It is mainly a wrapper around [Buildroot](https://buildroot.org/), including inital
configurations for system, kernel, and busybox, as well as some configuration files added to the
target root file system. The resulting output SD-card image can be installed e.g. using the
[Raspberry Pi Imager](https://www.raspberrypi.com/software/). The project adds a headless setup
script to the boot process, so that you can define WiFi access to your LAN, initial user, hostname,
and more, by copying a file into the boot partition after the SD-card image is installed. This
also works under Windows, as the boot patition has a FAT filesystem. Building was tested under
Ubuntu 20.04, and also under Windows WSL2.

You connect to the RPi **via SSH** (if you have GIT installed you already have `ssh`). For
**default user/password** see section *System and Packages*.

**Metrics:**

 - Kernel boot time about 4s, additional 4s for the `init`. Wifi connection established after 15s
   to 30s. (First boot takes longer because e.g. SSH generates its server keys).

 - Effective rootfs size 39M, from which 27M in `usr/lib` (shared libs and kernel modules), and 6M
   in `usr/bin`. Total SD card image is 124M (including boto partition and reserve).


### Prerequisites and initial Build

First we install common build packages for linux and some additional helpers specified in the
Buildroot manual, then get the repository, and run the `init` Makefile target to download buildroot
and start building the host toolchain (SDK). Once this is done, the target system can be composed:

  ```sh
  # Prerequisites
  sudo apt install binutils build-essential perl rsync bc cpio make unzip file ncurses-bin wget curl git zip
  git clone https://github.com/stfwi/rpi0w-buildroot-headless.git rpi0w
  # Buildroot init
  cd rpi0w
  make init
  # Initial target build
  make dist
  ```

After all that there is a `dist` directory with the images in your project root. When `init` is
executed, a few folders are added to the initially cloned directory structure, it should look like
this:

  - `.archive`: Contains the downloaded buildroot tarball and the `download-cache` where buildroot
    itself stores fetched sources.

  - `buildroot`: The main buildroot directory extracted from the downloaded tarball. For BR it is
    the `$(TOPDIR)`.

  - `configuration`: The configs fetched with this repository. Also a good playground to start with.

  - `headless`: The headless setup examples fetched with this repository. Read below.

  - `toolchain`: Generated while building the SDK. It contains a tarball that Buildroot will extract
    and use to compile/compose the target files. Having an SDK saves a lot of time. (Additionally to
    that you can enable the "compiler cache" feature in the Buildroot config).

### Headless Setup

This section relates to how an individual RPi system is set up after you have build the image and
transferred it to a SD-card. Is's based on a simple boot script `/etc/init.d/S02setup`, which quickly
seaches the boot partition for something like `setup.*`. When found, the file is *moved* to `/tmp`,
extracted, and the contained `setup.sh` executed. That's where you take over to modify the system
(as `root` user) however you like.

The example is in `headless/example`. You can copy and modify it, e.g.:

  ```sh
  cp -r headless/example/setup headless/
  # -- edit files
  tar cf setup.tar setup/
  # -- copy setup.tar to boot partition
  ```

File formats can be `setup.zip`, `setup.tar`, `setup.tgz`, or just the `setup.sh` directly. It does
not matter if `setup.sh` is marked executable, the `S02setup` script will do that implicity.

Once you logged in, you can disable further headless setup checks by switching to the root user
(`sudo su -l`) and invoking `setup-done`, which is in the `.local/bin` directory of the root user.
The script deletes itself and `/etc/init.d/S02setup`.

***Windows users: Careful*** that you use an editor that saves `UTF-8` encoding and `LF` line endings
(not `CRLF`), otherwise you may run into trouble. Linux us `LF` land.

### Relay Makefile

The `Makefile` in the root directory of this project encapsulates the most important Buildroot
commands, provides some additional tasks to save and restore snapshots of your config, and helps
initializing the build system according to the Buildroot documentation:

  - `init`: Downloads and extracts Buildroot, initializes the directory structure builds the SDK,
    applies the initial target config (br, linux, busybox).

  - `backup-config`: Copies the configs and current menuconfig snapshots (`.config`) or Buildroot,
    Kernel, and Busybox into `configuration/br-config`, and updates the minimized config files.

  - `restore-config`: The reverse of `backup-config`. Different from the known `make defconfig`,
    it writes the default config locations and the `.config` files. Just a convenience thing.

  - `dist`: Invokes Buildroot `make`, and copies the image output files into `dist`.

  - `menuconfig`: Invokes the Buildroot main configuration.

  - `busybox-menuconfig`: Invokes the Buildroot Busybox configuration.

  - `linux-menuconfig`: Invokes the Buildroot Kernel configuration.

  - `clean`: Invokes Buildroot `make clean`.

  - `build`: Invokes Buildroot `make`.

  - `rebuild-images`: Invalidates installed packages and forces Buildroot to re-compose the rootfs.

### System and Packages

- Default hostname is `pi0w`, default root password `root` (extremely safe, ***please change it***
  first thing in the morning, or directly in your headless `setup.sh` script).

- Default user is `admin` with the very creative password `admin` (also ***extremely safe***). If
  you use a headless setup script and define an own user anyway, add `deluser admin` to your script,
  or at least change the password.

- Image size is 32MB bootloader (FAT partition) + 92MB file system (ext4 root file system). You can
  decide weather to e.g. extend the rootfs partition or add a third data partition.

- Directories `/tmp` and `/var/log` are volatile (RAM based `tmpfs`) to inhibit SD-card wear-off,
  most importantly `/var/log/messages` is volatile and gone at the next boot.

- Busybox used where possible for the common unix tools to save space. That means the shell is `ash`,
  not `bash`, and basic utilities (`/bin`, `/usr/bin`, etc) are symlinked to `busybox`.

- Additional packages: `xz-utils`, `tree`, `openssl`, `openssh`, `wpa_supplicant`, `wireless-regdb`,
  `sudo`, `nano`.

- Basic security features included are `iptables` and `apparmor`. The default config restricts
  incoming requests to your LAN (`fe80::/64`, `192.168.0.0/16`, `172.16.0.0/12`, `10.1.0.0/16`). There
  are initially no apparmor profiles active.

- Init system is Busybox `init`, which is similar to sysv. All init scripts are directly in `/etc/init.d`,
  which is for small embedded systems very simple to handle.

- Dynamic hardware is handled with `devtmpfs+mdev`, similar to `udevd` known from `systemd` but simpler.
  The Kernel detects that hardware is added or removed, and informs `mdev` via the `sysfs`. In turn, `mdev`
  adds/removes the device node in `/dev` and can run a script accordingly. Control file is `/etc/mdev.conf`.

- The Kernel is configured to contain the basic drivers needed for the Pi chip (BCM2835), the most used
  filesystems (`ext4`, `fat32`, `exfat`, `ntfs`), networking basics (WiFi/PHY, `ipv6`, `ipv4`, unix
  sockets, `iptables`, `smb`, Bluetooth). Stuff like audio, force-feedback joyticks, printers, or USB-Gadget,
  are omitted. Left in are drivers related to the RasPi pin header, and USB storage devices. Means, e.g.
  GPIO, SPI, I2C, OneWire, CAN, and a careful selection of bus devices are usable. Kernel preemption is
  enabled (only `PREEMPT`, not `PREEMPT_RT`).

### Conclusions/Notes/References

In short, it's a boiler plate to get started, or to start a new project. You already have Wifi, SSH, headless
setup, and basic security features like incoming connections restricted to your LAN. You add what else you
need or like to experiment with. One of the very nice things about minimalistic Buildroot or Yocto setups is
that they help learning how Linux works - and also show that embedded setups do not have to be overloaded
or complex. Have fun exploring. `+++`
