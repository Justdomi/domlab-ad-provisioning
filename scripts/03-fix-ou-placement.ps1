<#
.SYNOPSIS
    Recovery script: moves a computer object out of the default
    CN=Computers container into a real OU, and renames the machine,
    for a domain join that already happened but landed incorrectly.

.DESCRIPTION
    Use this if Add-Computer ran successfully but without -OUPath /
    -NewName (e.g. from a broken multi-line paste), leaving the
    computer object in the default Computers container under its
    auto-generated hostname (WIN-XXXXXXXXXXX).

.NOTES
    PART 1 runs on DC01 (requires the ActiveDirectory module — run
    Import-Module ActiveDirectory first if Get-ADComputer errors out
    with CommandNotFoundException).

    PART 2 runs on the member server itself, AFTER Part 1 has been
    verified to have actually moved the object (Move-ADObject can
    return no error and no output while doing nothing at all if the
    target OU path is misspelled or the wrong session is active —
    always verify with a follow-up Get-ADComputer, don't trust silence).
#>

# ============================================================
# PART 1 — run on DC01
# ============================================================

$OldHostname = "WIN-VGMPDNLR0EL"     # the auto-generated hostname to find
$TargetOU    = "OU=DOMLAB-Computers,DC=domlab,DC=local"

Import-Module ActiveDirectory

# Confirm the object exists and see its current location
$computer = Get-ADComputer -Identity $OldHostname
Write-Host "Found: $($computer.DistinguishedName)"

# Move it into the real OU (use -Identity with the DN, not a -Filter
# piped in — more reliable and fails loudly if something's wrong)
Move-ADObject -Identity $computer.DistinguishedName -TargetPath $TargetOU

# VERIFY — do not skip this step
$moved = Get-ADComputer -Identity $OldHostname -Properties DistinguishedName
Write-Host "Now at: $($moved.DistinguishedName)"
if ($moved.DistinguishedName -notlike "*$TargetOU*") {
    throw "Move did not take effect — check the target OU path for typos and confirm you're on DC01."
}

# ============================================================
# PART 2 — run on the member server itself, once Part 1 is confirmed
# ============================================================

<#
$NewHostname = "IIS01"

Rename-Computer -NewName $NewHostname `
    -DomainCredential (Get-Credential -Message "Enter domain admin credentials (format: DOMLAB\Administrator)") `
    -Restart

# If this fails with a credential-shaped error even though the password
# is correct, verify auth independently before assuming it's wrong:
#   net use \\DC01\IPC$ /user:DOMLAB\Administrator *
# If that succeeds, the problem is authorization/object placement
# (i.e. Part 1 above genuinely needs to complete first), not the password.
#>
