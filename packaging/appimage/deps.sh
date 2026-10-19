#!/usr/bin/env bash
# Ubuntu 22.04 packages for packaging/appimage/build.sh. Run as root (CI runs
# it with sudo; locally it runs inside an ubuntu:22.04 container).
#
# 22.04 is the build base on purpose: everything bundled from it needs at
# most glibc 2.35, so the AppImage runs on any distribution from 2022 on.

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
  ca-certificates curl file git xz-utils zsync python3 python3-venv \
  build-essential g++-12 cmake ninja-build meson pkg-config \
  libgl-dev libegl-dev libgbm-dev libdrm-dev libvulkan-dev \
  libwayland-dev libxkbcommon-dev libxkbcommon-x11-dev libfontconfig1-dev libfreetype-dev \
  libxcb1-dev libjemalloc-dev libglib2.0-dev libdbus-1-dev \
  libxcb-cursor0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 libxcb-randr0 libxcb-render-util0 \
  libxcb-shape0 libxcb-xinerama0 libxcb-xkb1 libxcb-sync1 libxcb-xfixes0 libxcb-shm0 libxcb-util1 \
  libwayland-cursor0 libwayland-egl1 libpulse0 \
  desktop-file-utils appstream procps xvfb xauth x11-utils xdotool weston
