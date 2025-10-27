#!/bin/bash

# --- Início da Verificação de Root ---
if [ "$UID" -ne 0 ]; then
  echo "Erro: Este script precisa ser executado com privilégios de root." >&2
  echo "Por favor, execute com 'sudo'." >&2
  exit 1
fi
# --- Fim da Verificação de Root ---

# Cores ANSI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor

ZONEINFO="/usr/share/zoneinfo"

# --- Verifica dependências (whiptail e curl) ---
pacotes_necessarios="whiptail curl"
pacotes_faltando=""

echo -e "${YELLOW}Verificando dependências...${NC}"

for pkg in $pacotes_necessarios; do
    if ! command -v "$pkg" &> /dev/null; then
        # Adiciona o pacote à lista de pacotes faltando
        pacotes_faltando="$pacotes_faltando $pkg"
    fi
done

# Se a lista de pacotes faltando não estiver vazia, instala
if [ -n "$pacotes_faltando" ]; then
    echo -e "${YELLOW}🔍 Pacotes não encontrados:$pacotes_faltando. Instalando automaticamente...${NC}"
    
    # Roda o apt update e o install
    apt update && apt install -y $pacotes_faltando
    
    # Re-verifica apenas os pacotes que deveriam ter sido instalados
    for pkg in $pacotes_faltando; do
        if ! command -v "$pkg" &> /dev/null; then
            echo -e "${RED}❌ Falha ao instalar o pacote '$pkg'. Encerrando.${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}✅ Dependências instaladas com sucesso.${NC}"
else
    echo -e "${GREEN}✅ Dependências (whiptail, curl) já estão instaladas.${NC}"
fi
# --- Fim da verificação ---

# Função para instalar o docker
install_docker() {
  echo -e "${YELLOW}⚙️ Instalando Docker (via script oficial)...${NC}"
  curl -fsSL https://get.docker.com | sh

  echo -e "${YELLOW}⚙️ Habilitando e iniciando o serviço Docker...${NC}"
   systemctl enable docker
   systemctl start docker

  echo -e "${GREEN}✅ Docker instalado com sucesso!${NC}"
}

# Verifica se Docker está instalado
if ! command -v docker &> /dev/null; then
  echo -e "${RED}❌ Docker não encontrado.${NC}"
  install_docker
else
  echo -e "${GREEN}✔ Docker já instalado, continuando.${NC}"
fi

# Verifica se o plugin Docker Compose está disponível
if ! docker compose version &> /dev/null; then
  echo -e "${RED}❌ Docker Compose não encontrado.${NC}"
  echo -e "${YELLOW}⚙️ Instalando Docker Compose plugin...${NC}"
   apt-get update -y &&  apt-get install -y docker-compose-plugin
  echo -e "${GREEN}✅ Docker Compose instalado com sucesso!${NC}"
else
  echo -e "${GREEN}✔ Docker Compose já está instalado.${NC}"
fi

  # Verifica se os containers já existem
  # Nome inicial sugerido
CONTAINER_NAME="nextcloud"

# Verifica se o nome segue boas práticas
validar_nome_container() {
  [[ "$1" =~ ^[a-z0-9_-]+$ ]]
}

# Função para verificar se algum container com base no nome existe
check_container_name() {
  for name in "$1-app" "$1-db" "$1-redis"; do
    if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
      return 1  # Existe
    fi
  done
  return 0  # Não existe
}

# Verifica se o nome atual está válido
if ! validar_nome_container "$CONTAINER_NAME"; then
  echo -e "${RED}❌ Nome '$CONTAINER_NAME' inválido. Use apenas letras minúsculas, números, hífens (-) ou underscores (_).${NC}"
  CONTAINER_NAME=""
fi

