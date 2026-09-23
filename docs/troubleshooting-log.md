# Troubleshooting Log — IIS01 Member Server Build

Real issues hit during this build, in the order encountered, with root cause, fix, and the actual console output for each. Screenshots referenced below live in [`../screenshots/`](../screenshots/) — see [`MANIFEST.md`](../screenshots/MANIFEST.md) for the full original-to-repo filename mapping.

---

### 1. `Get-NetAdapter` returned nothing at all

**Symptom:** Fresh VM, no adapters listed — not even a header row.

![Get-NetAdapter empty](../screenshots/01-01-get-netadapter-empty.png)

**Root cause:** The VM's NIC was configured as VirtIO (`net0: virtio=...` in the Proxmox config). VirtIO is a paravirtualized device type with no native Windows driver — Windows genuinely cannot see the adapter until the driver is installed.

**Fix:**
```powershell
pnputil /add-driver E:\NetKVM\2k22\amd64\netkvm.inf /install
```
First attempt failed against drive `D:` — the `virtio-win.iso` had mounted to a different letter than assumed. Confirm with `Get-Volume` before referencing a drive letter.

![Driver installed, adapter found](../screenshots/01-02-driver-installed-adapter-found.png)

---

### 2. `New-NetIPAddress` returned `AddressState: Invalid`

**Symptom:** After assigning a static IP, `AddressState` showed `Invalid` instead of the expected `Preferred`.

![Address state invalid](../screenshots/02-01-address-state-invalid.png)

**Root cause:** Transient Duplicate Address Detection (DAD) hiccup — Windows briefly couldn't confirm the address was conflict-free.

**Fix:** None needed. Re-checked with `ipconfig /all` moments later and the address had settled to `Preferred`.

**But `ipconfig /all` surfaced a second, real problem:** the DNS Servers field showed `fec0:0:0:ffff::1`, `::2`, `::3` — Windows' deprecated site-local IPv6 placeholders, not DC01. The `Set-DnsClientServerAddress` step had been skipped during the troubleshooting detour, so the server had no idea where its domain DNS lived.

![ipconfig shows DNS not set](../screenshots/02-02-ipconfig-dns-not-set.png)

Raw routing to DC01 was fine (`Test-NetConnection` on port 445 succeeded), which proved the network path independently of DNS:

![Connectivity confirmed](../screenshots/02-03-connectivity-confirmed.png)

Pointing DNS at DC01 fixed name resolution:
```powershell
Set-DnsClientServerAddress -InterfaceIndex 6 -ServerAddresses 10.10.10.10
Resolve-DnsName domlab.local
```
![DNS resolution confirmed](../screenshots/02-04-dns-resolution-confirmed.png)

**Lesson:** Network reachability and name resolution are two separate checks. Port 445 succeeding proves the path; `Resolve-DnsName` proves the DC will actually answer a domain-join request.

---

### 3. DNS cmdlets failing with `CommandNotFoundException`

**Symptom:** `Get-DnsServerResourceRecord` / `Add-DnsServerResourceRecordA` repeatedly not recognized, across multiple attempts on multiple machines.

![WINCL01NODE01 cluster DNS error](../screenshots/03-01-wincl01node01-cluster-dns-error.png)
![WINCL01NODE01 DNS error](../screenshots/03-02-wincl01node01-dns-error.png)

**Root cause:** The `DnsServer` PowerShell module only exists on a machine with the DNS Server *role* installed — not on WSFC cluster nodes, not on the member server itself. Ran the command from the wrong machine multiple times before catching this. Even after switching consoles, one attempt still hit the same wall:

![Get-ADDomain succeeding](../screenshots/03-03-get-addomain-success.png)
![DNS still failing](../screenshots/03-04-dns-still-failing.png)

The `Get-ADDomain` success was misleading — it only proves the `ActiveDirectory` module is loaded, which is a completely separate module from `DnsServer`. A hostname check finally revealed the real problem: the console in use the whole time was never DC01.

![Hostname reveals wrong machine](../screenshots/03-05-hostname-reveals-wrong-machine.png)

