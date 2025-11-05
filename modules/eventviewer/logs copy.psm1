# Module para funções relacionadas a eventos do Windows
# Contém funções para coletar, processar e enviar eventos para MySQL e Zabbix

#!############################################################################################
#!                                    .env
#!############################################################################################
# Importa o módulo PSdotenv (necessário para Set-DotEnv funcionar)
if (-not (Get-Module -Name PSdotenv)) {
    try {
        Import-Module PSdotenv -ErrorAction Stop
    }
    catch {
        Write-Host "Erro ao importar o módulo PSdotenv. Verifique se ele está instalado."
        exit
    }
}

# Caminho absoluto para o .env
$envPath = (Join-Path $PSScriptRoot ".env")

# Verificar se o arquivo .env existe
if (Test-Path $envPath) {
    # Carregar as variáveis do .env
    $dotenv = Get-Content -Path $envPath | Where-Object { $_ -match '^\w+=' }
    foreach ($line in $dotenv) {
        $key, $value = $line -split '=', 2
        [Environment]::SetEnvironmentVariable($key.Trim(), $value.Trim(), 'Process')
    }
    Write-Host "Arquivo .env carregado de: $envPath"
} else {
    Write-Host "Arquivo .env não encontrado em: $envPath"
}
#!###########################################################################################

# Função para criar um hash MD5 de string
function Get-StringHash {
    param (
        [Parameter(Mandatory=$true)]
        [string]$String
    )
    
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hashBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))
    $md5.Dispose()
    
    return [BitConverter]::ToString($hashBytes).Replace("-", "").ToLower()
}

# Função para enviar dados para o Zabbix usando zabbix_sender
# Comentada conforme solicitado - será implementada de outra forma
<#
function Send-ZabbixData {
    # Função removida conforme solicitação
}
#>

# Função para coletar eventos do Windows
function Get-WindowsEvents {
    param (
        [string]$ComputerName = $env:COMPUTERNAME,
        [int]$Days = 7,
        [string[]]$EventIDs = @(4720),
        [string[]]$LogNames = @('Security')
    )
    
    $StartDate = (Get-Date).AddDays(-$Days)
    $AllResults = @()
    
    Write-Host "Coletando eventos $($EventIDs -join ', ') dos logs $($LogNames -join ', ') dos últimos $Days dias em $ComputerName..." -ForegroundColor Cyan
    
    try {
        # Para cada log especificado
        foreach ($LogName in $LogNames) {
            # Consultar os eventos com os IDs especificados
            $Events = Get-WinEvent -FilterHashtable @{
                LogName = $LogName
                ID = $EventIDs
                StartTime = $StartDate
            } -ComputerName $ComputerName -ErrorAction SilentlyContinue
            
            if ($Events.Count -eq 0) {
                Write-Host "Nenhum evento encontrado para o log $LogName no período especificado." -ForegroundColor Yellow
                continue
            }
            
            Write-Host "Encontrados $($Events.Count) eventos no log $LogName." -ForegroundColor Green
            
            # Processar os eventos para extrair informações relevantes
            $Results = foreach ($Event in $Events) {
                $EventXML = [xml]$Event.ToXml()
                $EventData = $EventXML.Event.EventData.Data
                
                # Criar um objeto básico com campos comuns
                $EventObject = [PSCustomObject]@{
                    TimeCreated = $Event.TimeCreated
                    EventID = $Event.Id
                    LogName = $Event.LogName
                    EventDescription = $Event.Message.Split([Environment]::NewLine)[0] # Primeira linha como descrição
                    TargetUserName = [string]::Empty
                    TargetDomain = [string]::Empty
                    SubjectUserName = [string]::Empty
                    SubjectLogonId = [string]::Empty
                    Computer = $Event.MachineName
                    EventDataJSON = [string]::Empty
                    EventHash = [string]::Empty
                }
                
                # Extrair dados específicos com base no tipo de evento
                try {
                    # Converter EventData para formato JSON
                    $EventDataDict = @{}
                    foreach ($Data in $EventData) {
                        if ($Data.Name) {
                            $EventDataDict[$Data.Name] = $Data.'#text'
                        }
                    }
                    
                    # Para eventos específicos, mapear campos conhecidos
                    if ($Event.Id -eq 4720) {
                        $EventObject.TargetUserName = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'TargetUserName' })) { ($EventData | Where-Object { $_.Name -eq 'TargetUserName' }).'#text' } else { [string]::Empty }
                        $EventObject.TargetDomain = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'TargetDomain' })) { ($EventData | Where-Object { $_.Name -eq 'TargetDomain' }).'#text' } else { [string]::Empty }
                        $EventObject.SubjectUserName = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'SubjectUserName' })) { ($EventData | Where-Object { $_.Name -eq 'SubjectUserName' }).'#text' } else { [string]::Empty }
                        $EventObject.SubjectLogonId = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'SubjectLogonId' })) { ($EventData | Where-Object { $_.Name -eq 'SubjectLogonId' }).'#text' } else { [string]::Empty }
                    }
                    elseif ($Event.Id -eq 4625) { # Falha de logon
                        $EventObject.TargetUserName = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'TargetUserName' })) { ($EventData | Where-Object { $_.Name -eq 'TargetUserName' }).'#text' } else { [string]::Empty }
                        $EventObject.TargetDomain = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'TargetDomain' })) { ($EventData | Where-Object { $_.Name -eq 'TargetDomain' }).'#text' } else { [string]::Empty }
                        $EventObject.SubjectUserName = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'SubjectUserName' })) { ($EventData | Where-Object { $_.Name -eq 'SubjectUserName' }).'#text' } else { [string]::Empty }
                    }
                    elseif ($Event.Id -eq 1102) { # Limpeza de log de auditoria
                        $EventObject.SubjectUserName = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'SubjectUserName' })) { ($EventData | Where-Object { $_.Name -eq 'SubjectUserName' }).'#text' } else { [string]::Empty }
                        $EventObject.SubjectLogonId = if ($null -ne ($EventData | Where-Object { $_.Name -eq 'SubjectLogonId' })) { ($EventData | Where-Object { $_.Name -eq 'SubjectLogonId' }).'#text' } else { [string]::Empty }
                    }
                    
                    # Armazenar todos os dados do evento em JSON para campos não mapeados
                    $EventObject.EventDataJSON = ($EventDataDict | ConvertTo-Json -Compress)
                    
                    # Criar um hash único para o evento combinando campos chave
                    $hashString = "$($EventObject.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss.fff'))_$($EventObject.EventID)_$($EventObject.LogName)_$($EventObject.Computer)_$($EventObject.TargetUserName)_$($EventObject.SubjectUserName)"
                    $EventObject.EventHash = Get-StringHash -String $hashString
                }
                catch {
                    Write-Host "Erro ao processar dados do evento $($Event.Id): $_" -ForegroundColor Yellow
                }
                
                $EventObject
            }
            
            $AllResults += $Results
        }
        
        return $AllResults
    }
    catch {
        Write-Host "Erro ao coletar eventos: $_" -ForegroundColor Red
        
        if ($_.Exception.Message -like "*não foi encontrado*") {
            Write-Host "Verifique se o log está habilitado e se você tem permissões para acessá-lo." -ForegroundColor Yellow
        }
        
        return @()
    }
}

