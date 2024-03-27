function Compare-Json {
    param (
        [PSCustomObject]$json1,
        [PSCustomObject]$json2,
        [string]$basePath = ''
    )
    $result = New-Object System.Collections.ArrayList

    # Combine keys from both JSON objects and remove duplicates
    $keys = $json1.psobject.Properties.Name  | Sort-Object -Unique
    $keys = $keys | ?{$_ -notlike "@*"}
    foreach ($key in $keys) {
        $path = if ($basePath) { "$basePath.$key" } else { $key }
        $value1 = $json1.$key
        $value2 = $json2.$key
        
        if ($value1 -is [PSCustomObject] -and $value2 -is [PSCustomObject]) {
            # Recurse into nested objects
            $nestedDifferences = Compare-Json -json1 $value1 -json2 $value2 -basePath $path
            $result.AddRange($nestedDifferences)
        }
        elseif ($value1 -ne $value2) {
            # Value difference found
            $result.Add([PSCustomObject]@{
                Path = $path
                'BP' = $value1
                'Current' = $value2
            }) | Out-Null
        }
    }

    return $result
}

$permissions = "Policy.Read.All, Policy.ReadWrite.Authorization"
#Connect-MgGraph -Scopes $permissions
$policyUrl = "https://graph.microsoft.com/beta/policies/authorizationPolicy"
$request = (Invoke-MgGraphRequest -Uri $policyUrl -Method GET).Value | ConvertTo-Json | ConvertFrom-Json

$bp = (Invoke-WebRequest "https://raw.githubusercontent.com/directorcia/bp/main/EntraID/authorization.json").Content | ConvertFrom-Json

$differences = Compare-Json -json1 $bp -json2 $request
