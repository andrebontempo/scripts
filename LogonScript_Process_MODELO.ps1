# =========================== DOCUMENTAÇÃO ===========================
# Script de Logon para Verificação de Processo
# Este script verifica se um processo específico está em execução em um sistema.
# Caso o processo não esteja rodando, ele executa um instalador específico
# localizado em um caminho de rede. Além disso, ele cria um arquivo de log
# detalhado com as informações da execução, incluindo o hostname da máquina.
# Também realiza a cópia de um diretório e seu conteúdo, verificando o sucesso da operação.
# Caso a cópia falhe, o script será encerrado.
# ====================================================================

# =========================== CONFIGURAÇÕES ===========================
# Nome do processo a ser verificado
$ProcessName = "xxxxx"

# Caminho do arquivo de instalação
$InstallPath = "C:\system32\Calc.exe"

# Caminhos para a cópia do diretório
$SourceDirectory = "\\servk\servdisco\symanteste\arquivos"
$DestinationDirectory = "C:\temp\"

# Caminho do arquivo de log
$LogPath = "C:\Logs\ProcessCheckLog.log"

# ====================================================================

# =========================== FUNÇÃO PARA LOG ==========================
Function Write-Log {
    param (
        [string]$Message
    )
    $Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $Hostname = $env:COMPUTERNAME
    $LogEntry = "$Timestamp - Hostname: $Hostname - $Message"
    Write-Output $LogEntry | Out-File -FilePath $LogPath -Append -Encoding utf8
}

# ======================== INÍCIO DO SCRIPT ===========================
try {
    # Verificar se o arquivo de log já existe. Caso contrário, criar o cabeçalho
    if (-not (Test-Path $LogPath)) {
        "Data e Hora - Hostname - Mensagem" | Out-File -FilePath $LogPath -Encoding utf8
    }

    Write-Log -Message "Início do script de verificação."

    # Verificar se o processo está em execução
    $Process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue

    if ($Process) {
        Write-Log -Message "O processo '$ProcessName' está rodando."
    } else {
        Write-Log -Message "O processo '$ProcessName' não está rodando."

        # Realizar a cópia do diretório antes da execução do instalador
        Write-Log -Message "Iniciando a cópia do diretório."
        try {
            if (-not (Test-Path $DestinationDirectory)) {
                New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
            }
            Copy-Item -Path $SourceDirectory -Destination $DestinationDirectory -Recurse -Force
            Write-Log -Message "Cópia do diretório de '$SourceDirectory' para '$DestinationDirectory' concluída com sucesso."
        } catch {
            Write-Log -Message "Erro ao copiar o diretório de '$SourceDirectory' para '$DestinationDirectory': $_"
            Write-Log -Message "Encerrando o script devido a falha na cópia do diretório."
            exit 1
        }

        # Executar o instalador
        Write-Log -Message "Tentando executar o instalador."
        Start-Process -FilePath $InstallPath -Wait -ErrorAction Stop
        Write-Log -Message "O instalador foi executado com sucesso."
    }

} catch {
    # Registrar erros no log
    Write-Log -Message "Erro encontrado: $_"
} finally {
    Write-Log -Message "Fim do script de verificação."
}
