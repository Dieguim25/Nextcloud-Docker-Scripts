#!/bin/bash

# Definição de Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # Sem Cor

# Se o .env não estiver aqui, encerra.
if [ ! -f .env ]; then
    echo -e "${RED}Erro: Arquivo .env não encontrado no diretório atual.${NC}"
    echo "Execute este script de dentro da pasta de instalação."
    exit 1
fi

# 2. Carrega as variáveis (como $CONTAINER_NAME) do arquivo .env
echo -e "${GREEN}Carregando configuração...${NC}"
export $(grep -v '^#' .env | xargs)

# 3. Pergunta ao usuário qual é o domínio (usando whiptail)
DOMINIO=$(whiptail --inputbox "Digite seu domínio/subdomínio para o Nextcloud:\n\nEx: nextcloud.meudominio.com" 10 70 3>&1 1>&2 2>&3)

if [ -z "$DOMINIO" ]; then
    echo -e "${RED}❌ Domínio não fornecido. Configuração HTTPS cancelada.${NC}"
    exit 1
fi

echo -e "${GREEN}Configurando domínio: $DOMINIO...${NC}"

# --- FIM DA CORREÇÃO ---
CONTAINER=${CONTAINER_NAME}-app
# Captura o IP local
IP_LOCAL=$(hostname -I | awk '{print $1}')
NEXTCLOUD_PORT=${NEXTCLOUD_PORT}
CONTAINER_IP=http://${IP_LOCAL}:${NEXTCLOUD_PORT}

# Seus comandos (agora corretos, pois $CONTAINER_NAME e $DOMINIO existem)
echo -e "${GREEN}🔧 Aplicando configurações no Nextcloud...${NC}"
docker exec -u www-data $CONTAINER php occ config:system:set overwrite.cli.url --value="https://$DOMINIO"
docker exec -u www-data $CONTAINER php occ config:system:set overwriteprotocol --value="https"
docker exec -u www-data $CONTAINER php occ maintenance:update:htaccess
docker restart $CONTAINER

echo -e "${GREEN}✅ Configuração de HTTPS concluída.${NC}"
echo -e "${YELLOW}Lembre-se de apontar seu proxy reverso para o container em $CONTAINER_IP.${NC}"
