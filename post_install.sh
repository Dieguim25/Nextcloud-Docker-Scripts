#!/bin/bash

# --- Início da Verificação de Root ---
if [ "$UID" -ne 0 ]; then
  echo "Erro: Este script precisa ser executado com privilégios de root." >&2
  echo "Por favor, execute com 'sudo'." >&2
  exit 1
fi
# --- Fim da Verificação de Root ---

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor

CONFIG_PATH="/var/www/html/config/config.php"
ENV_FILE=".env"


# Se o .env não estiver aqui, encerra.
if [ ! -f .env ]; then
    echo -e "${RED}Erro: Arquivo .env não encontrado no diretório atual.${NC}"
    echo "Execute este script de dentro da pasta de configuração desse container."
    exit 1
fi

# 2. Carrega as variáveis (como $CONTAINER_NAME) do arquivo .env
echo -e "${GREEN}Carregando configuração...${NC}"
export $(grep -v '^#' .env | xargs)

APP_CONTAINER="${CONTAINER_NAME}-app"


# Captura o IP local
IP_LOCAL=$(hostname -I | awk '{print $1}')

# Função para executar comandos OCC com verificação
executar_occ() {
  local descricao="$1"
  shift
  echo -e "${YELLOW}🔧 $descricao...${NC}"
  if docker exec -u www-data "$APP_CONTAINER" php occ "$@"; then
    echo -e "${GREEN}✅ $descricao concluído com sucesso.${NC}"
  else
    echo -e "${RED}❌ Falha ao executar: $descricao${NC}"
  fi
}


# Define idioma com base no fuso horário
case "$TZ" in
  America/Sao_Paulo|America/Fortaleza|America/Recife|America/Belem|America/Manaus)
    DEFAULT_LANG="pt_BR"
    ;;
  America/New_York|America/Chicago|America/Los_Angeles)
    DEFAULT_LANG="en"
    ;;
  Europe/Paris|Europe/Madrid)
    DEFAULT_LANG="fr"
    ;;
  Europe/Berlin)
    DEFAULT_LANG="de"
    ;;
  Asia/Tokyo)
    DEFAULT_LANG="ja"
    ;;
  Asia/Seoul)
    DEFAULT_LANG="ko"
    ;;
  Asia/Shanghai|Asia/Beijing)
    DEFAULT_LANG="zh_CN"
    ;;
  *)
    DEFAULT_LANG="en"
    ;;
esac

echo -e "${GREEN}✅ LOCAL=$LOCAL | TZ=$TZ | IP_LOCAL=$IP_LOCAL | default_language=$DEFAULT_LANG${NC}"

# 1. Configurações de Banco de Dados e Manutenção
executar_occ "Corrigindo banco de dados" db:add-missing-indices
executar_occ "Executando manutenção" maintenance:repair --include-expensive

# 3. Configurações Regionais e de Manutenção
executar_occ "Definindo região de telefone" config:system:set default_phone_region --value="$LOCAL"
executar_occ "Definindo fuso horário" config:system:set default_timezone --value="$TZ"
executar_occ "Definindo idioma padrão com base no fuso horário" config:system:set default_language --value="$DEFAULT_LANG"
executar_occ "Definindo início da janela de manutenção" config:system:set maintenance_window_start --value="7"

# 4. Configurações de Segurança e Apps
executar_occ "Adicionando IP local aos domínios confiáveis" config:system:set trusted_domains 2 --value="$IP_LOCAL"
executar_occ "Desativando app_api" app:disable app_api

# 2. Configurações de Cache e Redis
executar_occ "habilitando bloqueio de arquivo" config:system:set filelocking.enabled --value='true'
executar_occ "Definindo memcache.locking para Redis" config:system:set memcache.locking --value '\OC\Memcache\Redis'

echo -e "${CYAN}As informações de credenciais podem ser encontradas na pasta ${NC}${GREEN}${CONTAINER_NAME}/.env"
sleep 3

echo -e "${YELLOW}🔄 Reiniciando o container '$APP_CONTAINER' para aplicar as configurações...${NC}"
docker restart "$APP_CONTAINER"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Container '$APP_CONTAINER' reiniciado com sucesso.${NC}"
else
  echo -e "${RED}❌ Falha ao reiniciar o container '$APP_CONTAINER'. Verifique os logs do Docker.${NC}"
  exit 1
fi

# Pergunta ao usuário se deseja configurar o HTTPS
if (whiptail --title "Configuração de Domínio (Opcional)" --yesno "Deseja configurar o HTTPS (Domínio) agora?\n\nAVISO:\nEsta etapa é destinada a usuários que possuem um PROXY REVERSO (como Nginx, Traefik, Caddy, Cloudflare Tunnel, etc) já configurado.\n\nAo continuar, o acesso direto via HTTP (IP:PORTA) deixará de funcionar.\n\nDeseja continuar?" 15 70 3>&1 1>&2 2>&3); then
    
    # Se o usuário clicar em "Sim" (código de saída 0)
    echo -e "${YELLOW}Iniciando configuração de HTTPS/Domínio...${NC}"
    
    # Executa o script de configuração de domínio
    bash config_domain.sh
    
else
    
    # Se o usuário clicar em "Não" (código de saída 1)
    echo -e "${GREEN}Configuração de HTTPS/Domínio ignorada.${NC}"
    echo -e "A instalação básica foi concluída."
    # Exibe mensagem interativa via SSH com whiptail
    whiptail --title "Nextcloud está pronto!" \
      --msgbox "O Nextcloud está funcional!\n\nAcesse pelo navegador:\n\nhttp://${IP_LOCAL}:${NEXTCLOUD_PORT}\nUsuário: ${NC_USER}\nSenha: ${NC_PASS}\nPara configurar um domínio e HTTPS execute o scipt config_domain.sh que está na pasta $CONTAINER_NAME" 20 70

    exit 0
fi
