<#

Description: Connect to a vCenter and calculate the pCPU:vCPU ratio
Author: David Comerford

=== Tested Against Environment ===
vSphere Version: 5.5

#>


param(
  [Parameter(Mandatory=$true, Position=0, HelpMessage="vCenter hostname or IP")][string]$vcenter,
  [Parameter(Mandatory=$true, Position=1, HelpMessage="Username for vCenter")][string]$user
  )

#
# Variables
$global:clusterlist = "empty"
$targetratio = 4
$Output=@()

$passwordin = Read-Host -AsSecureString -Prompt "Enter password for $user@$vcenter"
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordin))

#
# Attempt connections to vCenter
cls
Write-Host "Connecting to $vcenter with user $user..."
$vc = Connect-VIServer $vcenter -User $user -Password $password -WarningAction SilentlyContinue

#
# Check if connection was established. Exit if login failed
if(-Not $vc.IsConnected) {
    Write-Host -ForegroundColor Yellow "Unable to connect to $vcenter. Exiting."
    Write-Host "Make sure your username format is correct."
    Write-Host "example: user.name@domainname or username@vsphere.local"
    Write-Host ""

    exit # exit if unable to connect
}
else {
    Write-Host -ForegroundColor Green "Connected successfully"
}

#
# displays menu of list of clusters
function Show-Cluster-Menu {

    Write-Host ""
    Write-Host ""
    Write-Host -ForegroundColor White "=========== Clusters ==========="

    $global:clusterlist = Get-Cluster

    # print out the array with numbers to make picking easier
    foreach ($item in $clusterlist) {
        Write-Host $clusterlist.IndexOf($item): $item 
    }
    
    Write-Host
    Write-Host "Press 'q' to quit."
}

#
# cluster object passed to function
function Get-Cluster-Data($clusterselection) {
    
    Write-Host ""
    Write-Host "Processing cluster $clusterselection "
    Write-Host ""

    # build an list of hosts in cluster
    $vmhosts = Get-VMHost -Location $clusterselection

    # Number of hosts in the cluster
    $numhosts = $vmhosts.count

    # Host RAM
    $clustertotalram = $vmhosts | Measure-Object 'MemoryTotalGB' -Sum
    
    # Host RAM less one for HA
    $clustertotalramlessha = $clustertotalram.Sum - ($clustertotalram.Sum/$numhosts)
    
    # Host CPU cores
    $clustertotalcores = $clusterselection.ExtensionData.Summary.NumCpuCores

    # Host CPU cores less one host for HA
    $clustertotalcoreslessha = $clustertotalcores - ($clustertotalcores/$numhosts)

    # VM vCPUs
    $clustervmtotalcores = $vmhosts | Get-VM | Measure-Object 'NumCPU' -Sum

    # build a list of VMs in cluster
    $vmmemory = $clusterselection | Get-VM | Measure-Object 'MemoryGB' -Sum

    # Round up the numbers
    $clustertotalramparsed = [math]::Round($clustertotalram.Sum)
    $clustertotalramlesshaparsed = [math]::Round($clustertotalramlessha)
    $clustervmtotalcoresparsed = $clustervmtotalcores.Sum
    $vmmemoryparsed = [math]::Round($vmmemory.Sum)

    # pCPU:vCPU ratio
    $cpuratio = [math]::Round($clustervmtotalcoresparsed/$clustertotalcores,1)
    $cpuratiolessha = [math]::Round($clustervmtotalcoresparsed/$clustertotalcoreslessha,1)

    # Print the stuff
    $temp= New-Object psobject
    $temp| Add-Member -MemberType Noteproperty "Cluster RAM" -value "$clustertotalramparsed GB"
    $temp| Add-Member -MemberType Noteproperty "Cluster RAM less HA host" -Value "$clustertotalramlesshaparsed GB"

    $temp| Add-Member -MemberType NoteProperty "VM vRAM" -Value "$vmmemoryparsed GB"

    $temp| Add-Member -MemberType Noteproperty "Cluster cores" -Value $clustertotalcores
    $temp| Add-Member -MemberType Noteproperty "Cluster cores less HA" -Value $clustertotalcoreslessha
    
    $temp| Add-Member -MemberType Noteproperty "Total vCPUs" -Value $clustervmtotalcoresparsed

    $temp| Add-Member -MemberType Noteproperty "pCPU:vCPU ratio" -Value "1:$cpuratio"
    $temp| Add-Member -MemberType Noteproperty "pCPU:vCPU ratio less HA" -Value "1:$cpuratiolessha "
    $Output+=$temp

    $temp

}


#
# Print the cluster menu in a loop
do 
{
   Show-Cluster-Menu
   $clusterselection = Read-Host "Pick cluster"

   if ($clusterselection -eq "q") {
        break
   }
   

   # Get the cluster object from selection
   $clusterselectionobj = $clusterlist[$clusterselection]

   # pass the cluster object to the function
   Get-Cluster-Data($clusterselectionobj)
}
until ($clusterselection -eq 'q')


Disconnect-VIServer -Server $vcenter -Confirm:$false -force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue | Out-Null
Write-Host
Write-Host "Disconnected from $vcenter"