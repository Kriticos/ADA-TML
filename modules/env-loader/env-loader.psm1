function Import-Env {
    param (
        [Parameter(Mandatory)]
        [string]$envPath
    )

    if (-not (Get-Module -Name PSdotenv)) {
        try {
            Import-Module PSdotenv -ErrorAction Stop
        } catch {
            Write-Host "Error importing the PSdotenv module. Make sure it is installed."
            return
        }
    }

    if (Test-Path $envPath) {
        $dotenv = Get-Content -Path $envPath | Where-Object { $_ -match '^\w+=' }
        foreach ($line in $dotenv) {
            $key, $value = $line -split '=', 2
            [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), 'Process')
        }
        Write-Host "Environment variables loaded from: $envPath"
    } else {
        Write-Host "Environment file not found at: $envPath"
    }
}