# Verifica se o nome está livre ou precisa ser alterado
if [ -z "$CONTAINER_NAME" ] || ! check_container_name "$CONTAINER_NAME"; then
  [ -n "$CONTAINER_NAME" ] && echo -e "${RED}❌ Já existe um container com o nome '$CONTAINER_NAME'.${NC}"

  while true; do
    NOVO_NOME=$(whiptail --inputbox "Digite um novo nome base para os containers:\n\nPermitido:\n- Letras minúsculas (a-z)\n- Números (0-9)\n- Hífens (-)\n- Underscores (_)\n\nSem espaços ou caracteres especiais." 15 70 "nextcloud1" 3>&1 1>&2 2>&3)
    [ $? -ne 0 ] && echo -e "${RED}❌ Cancelado pelo usuário.${NC}" && exit 1

    if ! validar_nome_container "$NOVO_NOME"; then
      whiptail --msgbox "❌ Nome inválido.\n\nUse apenas:\n- Letras minúsculas (a-z)\n- Números (0-9)\n- Hífens (-)\n- Underscores (_)\n\nSem espaços ou caracteres especiais." 12 70
      continue
    fi

    if check_container_name "$NOVO_NOME"; then
      CONTAINER_NAME="$NOVO_NOME"
      echo -e "${GREEN}✅ Novo nome definido: $CONTAINER_NAME${NC}"
      break
    else
      whiptail --msgbox "❌ Já existe um container com o nome '$NOVO_NOME'. Tente outro nome." 10 70
    fi
  done
else
  echo -e "${GREEN}✅ O nome '$CONTAINER_NAME' foi aceito.${NC}"
fi

echo -e "${YELLOW}Criando diretório de configuração: ./${CONTAINER_NAME}${NC}"
mkdir -p "$CONTAINER_NAME"
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Falha ao criar o diretório ./${CONTAINER_NAME}. Verifique as permissões.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Diretório criado com sucesso.${NC}",

#Copia os arquivos para a pasta com nome do container
\cp docker-compose.yml $CONTAINER_NAME/docker-compose.yml
\cp post_install.sh $CONTAINER_NAME/post_install.sh
\cp config_domain.sh $CONTAINER_NAME/config_domain.sh

# Lista de regiões principais
REGIOES=$(find "$ZONEINFO" -mindepth 1 -maxdepth 1 -type d | xargs -n1 basename)

# Loop mestre para seleção de Região e Cidade
while true; do

    # --- 1. Escolher Região ---
    REGIAO_ESCOLHIDA=$(whiptail --title "Escolha a Região" \
        --menu "Selecione uma região:" 20 60 10 $(for r in $REGIOES; do echo "$r ''"; done | sort) 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        # Se o usuário cancelar na SELEÇÃO DE REGIÃO, insiste (com base na sua lógica original)
        whiptail --msgbox "❌ Você precisa escolher uma região para continuar." 8 60
        continue # Volta ao início do loop mestre (mostra Região novamente)
    fi

    echo -e "${GREEN}✅ Região selecionada: $REGIAO_ESCOLHIDA${NC}"


    # --- 2. Escolher Cidade (Baseado na Região) ---

    # Lista cidades da região escolhida
    CIDADES=$(find "$ZONEINFO/$REGIAO_ESCOLHIDA" -type f | sed "s|$ZONEINFO/$REGIAO_ESCOLHIDA/||" | sort)

    # Monta menu de cidades com uma linha por item
    OPCOES=""
    for c in $CIDADES; do
        OPCOES="$OPCOES $c ''"
    done

    # Escolher cidade/fuso horário
    CIDADE_ESCOLHIDA=$(whiptail --title "Escolha a Cidade" \
        --menu "Selecione o fuso horário (Pressione 'Cancelar' para voltar à Região):" 20 60 15 $(echo "$OPCOES" | sort) 3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        # Se o usuário cancelar na SELEÇÃO DE CIDADE, volta para a Região
        echo -e "${YELLOW}Voltando para a seleção de Região...${NC}"
        continue # Volta ao início do loop mestre (mostra Região novamente)
    fi

    # Se chegou aqui, o usuário selecionou Região E Cidade
    echo -e "${GREEN}✅ Cidade selecionada: $CIDADE_ESCOLHIDA${NC}"
    break # Sai do loop mestre

done

# O script continua aqui com as variáveis $REGIAO_ESCOLHIDA e $CIDADE_ESCOLHIDA definidas
echo "Fuso horário final selecionado: $REGIAO_ESCOLHIDA/$CIDADE_ESCOLHIDA"


# Define variáveis
TZ="$REGIAO_ESCOLHIDA/$CIDADE_ESCOLHIDA"

# Mapeia código de país
case "$REGIAO_ESCOLHIDA" in
  America)
    case "$CIDADE_ESCOLHIDA" in
      Sao_Paulo|Recife|Fortaleza|Brasilia|Belem|Manaus) LOCAL="BR" ;;
      New_York|Chicago|Los_Angeles|Denver) LOCAL="US" ;;
      *) LOCAL="US" ;;
    esac
    ;;
  Europe)
    case "$CIDADE_ESCOLHIDA" in
      Paris) LOCAL="FR" ;;
      Berlin) LOCAL="DE" ;;
      Madrid) LOCAL="ES" ;;
      *) LOCAL="EU" ;;
    esac
    ;;
  Asia)
    case "$CIDADE_ESCOLHIDA" in
      Tokyo) LOCAL="JP" ;;
      Seoul) LOCAL="KR" ;;
      Shanghai|Beijing) LOCAL="CN" ;;
      *) LOCAL="AS" ;;
    esac
    ;;
  Africa)
    LOCAL="ZA" ;;
  *)
    LOCAL="XX" ;;
