<#
.SYNOPSIS
    Módulo para interagir com o banco de dados MySQL.

.DESCRIPTION
    Este módulo fornece funções para conexão, execução de consultas
    e manipulação de dados em bancos de dados MySQL. Pode ser usado
    em conjunto com outros módulos de coleta de eventos.

.NOTES
    Autor: Kriticos
    Data: 2024-09-10
    Versão: 1.12.0
#>

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

#? Função para verificar se os itens ja foram enviados ---------------------------------------------
function Test-RecordExists {
    param (
        [DateTime]$TimeCreated,
        [string]$TargetUserName,
        [string]$SubjectUserName,
        [string]$EventDescription,
        [string]$DataBase
    )
    
    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.5\MySql.Data.dll"

    $mysqlConn = New-Object MySql.Data.MySqlClient.MySqlConnection
    $mysqlConn.ConnectionString = "Server=$Env:MYSQL_SERVER; Database=$Env:MYSQL_DATABASE; Uid=$Env:MYSQL_USER; Pwd=$Env:MYSQL_PASSWORD;"
    
    try {
        $mysqlConn.Open()
        
        $formattedTime = $TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        
        # Query corrigida com backticks para nome de tabela
        $query = "SELECT COUNT(*) FROM `{0}` WHERE time_created = '{1}' AND target_username = '{2}' AND subject_username = '{3}' AND event_description = '{4}'"
        $query = $query -f $DataBase, $formattedTime, $TargetUserName.Replace("'", "''"), $SubjectUserName.Replace("'", "''"), $EventDescription.Replace("'", "''")
        
        $mysqlCmd = $mysqlConn.CreateCommand()
        $mysqlCmd.CommandText = $query
        
        $result = $mysqlCmd.ExecuteScalar()
        return ([int]$result -gt 0)
        
    } catch {
        Write-Host "Erro ao verificar registro: $_" -ForegroundColor Red
        return $false
    } finally {
        if ($mysqlConn.State -eq [System.Data.ConnectionState]::Open) {
            $mysqlConn.Close()
        }
    }
}

#? Função para inserir novo registro no banco -------------------------------------
function Add-AdUserRecord {
    param (
        [DateTime]$TimeCreated,
        [string]$TargetUserName,
        [string]$SubjectUserName,
        [int]$EventID,
        [string]$EventDescription,
        [string]$DataBase
    )
    
    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.5\MySql.Data.dll"

    $mysqlConn = New-Object MySql.Data.MySqlClient.MySqlConnection
    $mysqlConn.ConnectionString = "Server=$Env:MYSQL_SERVER; Database=$Env:MYSQL_DATABASE; Uid=$Env:MYSQL_USER; Pwd=$Env:MYSQL_PASSWORD;"
    
    try {
        $mysqlConn.Open()
        
        $formattedTime = $TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")
        
        # Query corrigida com backticks para nome de tabela
        $query = "INSERT INTO `{0}` (time_created, target_username, subject_username, event_id, event_description) VALUES ('{1}', '{2}', '{3}', {4}, '{5}')"
        $query = $query -f $DataBase, $formattedTime, $TargetUserName.Replace("'", "''"), $SubjectUserName.Replace("'", "''"), $EventID, $EventDescription.Replace("'", "''")
        
        $mysqlCmd = $mysqlConn.CreateCommand()
        $mysqlCmd.CommandText = $query
        
        $result = $mysqlCmd.ExecuteNonQuery()
        Write-Host "Registro inserido com sucesso: $TargetUserName" -ForegroundColor Green
        return $true
        
    } catch {
        Write-Host "Erro ao inserir registro: $_" -ForegroundColor Red
        return $false
    } finally {
        if ($mysqlConn.State -eq [System.Data.ConnectionState]::Open) {
            $mysqlConn.Close()
        }
    }
}

function Add-AdUserRecordFull {
    param (
        [DateTime]$TimeCreated,
        [string]$TargetUserName,
        [string]$SubjectUserName,
        [int]$EventID,
        [string]$EventDescription,
        [string]$WorkstationName = '',
        [string]$IpAddress = '',
        [string]$DataBase
    )

    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.5\MySql.Data.dll"
    $mysqlConn = New-Object MySql.Data.MySqlClient.MySqlConnection
    $mysqlConn.ConnectionString = "Server=$Env:MYSQL_SERVER; Database=$Env:MYSQL_DATABASE; Uid=$Env:MYSQL_USER; Pwd=$Env:MYSQL_PASSWORD;"
    
    try {
        $mysqlConn.Open()
        $formattedTime = $TimeCreated.ToString("yyyy-MM-dd HH:mm:ss")

        $query = "INSERT INTO `{0}` (time_created, target_username, subject_username, workstationName, ipaddress, event_id, event_description) VALUES ('{1}', '{2}', '{3}', '{4}', '{5}', {6}, '{7}')"
        $query = $query -f $DataBase, 
            $formattedTime, 
            $TargetUserName.Replace("'", "''"), 
            $SubjectUserName.Replace("'", "''"), 
            $WorkstationName.Replace("'", "''"), 
            $IpAddress.Replace("'", "''"), 
            $EventID, 
            $EventDescription.Replace("'", "''")

        $mysqlCmd = $mysqlConn.CreateCommand()
        $mysqlCmd.CommandText = $query
        $mysqlCmd.ExecuteNonQuery()
        Write-Host "Registro inserido com sucesso: $TargetUserName" -ForegroundColor Green
        return $true

    } catch {
        Write-Host "Erro ao inserir registro: $_" -ForegroundColor Red
        return $false
    } finally {
        if ($mysqlConn.State -eq [System.Data.ConnectionState]::Open) {
            $mysqlConn.Close()
        }
    }
}