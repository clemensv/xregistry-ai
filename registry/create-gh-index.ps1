# Requires -Version 7.0
$basePath = Join-Path $PSScriptRoot 'mcpproviders'
$dirs = Get-ChildItem -Path $basePath -Directory

foreach ($dir in $dirs) {
    $login = $dir.Name
    $profileUrl = "https://github.com/$login"
    $apiUrl = "https://api.github.com/users/$login"
    try {
        $ghResult = Invoke-RestMethod -Uri $apiUrl -Headers @{ 'User-Agent' = 'PowerShell' }
    } catch {
        Write-Warning "Could not fetch info for $login"
        continue
    }
    $bio = $ghResult.bio
    $desc = if (![string]::IsNullOrWhiteSpace($bio)) { $bio } else { $ghResult.description }
    $name = if ([string]::IsNullOrWhiteSpace($ghResult.name)) { $login } else { $ghResult.name }
    $obj = [ordered]@{
        name = $name
        description = $desc
        docs = $profileUrl
    }
    $json = $obj | ConvertTo-Json -Depth 3
    $outFile = Join-Path $dir.FullName 'index.json'
    $json | Set-Content -Path $outFile
    Write-Host "Wrote $outFile"
}
