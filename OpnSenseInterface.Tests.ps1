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
      <enable></enable>
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
    It 'Automatically takes the first free opt interface name if not given' {
        # Test the opt1 special case
        $if = New-OpnSenseInterface $conf -Interface "em2"
        $if.Name | Should Be "opt1"
        $if = New-OpnSenseInterface $conf -Interface "em3"
        $if.Name | Should Be "opt3"
    }
    It 'Sets the description from the name if not given' {
        $if = New-OpnSenseInterface $conf -Name "opt99" -Interface "em99"
        $if.Description | Should BeExactly "OPT99"
        $if = New-OpnSenseInterface $conf -Interface "em98"
        $if.Description | Should Be $if.Name.ToUpper()
    }
}

Describe 'Set-OpnSenseInterface' {
    It 'Sets a description of an interface by name' {
        (Get-OpnSenseInterface $conf -Name WaN).descr | Should Not Be "test1"
        Set-OpnSenseInterface $conf -Name wan -Description "test1"
        (Get-OpnSenseInterface $conf -Name WAN).descr | Should Be "test1"
    }
    It 'Sets a description of a single interface by pipeline' {
        $if = Get-OpnSenseInterface $conf -Name wan
        $if.descr | Should Not Be "test2"
        $if | Set-OpnSenseInterface -Description "test2"
        $if.descr | Should Be "test2"
    }
    It 'Sets a description of a single interface by argument' {
        $if = Get-OpnSenseInterface $conf -Name Wan
        $if.descr | Should Not Be "test3"
        Set-OpnSenseInterface -XMLElement $if -Description "test3"
        $if.descr | Should Be "test3"
    }
    It 'Sets a description of a multiple interfaces by pipeline' {
        $if = Get-OpnSenseInterface $conf
        $if.Count -gt 1 | Should Be True
        $if | % { $_.Description | Should Not Be "test4" }
        $if | Set-OpnSenseInterface -Description "test4"
        $if | % { $_.Description | Should Be "test4" }
    }
    It 'Sets a description of a multiple interfaces by argument' {
        $if = Get-OpnSenseInterface $conf
        $if.Count -gt 1 | Should Be True
        $if | % { $_.Description | Should Not Be "test5" }
        Set-OpnSenseInterface -XMLElement $if -Description "test5"
        $if | % { $_.Description | Should Be "test5" }
    }

    It 'Can set SpoofMac' {
        $if.SpoofMAC | Should be ""
        Set-OpnSenseInterface $if -SpoofMac "11:22:33:44:55:66"
        $if.SpoofMAC | Should be "11:22:33:44:55:66"
        Set-OpnSenseInterface $if -SpoofMac ""
        $if.SpoofMAC | Should be ""
    }

    It 'Validates SpoofMac parameter' {
        { Set-OpnSenseInterface $if -SpoofMac "pnyxtr" } | Should Throw

    }

    It 'Can set interface' {
        $if.Interface | Should not be "em55"
        Set-OpnSenseInterface $if -Interface "em55"
        $if.Interface | Should be "em55"
    }

    It 'Can set IPAddress' {
        $if.IPAddress | Should not be "192.0.2.123"
        Set-OpnSenseInterface $if -IPAddress "192.0.2.123"
        $if.IPAddress | Should be "192.0.2.123"
    }

    It 'Can set IPv6 Address' {
        $if.IPv6Address | Should not be "2001:db8:abcd:1::123"
        Set-OpnSenseInterface $if -IPAddress "2001:db8:abcd:1::123"
        $if.IPv6Address | Should be "2001:db8:abcd:1::123"
    }

    It 'Validates IPAddress parameter' {
        { Set-OpnSenseInterface $if -IPAddress "192.0.2.257" } | Should Throw
        { Set-OpnSenseInterface $if -IPAddress "123456" } | Should Throw
        { Set-OpnSenseInterface $if -IPAddress "1.2.3." } | Should Throw
        { Set-OpnSenseInterface $if -IPAddress "zxcv" } | Should Throw
        { Set-OpnSenseInterface $if -IPAddress "1a7.1.2.3" } | Should Throw
        { Set-OpnSenseInterface $if -IPAddress "2001:db8:abcd:1::123" } | Should Throw
    }

    It 'Validates IPv6Address parameter' {
        { Set-OpnSenseInterface $if -IPv6Address "fffg:db8:abcd:1::123" } | Should Throw
        { Set-OpnSenseInterface $if -IPv6Address "123456" } | Should Throw
        { Set-OpnSenseInterface $if -IPv6Address "1.2.3." } | Should Throw
        { Set-OpnSenseInterface $if -IPv6Address "zxcv" } | Should Throw
        { Set-OpnSenseInterface $if -IPv6Address "1a7.1.2.3" } | Should Throw
        { Set-OpnSenseInterface $if -IPv6Address "192.0.2.123" } | Should Throw
    }

    It 'Sets prefix length' {
        $if.IPPrefixLength | Should not be 30
        Set-OpnSenseInterface $if -IPPrefixLength
        $if.IPPrefixLength | Should be 30
    }

    It 'Validates prefix length' {
        { Set-OpnSenseInterface $if -IPPrefixLength -1 } | Should Throw
        # Weird but valid configurations...
        { Set-OpnSenseInterface $if -IPPrefixLength 0 } | Should Not Throw
        { Set-OpnSenseInterface $if -IPPrefixLength 32 } | Should Not Throw
        { Set-OpnSenseInterface $if -IPPrefixLength 33 } | Should Throw
    }

    It 'Sets prefix length' {
        $if.IPv6PrefixLength | Should not be 65
        Set-OpnSenseInterface $if -IPv6PrefixLength
        $if.IPv6PrefixLength | Should be 65
    }

    It 'Validates ipv6 prefix length' {
        { Set-OpnSenseInterface $if -IPv6PrefixLength -1 } | Should Throw
        # Weird but valid configurations...
        { Set-OpnSenseInterface $if -IPv6PrefixLength 0 } | Should Not Throw
        { Set-OpnSenseInterface $if -IPv6PrefixLength 32 } | Should Not Throw
        { Set-OpnSenseInterface $if -IPv6PrefixLength 33 } | Should Throw
    }

    It 'Can set BlockBogons' {
        $if.BlockBogons | Should be $true
        Set-OpnSenseInterface $if -BlockBogons $false
        $if.BlockBogons | Should be $false
    }

    It 'Can set BlockRFC1918' {
        $if.BlockRFC1918 | Should be $true
        Set-OpnSenseInterface $if -BlockRFC1918 $false
        $if.BlockRFC1918 | Should be $false
    }
}

