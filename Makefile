COMPOSE_FILE := srcs/docker-compose.yml
COMPOSE := docker compose -f $(COMPOSE_FILE)
SERVICE ?=

all: up

help:
	@printf '%s\n' \
	  'Usage:' \
	  '  make                      Build and start the complete stack' \
	  '  make build                Build the custom images only' \
	  '  make up                   Build and start the complete stack' \
	  '  make down                 Stop/remove containers and network; preserve volumes' \
	  '  make ps                   Show service status and ports' \
	  '  make logs SERVICE=name    Show logs for all services or one service' \
	  '  make stop SERVICE=name    Stop all services or one service without deleting it' \
	  '  make start SERVICE=name   Start all services or one stopped service' \
	  '  make restart SERVICE=name Restart all services or one running service' \
	  '  make re                   Recreate the stack while preserving named volumes'

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs $(SERVICE)

stop:
	$(COMPOSE) stop $(SERVICE)

start:
	$(COMPOSE) start $(SERVICE)

restart:
	$(COMPOSE) restart $(SERVICE)

re: down up

.PHONY: all help build up down ps logs stop start restart re
