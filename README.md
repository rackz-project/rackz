# Rackz

Copyright (c) 2026-present, The Rackz Project
Portions Copyright (c) 2014-2024, The Monero Project
Portions Copyright (c) 2012-2013 The CryptoNote developers

## Table of Contents

- [Development resources](#development-resources)
- [Vulnerability response](#vulnerability-response)
- [Research](#research)
- [Announcements](#announcements)
- [Translations](#translations)
- [Coverage](#coverage)
- [Introduction](#introduction)
- [About this project](#about-this-project)
- [Supporting the project](#supporting-the-project)
- [License](#license)
- [Contributing](#contributing)
- [Scheduled software upgrades](#scheduled-softwarenetwork-upgrades)
- [Release staging schedule and protocol](#release-staging-schedule-and-protocol)
- [Compiling Rackz from source](#compiling-rackz-from-source)
  - [Dependencies](#dependencies)
  - [Guix builds](#guix-builds)
- [Internationalization](#Internationalization)
- [Using Tor](#using-tor)
- [Pruning](#Pruning)
- [Debugging](#Debugging)
- [Known issues](#known-issues)

## Development resources

- Web: [rackz.io](https://rackz.io)
- GitHub: [https://github.com/rackz-project/rackz](https://github.com/rackz-project/rackz)
- Discord: [discord.gg/rackz](https://discord.gg/rackz)
- Matrix: [#rackz-dev](https://matrix.to/#/#rackz-dev:matrix.org)

If you are building software that integrates with Rackz, joining the developer channel is strongly recommended. Protocol changes, hardfork schedules, and RPC deprecations are announced there first. The channel is for protocol and core software discussion — for general usage questions, see the community channels linked on the website.

## Vulnerability response

- Responsible disclosure is handled via our [Security Policy](SECURITY.md)
- Critical vulnerabilities may be reported confidentially via the contact on the website
- Please **do not** open public GitHub issues for security vulnerabilities

## Research

Rackz builds on a decade of CryptoNote and Monero research. The codebase inherits
RandomX PoW, RingCT, CLSAG ring signatures, and Bulletproofs+ from the Monero
Research Lab's body of work. We stand on the shoulders of that community.

Ongoing Rackz-specific research is coordinated in the `#rackz-research` channel
(Matrix/Discord) and tracked in the [docs/rackz/](docs/rackz/) directory of this
repository.

## Announcements

Critical network upgrade announcements and release notices are posted to:

- GitHub Releases: [github.com/rackz-project/rackz/releases](https://github.com/rackz-project/rackz/releases)
- Website: [rackz.io/news](https://rackz.io/news)

Subscribe to GitHub releases or watch the repository to receive upgrade notifications.
Running an outdated node around a scheduled hardfork height will result in a chain split.

## Translations

The CLI wallet supports multiple languages. Translations are managed via the repository.
Pull requests adding or improving translations are welcome — see [docs/README.i18n.md](docs/README.i18n.md)
for instructions on contributing.

## Coverage

| Type    | Status                                                                                                         |
| ------- | -------------------------------------------------------------------------------------------------------------- |
| License | [![License](https://img.shields.io/badge/license-BSD3-blue.svg)](https://opensource.org/licenses/BSD-3-Clause) |

## Introduction

Rackz is a private, secure, and decentralised digital currency built for a world
where financial privacy is a right, not a privilege.

**Privacy by default.** Every transaction on the Rackz network is private out of
the box. Ring signatures obscure the true source of funds, stealth addresses ensure
outputs are unlinkable to recipients, and RingCT hides all transfer amounts — with
no opt-in required and no transparent mode to fall back on.

**Cryptographic security.** The network runs on a distributed peer-to-peer consensus
mechanism where every transaction is cryptographically verified by every node.
Your wallet is backed by a 25-word mnemonic seed — write it down once, store it
safely, and you own your funds forever. No custodian, no counterparty risk.

**Untraceable by design.** CLSAG ring signatures provide plausible deniability at
the protocol level. Transactions cannot be reliably tied to a sender or receiver
by any on-chain observer, regardless of their resources.

**Genuinely decentralised.** RandomX proof-of-work is deliberately ASIC-resistant,
keeping mining accessible to commodity hardware. Anyone can run a full node, verify
the entire chain, and participate equally in the network — the software is designed
to make this cheap and practical.

## About this project

Rackz is an open-source CryptoNote-derived blockchain. The codebase descends from
Monero's battle-tested core, which has been in continuous production since 2014 and
has withstood years of adversarial scrutiny. We inherit that foundation while
building forward independently.

The repository `master` branch is the active development staging area. Releases
are tagged and tested before mainnet deployment. For production use, always run a
tagged release rather than an untagged commit from master.

**Contributions are welcome.** Bug fixes, performance improvements, documentation,
and test coverage are all valuable. For significant protocol changes, open a
discussion issue first — large changes benefit from design review before
implementation begins. See [CONTRIBUTING](docs/CONTRIBUTING.md) for the full
contribution workflow, coding standards, and CI requirements.

## Supporting the project

Rackz is entirely community-funded. No pre-mine. No dev tax. No foundation with a
cheque book.

If you want to support development, the most direct way is to:

- Run a full node and contribute to network decentralisation
- Mine on the network and point hashrate at smaller pools
- Contribute code, documentation, or translations
- Spread the word to people who value financial privacy

A donation address will be published with the first mainnet release.
Packaging Rackz for your favourite Linux distribution is a welcome contribution.

## License

See [LICENSE](LICENSE).

## Contributing

If you want to help out, see [CONTRIBUTING](docs/CONTRIBUTING.md) for a set of guidelines.

## Scheduled software/network upgrades

Rackz uses a scheduled hardfork mechanism to deploy consensus changes. All node
operators and service providers **must** upgrade before the scheduled block height
or they will be left on a minority chain. Required software is published at least
four weeks before the activation height.

Dates are in YYYY-MM-DD format. "Minimum" follows the new consensus rules.
"Recommended" may additionally include bug fixes and non-consensus improvements.

> **Inherited baseline**: Rackz launches from the Monero v0.18 codebase, which
> already incorporates RandomX PoW, RingCT, CLSAG, Bulletproofs+, view tags, and
> ringsize-16. These are active at genesis — no re-play of Monero's hardfork history.

| Block height | Date | Version | Minimum RKZ version | Recommended RKZ version | Details                                                                |
| ------------ | ---- | ------- | ------------------- | ----------------------- | ---------------------------------------------------------------------- |
| 1            | TBD  | v1      | v0.1.0              | v0.1.0                  | Genesis: RandomX, RingCT, CLSAG, Bulletproofs+, view tags, ringsize 16 |
| TBD          | TBD  | v2      | TBD                 | TBD                     | TBD — schedule announced via GitHub releases                           |

\* indicates estimate as of commit date

## Release staging schedule and protocol

Approximately six weeks before a scheduled network upgrade, a release branch is
cut from master with the new version tag. Bug-fix pull requests should target both
master and the release branch. Feature and optimisation PRs that require extended
review should target master only and not be backported to the release branch.

## Compiling Rackz from source

### Dependencies

The following table summarizes the tools and libraries required to build. A
few of the libraries are also included in this repository (marked as
"Vendored"). By default, the build uses the library installed on the system
and ignores the vendored sources. However, if no library is found installed on
the system, then the vendored source will be built and used. The vendored
sources are also used for statically-linked builds because distribution
packages often include only shared library binaries (`.so`) but not static
library archives (`.a`).

| Dep         | Min. version  | Vendored | Debian/Ubuntu pkg    | Arch pkg     | Void pkg              | Fedora pkg          | Optional | Purpose         |
| ----------- | ------------- | -------- | -------------------- | ------------ | --------------------- | ------------------- | -------- | --------------- |
| GCC         | 7             | NO       | `build-essential`    | `base-devel` | `base-devel`          | `gcc`               | NO       |                 |
| CMake       | 3.10          | NO       | `cmake`              | `cmake`      | `cmake`               | `cmake`             | NO       |                 |
| pkg-config  | any           | NO       | `pkg-config`         | `base-devel` | `base-devel`          | `pkgconf`           | NO       |                 |
| Boost       | 1.66          | NO       | `libboost-all-dev`   | `boost`      | `boost-devel`         | `boost-devel`       | NO       | C++ libraries   |
| OpenSSL     | basically any | NO       | `libssl-dev`         | `openssl`    | `openssl-devel`       | `openssl-devel`     | NO       | sha256 sum      |
| libzmq      | 4.2.0         | NO       | `libzmq3-dev`        | `zeromq`     | `zeromq-devel`        | `zeromq-devel`      | NO       | ZeroMQ library  |
| libunbound  | 1.4.16        | NO       | `libunbound-dev`     | `unbound`    | `unbound-devel`       | `unbound-devel`     | NO       | DNS resolver    |
| libsodium   | ?             | NO       | `libsodium-dev`      | `libsodium`  | `libsodium-devel`     | `libsodium-devel`   | NO       | cryptography    |
| libunwind   | any           | NO       | `libunwind8-dev`     | `libunwind`  | `libunwind-devel`     | `libunwind-devel`   | YES      | Stack traces    |
| liblzma     | any           | NO       | `liblzma-dev`        | `xz`         | `liblzma-devel`       | `xz-devel`          | YES      | For libunwind   |
| libreadline | 6.3.0         | NO       | `libreadline6-dev`   | `readline`   | `readline-devel`      | `readline-devel`    | YES      | Input editing   |
| expat       | 1.1           | NO       | `libexpat1-dev`      | `expat`      | `expat-devel`         | `expat-devel`       | YES      | XML parsing     |
| GTest       | 1.5           | YES      | `libgtest-dev`       | `gtest`      | `gtest-devel`         | `gtest-devel`       | YES      | Test suite      |
| ccache      | any           | NO       | `ccache`             | `ccache`     | `ccache`              | `ccache`            | YES      | Compil. cache   |
| Doxygen     | any           | NO       | `doxygen`            | `doxygen`    | `doxygen`             | `doxygen`           | YES      | Documentation   |
| Graphviz    | any           | NO       | `graphviz`           | `graphviz`   | `graphviz`            | `graphviz`          | YES      | Documentation   |
| lrelease    | ?             | NO       | `qttools5-dev-tools` | `qt5-tools`  | `qt5-tools`           | `qt5-linguist`      | YES      | Translations    |
| libhidapi   | ?             | NO       | `libhidapi-dev`      | `hidapi`     | `hidapi-devel`        | `hidapi-devel`      | YES      | Hardware wallet |
| libusb      | ?             | NO       | `libusb-1.0-0-dev`   | `libusb`     | `libusb-devel`        | `libusbx-devel`     | YES      | Hardware wallet |
| libprotobuf | ?             | NO       | `libprotobuf-dev`    | `protobuf`   | `protobuf-devel`      | `protobuf-devel`    | YES      | Hardware wallet |
| protoc      | ?             | NO       | `protobuf-compiler`  | `protobuf`   | `protobuf`            | `protobuf-compiler` | YES      | Hardware wallet |
| libudev     | ?             | NO       | `libudev-dev`        | `systemd`    | `eudev-libudev-devel` | `systemd-devel`     | YES      | Hardware wallet |

Install all dependencies at once on Debian/Ubuntu:

```
sudo apt update && sudo apt install build-essential cmake pkg-config libssl-dev libzmq3-dev libunbound-dev libsodium-dev libunwind8-dev liblzma-dev libreadline6-dev libexpat1-dev qttools5-dev-tools libhidapi-dev libusb-1.0-0-dev libprotobuf-dev protobuf-compiler libudev-dev libboost-chrono-dev libboost-date-time-dev libboost-filesystem-dev libboost-locale-dev libboost-program-options-dev libboost-regex-dev libboost-serialization-dev libboost-system-dev libboost-thread-dev python3 ccache doxygen graphviz git curl autoconf libtool gperf
```

Install all dependencies at once on Arch:

```
sudo pacman -Syu --needed base-devel cmake boost boost-libs openssl zeromq unbound libsodium libunwind xz readline expat python3 ccache doxygen graphviz qt5-tools hidapi libusb protobuf systemd
```

Install all dependencies at once on Fedora:

```
sudo dnf install gcc gcc-c++ cmake pkgconf boost-devel openssl-devel zeromq-devel unbound-devel libsodium-devel libunwind-devel xz-devel readline-devel expat-devel ccache doxygen graphviz qt5-linguist hidapi-devel libusbx-devel protobuf-devel protobuf-compiler systemd-devel
```

Install all dependencies at once on openSUSE:

```
sudo zypper ref && sudo zypper in cppzmq-devel libboost_chrono-devel libboost_date_time-devel libboost_filesystem-devel libboost_locale-devel libboost_program_options-devel libboost_regex-devel libboost_serialization-devel libboost_system-devel libboost_thread-devel libexpat-devel libsodium-devel libunwind-devel unbound-devel cmake doxygen ccache fdupes gcc-c++ libevent-devel libopenssl-devel pkgconf-pkg-config readline-devel xz-devel libqt5-qttools-devel patterns-devel-C-C++-devel_C_C++
```

Install all dependencies at once on macOS with the provided Brewfile:

```
brew update && brew bundle --file=contrib/brew/Brewfile
```

FreeBSD 12.1 one-liner required to build dependencies:

```
pkg install git gmake cmake pkgconf boost-libs libzmq4 libsodium unbound
```

### Cloning the repository

Clone recursively to pull in needed submodules:

```
git clone --recursive https://github.com/rackz-project/rackz
```

If you already have a repo cloned, initialize and update:

```
cd rackz && git submodule init && git submodule update
```

_Note_: If there are submodule differences between branches, you may need
to use `git submodule sync && git submodule update` after changing branches
to build successfully.

### Build instructions

Rackz uses the CMake build system and a top-level [Makefile](Makefile) that
invokes cmake commands as needed.

#### On Linux and macOS

- Install the dependencies
- Change to the root of the source code directory, check out the most recent release tag, and build:

  ```bash
  cd rackz
  git checkout release-v0.1
  make
  ```

  _Optional_: If your machine has several cores and enough memory, enable
  parallel build by running `make -j<number of threads>` instead of `make`. For
  this to be worthwhile, the machine should have one core and about 2 GB of RAM
  available per thread.

  _Note_: The instructions above compile the most stable release of the Rackz
  software. To test the most recent changes, use `git checkout master`. The
  master branch may contain updates that are unstable or incompatible with
  the current release — testing is always appreciated.

- The resulting executables can be found in `build/release/bin`

- Add `PATH="$PATH:$HOME/rackz/build/release/bin"` to `.profile`

- Run the Rackz daemon with `rackzd --detach`

- **Optional**: build and run the test suite to verify the binaries:

  ```bash
  make release-test
  ```

  _NOTE_: `core_tests` may take a few hours to complete.

- **Optional**: to build binaries suitable for debugging:

  ```bash
  make debug
  ```

- **Optional**: build documentation in `doc/html` (omit `HAVE_DOT=YES` if `graphviz` is not installed):

  ```bash
  HAVE_DOT=YES doxygen Doxyfile
  ```

- **Optional**: use ccache to avoid recompiling unchanged translation units — `CMakeLists.txt` handles it automatically:

  ```bash
  sudo apt install ccache
  ```

#### On the Raspberry Pi

Tested on a Raspberry Pi 5B with a clean installation of Raspberry Pi OS (64-bit)
with Debian 12 from https://www.raspberrypi.com/software/operating-systems/.

- `apt-get update && apt-get upgrade` to install the latest software

- Install the dependencies from the 'Debian' column in the table above.

- **Optional**: increase the system swap size:

  ```bash
  sudo /etc/init.d/dphys-swapfile stop
  sudo nano /etc/dphys-swapfile
  CONF_SWAPSIZE=2048
  sudo /etc/init.d/dphys-swapfile start
  ```

- If using an external hard disk without an external power supply, ensure it gets
  enough power to avoid hardware issues during sync by adding `max_usb_current=1`
  to `/boot/config.txt`.

- Clone Rackz and check out the most recent release tag:

  ```bash
  git clone --recursive https://github.com/rackz-project/rackz.git
  cd rackz
  git checkout v0.1.0
  ```

- Build:

  ```bash
  USE_SINGLE_BUILDDIR=1 make release
  ```

- Wait a few hours

- The resulting executables can be found in `build/release/bin`

- Add `export PATH="$PATH:$HOME/rackz/build/release/bin"` to `$HOME/.profile`

- Run `source $HOME/.profile`

- Run the daemon with `rackzd --detach`

- You may wish to reduce the swap file size after the build and delete the boost
  source directory from your home directory.

#### On Windows:

Binaries for Windows can be built using the MinGW toolchain within the
[MSYS2 environment](https://www.msys2.org). The MSYS2 environment emulates a
POSIX system. The toolchain runs within the environment and _cross-compiles_
binaries that can run outside of it as a regular Windows application.

**Preparing the build environment**

- Download and install the [MSYS2 installer](https://www.msys2.org). Requires 64-bit Windows 10 or newer.
- Open the MSYS shell via the `MSYS2 MSYS` shortcut
- Update packages using pacman:

  ```bash
  pacman -Syu
  ```

- Install dependencies:

  ```bash
  pacman -S mingw-w64-x86_64-toolchain make mingw-w64-x86_64-cmake mingw-w64-x86_64-boost mingw-w64-x86_64-openssl mingw-w64-x86_64-zeromq mingw-w64-x86_64-libsodium mingw-w64-x86_64-hidapi mingw-w64-x86_64-unbound
  ```

- Open the MinGW shell via the `MSYS2 MINGW64` shortcut.

**Cloning**

- To git clone, run:

  ```bash
  git clone --recursive https://github.com/rackz-project/rackz.git
  ```

**Building**

- Change to the cloned directory:

  ```bash
  cd rackz
  ```

- To check out a specific [release tag](https://github.com/rackz-project/rackz/tags), e.g. `v0.1.0`:

  ```bash
  git checkout v0.1.0
  ```

- Build:

  ```bash
  make release-static -j $(nproc)
  ```

  The resulting executables can be found in `build/release/bin`

- **Optional**: to build Windows binaries suitable for debugging:

  ```bash
  make debug -j $(nproc)
  ```

  The resulting executables can be found in `build/debug/bin`

### On FreeBSD:

Build from scratch by following the Linux instructions above, but use `gmake`
instead of `make`. If you are running the daemon in a jail, add `sysvsem="new"`
to your jail configuration, otherwise LMDB will throw:
`Failed to open lmdb environment: Function not implemented`.

### On OpenBSD:

Install required packages: `pkg_add cmake gmake zeromq libiconv boost libunbound`.

The `doxygen` and `graphviz` packages are optional and require the xbase set.
The test suite also requires `py3-requests`.

Build: `gmake`

Note: you may encounter the following error when compiling as a normal user:

```
LLVM ERROR: out of memory
c++: error: unable to execute command: Abort trap (core dumped)
```

Then increase the data ulimit to 2 GB and try again: `ulimit -d 2000000`

### On NetBSD:

Verify dependencies are present: `pkg_info -c libexecinfo boost-headers boost-libs protobuf readline libusb1 zeromq git-base pkgconf gmake cmake | more`. Install any missing packages via `pkg_add` or pkgsrc. Readline is optional but recommended.

Third-party dependencies are usually under `/usr/pkg/`. Adjust accordingly for custom setups.

Clone the repository recursively and check out the most recent release as described above. Then build: `gmake BOOST_ROOT=/usr/pkg LDFLAGS="-Wl,-R/usr/pkg/lib" release`. Executables are in `build/NetBSD/[Release version]/Release/bin/`.

### On Solaris:

The default Solaris linker is not supported. Install GNU ld and invoke cmake manually with the path to it:

```bash
mkdir -p build/release
cd build/release
cmake -DCMAKE_LINKER=/path/to/ld -D CMAKE_BUILD_TYPE=Release ../..
cd ../..
```

Then you can run make as usual.

### Cross Compiling

You can cross-compile static binaries on Linux for Windows and macOS with the `depends` system.

- `make depends target=x86_64-linux-gnu` for 64-bit linux binaries.
- `make depends target=x86_64-w64-mingw32` for 64-bit windows binaries.
  - Requires: `g++-mingw-w64-x86-64`
  - You also need to run:
    ```shell
    update-alternatives --set x86_64-w64-mingw32-g++ $(which x86_64-w64-mingw32-g++-posix) && \
    update-alternatives --set x86_64-w64-mingw32-gcc $(which x86_64-w64-mingw32-gcc-posix)
    ```
- `make depends target=x86_64-apple-darwin` for Intel macOS binaries.
  - Requires: `clang-18 lld-18`
- `make depends target=arm64-apple-darwin` for Apple Silicon macOS binaries.
  - Requires: `clang-18 lld-18`
  - You also need to run:
    ```shell
    export PATH="/usr/lib/llvm-18/bin/:$PATH"
    ```
- `make depends target=i686-linux-gnu` for 32-bit linux binaries.
  - Requires: `g++-multilib bc`
- `make depends target=i686-w64-mingw32` for 32-bit windows binaries.
  - Requires: `python3 g++-mingw-w64-i686`
- `make depends target=arm-linux-gnueabihf` for armv7 binaries.
  - Requires: `g++-arm-linux-gnueabihf`
- `make depends target=aarch64-linux-gnu` for armv8 binaries.
  - Requires: `g++-aarch64-linux-gnu`
- `make depends target=riscv64-linux-gnu` for RISC V 64 bit binaries.
  - Requires: `g++-riscv64-linux-gnu`
- `make depends target=x86_64-unknown-freebsd` for freebsd binaries.
  - Requires: `clang-8`
- `make depends target=arm-linux-android` for 32bit android binaries
- `make depends target=aarch64-linux-android` for 64bit android binaries

The required packages are the names for each toolchain on apt. Depending on your distro, they may have different names. The `depends` system has been tested on Ubuntu 18.04 and 20.04.

Using `depends` is often easier than MSYS for building on Windows. Activate Windows Subsystem for Linux (WSL) with a distro (e.g. Ubuntu), install the apt build-essentials, and follow the `depends` steps above.

The produced binaries still link libc dynamically. If the binary is compiled on a current distribution, it might not run on an older distribution with an older installation of libc.

### Trezor hardware wallet support

If you have an issue building with Trezor support, disable it by setting `USE_DEVICE_TREZOR=OFF`, e.g.,

```bash
USE_DEVICE_TREZOR=OFF make release
```

For more information, please check out Trezor [src/device_trezor/README.md](src/device_trezor/README.md).

### Guix builds

See [contrib/guix/README.md](contrib/guix/README.md).

## Installing Rackz from a package

Rackz has not yet been submitted to any distribution package trees. Building
from source (see above) is the only supported method until mainnet launch.

Packaging Rackz for Debian, Arch, NixOS, Homebrew, or Docker is a welcome
community contribution — see [CONTRIBUTING](docs/CONTRIBUTING.md) for the
pull request process.

### Docker

```bash
# Build using all available cores
docker build -t rackz .

# or build using a specific number of cores (reduces RAM requirement)
docker build --build-arg NPROC=1 -t rackz .

# run in foreground
docker run -it -v /rackz/chain:/home/rackz/.rackz -v /rackz/wallet:/wallet -p 19080:19080 rackz

# or in background
docker run -it -d -v /rackz/chain:/home/rackz/.rackz -v /rackz/wallet:/wallet -p 19080:19080 rackz
```

- The build needs approximately 3 GB of disk space.
- Allow one hour or more for the initial build.

## Running rackzd

The build places the binary in `bin/` within the build directory (repository root
by default). To run in the foreground:

```bash
./bin/rackzd
```

To list all available options, run `./bin/rackzd --help`. Options can be
specified on the command line or in a configuration file passed via
`--config-file`. Configuration file syntax: `argumentname=value`, where the
argument name has no leading dashes — e.g. `log-level=1`.

To run in the background:

```bash
./bin/rackzd --log-file rackzd.log --detach
```

To run as a systemd service, copy
[rackzd.service](utils/systemd/rackzd.service) to `/etc/systemd/system/` and
[rackzd.conf](utils/conf/rackzd.conf) to `/etc/`. The example service assumes
a `rackz` user exists whose home directory matches the data directory in the
example config.

On macOS, if you experience crashes on wallet refresh, try adding
`--max-concurrency 1` to `rackz-wallet-cli` and/or `rackzd`.

## Internationalization

See [README.i18n.md](docs/README.i18n.md).

## Using Tor

> Rackz supports an experimental [Tor/anonymity network integration](docs/ANONYMITY_NETWORKS.md)
> that allows simultaneous IPv4 and Tor connectivity. IPv4 handles block and peer
> transaction relay; Tor is used solely for transactions received over local RPC.
> This provides stronger protection against sybil attacks while keeping block
> propagation fast.

Rackz can also be wrapped with `torsocks` for a simpler setup:

- `--p2p-bind-ip 127.0.0.1` on the command line or `p2p-bind-ip=127.0.0.1` in
  `rackzd.conf` to stop listening on external interfaces.
- If using the wallet against a Tor daemon on the loopback (e.g. `127.0.0.1:9050`),
  pass `--untrusted-daemon` unless it is your own hidden service.

Example — start the daemon through Tor:

```bash
rackzd --proxy 127.0.0.1:9050 --p2p-bind-ip 127.0.0.1
```

A helper script is available at `contrib/tor/rackz-over-tor.sh`. It assumes Tor
is already installed and configures both Tor and Rackz automatically.

### Using Tor on Tails

Tails ships with a very restrictive firewall. Add a rule to allow the RPC
connection, then start the daemon:

```bash
sudo iptables -I OUTPUT 2 -p tcp -d 127.0.0.1 -m tcp --dport 19081 -j ACCEPT
DNS_PUBLIC=tcp torsocks ./rackzd --p2p-bind-ip 127.0.0.1 --rpc-bind-ip 127.0.0.1 \
    --data-dir /home/amnesia/Persistent/your/directory/to/the/blockchain
```

## Pruning

A full Rackz blockchain is small at launch and grows over time. To conserve
disk space, run a pruned node which stores approximately one-third of the
chain data while retaining full validation capability.

Start the initial sync with pruning enabled:

```bash
rackzd --prune-blockchain
```

To prune an existing chain, use the `rackz-blockchain-prune` tool or pass
`--prune-blockchain` to `rackzd` on an existing data directory. Note that
pruning an existing full chain temporarily requires space for both the full
and pruned copies; ensure you have sufficient free disk space before starting.

A pruned node can serve partial historical chain data to peers and is otherwise
functionally identical to a full node for all wallet and consensus operations.

## Debugging

The following instructions cover debugging failed builds and runtime issues.
Always ensure you are running the latest tagged release or a recent master build
before opening a bug report.

### Obtaining stack traces and core dumps on Unix systems

We generally use the tool `gdb` (GNU debugger) to provide stack trace functionality, and `ulimit` to provide core dumps in builds which crash or segfault.

- To use `gdb` to obtain a stack trace for a stalled process:

  Run the daemon, then once it stalls:

  ```bash
  gdb /path/to/rackzd `pidof rackzd`
  ```

  Type `thread apply all bt` within gdb to print the stack trace.

- If the process crashes or segfaults:

Enter `ulimit -c unlimited` on the command line to enable unlimited filesizes for core dumps

Enter `echo core | sudo tee /proc/sys/kernel/core_pattern` to stop cores from being hijacked by other tools

Run the build.

When it terminates with "Segmentation fault (core dumped)", a core dump file
will appear in the working directory — named `core` or `core.xxxx`.

Analyse it with gdb:

```bash
gdb /path/to/rackzd /path/to/dumpfile
```

Print the stack trace with `bt`

- If a program crashed and cores are managed by systemd, the following can also get a stack trace for that crash:

```bash
coredumpctl -1 gdb
```

#### To run rackzd within gdb:

Type `gdb /path/to/rackzd`

Pass command-line options with `--args` followed by the relevant arguments.

Type `run` to start the daemon.

### Analysing memory corruption

There are two tools available:

#### ASAN

Configure with `-D SANITIZE=ON`:

```bash
cd build/debug && cmake -D SANITIZE=ON -D CMAKE_BUILD_TYPE=Debug ../..
```

Run the tools normally. Expect roughly half normal performance under ASAN.

#### valgrind

Install valgrind and run: `valgrind /path/to/rackzd`. Execution will be very slow.

### LMDB

`mdb_stat` is in the LMDB source and can print database statistics, but is not
built by default. Build it with:

```bash
cd ~/rackz/external/db_drivers/liblmdb && make
```

`mdb_stat -ea <path to blockchain dir>` reports inconsistencies across the
`blocks`, `block_heights`, and `block_info` tables.

`mdb_dump -s blocks <path>` and `mdb_dump -s block_info <path>` are useful for
verifying that both tables contain matching keys.

These records are dumped as hex data, where the first line is the key and the second line is the data.

# Known Issues

## Protocols

### Socket-based

The P2P protocol has inherent limitations that cannot be fully eliminated without
disproportionate engineering cost. Node operators should take the following
precautions:

- Run `rackzd` on a dedicated, secured machine. Do not browse the web, use email
  clients, or run any other network-facing applications on the same machine.
  **Do not click links or load external content on the node machine** — commands
  accepting `localhost` and `127.0.0.1` are potentially exploitable.
- If you are hosting a public remote node, always start `rackzd` with
  `--restricted-rpc`. This is non-negotiable for public-facing nodes.

### Blockchain-based

Certain protocol-level behaviours can be misused:

- When receiving RKZ, outputs may be time-locked by the sender for an arbitrary
  duration. Locked outputs cannot be spent until the lock height expires. Check
  the remaining block height until unlock using the `show_transfers` command in
  `rackz-wallet-cli` before acting on incoming funds.
