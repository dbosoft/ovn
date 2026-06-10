# OVN Windows test suite — known failures (real build bugs)

These are **real OVN/MSVC build bugs** surfaced by the Windows autotest suite
(`tests/windows/run-windows-testsuite.ps1`). They are deliberately **not** in
`excluded-tests.txt`: the tests must keep running and failing until the bugs are
fixed. Method/feature incompatibilities (which *are* excluded) live in
`excluded-tests.txt` / `excluded-keywords.txt`.

Baseline run: userspace groups 1–371, **304 pass / 65 fail / 2 skip** (after the
PKI + watchdog fixes; before excluding the method-incompatible tests). **NOTE:**
that local baseline was contaminated by bug #1 below (a stale generated `.inc`
in the local tree), which inflated the failure count; it must be re-measured on
a clean build.

## 1. `xxreg`/`xreg` register field width wrong — RESOLVED (stale generated `.inc`, not an MSVC bug)

The symptom: every test using an `xreg`/`xxreg` subfield logged

```
expr|WARN|xxreg0[64..127]: error parsing xreg0 subfield
  (Cannot select bits 64 to 127 of 2-bit field xxreg0.)
```

`xxreg0` is **128-bit** and `xreg*` are **64-bit**, but they were reported as
**2-/8-bit**, so the expr parser rejected the subfields and northd flow
generation broke (~16 direct failures plus cascades).

**Corrected root cause — not MSVC.** A prior in-source autotools build of the
OVS submodule had left stale generated `ovs/lib/*.inc` (`meta-flow.inc`, …) on
disk. A quoted `#include "meta-flow.inc"` from `ovs/lib/meta-flow.c` resolves the
compiland's own directory before any `-I` path, so the stale in-source copy
shadowed the freshly generated `gen/lib/meta-flow.inc`. The stale table had 183
field entries against today's 211-id `MFF_N_IDS`; with positional initialization
+ direct indexing (`mf_fields[id]`), every field whose enum position had shifted
read the wrong slot, so `xxreg`/`xreg` landed on small fields and reported
2-/8-bit. (OVN's `lib/logical-fields.c` registration was correct all along.)

These `.inc` are `.gitignore`'d generated artifacts, so a **clean checkout (CI)
was never affected** — this only bites a local tree that was once
autotools-built. Fixed by removing the stale in-source `.inc`; a configure-time
guard in the OVS CMake (`file(REMOVE …)`, dbosoft/ovs) prevents recurrence and
reaches OVN on the next `ovs` submodule bump. Confirmed: after the removal +
rebuild, `ovntest test-ovn parse-expr` normalizes `xxreg0[0..127]` → `xxreg0`
and accepts `xxreg0[64..127]` with no error.

## 2. `ovn-nbctl` mirror `Index/Key` integer bug

`ovn-nbctl.at:493` (mirrors, direct + daemon). `mirror-list` prints:

```
Index/Key:  -4294967296      (expected 0)
Index/Key:  -4294967295      (expected 1)
```

`-4294967296 = 0xFFFFFFFF00000000`: a 32-bit mirror index sign-extended into the
high 32 bits of a 64-bit value when read from the OVSDB integer column / printed.
MSVC integer-width/sign-extension bug.

## Still to triage

~37 failures (mostly `ovn-macros.at:992`/`:944` and `ovs-macros.at:221` macro
"hard failure"s) were attributed to bug #1 (northd producing wrong/incomplete
southbound data from the corrupted register widths). With #1 resolved, **the
baseline must be re-measured on a clean build** — these cascades are expected to
clear. Re-baseline before individually triaging any remainder.