esac

# Aplica timezone
 timedatectl set-timezone "$TZ"

# Exibe resultado
echo -e "✅ ${CYAN}Timezone definido para:${GREEN} $TZ${NC}\n📞 ${CYAN}Código de país definido:${NC}${GREEN} $LOCAL${NC}"


# Função para exibir erros
erro() {
  whiptail --title "Erro" --msgbox "$1" 10 70
}

# Loop para entrada e validação do caminho
while true; do
  # Campo já vem preenchido com /mnt/ncdata
  NC_DATA_PATH=$(whiptail --inputbox \
    "Digite o caminho onde os dados do Nextcloud serão armazenados (ex: /ncdata ou /mnt/ncdata):" \
    10 70 "/mnt/ncdata" 3>&1 1>&2 2>&3)

  # Se o usuário cancelar
  if [ $? -ne 0 ]; then
    echo -e "${RED}[CANCELADO] Operação interrompida pelo usuário.${NC}"
    exit 1
  fi

  # Verifica se o diretório existe
  if [ ! -d "$NC_DATA_PATH" ]; then
    erro "O caminho '$NC_DATA_PATH' não existe.\n\nCrie manualmente e execute o script novamente."
    continue
  fi

  # Verifica se o caminho é um ponto de montagem válido
  if ! mountpoint -q "$NC_DATA_PATH"; then
    erro "O caminho '$NC_DATA_PATH' não é um ponto de montagem válido.\n\nMonte um disco (ex: /mnt/ncdata) e tente novamente."
    continue
  fi

  # Caminho final (ex: /mnt/ncdata/nextcloud)
  FINAL_PATH="$NC_DATA_PATH/$CONTAINER_NAME"

  # Verifica se já existe a pasta
  if [ -d "$FINAL_PATH" ]; then
    CHOICE=$(whiptail --title "Pasta existente" \
      --menu "O diretório '$FINAL_PATH' já existe.\n\nEscolha uma ação:" 15 70 3 \
      "1" "Criar backup (renomear com data)" \
      "2" "Apagar e criar novamente" \
      "3" "Cancelar" 3>&1 1>&2 2>&3)

    case "$CHOICE" in
      1)
        DATE_SUFFIX=$(date +%Y%m%d-%H%M%S)
        BACKUP_PATH="${FINAL_PATH}_backup_${DATE_SUFFIX}"
        mv "$FINAL_PATH" "$BACKUP_PATH"
        mkdir -p "$FINAL_PATH"
        whiptail --msgbox "Backup criado em:\n$BACKUP_PATH\n\nNova pasta criada:\n$FINAL_PATH" 12 70
        ;;
      2)
        rm -rf "$FINAL_PATH"
        mkdir -p "$FINAL_PATH"
        whiptail --msgbox "Diretório antigo removido e recriado:\n$FINAL_PATH" 10 70
        ;;
      3|*)
        echo -e "${YELLOW}[INFO] Operação cancelada pelo usuário.${NC}"
        exit 1
        ;;
    esac
  else
    mkdir -p "$FINAL_PATH"
    whiptail --msgbox "Diretório criado com sucesso:\n$FINAL_PATH" 10 70
  fi

  echo -e "${GREEN}[OK] Diretório de dados do Nextcloud pronto em: $FINAL_PATH${NC}"
  break
done



# Função para verificar se a porta está em uso por algum container Docker
porta_em_uso() {
  docker ps --format '{{.Ports}}' | grep -q ":$1->"
}

