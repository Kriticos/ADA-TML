@{
    # Informações básicas do módulo
    RootModule = 'dotenv.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Autor e empresa
    Author = 'Rodrigo "Kriticos" Fabricio'
    CompanyName = 'BlackSkulp'
    Copyright = '(c) 2025. All rights reserved.'
    
    # Descrição do módulo
    Description = 'PowerShell module for loading environment variables from .env files. Supports comments, quoted values, variable expansion, and multiple scopes.'
    
    # Versão mínima do PowerShell
    PowerShellVersion = '5.1'
    
    # Funções exportadas pelo módulo
    FunctionsToExport = @('Import-Env')
    
    # Cmdlets exportados
    CmdletsToExport = @()
    
    # Variáveis exportadas
    VariablesToExport = @()
    
    # Aliases exportados
    AliasesToExport = @('Load-Env')
    
    # Arquivos associados ao módulo
    FileList = @('dotenv.psm1', 'dotenv.psd1')
    
    # Tags para pesquisa no PowerShell Gallery
    PrivateData = @{
        PSData = @{
            # Tags aplicadas ao módulo
            Tags = @('environment', 'dotenv', 'env', 'configuration', 'settings', 'variables')
            
            # URL da licença
            # LicenseUri = 'https://github.com/seu-usuario/dotenv-ps/blob/main/LICENSE'
            
            # URL do projeto
            # ProjectUri = 'https://github.com/seu-usuario/dotenv-ps'
            
            # URL do ícone
            # IconUri = ''
            
            # Notas de release
            ReleaseNotes = @'
# v1.0.0
- Initial release
- Support for .env file parsing
- Comments support (lines starting with #)
- Quoted values support (single and double quotes)
- Variable expansion from existing environment variables
- Multiple scope support (Process, User, Machine)
- Override option for existing variables
- PassThru option to return loaded variables
- Verbose logging support
'@
            
            # Pré-release tag
            # Prerelease = 'beta'
            
            # Flag indicando se requer aceitação de licença
            # RequireLicenseAcceptance = $false
            
            # URI de suporte externo
            # ExternalModuleDependencies = @()
        }
    }
    
    # URI do help online
    # HelpInfoURI = 'https://github.com/seu-usuario/dotenv-ps/wiki'
}