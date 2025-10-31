@{
    # Informações básicas do módulo
    RootModule        = 'env-loader.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b97b27b1-6f62-4b75-9f6a-bf25b1749a9d'
    Author            = 'Kriticos'
    CompanyName       = 'BlackSkulp Labs'
    Copyright         = '(c) 2025 BlackSkulp Labs. All rights reserved.'
    Description       = 'Module to load .env files and set environment variables in the process scope.'

    # Funções exportadas
    FunctionsToExport = @('Import-Env')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    # Dependências
    RequiredModules   = @('PSdotenv')

    # Compatibilidade
    PowerShellVersion = '5.1'

    # Informações opcionais (comentadas)
    # RequiredAssemblies = @()
    # ScriptsToProcess   = @()
    # FileList           = @('Import-Env.psm1')
    # PrivateData        = @{
    #     PSData = @{
    #         Tags        = @('Environment', 'DotEnv', 'Configuration', 'Loader')
    #         LicenseUri  = 'https://opensource.org/licenses/MIT'
    #         ProjectUri  = 'https://github.com/blackskulp/ADA-TLM'
    #     }
    # }
}
