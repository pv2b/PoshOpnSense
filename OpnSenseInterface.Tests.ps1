# Force the module to be reloaded for testing...
Import-Module -ErrorAction Stop -Force PoshOpnSense

$ConfigPath = [System.IO.Path]::GetTempFileName()
Set-Content $ConfigPath -Value @"
<?xml version="1.0"?>
<opnsense>
  <version>11.2</version>
  <interfaces>
    <wan>
      <if>em1</if>
      <descr>WAN</descr>
      <enable>1</enable>
      <spoofmac/>
      <blockpriv>1</blockpriv>
      <blockbogons>1</blockbogons>
      <ipaddr>192.0.2.1</ipaddr>
      <subnet>26</subnet>
      <gateway>ISP</gateway>
      <ipaddrv6>2001:db8:abcd:1::1</ipaddrv6>
      <subnetv6>64</subnetv6>
      <gatewayv6>ISPv6</gatewayv6>
    </wan>
    <lan>
      <if>em0_vlan10</if>
      <descr>LAN</descr>
      <enable>1</enable>
      <spoofmac/>
      <ipaddr>192.0.2.65</ipaddr>
      <subnet>26</subnet>
      <ipaddrv6>2001:db8:abcd:2::1</ipaddrv6>
      <subnetv6>64</subnetv6>
    </lan>
    <opt2>
      <if>em0_vlan18</if>
      <descr>DMZ</descr>
      <enable>1</enable>
      <spoofmac/>
      <blockbogons>1</blockbogons>
      <ipaddr>192.0.2.129</ipaddr>
      <subnet>25</subnet>
      <ipaddrv6>2001:db8:abcd:3::1</ipaddrv6>
      <subnetv6>64</subnetv6>
    </opt2>
  </interfaces>
</opnsense>
"@

$conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath

Describe 'Get-OpnSenseInterface' {
    It 'Parses the sample config' {
        $interfaces = Get-OpnSenseInterface $conf
        $interfaces.Count | Should Be 3
    }

    It 'Has handy script properties' {
        Get-OpnSenseInterface $conf | % {
            $_.Interface        | Should Be $_.if
            $_.Description      | Should Be $_.descr
            $_.Enabled          | Should Be ([bool]$_.enable)
            $_.SpoofMAC         | Should Be $_.spoofmac
            $_.IPAddress        | Should Be ([ipaddress]$_.ipaddr)
            $_.IPv6Address      | Should Be ([ipaddress]$_.ipaddrv6)
            $_.IPPrefixLength   | Should Be ([int]$_.subnet)
            $_.IPv6PrefixLength | Should Be ([int]$_.subnetv6)
            $_.BlockBogons      | Should Be ([bool]$_.blockbogons)
            $_.BlockRFC1918     | Should Be ([bool]$_.blockpriv)
        }
    }

    $interface = Get-OpnSenseInterface $conf | Select -First 1
    # This might be subject to change.
    It "Doesn't allow these script properties to be set" {
        { $interface.Interface        = 'asdf' } | Should Throw
        { $interface.Description      = 'asdf' } | Should Throw
        { $interface.Enabled          = 'asdf' } | Should Throw
        { $interface.SpoofMAC         = 'asdf' } | Should Throw
        { $interface.IPAddress        = 'asdf' } | Should Throw
        { $interface.IPv6Address      = 'asdf' } | Should Throw
        { $interface.IPPrefixLength   = 'asdf' } | Should Throw
        { $interface.IPv6PrefixLength = 'asdf' } | Should Throw
        { $interface.BlockBogons      = 'asdf' } | Should Throw
        { $interface.BlockRFC1918     = 'asdf' } | Should Throw
    }

    It 'Always reflects the same data in these friendly properties' {
        $interface.descr | Should not be 'asdf'
        $interface.descr = 'asdf'
        $interface.Description | Should be $interface.descr
    }

    It 'Can get interface by name (lowercase)' {
        $result = Get-OpnSenseInterface $conf -Name "opt2"
        $result.GetType().Name | Should Be 'XMLElement'
        $result | % { $_.if | Should Be "em0_vlan18" }
    }

    It "Can get interface by name (mixed case)" {
        $result = Get-OpnSenseInterface $conf -Name "OpT2"
        $result.GetType().Name | Should Be 'XMLElement'
        $result | % { $_.if | Should Be "em0_vlan18" }
    }

    It 'Validates parameter input for name' {
        { Get-OpnSenseInterface $conf -Name "Wan" } | Should Not Throw
        { Get-OpnSenseInterface $conf -Name "LAN" } | Should Not Throw
        { Get-OpnSenseInterface $conf -Name "opt234" } | Should Not Throw
        { Get-OpnSenseInterface $conf -Name "opt" } | Should Throw
        { Get-OpnSenseInterface $conf -Name "" } | Should Throw
        { Get-OpnSenseInterface $conf -Name "pnyxtr" } | Should Throw
    }

    It 'Can be given an XML Element as a paramter (useful to add its ScriptProperties if neccessary)' {
        $if = Get-OpnSenseInterface $conf "wan"
        Get-OpnSenseInterface $if | should be $if
    }
}

