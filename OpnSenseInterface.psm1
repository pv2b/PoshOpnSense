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
        [ValidatePattern("^(wan|lan|opt\d+)$)]")]
        [string]$Name,

        # A string representing the FreeBSD interface name
        # (as seen in /sbin/ifconfig)
        [Parameter(Mandatory=$True)]
        [string]$Interface,

        # A string containing a "friendly description" of the interface in question.
        # Defaults to 
        [Parameter(Mandatory=$False)]
        [string]$Description = $Interface.ToUpper()
    )
    if (-not $name) {
        # A name was not provided, so we need to find a free opt interface.
        $i = 1
        do {
            $Name = "opt$i"
            $i++
        } while (-not (Get-OpnSenseInterface -Name $Name))
    }
    $if = $ConfigXML.CreateElement($Name)
    foreach ($elementname in @("descr", "if", "enable", "spoofmac")) {
        $child = $ConfigXML.CreateElement($elementname)
        $if.AppendChild($child) | Out-Null
    }
    $ConfigXML.SelectSingleNode('/opnsense/interfaces').AppendChild($interface) | Set-OpnSenseInterface -Interface $Interface -Description $Description
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
        # An System.Xml.XmlElement object from an OPNsense configuration file
        # representing a interface. Such an object is returned by the
        # Get-OpnSenseInterface cmdlet. The element specified will be changed in
        # place as a result of executing the cmdlet, and as a result the DOM
        # containing this element will change.
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
        [System.Xml.XmlElement]$XMLElement,

        # A string representing the FreeBSD interface name
        # (as seen in /sbin/ifconfig)
        [Parameter(Mandatory=$False)]
        [string]$Interface,

        # A string containing a "friendly description" of the VLAN in question.
        [Parameter(Mandatory=$False)]
        [string]$Description
    )
    if ($Interface) {
        $XMLElement.if = $Interface
    }
    if ($Description) {
        $XMLElement.descr = $Description
    }
    $XMLElement
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


if          : em0
descr       : AwesomeNet
enable      : 1
spoofmac    :
blockbogons : 1
ipaddr      : 192.0.2.1
subnet      : 24
ipaddrv6    : 2001:db8:e1e:e7::1
subnetv6    : 64

Retrieve information about the interface named em0.
#>
function Get-OpnSenseInterface {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file.
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
        [xml]$ConfigXML,

        # A string representing the OPNsense interface name. Must be wan, lan,
        # or opt\d+. If not given, the first available opt interface is used.
        [Parameter(Mandatory=$False)]
        [ValidatePattern("^(wan|lan|opt\d+)$)]")]
        [string]$Name
    )

    if ($Name) {
        $xpath = "/opnsense/interfaces/$Name"
    } else {
        $xpath = "/opnsense/interfaces/*"
    }
    $ConfigXML.SelectNodes($xpath) | % {
        try {
            $_ | Add-Member -ErrorAction Stop ScriptProperty Interface { $this.if }
            $_ | Add-Member -ErrorAction Stop ScriptProperty VLANTag { $this.tag }
            $_ | Add-Member -ErrorAction Stop ScriptProperty Description { $this.descr }
            $_ | Add-Member -ErrorAction Stop ScriptProperty Enabled { [bool]$this.enable }
            $_ | Add-Member -ErrorAction Stop ScriptProperty IPAddress { [ipaddress]$this.ipaddr }
            $_ | Add-Member -ErrorAction Stop ScriptProperty IPv6Address { [ipaddress]$this.ipaddrv6 }
            $_ | Add-Member -ErrorAction Stop ScriptProperty IPPrefixLength { [int]$this.subnet }
            $_ | Add-Member -ErrorAction Stop ScriptProperty IPv6PrefixLength { [int]$this.subnetv6 }
            $_ | Add-Member -Force -ErrorAction Stop ScriptProperty BlockBogons { [bool]$this['blockbogons'] }
            $_ | Add-Member -ErrorAction Stop ScriptProperty BlockRFC1918 { [bool]$this.blockpriv }
            $_ | Add-Member -Force -ErrorAction Stop ScriptProperty SpoofMac { [bool]$this['spoofmac'] }

            $_ | Add-Member -ErrorAction Stop MemberSet PSStandardMembers $PSStandardMembers
        } catch {
            # Ignore any errors in the Add-Members. They will happen if an
            # XMLElement has been worked on already at an earlier stage, in
            # which case, adding the ScriptProperties will be redundant.
        }
        $_
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
        [Parameter(ParameterSetName="ByValue", Mandatory=$True, ValueFromPipeline=$true)]
        [xml]$ConfigXML,

        # A string representing the OPNsense interface name. Must be wan, lan,
        # or opt\d+. If not given, the first available opt interface is used.
        [Parameter(ParameterSetName="ByValue", Mandatory=$False)]
        [ValidatePattern("^(wan|lan|opt\d+)$)]")]
        [string]$Name,

        # A System.Xml.XmlElement object referring to the interface, as provided by
        # the Get-OpnSenseVLAN cmdlet.
        [Parameter(ParameterSetName="ByXMLElement", Mandatory=$True, ValueFromPipeline=$true)]
        [System.Xml.XmlElement]$XMLElement
    )
    if ($PsCmdlet.ParameterSetName -eq "ByValue") {
        $XMLElement = Get-OpnSenseInterface -Config $ConfigXML -Name $Name
    }
    if ($XMLElement) {
        $XMLElement | % {
            $_.ParentNode.RemoveChild($_) | Out-Null
        }
    } else {
        Throw "Could not find interface to remove!"
    }
}