# Loop até obter uma porta válida e confirmada
while true; do
  NEXTCLOUD_PORT=$(whiptail --inputbox "Digite a porta que deseja usar para o Nextcloud:" 10 60 "8081" 2>&1 >/dev/tty)

  # Verifica se foi cancelado ou vazio
  if [ -z "$NEXTCLOUD_PORT" ]; then
    whiptail --msgbox "❌ Você precisa informar uma porta. Tente novamente." 8 50
    continue
  fi

  # Confirmação
  whiptail --yesno "Você escolheu a porta $NEXTCLOUD_PORT. Confirma?" 8 60
  if [ $? -eq 0 ]; then
    # Verifica se a porta está em uso
    if porta_em_uso "$NEXTCLOUD_PORT"; then
      whiptail --msgbox "❌ A porta $NEXTCLOUD_PORT já está em uso por outro container Docker." 8 60
    else
      whiptail --msgbox "✅ Porta $NEXTCLOUD_PORT está disponível!" 8 50
      break
    fi
  fi
done
# Porta final está salva em $NEXTCLOUD_PORT
echo "Porta escolhida para o Nextcloud: $NEXTCLOUD_PORT"

# Loop para definir nome de usuário
while true; do
  NC_USER=$(whiptail --inputbox "Digite o nome de usuário para o Nextcloud:" 10 60 "admin" 3>&1 1>&2 2>&3)

  if [ -z "$NC_USER" ]; then
    whiptail --msgbox "❌ Você precisa informar um nome de usuário para continuar." 8 60
    continue
  fi

  whiptail --yesno "Você digitou:\n\n$NC_USER\n\nDeseja continuar com esse nome?" 10 60
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Nome de usuário confirmado: $NC_USER${NC}"
    break
  else
    whiptail --msgbox "❌ Não é possível continuar sem confirmar um nome de usuário." 8 60
  fi
done

