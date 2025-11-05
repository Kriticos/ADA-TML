#? Module para funções relacionadas a eventos do Windows e Logs em geral
#? Contém funções para coletar, processar e enviar eventos para MySQL e Zabbix

#? Função para coleta eventos do Windows ----------------------------------------------------
function Get-WindowsEvents { 
    param (
        [string]$ComputerName = $env:COMPUTERNAME,
        [int]$Days = 1,
        [string[]]$EventIDs = @(),
        [string[]]$LogNames = @('Security')
    )
    
    $StartDate = (Get-Date).AddDays(-$Days)
    $AllResults = @()
    
    Write-Host "Coletando eventos $($EventIDs -join ', ') dos logs $($LogNames -join ', ') dos últimos $Days dias em $ComputerName..." -ForegroundColor Cyan
    
    try {
        foreach ($LogName in $LogNames) {
            $Events = if ($ComputerName -ne $env:COMPUTERNAME) {
                Get-WinEvent -FilterHashtable @{
                    LogName = $LogName
                    ID = $EventIDs
                    StartTime = $StartDate
                } -ComputerName $ComputerName -ErrorAction SilentlyContinue
            } else {
                Get-WinEvent -FilterHashtable @{
                    LogName = $LogName
                    ID = $EventIDs
                    StartTime = $StartDate
                } -ErrorAction SilentlyContinue
            }
            
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
                        # Usuario conectado com sucesso
                        4624 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                            $EventObject.WorkstationName = if ($EventDataDict.ContainsKey('WorkstationName')) { $EventDataDict['WorkstationName'] } else { '' }
                            $EventObject.IpAddress = if ($EventDataDict.ContainsKey('IpAddress')) { $EventDataDict['IpAddress'] } else { '' }
                        }
                        # Falha de logon
                        4625 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                        }
                        # Criação de novo usuário
                        4720 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                        }
                        # Habilitação de conta de usuário
                         4722 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                        }
                        # Troca de senha de usuário
                        4723 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                        }
                        # Redefinição de senha de usuário
                        4724 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                        }
                        4725 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                        }
                        4726 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
                        }
                        4743 {
                            $EventObject.TargetUserName = $EventDataDict['TargetUserName']
                            $EventObject.TargetDomain = $EventDataDict['TargetDomain']
                            $EventObject.SubjectUserName = $EventDataDict['SubjectUserName']
                            $EventObject.SubjectLogonId = $EventDataDict['SubjectLogonId']
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




