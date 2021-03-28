function Set-ServiceNowAuth {
<#
    .SYNOPSIS
    Set your Service-Now authentication credentials

    .DESCRIPTION
    This cmdlet will set your Service-Now authentication credentials which will enable you to interact with Service-Now using the other cmdlets in the module

    .PARAMETER Url
    The URL of your Service-Now instance

    .PARAMETER Credentials
    Credentials to authenticate you to the Service-Now instance provided in the Url parameter

    .EXAMPLE
    Set-ServiceNowAuth -Url tenant.service-now.com

    .NOTES
    The URL should be the instance name portion of the FQDN for your instance. If you browse to https://yourinstance.service-now.com the URL required for the module is yourinstance.service-now.com
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({$_ | Test-ServiceNowURL})]
        [Alias('ServiceNowUrl')]
        [string] $Url,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential] $Credentials
    )
    Write-Warning -Message 'Set-ServiceNowAuth will be deprecated in a future release.  Please use New-ServiceNowSession.'
    New-ServiceNowSession -Url $Url -Credential $Credentials
    return $true
}
