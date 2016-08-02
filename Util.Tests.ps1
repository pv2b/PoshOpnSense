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

Describe 'Join-Array' {
    It 'Joins arrays' {
        $names = ("apple", "banana", "pineapple")
        $numbers = 9923, 1234, 7123

        $joined = Join-Array @{Name="Number"; Array=$numbers}, @{Name="Name"; Array=$names}
        ($joined | Measure-Object).Count | Should Be 3
        $joined[0].Name | Should Be "apple"
        $joined[0].Number | Should Be 9923
        $joined[1].Name | Should Be "banana"
        $joined[1].Number | Should Be 1234
        $joined[2].Name | Should Be "pineapple"
        $joined[2].Number | Should Be 7123
    }

    It 'Handles arrays of different length' {
        $names = ("apple", "banana")
        $numbers = 9923, 1234, 7123

        $joined = Join-Array @{Name="Number"; Array=$numbers}, @{Name="Name"; Array=$names}
        ($joined | Measure-Object).Count | Should Be 3
        $joined[0].Name | Should Be "apple"
        $joined[0].Number | Should Be 9923
        $joined[1].Name | Should Be "banana"
        $joined[1].Number | Should Be 1234
        $joined[2].Name | Should Be $null
        $joined[2].Number | Should Be 7123
    }

    It 'Handles arrays of different length (flipped)' {
        $names = ("apple", "banana")
        $numbers = 9923, 1234, 7123

        $joined = Join-Array @{Name="Name"; Array=$names}, @{Name="Number"; Array=$numbers}
        ($joined | Measure-Object).Count | Should Be 3
        $joined[0].Name | Should Be "apple"
        $joined[0].Number | Should Be 9923
        $joined[1].Name | Should Be "banana"
        $joined[1].Number | Should Be 1234
        $joined[2].Name | Should Be $null
        $joined[2].Number | Should Be 7123
    }

    It 'Properly deals arrays dropping off over time' {
        $names = ("apple", "banana", "pineapple")
        $numbers = 9923, 1234
        $prices = 111

        $joined = Join-Array @{Name="Number"; Array=$numbers}, @{Name="Name"; Array=$names}, @{Name="Price"; Array=$prices}
        ($joined | Measure-Object).Count | Should Be 3
        $joined[0].Name | Should Be "apple"
        $joined[0].Number | Should Be 9923
        $joined[0].Price | Should Be 111

        $joined[1].Name | Should Be "banana"
        $joined[1].Number | Should Be 1234
        $joined[1].Price | Should Be $null

        $joined[2].Name | Should Be "pineapple"
        $joined[2].Number | Should Be $null
        $joined[2].Price | Should Be $null
    }
}
