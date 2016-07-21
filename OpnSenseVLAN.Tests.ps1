# Force the module to be reloaded for testing...
Import-Module -Force PoshOpnSense

$ConfigPath = [System.IO.Path]::GetTempFileName()
Set-Content $ConfigPath -Value @"
<?xml version="1.0"?>
<opnsense>
    <version>11.2</version>
    <vlans>
        <vlan>
            <if>em0</if>
            <tag>10</tag>
            <descr>Apple</descr>
            <vlanif>em0_vlan10</vlanif>
        </vlan>
        <vlan>
            <if>em0</if>
            <tag>11</tag>
            <descr>Banana</descr>
            <vlanif>em0_vlan11</vlanif>
        </vlan>
        <vlan>
            <if>em0</if>
            <tag>12</tag>
            <descr />
            <vlanif>em0_vlan12</vlanif>
        </vlan>
        <vlan>
            <if>em1</if>
            <tag>10</tag>
            <descr>Cheesecake</descr>
            <vlanif>em1_vlan10</vlanif>
        </vlan>
    </vlans>
</opnsense>
"@

$conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath

Describe 'Get-OpnSenseVLAN' {
    It 'Parses the sample config' {
        $result = Get-OpnSenseVLAN $conf
        $result.Count | Should Be 4
        $result[0].Interface | Should Be "em0"
        $result[1].Interface | Should Be "em0"
        $result[2].Interface | Should Be "em0"
        $result[3].Interface | Should Be "em1"
        $result[0].VLANTag | Should Be 10
        $result[1].VLANTag | Should Be 11
        $result[2].VLANTag | Should Be 12
        $result[3].VLANTag | Should Be 10
        $result[0].Description | Should Be "Apple"
        $result[1].Description | Should Be "Banana"
        $result[2].Description | Should Be ""
        $result[3].Description | Should Be "Cheesecake"
        foreach ($r in $result) {
            $r.VLANInterface | Should Be ($r.Interface + "_vlan" + $r.VLANTag)
        }
    }

    It 'Filters on Interface Only' {
        $result = Get-OpnSenseVLAN $conf -Interface "em0"
        $result.GetType().Name | Should Be 'Object[]'
        $result.Count | Should Be 3
        $result | % { $_.Interface | Should Be "em0" }
    }

    It 'Filters on VLANTag Only' {
        $result = Get-OpnSenseVLAN $conf -VLANTag 10
        $result.GetType().Name | Should Be 'Object[]'
        $result.Count | Should Be 2
        $result | % { $_.VLANTag | Should Be 10 }
    }

    It 'Filters on both Interface and VLANTag' {
        $result = Get-OpnSenseVLAN $conf -Interface "em1" -VLANTag 10
        $result.GetType().Name | Should Be 'PSCustomObject'
        $result.VLANInterface | Should Be "em1_vlan10"
    }

    It 'Validates parameter input for Interface' {
        { Get-OpnSenseVLAN $conf -Interface "em0" } | Should Not Throw
        { Get-OpnSenseVLAN $conf -Interface "em9" } | Should Not Throw
        { Get-OpnSenseVLAN $conf -Interface "em0_vlan10" } | Should Throw
    }

    It 'Validates parameter input for VLANTag' {
        { Get-OpnSenseVLAN $conf -VLANTag 1 } | Should Not Throw
        { Get-OpnSenseVLAN $conf -VLANTag 10 } | Should Not Throw
        { Get-OpnSenseVLAN $conf -VLANTag "10" } | Should Not Throw
        { Get-OpnSenseVLAN $conf -VLANTag 10.0 } | Should Not Throw
        { Get-OpnSenseVLAN $conf -VLANTag 4094 } | Should Not Throw
        { Get-OpnSenseVLAN $conf -VLANTag 0 } | Should Throw
        { Get-OpnSenseVLAN $conf -VLANTag -100 } | Should Throw
    }
}

Describe 'New-OpnSenseVLAN' {
    It 'Adds a new VLAN' {
        $result = New-OpnSenseVLAN $conf -Interface "em2" -VLANTag 1234
        $result.GetType().Name | Should Be "PSCustomObject"
        $result.Interface | Should Be "em2"
        $result.VLANTag | Should Be "1234"
        $result.VLANInterface | Should Be "em2_vlan1234"
        (Get-OpnSenseVLAN $conf -Interface "em2" -VLANTag "1234").XMLElement | Should Be $result.XMLElement
        (Get-OpnSenseVLAN $conf -Interface "em0" -VLANTag "10").XMLElement | Should Not Be $result.XMLElement
    }
    It 'Refuses to create a duplicate VLAN' {
        { New-OpnSenseVLAN $conf -Interface "em2" -VLANTag 1234 } | Should Throw
    }
}

Describe 'Set-OpnSenseVLAN' {
    It 'Sets a description of a single VLAN by value' {
        (Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10).Description | Should Not Be "test1"
        Set-OpnSenseVLAN $conf -Interface em0 -VLANTag 10 -Description "test1"
        (Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10).Description | Should Be "test1"
    }
    It 'Sets a description of a single VLAN by pipeline' {
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan.Description | Should Not Be "test2"
        $vlan | Set-OpnSenseVLAN -Description "test2"
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan.Description | Should Be "test2"
    }
    It 'Sets a description of a single VLAN by argument' {
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan.Description | Should Not Be "test3"
        Set-OpnSenseVLAN -XMLElement $vlan.XMLElement -Description "test3"
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan.Description | Should Be "test3"
    }
    It 'Sets a description of a multiple VLANs by pipeline' {
        $vlan = Get-OpnSenseVLAN $conf -Interface em0
        $vlan.Count -gt 1 | Should Be True
        $vlan | % { $_.Description | Should Not Be "test4" }
        $vlan | Set-OpnSenseVLAN -Description "test4"
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan | % { $_.Description | Should Be "test4" }
    }
    It 'Sets a description of a multiple VLANs by argument' {
        $vlan = Get-OpnSenseVLAN $conf -Interface em0
        $vlan.Count -gt 1 | Should Be True
        $vlan | % { $_.Description | Should Not Be "test5" }
        Set-OpnSenseVLAN -XMLElement $vlan.XMLElement -Description "test5"
        $vlan = Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 10
        $vlan | % { $_.Description | Should Be "test5" }
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
        Remove-OpnSenseVLAN -XMLElement $vlan.XMLElement
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
        Remove-OpnSenseVLAN -XMLElement $vlan.XMLElement
        Get-OpnSenseVLAN $conf -Interface em0 | Should Be $null
    }
    It 'Refuses to remove a non-existent VLAN' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        Get-OpnSenseVLAN $conf -Interface em0 -VLANTag 999 | Should Be $null
        { Remove-OpnSenseVLAN $conf -Interface em0 -VLANTag 999 } | Should Throw
    }
}
Remove-Item $ConfigPath