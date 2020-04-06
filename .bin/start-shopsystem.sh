#!/bin/bash
set -e # Exit with nonzero exit code if anything fails
export WOOCOMMERCE_CONTAINER_NAME=woo_commerce

for ARGUMENT in "$@"; do
  KEY=$(echo "${ARGUMENT}" | cut -f1 -d=)
  VALUE=$(echo "${ARGUMENT}" | cut -f2 -d=)

  case "${KEY}" in
  NGROK_URL) NGROK_URL=${VALUE} ;;
  SHOP_VERSION) WOOCOMMERCE_VERSION=${VALUE} ;;
  *) ;;
  esac
done

export WOOCOMMERCE_ADMIN_USER=admin
export WOOCOMMERCE_ADMIN_PASSWORD=password

docker-compose build --build-arg WOOCOMMERCE_VERSION="${WOOCOMMERCE_VERSION}" web

docker-compose up -d
docker-compose ps

# wordpress running on 9090
while ! $(curl --output /dev/null --silent --head --fail "${NGROK_URL}/wp-admin/install.php"); do
    echo "Waiting for docker container to initialize"
    sleep 5
done

#install wordpress
docker-compose exec web wp core install --allow-root --url="${NGROK_URL}" --admin_password="${WOOCOMMERCE_ADMIN_PASSWORD}" --title=test --admin_user=${WOOCOMMERCE_ADMIN_USER} --admin_email=test@test.com

#activate woocommerce
docker-compose exec web wp plugin activate woocommerce --allow-root

#activate woocommerce-ee
docker-compose exec web wp plugin activate wirecard-woocommerce-extension --allow-root

#install wordpress-importer
docker-compose exec web wp plugin install wordpress-importer --activate --allow-root

#import sample product
docker-compose exec web wp import /var/www/html/wp-content/plugins/woocommerce/sample-data/sample_products.xml --allow-root --authors=create

#activate storefront theme
docker-compose exec web wp theme install storefront --activate --allow-root

#install shop pages
docker-compose exec web wp wc tool run install_pages --user=admin --allow-root
