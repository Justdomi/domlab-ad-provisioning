<#
.SYNOPSIS
    Prepares a fresh Server Core VM's networking before a domain join.

.DESCRIPTION
    Run this on the target member server (e.g. IIS01) BEFORE attempting
    Add-Computer. Installs the VirtIO NIC driver (required if the VM's
    network device is virtio-based, as it is on Proxmox by default),
    assigns a static IP on the domain subnet, and points DNS at the
    domain controller.

.NOTES
    Run on: the new member server's own console (Server Core, no GUI).
    Adjust $StaticIP, $Gateway, $DnsServer, and the driver path to match
    your environment. Confirm the VirtIO ISO's drive letter first with
    Get-Volume — it is not always D:.
#>

# --- Confirm the VirtIO driver ISO's drive letter before running this section ---
# Get-Volume

$DriverPath = "E:\NetKVM\2k22\amd64\netkvm.inf"   # adjust drive letter as needed
$StaticIP   = "10.10.10.22"
$PrefixLen  = 24
$Gateway    = "10.10.10.1"
$DnsServer  = "10.10.10.10"                        # DC01

# Install the VirtIO network driver so Windows can see the adapter at all
pnputil /add-driver $DriverPath /install

# Confirm the adapter is now visible
$adapter = Get-NetAdapter | Select-Object -First 1
if (-not $adapter) {
    throw "No network adapter found after driver install — check the driver path and ISO mount."
}
Write-Host "Adapter found: $($adapter.Name), ifIndex $($adapter.ifIndex)"

# Assign the static IP
New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $StaticIP -PrefixLength $PrefixLen -DefaultGateway $Gateway

# Point DNS at the domain controller
Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DnsServer

# Verify: DNS resolution and reachability to the DC
Resolve-DnsName domlab.local
Test-NetConnection $DnsServer -Port 445
