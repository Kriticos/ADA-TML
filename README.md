# PWS - ADA TLM

## Estrutra de pastas

ADA-Logs
│
├── modules/
│   ├── datalog/       → módulo de logging interno (Write-Log, níveis, etc.)
│   ├── db.firebird/   → funções de conexão e query com Firebird
│   ├── db.mssql/      → funções de conexão e query com SQL Server
│   ├── db.mysql/      → funções de conexão e query com MySQL
│   ├── dotenv/        → leitor de variáveis de ambiente (.env)
│   ├── eventviewer/   → parser e coleta de eventos do Windows
│   └── zbx.sender/    → envio de métricas para Zabbix (via zabbix_sender)
│
├── sql/
│   ├── schema.sql     → estrutura do banco (CREATE TABLE etc.)
│   ├── inserts.sql    → inserts padrões (opcional)
│   ├── queries/       → consultas reutilizáveis
│   └── procedures/    → stored procedures ou views
│
├── main.ps1           → ponto de entrada do projeto
│
└── README.md          → documentação e instruções de uso