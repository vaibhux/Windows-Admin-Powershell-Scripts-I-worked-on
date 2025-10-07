<# This script does:

Validates cluster nodes using Test-Cluster.

Creates a new failover cluster with New-Cluster.

Displays cluster group status.

Retrieves the last 20 cluster-related events for quick error checking.#>

# -----------------------------
# Basic Failover Cluster Script
# -----------------------------

Import-Module FailoverClusters

# Cluster parameters
$ClusterName = "MyCluster"
$ClusterIP = "192.168.1.100"
$ClusterNodes = @("Node1", "Node2")  # Add all node names here

# Step 1: Validate cluster configuration
Write-Host "Validating cluster nodes: $($ClusterNodes -join ', ')" -ForegroundColor Cyan
Test-Cluster -Node $ClusterNodes -Verbose

# Step 2: Create the cluster
Write-Host "Creating cluster $ClusterName..." -ForegroundColor Cyan
New-Cluster -Name $ClusterName -Node $ClusterNodes -StaticAddress $ClusterIP -NoStorage

# Step 3: Check cluster status
Write-Host "Cluster groups status:" -ForegroundColor Cyan
Get-ClusterGroup -Cluster $ClusterName | Format-Table Name, State, OwnerNode -AutoSize

# Step 4: View recent cluster errors/warnings
Write-Host "Recent cluster events:" -ForegroundColor Cyan
Get-WinEvent -LogName "Microsoft-Windows-FailoverClustering/Operational" -MaxEvents 20 |
    Select-Object TimeCreated, Id, LevelDisplayName, Message | Format-Table -AutoSize

#====================================================================================================================================================================================================================================================================================
#====================================================================================================================================================================================================================================================================================

<#script to automatically parse errors and warnings from both cluster validation and cluster logs, and produce a summary report with recommendations. This is very useful for troubleshooting and ensuring a healthy failover cluster.#>

# -----------------------------
# Script: Create, Validate, and Analyze Failover Cluster
# Requirements: Run as Administrator on all nodes
# Modules: FailoverClusters
# -----------------------------

Import-Module FailoverClusters

# -----------------------------
# Step 1: Define Cluster Parameters
# -----------------------------
$ClusterName = "MyCluster"
$ClusterIP = "192.168.1.100"
$ClusterNodes = @("Node1", "Node2")  # Add all node names here
$ClusterLogDestination = "C:\ClusterLogs"
$ReportFile = "$ClusterLogDestination\ClusterSummaryReport.txt"

# Ensure log folder exists
if (!(Test-Path $ClusterLogDestination)) {
    New-Item -ItemType Directory -Path $ClusterLogDestination -Force
}

# -----------------------------
# Step 2: Validate Cluster Configuration
# -----------------------------
Write-Host "Validating cluster configuration for nodes: $($ClusterNodes -join ', ')" -ForegroundColor Cyan
$ValidationReport = Test-Cluster -Node $ClusterNodes -Verbose

# Parse validation errors/warnings
$ValidationErrors = $ValidationReport | Where-Object {$_.State -eq "Failed"}
$ValidationWarnings = $ValidationReport | Where-Object {$_.State -eq "Warning"}

# Write summary
$Report = @()
$Report += "==== Cluster Validation Report ===="
if ($ValidationErrors) {
    $Report += "Errors found in cluster validation:"
    $ValidationErrors | ForEach-Object { $Report += " - $_.Message" }
} else {
    $Report += "No validation errors found."
}

if ($ValidationWarnings) {
    $Report += "Warnings found in cluster validation:"
    $ValidationWarnings | ForEach-Object { $Report += " - $_.Message" }
} else {
    $Report += "No validation warnings found."
}

# Stop if critical errors exist
if ($ValidationErrors) {
    $Report += "`nCluster validation failed. Fix issues before proceeding."
    $Report | Out-File $ReportFile
    Write-Host "Validation failed. See report at $ReportFile" -ForegroundColor Red
    exit 1
} else {
    $Report += "`nValidation passed. Proceeding to create cluster..."
}

# -----------------------------
# Step 3: Create the Cluster
# -----------------------------
Write-Host "Creating cluster $ClusterName with IP $ClusterIP" -ForegroundColor Cyan
try {
    $Cluster = New-Cluster -Name $ClusterName -Node $ClusterNodes -StaticAddress $ClusterIP -NoStorage -Verbose
    Write-Host "Cluster $ClusterName created successfully!" -ForegroundColor Green
    $Report += "`nCluster $ClusterName created successfully."
} catch {
    $Report += "Error creating cluster: $_"
    $Report | Out-File $ReportFile
    Write-Host "Error creating cluster. See report at $ReportFile" -ForegroundColor Red
    exit 1
}

# -----------------------------
# Step 4: Configure Cluster Quorum (optional)
# -----------------------------
try {
    Set-ClusterQuorum -Cluster $ClusterName -NodeAndFileShareMajority "\\FileServer\QuorumShare"
    $Report += "`nCluster quorum configured successfully."
} catch {
    $Report += "Error configuring quorum: $_"
}

# -----------------------------
# Step 5: Check Cluster Status
# -----------------------------
Write-Host "Checking cluster status..." -ForegroundColor Cyan
$ClusterGroups = Get-ClusterGroup -Cluster $ClusterName
$Report += "`n==== Cluster Groups Status ===="
$ClusterGroups | ForEach-Object { $Report += "Group: $($_.Name), State: $($_.State), Owner: $($_.OwnerNode)" }

# -----------------------------
# Step 6: Collect Cluster Logs and Analyze
# -----------------------------
Write-Host "Generating cluster log..." -ForegroundColor Cyan
Get-ClusterLog -Cluster $ClusterName -Destination $ClusterLogDestination -TimeSpan 1:00:00
$Report += "`nCluster logs saved at $ClusterLogDestination"

# Get recent cluster events (last 50) from Event Viewer
$ClusterEvents = Get-WinEvent -LogName "Microsoft-Windows-FailoverClustering/Operational" -MaxEvents 50
$Errors = $ClusterEvents | Where-Object {$_.LevelDisplayName -eq "Error"}
$Warnings = $ClusterEvents | Where-Object {$_.LevelDisplayName -eq "Warning"}

$Report += "`n==== Recent Cluster Errors ===="
if ($Errors) {
    $Errors | ForEach-Object { $Report += "$($_.TimeCreated) | $($_.Id) | $($_.Message)" }
} else {
    $Report += "No errors found."
}

$Report += "`n==== Recent Cluster Warnings ===="
if ($Warnings) {
    $Warnings | ForEach-Object { $Report += "$($_.TimeCreated) | $($_.Id) | $($_.Message)" }
} else {
    $Report += "No warnings found."
}

# -----------------------------
# Step 7: Output Final Report
# -----------------------------
$Report | Out-File $ReportFile
Write-Host "Cluster setup and validation completed. Summary report saved at $ReportFile" -ForegroundColor Green



