#!/bin/bash

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Função para validar domínio (formato básico)
validar_dominio() {
  [[ "$1" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}

whiptail --title "⚠️ Atenção: HTTPS sem Proxy Reverso" \
--msgbox "Você está prestes a habilitar HTTPS.\n\n⚠️ Se o Nextcloud não estiver atrás de um proxy reverso (como Nginx, Traefik, Cloudflare Tunnel ou Caddy), isso pode causar falhas graves na aplicação, como:\n\n- Interface inacessível\n\nCertifique-se de que o proxy está corretamente configurado antes de prosseguir." 20 70

# Loop até obter domínio válido e confirmado
while true; do
  DOMINIO=$(whiptail --inputbox "Digite o domínio que deseja usar (ex: cloud.seudominio.com):" 10 70 "" 3>&1 1>&2 2>&3)

  # Cancelado
  if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Operação cancelada pelo usuário.${NC}"
    exit 1
  fi

  # Validação
  if ! validar_dominio "$DOMINIO"; then
    whiptail --msgbox "❌ Domínio inválido.\n\nUse um formato como: exemplo.com ou sub.exemplo.com" 10 70
    continue
  fi

  # Confirmação
  whiptail --yesno "Você digitou:\n\n$DOMINIO\n\nDeseja continuar com esse domínio?" 10 70
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Domínio confirmado: $DOMINIO${NC}"
    break
  fi
done

# Aplica configurações no Nextcloud
echo -e "${GREEN}🔧 Aplicando configurações no Nextcloud...${NC}"
docker exec -u www-data nextcloud-app php occ config:system:set overwrite.cli.url --value="https://$DOMINIO"
docker exec -u www-data nextcloud-app php occ config:system:set overwriteprotocol --value="https"
docker exec -u www-data nextcloud-app php occ maintenance:update:htaccess
docker restart nextcloud-app
echo -e "${GREEN}✅ Configuração concluída!${NC}"
