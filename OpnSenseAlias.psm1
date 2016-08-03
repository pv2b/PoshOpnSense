Import-Module "$PSScriptRoot\Util.psm1"

function New-OpnSenseAlias {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
        [xml]$ConfigXML,

        # A string representing the OPNsense alias name.
        [Parameter(Mandatory=$True)]
        [ValidatePattern("^[A-Za-z0-9_]+$")]
        [string]$Name,

        # The type of alias to create. Right now, only host and network are
        # implemented.
        [Parameter(Mandatory=$True)]
        [string]$Type,

        # A string containing a "friendly description" of the interface in question.
        # Defaults to 
        [Parameter(Mandatory=$False)]
        [string]$Description
    )

    $XMLElement = $ConfigXML.CreateElement('alias')
    foreach ($elementname in @("name", "address", "descr", "type", "detail")) {
        $child = $ConfigXML.CreateElement($elementname)
        $XMLElement.AppendChild($child) | Out-Null
    }
    $ConfigXML.SelectSingleNode('/opnsense/aliases').AppendChild($XMLElement) | Out-Null

    $XMLElement.name = $Name
    $XMLElement.type = switch ($Type) {
        "Host" { "host" }
        "Network" { "network" }
        "Port" { "port" }
        default { Throw "Unrecognised type $Type" }
    }
    $alias = Get-OpnSenseAlias -XMLElement $XMLElement
    if ($Description) {
        $alias | Set-OpnSenseAlias -Description $Description | Out-Null
    }
    $alias
}

function Set-OpnSenseAlias {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(ParameterSetName="ByName", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [xml]$ConfigXML,

        # A string representing the OPNsense alias name.
        [Parameter(ParameterSetName="ByName", Mandatory=$True)]
        [ValidatePattern("^[A-Za-z0-9_]+$")]
        [string]$Name,

        [Parameter(ParameterSetName="ByOpnSenseAlias", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [PSCustomObject[]]$OpnSenseAlias,

        [Parameter(Mandatory=$False)]
        [string]$NewName,

        [Parameter(Mandatory=$False)]
        [string]$Description
    )
    Begin {
        if ($PsCmdlet.ParameterSetName -eq "ByName") {
            $OpnSenseAlias = Get-OpnSenseAlias $ConfigXML $Name
        }
        # Don't use $PSBoundParameters here, we don't want to run NormalizeMacAddress on an empty MAC.
        if ($SpoofMac) {
            $SpoofMac = NormalizeMacAddress($SpoofMac)
        }
    }
    Process {
        $OpnSenseAlias | % {
            $x = $_.XMLElement
            if ($PSBoundParameters.ContainsKey('NewName')) {
                $x.name = $NewName
            }
            if ($PSBoundParameters.ContainsKey('Description')) {
                $x.descr = $Description
            }
        }
    }
}

function Get-OpnSenseAlias {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(ParameterSetName="ByName", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [xml]$ConfigXML,

        # A string representing the OPNsense alias name.
        [Parameter(ParameterSetName="ByName", Mandatory=$False, Position=2)]
        [ValidatePattern("^[A-Za-z0-9_]+$")]
        [string]$Name,

        [Parameter(ParameterSetName="ByElement", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [System.Xml.XmlElement[]]$XMLElement
    )
    $defaultProperties = @('Name', 'Description', ’Type')
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultProperties)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    if ($PsCmdlet.ParameterSetName -eq "ByName") {
        $xpath = "/opnsense/aliases/alias"
        if ($Name) {
            # Safe because $Name is guaranteed only to contain safe characters.
            $xpath += "[name='$Name']"
        }
        $XMLElement = $ConfigXML.SelectNodes($xpath)
    }
    $XMLElement | % {
        $if = New-Object PSCustomObject
        $if | Add-Member NoteProperty   XMLElement        $_
        $if | Add-Member ScriptProperty Name              { $this.XMLElement.name }
        $if | Add-Member ScriptProperty Description       { $this.XMLElement.descr }
        $if | Add-Member ScriptProperty Type {
            $t = $this.XMLElement.type
            switch ($t) {
                "host" { "Host" }
                "network" { "Network" }
                "port" { "Port" }
                default { $t }
            }
        }
        $if | Add-Member MemberSet      PSStandardMembers $PSStandardMembers
        $if
    }
}

function Get-OpnSenseAliasEntry {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(ParameterSetName="ByName", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [xml]$ConfigXML,

        # A string representing the OPNsense alias name.
        [Parameter(ParameterSetName="ByName", Mandatory=$True)]
        [ValidatePattern("^[A-Za-z0-9_]+$")]
        [string]$Name,

        [Parameter(ParameterSetName="ByOpnSenseAlias", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [PSCustomObject]$OpnSenseAlias
    )
    $defaultProperties = @('Address', 'Description')
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultProperties)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    if ($PsCmdlet.ParameterSetName -eq "ByName") {
        $OpnSenseAlias = Get-OpnSenseAlias $ConfigXML -Name $Name
    }
    if (-not $OpnSenseAlias) {
        Throw "Could not get OpnSenseAlias"
    }

    # Whoever designed this XML format was on drugs. The address element
    # contains a space-separated list of address elements. The detail
    # element contains a ||-seperated list of description elements.
    # The nth address element corresponds to the nth description element.

    $addresses = $OpnSenseAlias.XMLElement.address -split ' '
    $descriptions = $OpnSenseAlias.XMLElement.detail -split '\|\|'

    Join-Array @{Name="Address"; Array=$addresses}, @{Name="Description"; Array=$descriptions} | % {
        # Just building on the object returned by Join-Array
        $_ | Add-Member NoteProperty XMLElement        $_
        $_ | Add-Member MemberSet    PSStandardMembers $PSStandardMembers
        $_
    }
}

