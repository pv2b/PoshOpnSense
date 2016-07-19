<#

.SYNOPSIS

Creates a new VLAN definition in an OPNsense configuration file.

.DESCRIPTION

The New-OpnSenseVLAN function manipulates the DOM of an OPNsense XML
configuration document in order to add a new VLAN.

In order to use this function, an object of the xml (System.Xml.XmlDocument)
type representing an OPNsense configuration is required. The cmdlet will
mutate the DOM supplied in order to create a new VLAN configuration with the
specified settings.

.PARAMETER ConfigXML

The DOM of an OPNsense configuration file. The DOM specified will be changed
in place as a result of executing the cmdlet.

.PARAMETER Interface

A string representing the interface name of the interface a VLAN is to be
overlaid on top of. This is to be given as a FreeBSD interface name (as
seen in /sbin/ifconfig)

.PARAMETER VLANTag

An integer (between 1 and 4094) representing the VLAN ID to use.

.PARAMETER Description

A string containing a "friendly description" of the VLAN in question.

.EXAMPLE
$c = Get-OpnSenseXMLConfig config.xml; $c | New-OpnSenseVLAN -Interface em0 -VLANTag 1234; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file and add a VLAN definition with a parent interface
em0 and a VLAN tag of 1234.
#>
function New-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
        [xml]$ConfigXML,

        [Parameter(Mandatory=$True)]
        [string]$Interface,

        [Parameter(Mandatory=$True)]
        [ValidateRange(1,4094)]
        [int]$VLANTag,

        [Parameter(Mandatory=$False)]
        [string]$Description
    )

    $vlan = $ConfigXML.CreateElement("vlan")
    foreach ($elementname in @("if", "tag", "descr", "vlanif")) {
        $child = $ConfigXML.CreateElement($elementname)
        $vlan.AppendChild($child) | Out-Null
    }
    $ConfigXML.SelectSingleNode('/opnsense/vlans').AppendChild($vlan) | Set-OpnSenseVLAN -Interface $Interface -VLANTag $VLANTag -Description $Description
}

<#

.SYNOPSIS

Manipulates an existing VLAN definition in an OPNsense configuration file.

.DESCRIPTION

The Get-OpnSenseVLAN function queries the DOM of an OPNsense XML configuration
document in order to get information on VLANs matching specified criteria.

In order to use this function, an object of the xml (System.Xml.XmlDocument)
type representing an OPNsense configuration is required.

.PARAMETER XMLElement

An System.Xml.XmlElement object from an OPNsense configuration file
representing a VLAN. Such an object is returned by the Get-OpnSenseVLAN
cmdlet. The element specified will be changed in place as a result of
executing the cmdlet, and as a result the DOM containing this element will
change.

.PARAMETER Interface

A string representing the interface name of the interface a VLAN is to be
overlaid on top of. This is to be given as a FreeBSD interface name (as
seen in /sbin/ifconfig)

.PARAMETER VLANTag

An integer (between 1 and 4094) representing the VLAN ID to use.

.PARAMETER Description

A string containing a "friendly description" of the VLAN in question.

.NOTES

This cmdlet will not update any interface assignments or other configuration
referring to the VLAN in question. That will have to be done with other
cmdlets.

.EXAMPLE
$c = Get-OpnSenseXMLConfig config.xml; $c | Get-OpnSenseVLAN -Interface em0 -VLANTag 1234 | Set-OpnSenseVLAN -Description "The one-two-three-four network"; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file and add a description to the VLAN with tag 1234
on interface em0.
#>
function Set-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
        [System.Xml.XmlElement]$XMLElement,

        [Parameter(Mandatory=$True)]
        [string]$Interface,

        [Parameter(Mandatory=$True)]
        [ValidateRange(1,4094)]
        [int]$VLANTag,

        [Parameter(Mandatory=$False)]
        [string]$Description
    )
    if ($Interface) {
        $vlan.if = $Interface
    }
    if ($VLANTag) {
        [string]$vlan.tag = $VLANTag
    }
    if ($Description) {
        $vlan.descr = $Description
    }
    $vlan.vlanif = $vlan.if+"_vlan"+$vlan.tag
    $vlan
}

<#

.SYNOPSIS

Retrieves a VLAN definition in an OPNsense configuration file.

.DESCRIPTION

The Get-OpnSenseVLAN function reads an OPNsense configuration file in
order to add a new VLAN.

In order to use this function, an object of the xml (System.Xml.XmlDocument)
type representing an OPNsense configuration is required. The cmdlet will
mutate the DOM supplied in order to create a new VLAN configuration with the
specified settings.

.OUTPUT

