# Use the official WordPress image from Docker Hub
FROM wordpress:latest

# Copy custom configuration files (if any)
# COPY wp-config.php /var/www/html/

# Ensure the WordPress directory is owned by the right user
RUN chown -R www-data:www-data /var/www/html

# Expose port 80
EXPOSE 80
