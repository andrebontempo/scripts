# =========================== DOCUMENTAÇÃO ===========================
# Script para Ping em Faixa de IP e Execução Remota
# Este script solicita ao usuário uma faixa de IP através de uma interface gráfica.
# Realiza ping em cada IP dentro da faixa e, se o ping for bem-sucedido, executa
# o comando de desligamento remoto via `psexec.exe`.
# Adicionada máscara para garantir que o IP inserido esteja no formato correto.
# ====================================================================

# =========================== CONFIGURAÇÕES ===========================
# Caminho para o arquivo de log
$LogPath = "\\\\servk\\servdisco\\ping\\PingLog.log"

# Caminho para o `psexec.exe`
$PsExecPath = "C:\\Path\\To\\psexec.exe"

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

# =========================== GUI COM MÁSCARA =========================
Add-Type -AssemblyName System.Windows.Forms

Function Show-IPInputDialog {
    param (
        [string]$Message,
        [string]$Title
    )
    
    $Form = New-Object System.Windows.Forms.Form
    $Form.Text = $Title
    $Form.Size = New-Object System.Drawing.Size(300, 150)
    $Form.StartPosition = "CenterScreen"

    $Label = New-Object System.Windows.Forms.Label
    $Label.Text = $Message
    $Label.Location = New-Object System.Drawing.Point(10, 10)
    $Label.Size = New-Object System.Drawing.Size(260, 20)
    $Form.Controls.Add($Label)

    $TextBox = New-Object System.Windows.Forms.MaskedTextBox
    $TextBox.Mask = "000.000.000.000"
    $TextBox.Location = New-Object System.Drawing.Point(10, 40)
    $TextBox.Size = New-Object System.Drawing.Size(260, 20)
    $Form.Controls.Add($TextBox)

    $ButtonOK = New-Object System.Windows.Forms.Button
    $ButtonOK.Text = "OK"
    $ButtonOK.Location = New-Object System.Drawing.Point(50, 70)
    $ButtonOK.Add_Click({
        if ($TextBox.Text -match "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$") {
            $Form.Tag = $TextBox.Text
            $Form.Close()
        } else {
            [System.Windows.Forms.MessageBox]::Show("Por favor, insira um endereço IP válido.", "Erro", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })
    $Form.Controls.Add($ButtonOK)

    $ButtonCancel = New-Object System.Windows.Forms.Button
    $ButtonCancel.Text = "Cancelar"
    $ButtonCancel.Location = New-Object System.Drawing.Point(150, 70)
    $ButtonCancel.Add_Click({
        $Form.Close()
    })
    $Form.Controls.Add($ButtonCancel)

    $Form.ShowDialog()
    return $Form.Tag
}

# Solicitar faixa de IPs
$StartIP = Show-IPInputDialog -Message "Digite o IP inicial da faixa:" -Title "IP Inicial"
$EndIP = Show-IPInputDialog -Message "Digite o IP final da faixa:" -Title "IP Final"

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
