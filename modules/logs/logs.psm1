#? Module para funções relacionadas a eventos do Windows e Logs em geral
#? Contém funções para coletar, processar e enviar eventos para MySQL e Zabbix

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

#? Função para coleta eventos do Windows ----------------------------------------------------
function Get-WindowsEvents { 
    param (
        [string]$ComputerName = $env:COMPUTERNAME,
        [int]$Days = 1,
        [string[]]$EventIDs = @(4720),
        [string[]]$LogNames = @('Security')
    )
    
    $StartDate = (Get-Date).AddDays(-$Days)
    $AllResults = @()
    
    Write-Host "Coletando eventos $($EventIDs -join ', ') dos logs $($LogNames -join ', ') dos últimos $Days dias em $ComputerName..." -ForegroundColor Cyan
    
    try {
        foreach ($LogName in $LogNames) {
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
            
            $Results = foreach ($Event in $Events) {
                $EventXML = [xml]$Event.ToXml()
                $EventData = $EventXML.Event.EventData.Data
                
                $EventObject = [PSCustomObject]@{
                    TimeCreated = $Event.TimeCreated
                    EventID = $Event.Id
                    LogName = $Event.LogName
                    EventDescription = $Event.Message.Split([Environment]::NewLine)[0]
                    TargetUserName = [string]::Empty
                    TargetDomain = [string]::Empty
                    SubjectUserName = [string]::Empty
                    SubjectLogonId = [string]::Empty
                    Computer = $Event.MachineName
                    EventDataJSON = [string]::Empty
                    EventHash = [string]::Empty
                    WorkstationName = [string]::Empty
                    IpAddress = [string]::Empty
                }
                
                try {
                    $EventDataDict = @{}
                    foreach ($Data in $EventData) {
                        if ($Data.Name) {
                            $EventDataDict[$Data.Name] = $Data.'#text'
                        }
                    }

                    switch ($Event.Id) {
                        4720 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                        }
                        4625 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                        }
                        1102 {
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                        }
                        4624 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                            $EventObject.WorkstationName = if ($EventDataDict.ContainsKey('WorkstationName')) { $EventDataDict['WorkstationName'] } else { '' }
                            $EventObject.IpAddress = if ($EventDataDict.ContainsKey('IpAddress')) { $EventDataDict['IpAddress'] } else { '' }
                        }
                        
                    }

                    $EventObject.EventDataJSON = ($EventDataDict | ConvertTo-Json -Compress)
                    
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


#? Função para verificar se os itens ja foram enviados ---------------------------------------------
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
function Get-WindowsEvents2 {
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

#? Medidor de Tempo de execução -------------------------------------------
function Measure-TimeStart {
    # Define a variável como global para ser acessada em outra função
    $global:startTime = Get-Date
}

function Measure-TimeStop {
    param (
        [string]$ScriptName
    )

    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.2\MySql.Data.dll"

    if ($global:startTime -eq $null) {
        Write-Host "Erro: Measure-TimeStart ainda não foi chamado!" -ForegroundColor Red
        return
    }

    $endTime = Get-Date
    $executionTime = $endTime - $global:startTime

    # Formatar datas para MySQL
    $formattedStart = $global:startTime.ToString("yyyy-MM-dd HH:mm:ss")
    $formattedEnd = $endTime.ToString("yyyy-MM-dd HH:mm:ss")
    $formattedExecutionTime = "{0:D2}:{1:D2}:{2:D2}" -f $executionTime.Hours, $executionTime.Minutes, $executionTime.Seconds

    # Conectar ao MySQL
    $mysqlConn = New-Object MySql.Data.MySqlClient.MySqlConnection
    $mysqlConn.ConnectionString = "Server=$Env:DB_SERVER; Database=hub; Uid=$Env:DB_USER; Pwd=$Env:DB_PASSWD;"

    try {
        $mysqlConn.Open()

        # Query de inserção
        $query = "INSERT INTO execution_logs_time (script_name, execution_time, start_time, end_time) VALUES ('{0}', '{1}', '{2}', '{3}')"
        $query = $query -f $ScriptName, $formattedExecutionTime, $formattedStart, $formattedEnd

        $mysqlCmd = $mysqlConn.CreateCommand()
        $mysqlCmd.CommandText = $query

        $result = $mysqlCmd.ExecuteNonQuery()
        Write-Host "Tempo de execução registrado no banco para '$ScriptName'." -ForegroundColor Green

    } catch {
        Write-Host "Erro ao registrar tempo no banco: $_" -ForegroundColor Red
    } finally {
        if ($mysqlConn.State -eq [System.Data.ConnectionState]::Open) {
            $mysqlConn.Close()
        }
        $global:startTime = $null # Resetar para evitar problemas em execuções futuras
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

    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.2\MySql.Data.dll"
    $mysqlConn = New-Object MySql.Data.MySqlClient.MySqlConnection
    $mysqlConn.ConnectionString = "Server=$Env:DB_SERVER; Database=$Env:DB_BASE; Uid=$Env:DB_USER; Pwd=$Env:DB_PASSWD;"
    
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
