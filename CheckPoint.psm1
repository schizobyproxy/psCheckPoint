### START OF SHARED FUNCTIONS ###
<# 
 .Synopsis
  Runs Check Point Web API Call

 .Description
  Runs Check Point Web API Call.

 .Parameter Session
  Session object returned by Invoke-CPLogin command

 .Parameter Command
  Command you wish to run

 .Parameter Payload
  Hashtable of parameters to pass to the call.
#>
function APICall {
	param (
		[Parameter(Mandatory=$true)] [hashtable] $Session,
		[Parameter(Mandatory=$true)] [string] $Command,
		[hashtable] $Payload = @{}
	)
	
	if ($Session.'x-chkp-sid') {
		$Headers = @{'x-chkp-sid'=$Session.'x-chkp-sid'}
	} else {
		$Headers = @{}
	}
	
	$jsonPayload = $Payload | ConvertTo-Json
	
    Write-Debug @"
Calling "$($Session.URI)/$($Command)"
---Payload Start---
$($jsonPayload -replace '"password":\s*"(.*)"', '"password":  "***"')
---Payload End---
"@

	try {
        $Result = Invoke-RestMethod -Uri "$($Session.URI)/$($Command)" -Method Post -ContentType "application/json" -Headers $Headers -Body $jsonPayload -Verbose:$false
    } catch [System.Net.WebException] {
        $e = $_
        if ($e.Exception.Response) {
            $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
            $Result = $streamReader.ReadToEnd() | ConvertFrom-Json
            $streamReader.Close()
        } else {
            if ($e.Exception.Message.Contains("Could not establish trust relationship")) {
                $host.ui.WriteErrorLine.invoke(@"
$($e.Exception.Message)
You may need to run the following command first to allow self-signed certificates:
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { `$True }
"@)
            } else {
                Write-Error $e.Exception
            }
        }
    } catch {
        Write-Error "$($_.Exception)"
    }
    
    Write-Debug @"
---Result Start---
$($Result)
---Result End---
"@
    
    $Result
}

<# 
 .Synopsis
  Adds either uid or name to a Payload for when one or the other is required.

 .Parameter Payload
  Current Payload hashtable to add identifier to
  
 .Parameter UID
  Object unique identifier
  
 .Parameter Name
  Object name. Ignored if UID is provided.
#>
function AddIdentifier {
	param (
		[Parameter(Mandatory=$true)] [hashtable] $Payload,
		[string] $UID,
		[string] $Name
	)
	if ($uid) {
		$Payload.uid = $UID
	} else {
		$Payload.name = $Name
	}
}

<# 
 .Synopsis
  Adds switch boolean value to Payload.
  
 .Description
  If Value is True adds parameter to Payload.

 .Parameter Payload
  Current Payload hashtable to add identifier to
  
 .Parameter Name
  Name of parameter to be added
  
 .Parameter Value
  True or False value to set
  
 .Parameter Force
  Forces parameter to be added even if it is false. Use if the Web API default is True.
#>
function AddSwitchPayload {
	param (
		[Parameter(Mandatory=$true)] [hashtable] $Payload,
		[Parameter(Mandatory=$true)] [string]    $Name,
		[Parameter(Mandatory=$true)] [bool]      $Value,
		[switch] $Force
	)
	
	if ($Value) {
		$Payload.$Name = "true"
	} elseif ($Force) {
		$Payload.$Name = "false"
	}
}

<# 
 .Synopsis
  Adds array value to Payload.

 .Parameter Payload
  Current Payload hashtable to add identifier to
  
 .Parameter Name
  Name of parameter to be added
  
 .Parameter Values
  Array to add
  
 .Parameter Force
  Forces parameter to be added even if it is false. Use if the Web API default is True.
#>
function AddArrayPayload {
	param (
		[Parameter(Mandatory=$true)] [hashtable] $Payload,
		[Parameter(Mandatory=$true)] [string]    $Name,
		                             [string[]]  $Values,
		[switch] $Force
	)
	
	if ($Values.Count -gt 0) {
		if ($Values.Count -eq 1) {
			$Values = $Values.split(@(",", ";"), [System.StringSplitOptions]::RemoveEmptyEntries)
		}
        $Payload.$Name = $Values
	} elseif ($Force) {
		$Payload.$Name = @()
	}
}

<# 
 .Synopsis
  Adds string value to Payload only if not blank.

 .Parameter Payload
  Current Payload hashtable to add identifier to
  
 .Parameter Name
  Name of parameter to be added
  
 .Parameter Value
  String value to add
#>
function AddStringPayload {
	param (
		[Parameter(Mandatory=$true)] [hashtable] $Payload,
		[Parameter(Mandatory=$true)] [string]    $Name,
		                             [string]    $Value
	)
	
	if ($Value) {
        $Payload.$Name = $Value
	}
}

<# 
 .Synopsis
  Adds string value to Payload only if not blank.

 .Parameter Payload
  Current Payload hashtable to add identifier to
  
 .Parameter Name
  Name of parameter to be added
  
 .Parameter Value
  Int value to add
#>
function AddIntPayload {
	param (
		[Parameter(Mandatory=$true)] [hashtable] $Payload,
		[Parameter(Mandatory=$true)] [string]    $Name,
		                             [int]       $Value
	)
	
	if ($Value) {
        $Payload.$Name = $Value
	}
}

<# 
 .Synopsis
  Checks if Result for errors and displays all errors and warnings.

 .Parameter Result
  Result from other commands
  
 .Parameter SuppressOutput
  Do not output all errors and warnings.
  
 .Parameter OnSuccessOutput
  Change result when Result is successful
    TRUE: Will return $TRUE (Default)
    Result: Will just return the Result provided
    None: Return nothing at all
  
 .Parameter OnFailureOutput
  Change result when Result is not successful
    FALSE: Will return $FALSE (Default)
    Result: Will just return the Result provided. Can be used to get more details.
    None: Return nothing at all
#>
function isSuccessful {
    param (
		$Result,
		[switch] $SuppressOutput,
        [ValidateSet("TRUE","Result","None")] [string] $OnSuccessOutput = "TRUE",
        [ValidateSet("FALSE","Result","None")] [string] $OnFailureOutput = "FALSE"
	)
    if (-Not $Result) {
        switch ($OnFailureOutput) 
        {
            "FALSE" { $FALSE }
            "Result" { $Result }
            default { }
        }
    } elseif ($Result.code) {
        # Error found
        if (-Not $SuppressOutput) {
            $host.ui.WriteErrorLine.invoke("[$($Result.code)] $($Result.message)")
            if ($Result.warnings) {
                foreach ($w in $Result.warnings) {
                    Write-Warning $w.message
                }
            }
            if ($Result.errors) {
                foreach ($e in $Result.errors) {
                    $host.ui.WriteErrorLine.invoke("Error: $($e.message)")
                }
            }
            if ($Result.'blocking-errors') {
                foreach ($e in $Result.'blocking-errors') {
                    $host.ui.WriteErrorLine.invoke("Blocking Error: $($e.message)")
                }
            }
        }
        switch ($OnFailureOutput) 
        {
            "FALSE" { $FALSE }
            "Result" { $Result }
            default { }
        }
    } else {
        switch ($OnSuccessOutput) 
        {
            "TRUE" { $TRUE }
            "Result" { $Result }
            default { }
        }
    }
}
### END OF SHARED FUNCTIONS ###

### START OF SESSION MANAGEMENT FUNCTIONS ###
<# 
 .Synopsis
  Log in to the server with username and password.

 .Parameter ManagmentServer
  IP or Hostname of the Check point Management Server
  
 .Parameter ManagementPort
  Port Web API running on. Default: 443
  
 .Parameter Credentials
  PSCredential containing Username and Password. If not provided you will be prompted.
  
 .Parameter ReadOnly
  Login with Read Only permissions. This parameter is not considered in case continue-last-session is true.
  
 .Parameter ContinueLastSession
  The new session would continue where the last session was stopped.
  This option is available when the administrator has only one session that can be continued. 
  If there is more than one session, see 'switch-session' API.
  
 .Parameter Domain
  Use domain to login to specific domain. Domain can be identified by name or UID.
  
 .Outputs Session
  Session object containing URI & Check Point Session ID
#>
function Invoke-CPLogin {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] [string] $ManagmentServer,
		[int] $ManagementPort = 443,
		[Parameter(Mandatory=$true)] [System.Management.Automation.PSCredential] $Credentials,
		[switch] $ReadOnly,
		[switch] $ContinueLastSession,
		[string] $Domain
	)
	
	$WebAPIURI = "https://" + $ManagmentServer + ":" + $ManagementPort + "/web_api"
	$Payload = @{user=$Credentials.GetNetworkCredential().Username;password=$Credentials.GetNetworkCredential().Password;domain=$Domain}
	
	AddSwitchPayload -Payload $Payload  -Name 'read-only' -Value $ReadOnly
	AddSwitchPayload -Payload $Payload -Name 'continue-last-session' -Value $ContinueLastSession
	
	$Result = APICall -Session @{URI=$WebAPIURI} -Command 'login' -Payload $Payload
    if (isSuccessful -Result $Result) {
        Write-Verbose "Login successfull"
	    @{URI=$WebAPIURI; 'x-chkp-sid'=$Result.sid}
    } else {
        Write-Verbose "Login failed."
    }
}

<# 
 .Synopsis
  Log out from the current session. After logging out the session object is not valid any more.

 .Parameter Session
  Session object from Invoke-CPLogin
#>
function Invoke-CPLogout {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session
	)
	$Result = APICall -Session $Session -Command 'logout'
    if (isSuccessful -Result $Result) {
        Write-Verbose "Logout successfull"
    } else {
        Write-Verbose "Logout failed."
    }
}

<# 
 .Synopsis
  Logout from existing session. The session will be continued next time your open SmartConsole.

 .Description
  In case 'uid' is not provided, use current session. In order for the session to pass successfully to SmartConsole, make sure you don't have any other active GUI sessions.
 
 .Parameter Session
  Session object from Invoke-CPLogin
#>
function Invoke-CPContinueSessionInSmartconsole {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session
	)
	$Result = APICall -Session $Session -Command 'continue-session-in-smartconsole'
    if (isSuccessful -Result $Result) {
        Write-Verbose "Successfull"
    } else {
        Write-Verbose "Failed."
    }
}

<# 
 .Synopsis
  All the changes done by this user will be seen by all users only after publish is called.

 .Parameter Session
  Session object from Invoke-CPLogin
#>
function Invoke-CPPublish {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session
	)
	$Result = APICall -Session $Session -Command 'publish'
    if (isSuccessful -Result $Result) {
        Write-Verbose "Publish Successfull"
    } else {
        Write-Verbose "Publish Failed."
    }
}

<# 
 .Synopsis
  All changes done by user are discarded and removed from database.

 .Parameter Session
  Session object from Invoke-CPLogin
#>
function Invoke-CPDiscard {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session
	)
	$Result = APICall -Session $Session -Command 'discard'
    if (isSuccessful -Result $Result) {
        Write-Verbose "Discard Successfull"
    } else {
        Write-Verbose "Discard Failed."
    }
}
### END OF SESSION MANAGEMENT FUNCTIONS ###

### START OF NETWORK OBJECT FUNCTIONS ###
## Hosts ##
<# 
 .Synopsis
  Create new object.
  
 .Parameter Session
  Session object from Invoke-CPLogin

 .Parameter Name
  Object name. Should be unique in domain.
 
 .Parameter IpAddress
  IPv4 or IPv6 address. If both addresses are required use ipv4-address and ipv6-address fields explicitly.

 .Parameter Ipv4Address
  IPv4 address.

 .Parameter Ipv6Address
  IPv6 address.

 .Parameter Color
  Color of the object. Should be one of existing colors.
  
 .Parameter Comments
  Comments string.
  
 .Parameter Tags
  Collection of tag identifiers.
  
 .Parameter Groups
  Collection of group identifiers. Groups must already exist.
 
 .Parameter IgnoreWarnings
  Apply changes ignoring warnings.

 .Parameter SetIfExists
  If another object with the same identifier already exists, it will be updated.
  The command behaviour will be the same as if originally a set command was called.
  Pay attention that original object's fields will be overwritten by the fields provided in the request payload!
  
 .Example
 Import-Csv .\AddHosts.csv | Add-CPHost -Session $Session
#>
function Add-CPHost {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session,
		[parameter(ValueFromPipelineByPropertyName, Mandatory=$true)] [string] $Name,
		[parameter(ValueFromPipelineByPropertyName)] [alias("ip-address")] [string] $IpAddress,
        [parameter(ValueFromPipelineByPropertyName)] [alias("ipv4-address")] [string] $Ipv4Address,
        [parameter(ValueFromPipelineByPropertyName)] [alias("ipv6-address")] [string] $Ipv6Address,
		[parameter(ValueFromPipelineByPropertyName)] [string] $Comments,
		[parameter(ValueFromPipelineByPropertyName)] [string[]] $Tags,
		[parameter(ValueFromPipelineByPropertyName)] [string[]] $Groups,
		[parameter(ValueFromPipelineByPropertyName)] 
			[alias("colour")]
			[ValidateSet(
				"aquamarine 1", "black", "blue", "blue 1", "burly wood 4", "cyan",
				"dark green", "dark khaki", "dark orchid", "dark orange 3",
				"dark sea green 3", "deep pink", "deep sky blue 1", "dodger blue 3",
				"firebrick", "foreground", "forest green", "gold", "gold 3",
				"gray 83", "gray 90", "green", "lemon chiffon", "light coral",
				"light sea green", "light sky blue 4", "magenta", "medium orchid",
				"medium slate blue", "medium violet red", "navy blue", "olive drab",
				"orange", "red", "sienna", "yellow", "")]
			[string] $Color = "black",
		[switch] $IgnoreWarnings,
        [switch] $SetIfExists
	)
	Begin {}
	Process {
		if ($Color -eq "") {
			$Color = "black"
		}
		
		$Payload = @{name=$Name;color=$Color;comments=$Comments}
        AddStringPayload -Payload $Payload -Name 'ip-address'      -Value $IpAddress
        AddStringPayload -Payload $Payload -Name 'ipv4-address'    -Value $Ipv4Address
        AddStringPayload -Payload $Payload -Name 'ipv6-address'    -Value $Ipv6Address
        AddArrayPayload  -Payload $Payload -Name tags              -Values $Tags
        AddArrayPayload  -Payload $Payload -Name groups            -Values $Groups
		AddSwitchPayload -Payload $Payload -Name 'ignore-warnings' -Value  $IgnoreWarnings
        AddSwitchPayload -Payload $Payload -Name 'set-if-exists'   -Value  $SetIfExists
		
		$Result = APICall -Session $Session -Command 'add-host' -Payload $Payload
        if (isSuccessful -Result $Result) {
            Write-Verbose "Added host $($Name)"
            $Result
        } else {
            Write-Verbose "Failed to add host $($Name)"
        }
	}
	End {}
}

<# 
 .Synopsis
  Create new object.
  
 .Parameter Session
  Session object from Invoke-CPLogin

 .Parameter UID
  Object unique identifier
  
 .Parameter Name
  Object name. Ignored if UID is provided.

 .Parameter IgnoreWarnings
  Apply changes ignoring warnings.
#>
function Remove-CPHost {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session,
		[parameter(ValueFromPipelineByPropertyName)] [string] $Name,
		[parameter(ValueFromPipelineByPropertyName)] [string] $UID,
		[switch] $IgnoreWarnings
	)
	Begin {}
	Process {
		$Payload = @{}
		AddIdentifier    -Payload $Payload -Name $Name             -UID $UID
		AddSwitchPayload -Payload $Payload -Name 'ignore-warnings' -Value $IgnoreWarnings
		
		$Result = APICall -Session $Session -Command 'delete-host' -Payload $Payload
        if (isSuccessful -Result $Result) {
            Write-Verbose "Deleted host $($Name)$($UID)"
        } else {
            Write-Verbose "Failed to delete host $($Name)$($UID)"
            $Result
        }
	}
	End {}
}

## Networks ##
<# 
 .Synopsis
  Create new object.
  
 .Parameter Session
  Session object from Invoke-CPLogin

 .Parameter name
  Object name. Should be unique in domain.

 .Parameter color
  Color of the object. Should be one of existing colors.
  
 .Parameter Comments
  Comments string.
  
 .Parameter Tags
  Collection of tag identifiers.
  
 .Parameter Groups
  Collection of group identifiers. Groups must already exist.
  
 .Parameter Subnet
  IPv4 or IPv6 network address. 
  If both addresses are required use subnet4 and subnet6 fields explicitly.

 .Parameter MaskLength
  IPv4 or IPv6 network mask length. 
  If both masks are required use mask-length4 and mask-length6 fields explicitly. 
  Instead of IPv4 mask length it is possible to specify IPv4 mask itself in subnet-mask field.

 .Parameter SubnetMask
  IPv4 network mask.

 .Parameter Subnet4
  IPv4 network address.

 .Parameter MaskLength4
  IPv4 network mask length.

 .Parameter Subnet6
  IPv6 network address.

 .Parameter MaskLength6
  IPv6 network mask length.
 
 .Parameter IgnoreWarnings
  Apply changes ignoring warnings.
#>
function Add-CPNetwork {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session,
		[parameter(ValueFromPipelineByPropertyName, Mandatory=$true)] [string] $Name,
        [parameter(ValueFromPipelineByPropertyName)] [string] $Subnet,
        [parameter(ValueFromPipelineByPropertyName)] [int] $MaskLength,
        [parameter(ValueFromPipelineByPropertyName)] [string] $SubnetMask,
        [parameter(ValueFromPipelineByPropertyName)] [string] $Subnet4,
        [parameter(ValueFromPipelineByPropertyName)] [int] $MaskLength4,
        [parameter(ValueFromPipelineByPropertyName)] [string] $Subnet6,
        [parameter(ValueFromPipelineByPropertyName)] [int] $MaskLength6,
		[parameter(ValueFromPipelineByPropertyName)] [string] $Comments,
		[parameter(ValueFromPipelineByPropertyName)] [string[]] $Tags,
		[parameter(ValueFromPipelineByPropertyName)] [string[]] $Groups,
		[parameter(ValueFromPipelineByPropertyName)] 
			[alias("colour")]
			[ValidateSet(
				"aquamarine 1", "black", "blue", "blue 1", "burly wood 4", "cyan",
				"dark green", "dark khaki", "dark orchid", "dark orange 3",
				"dark sea green 3", "deep pink", "deep sky blue 1", "dodger blue 3",
				"firebrick", "foreground", "forest green", "gold", "gold 3",
				"gray 83", "gray 90", "green", "lemon chiffon", "light coral",
				"light sea green", "light sky blue 4", "magenta", "medium orchid",
				"medium slate blue", "medium violet red", "navy blue", "olive drab",
				"orange", "red", "sienna", "yellow", "")]
			[string] $Color = "black",
		[switch] $IgnoreWarnings,
        [switch] $SetIfExists
	)
	Begin {}
	Process {
		if ($Color -eq "") {
			$Color = "black"
		}
		
		$Payload = @{name=$Name;color=$Color;comments=$Comments}
        AddStringPayload -Payload $Payload -Name subnet            -Value $Subnet
        AddIntPayload    -Payload $Payload -Name 'mask-length'     -Value $MaskLength
        AddStringPayload -Payload $Payload -Name 'subnet-mask'     -Value $SubnetMask
        AddStringPayload -Payload $Payload -Name subnet4           -Value $Subnet4
        AddIntPayload    -Payload $Payload -Name 'mask-length4'    -Value $MaskLength4
        AddStringPayload -Payload $Payload -Name subnet6           -Value $Subnet6
        AddIntPayload    -Payload $Payload -Name 'mask-length6'    -Value $MaskLength6
        AddArrayPayload  -Payload $Payload -Name tags              -Values $Tags
        AddArrayPayload  -Payload $Payload -Name groups            -Values $Groups
		AddSwitchPayload -Payload $Payload -Name 'ignore-warnings' -Value  $IgnoreWarnings
        AddSwitchPayload -Payload $Payload -Name 'set-if-exists'   -Value  $SetIfExists
		
		$Result = APICall -Session $Session -Command 'add-network' -Payload $Payload
        if (isSuccessful -Result $Result) {
            Write-Verbose "Added network $($Name)"
            $Result
        } else {
            Write-Verbose "Failed to add network $($Name)"
        }
	}
	End {}
}

<# 
 .Synopsis
  Create new object.
  
 .Parameter Session
  Session object from Invoke-CPLogin

 .Parameter UID
  Object unique identifier
  
 .Parameter Name
  Object name. Ignored if UID is provided.

 .Parameter IgnoreWarnings
  Apply changes ignoring warnings.
#>
function Remove-CPNetwork {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session,
		[parameter(ValueFromPipelineByPropertyName)] [string] $Name,
		[parameter(ValueFromPipelineByPropertyName)] [string] $UID,
		[switch] $IgnoreWarnings
	)
	Begin {}
	Process {
		$Payload = @{}
		AddIdentifier    -Payload $Payload -Name $Name             -UID $UID
		AddSwitchPayload -Payload $Payload -Name 'ignore-warnings' -Value $IgnoreWarnings
		
		$Result = APICall -Session $Session -Command 'delete-network' -Payload $Payload
        if (isSuccessful -Result $Result) {
            Write-Verbose "Deleted network $($Name)$($UID)"
        } else {
            Write-Verbose "Failed to delete network $($Name)$($UID)"
            $Result
        }
	}
	End {}
}

## Groups ##
<# 
 .Synopsis
  Create new object.
  
 .Parameter Session
  Session object from Invoke-CPLogin

 .Parameter name
  Object name. Should be unique in domain.

 .Parameter color
  Color of the object. Should be one of existing colors.
  
 .Parameter Comments
  Comments string.
  
 .Parameter Tags
  Collection of tag identifiers.
  
 .Parameter Members
  Collection of Network objects identified by the name or UID. Must already exist.
 
 .Parameter IgnoreWarnings
  Apply changes ignoring warnings.
#>
function Add-CPGroup {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session,
		[parameter(ValueFromPipelineByPropertyName, Mandatory=$true)] [string] $Name,
		[parameter(ValueFromPipelineByPropertyName)] [string] $Comments,
		[parameter(ValueFromPipelineByPropertyName)] [string[]] $Tags,
		[parameter(ValueFromPipelineByPropertyName)] [string[]] $Members,
		[parameter(ValueFromPipelineByPropertyName)] 
			[alias("colour")]
			[ValidateSet(
				"aquamarine 1", "black", "blue", "blue 1", "burly wood 4", "cyan",
				"dark green", "dark khaki", "dark orchid", "dark orange 3",
				"dark sea green 3", "deep pink", "deep sky blue 1", "dodger blue 3",
				"firebrick", "foreground", "forest green", "gold", "gold 3",
				"gray 83", "gray 90", "green", "lemon chiffon", "light coral",
				"light sea green", "light sky blue 4", "magenta", "medium orchid",
				"medium slate blue", "medium violet red", "navy blue", "olive drab",
				"orange", "red", "sienna", "yellow", "")]
			[string] $Color = "black",
		[switch] $IgnoreWarnings
	)
	Begin {}
	Process {
		if ($Color -eq "") {
			$Color = "black"
		}
		
		$Payload = @{name=$Name;color=$Color;comments=$Comments}
        AddArrayPayload  -Payload $Payload -Name tags              -Values $Tags
        AddArrayPayload  -Payload $Payload -Name members           -Values $Members
		AddSwitchPayload -Payload $Payload -Name 'ignore-warnings' -Value  $IgnoreWarnings
		
		$Result = APICall -Session $Session -Command 'add-group' -Payload $Payload
        if (isSuccessful -Result $Result) {
            Write-Verbose "Added group $($Name)"
            $Result
        } else {
            Write-Verbose "Failed to add group $($Name)"
        }
	}
	End {}
}

<# 
 .Synopsis
  Create new object.
  
 .Parameter Session
  Session object from Invoke-CPLogin

 .Parameter UID
  Object unique identifier
  
 .Parameter Name
  Object name. Ignored if UID is provided.

 .Parameter IgnoreWarnings
  Apply changes ignoring warnings.
#>
function Remove-CPGroup {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)] $Session,
		[parameter(ValueFromPipelineByPropertyName)] [string] $Name,
		[parameter(ValueFromPipelineByPropertyName)] [string] $UID,
		[switch] $IgnoreWarnings
	)
	Begin {}
	Process {
		$Payload = @{}
		AddIdentifier    -Payload $Payload -Name $Name             -UID $UID
		AddSwitchPayload -Payload $Payload -Name 'ignore-warnings' -Value $IgnoreWarnings
		
		$Result = APICall -Session $Session -Command 'delete-group' -Payload $Payload
        if (isSuccessful -Result $Result) {
            Write-Verbose "Deleted group $($Name)$($UID)"
            $Result
        } else {
            Write-Verbose "Failed to delete group $($Name)$($UID)"
            $Result
        }
	}
	End {}
}
### END OF NETWORK OBJECT FUNCTIONS ###

export-modulemember -function "Invoke-*"
export-modulemember -function "Add-*"
export-modulemember -function "Remove-*"
