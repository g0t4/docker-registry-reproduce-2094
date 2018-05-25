#!/usr/bin/env zsh

# TODO - commit an image at different steps to freeze filesystem for inspection if I want to see the files, can then auto diff in this script too!

logmd() {
    echo "$@" | highlight --syntax md -O ansi    
}

local repo="busybox"
local tag="latest"

# should just rewrite this script to not use published port on host and just exec in to a dind container
local registry_host_port="5200"
local registry="localhost:$registry_host_port"

local container_name="registry_2094"

logmd "\n## Cleanup before running repro"
rm temp/*.txt
docker image rm $(docker image ls -q reproduce-2094)
docker container rm -vf $container_name

logmd "\n## Launch registry"
docker container run \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -d \
  -p $registry_host_port:5000 \
  --name $container_name \
  registry

local registry_data_directory="/var/lib/registry"
registry_exec() { docker container exec -ti $container_name "$@" }
unset prev_dump
tree_dump_cmd() {
  step="$@" 
  docker container commit $container_name "reproduce-2094:$step"
  current_dump=$(registry_exec tree -ah $registry_data_directory)
  echo $current_dump
  echo $current_dump > "temp/$step.txt"
  registry_exec du -sh $registry_data_directory 
  if [[ -v prev_dump ]]; then
    logmd "### fs changes:"
    diff -y =(echo $prev_dump) =(echo $current_dump)
  fi
  prev_dump=$current_dump
}

logmd "\n## Install tree in registry container"
registry_exec apk add --no-cache tree
tree_dump_cmd "00-new-registry"

source_image=busybox@sha256:186694df7e479d2b8bf075d9e1b1d7a884c6de60470006d572350573bfa6dcd2
logmd "\n## Pull $source_image from docker hub"
docker image pull $source_image 

registry_image="$registry/$repo:$tag"
logmd "\n## Tag as $registry_image"
docker image tag $source_image $registry_image 

logmd "\n## Push $registry_image to local registry"
docker image push $registry_image
tree_dump_cmd "10-after-first-image-push"

#logmd "## Get all layers"
#layers=`curl -s -XGET -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $registry/v2/$repo/manifests/$tag |
#  grep digest  |
#  awk '{ print $2 }' |
#  tr -d '"' `

#logmd "## Delete all layers"
#for l in $layers; do
#  curl -XDELETE -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $registry/v2/$repo/blobs/$l
#done
# tree_dump_cmd "20-after-delete-layers"

# leaving GET to pull digest even though I current explicitly pull busybox by digest and so I have it already... this is if I change that image, I won't get owned nor have to lookup the new digest if I don't want to pull by digest
logmd "\n## Get manifest"
id=`curl -v -s -XGET -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $registry/v2/$repo/manifests/$tag 2>&1 |
  grep 'Docker-Content-Digest' |
  awk '{ print $3 }' |
  tr -cd '[[:alnum:]]:'`

logmd "\n## Delete manifest"
curl -XDELETE -H "Accept: application/vnd.docker.distribution.manifest.v2+json" $registry/v2/$repo/manifests/$id
tree_dump_cmd "30-after-delete-manifest"

logmd "\n## Run garbage collector"
registry_exec registry garbage-collect /etc/docker/registry/config.yml
tree_dump_cmd "40-after-gc"

logmd "\n## Push again to local registry"
docker image push $registry_image
tree_dump_cmd "50-after-second-push" 

logmd "\n## Remove and attempt to pull repushed image"
docker image rm $registry_image
docker image pull $registry_image 


# One approach: restart after GC:
logmd "\n## Restart registry will fix cache invalidation bug so we can push image again"
docker container restart $container_name
tree_dump_cmd "60-after-restart"

logmd "\n## Pushing again, after restart, this should work:"
docker image push $registry_image
tree_dump_cmd "70-after-push-after-restart"

echo