<#
.SYNOPSIS
    Installs the IIS web server role and creates the NTFS file share
    for the member server.

.NOTES
    Run on: the member server, after the domain join is confirmed
    complete (hostname shows the new name, machine has rebooted).
#>

# Install IIS with management tools
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Create the share directory
New-Item -Path "C:\Shares\DomLabShare" -ItemType Directory -Force

# Create the SMB share
New-SmbShare -Name "DomLabShare" -Path "C:\Shares\DomLabShare" -FullAccess "DOMLAB\Domain Admins"

# Verify
Get-SmbShare -Name "DomLabShare"
