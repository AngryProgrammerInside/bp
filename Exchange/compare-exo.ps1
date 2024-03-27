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

        if ($value1 -is [System.Array] -or $value1 -is [System.Collections.ArrayList]) {$value1 = $value1 -join ','}
        if ($value2 -is [System.Array] -or $value2 -is [System.Collections.ArrayList]) {$value2 = $value2 -join ','}

        if ($value1 -is [PSCustomObject] -and $value2 -is [PSCustomObject]) {
            # Recurse into nested objects
            $nestedDifferences = Compare-Json -json1 $value1 -json2 $value2 -basePath $path
            $result.AddRange($nestedDifferences)
        }
            # Value difference found
            $result.Add([PSCustomObject]@{
                Path = $path
                'BP' = $value1
                'Current' = $value2
            }) | Out-Null
    }

    return $result
}

#Connect-ExchangeOnline

$policyCommandsHT = @{
    'inbound-connections.json' = {Get-HostedConnectionFilterPolicy -Identity Default}
    'inbound-malware.json' = {Get-MalwareFilterPolicy  -Identity Default}
    'inbound-spam.json' = {Get-HostedContentFilterPolicy -Identity Default}
}

$bp_report = New-Object System.Collections.ArrayList
foreach ($file in $policyCommandsHT.Keys) {
    $bp = Get-Content "$PSScriptRoot\$file" | ConvertFrom-Json
    $configuration = & $policyCommandsHT[$file]
    $differences = Compare-Json -json1 $bp -json2 $configuration
    $differences = $differences | Select-Object @{n='Policy';e={$file}},@{n='Command';e={$policyCommandsHT[$file]}},*,@{n='Aligned';e={if ($_.BP -eq $_.Current -or $_.BP -like $_.Current) { $true } else { $false }}}
    $bp_report.AddRange($differences)    
}
$DateTime = Get-Date
$DateTime = $DateTime.ToString("yyyyMMddHHmmss")
$ReportName = "C:\Temp\$DateTime-ExoReport.xlsx"

# Export the device report to an Excel file
$bp_report | Export-Excel -Path $ReportName -WorksheetName "Exchange" -ClearSheet –BoldTopRow -AutoSize `
    -TableName DevicesTable -TableStyle Medium6 -FreezeTopRow