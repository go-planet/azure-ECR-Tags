 <#
    .SYNOPSIS
        Creates a report of all objects and tags in all subscriptions

    .DESCRIPTION
        Process Flow:
            Connect to Azure
            Select subscription
	    Create report templates per subscription
            Query Resource Groups
	    QUery each object within the resource group
	    Export the following attributes to the report: Object,ResourceGroup,All Tags
            Continue checking all subscriptions
	    Removes report templates                
    .NOTES
        Author: Travis Moore
        Date: September 2018
        URL: TBD

        Assumptions:
            -Administrator rights to view all subscriptions and VM statuses
#>
  
###Start Script

cls

##Connect to Azure
#Prompt for Azure credentials
$creds = (get-credential)
Connect-AzureRmAccount -Credential $creds


#Create array of subscriptions for looping through
$subscription = Get-AzureRmSubscription

foreach ($tenant in $subscription)
    
    #1
    {

$focus = $tenant.Name

    #Set context and select Azure subscription from array
    write-host "Selecting Tenant: "$focus -ForegroundColor Cyan
    $context = Get-AzureRmSubscription -SubscriptionName $focus | Set-AzureRmContext
    Select-AzureRmSubscription -Context $context

    #Create Report Files
    write-host "Creating array files..." -ForegroundColor Cyan
    new-item .\$focus'_tag.csv' -type file -force
    add-content .\$focus'_tag.csv' "ResourceName",",","ResourceGroupName" -NoNewline

    #Get List of Tags per subscription and create a CSV
    write-host "Getting list of Tags in"$focus -ForegroundColor Cyan
    get-azurermtag | select Name | export-csv .\$focus'_tagheader.csv' -NoTypeInformation

    $tagheader = import-csv .\$focus'_tagheader.csv' 

	foreach ($label in $tagheader){
		
        $tagname = $label.name
        write-host "Adding content to"$focus"_tag.csv: Tag Name = "$tagname
        Add-Content .\$focus'_tag.csv' ",","$tagname" -NoNewline
                                 
                                  }
        #Close File Header
		Add-Content .\$focus'_tag.csv' ","

        
        write-host "Gathering inventory and tags..." -ForegroundColor Cyan
        Write-Host ""
        $RGs = Get-AzureRMResourceGroup
            foreach($RG in $RGs)
               #3
               {
                write-host "Querying Resource Group: "$RG.ResourceGroupName -ForegroundColor Cyan
                $objects = Find-AzureRmResource -ResourceGroupName $RG.ResourceGroupName
                
                ##Gather server details
                foreach ($item in $objects)
                        #4
                        
                        {
                        $RGName = $RG.ResourceGroupName
                        $thing = $item.ResourceName
                        write-host "Querying Resource Name (thing): "$thing -ForegroundColor Cyan
                        write-host "Resource Group: "$RGName -ForegroundColor Cyan
                        #write-host "Tag List: " $tagheader.name
                        Add-Content .\$focus'_tag.csv' "$thing" -NoNewLine -Force
                        Add-Content .\$focus'_tag.csv' "," -NoNewLine -Force
                        Add-Content .\$focus'_tag.csv' "$RGName" -NoNewLine -Force
                        foreach ($t in $tagheader)
                                #5
                                {
                                $ztag = $t.name
                                write-host "Querying for Tag: "$ztag -ForegroundColor Magenta
                                $z = (Find-AzureRmResource -ResourceNameEquals $thing).Tags.$ztag
                                write-host "Value: "$z -ForegroundColor Green
                                if ($z -eq $null)
                                    {
                                    write-host "Empty Tag. Adding comma to CSV." -ForegroundColor Yellow
                                    add-content .\$focus'_tag.csv' "," -NoNewline -Force
                                    }
                                else 
                                    {
                                    write-host "Adding value to CSV: "$z -ForegroundColor Green
                                    add-content .\$focus'_tag.csv' ",","$z" -NoNewline -Force
                                    }
                                #5
                                }
                         add-content .\$focus'_tag.csv' "," -Force
                         #4
                         }
                         
                 #3
                 }
                 
        #1
        }
del .\*tagheader*

###End Script
