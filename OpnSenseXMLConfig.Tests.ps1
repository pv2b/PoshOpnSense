# Force the module to be reloaded for testing...
Import-Module -Force PoshOpnSense

$ConfigPath = [System.IO.Path]::GetTempFileName()
Set-Content $ConfigPath -Value @"
<?xml version="1.0"?>
<opnsense>
  <version>11.2</version>
  <revision>
    <time>1468852875.0343</time>
    <description>/services_unbound_overrides.php made changes</description>
    <username>root@192.0.2.123</username>
  </revision>
</opnsense>
"@

Describe 'Get-OpnSenseXMLConfig' {
    # This is a test in itself, implicitly, making sure it doesn't throw an exception!
    It 'Reads a configuration file from disk' {
        $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        # Basic sanity check of read data
        $conf.opnsense.version | Should Be "11.2"
        $conf.opnsense.revision | Should Not Be $null
    }
}

Describe 'Out-OpnSenseXMLConfig' {
    $conf = Get-OpnSenseXMLConfig -FilePath $ConfigPath
    It 'Overwriting existing file' {
        $oldtime = $conf.opnsense.revision.time
        Out-OpnSenseXMLConfig -FilePath $ConfigPath -ConfigXML $conf -Description "Unit testing 1"
        $conf2 = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $conf2.opnsense.revision.time | Should Not Be $oldtime
        $conf2 | Should Not Be $conf
        $conf2.opnsense.revision.description | Should Be "Unit Testing 1"
    }
    It 'Creating new file' {
        Remove-Item $ConfigPath
        $oldtime = $conf.opnsense.revision.time
        Out-OpnSenseXMLConfig -FilePath $ConfigPath -ConfigXML $conf -Description "Unit testing 2"
        $conf2 = Get-OpnSenseXMLConfig -FilePath $ConfigPath
        $conf2.opnsense.revision.time | Should Not Be $oldtime
        $conf2 | Should Not Be $conf
        $conf2.opnsense.revision.description | Should Be "Unit Testing 2"
    }
}

Remove-Item $ConfigPath