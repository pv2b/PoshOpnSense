﻿<#
.SYNOPSIS

Creates a new OPNsense VLAN

.DESCRIPTION

The New-OpnSenseVLAN function manipulates an OPNsense configuration in order
to add a new VLAN.

.EXAMPLE

New-OpnSenseVLAN -ConfigXML $conf -Interface em0 -VLANTag 1234

Creates a VLAN with interface em0 and VLAN Tag 1234 in the configuration
object referred to by $conf.
#>
function New-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        #
        # An appropriate object can be obtained using Get-OpnSenseXMLConfig.
        [Parameter(Mandatory=$True, Position=1)]
        [xml]$ConfigXML,

        # The FreeBSD interface name of the physical interface this VLAN runs
        # on top of.
        [Parameter(Mandatory=$True)]
        [string]$Interface,

        # The VLAN ID of the VLAN. (Must be between 1 and 4094.)
        [Parameter(Mandatory=$True)]
        [ValidateRange(1,4094)]
        [int]$VLANTag
    )

    # Refuse to create a duplicate
    if (Get-OpnSenseVLAN $ConfigXML -Interface $Interface -VLANTag $VLANTag) {
        Throw "VLAN already exists!"
    }

    $vlan = $ConfigXML.CreateElement("vlan")
    foreach ($elementname in @("if", "tag", "descr", "vlanif")) {
        $child = $ConfigXML.CreateElement($elementname)
        $vlan.AppendChild($child) | Out-Null
    }
    $vlan.if = $Interface
    [string]$vlan.tag = $VLANTag
    $vlan.vlanif = $Interface + "_vlan" + $VLANTag
    $XMLElement = $ConfigXML.SelectSingleNode('/opnsense/vlans').AppendChild($vlan)
    Get-OpnSenseVLAN -XMLElement $XMLElement
}

<#
.SYNOPSIS

Changes settings on an OPNsense VLAN

.DESCRIPTION

The Set-OpnSenseVLAN function manipulates an OPNsense configuration in order
to set settings on an existing VLAN.

The existing VLAN can either be looked up using the Interface name and VLAN
tag, or by piping in the output of Get-OpnSenseVLAN.

.EXAMPLE

$c = Get-OpnSenseXMLConfig config.xml; $c | Get-OpnSenseVLAN -Interface em0 -VLANTag 1234 | Set-OpnSenseVLAN -Description "The one-two-three-four network"; $c | Out-OpnSenseXMLConfig config.xml

Edit a configuration file and add a description to the VLAN with tag 1234
on interface em0.
#>
function Set-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        # An System.Xml.XmlElement object from an OPNsense configuration file
        # representing a VLAN. Such an object is returned by the
        # Get-OpnSenseVLAN cmdlet. The element specified will be changed in
        # place as a result of executing the cmdlet, and as a result the DOM
        # containing this element will change.
        [Parameter(ParameterSetName="ByElement", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [System.Xml.XmlElement[]]$XMLElement,
        
        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        #
        # An appropriate object can be obtained using Get-OpnSenseXMLConfig.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True, Position=1)]
        [xml]$ConfigXML,

        # The FreeBSD interface name of the physical interface this VLAN runs
        # on top of.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True)]
        [string]$Interface,

        # The VLAN ID of the VLAN. (Must be between 1 and 4094.)
        [Parameter(ParameterSetName="ByValue", Mandatory=$True)]
        [ValidateRange(1,4094)]
        [int]$VLANTag,

        # A string containing a "friendly description" of the VLAN in
        # question.
        [Parameter(Mandatory=$False)]
        [string]$Description
    )
    Begin {
        if ($PsCmdlet.ParameterSetName -eq "ByValue") {
            $XMLElement = Get-OpnSenseVLAN $ConfigXML -Interface $Interface -VLANTag $VLANTag
        }
    }
    Process {
        $XMLElement | % {
            if ($PSBoundParameters.ContainsKey('Description')) {
                $_.descr = $Description
            }
            Get-OpnSenseVLAN -XMLElement $_
        }
    }
}

<#
.SYNOPSIS

Gets settings for OPNsense VLANs

.DESCRIPTION

The Get-OpnSenseVLAN function reads an OPNsense configuration in order to add
get settings for existing VLANs.

The existing VLANs can either be looked up using the Interface name and VLAN
tag, or by piping in the output of Get-OpnSenseVLAN.

.OUTPUT

