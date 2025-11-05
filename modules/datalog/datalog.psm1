#? Medidor de Tempo de execução -------------------------------------------
function Measure-TimeStart {
    # Define a variável como global para ser acessada em outra função
    $global:startTime = Get-Date
}

function Measure-TimeStop {
    param (
        [string]$ScriptName
    )

    Add-Type -Path "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.5\MySql.Data.dll"

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