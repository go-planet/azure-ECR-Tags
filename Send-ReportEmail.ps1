<#  
.SYNOPSIS   
     Send reports as email attachments using secure SMTP 
.DESCRIPTION  

This runbook will send email with attachments through secure SMTP (like Exchange Online). The attached files are 
pulled from an Azure storage account where reports are stored for tracking.

Prereq:     
    1. Automation PS Credential Asset with userid and password to smtp service. 
    
.PARAMETER From  
    String email address that will be used as sender
    Example: no-reply@domain.com 
  
.PARAMETER To 
    String email address of destination  
    Example: target@domain.com

.PARAMETER Server 
    String SMTP server address
    Example: smtp.office365.com

.PARAMETER Port 
    String SMTP server port number
    Example: 587
         
.PARAMETER Subject
    String Subject of mail message
    
.PARAMETER fileNames
     File attachments
     Example: ["Data.csv","ReadMe.txt"]

.PARAMETER credName 
    String - Name of PS Credential asset
    Example: SMTPCredential


.EXAMPLE  
  Send-ReportEmail -From "service@yourdomain.com" -To "recipient@yourdomain.com" -Server "smtp.live.com" -Subject "This is a test"

.NOTES  
    Author: Dave J Dyer 
    Website: davejdyer.com
    Last Updated: 08/17/2018   
#>

workflow Send-ReportEmail {
    param (
        [Parameter(Mandatory=$true)][string]$From,
        [Parameter(Mandatory=$true)][string]$To,
        [Parameter(Mandatory=$false)][string]$Server = 'smtp.office365.com',
        [Parameter(Mandatory=$false)][string]$Port = '587',
        [Parameter(Mandatory=$false)][string]$Subject = 'Email Report', 
        [Parameter(Mandatory=$false)][string]$Body = 'This is an automated email from Azure',
        [Parameter(Mandatory=$false)][string]$FileName,
        [Parameter(Mandatory=$true)][string]$CredName,
        [Parameter(Mandatory=$false)][string]$StorageAccountName = 'djdreportsrepository01',
        [Parameter(Mandatory=$false)][string]$StorageAccountShare = 'weeklytagreport'
            
    )

    ## Authenticate to Azure if running from Azure Automation ##
    $ServicePrincipalConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
    Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $ServicePrincipalConnection.TenantId `
        -ApplicationId $ServicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $ServicePrincipalConnection.CertificateThumbprint | Write-Verbose

    InlineScript {
        ## Retrieve report files to add as attachments ##
        $StorageAccountKey = Get-AzureRmStorageAccountKey -ResourceGroupName 'djdGenStorage-rg' -Name $Using:StorageAccountName
        $Context = New-AzureStorageContext -StorageAccountKey $StorageAccountKey[0].Value -StorageAccountName $Using:StorageAccountName
        Get-AzureStorageFileContent -ShareName 'weeklytagreport' -Context $Context -Path $Using:FileName -Destination 'C:\Temp'
        $Attachments = Join-Path -Path 'C:\Temp' -ChildPath $Using:FileName


        ## Send mail message ##
        $cred = Get-AutomationPSCredential -Name $Using:credName

        Send-MailMessage `
            -To $Using:To `
            -Subject $Using:Subject `
            -Body $Using:Body `
            -UseSsl `
            -Port $Using:Port `
            -SmtpServer $Using:Server `
            -From $Using:From `
            -BodyAsHtml `
            -Credential $cred `
            -Attachments $Attachments
            

        Write-Output "Sending mail to $Using:To"

    }

}