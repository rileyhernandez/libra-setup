# libra-setup

A Debian package to configure an `arm64` system for use with Phidgets devices.

## Overview

The `libra-setup` package simplifies the configuration of a Debian-based `arm64` (aarch64) system after installing the Phidgets library (`libphidget22`). It automates two crucial setup steps:
1.  Setting correct device permissions via a `udev` rule.
2.  Creating a required symbolic link for the `libphidget22` shared library.

This package also installs and manages a systemd service to run a background application.
This ensures that applications can seamlessly discover and communicate with Phidgets hardware without requiring root privileges or manual file system changes.

## Features

-   **Automatic Udev Rule**: Installs a `udev` rule that grants non-root users read/write access to Phidgets USB devices.
-   **Library Symlink**: Creates a symbolic link from the versioned `libphidget22.so.0` to the unversioned `libphidget22.so`, which is often required by applications.
-   **Dependency Management**: Declares dependencies on `libphidget22` and `libssl-dev` for automatic installation.
-   **Systemd Service**: Installs, enables, and starts a systemd service for a background process.
-   **Clean Uninstallation**: Removes all created files and links when the package is uninstalled.
-   **Architecture Specific**: Tailored for `arm64` (aarch64) systems.

## Prerequisites

-   A Debian-based `arm64` system (e.g., Ubuntu, Raspberry Pi OS 64-bit).
-   The `libphidget22` and `libssl3` packages must be available in your configured APT repositories.

To build the package from source, you will also need `curl` and `dpkg-dev` installed.

## Building the Package

To build the `.deb` package, run the `build-setup.sh` script from the project's root directory (the parent directory of `libra-setup`).

```bash
./build.sh
```

This will generate a `.deb` file (e.g., `libra-setup_1.0-1_arm64.deb`), ready for installation.

## Installation

Install the generated `.deb` package using `apt`. Using `apt` is recommended as it will automatically resolve and install the required dependencies (`libphidget22`, `libssl-dev`).

```bash
sudo apt install ./libra-setup_1.0-1_arm64.deb
```
*(Replace the filename with the one you generated).*

## How It Works

### Udev Rule

The package installs a rule at `/etc/udev/rules.d/99-libphidget.rules`:

```
SUBSYSTEMS=="usb", ACTION=="add", ATTRS{idVendor}=="06c2", ATTRS{idProduct}=="00[3-a][0-f]", MODE="666"
```

This rule does the following:
-   It triggers when a USB device (`SUBSYSTEMS=="usb"`) is connected (`ACTION=="add"`).
-   It matches Phidgets devices using their vendor ID (`ATTRS{idVendor}=="06c2"`) and a range of product IDs.
-   It sets the device file permissions to `666` (`MODE="666"`), allowing any user on the system to read from and write to the device. This is essential for applications that need to communicate with Phidgets but are not run as the root user.

### Symbolic Link

The `postinst` script, which runs after installation, creates a symbolic link:

```bash
ln -s /lib/aarch64-linux-gnu/libphidget22.so.0 /usr/lib/libphidget22.so
```

The `libphidget22` package installs its shared library with a version number (`libphidget22.so.0`). However, applications are often linked against the unversioned name (`libphidget22.so`). This symbolic link ensures that the system's dynamic linker can find the library, allowing such applications to run correctly.

### Systemd Service

The package installs a systemd service file at `/etc/systemd/system/libra.service`. The `postinst` script then enables this service to start on boot and starts it immediately.

The service is configured to run an application from a fixed path and restart it automatically if it fails.

```
[Service]
ExecStart=/home/pi-zero/libra-inventory/target/release/libra-inventory
Restart=always
```

## Uninstallation

You can remove the package using `apt`:

```bash
sudo apt remove libra-setup
```

The `postrm` script will automatically remove the symbolic link and the `udev` rule, ensuring your system is returned to its original state.
