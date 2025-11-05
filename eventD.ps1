# EventID - Coleta informações dos eventos do windows

# Tempo de execução Inicio
Measure-TimeStart

# Importa os módulos necessários
Import-Module dotenv
Import-Module eventviewer

# Arquivo de configuração
Import-Env .\modules\db.mysql\.env -Override

Get-WindowsEvents -EventIDs 4722