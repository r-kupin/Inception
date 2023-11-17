# TODO
- [x] [[README.md#^aba349]] weird way to temp store script
- [x] [[README.md#^ca14cc]] smth weird in SQL
- [x] [[README.md#^bf9c17]] make fclean after container already cleaned: UPD: because at least 1 container should run in order to use `docker stop`
- [x] [[README.md#^2df383]] add comments to location blocs
- [x] [[README.md#^665b5d]] add comments
- [ ] **maybe** setup DNS to access from Host via correct link
- [x] **maybe** extract SQL init-database script
- [ ] ssh security
- [ ] certificates precreated?
- [x] preconfigure wordpress with wp_core or whatewer
- [x] copy VM, deploy bitnami and find out which install_packages would be used
- [x] make sure that credentials, API keys, env variables are not in *git*
- [ ] check 
# QA
1. **What docker environment consists of?**:
    1. **Images**:
        1. **What is it?**: An image is a lightweight, stand-alone, executable package that includes everything needed to run a piece of software, including the code, runtime, system tools, libraries, and settings.
        2. **How to create / define it?**: Images are typically created using a Dockerfile, which specifies the instructions for building the image.
    2. **Containers**:
        1. **What is it?**: A container is a runnable instance of an image. It's an isolated environment that includes the application and all its dependencies.
        2. **How to create / define it?**: Containers are created by running an image with the `docker run` command. You can also define container configurations in a Docker Compose file.
    3. **Networks**:
        1. **What is it?**: Networks in Docker allow containers to communicate with each other or with the outside world. They provide isolated communication channels for containers.
        2. **How to create / define it?**: You can create custom networks using `docker network create` or use the default bridge network.
    4. **Volumes**:
        1. **What is it?**: Volumes are a way to persist and share data between containers and the host. They are separate from the container file system and can be used for data storage.
        2. **How to create / define it?**: Volumes can be created with the `docker volume create` command or by specifying them in the `docker run` command.
2. **Environment variables. How to pass? How to use?**:
    - Environment variables in Docker can be passed and used in containers using the `-e` option with `docker run` to set environment variables when the container is created. Inside the container, you can access these environment variables like regular environment variables in your application.


**FastCGI & FPM**: *FastCGI* is a protocol of communication between the server and application it serves (wordpress). *FPM* is an implementation of that protocol specifically designed for PHP. 
    1. **FastCGI (Common Gateway Interface):** is a protocol for interfacing external applications (like PHP) with web servers. It keeps the PHP interpreter running as a separate process, and the web server communicates with it.
    2. **FPM (FastCGI Process Manager):** is a specific implementation of FastCGI for PHP. It's a process manager that manages a pool of PHP processes to handle incoming requests. FPM maintains a pool of worker processes, and each process can handle multiple requests over its lifetime. It provides features like process management, resource limiting, and the ability to handle large numbers of simultaneous connections.
# How it works
1. *Make* runs `docker-compose up` and docker-compose executes instructions
2. *docker-compose* loads Dockerfiles of the described services, in order of their interdependency and asks docker to execute them, as well as mount volumes and creating networks
3. *docker* starts with creating described networks, and then goes by all services's *Dockerfiles*
4. *docker* starts from the Dockerfile for `mariadb`, because nginx depends on wordpress, which in turn depends on `mariadb`
5. *docker* looks for `FROM` instruction, which tells us what distro image do we need for building up this container - in our case it is `alpine:3.18.4`
6. *docker* downloads distro image if needed and proceeds with it's configuration as described
7. *docker* loads environement variables via `ENV` or `ARG`
8. *docker* executes Dockerfile `CMD` instruction, that starts service which is a purpose of a particular container
9. when all containers are up and configured propperly the *443* port of *nginx*'s container get's exposed from *docker network* to hosting machine (*VM*) which then forwards it to PC's *42443* port and becomes accessible through https://localhost:42443 via browser
10. ***Nginx*** loads `index.php` - entry point to the wordpress
11. *nginx* receives the HTTP Request initiated by the user's interaction with the webpage. It looks up `nginx.conf` and directs incoming requests to the appropriate location block and sends **FastCGI** request to ***PHP-FPM***
12. The `location ~ \.php$` block in *nginx* config forwards PHP requests to the *PHP-FPM* service running in the WordPress/PHP container and listens for *FastCGI* requests on port 9000, as configured in `nginx.conf` on nginx side and `php-fpm.d/www.conf` on WP/PHP side. 
13. **WordPress** interprets the PHP scripts associated with the requested action querying the database, generating dynamic content, and preparing the HTTP response.
14. *WordPress*, using the database abstraction layer, performs SQL queries to read or write data in the **MariaDB** database.
15. *MariaDB* executes the SQL queries received from WordPress, updating the database records accordingly. For instance, when creating a new post, records are inserted into the `wp_posts` table, capturing post content, titles, timestamps, and other metadata.
16. *WordPress* generates an HTTP response, which is sent back through the *PHP-FPM* service and *Nginx* to the user's browser.
17. *browser* receives the HTTP response and renders the updated webpage based on the changes made through the WordPress interface.
