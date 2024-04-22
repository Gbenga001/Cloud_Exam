# HHOW TO DEVELOP A REUSABLE AND READABLE BASH SCRIPT ON THE "MASTER" NODE TO AUTOMATE THE DEPLOYMENT OF A LAMP (LINUX, APACHE, MYSQL, PHP) STACK, INCLUDING CLONING A PHP APPLICATION FROM GITHUB, INSTALLING ALL NECESSARY PACKAGES, AND CONFIGURING APACHE WEB SERVER AND MYSQL, ENSURING EASE OF MAINTENANCE AND FUTURE DEPLOYMENTS#
#!/bin/bash

# Function to handle errors
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Update Linux system
sudo apt update -y || handle_error "Failed to update the system."

# Install Apache web server
sudo apt install apache2 -y || handle_error "Failed to install Apache web server."

# Add PHP ondrej repository
sudo add-apt-repository ppa:ondrej/php --yes || handle_error "Failed to add PHP repository."

# Update repository again
sudo apt update -y || handle_error "Failed to update repository."

# Install PHP 8.2 and necessary extensions
sudo apt install php8.2 php8.2-curl php8.2-dom php8.2-mbstring php8.2-xml php8.2-mysql zip unzip -y || handle_error "Failed to install PHP and extensions."

# Enable rewrite module for Apache
sudo a2enmod rewrite || handle_error "Failed to enable rewrite module for Apache."

# Restart Apache server
sudo systemctl restart apache2 || handle_error "Failed to restart Apache server."

# Install Composer globally
cd /tmp || handle_error "Failed to change directory to /tmp."
sudo curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer || handle_error "Failed to install Composer globally."

# Change directory to /var/www and clone Laravel repository

if [ -d /var/www/laravel ]; then
   echo "deleting existing laravel directory"
   sudo rm -r /var/www/laravel

else
   echo "creating laravel directory"
fi
sudo mkdir /var/www/laravel
sudo chown  -R $USER:$USER /var/www/laravel
cd /var/www/ || handle_error "Failed to change directory to /var/www/."
sudo git clone https://github.com/laravel/laravel.git laravel || handle_error "Failed to clone Laravel repository."

# Set permissions
sudo chown -R $USER:$USER /var/www/laravel || handle_error "Failed to set permissions."

# Install Composer dependencies
cd /var/www/laravel || handle_error "Failed to change directory to /var/www/laravel."
composer install --optimize-autoloader --no-dev --no-interaction || handle_error "Failed to install Composer dependencies."
composer update --no-interaction || handle_error "Failed to update Composer dependencies."

# Copy .env file and set permissions
sudo cp .env.example .env || handle_error "Failed to copy .env file."
sudo chown -R www-data:www-data storage bootstrap/cache || handle_error "Failed to set permissions."

# Configure Apache Virtual Host
sudo tee /etc/apache2/sites-available/latest.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/laravel/resources/views/welcome.blade.php

    <Directory /var/www/laravel>
        AllowOverride All
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/laravel-error.log
    CustomLog \${APACHE_LOG_DIR}/laravel-access.log combined
</VirtualHost>
EOF

# Enable the new Virtual Host and disable the default one
sudo a2ensite latest.conf || handle_error "Failed to enable new Virtual Host."
sudo a2dissite 000-default.conf || handle_error "Failed to disable default Virtual Host."

# Restart Apache server
sudo systemctl restart apache2 || handle_error "Failed to restart Apache server."

# Install MySQL server and client
sudo apt install mysql-server mysql-client -y || handle_error "Failed to install MySQL server and client."

# Start MySQL service
sudo systemctl start mysql || handle_error "Failed to start MySQL service."

# Update .env file with MySQL configuration
sudo cp .env.example .env
sudo chown -R $USER:$USER /var/www/laravel/.env

echo "APP_URL=http://localhost

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD= " >> /var/www/laravel/.env


# Generate Laravel application key
sudo php artisan key:generate || handle_error "Failed to generate application key."

# Create symbolic link for storage
sudo php artisan storage:link || handle_error "Failed to create storage symbolic link."

# Migrate database
sudo php artisan migrate

# Seed database
sudo php artisan db:seed

# Serve page
sudo php artisan serve

# Restart Apache server
sudo systemctl restart apache2

echo "Setup completed successfully!"