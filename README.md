### React Product App using Spring Boot as the backend
![alt text](react-product-app.avif)

## Run locally with Docker

    docker compose up --build

## Run locally with Podman

    podman compose --file docker-compose.yml up --detach --build

Frontend: http://localhost:3000, backend: http://localhost:8080/api/products.

## Database migration

The backend now uses MariaDB instead of MySQL. For existing deployments, use a MariaDB server and change `SPRING_DATASOURCE_URL` from `jdbc:mysql://...` to `jdbc:mariadb://<host>:3306/<database>`. Set `SPRING_DATASOURCE_USERNAME` and `SPRING_DATASOURCE_PASSWORD` for that database. The Compose configuration already includes these settings. Use the `mariadb` client for SQL commands; the container data directory remains `/var/lib/mysql`.
