#!/usr/bin/env bash

set -euo pipefail

# ================================================
# setup.sh - Inicia Traefik + Portainer com rede externa + espera por health
# Uso: ./setup.sh [up | down | restart]
# ================================================

COMPOSE_TRAEFIK="../traefik/docker-compose.yaml"
COMPOSE_PORTAINER="../portainer/docker-compose.yaml"
NETWORK_NAME="proxy-net"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funções auxiliares
check_docker_compose() {
    if ! command -v docker compose &> /dev/null; then
        if ! command -v docker-compose &> /dev/null; then
            echo -e "${RED}Erro: nem 'docker compose' nem 'docker-compose' encontrados.${NC}"
            exit 1
        else
            DOCKER_COMPOSE_CMD="docker-compose"
        fi
    else
        DOCKER_COMPOSE_CMD="docker compose"
    fi
}

ensure_network_exists() {
    # if ! docker network ls --filter name="^${NETWORK_NAME}$" --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    #     echo -e "${GREEN}→ Criando rede externa: ${NETWORK_NAME}${NC}"
    #     docker network create "${NETWORK_NAME}"
    # else
        echo -e "${GREEN}→ Verificando rede ${NETWORK_NAME} (deixe o Traefik criar se necessário)${NC}"
    # fi
}

wait_for_healthy() {
    local container_name=$1
    local max_attempts=30
    local attempt=1

    echo -e "${YELLOW}Aguardando container ${container_name} ficar healthy...${NC}"
    while [ $attempt -le $max_attempts ]; do
        local status
        status=$(docker inspect --format='{{json .State.Health.Status}}' "${container_name}" 2>/dev/null || echo "none")

        if [[ "$status" == *"healthy"* ]]; then
            echo -e "${GREEN}→ ${container_name} está healthy!${NC}"
            return 0
        fi

        echo -e "${YELLOW}  Tentativa $attempt/$max_attempts: status = $status${NC}"
        sleep 5
        ((attempt++))
    done

    echo -e "${RED}Erro: ${container_name} não ficou healthy após ${max_attempts} tentativas.${NC}"
    echo "Verifique logs: docker logs ${container_name}"
    exit 1
}

up_services() {
    echo -e "${GREEN}Iniciando serviços na ordem correta...${NC}"
    
    echo -e "\n${YELLOW}1. Subindo Traefik...${NC}"
    if [[ -f "${COMPOSE_TRAEFIK}" ]]; then
        (cd "$(dirname "${COMPOSE_TRAEFIK}")" && ${DOCKER_COMPOSE_CMD} up -d)
    else
        echo -e "${RED}Arquivo não encontrado: ${COMPOSE_TRAEFIK}${NC}"
        exit 1
    fi
    
    wait_for_healthy "traefik"
    
    echo -e "\n${YELLOW}2. Subindo Portainer...${NC}"
    if [[ -f "${COMPOSE_PORTAINER}" ]]; then
        (cd "$(dirname "${COMPOSE_PORTAINER}")" && ${DOCKER_COMPOSE_CMD} up -d)
    else
        echo -e "${RED}Arquivo não encontrado: ${COMPOSE_PORTAINER}${NC}"
        exit 1
    fi
    
    #wait_for_healthy "portainer"
    
    echo -e "\n${GREEN}✔ Todos os serviços iniciados e healthy${NC}"
    echo ""
    echo "Acessos esperados:"
    echo "  • Portainer → http://portainer.local"
    echo "  • Traefik dashboard → http://traefik.local:8080  (se configurado)"
    echo ""
    echo "Verifique status:"
    echo "  docker ps"
    echo "  docker inspect --format '{{json .State.Health}}' traefik portainer"
}

down_services() {
    echo -e "${YELLOW}Parando e removendo containers...${NC}"
    
    if [[ -f "${COMPOSE_PORTAINER}" ]]; then
        (cd "$(dirname "${COMPOSE_PORTAINER}")" && ${DOCKER_COMPOSE_CMD} down)
    fi
    
    if [[ -f "${COMPOSE_TRAEFIK}" ]]; then
        (cd "$(dirname "${COMPOSE_TRAEFIK}")" && ${DOCKER_COMPOSE_CMD} down)
    fi
    
    echo -e "${GREEN}✔ Serviços parados${NC}"
}

restart_services() {
    down_services
    up_services
}

# ------------------------------------------------

check_docker_compose

case "${1:-up}" in
    up)
        ensure_network_exists
        up_services
        ;;
    down)
        down_services
        ;;
    restart)
        restart_services
        ;;
    *)
        echo "Uso: $0 [up | down | restart]"
        echo "  (padrão = up)"
        exit 1
        ;;
esac

echo -e "\n${GREEN}Concluído.${NC}"