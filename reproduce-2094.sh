#!/bin/sh

repo="busybox"
tag="latest"

registry_host_port="5000"
registry="localhost:$registry_host_port"

container_name="registry_2094"
echo "===== Launch registry ====="
docker container rm -vf $container_name
docker container run \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -d \
  --net=dev \
  -p $registry_host_port:5000 \
  --name $container_name \
  registry

registry_data_directory="/var/lib/registry"
registry_exec() { docker container exec -ti $container_name "$@" }
tree_dump_cmd() { 
  registry_exec tree -ah $registry_data_directory
  registry_exec du -sh $registry_data_directory 
}

echo "===== Install tree in registry container ====="
registry_exec apk add --no-cache tree
tree_dump_cmd

source_image=busybox@sha256:186694df7e479d2b8bf075d9e1b1d7a884c6de60470006d572350573bfa6dcd22
echo "===== Pull $source_image from docker hub ====="
docker image pull $source_image 

registry_image="$registry/$repo:$tag"
echo "===== Tag as $registry_image ====="
docker image tag $source_image $registry_image 

echo "===== Push $registry_image to local registry ====="
docker image push $registry_image
tree_dump_cmd

#echo "===== Get all layers ====="
#layers=`curl -s -XGET -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $registry/v2/$repo/manifests/$tag |
#  grep digest  |
#  awk '{ print $2 }' |
#  tr -d '"' `

#echo "===== Delete all layers ====="
#for l in $layers; do
#  curl -XDELETE -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $registry/v2/$repo/blobs/$l
#done
# tree_dump_cmd

echo "===== Get manifest ====="
id=`curl -v -s -XGET -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $registry/v2/$repo/manifests/$tag 2>&1 |
  grep 'Docker-Content-Digest' |
  awk '{ print $3 }' |
  tr -cd '[[:alnum:]]:'`

echo "===== Delete manifest ====="
curl -XDELETE -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $registry/v2/$repo/manifests/$id
tree_dump_cmd

echo "===== Run garbage collector ====="
registry_exec registry garbage-collect /etc/docker/registry/config.yml
tree_dump_cmd

echo "===== Push again to local registry ====="
docker image push $registry_image
tree_dump_cmd 

echo "===== Remove and attempt to pull repushed image ====="
docker image rm $registry_image
docker image pull $registry_image 
