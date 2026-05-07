function Get-CRSafeProperty {
    <#
    .SYNOPSIS
        Safely retrieves a property value from a PSObject or Hashtable without throwing
        under Set-StrictMode -Version Latest.
    .DESCRIPTION
        Graph SDK (Invoke-MgGraphRequest -OutputType PSObject) may return nested collection
        items as System.Collections.Hashtable rather than PSCustomObject depending on the
        endpoint (beta vs v1.0) and SDK version. Direct property access on either type
        throws under strict mode when the property/key is absent.

        This helper returns $null for absent properties/keys on both types.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        $InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string]$Name
    )

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Collections.IDictionary]) {
        # Hashtable / OrderedDictionary
        if ($InputObject.Contains($Name)) { return $InputObject[$Name] }
        return $null
    }

    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $null
}
