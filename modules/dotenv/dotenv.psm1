#Requires -Version 5.1

<#
.SYNOPSIS
    DotEnv PowerShell Module - Load environment variables from .env files

.DESCRIPTION
    A lightweight module for loading environment variables from .env files.
    Supports comments, quoted values, variable expansion, and multiple scopes.

.NOTES
    Name: DotEnv
    Author: Seu Nome
    Version: 1.0.0
    License: MIT
#>

function Import-Env {
    <#
    .SYNOPSIS
        Imports environment variables from a .env file
    
    .DESCRIPTION
        Reads a .env file and sets environment variables. Supports comments,
        quoted values, and variable expansion.
    
    .PARAMETER Path
        Path to the .env file. Can be relative or absolute.
        Supports paths with spaces (use quotes).
    
    .PARAMETER Scope
        Scope for environment variables:
        - Process: Current session only (default)
        - User: Permanent for current user
        - Machine: System-wide (requires admin)
    
    .PARAMETER Override
        Override existing environment variables
    
    .PARAMETER PassThru
        Return loaded variables as hashtable
    
    .EXAMPLE
        Import-Env .env
        Loads variables from .env in current directory
    
    .EXAMPLE
        Import-Env .\modules\db.mysql\.env -Verbose
        Loads with detailed output
    
    .EXAMPLE
        Import-Env "C:\Project\config\.env" -Override
        Loads from absolute path and overrides existing vars
    
    .EXAMPLE
        $vars = Import-Env .env -PassThru
        Returns loaded variables as hashtable
    
    .EXAMPLE
        Import-Env .env -Scope User -Override
        Saves permanently to user profile
    
    .LINK
        https://github.com/seu-usuario/dotenv-ps
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [ValidateScript({ 
            if (Test-Path $_ -PathType Leaf) { 
                return $true 
            }
            throw "File not found: $_"
        })]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'Process',

        [Parameter()]
        [switch]$Override,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Write-Verbose "DotEnv Module v1.0.0"
        
        # Valida permissões para Machine scope
        if ($Scope -eq 'Machine') {
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if (-not $isAdmin) {
                throw "Machine scope requires Administrator privileges. Run PowerShell as Administrator or use 'Process' or 'User' scope."
            }
        }
    }

    process {
        try {
            $envVars = @{}
            $resolvedPath = Resolve-Path $Path -ErrorAction Stop
            Write-Verbose "Reading file: $($resolvedPath.Path)"
            
            $content = Get-Content -Path $resolvedPath -Raw -ErrorAction Stop
            
            if ([string]::IsNullOrWhiteSpace($content)) {
                Write-Warning "File is empty: $($resolvedPath.Path)"
                return
            }
            
            # Processa linha por linha
            $lines = $content -split "`r?`n"
            $lineNumber = 0
            
            foreach ($line in $lines) {
                $lineNumber++
                
                # Remove espaços em branco
                $line = $line.Trim()
                
                # Ignora linhas vazias e comentários
                if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) {
                    continue
                }
                
                # Valida formato KEY=VALUE
                if ($line -match '^([a-zA-Z_][a-zA-Z0-9_]*)\s*=\s*(.*)$') {
                    $key = $Matches[1]
                    $value = $Matches[2].Trim()
                    
                    # Remove aspas (simples ou duplas)
                    if ($value -match '^([''"])(.*)\\1$') {
                        $value = $Matches[2]
                    }
                    
                    # Expande variáveis de ambiente existentes
                    $value = [Environment]::ExpandEnvironmentVariables($value)
                    
                    # Verifica se deve sobrescrever
                    if (-not $Override) {
                        $existing = [Environment]::GetEnvironmentVariable($key, $Scope)
                        if ($null -ne $existing) {
                            Write-Verbose "Skipped '$key' (already exists with value: '$existing')"
                            continue
                        }
                    }
                    
                    # Define variável de ambiente
                    [Environment]::SetEnvironmentVariable($key, $value, $Scope)
                    $envVars[$key] = $value
                    Write-Verbose "Set $key=$value"
                    
                } else {
                    Write-Warning "Line $lineNumber ignored (invalid format): $line"
                }
            }
            
            # Mensagem de sucesso
            if ($envVars.Count -gt 0) {
                $scopeMsg = if ($Scope -ne 'Process') { " [$Scope scope]" } else { "" }
                Write-Host "✓ Loaded $($envVars.Count) variable(s) from $($resolvedPath.Path)$scopeMsg" -ForegroundColor Green
            } else {
                Write-Warning "No valid environment variables found in: $($resolvedPath.Path)"
            }
            
            # Retorna variáveis se solicitado
            if ($PassThru) { 
                return $envVars 
            }
            
        } catch {
            Write-Error "Failed to import environment variables from '$Path': $_"
            if ($_.Exception.InnerException) {
                Write-Error "Inner exception: $($_.Exception.InnerException.Message)"
            }
            throw
        }
    }
}

function Import-ProjectEnv {
    <#
    .SYNOPSIS
        Helper function to load .env files from project modules
    
    .DESCRIPTION
        Loads .env files from a predefined project structure.
        Useful for projects with multiple module configurations.
    
    .PARAMETER Module
        Module name (e.g., "db.mysql", "api.config")
    
    .PARAMETER ProjectRoot
        Root path of the project. Defaults to $env:PROJECT_ROOT
    
    .PARAMETER Scope
        Environment variable scope (Process, User, Machine)
    
    .PARAMETER Override
        Override existing environment variables
    
    .EXAMPLE
        $env:PROJECT_ROOT = "C:\Projects\MyApp"
        Import-ProjectEnv db.mysql
    
    .EXAMPLE
        Import-ProjectEnv api.config -ProjectRoot "C:\Projects\MyApp" -Override
    #>
    
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Module,
        
        [Parameter()]
        [string]$ProjectRoot = $env:PROJECT_ROOT,
        
        [Parameter()]
        [ValidateSet('Process', 'User', 'Machine')]
        [string]$Scope = 'Process',
        
        [Parameter()]
        [switch]$Override,
        
        [Parameter()]
        [switch]$PassThru
    )
    
    if ([string]::IsNullOrEmpty($ProjectRoot)) {
        throw "ProjectRoot not defined. Set `$env:PROJECT_ROOT or pass -ProjectRoot parameter.`n" +
              "Example: `$env:PROJECT_ROOT = 'C:\Your\Project\Path'"
    }
    
    if (-not (Test-Path $ProjectRoot)) {
        throw "Project root not found: $ProjectRoot"
    }
    
    $envPath = Join-Path $ProjectRoot "modules\$Module\.env"
    
    if (-not (Test-Path $envPath)) {
        throw "Module .env file not found: $envPath"
    }
    
    Write-Verbose "Loading module '$Module' from: $envPath"
    
    # Chama Import-Env com os parâmetros
    $params = @{
        Path = $envPath
        Scope = $Scope
        Override = $Override
        PassThru = $PassThru
        Verbose = $VerbosePreference -eq 'Continue'
    }
    
    Import-Env @params
}

# Aliases para facilitar uso
Set-Alias -Name Load-Env -Value Import-Env
Set-Alias -Name dotenv -Value Import-Env

# Exporta funções e aliases
Export-ModuleMember -Function Import-Env, Import-ProjectEnv -Alias Load-Env, dotenv