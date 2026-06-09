# OVN Windows test suite — known failures (real build bugs)

These are **real OVN/MSVC build bugs** surfaced by the Windows autotest suite
(`tests/windows/run-windows-testsuite.ps1`). They are deliberately **not** in
`excluded-tests.txt`: the tests must keep running and failing until the bugs are
fixed. Method/feature incompatibilities (which *are* excluded) live in
`excluded-tests.txt` / `excluded-keywords.txt`.

Baseline run: userspace groups 1–371, **304 pass / 65 fail / 2 skip** (after the
PKI + watchdog fixes; before excluding the method-incompatible tests).

## 1. `xxreg`/`xreg` register field width is wrong on MSVC  ⚠️ fix soon

The single biggest cause (~16 direct failures, plus likely cascades into the
`ovn-macros.at:992`/`:944` "NBDB→SBDB" convergence checks). Every test that uses
an `xreg`/`xxreg` subfield in a flow logs:

```
expr|WARN|xxreg0[64..127]: error parsing xreg0 subfield
  (Cannot select bits 64 to 127 of 2-bit field xxreg0.)
expr|WARN|xxreg1[0..63]:  error parsing xreg3 subfield
  (Cannot select bits 0 to 63 of 8-bit field xxreg1.)
```

`xxreg0` is a **128-bit** register and `xreg*` are **64-bit**, but the build
reports them as **2-bit / 8-bit**, so the expr parser rejects every `xreg`/`xxreg`
subfield reference and northd flow generation breaks. The symbols are registered
in `lib/logical-fields.c` (`expr_symtab_add_field(symtab, xxname, MFF_XXREG0 + xxi, ...)`)
from the OVS `mf_fields[]` meta-flow table — the wrong width points at an
enum/array-index or struct-width miscomputation of `MFF_XXREG*`/`MFF_XREG*` on
MSVC. Same integer-handling family as bug #2.

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
"hard failure"s) are not yet individually root-caused. Most are expected to be
downstream of bug #1 (northd producing wrong/incomplete southbound data); they
should be re-checked once the `xxreg` width bug is fixed.
