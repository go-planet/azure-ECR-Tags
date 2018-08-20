<#  
.SYNOPSIS   
    Generate a CSV for Azure Resources that are missing required tags

.DESCRIPTION  
    This runbook will generate a report of resources that are missing tags based on an array of tags passed in as a parameter.

    Prereq:     
        1. 
    
.PARAMETER RequiredTags  
    Array of tags that are required for all resources (these are case-sensitive)
    Example: "Application","Owner","Division","Environment","CostCenter"
  
.PARAMETER StorageAccountName 
    String Azure Storage account name where the report will be saved
    Example: djdreportrepository01sa

.PARAMETER StorageAccountShare 
    String file share in the Azure Storage account where the report will be saved
    Example: TagReports

.PARAMETER StorageAccountResourceGroup
    String resource group name of Azure Storage account
    Example: djdGenStorage-rg

.EXAMPLE  
  Get-MissingTagsReport -RequiredTags "Application","Owner","Division","Environment","CostCenter" -StorageAccountName djdreportrepository01sa -StorageAccountShare weeklytagreport -StorageAccountResourceGroup djdGenStorage-rg

.NOTES  
    Author: Michael Cross and Dave J Dyer 
    Last Updated: 08/17/2018   
#>

workflow Get-MissingTagsReport {
    param (
        [Parameter(Mandatory=$true)][string]$RequiredTags,
        [Parameter(Mandatory=$true)][string]$StorageAccountShare,
        [Parameter(Mandatory=$true)][string]$StorageAccountName,
        [Parameter(Mandatory=$true)][string]$StorageAccountResourceGroup
            
    )

    # Connect to Azure with Run As
    $Conn = Get-AutomationConnection -Name AzureRunAsConnection
    Connect-AzureRmAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

    $rundate = Get-Date -UFormat "%Y%m%d-%H%M"
    $csvPath = "C:\Temp" + "\$rundate-MissingTagsReport.csv"
    $defaultValue = "DEFAULT"
    
    InlineScript {
        ## Get all resources ##
        $Resources = Get-AzureRmResource
        ## Retrieve existing tags ##
        foreach ($Resource in $Resources)
        {
            try 
            {
                $InPlaceTags = (Get-AzureRmResource -Name $Resource.Name -ResourceGroupName $Resource.ResourceGroupName -ResourceType $Resource.ResourceType).Tags
            }
            catch
            {
                ## Output entry for all required tags, because error thrown retrieving ##
                foreach ($RequiredTag in $Using:RequiredTags)
                {

                    New-Object -TypeName PSObject -Property @{
                                ResourceGroupName = $Resource.ResourceGroupName
                                ResourceType = $Resource.ResourceType
                                Name = $Resource.Name
                                MissingTag = $RequiredTag
                                Value = ""
                                } | Select-Object ResourceGroupName, ResourceType, Name, MissingTag, Value | Export-Csv -Path $Using:csvPath -Append -Force -NoTypeInformation

                }
            }
            ## Check all resources for required tags
            foreach ($RequiredTag in $Using:RequiredTags) 
            {
                ## Check if no tags in place
                if ($InPlaceTags -eq $null)
                {
                    # No tags, so it must be missing
                    New-Object -TypeName PSObject -Property @{
                                ResourceGroupName = $Resource.ResourceGroupName
                                ResourceType = $Resource.ResourceType
                                Name = $Resource.Name
                                MissingTag = $RequiredTag
                                Value = ""
                                } | Select-Object ResourceGroupName, ResourceType, Name, MissingTag, Value | Export-Csv -Path $Using:csvPath -Append -Force -NoTypeInformation
                }
                else
                {
                    # Check hashtable for tag
                    if ($InPlaceTags.ContainsKey($RequiredTag) -eq $false)
                    {
                        New-Object -TypeName PSObject -Property @{
                                    ResourceGroupName = $Resource.ResourceGroupName
                                    ResourceType = $Resource.ResourceType
                                    Name = $Resource.Name
                                    MissingTag = $RequiredTag
                                    Value = ""
                                    } | Select-Object ResourceGroupName, ResourceType, Name, MissingTag, Value | Export-Csv -Path $Using:csvPath -Append -Force -NoTypeInformation
                    }
                    else
                    {
                        # Make sure the tag is not a DEFAULT value
                        if ($InPlaceTags[$RequiredTag] -eq $Using:defaultValue)
                        {
                            New-Object -TypeName PSObject -Property @{
                                        ResourceGroupName = $Resource.ResourceGroupName
                                        ResourceType = $Resource.ResourceType
                                        Name = $Resource.Name
                                        MissingTag = $RequiredTag
                                        Value = $Using:defaultValue
                                        } | Select-Object ResourceGroupName, ResourceType, Name, MissingTag, Value | Export-Csv -Path $Using:csvPath -Append -Force -NoTypeInformation
                            }
                    }
                } # ($tags -eq $null)
            } # ($requiredTag in $requiredTags)
        } # ($Resource in $Resources)

        ## Post missing tags report to Azure Storage account ##
        $StorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName $Using:StorageAccountResourceGroup -Name $Using:StorageAccountName
        $Context = New-AzureStorageContext -StorageAccountKey $StorageAccountKey[0].Value -StorageAccountName $Using:StorageAccountName
        Set-AzureStorageFileContent -ShareName $Using:StorageAccountShare -Context $Context -Source $Using:csvPath -Force

    } # end InlineScript
}
