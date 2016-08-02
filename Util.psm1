function NormalizeMacAddress([string]$MacAddress) {
    # Mac addresses are crazy because of all possible standards that you may see.
    # We make an effort to recognize common notations, recognising the characters
    # hyphen (-), dot (.), and colon (:) as legal group seperators.
    # We enforce the following criteria:
    # - All group seperators must be the same
    # - There must be one, three, or six groups
    # - Every group shall contain a number of hex digits.
    # - Surrounding whitespace is ignored

    # Trim surrounding whitespace
    $MacAddress = $MacAddress.Trim()

    if ($MacAddress -eq "") {
        throw "Null Mac Address"
    }

    $separator = ''
    $groupCount = 1
    foreach ($c in $MacAddress.ToCharArray()) {
        if ("1234567890abcdefABCDEF".Contains($c)) {
            # It's a digit, do nothing with this for now.
        } elseif (".-:".Contains($c)) {
            # It's a separator!
            $groupCount++
            if (-not $separator) {
                $separator = $c
            } elseif ($separator -ne $c) {
                Throw "Malformed MAC Address: Mixing group seperators is not allowed"
            }
        } else {
            Throw "Malformed MAC Address: Contains unrecognised character: '$c'"
        }
    }
    $groupLength = switch ($groupCount) {
        1 { 12 }
        3 { 4 }
        6 { 2 }
        default {
            throw "Malformed MAC Address: Invalid group count!"
        }
    }
    if ($groupCount -gt 1) {
        $groups = $MacAddress -split [Regex]::Escape($separator)
    } else {
        $groups = $MacAddress
    }
    $MacDigits = ''
    foreach ($group in $groups) {
        if ($group.Length -gt $groupLength) {
            throw "Malformed MAC Address: Over-long group!"
        } elseif ($group.Length -lt $groupLength) {
            # Zero padding
            $MacDigits += "0"*($groupLength - $group.Length)
        }
        $MacDigits += $group.ToLower()
    }
    if ($MacDigits.Length -ne 12) {
        Throw "Programming error"
    }
    $MacAddress = $MacDigits[0]
    for ($i = 1; $i -lt 12; $i++) {
        if (($i % 2) -eq 0) {
            $MacAddress += ':'
        }
        $MacAddress += $MacDigits[$i]
    }

    return $MacAddress
}