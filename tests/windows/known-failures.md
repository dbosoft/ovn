# OVN Windows test suite — known failures

Re-baselined on the xxreg-fixed clean `ovs` head, with OVN built against an OVS
that carries the binary-stdout fix (dbosoft/ovs#52). Real platform/method
incompatibilities are skipped via `excluded-tests.txt` / `excluded-keywords.txt`,
not listed here.

The suite is **not** wired into CI as a gate. It splits into two very different
populations:

- **Userspace / control-plane (the original groups 1–371): 65 → 14 failures.**
  The drop came from three fixes: the stale-`.inc` guard (the `xxreg`/`xreg`
  width corruption — see git history), the OVS UTF-8 argv manifest + this repo's
  `cmake/windows-utf8.manifest` on the OVN exes, and OVS binary-mode stdout
  (LF, not CRLF) which clears the `ovn-macros.at:992` NB→SB convergence checks
  that compared `\r`-laden `ovn-sbctl/nbctl` output (122/132/170 now pass).
- **Integration suites (`ovn.at`, `ovn-controller.at`, …, groups 372+):**
  hundreds of scenarios that stand up northd + controller + ovsdb + a simulated
  datapath together. These were ordered last and never part of the userspace
  baseline; they are a separate, large Windows-porting effort (datapath
  simulation, timing, parallelization) and are out of scope for this pass.

## Dependency

The CRLF clearance above requires OVS binary-stdout (dbosoft/ovs#52). OVN gets it
by bumping the `ovs` submodule to a `dbosoft-main` that contains #52; until then
the convergence/`ovn-sbctl`-dump comparisons fail on embedded `\r`.

## Userspace residual (14) — categorized

| Tests | Cause | Disposition |
|---|---|---|
| 41, 42 `ovn-nbctl mirrors`; 157 NB-SB mirrors sync | The `ovn-nbctl` mirror `Index/Key` integer bug: a 32-bit mirror index is sign-extended into the high 32 bits of a 64-bit value (`-4294967296` for `0`). MSVC integer-width/sign-extension. **Real OVN/MSVC bug.** | Fix (separate change). |
| 100 SNI; 234 northd-parallelization unixctl; 256/258 LSP incremental; 259 SB pb incremental; 268 LR NAT incremental; 290 IGMP incremental (all `parallelization=yes`) | `ovs-macros.at:221` hard failures. These drive northd via `kill -STOP`/`-CONT` (SIGSTOP/SIGCONT) or unixctl pause, and several need `add-br`/`lsp-bind` against a datapath — neither method works for a Windows `--detach` daemon. Same family as the already-excluded incremental-processing tests. | Likely exclude (verify each is signal/datapath-bound, then add to excluded-tests.txt). |
| 165, 166 tunnel ids exhaustion | `ovn-macros.at:944`. | Investigate. |
| 353, 354 `ovn-br-controller` | `create` failure. | Investigate. |

## Integration suites (sample)

Not individually triaged. Note: the `ovn.at` expression/register tests
(373 `registers`, 377 `expression parser`, …) show register→OXM/NXM **name**
mismatches (e.g. `xxreg0 = OXM_OF_IP_ECN` vs expected `NXM_NX_XXREG0`). Real flow
generation is correct (the convergence tests pass), so this is an OVS/OVN
**test-expectation version difference** (the dbosoft OVS field set differs from
what OVN's `ovn.at` was written against), not a build bug — it resolves with a
coordinated OVS+OVN resync, not a Windows fix.

## How to reproduce one test

```powershell
.\tests\windows\run-windows-testsuite.ps1 -BuildDir <build-cmake> -Groups '41'
# detailed log: tests/testsuite.dir/<NNNN>/testsuite.log
```
