# Linukkusu — Technical guide

[← 日本語の紹介・使い方](../README.md) · [開発に参加する](../CONTRIBUTING.md)

This document preserves the detailed v0.1 architecture, operation, and validation notes.

A user-space, Unix-like Windows development environment bootstrapped from
**Windows + Git for Windows**. Git Bash starts the bootstrap; a private MSYS2
installation supplies the UCRT64 development environment.

No WSL, administrator privileges, MSI installation, or preinstalled Node.js,
Python, or CMake is required. Use a current Git for Windows on x86_64 Windows
10/11, with internet access and several GB of free disk space.

## Quick start

In **Git Bash**:

```bash
git clone https://github.com/norimichi1013/Linukkusu.git
cd Linukkusu
./bootstrap.sh
export PATH="$HOME/.dev/bin:$PATH"
dev
```

Add the `export` line to your Git Bash `~/.bashrc` to keep it for future shells.
Bootstrap does not edit shell startup files or the Windows PATH.

```bash
dev                       # Interactive UCRT64 login shell; exit returns to Git Bash
dev-run python --version
dev-run cmake --version
dev-run node --version
dev-run npm --version
dev-run bash -c 'printf "%s\n" "$PWD"'
dev-update                # Run from Git Bash after closing Linukkusu sessions
dev --help                # Each launcher describes its own usage
```

Both launchers retain the current working directory. `dev-run` forwards one
command and its arguments and returns its exit status. Pipelines and shell
syntax require an explicit `bash -c`, as in the example above.

## Installation and updates

```text
~/.dev/
├── bin/
│   ├── .linukkusu.sh       # Shared launcher implementation
│   ├── dev
│   ├── dev-run
│   └── dev-update
└── Linukkusu/
    ├── usr/               # MSYS/POSIX infrastructure
    ├── ucrt64/            # Windows-native development tools
    ├── etc/
    ├── var/
    └── home/dev/          # Private home and dotfiles
```

Bootstrap downloads the official **2026-06-11 x86_64 self-extracting archive**,
checks its pinned SHA-256, extracts into a staging directory, and moves the
completed tree into place. This archive does not run the Windows installer.
A first login runs MSYS2's initialization scripts, including keyring setup.
The source and checksum are pinned in `bootstrap.sh`; package signatures
continue to be checked by pacman.

The Git Bash parent runs `pacman --noconfirm -Syuu`, waits for it to finish,
then invokes `pacman --noconfirm -Suu` in a new MSYS2 process. This finishes
the full upgrade after a core update terminates the old runtime. The second
pass uses the same synchronized databases. `-uu` also permits downgrades, so
a package rolled back upstream cannot stall the whole upgrade. Both passes
replace the inner shell with pacman using `exec`, and propagate failures.
Close all Linukkusu shells and background tasks first: a core update can
terminate them.

Rerunning `./bootstrap.sh` updates the existing managed installation, installs
missing entries from `packages/base.txt`, and refreshes the launchers. It
preserves your private home and additional packages; removing a package from
the list does not uninstall it. Each launcher is staged next to its destination
and moved into place, because overwriting one where it stands can corrupt a
launcher that a running shell is still reading; when a replacement cannot be
made, bootstrap stops and says so. Run the launchers from `~/.dev/bin`: they
locate their shared implementation next to themselves, so a symlink placed
elsewhere on PATH does not work. `dev-update` updates installed packages;
rerun bootstrap after changing the repository's package list or launchers.

