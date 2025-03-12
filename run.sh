#!/bin/bash

image_name="xuan_shu_technologies"
container_name="xuan_shu_technologies"
host_port=3000
container_port=8080

docker build -t "$image_name" .
docker stop "$container_name" &>/dev/null || true
docker rm "$container_name" &>/dev/null || true

docker run -d -p "$host_port":"$container_port" \
    --add-host=host.docker.internal:host-gateway \
    -v "${image_name}:/app/backend/data" \
    --name "$container_name" \
    --restart always \
    -e NODE_OPTIONS="--max-old-space-size=8192" \
    "$image_name"


docker image prune -f