# Função para exportar eventos para CSV
function Export-EventsToCsv {
    param (
        [Parameter(Mandatory=$true)]
        [PSCustomObject[]]$Events,
        [string]$OutputPath
    )
    
    if ($Events.Count -gt 0) {
        # Exportar para CSV
        $Events | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Os resultados foram exportados para: $OutputPath" -ForegroundColor Green
        
        # Exibir um resumo dos resultados
        $Events | Group-Object EventID, LogName | 
            Select-Object Count, Name | 
            Sort-Object -Property Name | 
            Format-Table -AutoSize
        
        return $true
    }
    else {
        Write-Host "Nenhum evento para exportar." -ForegroundColor Yellow
        return $false
    }
}

function Test-RecordExists {
    param (
        [DateTime]$TimeCreated,
        [string]$TargetUserName,
        [string]$SubjectUserName,
        [string]$EventDescription,
        [string]$DataBase
    )
    
    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.2\MySql.Data.dll"

    $mysqlConn = New-Object MySql.Data.MySqlClient.MySqlConnection
    $mysqlConn.ConnectionString = "Server=$Env:DB_SERVER; Database=$Env:DB_BASE; Uid=$Env:DB_USER; Pwd=$Env:DB_PASSWD;"
    
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

# Função para inserir novo registro no banco
function Add-AdUserRecord {
    param (
        [DateTime]$TimeCreated,
        [string]$TargetUserName,
        [string]$SubjectUserName,
        [int]$EventID,
        [string]$EventDescription,
        [string]$DataBase
    )
    
    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.2\MySql.Data.dll"

    $mysqlConn = New-Object MySql.Data.MySqlClient.MySqlConnection
    $mysqlConn.ConnectionString = "Server=$Env:DB_SERVER; Database=$Env:DB_BASE; Uid=$Env:DB_USER; Pwd=$Env:DB_PASSWD;"
    
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