The package list contains MSYS `base-devel` and `git`, plus the UCRT64
toolchain, CMake, Ninja, Python, Node.js (including npm), ripgrep, and fd.
Names are checked against the [official package catalog](https://packages.msys2.org/).
This v0.1 reproduces the layout and package selection, **not identical package
versions**: MSYS2 is a rolling distribution, and each full update resolves
against its current repositories.

If an operation fails, fix the reported cause and rerun bootstrap. Failed
downloads/extractions are retained in the printed staging directory for
inspection. Each failed attempt keeps its own several-hundred-megabyte
directory, so delete the `~/.dev/.linukkusu-download.*` directories you no
longer need. An existing unmarked destination is rejected instead of
overwritten. Ctrl-C normally releases `~/.dev/.linukkusu-bootstrap.lock`
through the exit trap; after a bootstrap was killed outright, remove the lock
only after checking that no bootstrap is running. Never remove pacman's
database lock while pacman is active. Concurrent bootstrap/update/package
installation is unsupported.

## Runtime and argument boundary

Only `~/.dev/bin` belongs on Git Bash's PATH. **Never add Linukkusu's
`usr/bin` to Git Bash's PATH**: the two installations have separate MSYS DLLs.
Each launcher invokes the private `bash.exe` with `MSYSTEM=UCRT64`,
`CHERE_INVOKING=1`, and `MSYS2_PATH_TYPE=minimal`. A clean child environment
keeps Windows facilities, terminal/locale settings and proxy settings, while
discarding the outer toolchain PATH, exported functions and startup hooks.
The private home also keeps Git Bash dotfiles from contaminating UCRT64.
Custom build variables and credentials are not inherited automatically;
configure them inside Linukkusu or pass them explicitly with `dev-run env`.

Two consequences are worth stating plainly. First, `MSYS2_PATH_TYPE=minimal`
keeps the Windows PATH out, so `cmd.exe`, PowerShell, `where` and tools
installed on the Windows side, including the credential helper shipped with
Git for Windows, are not reachable from inside. Configure git credentials
inside Linukkusu, or pass a helper explicitly. Second, `HOME=/home/dev` only
separates the POSIX home: node, npm and Python run as native Windows programs
and keep reading `USERPROFILE`, `APPDATA` and `LOCALAPPDATA`, so for example
`npm install -g` still writes to `%APPDATA%\npm`, shared with any other Node.js
installation on the machine.

At the Git Bash → MSYS2 boundary, arguments, the working directory and selected
environment variables travel through a temporary NUL-delimited file. This avoids
cross-runtime environment rewriting and Windows command-line quoting; the file
is removed when the child exits. A fixed shell program reads the records into
an array, sets a clean environment inside MSYS2 and forwards `"$@"`; user input
is never evaluated. Normal conversion to native Windows tools remains enabled
inside MSYS2. Thus `/usr/...` refers to **Linukkusu**, not Git for Windows. Use
`C:/...` paths when referring to files outside the private installation.

For a native tool that needs literal POSIX-looking text instead of a converted
Windows path, opt out inside the environment:

```bash
dev-run env MSYS2_ARG_CONV_EXCL='*' python -c 'import sys; print(sys.argv)' /literal
```

Shell scripts quote paths, including paths with spaces. Upstream
[p11-kit has a known space-in-path bug](https://github.com/msys2/MINGW-packages/issues/22438)
in its certificate extraction dispatcher. After package installation and updates,
Linukkusu invokes `trust.exe` directly to regenerate the UCRT64 certificate
bundles and propagates any failure. The upstream package hook may still print
its error before this repair. **The repair covers the UCRT64 bundles only**:
the MSYS bundle under `/usr/ssl/certs`, used by the MSYS `git` in the package
list, is left to its own package hook and has not been verified under an
installation path containing spaces. Other upstream build tools can impose
their own path restrictions.

## Validation

After bootstrap, run from Git Bash:

```bash
bash tests/smoke.sh
dev-run gcc --version
dev-run cmake --version
dev-run ninja --version
dev-run python --version
dev-run node --version
dev-run npm --version
dev-run rg --version
dev-run fd --version
```

The smoke test checks argument boundaries (empty values, spaces, quotes,
metacharacters, newlines and Japanese text), working directories with spaces,
PATH isolation, stdin, exit status, and MSYS2-to-native path conversion.

Development validation used an isolated installation whose path contained spaces:
initialization, an actual core-runtime upgrade, the full package list, repeat
bootstrap, the smoke test, all tool versions, a CMake/Ninja C++ build, interactive
shell entry/exit, and HTTPS with the repaired UCRT64 certificate bundle passed.
The bootstrap test redirected installation paths into the workspace; it did not
install into the developer's normal `~/.dev`.

Before declaring a release, validate on a clean Windows + Git for Windows
machine: the complete bootstrap, a second bootstrap, interactive `dev` and
Ctrl-C/exit, all tool versions and a CMake/Ninja C++ build, an HTTPS `git clone`
run by the MSYS `git` inside the environment, a user profile path with
spaces/non-ASCII characters, and a real core-runtime upgrade. Also exercise
interrupted downloads, pacman network failures and recovery. Automated shell
checks alone do not establish these Windows installation/terminal behaviors.

## Uninstall

Everything lives under `~/.dev`. Close every Linukkusu shell, then remove
`~/.dev/Linukkusu` for the environment and `~/.dev/bin` for the launchers, and
drop the `export PATH=...` line from your Git Bash `~/.bashrc`. Nothing is
written to the Windows PATH or the registry, so no other cleanup is needed.

## The Bootstrap Paradox

Linukkusu requires only Windows and Git for Windows. But Git cannot create
the first GitHub repository containing Linukkusu: repository creation belongs
to GitHub's service/API, not the Git protocol. The first repository was therefore
created manually.

Once Linukkusu exists, tools such as `gh` can be added so it can create
repositories for its descendants. (`gh` is not part of this initial package set.)

**The first Linukkusu must be created by hand. After that, Linukkusu can reproduce.**

## Upstream references

- [Archive installation and initialization](https://www.msys2.org/docs/installer/)
- [MSYS2 process invocation and two-pass CI updates](https://www.msys2.org/docs/ci/)
- [Full upgrades and core-runtime restart](https://www.msys2.org/docs/updating/)
- [UCRT64 environment selection](https://www.msys2.org/docs/environments/)
- [Argument and environment path conversion](https://www.msys2.org/docs/filesystem-paths/)
- [Pinned archive release](https://github.com/msys2/msys2-installer/releases/tag/2026-06-11)
