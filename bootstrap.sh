#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$repo/bin/.linukkusu.sh"
[[ $# == 0 ]] || linukkusu_die 'Usage: ./bootstrap.sh'

# Official release asset digest from the MSYS2 GitHub release API.
archive=msys2-base-x86_64-20260611.sfx.exe
archive_sha256=c105946e64e08f099ac0e4647461ce762b95333ad211777666476a9a41451d65
archive_url="https://github.com/msys2/msys2-installer/releases/download/2026-06-11/$archive"
for tool in curl sha256sum cygpath mktemp mv mkdir cp chmod rm rmdir; do
    command -v "$tool" >/dev/null || linukkusu_die "Missing Git for Windows tool: $tool"
done

# Validate before downloading or changing an existing installation.
packages=()
while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || linukkusu_die "Invalid package entry: $line"
    packages+=("$line")
done < "$repo/packages/base.txt"
(( ${#packages[@]} > 0 )) || linukkusu_die 'The package list is empty.'

mkdir -p -- "$HOME/.dev"
lock="$HOME/.dev/.linukkusu-bootstrap.lock"
mkdir -- "$lock" 2>/dev/null || linukkusu_die "Bootstrap already running, or stale lock: $lock"
trap 'rmdir -- "$lock"' EXIT

if [[ ! -e "$linukkusu_root" ]]; then
    staging=$(mktemp -d "$HOME/.dev/.linukkusu-download.XXXXXXXX")
    printf 'Downloading %s\n' "$archive"
    # Retain staging on failure for diagnosis; never erase an existing install.
    printf 'Staging directory: %s\n' "$staging"
    curl --fail --location --retry 3 --proto '=https' --proto-redir '=https' \
        --output "$staging/$archive" "$archive_url"
    (cd -- "$staging" && printf '%s  %s\n' "$archive_sha256" "$archive" | sha256sum -c -)
    staging_win=$(cygpath -am "$staging")
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
        "$staging/$archive" -y "-o$staging_win"
    [[ -x "$staging/msys64/usr/bin/bash.exe" ]] || linukkusu_die 'Archive extraction failed.'
    printf '%s\n' "$archive" > "$staging/msys64/.linukkusu-install"
    mv -T -- "$staging/msys64" "$linukkusu_root"
    rm -- "$staging/$archive"
    rmdir -- "$staging"
elif [[ ! -f "$linukkusu_root/.linukkusu-install" ]]; then
    linukkusu_die "Refusing to modify an unrecognized installation: $linukkusu_root"
fi

# The first login runs /etc/post-install scripts, including pacman key setup.
# Run it to completion BEFORE updating, and repeat safely on subsequent runs.
linukkusu_run /usr/bin/true
linukkusu_update
linukkusu_run /usr/bin/pacman --noconfirm -S --needed -- "${packages[@]}"
linukkusu_refresh_certificates

mkdir -p -- "$HOME/.dev/bin"
for launcher in .linukkusu.sh dev dev-run dev-update; do
    cp -- "$repo/bin/$launcher" "$HOME/.dev/bin/$launcher"
    chmod +x -- "$HOME/.dev/bin/$launcher"
done
printf '\n%s\n' 'Linukkusu is ready. Add this to your Git Bash ~/.bashrc if needed:'
printf '%s\n' 'export PATH="$HOME/.dev/bin:$PATH"' 'Then run: dev'
