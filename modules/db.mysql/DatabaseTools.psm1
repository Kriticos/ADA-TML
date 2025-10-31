<#
.SYNOPSIS
    Módulo para interagir com o banco de dados SQL Server e MySQL.

.DESCRIPTION
    Este módulo fornece funções para conexão, execução de consultas
    e inserção de dados em tabelas no SQL Server. Pode ser usado
    em conjunto com outros módulos de coleta de eventos.

.NOTES
    Autor: Kriticos
    Data: 2024-09-10
    Versão: 1.12.0
#>

# =====================================================================
# Dependências
# =====================================================================

# Carrega o módulo Import-Env (precisa estar disponível no PSModulePath ou em caminho conhecido)
if (-not (Get-Module -Name Import-Env -ListAvailable)) {
    throw "O módulo 'Import-Env' é necessário e não está instalado ou acessível."
}

# Importa o módulo Import-Env forçadamente
Import-Module Import-Env -Force

# Carrega as variáveis de ambiente automaticamente ao importar este módulo
$envPath = Join-Path $PSScriptRoot '.env'
if (Test-Path $envPath) {
    Import-Env -envPath $envPath
} else {
    Write-Host "⚠️ Arquivo .env não encontrado: $envPath" -ForegroundColor Yellow
}

# =====================================================================
# Funções auxiliares
# =====================================================================

function Find-Null {
    <#
    .SYNOPSIS
        Verifica se o DataSet contém tabelas.
    .DESCRIPTION
        Retorna as tabelas do DataSet quando existem registros,
        caso contrário exibe uma mensagem e encerra a execução.
    .PARAMETER data
        Objeto DataSet retornado de uma consulta SQL.
    .EXAMPLE
        $resultado = Find-Null $dataset
    #>
    param (
        $data
    )
    [array]$check = $data.Tables
    $check.count | Out-Null
    if ($check.count -gt 0) {
        return $data.Tables
    } else {
        Write-Host "Empty table"
        exit
    }
}

# =====================================================================
# Funções principais (SQL Server)
# =====================================================================

function Get-UserSQL {
    <#
    .SYNOPSIS
        Retorna todos os usuários da base Questor_AD.
    .DESCRIPTION
        Executa um SELECT na view definida pela variável de ambiente SQL_VIEW_USERS.
    .EXAMPLE
        Get-UserSQL
    #>
    $sqlConn = New-Object System.Data.SqlClient.SqlConnection
    $sqlConn.ConnectionString = "Server=$Env:SQL_SERVER; Database=$Env:SQL_BASE; Uid=$Env:SQL_USER; Pwd=$Env:SQL_PASSWD;"
    $sqlConn.Open()

    $sqlcmd = $sqlConn.CreateCommand()
    $sqlcmd.CommandText = "SELECT * FROM $Env:SQL_VIEW_USERS;"

    $adp = New-Object System.Data.SqlClient.SqlDataAdapter($sqlcmd)
    $data = New-Object System.Data.DataSet
    $adp.Fill($data) | Out-Null

    $sqlConn.Close()
    Find-Null $data
}

function Get-ActivedUserSQL {
    <#
    .SYNOPSIS
        Retorna usuários ativos ou desativados do Questor_AD.
    .DESCRIPTION
        Seleciona os usuários a partir das views configuradas via variáveis
        de ambiente SQL_VIEW_USERS_ATIVOS ou SQL_VIEW_USERS_DEMITIDOS.
    .PARAMETER Actived
        Define a view de usuários ativos.
    .PARAMETER Deactived
        Define a view de usuários demitidos.
    .EXAMPLE
        Get-ActivedUserSQL -Actived
    .EXAMPLE
        Get-ActivedUserSQL -Deactived
    #>
    param(
        [switch]$Actived,
        [switch]$Deactived
    )

    # Define a view de acordo com o parâmetro
    if ($Actived) {
        $view = $Env:SQL_VIEW_USERS_ATIVOS
    }
    elseif ($Deactived) {
        $view = $Env:SQL_VIEW_USERS_DEMITIDOS
    }
    else {
        throw "É necessário especificar -Actived ou -Deactived"
    }
    
    $sqlConn = New-Object System.Data.SqlClient.SqlConnection
    $sqlConn.ConnectionString = "Server=$Env:SQL_SERVER; Database=$Env:SQL_BASE; Uid=$Env:SQL_USER; Pwd=$Env:SQL_PASSWD;"
    $sqlConn.Open()

    $sqlcmd = $sqlConn.CreateCommand()
    $sqlcmd.CommandText = "SELECT * FROM $view;"

    $adp = New-Object System.Data.SqlClient.SqlDataAdapter($sqlcmd)
    $data = New-Object System.Data.DataSet
    $adp.Fill($data) | Out-Null

    $sqlConn.Close()
    Find-Null $data
}

# =====================================================================
# Exporta funções públicas
# =====================================================================
Export-ModuleMember -Function Get-UserSQL, Get-ActivedUserSQL