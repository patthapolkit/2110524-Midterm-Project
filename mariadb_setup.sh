#!/bin/bash

sudo apt update && sudo apt upgrade -y
sudo apt install -y curl apt-transport-https

# Add MariaDB repository explicitly for MariaDB 10.11
sudo curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="mariadb-10.11" --os-type=ubuntu --os-version=24.04

# Install MariaDB 10.11
sudo apt install -y mariadb-server

# Start and enable MariaDB service
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Secure MariaDB installation
sudo mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${db_pass}');"
sudo mysql -e "DELETE FROM mysql.user WHERE User='';"
sudo mysql -e "DROP DATABASE IF EXISTS test;"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Create WordPress database and user
sudo mysql -u root -p"${db_pass}" <<EOF
CREATE DATABASE \`${db_name}\`;
CREATE USER '${db_user}'@'%' IDENTIFIED BY '${db_pass}';
GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'%';
FLUSH PRIVILEGES;
EOF

# Allow remote connections
sudo sed -i "s/^bind-address\s*=.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf

# Restart MariaDB to apply changes
sudo systemctl restart mariadb

echo "MariaDB 10.11 setup completed"