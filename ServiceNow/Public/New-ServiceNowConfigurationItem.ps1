function New-ServiceNowConfigurationItem {   
    <#
    .SYNOPSIS
        Create a new configuration item

    .DESCRIPTION
        Create a new configuration item.  You can create a specific class ci or root cmdb_ci.

    .PARAMETER Name
        Name of the ci

    .PARAMETER Class
        Specify the class of the CI, eg. cmdb_ci_server.  If not specified, cmdb_ci will be used.

    .PARAMETER Description
        Description for the CI

    .PARAMETER OperationalStatus
        Operational status value of the CI.  Note, this is the numerical value, not display value.  Eg. Use '1', not 'Operational'.

    .PARAMETER CustomField
        Key/value pairs for fields not available as a function parameter, eg. @{'ip_address'='1.2.3.4'}

    .PARAMETER PassThru
        Return the newly created CI

    .PARAMETER Connection
        Azure Automation Connection object containing username, password, and URL for the ServiceNow instance

    .PARAMETER ServiceNowSession    
        ServiceNow session created by New-ServiceNowSession.  Will default to script-level variable $ServiceNowSession.

    .EXAMPLE
        New-ServiceNowConfigurationItem -Name 'MyServer' -Class cmdb_ci_server
        Create a new CI

    .EXAMPLE
        New-ServiceNowConfigurationItem -Name 'MyServer' -Class cmdb_ci_server -PassThru
        Create a new CI and return the newly created object to the pipeline
    #>

    [CmdletBinding(DefaultParameterSetName = 'Session', SupportsShouldProcess)]

    param(
        [parameter(Mandatory)]
        [string] $Name,

        [parameter()]
        [string] $Class,

        [parameter()]
        [string] $Description,

        [parameter()]
        [string] $OperationalStatus,

        # custom fields as hashtable
        [parameter()]
        [Hashtable] $CustomField,

        [Parameter()]
        [switch] $PassThru,

        #Azure Automation Connection object containing username, password, and URL for the ServiceNow instance
        [Parameter(ParameterSetName = 'UseConnectionObject', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Hashtable] $Connection,

        [Parameter(ParameterSetName = 'Session')]
        [ValidateNotNullOrEmpty()]
        [Hashtable] $ServiceNowSession = $script:ServiceNowSession
    )

    begin {}

    process {
        # Create a hash table of any defined parameters (not CustomFields) that have values
        $DefinedParams = @{
            'Name'              = 'name'
            'Class'             = 'sys_class_name'
            'Description'       = 'description'
            'OperationalStatus' = 'operational_status'
        }
        $TableEntryValues = @{}
        foreach ($Key in $PSBoundParameters.Keys) {
            if ($DefinedParams.$Key) {
                $TableEntryValues.Add($DefinedParams.$Key, $PSBoundParameters.$Key)
            }
        }

        # Add CustomFields hash pairs to the Table Entry Values hash table
        $DuplicateKeys = foreach ($Key in $CustomField.Keys) {
            if ($TableEntryValues.ContainsKey($Key)) {
                # Capture the duplicate key name
                $Key
            } else {
                # Add the unique entry to the table entry values hash table
                $TableEntryValues.Add($Key, $CustomField[$Key])
            }
        }

        # Throw an error if duplicate fields were provided
        if ($DuplicateKeys) {
            throw ('You are attempting to redefine a value, ''{0}'', with $CustomFields that is already set' -f ($DuplicateKeys -join ','))
        }

        # Table Entry Splat
        $Params = @{
            Table    = 'cmdb_ci'
            Values   = $TableEntryValues
            PassThru = $true
        }

        if ($ServiceNowSession) {
            $Params.ServiceNowSession = $ServiceNowSession
        } else {
            $Params.Connection = $Connection
        }

        if ( $PSCmdlet.ShouldProcess($Name, 'Create new configuration item') ) {
            $Response = New-ServiceNowRecord @Params
            if ($PassThru.IsPresent) {
                $Response.PSObject.TypeNames.Insert(0, 'ServiceNow.ConfigurationItem')
                $Response
            }
        }
    }
}
