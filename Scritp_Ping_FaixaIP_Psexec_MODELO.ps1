# =========================== DOCUMENTAÇÃO ===========================
# Script para Ping em Faixa de IP e Execução Remota
# Este script solicita ao usuário, por meio de uma interface gráfica, uma faixa de IP.
# Realiza ping em cada IP dentro da faixa e, se o ping for bem-sucedido, executa
# o comando de desligamento remoto via `psexec.exe`.
# Todos os resultados, de sucesso ou falha, são registrados em um arquivo de log.
# ====================================================================

# =========================== CONFIGURAÇÕES ===========================
# Caminho para o arquivo de log
$LogPath = "\\servk\servdisco\ping\PingLog.log"

# Caminho para o `psexec.exe`
$PsExecPath = "C:\PsTools\psexec.exe"

# Comando de desligamento remoto
$ShutdownCommand = "cmd /c shutdown -s -t 0"

# ====================================================================

# =========================== FUNÇÃO PARA LOG =========================
Function Write-Log {
    param (
        [string]$Message
    )
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $LogEntry = "$Timestamp - $Message"
    Write-Output $LogEntry | Out-File -FilePath $LogPath -Append -Encoding utf8
}

# =========================== GUI PARA INPUT ==========================
Add-Type -AssemblyName Microsoft.VisualBasic
$StartIP = [Microsoft.VisualBasic.Interaction]::InputBox("Digite o IP inicial da faixa:", "IP Inicial")
$EndIP = [Microsoft.VisualBasic.Interaction]::InputBox("Digite o IP final da faixa:", "IP Final")

if (-not $StartIP -or -not $EndIP) {
    Write-Host "Faixa de IP não informada. O script será encerrado."
    exit 1
}

# ===================== FUNÇÃO PARA GERAR FAIXA =======================
Function Generate-IPRange {
    param (
        [string]$StartIP,
        [string]$EndIP
    )
    $StartParts = $StartIP.Split('.')
    $EndParts = $EndIP.Split('.')

    if ($StartParts.Count -ne 4 -or $EndParts.Count -ne 4) {
        throw "Formato de IP inválido. Insira endereços no formato xxx.xxx.xxx.xxx."
    }

    $Start = [int]::Parse($StartParts[3])
    $End = [int]::Parse($EndParts[3])

    if ($Start -gt $End) {
        throw "O IP inicial deve ser menor ou igual ao IP final."
    }

    $IPRange = @()
    for ($i = $Start; $i -le $End; $i++) {
        $IPRange += "$($StartParts[0]).$($StartParts[1]).$($StartParts[2]).$i"
    }
    return $IPRange
}

# ======================== EXECUÇÃO PRINCIPAL =========================
try {
    # Criar o arquivo de log se não existir
    if (-not (Test-Path $LogPath)) {
        "Data e Hora - Mensagem" | Out-File -FilePath $LogPath -Encoding utf8
    }

    Write-Log -Message "Início do script para ping em faixa de IP."

    # Gerar a faixa de IPs
    $IPRange = Generate-IPRange -StartIP $StartIP -EndIP $EndIP

    # Loop para cada IP na faixa
    foreach ($IP in $IPRange) {
        Write-Log -Message "Iniciando ping no IP $IP."
        $PingResult = Test-Connection -ComputerName $IP -Count 1 -Quiet

        if ($PingResult) {
            Write-Log -Message "Ping bem-sucedido no IP $IP. Executando comando de desligamento."
            try {
                Start-Process -FilePath $PsExecPath -ArgumentList "\\\\$IP $ShutdownCommand" -NoNewWindow -Wait -ErrorAction Stop
                Write-Log -Message "Comando de desligamento executado com sucesso no IP $IP."
            } catch {
                Write-Log -Message "Falha ao executar o comando de desligamento no IP $IP: $_"
            }
        } else {
            Write-Log -Message "Ping falhou no IP $IP."
        }
    }

} catch {
    # Registrar erros no log
    Write-Log -Message "Erro no script: $_"
} finally {
    Write-Log -Message "Fim do script para ping em faixa de IP."
}