Describe 'New-OpnSenseInterface' {
    It 'Adds a new Interface' {
        # Random capital letter in the name to test that value is properly folded to lowercase
        $result = New-OpnSenseInterface $conf -Name "oPt11" -Interface "em2" -Description "test1"
        $result.GetType().Name | Should Be "XmlElement"
        # Make sure value is folder to lowercase here!
        $result.Name | Should BeExactly "opt11"
        $result.Interface | Should Be "em2"
        $result.Description | Should Be "test1"
        Get-OpnSenseInterface $conf "opt11" | Should Be $result
        Get-OpnSenseInterface $conf "wan" | Should Not Be $result
    }
    It 'Refuses to create a duplicate Interface' {
        { New-OpnSenseInterface $conf -Name "opt11" -Interface "em999" -Description "test2" } | Should Throw
        (Get-OpnSenseInterface $conf "opt11").Name | Should not be "test2"
    }
}
<#
Describe 'Set-OpnSenseVLAN' {
    It 'Sets a description of a single VLAN by value' {
        (Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10).descr | Should Not Be "test1"
        Set-OpnSenseVLAN $conf -Interface em0 -VLANTag 10 -Description "test1"
        (Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10).descr | Should Be "test1"
    }
    It 'Sets a description of a single VLAN by pipeline' {
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan.descr | Should Not Be "test2"
        $vlan | Set-OpnSenseVLAN -Description "test2"
        $vlan.descr | Should Be "test2"
    }
    It 'Sets a description of a single VLAN by argument' {
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan.descr | Should Not Be "test3"
        Set-OpnSenseVLAN -XMLElement $vlan -Description "test3"
        $vlan.descr | Should Be "test3"
    }
    It 'Sets a description of a multiple VLANs by pipeline' {
        $vlan = Get-OpnSenseVLAN $conf -Interface em0
        $vlan.Count -gt 1 | Should Be True
        $vlan | % { $_.descr | Should Not Be "test4" }
        $vlan | Set-OpnSenseVLAN -Description "test4"
        $vlan | % { $_.descr | Should Be "test4" }
    }
    It 'Sets a description of a multiple VLANs by argument' {
        $vlan = Get-OpnSenseVLAN $conf -Interface em0
        $vlan.Count -gt 1 | Should Be True
        $vlan | % { $_.descr | Should Not Be "test5" }
        Set-OpnSenseVLAN -XMLElement $vlan -Description "test5"
        $vlan | % { $_.descr | Should Be "test5" }
    }
}

Describe 'Remove-OpnSenseVLAN' {
    It 'Removes a single VLAN by value' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10 | Should Not Be $null
        Remove-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10 | Should Be $null
    }
    It 'Removes a single VLAN by pipeline' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan | Should Not Be $null
        $vlan | Remove-OpnSenseVLAN
        Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10 | Should Be $null
    }
    It 'Removes a single VLAN by argument' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan | Should Not Be $null
        Remove-OpnSenseVLAN $vlan
        Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10 | Should Be $null
    }
    It 'Removes multiple VLANs by pipeline' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $vlan = Get-OpnSenseVLAN $conf -Interface em0
        $vlan.Count -gt 1 | Should Be True
        $vlan | Remove-OpnSenseVLAN
        Get-OpnSenseVLAN $conf -Interface em0 | Should Be $null
    }
    It 'Removes multiple VLANs by argument' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $vlan = Get-OpnSenseVLAN $conf -Interface em0
        $vlan.Count -gt 1 | Should Be True
        Remove-OpnSenseVLAN $vlan
        Get-OpnSenseVLAN $conf -Interface em0 | Should Be $null
    }
    It 'Refuses to remove a non-existent VLAN' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 999 | Should Be $null
        { Remove-OpnSenseVLAN $conf -Interface em0 -VLANTag 999 } | Should Throw
    }
}
#>
Remove-Item $ConfigPath
