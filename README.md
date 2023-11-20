Step by step guide to my Inception project done on Debian VM. Based on [codeshaman's work](https://github.com/codesshaman/inception) and [bitnami/wordpress-nginx](https://github.com/bitnami/containers/tree/main/bitnami/wordpress-nginx). 
# Set up VM
## Install stuff
1. login as root
2. `apt install -y neofetch curl sudo ufw docker docker-compose make openbox xinit kitty firefox-esr lsof wget libnss3-tools`
	1. **neofetch**: a command-line utility that displays system information and distribution logos. It's useful for getting a quick overview of the system's configuration and can be used for diagnostic purposes. It also makes your machine look cool ;)
	2. **sudo**: Sudo is a program that allows users to run programs with the security privileges of a root. It is essential for executing administrative tasks on the system.
	3. **ufw (Uncomplicated Firewall)**: UFW is a user-friendly command-line interface for managing iptables, which is a firewall management tool. It can be used to configure firewall rules to control incoming and outgoing network traffic, helping secure the server and Docker containers.
	4. **docker**: Docker is a platform for developing, shipping, and running applications in containers. It's commonly used for containerization, making it easier to deploy and manage applications, especially in server environments.
	5. **docker-compose**: Docker Compose is a tool for defining and running multi-container Docker applications. It allows you to define the services, networks, and volumes required for your applications in a single `docker-compose.yml` file.
	6. **make**: Make is a build automation tool that can be used to simplify and automate the building and deployment of software. It can be useful for creating scripts and automating tasks related to Docker container management.
	7. **openbox**: Openbox is a lightweight, highly configurable window manager. Just so firefox can show the website.
	8. **xinit**: Xinit is a script that starts the X Window System server. It's used to launch X sessions and window managers, including Openbox.
	9. **kitty**: Kitty is a fast, feature-rich terminal emulator, so we're not bounded to tty only
	10. **firefox-esr**: to show websites on machine
	11. **curl**: Curl is a command-line tool for transferring data with URLs. It's commonly used to make HTTP requests to APIs or web services, which can be be useful when interacting with external resources or Docker-related web services.
	12. **lsof**: to check ports, and what apps use them
	13. **wget**: a command-line utility for downloading files from the internet. It can be used to retrieve files from web servers, FTP servers, and various other protocols. Will be used to install `mkcert`
	14. **libnss3-tools**: a collection of command-line tools related to the Network Security Services (NSS) library. This library provides support for [SSL/TLS](ttps://aws.amazon.com/what-is/ssl-certificate/), and it's used for secure network communications. Is a dependency of `mkcert`
## Set up services on VM
### sudo
let non-root account to use `sudo` and `docker`
- add non-root user to `/etc/sudoers` file
- add non-root to docker group `sudo usermod -aG docker ` non-root-username, to let the use of docker without `sudo` by a non-root user
### firewall
allow ports that will be used: `22` -  default for *ssh*, `80` - *http* and `443` - *https*
### SSH
Set some security settings. In `/etc/ssh/sshd-config`
```
PermitEmptyPasswords no
PermitRootLogin no
AllowUsers rokupin
PasswordAuthentication no
PublicKeyAuthentication yes
```
## Port forwarding
Inside VirtualBox: Current machine > settings > network > Advanced > Port forwarding. Without port forwarding there is no way to access VM via network connection. 
```
|   Name   | Host Port | Guest Port |
|----------|-----------|------------|
|   SSH    |      4222 |         22 |
|   HTTP   |      4280 |         80 |
|   HTTPS  |     42443 |        443 |
```
The ports with number less than *1024* are reserved by system
## Set up certificates
### Install [mkcert](https://github.com/FiloSottile/mkcert)
- Run `url -s https://api.github.com/repos/FiloSottile/mkcert/releases/latest| grep browser_download_url  | grep linux-amd64 | cut -d '"' -f 4 | wget -qi -`
- rename executable to `mkcert` and move to `/usr/local/bin`
### Change domain name
Subject requirement is that our domain name should be rokupin.42.fr
In order to achieve this we need to modify `/etc/hosts` file - add desired hostname in line with `localhost`. After this operation we'll be able to access our web service via specified address while inside VM's terminal.
### Getting self-signed certificate
All certificates should be placed inside `~/project/requirements/nginx/tools`. Run `mkcert rokupin.42.fr` in this directory. Then, rename certificate files in a way nginx will understand: 
`mv rokupin.42.fr-key.pem rokupin.42.fr.key`
`mv rokupin.42.fr.pem rokupin.42.fr.crt`
## Set up environment variables for the containers `.env`
In `~/project/srcs`
```
DOMAIN_NAME=rokupin.42.fr
CERT_=./requirements/tools/rokupin.42.fr.crt
KEY_=./requirements/tools/rokupin.42.fr.key
DB_NAME=wordpress
DB_ROOT=rootpass
DB_USER=wpuser
DB_PASS=wppass
WP_ADMIN=wproot
WP_ADMIN_PASS=wprootpass
WP_ADMIN_MAIL=planesvvalker@gmail.com
WP_USER=rokupin
WP_USER_PASS=rokupinpass
WP_USER_MAIL=rokupin@student.42.fr
```
## Create a little shell library that will help automatically edit config files at the container's build time with sed    `confedit.sh`
In `~/project/srcs/requirements/tools/`
```bash
#!/bin/sh

# Check the there are 4 args
if [ "$#" -ne 4 ]; then
        echo "Usage: $0 key value file assignation_operator"
        exit 1
fi

# Give them meaningful names
key="$1"
value="$2"
file="$3"
assignation="$4"

if [ ! -f "$file" ]; then
        echo "Error: File '$file' does not exist."
        exit 1
fi

if [ ! -w "$file" ]; then
        echo "Error: File '$file' is not writable."
        exit 1
fi

# Find a line that tsarts with spaces, comments preceeding key in file
if grep -q "^[[:space:];#]*$key" "$file"; then
		# Replace that line with concatenated key, assignation and value
		sed -i "s|^[[:space:];#]*$key.*|$key$assignation$value|" "$file"
        echo "Updated key '$key' with value '$value' in '$file'."
else
		# If key not present - append concatenated string to the end of file
        echo "$key$assignation$value" >> "$file"
        echo "Appended key '$key' with value '$value' to '$file'."
fi
```
# Set up containers
## [MariaDB](https://github.com/MariaDB/server)
### Create [Dockerfile](https://docs.docker.com/engine/reference/builder/)
In `~/project/srcs/requirements/mariadb`
```Dockerfile
FROM alpine:3.18.4
```
Define build-time arguments. The [`ARG`](https://docs.docker.com/engine/reference/builder/#arg) instruction defines a variable that users can pass at build-time to the builder with the `docker build` command.
```Dockerfile
ARG DB_NAME \
    DB_USER \
    DB_PASS \
    DB_ROOT
```
Install MariaDB
```Dockerfile
RUN apk update && apk add --no-cache mariadb mariadb-client
```
[`COPY`](https://docs.docker.com/engine/reference/builder/#copy)  *confedit.sh* to edit configs on buildtime and *docker.cnf* - config for mysql server's daemon process from host to container's root
```Dockerfile
COPY requirements/tools/confedit.sh .
COPY requirements/mariadb/conf/docker.cnf /etc/my.cnf.d/
```
Create a directory for MariaDB's runtime data and give full permissions. This is done to allow MariaDB to create its runtime socket file here.
```Dockerfile
RUN mkdir /var/run/mysqld; chmod 777 /var/run/mysqld
```
Set `skip-networking` to `0`  inside `/etc/my.cnf.d/mariadb-server.cnf` to enable network connections.
```Dockerfile
RUN sh confedit.sh skip-networking 0 /etc/my.cnf.d/mariadb-server.cnf "="
```
Initialize the MariaDB data directory `/var/lib/mysql`, then copy *create_db.sh* to init database, run it and remove - along with other scripts
```Dockerfile
RUN mysql_install_db --user=mysql --datadir=/var/lib/mysql
COPY requirements/mariadb/conf/create_db.sh .
RUN sh create_db.sh && rm -f /*.sh
```
The [`EXPOSE`](https://docs.docker.com/engine/reference/builder/#expose) instruction informs Docker that the container listens on the specified network ports at runtime. Through this interface the database will interact with the wordpress.
```Dockerfile
EXPOSE 3306
```
The [`USER`](https://docs.docker.com/engine/reference/builder/#user) instruction sets the user name to use as the default user for the remainder of the current stage. The specified user is used for `RUN` instructions and at runtime, runs the relevant and `CMD` commands.
```Dockerfile
USER mysql
```
this is default command to be executed when the container is started. Launch the MariaDB server `mysqld`.
```Dockerfile
CMD ["/usr/bin/mysqld"]
```
### Mysqld service config `docker.cnf`
in `~/project/srcs/requirements/mariadb/conf`
The MySQL server, or `mysqld`, has a built-in mechanism to read configuration files when it launches. The `docker.cnf` file will be picked up and applied by the MySQL server.
- `skip-host-cache`: This directive is used to skip the DNS host cache, which can help with performance. 
- `skip-name-resolve`: This directive disables hostname resolution, which means that the MySQL server won't perform DNS lookups to resolve hostnames. It can improve performance by avoiding the overhead of DNS resolution.
- `bind-address=0.0.0.0`: This directive specifies the IP address to which the MySQL server will bind. In this case, it's set to `0.0.0.0`, which means the MySQL server will listen on all available network interfaces. This allows the server to accept connections from any IP address. It's commonly used in Docker containers to make the MySQL server accessible from outside the container.
```
[mysqld]
skip-host-cache
skip-name-resolve
bind-address=0.0.0.0
```
### Script to create DB `create_db.sh`
In `~/project/srcs/requirements/mariadb/tools`
SQL queries are passed through shell, because the access to env variables is required to resolve the name of databese, user, etc. But SQL engine can't resolve them, so at the first step `sh` substitutes values of the variables in place of their names, and only then the script is passed to `mysqld` engine
```bash
#!bin/sh

# Check if database already set up (normally, not yet)
if [ ! -d "/var/lib/mysql/wordpress" ]; then
        /usr/bin/mysqld --user=mysql --bootstrap << EOF
USE mysql;
FLUSH PRIVILEGES;
DELETE FROM     mysql.user WHERE User='';
DROP DATABASE test;
DELETE FROM mysql.db WHERE Db='test';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT}';
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER '${DB_USER}'@'%' IDENTIFIED by '${DB_PASS}';
GRANT ALL PRIVILEGES ON wordpress.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
fi
```
Shell-processed script looks like this:
```sql
USE mysql;
FLUSH PRIVILEGES;
DELETE FROM     mysql.user WHERE User='';
DROP DATABASE test;
DELETE FROM mysql.db WHERE Db='test';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpass';
CREATE DATABASE wordpress CHARACTER SET utf8 COLLATE utf8_general_ci;
CREATE USER 'wpuser'@'%' IDENTIFIED by 'wppass';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'%';
FLUSH PRIVILEGES;
```
### SQL queries to perform initialization
Switch the active database to mysql. The mysql database contains system-related tables, including user and privilege information.
```sql
USE mysql;
```
Reload the user and privilege information. This is typically used after making changes to user accounts or privileges to ensure that the changes take effect immediately.
```sql
FLUSH PRIVILEGES;
```
#### Delete stuff created by default
Removes anonymous users that might exist in the MySQL user table.
```sql
DELETE FROM mysql.user WHERE User='';
```
Delete (drop) test database, needed for security. The test database is commonly present in MySQL installations for testing purposes.
```sql
DROP DATABASE test;
```
Remove any records related to the test database.
```sql
DELETE FROM mysql.db WHERE Db='test';
```
#### Basic security concerns
Ensure that the root user can only connect from the local machine and not from remote hosts, needed for security.
```sql
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
```
Set password for root user to the content of ${DB_ROOT} variable. Changing root password is also needed for security (COME ON).
```sql
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT}';
```
#### Prepare database to be used by wordpress
Create a database for the app
```sql
CREATE DATABASE ${DB_NAME} CHARACTER SET utf8 COLLATE utf8_general_ci;
```
Create a database user for the app.
In SQL scripts, the '%' character is used as a wildcard to represent zero or more unspecified characters 
```sql
CREATE USER '${DB_USER}'@'%' IDENTIFIED by '${DB_PASS}';
```
Grant all privileges on the wordpress database to the user created in the previous step.
```sql
GRANT ALL PRIVILEGES ON wordpress.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
```
## [Wordpress](https://en.wikipedia.org/wiki/WordPress)
### Create Dockerfile
In `~/project/srcs/requirements/wordpress`
```Dockerfile
FROM alpine:3.18.4
# latest stable php for now 8.2, but it is written 82
ARG PHP_VERSION=82 \
	# Neded to setup connection to the database
    DB_ROOT \
    DB_USER \
    DB_PASS \
    # Wordpress users data
    WP_ADMIN \
    WP_ADMIN_PASS \
    WP_ADMIN_MAIL \
    WP_USER \
    WP_USER_PASS \
    WP_USER_MAIL
# required modules for wordpress
RUN apk update && apk upgrade && apk add --no-cache \
	# The PHP interpreter itself
	php${PHP_VERSION} \
	# FastCGI process manager for PHP. Needed for nginx
    php${PHP_VERSION}-fpm \
	# Used for interacting with MySQL databases using the improved MySQLi extension.
	# Essential for WordPress to communicate with the MySQL
    php${PHP_VERSION}-mysqli \
	# Provides functions for encoding and decoding JSON data, which is used by WP
    php${PHP_VERSION}-json \
	# Allows PHP to make HTTP requests using the cURL library.
    php${PHP_VERSION}-curl \
	# Provides functions for working with the Document Object Model (DOM).
	# Essential for manipulating XML and HTML documents
    php${PHP_VERSION}-dom \
	# Allows reading and manipulating metadata from image files.
    php${PHP_VERSION}-exif \
	# Provides functions for determining the file type of a file or a stream.
	# Useful for identifying the MIME type and handle file-related operations.
    php${PHP_VERSION}-fileinfo \
	# Supports handling multibyte charars (because internet is not ascii-only thing)
    php${PHP_VERSION}-mbstring \
	# Allows PHP to interact with the OpenSSL library (https, certificates ...)
    php${PHP_VERSION}-openssl \
	# Provides functions for parsing and manipulating XML documents.
    php${PHP_VERSION}-xml \
	# Allows PHP to work with ZIP archives.
    php${PHP_VERSION}-zip \
    # PHP Archive (phar) manager. Needed to install wp-cli
    php${PHP_VERSION}-phar \
	# Interface to communicate with Redis, an in-memory data structure store (bonus)
    php${PHP_VERSION}-redis \
    wget \
	unzip

COPY requirements/tools/confedit.sh .
```
fix php-fpm config in-place and create symlinks for php82->php, because wp-cli is version-agnostic, and refers to php binary as "php" and not php82, as it is called by default
```Dockerfile
# The address on which to accept FastCGI requests
RUN sh confedit.sh "listen =" 9000  /etc/php82/php-fpm.d/www.conf " " && \
	# create links
	ln -s /usr/bin/php${PHP_VERSION} /usr/bin/php
```
The [`WORKDIR`](https://docs.docker.com/engine/reference/builder/#workdir) instruction sets the working directory for any `RUN`, `CMD`, `ENTRYPOINT`, `COPY` and `ADD` instructions that follow it in the `Dockerfile`.
**/var/www** - is a default location where php-fpm will look for php files
```Dockerfile
WORKDIR /var/www
```
Install wordpress and remove archive
```Dockerfile
RUN wget https://wordpress.org/latest.zip && \
    unzip latest.zip && \
    cp -rf wordpress/* . && \
    rm -rf wordpress latest.zip
```
Install WP-CLI, to be able to initialize website automatically, move to `/bin` and make accessible as `wp`
```Dockerfile
RUN wget https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar && \
    chmod +x wp-cli.phar && \
    mv wp-cli.phar /usr/local/bin/wp
```
Cleanup
```Dockerfile
RUN apk del wget && \
	apk del unzip && \
	apk cache clean
```
Define WP config with database connection details, etc
```Dockerfile
COPY ./requirements/wordpress/conf/wp-config-create.sh .
RUN sh wp-config-create.sh && rm wp-config-create.sh && chmod -R 0777 wp-content/
```
Create wp-cli core initializing script and entrypoint script
```Dockerfile
COPY ./requirements/wordpress/tools/make_wp_core_install_script.sh .
RUN sh make_wp_core_install_script.sh && rm make_wp_core_install_script.sh
```
Execute preconfiguration script and start php-fpm. `CMD` gets actually appended to `ENTRYPOINT`, so in fact, container starts with `sh entrypoint.sh /usr/sbin/php-fpm82 -F` command
```Dockerfile
ENTRYPOINT ["sh", "entrypoint.sh"]
CMD ["/usr/sbin/php-fpm82", "-F"]
```
### Create config [`wp-config-create.sh`](https://developer.wordpress.org/advanced-administration/before-install/howto-install/#detailed-step-3)
Here, the idea is similar to [[README#Script to create DB `create_db.sh`]] - but the output with expanded variables redirected to the file `wp-config.php`, that will be used to connect to the database, etc..
In `~/project/srcs/requirements/wordpress/conf`
```bash
#!bin/sh

if [ ! -f "/var/www/wp-config.php" ]; then
cat << EOF > /var/www/wp-config.php
<?php
define( 'DB_NAME', '${DB_NAME}' );
define( 'DB_USER', '${DB_USER}' );
define( 'DB_PASSWORD', '${DB_PASS}' );
define( 'DB_HOST', 'mariadb' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
define('FS_METHOD','direct');
\$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
if ( ! defined( 'ABSPATH' ) ) {
define( 'ABSPATH', __DIR__ . '/' );}
define( 'WP_REDIS_HOST', 'redis' );
define( 'WP_REDIS_PORT', 6379 );
define( 'WP_REDIS_TIMEOUT', 1 );
define( 'WP_REDIS_READ_TIMEOUT', 1 );
define( 'WP_REDIS_DATABASE', 0 );
require_once ABSPATH . 'wp-settings.php';
EOF
fi
```
And here is how `wp-config.php` looks after variable expansion:
```php
<?php
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'wpuser' );
define( 'DB_PASSWORD', 'wppass' );
define( 'DB_HOST', 'mariadb' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );
define('FS_METHOD','direct');
$table_prefix = 'wp_';
define( 'WP_DEBUG', false );
if ( ! defined( 'ABSPATH' ) ) {
define( 'ABSPATH', __DIR__ . '/' );}
define( 'WP_REDIS_HOST', 'redis' );
define( 'WP_REDIS_PORT', 6379 );
define( 'WP_REDIS_TIMEOUT', 1 );
define( 'WP_REDIS_READ_TIMEOUT', 1 );
define( 'WP_REDIS_DATABASE', 0 );
require_once ABSPATH . 'wp-settings.php';
```
### Create `make_wp_core_install_script.sh`
Here's almost the same, but this file is used to generate other two scripts:
1. `wp_core_install` to actually perform creation of 2 users with credentials
2. `entrypoint` to run the first script, then delete it (because it contains user credentials including passwords in unencrypted form) and execute the main service, which will be `/usr/sbin/php-fpm82`
In ``~/project/srcs/requirements/wordpress/tools`
```bash
#!/bin/sh

cat >> wp_core_install.sh << EOF
#!/bin/sh
wp_admin='${WP_ADMIN}'
wp_admin_pass='${WP_ADMIN_PASS}'
wp_admin_mail='${WP_ADMIN_MAIL}'

wp_user='${WP_USER}'
wp_user_pass='${WP_USER_PASS}'
wp_user_mail='${WP_USER_MAIL}'

if ! wp core is-installed; then
    wp core install \
        --url="https://localhost:42443" \
        --title="Inception" \
        --admin_user="\$wp_admin" \
        --admin_password="\$wp_admin_pass" \
        --admin_email="\$wp_admin_mail"

    wp user create \
        "\$wp_user" \
	"\$wp_user_mail" \
	--user_pass="\$wp_user_pass"
fi
EOF

cat >> entrypoint.sh << EOF
#!/bin/sh

sh wp_core_install.sh
rm wp_core_install.sh
exec "\$@"

EOF

chmod +x wp_core_install.sh entrypoint.sh
```
The multi-step expansion is needed, because all the sensitive data are defined in the dockerfile as `ARG` - which means that it will exist only in the temporary build-time images, and will not be present in the runtime.
However, we need some of this data in the runtime, because user creation operations involve modifying the database, which in the build time won't be up.
So in order to sneak needed date into run-time-init operations the temporary script file `wp_core_install.sh` is made. The variables are expanded in the build time into `wp_core_install.sh` file, which should be executed right after container's startup and removed before the start of container's main service.
```bash
#!/bin/sh
wp_admin='wproot'
wp_admin_pass='wprootpass'
wp_admin_mail='planesvvalker@gmail.com'

wp_user='rokupin'
wp_user_pass='rokupinpass'
wp_user_mail='rokupin@student.42.fr'

if ! wp core is-installed; then
    wp core install \
        --url="https://localhost:42443" \
        --title="Inception" \
        --admin_user="$wp_admin" \
        --admin_password="$wp_admin_pass" \
        --admin_email="$wp_admin_mail"

    wp user create \
        "$wp_user" \
	"$wp_user_mail" \
	--user_pass="$wp_user_pass"
fi
```
And that's what `entrypoint.sh` file is made for. At the container's `ENTRYPOINT`, the following script get's executed. 
- executes `wp_core_install`
- immediately removes it, because data in `wp_core_install` is a security hole
- starts container's `CMD` - that get's appended as argument 
```bash
#!/bin/sh

sh wp_core_install.sh
rm wp_core_install.sh
exec "$@"
```
## [Nginx](https://www.nginx.com/resources/glossary/nginx/)
### Create Dockerfile
In `~/project/srcs/requirements/nginx/`

The [`FROM`](https://docs.docker.com/engine/reference/builder/#from) instruction specifies the [_Parent Image_](https://docs.docker.com/glossary/#parent-image) from which you are building.
```Dockerfile
# Normally alpine:latest, but "latest" is forbidden in subject
FROM alpine:3.18.4
```
The [`RUN`](https://docs.docker.com/engine/reference/builder/#run) instruction will execute any commands in a new layer on top of the current image and commit the results. The resulting committed image will be used for the next step in the `Dockerfile`.
```Dockerfile
# Install nginx, "--no-cache" to reduce size
RUN	apk update && apk upgrade && apk add --no-cache nginx
```

```Dockerfile
EXPOSE 443
```
The main purpose of a [`CMD`](https://docs.docker.com/engine/reference/builder/#cmd) is to provide defaults for an executing container
```Dockerfile
# Starting nginx in non-daemon mode, so we can see logs directly in container's tty
CMD ["nginx", "-g", "daemon off;"]
```
### Create config `nginx.conf`
Inside container - config will be mounted to `/etc/nginx/http.d/` - the reserved directory that in turn gets included in the main config, created during instalation `/etc/nginx/nginx.conf` 
```nginx
...
	# Includes virtual hosts configs.
	include /etc/nginx/http.d/*.conf;
```

In `~/project/srcs/requirements/nginx/conf`
#### Basics
```nginx
server {
    # Listen on port 443 (HTTPS) with SSL enabled
    listen      443 ssl;
	# Define the server names (domain) for this configuration
    server_name  rokupin.42.fr www.rokupin.42.fr;
    # Set the root directory for the website
    root    /var/www/;
    index index.php;
```
#### Tweaking SSL
SSL sessions are used to store the state of a client-server interaction securely. 
- After 10 minutes of inactivity, the `ssl_session_timeout` will expire, requiring a new SSL handshake. This helps manage server resources and enhances security.
- `keepalive_timeout` sets the maximum time a connection is kept open between the client and the server. In this case, it's set to 60 seconds. Keeping connections alive reduces the overhead of establishing new connections for subsequent requests from the same client
```nginx
	# Set the SSL certificate file
    ssl_certificate     /etc/nginx/ssl/rokupin.42.fr.crt;
    # Set the SSL certificate key file 
    ssl_certificate_key /etc/nginx/ssl/rokupin.42.fr.key;
    # Define supported SSL/TLS protocols (subj requirement)
    ssl_protocols            TLSv1.2 TLSv1.3;
    # Set the SSL session timeout to 10 minutes
    ssl_session_timeout 10m;
    # Set the keep-alive timeout for connections
    keepalive_timeout 60;
```
#### Root location
Handles requests when the URI matches the root path - requests made to the main domain or the default path of the website. Such as:
1. *Direct Access to the Root Path*: like https://rokupin.42.fr/
2. *Requests for Static Files in root directory*: like https://rokupin.42.fr/logo.jpg
3. *Fallback for PHP Processing:* If the attempt to serve a static file directly fails, the `try_files $uri /index.php?$args;` line rewrites the request to "/index.php" with any query parameters appended. This directive is essential for WordPress ensuring that pretty permalinks and other  features work as expected.
```nginx
    location / {
	# Attempt to serve the requested URI directly if fails rewrite the request to "/index.php" with any query parameters ($args) appended.
        try_files $uri /index.php?$args;
```
##### Cache control
Instructions needed to prevent users of seeing outdated versions of pages, especially when content changes frequently. These directives are common in configurations for dynamic sites like those powered by WordPress, to ensure that users always receive the latest content.
```nginx
	# Add a Last-Modified header to the response using the $date_gmt variable.
        add_header Last-Modified $date_gmt;
    # Set the Cache-Control header to 'no-store, no-cache' instructing clients not to store or cache the response.
        add_header Cache-Control 'no-store, no-cache';
    # Disable the If-Modified-Since header, preventing conditional requests based on modification time.
        if_modified_since off;
    # Disable the Expires header, indicating that the response should not be cached based on time.
        expires off;
	# Disables the ETag header, which is another mechanism for cache validation.
        etag off;
    }
```
#### PHP location
Handles requests ending with *.php* with forwarding to FastCGI server. 
```nginx
    location ~ \.php$ {
    # Split the path info into script filename, and the path info.
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
    # Forward the request to a FastCGI server (wordpress port 9000)
        fastcgi_pass wordpress:9000;
    # Default index file for FastCGI requests.
        fastcgi_index index.php;
    # Set params to tweak nginx-fastcgi communication
        include fastcgi_params;
	    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
```

# Build and Run
## Create a `docker-compose.yml`
In `~/project/srcs`
```yaml
version: '3'

services:
  nginx:
    build:
      context: .
      dockerfile: requirements/nginx/Dockerfile
    container_name: nginx
    depends_on:
      - wordpress
    ports:
      - "443:443"
    networks:
      - inception
    volumes:
      - ./requirements/nginx/conf/:/etc/nginx/http.d/
      - ./requirements/nginx/tools:/etc/nginx/ssl/
      - wp-volume:/var/www/
    restart: always

  mariadb:
    build:
      context: .
      dockerfile: requirements/mariadb/Dockerfile
      args:
        DB_NAME: ${DB_NAME}
        DB_USER: ${DB_USER}
        DB_PASS: ${DB_PASS}
        DB_ROOT: ${DB_ROOT}
    container_name: mariadb
    ports:
      - "3306:3306"
    networks:
      - inception
    volumes:
      - db-volume:/var/lib/mysql
    restart: always

  wordpress:
    build:
      context: .
      dockerfile: requirements/wordpress/Dockerfile
      args:
	    DB_NAME: ${DB_NAME}
            DB_ROOT: ${DB_ROOT}
            DB_USER: ${DB_USER}
	    DB_PASS: ${DB_PASS}
            WP_ADMIN: ${WP_ADMIN}
	    WP_ADMIN_PASS: ${WP_ADMIN_PASS}
	    WP_ADMIN_MAIL: ${WP_ADMIN_MAIL}
	    WP_USER: ${WP_USER}
	    WP_USER_PASS: ${WP_USER_PASS}
	    WP_USER_MAIL: ${WP_USER_MAIL}
    container_name: wordpress
    depends_on:
      - mariadb
    networks:
      - inception
    volumes:
      - wp-volume:/var/www/
          restart: always

volumes:
  wp-volume:
    driver_opts:
      o: bind
      type: none
      device: /home/${USER}/data/wordpress

  db-volume:
    driver_opts:
      o: bind
      type: none
      device: /home/${USER}/data/mariadb

networks:
    inception:
        driver: bridge
```
## Create a `Makefile` 
### Create script checking required directories `make_dir.sh`
In `~/project/srcs/requirements/tools`
```bash
#!/bin/bash

if [ ! -d "/home/${USER}/data" ]; then
        mkdir ~/data
        mkdir ~/data/mariadb
        mkdir ~/data/wordpress
fi
```

### Makefile itself
In `~/project`
#### all (up)
Container's name
```make
name = inception

all:
```
Run script to make directories if they don't exist
```make
	@bash srcs/requirements/tools/make_dir.sh
```
Start container that was already built
- *-f ./docker-compose.yml*: Docker-compose with specified config
- *--env-file srcs/.env*: Specify an environment file from which Docker Compose will load environment variables by address relative to the current working directory. 
- **up**: start the services defined in the Compose file.
- *-d*: This flag tells Docker Compose to run the services in detached mode, meaning they run in the background, and you get your terminal prompt back. This is useful for running services without locking up the terminal.
```
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up -d
```
#### build
*--build*: This flag tells Docker Compose to rebuild the images for the services defined in the Compose file, even if they already exist. It ensures that the images are latest based on any changes in project.
```make
build:
	@bash srcs/requirements/wordpress/tools/make_dir.sh
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up -d --build
```
#### down
*down*: stop the services defined in the Compose file.
```make
down:
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env down
```
Stop, rebuild and launch
```
re:	down
	@docker-compose -f ./srcs/docker-compose.yml --env-file srcs/.env up -d --build
```
#### clean
*prune -a*: is used to remove all stopped containers, all networks not used by at least one container, and all images without at least one container associated with them
```make
clean: down
	@docker system prune -a
```
Remove everything from WP and DB data folders
```make
	@sudo rm -rf ~/data/wordpress/*
	@sudo rm -rf ~/data/mariadb/*
```
The command `docker stop $$(docker ps -qa)` is a shell command that stops all running Docker containers.
	1. `docker ps -qa`: This part of the command lists all containers, whether they are running or stopped, and provides their container IDs. The `-q` option stands for "quiet," which only displays the numeric IDs of the containers, and the `-a` option includes all containers. 
	2. `$$(...)`: The `$(...)` syntax is used for command substitution in shell scripts. It allows you to capture the output of the enclosed command and use it as a value. In this case, the command substitution captures the container IDs of all containers, whether running or stopped.
	3.  `docker stop $(...)`: This part of the command uses the output of the command substitution to stop the containers. It essentially runs the `docker stop` command with the list of container IDs obtained from the `docker ps -qa` command.
#### fclean
Then cleanup all data of Docker, WP and DB
 ```make
fclean:
	@docker stop $$(docker ps -qa)
	@docker system prune --all --force --volumes
	@docker network prune --force
	@docker volume prune --force
	@sudo rm -rf ~/data/wordpress/*
	@sudo rm -rf ~/data/mariadb/*
```
# How it works
Or what will happen when I'll type `make`?
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
