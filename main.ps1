# main.ps1
Write-Host "🔧 Inicializando ADA-Logs..." -ForegroundColor Cyan

# Define o caminho base
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ModulesPath = Join-Path $ScriptRoot "modules"

# Carrega módulos dinamicamente
Get-ChildItem -Path $ModulesPath -Directory | ForEach-Object {
    $module = Join-Path $_.FullName "$($_.Name).psm1"
    if (Test-Path $module) {
        Write-Host "→ Carregando módulo $($_.Name)" -ForegroundColor Yellow
        Import-Module $module -Force -ErrorAction Stop
    }
}

Import-Env .\.env

Write-Host "✅ Todos os módulos carregados com sucesso!" -ForegroundColor Green

# Alterado para usar horas em vez de dias
$hours = 1

Write-Host "Coletando eventos $env:EVENTID_4624 dos logs $env:LOG_NAME_SECURITY da última $hours hora em $env:ZABBIX_HOST..."

# Define o horário de início (1 hora atrás)
$startTime = (Get-Date).AddHours(-$hours)

# Coleta os eventos dos últimos dias (mantido para compatibilidade com Get-WindowsEvents)
$days = 1
$eventos = Get-WindowsEvents -ComputerName $env:ZABBIX_HOST -Days $days -EventIDs $env:EVENTID_4624 -LogNames $env:LOG_NAME_SECURITY | 
    # Filtra apenas eventos da última hora
    Where-Object { $_.TimeCreated -ge $startTime } | Select-Object TimeCreated, EventID, EventDescription, 
    @{Name="TargetUserName"; Expression={($_.EventDataJSON | ConvertFrom-Json).TargetUserName}},
    @{Name="WorkstationName"; Expression={($_.EventDataJSON | ConvertFrom-Json).WorkstationName}},
    @{Name="IpAddress"; Expression={($_.EventDataJSON | ConvertFrom-Json).IpAddress}}, 
    @{Name="SubjectUserName"; Expression={"Sistema"}} # Adicionando um valor padrão para SubjectUserName

# Exibe informação sobre quantos eventos foram encontrados
Write-Host "Encontrados $($eventos.Count) eventos no log $env:LOG_NAME_SECURITY da última hora."

# Processa cada evento
foreach ($evento in $eventos) {
    $timeStamp = Get-Date $evento.TimeCreated -Format "yyyy-MM-dd HH:mm:ss"
    
    # Verificamos se o registro já existe - ADICIONADO PARÂMETRO DataBase
    if (-not (Test-RecordExists -DataBase $env:TAB_4624 -TimeCreated $evento.TimeCreated -TargetUserName $evento.TargetUserName -SubjectUserName $evento.SubjectUserName -EventDescription $evento.EventDescription)) {
        # Insere o registro no banco de dados - ADICIONADO PARÂMETRO DataBase
        $inserted = Add-AdUserRecordFull `
            -DataBase $env:TAB_4624 `
            -TimeCreated $evento.TimeCreated `
            -TargetUserName $evento.TargetUserName `
            -SubjectUserName $evento.SubjectUserName `
            -EventID $evento.EventID `
            -EventDescription $evento.EventDescription `
            -IpAddress $evento.IpAddress `
            -WorkstationName $evento.WorkstationName
    }
    else {
        #Write-Host "Registro já existe: $($evento.TargetUserName) foi conectada com sucesso em $timeStamp" -ForegroundColor Yellow
    }
}

# Tempo de execução
Measure-TimeStop -ScriptName "zbx_win_event"