name = inception
all:
	@printf "Launch configuration ${name}...\n"
	@bash srcs/requirements/tools/make_dir.sh
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up -d --build mariadb wordpress nginx

maria:
	@printf "(re)creating mariadb...\n"
	@docker stop mariadb
	@docker rm -v mariadb
	@sudo rm -rf ~/data/mariadb/*
	@bash srcs/requirements/tools/make_dir.sh
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up -d --build mariadb

wp:
	@printf "(re)creating wordpress...\n"
#	@docker stop wordpress
	@docker rm -v wordpress
	@sudo rm -rf ~/data/wordpress/*
	@bash srcs/requirements/tools/make_dir.sh
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up  --build wordpress

nginx:
	@printf "(re)creating nginx...\n"
	@docker stop nginx
	@docker rm -v nginx
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up -d --build nginx

build:
	@printf "Building configuration ${name}...\n"
	@bash srcs/requirements/tools/make_dir.sh
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up -d --build

down:
	@printf "Stopping configuration ${name}...\n"
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env down

re: down
	@printf "Rebuild configuration ${name}...\n"
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up -d --build

clean: down
	@printf "Cleaning configuration ${name}...\n"
	@docker system prune -a
	@sudo rm -rf ~/data/wordpress/*
	@sudo rm -rf ~/data/mariadb/*

fclean:
	@printf "Total clean of all configurations docker\n"
	@docker stop $$(docker ps -qa)
	@docker system prune --all --force --volumes
	@docker network prune --force
	@docker volume prune --force
	@sudo rm -rf ~/data/wordpress/*
	@sudo rm -rf ~/data/mariadb/*

.PHONY	: all build down re clean fclean
