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
        $conf.version | Should Be "11.2"
        $conf.revision | Should Not Be $null
    }
}

Describe 'Out-OpnSenseXMLConfig' {
    It 'Overwriting existing file' {
        Out-OpnSenseXMLConfig -FilePath $ConfigPath -ConfigXML $conf -Description "Unit testing 1"
        $conf2 = Get-OpnSenseVLAN -ConfigXML $ConfigPath
        $conf2 | Should Not Be $conf
        $conf2.revision.desc | Should Be "Unit Testing 1"
    }
    Is 'Creating newfile' {
        Remove-Item $ConfigPath
        Out-OpnSenseXMLConfig -FilePath $ConfigPath -ConfigXML $conf -Description "Unit testing 2"
        $conf2 = Get-OpnSenseVLAN -ConfigXML $ConfigPath
        $conf2 | Should Not Be $conf
        $conf2.revision.desc | Should Be "Unit Testing 2"
    }
}

Remove-Item $ConfigPath