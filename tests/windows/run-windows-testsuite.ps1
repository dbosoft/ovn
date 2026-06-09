<#
.SYNOPSIS
  Run the OVN Windows autotest suite (tests/windows-testsuite.at) against the
  CMake/MSVC-built binaries, under MSYS2 -- no full autotools build.

.DESCRIPTION
  dbosoft OVN counterpart of ovs/tests/windows/run-windows-testsuite.ps1.
  Self-contained: it does everything the suite needs so nothing has to be set up
  by hand (that is how "missing test PKI" silently broke runs before):
    1. alias the CMake `ovntest` as `ovstest` (the name the .at bodies invoke);
    2. autom4te-generate tests/testsuite from the manifest + write tests/package.m4;
    3. repoint tests/atconfig's abs_* paths at THIS checkout;
    4. GENERATE THE TEST PKI (ovs-pki: the testpki-*.pem the ssl/tls tests need) --
       idempotent, skipped if tests/testpki-cacert.pem already exists;
    5. run the suite -j1 with AUTOTEST_PATH pointed at the CMake Release dirs;
    6. a stall-watchdog reaps ONLY this run's daemons when the suite wedges, so a
       single hung test can't block -j1 (progress = newest mtime under
       tests/testsuite.dir; the at-groups dir number is NOT a valid progress
       signal -- autotest pre-creates the range endpoint).

  eryph-zero managed OVN/OVS services (started before this run) are never touched:
  the watchdog only kills processes whose StartTime >= the run start.

.EXAMPLE
  .\run-windows-testsuite.ps1                       # whole suite
  .\run-windows-testsuite.ps1 -Groups '1-371'       # a range
  .\run-windows-testsuite.ps1 -List                 # just list groups
#>
[CmdletBinding()]
param(
  [string]$BuildDir   = 'F:\source\repos\dbosoft\ovn\build-cmake',
  [string]$Groups     = '',                       # autotest selector, e.g. '1-371' or '1 2 3'
  [int]$StallSeconds  = 90,                        # reap if testsuite.dir is quiet this long
  [string]$Msys2      = 'C:\msys64',
  [string]$OpenSslDir = 'C:\OpenSSL-Win64',
  [string]$PthreadsBin= 'C:\PTHREADS-BUILT\bin',
  [switch]$List
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path "$PSScriptRoot\..\..").Path
$bash = Join-Path $Msys2 'usr\bin\bash.exe'
$rel  = Join-Path $BuildDir 'Release'
$ovsrel = Join-Path $BuildDir 'ovs\Release'
if (-not (Test-Path (Join-Path $rel 'ovntest.exe'))) { throw "ovntest.exe not under $rel -- build first." }
if (-not (Test-Path $bash)) { throw "MSYS2 bash not found at $bash" }

# CN list mirrors tests/automake.mk TESTPKI_CNS.
$cns = 'test test2 main hv hv-foo hv1 hv2 hv3 hv4 hv5 hv6 hv7 hv8 hv9 hv10 hv-1 hv-2 hv-10-1 hv-10-2 hv-20-1 hv-20-2 vtep hv_gw pbr-hv gw1 gw2 gw3 gw4 gw5 ext1'

function To-Msys([string]$p) { '/' + $p.Substring(0,1).ToLower() + ($p.Substring(2) -replace '\\','/') }
$repoM = To-Msys $repo
$opensslBin = To-Msys (Join-Path $OpenSslDir 'bin')

