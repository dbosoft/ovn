# OVN for Windows (dbosoft)

[![Build for Windows (CMake)](https://github.com/dbosoft/ovn/actions/workflows/build-and-test-windows.yml/badge.svg)](https://github.com/dbosoft/ovn/actions/workflows/build-and-test-windows.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)
[![Upstream](https://img.shields.io/badge/upstream-ovn--org%2Fovn-lightgrey)](https://github.com/ovn-org/ovn)

## What is this fork?

This repository is **dbosoft's Windows-focused fork of OVN (Open Virtual
Network)**. It is **not** an official OVN release and is **not** affiliated with
or endorsed by the upstream OVN project.

Upstream OVN removed its remaining Windows build-system and source support from
the `main` branch (mirroring the earlier removal of Windows support from Open
vSwitch). This fork re-establishes and continues Windows development of the OVN
userspace daemons and tools (`ovn-northd`, `ovn-controller`, and the `ovn-*`
utilities) with a native, MSYS-free CMake build.

The fork is based on upstream OVN `main` and is periodically resynced with
upstream; the two upstream Windows-removal commits are reverted on each resync
so the Windows port stays intact. All non-Windows platforms (Linux, FreeBSD)
continue to inherit upstream behaviour unchanged; our additions are
Windows-specific.

OVN builds on top of Open vSwitch. This fork consumes dbosoft's matching
Windows fork of OVS through the [`ovs`](ovs) submodule
(<https://github.com/dbosoft/ovs>), which provides the Windows kernel datapath
(the `ovsext` NDIS forwarding extension) and the Windows OVS userspace that OVN
runs against.

If you are running OVN on Linux or FreeBSD, you almost certainly want the
upstream project at <https://github.com/ovn-org/ovn> instead of this fork.

## What is OVN?

OVN (Open Virtual Network) is a series of daemons that translate a virtual
network configuration into OpenFlow and install it into Open vSwitch. It is
licensed under the open source Apache 2 license.

OVN provides a higher-layer abstraction than Open vSwitch, working with logical
routers and logical switches rather than flows. OVN is intended to be used by
cloud management software (CMS). For details about the architecture of OVN, see
the `ovn-architecture` manpage. Some high-level features offered by OVN include:

- Distributed virtual routers
- Distributed logical switches
- Access Control Lists
- DHCP
- DNS server

Like Open vSwitch, OVN is written in platform-independent C and runs entirely
in userspace, so it requires no kernel modules of its own. On Windows it relies
on the Open vSwitch Windows port (the `ovsext` NDIS extension and the OVS
userspace) for the underlying datapath.

> **Two READMEs?** The upstream `README.rst` is left untouched to keep this
> fork's divergence from upstream minimal. This Windows-specific `README.md` is
> added alongside it; GitHub renders `README.md` in preference to `README.rst`.

## What's here?

The main components of this distribution are:

- `ovn-northd`, a centralized daemon that translates northbound configuration
  from a CMS into logical flows for the southbound database.
- `ovn-controller`, a daemon that runs on every hypervisor in the cluster. It
  translates the logical flows in the southbound database into OpenFlow for
  Open vSwitch. It also handles certain traffic, such as DHCP and DNS.
- `ovn-nbctl`, a tool for interfacing with the northbound database.
- `ovn-sbctl`, a tool for interfacing with the southbound database.
- `ovn-trace`, a debugging utility that allows for tracing of packets through
  the logical network.
- `ovn-debug`, a tool to simplify debugging of an OVN setup.
- the [`ovs`](ovs) submodule, dbosoft's Windows fork of Open vSwitch that OVN
  builds and runs against.

## Building on Windows

The Windows build uses CMake with Visual Studio 2022 (no MSYS/autotools/cccl).
It is a clean overlay that mirrors the OVS overlay: it builds the OVS submodule
via its own CMake overlay and then builds the OVN userspace (`libovn`, the
daemons, and the tools) against the resulting OVS CMake libraries. The
**Build for Windows (CMake)** GitHub Actions workflow
([`.github/workflows/build-and-test-windows.yml`](.github/workflows/build-and-test-windows.yml))
shows the canonical build and test steps.

For background on OVN concepts, the upstream documentation under
`Documentation/` remains a useful reference. **Note:** that documentation is
inherited from upstream and is **not** maintained for this Windows fork — it may
describe Linux-specific procedures or features that do not apply here, and may
be stale with respect to the Windows port.

## License

OVN is licensed under the open source Apache 2 license. Some files may be marked
specifically with a different license, in which case that license applies to the
file in question.

File `build-aux/cccl` is licensed under the GNU General Public License,
version 2.

## Contact

For issues specific to this Windows fork, please use the issue tracker at
<https://github.com/dbosoft/ovn/issues>.

Upstream OVN can be reached at bugs@openvswitch.org.
