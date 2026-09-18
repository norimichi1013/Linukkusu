#!/usr/bin/env bash
# Run from Git Bash after bootstrap; optional launcher directory for a test install.
set -euo pipefail
trap 'printf "FAIL at line %s (status %s)\n" "$LINENO" "$?" >&2' ERR
launchers=${1:-"$HOME/.dev/bin"}
launchers=$(cd -- "$launchers" && pwd)
run="$launchers/dev-run"
scratch=$(mktemp -d)
trap 'rm -f -- "$scratch/input"; rmdir -- "$scratch/project with spaces" "$scratch"' EXIT
mkdir -- "$scratch/project with spaces"
cd -- "$scratch/project with spaces"
expected_cwd=$(cygpath -aml "$PWD")

# These values must remain data, including empty arguments and shell syntax.
args=('' 'two words' '"quoted"' "it's literal" '$HOME' '$(exit 91)' '; exit 92' \
    '*' '/ucrt64/bin' 'C:\path with spaces\' $'line one\nline two' '日本語')
"$run" bash -c '
    [[ $MSYSTEM == UCRT64 ]] || exit 10
    [[ $HOME == /home/dev ]] || exit 17
    [[ -z ${MSYS_NO_PATHCONV-} && -z ${MSYS2_ARG_CONV_EXCL-} ]] || exit 18
    [[ $(cygpath -aml "$PWD") == "$1" ]] || { printf "cwd mismatch: %s / %s\n" "$PWD" "$1" >&2; exit 11; }
    [[ $PATH == /ucrt64/bin:* ]] || exit 12
    [[ $PATH != *Git/usr/bin* && $PATH != *Git/mingw64/bin* ]] || exit 13
    shift
    [[ $# == 12 && $1 == "" && $2 == "two words" && $3 == "\"quoted\"" ]] || exit 14
    [[ $5 == '\''$HOME'\'' && $6 == '\''$(exit 91)'\'' && $7 == "; exit 92" ]] || exit 15
    [[ $8 == "*" && $9 == /ucrt64/bin && ${12} == 日本語 ]] || exit 16
    printf "%s\0" "$@"
' smoke "$expected_cwd" "${args[@]}" > "$scratch/input"
printf '%s\0' "${args[@]}" | cmp - "$scratch/input"

printf 'stdin survives\n' | "$run" bash -c 'IFS= read -r x; [[ $x == "stdin survives" ]]'
status=0
"$run" bash -c 'exit 37' || status=$?
[[ $status == 37 ]]
status=0
"$run" linukkusu-command-that-does-not-exist 2>/dev/null || status=$?
[[ $status == 127 ]]
status=0
"$run" 2>/dev/null || status=$?
[[ $status == 2 ]]

# Native Win32 argument handling with conversions explicitly disabled inside.
"$run" env MSYS2_ARG_CONV_EXCL='*' python -c \
    'import sys; sys.stdout.buffer.write(b"\0".join(a.encode("utf-8") for a in sys.argv[1:]) + b"\0")' \
    "${args[@]}" > "$scratch/input"
printf '%s\0' "${args[@]}" | cmp - "$scratch/input"
# Default MSYS2 -> Win32 path conversion must still work.
"$run" python -c 'import os,sys; assert os.path.isfile(sys.argv[1]), sys.argv' /usr/bin/bash.exe
printf '%s\n' 'PASS: cwd, runtime PATH, arguments, stdin, status, and native path conversion'
