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

$passwordin = Read-Host -AsSecureString -Prompt "Enter password for $user@$vcenter "
$password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordin))

$global:clusterlist = "empty"
$targetratio = 4
$Output=@()

cls
Write-Host "Connecting to $vcenter with user $user..."
Write-Host 

Connect-VIServer $vcenter

#
# displays menu of list of clusters
function Show-Cluster-Menu {

    Write-Host ""
    Write-Host ""
    Write-Host -ForegroundColor Gray "============= Clusters ================"

     $global:clusterlist = Get-Cluster

    # print out the array with numbers to make picking easier
    foreach ($item in $clusterlist) {
        Write-Host $clusterlist.IndexOf($item): $item 
    }
    # q to quit
    Write-Host
    Write-Host "Press 'q' to quit."
}

#
# cluster object passed to function
function Get-Cluster-Data($clusterselection) {
    
    Write-Host ""
    Write-Host "Processing cluster $clusterselection "
    Write-Host ""

    # build an array of hosts in cluster
    $vmhosts = Get-VMHost -Location $clusterselection

    # Number of hosts in the cluster
    $numhosts = $vmhosts.count

    # Add up RAM
    $clustertotalram = $vmhosts | Measure-Object 'MemoryTotalGB' -Sum
    
    # RAM less one host (for HA)
    $clustertotalramlessha = $clustertotalram.Sum - ($clustertotalram.Sum/$numhosts)
    
    # Count CPU cores
    $clustertotalcores = $clusterselection.ExtensionData.Summary.NumCpuCores

    # CPU cores less one host (for HA)
    $clustertotalcoreslessha = $clustertotalcores - ($clustertotalcores/$numhosts)

    # Count VM vCPUs
    $clustervmtotalcores = $vmhosts | Get-VM | Measure-Object 'NumCPU' -Sum

    # Round up the numbers
    $clustertotalramparsed = [math]::Round($clustertotalram.Sum)
    $clustertotalramlesshaparsed = [math]::Round($clustertotalramlessha)
    $clustervmtotalcoresparsed = $clustervmtotalcores.Sum

    # pCPU:vCPU ratio
    $cpuratio = [math]::Round($clustervmtotalcoresparsed/$clustertotalcores,1)
    $cpuratiolessha = [math]::Round($clustervmtotalcoresparsed/$clustertotalcoreslessha,1)

    # Print the stuff
    Write-Host -foreground Green "Cluster RAM: 't $clustertotalramparsed GB"
    Write-Host -Foreground Green "Cluster RAM less HA: $clustertotalramlesshaparsed GB"
    Write-Host ""
    Write-Host -foreground Green "Cluster cores: " $clustertotalcores
    Write-Host -foreground Green "Cluster cores less HA: " $clustertotalcoreslessha
    Write-Host ""
    Write-Host -ForegroundColor Yellow "Total vCPUs: $clustervmtotalcoresparsed"

    Write-Host -ForegroundColor Yellow "pCPU:vCPU ratio: 1:$cpuratio"
    Write-Host -ForegroundColor Yellow "pCPU:vCPU ratio less HA: 1:$cpuratiolessha"
    
    Write-Host ""
    Write-Host ""
    Write-Host ""

    $temp= New-Object psobject
    $temp| Add-Member -MemberType Noteproperty "Cluster RAM" -value "$clustertotalramparsed GB"
    $temp| Add-Member -MemberType Noteproperty "Cluster RAM less HA host" -Value $clustertotalramlesshaparsed

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


Disconnect-VIServer -Server $vcenter -Confirm:$false
Write-Host
Write-Host "Disconnected from $vcenter"