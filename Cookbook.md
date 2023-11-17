# Docker
## Start
**up**: Start the services defined in the `docker-compose.yml` file. Use `-d` to run the containers in the background.
```bash
docker-compose -f docker-compose.yaml --env-file .env up -d <container_name>
```
## Execute
**exec**: executes command in specified container. `-it` creates new *tty*  session and `/bin/sh` gives access to container's shell
```bash
docker exec -it <container_name> /bin/sh
```
## Status
```bash
docker ps
```

# SQL
## Exec demon commands line-by-line
```bash
echo "<command>" | /usr/bin/mysqld --user=mysql --bootstrap
```