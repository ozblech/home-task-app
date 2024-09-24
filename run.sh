#!/bin/bash

docker stop mysql_db
docker stop app
docker rm mysql_db || true
docker rm app || true


docker network create test || true

docker run -d --network test -p 3306:3306 --name mysql_db -e MYSQL_ROOT_PASSWORD=root_password -e MYSQL_DATABASE=exampleDb \
 -e MYSQL_USER=flaskapp -e MYSQL_PASSWORD=flaskapp -v $(pwd)/init.sql:/docker-entrypoint-initdb.d/init.sql mysql:5.7 

sleep 20

docker run -it -p 8080:8080 -e DB_HOST=mysql_db -e BACKEND=http://localhost:8080 -e DB_USER=flaskapp \
 -e DB_PASS=flaskapp -e DB_NAME=exampleDb --network test app 
