# Screenshot Manifest

All 33 screenshots from the live build session, in the order they appear in [`docs/troubleshooting-log.md`](../docs/troubleshooting-log.md). Filenames are prefixed by troubleshooting-log section number.

| File | Original capture | Shows |
|---|---|---|
| `01-01-get-netadapter-empty.png` | 2026-09-23 00:14 | `Get-NetAdapter` returns nothing (no VirtIO driver) |
| `01-02-driver-installed-adapter-found.png` | 00:23 | `pnputil` installs NetKVM; adapter appears as ifIndex 6 |
| `02-01-address-state-invalid.png` | 00:27 | `AddressState: Invalid` (transient DAD) |
| `02-02-ipconfig-dns-not-set.png` | 00:29 | `ipconfig /all`: DNS still on `fec0::` placeholders |
| `02-03-connectivity-confirmed.png` | 00:30 | Address `Preferred`; port 445 to DC01 succeeds |
| `02-04-dns-resolution-confirmed.png` | 00:35 | DNS set to 10.10.10.10; `Resolve-DnsName` succeeds |
| `03-01-wincl01node01-cluster-dns-error.png` | 2026-09-22 23:48 | DNS cmdlets fail on WSFC node; `Get-ClusterNode` output |
| `03-02-wincl01node01-dns-error.png` | 23:53 | Same wrong-machine DNS errors |
| `03-03-get-addomain-success.png` | 23:57 | `Get-ADDomain` works (AD module ≠ DNS module) |
| `03-04-dns-still-failing.png` | 2026-09-23 00:00 | DNS cmdlets still failing |
| `03-05-hostname-reveals-wrong-machine.png` | 00:04 | Hostname reveals the console was never DC01 |
| `04-01-add-computer-broken-paste.png` | 00:43 | Broken backtick paste drops `-OUPath`/`-NewName`/`-Restart` |
| `05-01-gpinheritance-not-recognized.png` | 02:01 | `Get-GPInheritance` missing (no GPMC) |
| `05-02-gpmc-installed-ou-not-found.png` | 02:05 | GPMC installed; `Servers` OU doesn't exist |
| `05-03-ou-filter-attempts.png` | 02:14 | OU query attempts with typos |
| `05-04-computer-still-in-default-container.png` | 02:16 | Object still in `CN=Computers` |
| `05-05-real-ou-tree-discovered.png` | 02:18 | Full real OU tree, no `Servers` OU |
| `05-06-move-adobject-attempt-1.png` | 02:24 | Move runs with no error |
| `05-07-move-verified-failed.png` | 02:25 | Verification shows the move didn't happen |
| `05-08-wrong-session-no-ad-module.png` | 02:29 | All AD cmdlets missing in this session |
| `05-09-import-module-fails.png` | 02:31 | `ActiveDirectory` module not installed here |
| `05-10-hostname-confirms-iis01.png` | 02:32 | Hostname confirms session was on IIS01 |
| `05-11-typo-root-cause-found.png` | 02:42 | `DOMLAB-Computer` vs `DOMLAB-Computers`, real AD error |
| `05-12-move-corrected-and-verified.png` | 02:49 | Move succeeds and verifies |
| `06-01-rename-fails-credential-error.png` | 01:27 | `Rename-Computer` credential-shaped failure |
| `06-02-rename-retry-and-wrong-machine-acl.png` | 01:33 | Retry; `AD:` drive check run on wrong machine |
| `06-03-net-use-missing-param.png` | 01:43 | Rename retry with credential prompt dismissed |
| `06-04-net-use-success.png` | 01:49 | `net use` succeeds, credentials proven valid |
| `07-00-filter-leading-dash-error.png` | 01:14 | `-Filter '-Name ...'` parse error on DC01 |
| `07-01-iis-installed-hostname-confirmed.png` | 02:55 | IIS installed; hostname now `IIS01` |
| `07-02-newsmbshare-typo.png` | 03:00 | `NewSmbShare` missing hyphen |
| `07-03-dns-record-and-typo.png` | 03:08 | A record already present; `-IPv4Address` spacing typo |
| `07-04-final-dns-record-verified.png` | 03:11 | Single clean A record, build complete |
