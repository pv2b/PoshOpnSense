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

function Get-OpnSenseVLAN {
    [Cmdletbinding()]
    Param(
        [Parameter(Mandatory=$True)]
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
