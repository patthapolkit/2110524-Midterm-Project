#!/bin/bash

# Update and install dependencies
sudo apt update && sudo apt upgrade -y
sudo apt install -y apache2 unzip curl wget php8.3 php8.3-cli php8.3-common php8.3-mysql php8.3-xml php8.3-gd php8.3-curl php8.3-mbstring php8.3-zip libapache2-mod-php8.3 mariadb-client

# Download and extract WordPress
cd /var/www/html
sudo curl -O https://wordpress.org/latest.zip
sudo unzip latest.zip
sudo mv wordpress/* .
sudo rm -rf wordpress latest.zip

# Set correct permissions
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Configure Apache Virtual Host for WordPress
sudo tee /etc/apache2/sites-available/wordpress.conf > /dev/null <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
</VirtualHost>
EOF

# Enable the WordPress site and Apache rewrite module
sudo a2ensite wordpress
sudo a2enmod rewrite
sudo systemctl restart apache2

# Install WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

# Wait for the MariaDB server to be available
sleep 3m

# Configure WordPress Database Connection
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sudo sed -i "s/database_name_here/${db_name}/" /var/www/html/wp-config.php
sudo sed -i "s/username_here/${db_user}/" /var/www/html/wp-config.php
sudo sed -i "s/password_here/${db_pass}/" /var/www/html/wp-config.php
sudo sed -i "s/localhost/${db_host}/" /var/www/html/wp-config.php

# Add AWS S3 configuration in wp-config.php
sudo tee -a /var/www/html/wp-config.php > /dev/null <<EOF

/** AWS S3 Config for WP Offload Media */
define('AS3CF_SETTINGS', serialize(array(
    'provider' => 'aws',
    'access-key-id' => '${s3_access_key}',
    'secret-access-key' => '${s3_secret_key}',
    'bucket' => '${s3_bucket}',
    'region' => '${s3_region}',
)));
EOF

# Run WordPress Installation
sudo -u www-data wp core install --url="${public_ip}" --admin_user="${admin_user}" --admin_password="${admin_pass}" --admin_email="example@example.com" --title="Cloud" --skip-email --path=/var/www/html

# Install WP Offload Media plugin
sudo -u www-data wp plugin install amazon-s3-and-cloudfront --activate --path=/var/www/html

sudo systemctl enable apache2
sudo systemctl restart apache2

echo "WordPress installation completed"
