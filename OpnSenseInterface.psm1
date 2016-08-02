Import-Module '.\Util.psm1'

<#

.SYNOPSIS

Creates a new interface in an OPNsense configuration file.

.DESCRIPTION

The New-OpnSenseInterface function manipulates the DOM of an OPNsense XML
configuration document in order to add a new interface.

In order to use this function, an object of the xml (System.Xml.XmlDocument)
type representing an OPNsense configuration is required. The cmdlet will
mutate the DOM supplied in order to create a new interface configuration with the
specified settings.

.EXAMPLE
$c = Get-OpnSenseXMLConfig config.xml; $c | New-OpnSenseInterface -Name opt1 -Interface em1; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file to create the OPNSense interface opt1 connected to
the FreeBSD interface em1.
#>
function New-OpnSenseInterface {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
        [xml]$ConfigXML,

        # A string representing the OPNsense interface name. Must be wan, lan,
        # or opt\d+. If not given, the first available opt interface is used.
        [Parameter(Mandatory=$False)]
        [ValidatePattern("^(wan|lan|opt\d+)$")]
        [string]$Name,

        # A string representing the FreeBSD interface name
        # (as seen in /sbin/ifconfig)
        [Parameter(Mandatory=$True)]
        [string]$Interface,

        # A string containing a "friendly description" of the interface in question.
        # Defaults to 
        [Parameter(Mandatory=$False)]
        [string]$Description
    )
    if (-not $name) {
        # A name was not provided, so we need to find a free opt interface.
        $i = 1
        do {
            $Name = "opt$i"
            $i++
        } while (Get-OpnSenseInterface $ConfigXML -Name $Name)
    } else {
        $Name = $Name.ToLower()
        # Refuse to create a duplicate
        if (Get-OpnSenseInterface $ConfigXML -Name $Name) {
            Throw "Interface already exists!"
        }
    }
    if (-not $Description) {
        $Description = $Name.ToUpper()
    }
    $XMLElement = $ConfigXML.CreateElement($Name)
    foreach ($elementname in @("descr", "if", "enable", "spoofmac")) {
        $child = $ConfigXML.CreateElement($elementname)
        $XMLElement.AppendChild($child) | Out-Null
    }
    $ConfigXML.SelectSingleNode('/opnsense/interfaces').AppendChild($XMLElement) | Out-Null
    Get-OpnSenseInterface -XMLElement $XMLElement | Set-OpnSenseInterface -Interface $Interface -Description $Description
}

<#

.SYNOPSIS

Manipulates an existing interface in an OPNsense configuration file.

.DESCRIPTION

The Set-OpnSenseInterface function manipulates the DOM of an OPNsense XML
configuration document in order to set information on interfaces matching
specified criteria.

In order to use this function, an object of the xml (System.Xml.XmlDocument)
type representing an OPNsense configuration is required.

.EXAMPLE
$c = Get-OpnSenseXMLConfig config.xml; $c | Get-OpnSenseInterface -Interface em0 | Set-OpnSenseVLAN -Description "AwesomeNet"; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file to add a description to the interface belonging to
the em0 interface.
#>
function Set-OpnSenseInterface {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(ParameterSetName="ByName", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [xml]$ConfigXML,

        # A string representing the OPNsense interface name. Must be wan, lan,
        # or opt\d+.
        [Parameter(ParameterSetName="ByName", Mandatory=$False)]
        [ValidatePattern("^(wan|lan|opt\d+)$")]
        [string]$Name,

        [Parameter(ParameterSetName="ByOpnSenseInterface", Mandatory=$True, ValueFromPipeline=$true)]
        [PSCustomObject[]]$OpnSenseInterface,

        # A string representing the FreeBSD interface name
        # (as seen in /sbin/ifconfig)
        [Parameter(Mandatory=$False)]
        [string]$Interface,

        # A string containing a "friendly description" of the VLAN in question.
        [Parameter(Mandatory=$False)]
        [string]$Description,

        [Parameter(Mandatory=$False)]
        [string]$SpoofMac,

        [Parameter(Mandatory=$False)]
        [ValidateScript({ $_.AddressFamily -eq "InterNetwork" })]
        [ipaddress]$IPAddress,

        [ValidateScript({ $_.AddressFamily -eq "InterNetworkV6" })]
        [Parameter(Mandatory=$False)]
        [ipaddress]$IPv6Address,

        [ValidateRange(0,32)]
        [Parameter(Mandatory=$False)]
        [int]$IPPrefixLength,

        [ValidateRange(0,128)]
        [Parameter(Mandatory=$False)]
        [int]$IPv6PrefixLength,

        [Parameter(Mandatory=$False)]
        [bool]$BlockBogons,

        [Parameter(Mandatory=$False)]
        [bool]$BlockRFC1918
    )
    Begin {
        if ($PsCmdlet.ParameterSetName -eq "ByName") {
            $OpnSenseInterface = Get-OpnSenseInterface $ConfigXML $Name
        }
        # Don't use $PSBoundParameters here, we don't want to run NormalizeMacAddress on an empty MAC.
        if ($SpoofMac) {
            $SpoofMac = NormalizeMacAddress($SpoofMac)
        }
    }
    Process {
        $OpnSenseInterface | % {
            $x = $_.XMLElement
            if ($PSBoundParameters.ContainsKey('Interface')) {
                $x.if = $Interface
            }
            if ($PSBoundParameters.ContainsKey('Description')) {
                $x.descr = $Description
            }
            if ($PSBoundParameters.ContainsKey('SpoofMac')) {
                $x.spoofmac = $SpoofMac
            }
            if ($PSBoundParameters.ContainsKey('IPAddress')) {
                $x.ipaddr = $IPAddress.ToString()
            }
            if ($PSBoundParameters.ContainsKey('IPv6Address')) {
                $x.ipaddrv6 = $IPv6Address.ToString()
            }
            if ($PSBoundParameters.ContainsKey('IPPrefixLength')) {
                $x.subnet = $IPPrefixLength.ToString()
            }
            if ($PSBoundParameters.ContainsKey('IPv6PrefixLength')) {
                $x.subnetv6 = $IPv6PrefixLength.ToString()
            }
            if ($PSBoundParameters.ContainsKey('BlockBogons')) {
                $n = $x.SelectSingleNode('blockbogons')
                if ($BlockBogons) {
                    if (-not $n) {
                        $n = $ConfigXML.CreateElement('blockbogons')
                        $x.AppendChild($n) | Out-Null
                    }
                    $x.blockbogons = "1"
                } else {
                    if ($n) {
                        $x.RemoveChild($n) | Out-Null
                    }
                }
            }
            if ($PSBoundParameters.ContainsKey('BlockRFC1918')) {
                $n = $x.SelectSingleNode('blockpriv')
                if ($BlockBogons) {
                    if (-not $n) {
                        $n = $ConfigXML.CreateElement('blockpriv')
                        $x.AppendChild($n) | Out-Null
                    }
                    $x.blockpriv = "1"
                } else {
                    if ($n) {
                        $x.RemoveChild($n) | Out-Null
                    }
                }
            }
            $_
        }
    }
}