Objects of type System.Xml.XmlElement are returned, representing the
requested information. The cmdlet makes no attempt at interpreting the
data, instead opting to present it as is from the configuration DOM.

.EXAMPLE

Get-OpnSenseVLAN -ConfigXML $conf -Interface em0

Interface VLANTag Description
--------- ------- -----------
em0       10      Apple
em0       11      Banana
em0       12
em1       10      Cheesecake

Retrieve information about all VLANs configured for em0.
#>
function Get-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        # A System.Xml.XmlElement object from an OPNsense configuration file
        # representing a VLAN.
        [Parameter(ParameterSetName="ByElement", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [System.Xml.XmlElement[]]$XMLElement,

        # The DOM of an OPNsense configuration file.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True, Position=1)]
        [xml]$ConfigXML,

        # The FreeBSD interface name of the physical interface this VLAN runs
        # on top of.
        [Parameter(ParameterSetName="ByValue", Mandatory=$False)]
        [ValidatePattern("^[a-z0-9]*$")]
        [string]$Interface,

        # The VLAN ID of the VLAN. (Must be between 1 and 4094.)
        [Parameter(ParameterSetName="ByValue", Mandatory=$False)]
        [ValidateRange(1,4094)]
        [int]$VLANTag
    )
    if ($PsCmdlet.ParameterSetName -eq "ByValue") {
        $xpath = '/opnsense/vlans/vlan'
        if ($Interface) {
            # Safe because $Interface is guaranteed only to contain safe characters.
            $xpath += "[if='$Interface']"
        }
        if ($VLANTag) {
            # Safe because $VLANTag is guaranteed to be an integer.
            $xpath += "[tag='$VLANTag']"
        }
        $XMLElement = $ConfigXML.SelectNodes($xpath)
    }
    $defaultProperties = @('Interface', 'VLANTag', ’Description')
    $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet('DefaultDisplayPropertySet', [string[]]$defaultProperties)
    $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
    $XMLElement | % {
        try {
            $_ | Add-Member -ErrorAction Stop ScriptProperty Interface { $this.if }
            $_ | Add-Member -ErrorAction Stop ScriptProperty VLANTag { $this.tag }
            $_ | Add-Member -ErrorAction Stop ScriptProperty Description { $this.descr }
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

Removes an OPNsense VLAN

.DESCRIPTION

The Remove-OpnSenseVLAN function manipulates an OPNsense configuration in order
to remove an existing VLAN.

The existing VLAN can either be looked up using the Interface name and VLAN
tag, or by piping in the output of Get-OpnSenseVLAN.

.EXAMPLE

Remove-OpnSenseVLAN -ConfigXML $config -Interface em0 -VLANTag 1234

Remove the VLAN with the physical interface em0 and a VLAN tag of 1234.

.EXAMPLE

Get-OpnSenseVLAN -ConfigXML $config -Interface em0 | Remove-OPNSenseVLAN

Remove all VLANs on the physical interface em0.
#>
function Remove-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        # An System.Xml.XmlElement object from an OPNsense configuration file
        # representing a VLAN. Such an object is returned by the
        # Get-OpnSenseVLAN cmdlet. The element specified will be changed in
        # place as a result of executing the cmdlet, and as a result the DOM
        # containing this element will change.
        [Parameter(ParameterSetName="ByElement", Mandatory=$True, ValueFromPipeline=$true, Position=1)]
        [System.Xml.XmlElement[]]$XMLElement,

        # The DOM of an OPNsense configuration file. The DOM specified will be
        # changed in place as a result of executing the cmdlet.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True, Position=1)]
        [xml]$ConfigXML,

        # A string representing the FreeBSD interface name of the underlying
        # physical interface to remove the VLAN from.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True)]
        [ValidatePattern("^[a-z0-9]*$")]
        [string]$Interface,

        # An integer (between 1 and 4094) representing the VLAN ID to remove
        # the VLAN from.
        [Parameter(ParameterSetName="ByValue", Mandatory=$True)]
        [ValidateRange(1,4094)]
        [int]$VLANTag
    )
    Begin {
        if ($PsCmdlet.ParameterSetName -eq "ByValue") {
            $XMLElement = Get-OpnSenseVLAN -Config $ConfigXML -Interface $Interface -VLANTag $VLANTag
            if (-not $XMLElement) {
                Throw "Could not find VLAN to remove!"
            }
        }
    }
    Process {
        $XMLElement | % {
            $_.ParentNode.RemoveChild($_) | Out-Null
        }
    }
}
