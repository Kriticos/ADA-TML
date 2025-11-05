# DotEnv PowerShell Module

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Version](https://img.shields.io/badge/version-1.0.0-orange)

A lightweight PowerShell module for loading environment variables from `.env` files. Zero dependencies, secure, and easy to use.

## ✨ Features

- 🚀 **Zero dependencies** - No external modules required
- 🔒 **Secure** - No supply chain risks
- 💬 **Comments support** - Lines starting with `#`
- 🎯 **Quoted values** - Single and double quotes
- 🔄 **Variable expansion** - Use existing environment variables
- 📦 **Multiple scopes** - Process, User, or Machine level
- ⚡ **Fast and lightweight** - Minimal overhead
- 🛡️ **Error handling** - Robust validation and error messages

## 📦 Installation

### Option 1: Manual Installation

1. Download the module files
2. Copy to your PowerShell modules directory:

```powershell
# For current user
$modulePath = "$env:USERPROFILE\Documents\PowerShell\Modules\DotEnv"
New-Item -Path $modulePath -ItemType Directory -Force
Copy-Item .\DotEnv.* -Destination $modulePath

# Verify installation
Get-Module -ListAvailable DotEnv
```

### Option 2: Quick Install (from repository)

```powershell
# Clone and install
git clone https://github.com/seu-usuario/dotenv-ps.git
cd dotenv-ps
.\Install.ps1
```

## 🚀 Quick Start

### Basic Usage

```powershell
# Import the module
Import-Module DotEnv

# Load environment variables from .env file
Import-Env .env

# Access your variables
$env:DATABASE_URL
$env:API_KEY
```

### Example .env file

```bash
# Database Configuration
DATABASE_URL=postgresql://localhost:5432/mydb
DATABASE_USER=admin
DATABASE_PASSWORD=secret123

# API Settings
API_KEY=abc123xyz789
API_ENDPOINT=https://api.example.com
API_TIMEOUT=30

# Feature Flags
ENABLE_LOGGING=true
DEBUG_MODE=false

# Quoted values
MESSAGE="Hello, World!"
PATH_WITH_SPACES='/path/to/my folder'

# Variable expansion (uses existing env vars)
HOME_CONFIG=%USERPROFILE%\.config
```

## 📖 Documentation

### Import-Env

Imports environment variables from a .env file.

#### Syntax

```powershell
Import-Env [-Path] <String> 
           [-Scope <String>] 
           [-Override] 
           [-PassThru] 
           [-Verbose]
```

#### Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Path` | String | Yes | - | Path to the .env file |
| `Scope` | String | No | Process | Where to store variables: `Process`, `User`, or `Machine` |
| `Override` | Switch | No | False | Override existing environment variables |
| `PassThru` | Switch | No | False | Return loaded variables as hashtable |
| `Verbose` | Switch | No | False | Show detailed operation messages |

#### Scope Details

| Scope | Duration | Visibility | Admin Required |
|-------|----------|------------|----------------|
| **Process** | Current session only | Current PowerShell process | No |
| **User** | Permanent | Current user only | No |
| **Machine** | Permanent | All users | Yes ⚠️ |

## 💡 Usage Examples

### 1. Basic Load (Temporary)

```powershell
# Loads variables for current PowerShell session only
Import-Env .env
```

### 2. With Verbose Output

```powershell
# See exactly what's being loaded
Import-Env .env -Verbose
```

**Output:**
```
VERBOSE: Set DATABASE_URL=postgresql://localhost:5432
VERBOSE: Set API_KEY=abc123
VERBOSE: Skipped 'PATH' (exists: C:\Windows\System32)
✓ Loaded 2 variable(s) from C:\project\.env
```

### 3. Override Existing Variables

```powershell
# Force replace existing environment variables
Import-Env .env -Override
```

### 4. Get Loaded Variables

```powershell
# Return loaded variables as hashtable
$vars = Import-Env .env -PassThru

# Access individual values
Write-Host "API Key: $($vars.API_KEY)"

# List all loaded variables
$vars.Keys | ForEach-Object {
    Write-Host "$_ = $($vars[$_])"
}
```

### 5. Permanent User Variables

```powershell
# Save to user profile (survives restarts)
Import-Env .env -Scope User -Override
```

⚠️ **Warning:** Use `User` scope carefully - variables persist after restarts!

### 6. System-Wide Variables

```powershell
# Requires Administrator
Import-Env .env -Scope Machine -Override
```

⚠️ **Danger:** `Machine` scope affects all users. Never use with secrets!

### 7. Multiple Environment Files

```powershell
# Load base configuration
Import-Env .env

# Override with local settings
Import-Env .env.local -Override

# Override with production settings
Import-Env .env.production -Override
```

### 8. Development Workflow

```powershell
# In your PowerShell profile or startup script
if (Test-Path .\.env.local) {
    Import-Env .env.local -Verbose
} elseif (Test-Path .\.env) {
    Import-Env .env -Verbose
} else {
    Write-Warning "No .env file found"
}
```

### 9. Using Alias

```powershell
# Shorter command
Load-Env .env
```

## 🎯 Advanced Examples

### Conditional Loading

```powershell
# Load different files based on environment
$envFile = if ($env:ENVIRONMENT -eq 'production') {
    '.env.production'
} else {
    '.env.local'
}

if (Test-Path $envFile) {
    Import-Env $envFile -Override
}
```

### Validation After Loading

```powershell
# Load and validate required variables
$vars = Import-Env .env -PassThru

$required = @('DATABASE_URL', 'API_KEY', 'SECRET_KEY')
$missing = $required | Where-Object { -not $vars.ContainsKey($_) }

if ($missing) {
    Write-Error "Missing required variables: $($missing -join ', ')"
    exit 1
}
```

### Backup Current Environment

```powershell
# Save current state
$backup = @{}
Get-ChildItem env: | ForEach-Object {
    $backup[$_.Name] = $_.Value
}

# Load new variables
Import-Env .env -Override

# Restore if needed
# $backup.GetEnumerator() | ForEach-Object {
#     [Environment]::SetEnvironmentVariable($_.Key, $_.Value, 'Process')
# }
```

## 🔒 Security Best Practices

### ✅ DO

- Use `Process` scope (default) for development
- Add `.env` to `.gitignore`
- Use `.env.example` for documentation (without secrets)
- Validate required variables after loading
- Use different files for different environments

### ❌ DON'T

- Never commit `.env` files with secrets to version control
- Avoid `Machine` scope with sensitive data
- Don't use `User` scope for temporary secrets
- Never share `.env` files containing API keys or passwords

### Example `.gitignore`

```gitignore
# Environment files
.env
.env.local
.env.*.local

# Keep example file
!.env.example
```

### Example `.env.example`

```bash
# Copy this file to .env and fill in your values
DATABASE_URL=postgresql://localhost:5432/dbname
API_KEY=your_api_key_here
SECRET_KEY=your_secret_here
```

## 🐛 Troubleshooting

### Module Not Found

```powershell
# Check if module is in the right location
Get-Module -ListAvailable DotEnv

# If not found, check your module path
$env:PSModulePath -split ';'

# Manually import from specific path
Import-Module C:\path\to\DotEnv\DotEnv.psd1
```

### Variables Not Loading

```powershell
# Use verbose to see what's happening
Import-Env .env -Verbose

# Check if file exists and is readable
Test-Path .env
Get-Content .env
```

### Permission Denied (Machine Scope)

```powershell
# Run PowerShell as Administrator
Start-Process powershell -Verb RunAs

# Then import with Machine scope
Import-Env .env -Scope Machine
```

## 📋 Supported .env Format

### Valid Formats

```bash
# Comments
# This is a comment

# Simple key=value
KEY=value
API_KEY=abc123

# With spaces
KEY = value
API_KEY = abc123

# Quoted values
MESSAGE="Hello World"
PATH='/path/with/spaces'

# Variable expansion
HOME_DIR=%USERPROFILE%
CONFIG_PATH=$HOME/.config

# Empty values
EMPTY_VAR=

# Underscores and numbers
MY_VAR_123=value
_PRIVATE_KEY=secret
```

### Invalid Formats

```bash
# ❌ Keys starting with numbers
123KEY=value

# ❌ Keys with special characters
MY-KEY=value
MY.KEY=value

# ❌ Missing equals sign
KEY value

# ❌ Multiline values (not supported yet)
KEY="line1
line2"
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Inspired by the [dotenv](https://github.com/motdotla/dotenv) Node.js package
- Built for the PowerShell community

## 📞 Support

- 🐛 [Report a bug](https://github.com/seu-usuario/dotenv-ps/issues)
- 💡 [Request a feature](https://github.com/seu-usuario/dotenv-ps/issues)
- 📖 [Documentation](https://github.com/seu-usuario/dotenv-ps/wiki)

## 📊 Changelog

### v1.0.0 (2025-01-05)

- Initial release
- Support for .env file parsing
- Comments support
- Quoted values support
- Variable expansion
- Multiple scope support (Process, User, Machine)
- Override option
- PassThru option
- Verbose logging

---

Made with ❤️ for the PowerShell community