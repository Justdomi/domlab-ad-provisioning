<#
.SYNOPSIS
    Confirms (and creates if missing) the DNS A record for a newly
    domain-joined member server.

.DESCRIPTION
    Domain-joined machines usually self-register their A record during
    the join. This script checks first and only creates a record if
    one genuinely doesn't exist, to avoid creating a duplicate.

.NOTES
    Run on: DC01 (requires the DnsServer module — this only exists on
    a machine with the DNS Server role installed, not on member
    servers or cluster nodes). If this errors with
    CommandNotFoundException, confirm you're actually on DC01's
    console — check the browser tab's vmid/vmname in the URL bar if
    using a Proxmox noVNC console, it's easy to lose track across
    multiple open tabs.
#>

$ZoneName   = "domlab.local"
$RecordName = "IIS01"
$IPAddress  = "10.10.10.22"

$existing = Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $RecordName -ErrorAction SilentlyContinue

if ($existing) {
    Write-Host "Record already exists — no action needed:"
    $existing | Format-Table HostName, RecordType, Timestamp, TimeToLive, RecordData
} else {
    Write-Host "No record found, creating..."
    Add-DnsServerResourceRecordA -ZoneName $ZoneName -Name $RecordName -IPv4Address $IPAddress
    Get-DnsServerResourceRecord -ZoneName $ZoneName -Name $RecordName
}