# --- setup (suite + atconfig + PKI) done in one MSYS bash pass -------------
$setup = @"
set -e
cd '$repoM'
[ -e build-cmake/Release/ovstest.exe ] || cp build-cmake/Release/ovntest.exe build-cmake/Release/ovstest.exe
cat > tests/package.m4 <<EOF
m4_define([AT_PACKAGE_NAME],[ovn])
m4_define([AT_PACKAGE_TARNAME],[ovn])
m4_define([AT_PACKAGE_VERSION],[26.03.90])
m4_define([AT_PACKAGE_STRING],[ovn 26.03.90])
m4_define([AT_PACKAGE_BUGREPORT],[bugs@openvswitch.org])
m4_define([AT_PACKAGE_URL],[])
EOF
autom4te --language=autotest -I . -o tests/testsuite tests/windows-testsuite.at
chmod +x tests/testsuite
sed -i -E "s#^(abs_top_srcdir=).*#\1'$repoM'#; s#^(abs_top_builddir=).*#\1'$repoM'#; s#^(abs_srcdir=).*#\1'$repoM/tests'#; s#^(abs_builddir=).*#\1'$repoM/tests'#" tests/atconfig
# Test PKI (idempotent): generate testpki-*.pem the ssl/tls tests need.
if [ ! -e tests/testpki-cacert.pem ]; then
    export PATH='$opensslBin':"`$PATH"
    PKI="sh $repoM/ovs/utilities/ovs-pki.in --dir=$repoM/tests/pki --log=$repoM/tests/ovs-pki.log"
    rm -rf tests/pki
    `$PKI init
    ( cd tests/pki && for cn in $cns; do `$PKI -u req+sign `$cn || exit 1; done )
    cp tests/pki/switchca/cacert.pem tests/testpki-cacert.pem
    for cn in $cns; do
        cp tests/pki/`$cn-cert.pem    tests/testpki-`$cn-cert.pem
        cp tests/pki/`$cn-privkey.pem tests/testpki-`$cn-privkey.pem
        cp tests/pki/`$cn-req.pem     tests/testpki-`$cn-req.pem
    done
    echo "PKI generated."
else
    echo "PKI present, skipping."
fi
"@
Write-Host "[setup] generating suite + PKI ..."
& $bash -lc $setup
if ($LASTEXITCODE -ne 0) { throw "setup failed (rc=$LASTEXITCODE)" }

$ap = "$(To-Msys $rel):$(To-Msys $ovsrel):$(To-Msys $PthreadsBin):$(To-Msys $OpenSslDir):$repoM/tests"
$py = (Get-Command python3 -EA SilentlyContinue); if ($py) { $ap += ':' + (To-Msys (Split-Path $py.Source)) }

if ($List) { & $bash -lc "cd '$repoM' && sh tests/testsuite -C tests -l"; return }

# --- compute run set = candidates minus excluded-tests / excluded-keywords --
# Method/feature-incompatible tests are skipped here (NOT real bugs); see
# excluded-tests.txt / excluded-keywords.txt and known-failures.md.
$exclTitle = @(); if (Test-Path "$PSScriptRoot\excluded-tests.txt")    { $exclTitle = Get-Content "$PSScriptRoot\excluded-tests.txt"    | ForEach-Object { ($_ -replace '#.*','').Trim() } | Where-Object { $_ } }
$exclKw    = @(); if (Test-Path "$PSScriptRoot\excluded-keywords.txt") { $exclKw    = Get-Content "$PSScriptRoot\excluded-keywords.txt" | ForEach-Object { ($_ -replace '#.*','').Trim() } | Where-Object { $_ } }
$listing = & $bash -lc "cd '$repoM' && sh tests/testsuite -C tests -l"
$tests = @(); $cur = $null
foreach ($ln in $listing) {
  if ($ln -match '^\s*(\d+):\s+[\w.\-]+\.at:\d+\s+(.*?)\s*$') {
    if ($cur) { $tests += $cur }; $cur = [pscustomobject]@{ num=[int]$Matches[1]; title=$Matches[2]; kws='' }
  } elseif ($cur) { $cur.kws = ($cur.kws + ' ' + $ln.Trim()).Trim() }
}
if ($cur) { $tests += $cur }
$lo=0;$hi=0;$explicit=$null
if ($Groups -match '^\s*(\d+)\s*-\s*(\d+)\s*$') { $lo=[int]$Matches[1]; $hi=[int]$Matches[2] }
elseif ($Groups.Trim()) { $explicit = @($Groups -split '\s+' | ForEach-Object {[int]$_}) }
$run = New-Object System.Collections.Generic.List[int]; $skipped = 0
foreach ($t in $tests) {
  if ($lo -and ($t.num -lt $lo -or $t.num -gt $hi)) { continue }
  if ($explicit -and ($t.num -notin $explicit)) { continue }
  $ex = $false
  foreach ($p in $exclTitle) { if ($t.title -like "*$p*") { $ex = $true; break } }
  if (-not $ex) { $kw = $t.kws -split '\s+'; foreach ($k in $exclKw) { if ($kw -contains $k) { $ex = $true; break } } }
  if ($ex) { $skipped++ } else { $run.Add($t.num) }
}
Write-Host ("[run] {0} groups; skipping {1} method/feature-incompatible (excluded-*.txt)" -f $run.Count, $skipped)
$sel = ($run -join ' ')

# --- run with stall-watchdog ----------------------------------------------
$out = Join-Path $BuildDir 'winsuite.out'
$tdir = Join-Path $repo 'tests\testsuite.dir'
$runStart = Get-Date
$runScript = Join-Path $BuildDir 'winsuite_inner.sh'
$inner = "cd '$repoM' && sh tests/testsuite -C tests AUTOTEST_PATH='$ap' $sel -j1; echo RANGE_EXIT=`$? "
[IO.File]::WriteAllText($runScript, ($inner -replace "`r",""), (New-Object Text.UTF8Encoding($false)))
$p = Start-Process $bash -ArgumentList @('-l', (To-Msys $runScript)) -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError "$out.err"

function Reap { Get-Process ovsdb-server,ovs-vswitchd,ovn-northd,ovn-controller,ovn-nbctl,ovn-sbctl,ovn-ic,ovn-trace,ovn-appctl,ovn-controller-vtep -EA SilentlyContinue | Where-Object { $_.StartTime -ge $runStart } | Stop-Process -Force -EA SilentlyContinue }

$lastMtime = Get-Date; $reaps = 0
while (-not $p.HasExited) {
  Start-Sleep 15
  $newest = $null
  if (Test-Path $tdir) { $newest = (Get-ChildItem $tdir -Recurse -File -EA SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1).LastWriteTime }
  if ($newest -and $newest -gt $lastMtime) { $lastMtime = $newest }
  if (((Get-Date) - $lastMtime).TotalSeconds -gt $StallSeconds) {
    Reap; $reaps++; $lastMtime = Get-Date
    Write-Host ("[watchdog] stall -> reaped this run's daemons (reap #{0}) at {1}" -f $reaps, (Get-Date -Format HH:mm:ss))
  }
}
Start-Sleep 2; Reap

# --- tally ------------------------------------------------------------------
$o = @(Get-Content $out -EA SilentlyContinue)
$ok   = @($o | Select-String -Pattern '^\s*\d+:.*\bok\s*$').Count
$fail = @($o | Select-String -Pattern 'FAILED \(').Count
$skip = @($o | Select-String -Pattern '\bskipped \(').Count
Write-Host ("`n==== DONE reaps={0} ok={1} FAILED={2} skipped={3} ====" -f $reaps,$ok,$fail,$skip)
$o | Select-String -Pattern 'were run|successful|behaved as expected|failed unexpectedly|RANGE_EXIT' | ForEach-Object { $_.Line.Trim() }
$o | Select-String -Pattern 'FAILED \(' | ForEach-Object { $_.Line.Trim() }