# Loop para definir senha
while true; do
  NC_PASS=$(whiptail --passwordbox "Digite a senha para o usuário '$NC_USER':" 10 60 3>&1 1>&2 2>&3)

  # Verifica se está vazia
  if [ -z "$NC_PASS" ]; then
    whiptail --msgbox "[ERRO] Você precisa informar uma senha para continuar." 8 60
    continue
  fi

  # Verifica comprimento mínimo
  if [ ${#NC_PASS} -lt 8 ]; then
    whiptail --msgbox "[AVISO] A senha deve ter no mínimo 8 caracteres. Tente novamente." 8 60
    continue
  fi

  # Verifica complexidade
  if ! [[ "$NC_PASS" =~ [A-Z] ]]; then
    whiptail --msgbox "[AVISO] A senha deve conter pelo menos uma letra MAIÚSCULA." 8 60
    continue
  fi

  if ! [[ "$NC_PASS" =~ [a-z] ]]; then
    whiptail --msgbox "[AVISO] A senha deve conter pelo menos uma letra minúscula." 8 60
    continue
  fi

  if ! [[ "$NC_PASS" =~ [0-9] ]]; then
    whiptail --msgbox "[AVISO] A senha deve conter pelo menos um número." 8 60
    continue
  fi

  if ! [[ "$NC_PASS" =~ [^a-zA-Z0-9] ]]; then
    whiptail --msgbox "[AVISO] A senha deve conter pelo menos um caractere especial (ex: ! @ # $ % & * ...)." 8 60
    continue
  fi

  # Confirmação da senha
  NC_PASS_CONFIRM=$(whiptail --passwordbox "Confirme a senha digitando novamente:" 10 60 3>&1 1>&2 2>&3)
  if [ "$NC_PASS" != "$NC_PASS_CONFIRM" ]; then
    whiptail --msgbox "[ERRO] As senhas não coincidem. Tente novamente." 8 60
    continue
  fi

  whiptail --yesno "[OK] Senha válida e confirmada!\n\nDeseja continuar?" 10 60
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK] Senha confirmada para o usuário '$NC_USER'${NC}"
    break
  else
    whiptail --msgbox "[CANCELADO] Operação interrompida. Digite novamente a senha." 8 60
  fi
done

# Gera senhas aleatórias
DB_ROOT_PASSWORD=$(openssl rand -base64 26)
DB_PASSWORD=$(openssl rand -base64 21)
REDIS_PASSWORD=$(openssl rand -base64 16)
DB_USER="nc_$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
DB_NAME="${CONTAINER_NAME}_db"


# Cria o arquivo .env dentro do diretório $CONTAINER_NAME
cat <<EOF > "$CONTAINER_NAME/.env"
CONTAINER_NAME=$CONTAINER_NAME
DB_ROOT_PASSWORD=$DB_ROOT_PASSWORD
DB_PASSWORD=$DB_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
DB_USER=$DB_USER
DB_NAME=$DB_NAME
NC_DATA=$FINAL_PATH
NC_USER=$NC_USER
NC_PASS=$NC_PASS
CONTAINER_NAME=$CONTAINER_NAME
TZ=$TZ
LOCAL=$LOCAL
NEXTCLOUD_PORT=$NEXTCLOUD_PORT
EOF

# Exibe os dados gerados
echo -e "${CYAN}🔐 Credenciais geradas:${NC}"
echo -e "${YELLOW}DB_ROOT_PASSWORD=${NC}${GREEN} $DB_ROOT_PASSWORD${NC}"
echo -e "${YELLOW}DB_PASSWORD=${NC}${GREEN} $DB_PASSWORD${NC}"
echo -e "${YELLOW}REDIS_PASSWORD=${NC}${GREEN} $REDIS_PASSWORD${NC}"
echo -e "${YELLOW}DB_USER=${NC}${GREEN} $DB_USER${NC}"
echo -e "${YELLOW}DB_NAME=${NC}${GREEN} $DB_NAME${NC}"
echo -e "${YELLOW}Pasta para os dados de usuários do Nextcloud=${NC}${GREEN}$FINAL_PATH${NC}"
echo -e "${YELLOW}Nome do container=${NC} ${GREEN}$CONATINER_NAME${NC}"
echo -e "${YELLOW}Usuário Administrador=${NC}${GREEN} $NC_USER${NC}"
echo -e "${YELLOW}Senha de Administrador=${NC} ${GREEN}$NC_PASS${NC}"
echo -e "${YELLOW}Fuso horário=${NC}${GREEN} $TZ${NC}"
echo -e "${YELLOW}Região do Telefone=${NC} $LOCAL${NC}"
echo -e "${YELLOW}Porta usada pelo Nextcloud=${NC}${GREEN} $NEXTCLOUD_PORT${NC}"

echo -ne "${GREEN}🚀 Iniciando instalação! "
for i in {1..3}; do
  echo -n "."
  sleep 1
done
echo -e "${NC}\n"


cd $CONTAINER_NAME && docker compose -p "${CONTAINER_NAME}" up -d

# Captura IP local do servidor
IP_LOCAL=$(hostname -I | awk '{print $1}')

# Aguarda o Nextcloud responder via HTTP
echo -e "${YELLOW}⏳ Aguardando o Nextcloud iniciar...${NC}"

# Indicador de progresso animado
ANIM_CHARS="/-\|"
i=0
TIMEOUT=180 # Tempo limite de 3 minutos

while true; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://${IP_LOCAL}:${NEXTCLOUD_PORT}")

  # Se o status for diferente de 000 (sem resposta), considera que está respondendo
  if [ "$STATUS" -ne 000 ] && [ "$STATUS" -ne 503 ]; then
    echo -e "${GREEN}✅ Nextcloud respondeu com Status: $STATUS. Iniciando as configurações...${NC}"
    break
  fi

  # Controle de tempo limite (para evitar loop infinito)
  if [ $i -ge $TIMEOUT ]; then
    echo -e "${RED}❌ TEMPO ESGOTADO. Nextcloud não respondeu em ${TIMEOUT} segundos (Status: $STATUS). Verifique os logs do Docker.${NC}"
    exit 1
  fi
  
  # Lógica da animação e do timer
  i=$((i+1))
  CHAR="${ANIM_CHARS:$((i % 4)):1}"
  
  echo -ne "${CYAN} $CHAR ${YELLOW}Aguardando Nextcloud... Tentativa $i de $TIMEOUT (Status: $STATUS)${NC}\r"
  sleep 1

done
echo -ne "\033[K" # Limpa a linha

# Ajusta permissões da pasta de dados
echo -e "${CYAN} Ajustando as permissões da pasta: $FINAL_PATH${NC}"
chown -R 33:33 "$FINAL_PATH"
 chmod -R 750 "$FINAL_PATH"
echo -e "${GREEN} ✅ Ajustado${NC}"

echo -e "${CYAN}Iniciando script de configurações pós instalação${NC}"
sleep 3
bash post_install.sh
