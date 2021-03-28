function Get-ServiceNowUserGroup{
    [OutputType([System.Management.Automation.PSCustomObject])]
    [CmdletBinding(DefaultParameterSetName='Session', SupportsPaging)]
    Param(
        # Machine name of the field to order by
        [Parameter(Mandatory = $false)]
        [string]$OrderBy = 'name',

        # Direction of ordering (Desc/Asc)
        [Parameter(Mandatory = $false)]
        [ValidateSet('Desc', 'Asc')]
        [string]$OrderDirection = 'Desc',

        # Maximum number of records to return
        [Parameter(Mandatory = $false)]
        [int]$Limit,

        # Fields to return
        [Parameter(Mandatory = $false)]
        [Alias('Fields')]
        [string[]]$Properties,

        # Hashtable containing machine field names and values returned must match exactly (will be combined with AND)
        [Parameter(Mandatory = $false)]
        [hashtable]$MatchExact = @{},

        # Hashtable containing machine field names and values returned rows must contain (will be combined with AND)
        [Parameter(Mandatory = $false)]
        [hashtable]$MatchContains = @{},

        # Whether or not to show human readable display values instead of machine values
        [Parameter(Mandatory = $false)]
        [ValidateSet('true', 'false', 'all')]
        [string]$DisplayValues = 'true',

        [Parameter(ParameterSetName = 'SpecifyConnectionFields', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('ServiceNowCredential')]
        [PSCredential]$Credential,

        [Parameter(ParameterSetName = 'SpecifyConnectionFields', Mandatory = $true)]
        [ValidateScript({Test-ServiceNowURL -Url $_})]
        [Alias('Url')]
        [string]$ServiceNowURL,

        [Parameter(ParameterSetName = 'UseConnectionObject', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable]$Connection,

        [Parameter(ParameterSetName = 'Session')]
        [ValidateNotNullOrEmpty()]
        [hashtable] $ServiceNowSession = $script:ServiceNowSession
    )

    $result = Get-ServiceNowTable @PSBoundParameters -Table 'sys_user_group'

    If (-not $Properties) {
        $result | ForEach-Object { $_.PSObject.TypeNames.Insert(0, "ServiceNow.UserAndUserGroup") }
    }
    $result
}