**Fix:** Confirm which machine you're actually on before running role-specific cmdlets:
```powershell
$env:COMPUTERNAME
hostname
```
Then run DNS commands only from DC01.

---

### 4. Broken multi-line paste silently dropped `Add-Computer` parameters

**Symptom:** `Add-Computer -DomainName "domlab.local" \`<newline>-OUPath ...` was pasted as one multi-line command using backtick continuation. Only the first line executed; `-OUPath`, `-NewName`, and `-Restart` were submitted afterward as their own (invalid) standalone commands and errored out separately.

![Add-Computer broken paste](../screenshots/04-01-add-computer-broken-paste.png)

**Root cause:** Backtick line-continuation in PowerShell is fragile across copy-paste into a console window (especially a browser-based noVNC console) — trailing whitespace or how the clipboard handles line breaks can break it silently, with no warning that the command was truncated.

**Result:** The domain join itself succeeded (confirmed via the `WARNING: changes will take effect after restart` message) but landed in the default `CN=Computers` container under the auto-generated hostname, instead of the intended OU with the intended name.

**Fix:** Either run multi-line commands from a script file (`.ps1`) instead of pasting into a console, or write the whole command as a single unbroken line.

---

### 5. `Move-ADObject` appeared to succeed but did nothing — twice

**Symptom:** No error, no output, ran clean — but a follow-up `Get-ADComputer` check showed the object hadn't actually moved.

![GPInheritance not recognized](../screenshots/05-01-gpinheritance-not-recognized.png)

**Root cause, layer by layer:**

**1. First attempt — the target OU didn't exist.** `OU=Servers,DC=domlab,DC=local` was never a real OU in this domain.

![GPMC installed, OU not found](../screenshots/05-02-gpmc-installed-ou-not-found.png)
![OU filter attempts](../screenshots/05-03-ou-filter-attempts.png)
![Computer still in default container](../screenshots/05-04-computer-still-in-default-container.png)

Confirmed via the real OU tree:
```powershell
Get-ADOrganizationalUnit -Filter * | Select Name, DistinguishedName
```
![Real OU tree discovered](../screenshots/05-05-real-ou-tree-discovered.png)

which surfaced the actual structure (`DOMLAB`, `DOMLAB-Users`, `DOMLAB-Groups`, `DOMLAB-Computers`, plus nested `IT`/`Finance`/`Sales`/`Operations`). `DOMLAB-Computers` was the correct existing target.

**2. Second attempt — wrong session entirely.** Commands were being run from a PowerShell session on **IIS01**, not DC01, despite believing otherwise.

![First move attempt, no error](../screenshots/05-06-move-adobject-attempt-1.png)
![Move verified as failed](../screenshots/05-07-move-verified-failed.png)
![Wrong session, no AD module](../screenshots/05-08-wrong-session-no-ad-module.png)
![Import-Module fails](../screenshots/05-09-import-module-fails.png)
![Hostname confirms IIS01](../screenshots/05-10-hostname-confirms-iis01.png)

The `ActiveDirectory` module was never installed on IIS01, so every AD cmdlet failed outright — including ones that had appeared to succeed minutes earlier in a different, since-abandoned browser tab.

**3. Third attempt — a one-character typo, finally a real error.** Once genuinely on DC01 (confirmed via `hostname`), `OU=DOMLAB-Computer` (singular) vs. the real `OU=DOMLAB-Computers` (plural) produced a real, traceable error:

![Typo root cause found](../screenshots/05-11-typo-root-cause-found.png)
```
Move-ADObject : The operation could not be performed because the object's parent is either uninstantiated or deleted
```

**Fix:** Corrected the OU name spelling, ran again, and verified explicitly:
```powershell
Get-ADComputer -Identity "WIN-VGMPDNLR0EL" -Properties DistinguishedName | Select DistinguishedName
```
![Move corrected and verified](../screenshots/05-12-move-corrected-and-verified.png)

**Lesson:** A pipeline with zero errors and zero output is not proof of success. Verify with a follow-up read after every mutating AD command — especially when working across multiple console tabs, where it's easy to lose track of which VM's session is actually active.

