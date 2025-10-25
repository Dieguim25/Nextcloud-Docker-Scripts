#!/bin/bash

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor

CONFIG_PATH="/var/www/html/config/config.php"
ENV_FILE=".env"

# Verifica se o arquivo .env existe
if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}❌ Arquivo .env não encontrado no diretório atual.${NC}"
  exit 1
fi

# Carrega variáveis do .env
echo -e "${YELLOW}📦 Carregando variáveis do arquivo .env...${NC}"
LOCAL=$(grep '^LOCAL=' "$ENV_FILE" | cut -d '=' -f2)
TZ=$(grep '^TZ=' "$ENV_FILE" | cut -d '=' -f2)
NEXTCLOUD_PORT=$(grep '^NEXTCLOUD_PORT=' "$ENV_FILE" | cut -d '=' -f2)
NC_USER=$(grep '^NC_USER=' "$ENV_FILE" | cut -d '=' -f2)
NC_PASS=$(grep '^NC_PASS=' "$ENV_FILE" | cut -d '=' -f2)
CONTAINER_NAME=$(grep '^CONTAINER_NAME=' "$ENV_FILE" | cut -d '=' -f2)


# Captura o IP local
IP_LOCAL=$(hostname -I | awk '{print $1}')

# Verifica se as variáveis foram carregadas
if [ -z "$LOCAL" ] || [ -z "$TZ" ]; then
  echo -e "${RED}❌ Variáveis LOCAL ou TZ não encontradas ou estão vazias no .env.${NC}"
  exit 1
fi

# Função para executar comandos OCC com verificação
executar_occ() {
  local descricao="$1"
  shift
  echo -e "${YELLOW}🔧 $descricao...${NC}"
  if docker exec -u www-data "${CONTAINER_NAME}-app" php occ "$@"; then
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

# Aplicando configurações
executar_occ "Corrigindo banco de dados" db:add-missing-indices
executar_occ "Executando manutenção" maintenance:repair --include-expensive
executar_occ "Definindo região de telefone" config:system:set default_phone_region --value="$LOCAL"
executar_occ "Definindo fuso horário" config:system:set default_timezone --value="$TZ"
executar_occ "Definindo idioma padrão com base no fuso horário" config:system:set default_language --value="$DEFAULT_LANG"
executar_occ "Definindo início da janela de manutenção" config:system:set maintenance_window_start --value="7"
executar_occ "Adicionando IP local aos domínios confiáveis" config:system:set trusted_domains 2 --value="$IP_LOCAL"
executar_occ "Desativando app_api" app:disable app_api


echo -e "${CYAN}Renomeando o arquivo .env${NC}"
# Renomeia o arquivo .env com base no nome do container e data
DATA_ATUAL=$(date +%Y%m%d-%H%M%S)
NOVO_ENV=".env_${CONTAINER_NAME}_${DATA_ATUAL}"

mv "$ENV_FILE" "$NOVO_ENV"

echo -e "${CYAN}Informações de credenciais podem ser encontradas no arquivo $NOVO_ENV${NC}"
sleep 3


# Define o nome completo do container para reinício
APP_CONTAINER="${CONTAINER_NAME}-app"

echo -e "${YELLOW}🔄 Reiniciando o container '$APP_CONTAINER' para aplicar as configurações...${NC}"
docker restart "$APP_CONTAINER"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Container '$APP_CONTAINER' reiniciado com sucesso.${NC}"
else
  echo -e "${RED}❌ Falha ao reiniciar o container '$APP_CONTAINER'. Verifique os logs do Docker.${NC}"
  exit 1
fi

# Exibe mensagem interativa via SSH com whiptail
whiptail --title "Nextcloud está pronto!" \
  --msgbox "O Nextcloud está funcional!\n\nAcesse pelo navegador:\n\nhttp://${IP_LOCAL}:${NEXTCLOUD_PORT}\nUsuário: ${NC_USER}\nSenha: ${NC_PASS}\nPara configurar um domínio e HTTPS execute o scipt config_domain.sh" 20 70
