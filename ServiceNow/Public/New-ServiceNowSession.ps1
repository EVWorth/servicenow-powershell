function New-ServiceNowSession {
    <#
    .SYNOPSIS
        Create a new ServiceNow session

    .DESCRIPTION
        Create a new ServiceNow session via credentials, OAuth, or access token.
        This session will be used by default for all future calls.
        Optionally, you can specify the api version you'd like to use; the default is the latest.
        To use OAuth, ensure you've set it up, https://docs.servicenow.com/bundle/quebec-platform-administration/page/administer/security/task/t_SettingUpOAuth.html.

    .PARAMETER Url
        Base domain for your ServiceNow instance, eg. tenant.domain.com

    .PARAMETER Credential
        Username and password to connect.  This can be used standalone to use basic authentication or in conjunction with ClientCredential for OAuth.

    .PARAMETER ClientCredential
        Required for OAuth.  Credential where the username is the Client ID and the password is the Secret.

    .PARAMETER AccessToken
        Provide the access token directly if obtained outside of this module.

    .PARAMETER Proxy
        Use a proxy server for the request, rather than connecting directly.  Provide the full url.

    .PARAMETER ProxyCredential
        Credential of user who can access Proxy.  If not provided, the current user will be used.

    .PARAMETER ApiVersion
        Specific API version to use.  The default is the latest.

    .PARAMETER GetAllTable
        Populate $ServiceNowTable with data from all tables the user has access to

    .PARAMETER PassThru
        Provide the resulting session object to the pipeline as opposed to setting as a script scoped variable to be used by default for other calls.
        This is useful if you want to have multiple sessions with different api versions, credentials, etc.

    .EXAMPLE
        New-ServiceNowSession -Url tenant.domain.com -Credential $mycred
        Create a session using basic authentication and save it to a script-scoped variable

    .EXAMPLE
        New-ServiceNowSession -Url tenant.domain.com -Credential $mycred -ClientCredential $myClientCred
        Create a session using OAuth and save it to a script-scoped variable

    .EXAMPLE
        New-ServiceNowSession -Url tenant.domain.com -AccessToken 'asdfasd9f87adsfkksk3nsnd87g6s'
        Create a session with an existing access token and save it to a script-scoped variable

    .EXAMPLE
        $session = New-ServiceNowSession -Url tenant.domain.com -Credential $mycred -ClientCredential $myClientCred -PassThru
        Create a session using OAuth and save it as a local variable to be provided to functions directly

    .EXAMPLE
        New-ServiceNowSession -Url tenant.domain.com -Credential $mycred -Proxy http://1.2.3.4
        Create a session utilizing a proxy to connect

    .INPUTS
        None

    .OUTPUTS
        Hashtable if -PassThru provided

    .LINK
        https://docs.servicenow.com/bundle/quebec-platform-administration/page/administer/security/reference/r_OAuthAPIRequestParameters.html
    #>


    [CmdletBinding(DefaultParameterSetName = 'BasicAuth')]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'api call provides in plain text')]
    [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'No state is actually changing')]

    param(
        [Parameter(Mandatory)]
        [Alias('ServiceNowUrl')]
        [string] $Url,

        [Parameter(Mandatory, ParameterSetName = 'BasicAuth')]
        [Parameter(Mandatory, ParameterSetName = 'OAuth')]
        [Parameter(Mandatory, ParameterSetName = 'BasicAuthProxy')]
        [Parameter(Mandatory, ParameterSetName = 'OAuthProxy')]
        [Alias('Credentials')]
        [System.Management.Automation.PSCredential] $Credential,

        [Parameter(Mandatory, ParameterSetName = 'OAuth')]
        [Parameter(Mandatory, ParameterSetName = 'OAuthProxy')]
        [System.Management.Automation.PSCredential] $ClientCredential,

        [Parameter(Mandatory, ParameterSetName = 'AccessToken')]
        [Parameter(Mandatory, ParameterSetName = 'AccessTokenProxy')]
        [string] $AccessToken,

        [Parameter(Mandatory, ParameterSetName = 'BasicAuthProxy')]
        [Parameter(Mandatory, ParameterSetName = 'OAuthProxy')]
        [Parameter(Mandatory, ParameterSetName = 'AccessTokenProxy')]
        [string] $Proxy,

        [Parameter(ParameterSetName = 'BasicAuthProxy')]
        [Parameter(ParameterSetName = 'OAuthProxy')]
        [Parameter(ParameterSetName = 'AccessTokenProxy')]
        [System.Management.Automation.PSCredential] $ProxyCredential,

        [Parameter()]
        [int] $ApiVersion,

        [Parameter()]
        [switch] $GetAllTable,

        [Parameter()]
        [switch] $PassThru
    )

    Write-Verbose $PSCmdLet.ParameterSetName

    if ( $ApiVersion -le 0 ) {
        $Version = ''
    } else {
        $Version = ('/v{0}' -f $ApiVersion)
    }

    $NewSession = @{
        Domain  = $Url
        BaseUri = ('https://{0}/api/now{1}' -f $Url, $Version)
    }

    if ( $PSBoundParameters.ContainsKey('Proxy') ) {
        $NewSession.Add('Proxy', $Proxy)
        if ( $PSBoundParameters.ContainsKey('ProxyCredential') ) {
            $NewSession.Add('ProxyCredential', $ProxyCredential)
        }
    }

    switch -Wildcard ($PSCmdLet.ParameterSetName) {
        'OAuth*' {
            $Params = @{
                Uri             = 'https://{0}/oauth_token.do' -f $Url
                Body            = @{
                    'grant_type'    = 'password'
                    'client_id'     = $ClientCredential.UserName
                    'client_secret' = $ClientCredential.GetNetworkCredential().Password
                    'username'      = $Credential.UserName
                    'password'      = $Credential.GetNetworkCredential().Password
                }
                Method          = 'Post'
                UseBasicParsing = $true
            }

            # need to add this manually here, in addition to above, since we're making a rest call before our session is created
            if ( $PSBoundParameters.ContainsKey('Proxy') ) {
                $Params.Add('Proxy', $Proxy)
                if ( $PSBoundParameters.ContainsKey('ProxyCredential') ) {
                    $Params.Add('ProxyCredential', $ProxyCredential)
                } else {
                    $Params.Add('ProxyUseDefaultCredentials', $true)
                }
            }

            $OldProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'

            $Response = Invoke-WebRequest @Params

            # set the progress pref back now that done with invoke-webrequest
            $ProgressPreference = $OldProgressPreference

            if ( $Response.Content ) {
                $Token = $Response.Content | ConvertFrom-Json
                $NewSession.Add('AccessToken', (New-Object System.Management.Automation.PSCredential('AccessToken', ($Token.access_token | ConvertTo-SecureString -AsPlainText -Force))))
                $NewSession.Add('RefreshToken', (New-Object System.Management.Automation.PSCredential('RefreshToken', ($Token.refresh_token | ConvertTo-SecureString -AsPlainText -Force))))
            } else {
                # invoke-webrequest didn't throw an error, but we didn't get a token back either
                throw ('"{0} : {1}' -f $Response.StatusCode, $Response | Out-String )
            }
        }

        'AccessToken*' {
            $NewSession.Add('AccessToken', (New-Object System.Management.Automation.PSCredential('AccessToken', ($AccessToken | ConvertTo-SecureString -AsPlainText -Force))))
        }

        'BasicAuth*' {
            $NewSession.Add('Credential', $Credential)
        }

        default {

        }
    }

    # Write-Verbose 'Retrieving list of classes for this instance.  This will take a few seconds...'
    # $cmdbParams = @{
    #     Table             = 'sys_db_object'
    #     # Query             = 'nameSTARTSWITHcmdb_ci'
    #     Properties        = 'name', 'sys_id', 'label'
    #     First             = 100000
    #     ServiceNowSession = $NewSession
    # }

    # $class = Get-ServiceNowTable @cmdbParams -ErrorAction SilentlyContinue |
    # Select-Object @{
    #     'n' = 'Name'
    #     'e' = { $_.name }
    # },
    # @{
    #     'n' = 'SysId'
    #     'e' = { $_.sys_id }
    # },
    # @{
    #     'n' = 'ClassName'
    #     'e' = { $_.label }
    # }
    # if ( $class ) {
    #     $NewSession.Add('Classes', $class)
    # }

    Write-Verbose ($NewSession | ConvertTo-Json)

    if ( $PassThru ) {
        $NewSession
    } else {
        $Script:ServiceNowSession = $NewSession
    }

    if ( $GetAllTable.IsPresent ) {
        Write-Verbose 'Getting table number prefixes'
        $DefaultTable = $ServiceNowTable
        try {
            $Numbers = Get-ServiceNowRecord -Table 'sys_number' -Property prefix, category -First 10000 -IncludeTotalCount
            foreach ($Number in $Numbers) {
                if ( $Number.prefix.ToLower() -notin $DefaultTable.NumberPrefix ) {
                    $ServiceNowTable.Add(
                        [PSCustomObject] @{
                            'Name'             = ($Number.category.link | Select-String -Pattern '^.*\?name=(.*)$').matches.groups[1].Value
                            'ClassName'        = $Number.category.display_value
                            'Type'             = $null
                            'NumberPrefix'     = $Number.prefix.ToLower()
                            'DescriptionField' = 'short_description'
                        }
                    ) | Out-Null
                }
            }
        } catch {
            Write-Verbose "Session created, but failed to populate ServiceNowTable.  Prefixes beyond the default won't be available.  $_"
        }
    }
}
