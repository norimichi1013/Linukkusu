# Shared by the Git Bash launchers; never sourced inside the private MSYS2.
linukkusu_die() { printf 'Linukkusu: %s\n' "$*" >&2; exit 1; }

[[ $(uname -s) == MINGW* ]] || linukkusu_die 'Run this command from Git for Windows Git Bash.'
[[ -f /etc/package-versions.txt ]] && grep -Eq '^mingw-w64-.*-git ' /etc/package-versions.txt ||
    linukkusu_die 'Git for Windows is required as the outer shell.'

linukkusu_root="$HOME/.dev/Linukkusu"
linukkusu_bash="$linukkusu_root/usr/bin/bash.exe"

linukkusu_shell() (
    [[ -x "$linukkusu_bash" ]] || linukkusu_die 'Installation missing; run ./bootstrap.sh first.'
    local name payload payload_win cwd_win
    local -a keep=()
    # Preserve Windows facilities and terminal/proxy settings, not Git Bash's
    # PATH, startup hooks, exported functions, HOME, or toolchain variables.
    for name in SYSTEMROOT SystemRoot WINDIR COMSPEC PATHEXT USERNAME USERDOMAIN \
        USERPROFILE HOMEDRIVE HOMEPATH APPDATA LOCALAPPDATA PROGRAMDATA \
        TEMP TMP TERM COLORTERM LANG LC_ALL TZ \
        http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY; do
        [[ ! -v $name ]] || keep+=("$name=${!name}")
    done
    keep+=(PATH=/usr/bin:/bin HOME=/home/dev MSYSTEM=UCRT64
        MSYS2_PATH_TYPE=minimal CHERE_INVOKING=1)
    # Different MSYS runtime versions can lose/rewrite the environment during
    # direct spawn. Transfer data as NUL records, not Windows command-line text.
    # This also preserves empty arguments, newlines and literal POSIX paths.
    umask 077
    payload=$(mktemp)
    trap 'rm -f -- "$payload"' EXIT
    payload_win=$(cygpath -am "$payload")
    cwd_win=$(cygpath -am "$PWD")
    printf '%s\0' "${#keep[@]}" "$cwd_win" "${keep[@]}" "$@" > "$payload"
    # -p suppresses imported functions and BASH_ENV before we clear the
    # environment INSIDE the destination runtime. No user data is evaluated.
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
        "$linukkusu_bash" --noprofile --norc -p -c '
            set -euo pipefail
            mapfile -d "" -t payload < "$1"
            count=${payload[0]}
            cd -- "${payload[1]}"
            exec /usr/bin/env -i "${payload[@]:2:count}" \
                /usr/bin/bash "${payload[@]:2+count}"
        ' linukkusu "$payload_win"
)

linukkusu_run() {
    # This fixed program never interpolates user input. Restore normal MSYS2
    # native-tool conversion only AFTER crossing from the Git Bash runtime.
    linukkusu_shell -lc 'exec -- "$@"' linukkusu "$@"
}

linukkusu_refresh_certificates() {
    # Upstream p11-kit dispatch cannot quote its trust.exe path when the
    # installation contains spaces (MINGW-packages#22438). Invoke trust
    # directly, using the package's own extraction formats and destinations.
    linukkusu_run /usr/bin/bash -ec '
        [[ -x /ucrt64/bin/trust.exe ]] || exit 0
        printf "%s\n" "Refreshing UCRT64 certificate bundles (direct trust.exe invocation)..."
        dest=/ucrt64/etc/pki/ca-trust/extracted
        /ucrt64/bin/trust.exe extract --format=openssl-bundle --filter=certificates \
            --overwrite --comment "$dest/openssl/ca-bundle.trust.crt"
        for purpose in server-auth email code-signing; do
            case "$purpose" in
                server-auth) name=tls-ca-bundle.pem ;;
                email) name=email-ca-bundle.pem ;;
                code-signing) name=objsign-ca-bundle.pem ;;
            esac
            /ucrt64/bin/trust.exe extract --format=pem-bundle --filter=ca-anchors \
                --overwrite --comment --purpose "$purpose" "$dest/pem/$name"
        done
        /ucrt64/bin/trust.exe extract --format=java-cacerts --filter=ca-anchors \
            --overwrite --purpose server-auth "$dest/java/cacerts"
        test -s "$dest/pem/tls-ca-bundle.pem"
        cp -- "$dest/pem/tls-ca-bundle.pem" /ucrt64/etc/ssl/certs/ca-bundle.crt
        cp -- "$dest/pem/tls-ca-bundle.pem" /ucrt64/etc/ssl/cert.pem
        cp -- "$dest/openssl/ca-bundle.trust.crt" /ucrt64/etc/ssl/certs/ca-bundle.trust.crt
    '
}

linukkusu_update() {
    printf '%s\n' 'Close all Linukkusu shells and tasks before updating.'
    # exec replaces the inner Bash: pacman must not kill a waiting parent
    # shell and make the outer Git Bash lose the actual updater exit status.
    # -uu also allows downgrades, so a package rolled back upstream can still
    # be resolved instead of stalling the whole upgrade.
    linukkusu_run /usr/bin/pacman --noconfirm -Syuu
    # A core update exits before the rest of the system is upgraded. Start a
    # fresh runtime, using the SAME databases to avoid another core-update race.
    linukkusu_run /usr/bin/pacman --noconfirm -Suu
    linukkusu_refresh_certificates
}
