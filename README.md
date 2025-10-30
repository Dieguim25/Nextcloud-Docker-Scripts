# 🚀 Nextcloud Docker Installer

Instalação automatizada do Nextcloud com Docker e Docker Compose, incluindo banco de dados MariaDB 10.6, Redis Alpine, configuração regional, segurança e pós-instalação. Ideal para servidores Linux com interface SSH.
Otimizado para multiplas Instâncias

---

## 📦 Recursos

- Instalação interativa com validação de dados
- Geração automática de senhas seguras
- Configuração de timezone e idioma
- Criação de volumes com nomes dinâmicos
- Verificação de porta e containers existentes
- Pós-instalação com ajustes via occ
- Script para configurar domínio e HTTPS
- Organiza pastas de configurções pelo nome do container (Organização em multiplas instâncias)

---

## 🛠️ Requisitos

- Linux com acesso `root`, `Debian 11+/Ubuntu 22+`
- `Docker` e `Docker Compose` (instalados automaticamente se ausentes)
- Partição para as pastas de usuários do nextcloud. Ex: /mnt/ncdata ou /ncdata
- `whiptail` (instalado automaticamente)
- `curl` (instalado automaticamente)
- Acesso à internet para baixar imagens e releases
- `Git` para clonar o repositório

---

## 📥 Instalação

1. Instalar o Git se não tiver instalado:

```bash
sudo apt install git -y
```

2. Use o comando para clonar e executar:

```bash
git clone https://github.com/Dieguim25/nextcloud-docker.git && cd nextcloud-docker && bash install.sh
```

Esse script baixa a última release, extrai os arquivos e inicia o processo de instalação.

3. Siga os passos interativos do install.sh para configurar:

- Nome dos containers (Se multiplas Instâncias do Nextcloud)
- Fuso horário e país
- Pasta de dados
- Porta para o Nextcloud
- Usuário e senha de administrador do Nextcloud

4. Após a instalação, o post_install.sh será executado automaticamente para:

- Ajustar configurações internas via occ
- Definir idioma, fuso horário, domínio confiável

Aos instalar multiplas instâncias e no abrir na web e tentar fazer login retornar o seguinte erro:

<img width="450" height="650" alt="image" src="https://github.com/user-attachments/assets/e2682545-187e-47a3-a793-9ed289881a86" />

Apague tudo que tem a direita após a porta na ``Barra de Endereços``, ou simplesmente pressione `ctrl`+`shift` e clique em `R`:

<img width="426" height="47" alt="image" src="https://github.com/user-attachments/assets/542982c0-37c2-4e8a-bd00-f776869f2fa9" />

Deve ficar assim:

<img width="239" height="46" alt="image" src="https://github.com/user-attachments/assets/6ec87e02-6571-4314-b0fb-87baefb50a5a" />

Agora deve funcionar. 😀

## 🌐 Configurar domínio e HTTPS

⚠️ Importante: Para configurar HTTPS corretamente, é necessário que o Nextcloud esteja atrás de um proxy reverso (como Nginx, Traefik, Cloudflare Tunnel, etc...) que gerencie os certificados SSL. Sem isso, o Nextcloud pode parar de funcionar ou apresentar erros de redirecionamento, falhas de login ou problemas com domínios confiáveis. Após feita a configuração HTTPS a interface web não funcionara mais em HTTP.

Para a configuração, execute:

⚠️ Obs: deve ser executado da mesma pasta que contém os demais scripts, que é criada após a instalação.


```bash
bash config_domain.sh
```

Esse script solicitará o domínio desejado e aplicará as configurações no Nextcloud.

## 🔐 Segurança

- Senhas geradas com openssl rand
- Validação de complexidade de senha
- Permissões ajustadas na pasta de dados


## 📄 Licença

Este projeto está licenciado sob a [GNU Affero General Public License v3.0 (AGPLv3)](https://www.gnu.org/licenses/agpl-3.0.pt-br.html).  
Isso garante que qualquer modificação feita e utilizada remotamente (como em servidores ou serviços web) também seja disponibilizada publicamente.

Você é livre para usar, modificar e redistribuir este projeto, desde que respeite os termos da AGPLv3.


## ✉️ Contato

Desenvolvido por [Diego Zeppe](https://github.com/Dieguim25)   Para dúvidas ou sugestões, abra uma issue ou envie uma mensagem.
