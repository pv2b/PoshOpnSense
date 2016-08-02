# Force the module to be reloaded for testing...
Import-Module -Force '.\Util.psm1'

Describe 'NormalizeMacAddress' {
    It 'Normalizes Mac Addresses' {
        NormalizeMacAddress "aa:bb:cc:11:22:33" | Should Be "aa:bb:cc:11:22:33"
        NormalizeMacAddress "a:b:c:1:2:3"       | Should Be "0a:0b:0c:01:02:03"
        NormalizeMacAddress "aA:Bb:CC:dd:eE:fF" | Should Be "aa:bb:cc:dd:ee:ff"
        NormalizeMacAddress "aABbCCddeEfF"      | Should Be "aa:bb:cc:dd:ee:ff"
        NormalizeMacAddress "aABb.CCdd.eEfF"    | Should Be "aa:bb:cc:dd:ee:ff"
        NormalizeMacAddress "aA-Bb-CC-dd-eE-fF" | Should Be "aa:bb:cc:dd:ee:ff"
        NormalizeMacAddress "aABb-CCdd-eEfF"    | Should Be "aa:bb:cc:dd:ee:ff"
        NormalizeMacAddress "1"                 | Should Be "00:00:00:00:00:01"
        NormalizeMacAddress "    1    `n"       | Should Be "00:00:00:00:00:01"
        { NormalizeMacAddress("") }                     | Should Throw
        { NormalizeMacAddress($null) }                  | Should Throw
        #{ NormalizeMacAddress(1234) }                   | Should Throw
        { NormalizeMacAddress("123.12.12.12.12.12") }   | Should Throw
        { NormalizeMacAddress("12345.1234.12") }        | Should Throw
        { NormalizeMacAddress("12.34.12.34.12") }       | Should Throw
        { NormalizeMacAddress("12.34.12.34.12.99.99") } | Should Throw
    }
}