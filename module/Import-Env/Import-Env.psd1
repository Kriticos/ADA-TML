@{
    RootModule        = 'Import-Env.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '5949ac38-a8de-4baf-9143-6f753192b8d6'
    Author            = 'Kriticos'
    CompanyName       = 'Blackskulp'
    Copyright         = '(c) Kriticos. All rights reserved.'
    Description       = 'Module to load .env files and set environment variables in the process scope.'
    PowerShellVersion = '5.1'

    RequiredModules   = @('PSdotenv')

    FunctionsToExport = @('Import-Env')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{}
    }
}