<#

.SYNOPSIS

Retrieves an interface in an OPNsense configuration file.

.DESCRIPTION

The Get-OpnSenseInterface function reads an OPNsense configuration file in
order to add a new interface.

In order to use this function, an object of the xml (System.Xml.XmlDocument)
type representing an OPNsense configuration is required. The cmdlet will
mutate the DOM supplied in order to create a new interface configuration with
the specified settings.

.OUTPUT

An object of type System.Xml.XmlElement is returned, representing the
requested information. The cmdlet makes no attempt at interpreting the
data, instead opting to present it as is from the configuration DOM.

.EXAMPLE
Get-OpnSenseXMLConfig config.xml | Get-OpnSenseInterface -Interface em0


Name        : opt10
Interface   : em0
Description : GUEST
IPAddress   : 192.0.2.1
IPv6Address : 2001:db8:1561:a::1
Enabled     : True

Retrieve information about the interface named em0.
#>
function Get-OpnSenseInterface {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [xml]$ConfigXML,

        # A string representing the OPNsense interface name. Must be wan, lan,
        # or opt\d+. If not given, the first available opt interface is used.
        [Parameter(ParameterSetName="ByValue", Mandatory=$False, Position=2)]
        [ValidatePattern("^(wan|lan|opt\d+)$")]
        [string]$Name,

        [Parameter(ParameterSetName="ByElement", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [System.Xml.XmlElement[]]$XMLElement
    )

    if ($Name) {
        $Name = $Name.ToLower()
        $xpath = "/opnsense/interfaces/$Name"
    } else {
        $xpath = "/opnsense/interfaces/*"
    }
    $defaultProperties = @('Name', 'Interface', 'Description', ’IPAddress', 'IPv6Address', 'Enabled')
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultProperties)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    if ($PsCmdlet.ParameterSetName -eq "ByValue") {
        $XMLElement = $ConfigXML.SelectNodes($xpath)
    }
    $XMLElement | % {
        $if = New-Object PSCustomObject
        $if | Add-Member NoteProperty   XMLElement       $_
        $if | Add-Member ScriptProperty Name             { $this.XMLElement.Name }
        $if | Add-Member ScriptProperty Interface        { $this.XMLElement.if }
        $if | Add-Member ScriptProperty Description      { $this.XMLElement.descr }
        $if | Add-Member ScriptProperty Enabled          { [bool]$this.XMLElement.enable }
        $if | Add-Member ScriptProperty IPAddress        { [ipaddress]$this.XMLElement.ipaddr }
        $if | Add-Member ScriptProperty IPv6Address      { [ipaddress]$this.XMLElement.ipaddrv6 }
        $if | Add-Member ScriptProperty IPPrefixLength   { [int]$this.XMLElement.subnet }
        $if | Add-Member ScriptProperty IPv6PrefixLength { [int]$this.XMLElement.subnetv6 }
        $if | Add-Member ScriptProperty BlockBogons      { [bool]$this.XMLElement.blockbogons }
        $if | Add-Member ScriptProperty BlockRFC1918     { [bool]$this.XMLElement.blockpriv }
        $if | Add-Member ScriptProperty SpoofMac         { $this.XMLElement.spoofmac }
        $if | Add-Member MemberSet      PSStandardMembers $PSStandardMembers
        $if
    }
}

<#

.SYNOPSIS

Removes an interface from an OPNsense configuration file.

.DESCRIPTION

The New-OpnSenseVLAN function manipulates the DOM of an OPNsense XML
configuration document in order to remove an interface.

The interface to be removed can either be specified by value, or providing a
System.Xml.XmlElement object referring to the interface, as provided by the
Get-OpnSenseInterface cmdlet.

.NOTES

Both the Name and Interface arguments are optional. If neither is specified,
and the ConfigXML parameter is used, this will therefore delete all
interfaces.

.EXAMPLE
$c = Get-OpnSenseXMLConfig config.xml; $c | Remove-OpnSenseInterface -Interface em0; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file and remove an interface definition with a physical
interface of em0, by specifying the requested interface to be deleted by
value.

.EXAMPLE
$c = Get-OpnSenseXMLConfig config.xml; $c | Get-OpnSenseInterface -Interface em0 | Remove-OpnSenseInterface; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file and remove an interface definition with a physical
interface of em0, after retrieving the interface objects using the
Get-OpnSenseInterface cmdlet.
#>
function Remove-OpnSenseInterface {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [xml]$ConfigXML,

        # A string representing the OPNsense interface name. Must be wan, lan,
        # or opt\d+. If not given, the first available opt interface is used.
        [Parameter(ParameterSetName="ByValue", Mandatory=$False)]
        [ValidatePattern("^(wan|lan|opt\d+)$")]
        [string]$Name,

        [Parameter(ParameterSetName="ByOpnSenseInterface", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [PSCustomObject[]]$OpnSenseInterface
    )
    Begin {
        if ($PsCmdlet.ParameterSetName -eq "ByValue") {
            $OpnSenseInterface = Get-OpnSenseInterface $ConfigXML $Name
        }
    }
    Process {
        if (-not $OpnSenseInterface) {
            Throw "Could not find interface to remove!"
        }
        $OpnSenseInterface | % {
            $_.XMLElement.ParentNode.RemoveChild($_.XMLElement) | Out-Null
        }
    }
}

<#

.SYNOPSIS

Disables an interface in an OPNsense configuration file.

.DESCRIPTION

The Disable-OpnSenseVLAN function manipulates the DOM of an OPNsense XML
configuration document in order to disable an interface.

The interface to be removed can either be specified by value, or providing a
System.Xml.XmlElement object referring to the interface, as provided by the
Get-OpnSenseInterface cmdlet.

.NOTES

Both the Name and Interface arguments are optional. If neither is specified,
and the ConfigXML parameter is used, this will therefore disable all
interfaces.
#>
function Disable-OpnSenseInterface {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [xml]$ConfigXML,

        # A string representing the OPNsense interface name. Must be wan, lan,
        # or opt\d+. If not given, the first available opt interface is used.
        [Parameter(ParameterSetName="ByValue", Mandatory=$False)]
        [ValidatePattern("^(wan|lan|opt\d+)$")]
        [string]$Name,

        [Parameter(ParameterSetName="ByOpnSenseInterface", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [PSCustomObject[]]$OpnSenseInterface
    )
    Begin {
        if ($PsCmdlet.ParameterSetName -eq "ByValue") {
            $OpnSenseInterface = Get-OpnSenseInterface $ConfigXML $Name
        }
    }
    Process {
        if (-not $OpnSenseInterface) {
            Throw "Could not find interface to disable!"
        }
        $OpnSenseInterface | % {
            $_.XMLElement.enable = ""
        }
    }
}

<#

.SYNOPSIS

Enables an interface in an OPNsense configuration file.

.DESCRIPTION

The Enable-OpnSenseVLAN function manipulates the DOM of an OPNsense XML
configuration document in order to enable an interface.

The interface to be removed can either be specified by value, or providing a
System.Xml.XmlElement object referring to the interface, as provided by the
Get-OpnSenseInterface cmdlet.

.NOTES

Both the Name and Interface arguments are optional. If neither is specified,
and the ConfigXML parameter is used, this will therefore enable all
interfaces.
#>
function Enable-OpnSenseInterface {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [xml]$ConfigXML,

        # A string representing the OPNsense interface name. Must be wan, lan,
        # or opt\d+. If not given, the first available opt interface is used.
        [Parameter(ParameterSetName="ByValue", Mandatory=$False)]
        [ValidatePattern("^(wan|lan|opt\d+)$")]
        [string]$Name,

        [Parameter(ParameterSetName="ByOpnSenseInterface", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [PSCustomObject[]]$OpnSenseInterface
    )
    Begin {
        if ($PsCmdlet.ParameterSetName -eq "ByValue") {
            $OpnSenseInterface = Get-OpnSenseInterface $ConfigXML $Name
        }
    }
    Process {
        if (-not $OpnSenseInterface) {
            Throw "Could not find interface to remove!"
        }
        $OpnSenseInterface | % {
            $_.XMLElement.enable = "1"
        }
    }
}