An object of type System.Xml.XmlElement is returned, representing the
requested information. The cmdlet makes no attempt at interpreting the
data, instead opting to present it as is from the configuration DOM.

.PARAMETER ConfigXML

The DOM of an OPNsense configuration file.

.PARAMETER Interface

A string representing the interface name of the interface to retrieve VLAN
information for. This is to be given as a FreeBSD interface name (as seen
in /sbin/ifconfig)

If unspecified, matches all interfaces.

.PARAMETER VLANTag

An integer (between 1 and 4094) representing the VLAN ID to retrieve
VLAN information for.

If unspecified, matches all VLAN tags.

.EXAMPLE
Get-OpnSenseXMLConfig config.xml | Get-OpnSenseVLAN -Interface em0

if  tag  descr      vlanif      
--  ---  -----      ------      
em0 10   Binary     em0_vlan10 
em0 11   Unary      em0_vlan11
em0 12   Ternary    em0_vlan12
em0 1234 Sequence   em0_vlan1234
em0 99   Almost     em0_vlan99
em0 2345 Seq2       em0_vlan2345
em0 7    Lucky      em0_vlan7

Retrieve information about all VLANs configured for em0.
#>
function Get-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$true)]
        [xml]$ConfigXML,

        [Parameter(Mandatory=$False)]
        [string]$Interface,

        [Parameter(Mandatory=$False)]
        [ValidateRange(1,4094)]
        [int]$VLANTag
    )

    if ($Interface -notmatch "^[a-z0-9]*$") {
        throw "Invalid interface name"
    }
    $xpath = '/opnsense/vlans/vlan'
    if ($Interface) {
        $xpath += "[if='$Interface']"
    }
    if ($VLANTag) {
        $xpath += "[tag='$VLANTag']"
    }
    $ConfigXML.SelectNodes($xpath)
}

<#

.SYNOPSIS

Removes a VLAN definition in an OPNsense configuration file.

.DESCRIPTION

The New-OpnSenseVLAN function manipulates the DOM of an OPNsense XML
configuration document in order to remove a VLAN definition.

The VLAN to be removed can either be specified by value, or providing a
System.Xml.XmlElement object referring to the VLAN, as provided by the
Get-OpnSenseVLAN cmdlet.

.NOTES

Both the Interface and VLANTag arguments are optional. If neither are
specified, and the ConfigXML parameter is used, this will therefore delete all
VLANs.

.PARAMETER ConfigXML

The DOM of an OPNsense configuration file. The DOM specified will be changed
in place as a result of executing the cmdlet.

.PARAMETER Interface

A string representing the interface name of the interface to remove VLAN
configuration for. This is to be given as a FreeBSD interface name (as seen
in /sbin/ifconfig)

If unspecified, matches all interfaces.

.PARAMETER VLANTag

An integer (between 1 and 4094) representing the VLAN ID to remove VLAN
configuration for.

If unspecified, matches all VLAN tags.

.PARAMETER XMLElement

A System.Xml.XmlElement object referring to the VLAN, as provided by the
Get-OpnSenseVLAN cmdlet.

.EXAMPLE
$c = Get-OpnSenseXMLConfig config.xml; $c | Remove-OpnSenseVLAN -Interface em0 -VLANTag 1234; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file and remove a VLAN definition with a parent interface
em0 and a VLAN tag of 1234, by specifying the requested VLAN to be deleted by
value.

.EXAMPLE
$c = Get-OpnSenseXMLConfig config.xml; $c | Get-OpnSenseVLAN -Interface em0 -VLANTag 1234 | Remove-OpnSenseVLAN; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file and remove a VLAN definition with a parent interface
em0 and a VLAN tag of 1234, after retrieving the VLAN objects using the
Get-OpnSenseVLAN cmdlet.
#>
function Remove-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        [Parameter(ParameterSetName="ByValues", Mandatory=$True, ValueFromPipeline=$true)]
        [xml]$ConfigXML,

        [Parameter(ParameterSetName="ByValues", Mandatory=$False)]
        [string]$Interface,

        [Parameter(ParameterSetName="ByValues", Mandatory=$False)]
        [ValidateRange(1,4094)]
        [int]$VLANTag,

        [Parameter(ParameterSetName="ByXMLElement", Mandatory=$True, ValueFromPipeline=$true)]
        [System.Xml.XmlElement]$XMLElement
    )
    if ($PsCmdlet.ParameterSetName -eq "ByValues") {
        $XMLElement = Get-OpnSenseVLAN -Config $ConfigXML -Interface $Interface -VLANTag $VLANTag
    }
    if ($XMLElement) {
        $XMLElement | % {
            $_.ParentNode.RemoveChild($_) | Out-Null
        }
    } else {
        Throw "Could not find VLAN to remove!"
    }
}
