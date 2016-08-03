# Force the module to be reloaded for testing...
Import-Module -ErrorAction Stop -Force PoshOpnSense

$ConfigPath = [System.IO.Path]::GetTempFileName()
Set-Content $ConfigPath -Value @"
<?xml version="1.0"?>
<opnsense>
    <version>11.2</version>
    <aliases>
        <alias>
            <name>No_description</name>
            <address>1.1.1.1</address>
            <descr/>
            <type>host</type>
            <detail/>
        </alias>
        <alias>
            <name>One_entry</name>
            <address>1.1.1.2</address>
            <descr>Test alias with one entry</descr>
            <type>host</type>
            <detail>Only entry</detail>
        </alias>
        <alias>
            <name>Two_entries</name>
            <address>1.1.1.3 1.1.1.4</address>
            <descr>Test alias with two entries</descr>
            <type>host</type>
            <detail>First entry||Second entry</detail>
        </alias>
        <alias>
            <name>Two_networks</name>
            <address>1.1.2.0/24 1.1.3.0/24</address>
            <descr>Test alias with two networks</descr>
            <type>network</type>
            <detail>First network||Second network</detail>
        </alias>
        <alias>
            <name>Two_ports</name>
            <address>100 200:300</address>
            <descr>Test alias with one port and a port range</descr>
            <type>port</type>
            <detail>Single port||Port range</detail>
        </alias>
    </aliases>
</opnsense>
"@

$conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath

Describe 'Get-OpnSenseAlias' {
    It 'Can get a list of all aliases' {
        $aliases = Get-OpnSenseAlias $conf
        $aliases.Count | Should Be 5
    }
    It 'Can get a specific alias' {
        $a = Get-OpnSenseAlias $conf -Name Two_ports
        $a.Count | Should Be $null # Can't get a count of a single item. Yay powershell.
        $a.Name| Should Be Two_ports
    }
    It 'Can get a specific alias (pipeline method)' {
        $a = $conf | Get-OpnSenseAlias -Name Two_ports
        $a.Count | Should Be $null # Can't get a count of a single item. Yay powershell.
        $a.Name| Should Be Two_ports
    }
    It 'Throws an exception on non-existent alias' {
        { Get-OpnSenseAlias $conf -Name 'nonexistent' } | Should Throw
    }
}
Describe 'Get-OpnSenseAliasEntry' {
    It 'Can get entries out of a single-entry alias' {
        $a = Get-OpnSenseAliasEntry $conf -Name One_entry
        $a.Count | Should Be $null
        $a.Address | Should Be "1.1.1.2"
        $a.Description | Should Be "Only entry"
    }
    It 'Can get entries out of a single-entry alias (pipeline method)' {
        $a = $conf | Get-OpnSenseAlias -Name One_entry | Get-OpnSenseAliasEntry
        $a.Count | Should Be $null
        $a.Address | Should Be "1.1.1.2"
        $a.Description | Should Be "Only entry"
    }
    It 'Can get entries out of a multiple-entry alias' {
        $a = Get-OpnSenseAliasEntry $conf -Name Two_entries
        $a.Count | Should Be 2
        $a[0].Address | Should Be "1.1.1.3"
        $a[1].Address | Should Be "1.1.1.4"
        $a[0].Description | Should Be "First entry"
        $a[1].Description | Should Be "Second entry"
    }
    It 'Can get entries out of a multiple-entry alias (pipeline method)' {
        $a = $conf | Get-OpnSenseAlias -Name Two_entries | Get-OpnSenseAliasEntry
        $a.Count | Should Be 2
        $a[0].Address | Should Be "1.1.1.3"
        $a[1].Address | Should Be "1.1.1.4"
        $a[0].Description | Should Be "First entry"
        $a[1].Description | Should Be "Second entry"
    }
}

Describe 'New-OpnSenseAlias' {
    It 'Can create new aliases' {
        $ExpectedAliasCount = (Get-OpnSenseAlias $conf).Count + 3
        $n = $conf | New-OpnSenseAlias -Name 'Test_Network' -Type Network
        $h = New-OpnSenseAlias -ConfigXML $conf -Name 'Test_Host' -Type Host -Description "Test description"
        $p = New-OpnSenseAlias $conf -Name 'Test_Port' -Type Port
        (Get-OpnSenseAlias $conf).Count | Should Be $ExpectedAliasCount
        (Get-OpnSenseAlias $conf 'Test_Network').XMLElement | Should Be $n.XMLElement
        (Get-OpnSenseAlias $conf 'Test_Host').XMLElement | Should Be $h.XMLElement
        (Get-OpnSenseAlias $conf 'Test_Port').XMLElement | Should Be $p.XMLElement
        $n.Name | Should Be 'Test_Network'
        $h.Name | Should Be 'Test_Host'
        $p.Name | Should Be 'Test_Port'
        $n.Type | Should BeExactly Network
        $h.Type | Should BeExactly Host
        $p.Type | Should BeExactly Port
        $n.Description | Should Be ""
        $h.Description | Should Be "Test description"
        $n.Description | Should Be ""
    }
    It 'Refuses to create a duplicate alias' {
        { Get-OpnSenseAlias $conf -Name 'No_description' } | Should Not Throw
        { New-OpnSenseAlias $conf -Name 'No_description' -Type Host } | Should Throw
    }
}

Describe 'Set-OpnSenseAlias' {
    $n = Get-OpnSenseAlias $conf 'Test_Network'
    It 'Can set description on an alias where one is not present' {
        $n.Description | Should Be ''
        $n | Set-OpnSenseAlias -Description 'Test 1'
        $n.Description | Should Be 'Test 1'
    }
    It 'Can update an existing description' {
        $n.Description | Should Not Be 'Test 2'
        $n.Description | Should Not Be ''
        $n | Set-OpnSenseAlias -Description 'Test 2'
        $n.Description | Should Be 'Test 2'
    }
    It 'Can remove an existing description' {
        $n.Description | Should Not Be ''
        $n | Set-OpnSenseAlias -Description ''
        $n.Description | Should Be ''
    }
    It 'Can change the name of an existing alias' {
        $n.Name | Should Be 'Test_Network'
        Set-OpnSenseAlias $conf -Name 'Test_Network' -NewName 'Test_Namechange'
        $n.Name | Should Be 'Test_Namechange'
        { Get-OpnSenseAlias $conf -Name 'Test_Network' } | Should Throw
        { Get-OpnSenseAlias $conf -Name 'Test_Namechange' } | Should Not Throw
    }
    It 'Refuses to create a duplicate alias' {
        { Get-OpnSenseAlias $conf -Name 'Test_Namechange' } | Should Not Throw
        { Set-OpnSenseAlias $conf -Name 'Test_Namechange' -NewName 'No_description' } | Should Throw
    }
}

Remove-Item $ConfigPath