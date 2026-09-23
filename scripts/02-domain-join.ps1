<#
.SYNOPSIS
    Joins the local machine to domlab.local, places it directly into the
    correct OU, and renames it — all in one operation.

.DESCRIPTION
    This is the CORRECT single-command version of the join. Run this
    as one unbroken line (or via this .ps1 file directly — do not
    paste it as multiple separate lines into a console window, since
    backtick line-continuation can silently break on paste and cause
    Add-Computer to run with only -DomainName, dropping -OUPath,
    -NewName, and -Restart).

.NOTES
    Run on: the new member server's own console, AFTER 01-network-setup.ps1
    has completed and Resolve-DnsName / Test-NetConnection both succeed.

    -OUPath below uses OU=DOMLAB-Computers, the OU that actually exists
    in this domain. There is no OU literally named "Servers" — confirm
    your own domain's real OU tree with Get-ADOrganizationalUnit -Filter *
    from DC01 before reusing this script elsewhere.
#>

$NewHostname = "IIS01"
$OUPath      = "OU=DOMLAB-Computers,DC=domlab,DC=local"

Add-Computer -DomainName "domlab.local" `
    -OUPath $OUPath `
    -NewName $NewHostname `
    -Credential (Get-Credential -Message "Enter domain admin credentials (format: DOMLAB\Administrator)") `
    -Restart
