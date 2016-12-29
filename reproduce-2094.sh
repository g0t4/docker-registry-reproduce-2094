#!/bin/sh

repo="alpine"
tag="latest"

echo "===== Launch registry ====="
docker run -e REGISTRY_STORAGE_DELETE_ENABLED=true -d --net=dev -p 5000:5000 --name registry_2094 registry

echo "===== Install tree in registry container ====="
docker exec -ti registry_2094 apk add --no-cache tree

docker exec -ti registry_2094 tree /var/lib/registry

echo "===== Pull alpine:latest from docker hub ====="
docker pull alpine:latest

echo "===== Retag alpine:latest from docker hub ====="
docker tag alpine:latest localhost:5000/$repo:$tag

echo "===== Push alpine:latest to local registry ====="
docker push localhost:5000/$repo:$tag

docker exec -ti registry_2094 tree /var/lib/registry
docker exec -ti registry_2094 du -sh /var/lib/registry

echo "===== Get all layers ====="
layers=`curl -s -XGET -H "Accept: application/vnd.docker.distribution.manifest.v2+json" localhost:5000/v2/$repo/manifests/$tag |
  grep digest  |
  awk '{ print $2 }' |
  tr -d '"' `

echo "===== Delete all layers ====="
for l in $layers; do
  curl -XDELETE -H "Accept: application/vnd.docker.distribution.manifest.v2+json" localhost:5000/v2/$repo/blobs/$l
done

docker exec -ti registry_2094 tree /var/lib/registry

echo "===== Get manifest ====="
id=`curl -v -s -XGET -H "Accept: application/vnd.docker.distribution.manifest.v2+json" localhost:5000/v2/$repo/manifests/$tag 2>&1 |
  grep 'Docker-Content-Digest' |
  awk '{ print $3 }' |
  tr -cd '[[:alnum:]]:'`

echo "===== Delete manifest ====="
curl -XDELETE -H "Accept: application/vnd.docker.distribution.manifest.v2+json" localhost:5000/v2/$repo/manifests/$id

docker exec -ti registry_2094 tree /var/lib/registry

echo "===== Run garbage collector ====="
docker exec -ti registry_2094 registry garbage-collect /etc/docker/registry/config.yml

docker exec -ti registry_2094 tree /var/lib/registry

docker exec -ti registry_2094 du -sh /var/lib/registry

echo "===== Push alpine:latest to local registry ====="
docker push localhost:5000/$repo:$tag

docker exec -ti registry_2094 tree /var/lib/registry

docker pull localhost:5000/$repo:$tag