---

### 6. `Rename-Computer` failed with a credential-shaped error, even with correct credentials

**Symptom:**
```
Rename-Computer : Fail to rename computer 'WIN-VGMPDNLR0EL' to 'IIS01' due to the following exception: The user name...
```

![Rename fails, credential error](../screenshots/06-01-rename-fails-credential-error.png)
![Rename retry, wrong-machine ACL check](../screenshots/06-02-rename-retry-and-wrong-machine-acl.png)

Looked like a password/format problem. Retried with the `DOMLAB\Administrator` format — same failure.

**Root cause isolation:** Instead of continuing to guess at credential formats, tested authentication independently of the rename operation:

![net use missing parameter](../screenshots/06-03-net-use-missing-param.png)
```powershell
net use \\DC01\IPC$ /user:DOMLAB\Administrator *
# The command completed successfully.
```
![net use success](../screenshots/06-04-net-use-success.png)

This proved the credentials were completely correct — the failure was authorization, not authentication.

**Actual root cause:** The computer object was still sitting in the default `CN=Computers` **container** (not yet successfully moved — see issue #5), which has different, more restrictive delegation than a purpose-built OU. Once the object was confirmed to be correctly located in `OU=DOMLAB-Computers`, the exact same rename command with the exact same credentials succeeded immediately.

**Lesson:** When an operation fails with a credential-shaped error, test authentication in isolation (`net use`, or similar) before assuming the password/username is wrong. A valid credential can still fail if the *target object* doesn't grant that credential the specific permission the operation needs.

---

### 7. Assorted command typos

Several straightforward typos surfaced along the way, each producing a clear enough PowerShell error to self-diagnose:

| Typo | Should be | Error produced |
|---|---|---|
| `NewSmbShare` | `New-SmbShare` | `CommandNotFoundException` |
| `-IPv4Address10.10.10.22` (no space) | `-IPv4Address 10.10.10.22` | `ParameterBindingException` |
| `Get-ADComputer Filyer 'Name -life "..."'` | `Get-ADComputer -Filter 'Name -like "..."'` | `PositionalParameterNotFound` |
| `-OUPATH` (as its own line, from the broken paste in #4) | n/a — was never meant to run standalone | `CommandNotFoundException` |
| `-Filter '-Name -like "..."'` (leading dash inside the filter string) | `-Filter 'Name -like "..."'` | `ADFilterParsingException` at position 1 |

The filter one is worth calling out: AD `-Filter` takes a PowerShell-style *expression* as a string (`Name -like "x"`, same as an `if` test), not a parameter flag, so a leading `-` breaks the parser.

![Filter leading-dash parse error](../screenshots/07-00-filter-leading-dash-error.png)
![IIS installed, hostname confirmed](../screenshots/07-01-iis-installed-hostname-confirmed.png)
![NewSmbShare typo](../screenshots/07-02-newsmbshare-typo.png)
![DNS record and typo](../screenshots/07-03-dns-record-and-typo.png)
![Final DNS record verified](../screenshots/07-04-final-dns-record-verified.png)

**Lesson:** PowerShell cmdlets are strictly `Verb-Noun` with a hyphen; parameters need a space between the flag and its value. These errors are usually self-explanatory once read carefully rather than re-run on instinct.

---

## Summary of Root-Cause Categories

Every issue in this build fell into one of four buckets:

1. **Missing driver/role/module** — VirtIO NIC driver, DnsServer module, ActiveDirectory module, GroupPolicy module. Windows/PowerShell only expose what's actually installed.
2. **Wrong console/session** — running commands against the wrong VM's console, or a PowerShell session that never loaded a needed module.
3. **Silent no-ops** — commands that produced no error and no output while accomplishing nothing, due to a bad target path or an empty pipeline upstream.
4. **Typos** — missing hyphens, missing spaces, misspelled OU names, singular/plural mismatches.

None of these were exotic failures — all four categories are extremely common in real enterprise Windows administration, which is exactly why documenting them (rather than only the clean final commands) has real value.