Describe 'Remove-OpnSenseInterface' {
    It 'Removes a single interface by value' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        Get-OpnSenseInterface $conf -Name oPt2 | Should Not Be $null
        Remove-OpnSenseInterface $conf -Name OPt2
        Get-OpnSenseInterface $conf -Name opt2 | Should Be $null
    }
    It 'Removes a single interface by pipeline' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf -Name OPT2
        $if | Should Not Be $null
        $if | Remove-OpnSenseInterface
        Get-OpnSenseInterface $conf -Name opt2 | Should Be $null
    }
    It 'Removes a single interface by argument' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf -Name OPT2
        $if | Should Not Be $null
        Remove-OpnSenseInterface $if
        Get-OpnSenseInterface $conf -Name opt2 | Should Be $null
    }
    It 'Removes multiple interfaces by pipeline' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf | Select -First 2
        $if.Count | Should Be 2
        $if | Remove-OpnSenseInterface
        # Only one single element left!
        $result = Get-OpnSenseInterface $conf
        $result.GetType().Name | Should Be 'XMLElement'
    }
    It 'Removes multiple interfaces by argument' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf | Select -First 2
        $if.Count | Should Be 2
        Remove-OpnSenseInterface $if
        # Only one single element left!
        $result = Get-OpnSenseInterface $conf
        $result.GetType().Name | Should Be 'XMLElement'
    }
    It 'Refuses to remove a non-existent interface' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        Get-OpnSenseInterface $conf -Name opt567 | Should Be $null
        { Remove-OpnSenseInterface $conf -Name opt567 } | Should Throw
    }
}

Describe 'Enable-OpnSenseInterface' {
    It 'Enables a single interface by value' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        (Get-OpnSenseInterface $conf -Name oPt2).Enabled | Should Be $False
        Enable-OpnSenseInterface $conf -Name OPt2
        (Get-OpnSenseInterface $conf -Name oPt2).Enabled | Should Be $True
    }
    It 'Enables a single interface by pipeline' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf -Name OPT2
        $if.Enabled | Should Be $False
        $if | Enable-OpnSenseInterface
        (Get-OpnSenseInterface $conf -Name opt2).Enabled | Should Be $true
    }
    It 'Enables a single interface by argument' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf -Name OPT2
        $if.Enabled | Should Be $false
        Enable-OpnSenseInterface $if
        (Get-OpnSenseInterface $conf -Name opt2).Enabled | Should Be $true
    }
    It 'Enables multiple interfaces by pipeline' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf
        $if.Count | Should Be 3
        $if | Enable-OpnSenseInterface
        Get-OpnSenseInterface $conf | % {
            $_.enabled | Should Be $true
        }
    }
    It 'Enables multiple interfaces by argument' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf
        $if.Count | Should Be 3
        Enable-OpnSenseInterface $if
        Get-OpnSenseInterface $conf | % {
            $_.enabled | Should Be $true
        }
    }
    It 'Refuses to enable a non-existent interface' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        Get-OpnSenseInterface $conf -Name opt567 | Should Be $null
        { Enable-OpnSenseInterface $conf -Name opt567 } | Should Throw
    }
}

Describe 'Disable-OpnSenseInterface' {
    It 'Disables a single interface by value' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        (Get-OpnSenseInterface $conf -Name lAn).Enabled | Should Be $True
        Disable-OpnSenseInterface $conf -Name LAn
        (Get-OpnSenseInterface $conf -Name lan).Enabled | Should Be $False
    }
    It 'Disables a single interface by pipeline' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf -Name lAn
        $if.Enabled | Should Be $true
        $if | Disable-OpnSenseInterface
        (Get-OpnSenseInterface $conf -Name LAN).Enabled | Should Be $false
    }
    It 'Disables a single interface by argument' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf -Name lan
        $if.Enabled | Should Be $true
        Disable-OpnSenseInterface $if
        (Get-OpnSenseInterface $conf -Name laN).Enabled | Should Be $false
    }
    It 'Disables multiple interfaces by pipeline' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf
        $if.Count | Should Be 3
        $if | Disable-OpnSenseInterface
        Get-OpnSenseInterface $conf | % {
            $_.enabled | Should Be $false
        }
    }
    It 'Disables multiple interfaces by argument' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $if = Get-OpnSenseInterface $conf
        $if.Count | Should Be 3
        Disable-OpnSenseInterface $if
        Get-OpnSenseInterface $conf | % {
            $_.enabled | Should Be $false
        }
    }
    It 'Refuses to disable a non-existent interface' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        Get-OpnSenseInterface $conf -Name opt567 | Should Be $null
        { Disable-OpnSenseInterface $conf -Name opt567 } | Should Throw
    }
}
