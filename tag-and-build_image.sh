#!/bin/bash
set -e
set -u

#- get the current tag version for this repo from git
#  and increment
VNUM3=$(git tag |  tail -n 1 | sed 's/^.*\..*\.//g')
VNUM3=$((VNUM3 + 1))

#- get the first two version numbers from the aenmd package used
VNUM12=$(grep '^ARG aenmd_pack=' Dockerfile | sed 's/^ARG aenmd_pack=aenmd_//g ; s/\.[0-9]*\.tar\.gz//g')

#- make the new tag
TAG=v"$VNUM12"."$VNUM3"

#- update the git tag
git tag $TAG

#- build image with updated git tag
podman build -t aenmd_cli:$(git tag | tail -n 1) .

#- update the image on ghcr - re-tag
podman tag aenmd_cli:$(git tag | tail -n 1) ghcr.io/kostkalab/aenmd_cli:$(git tag | tail -n 1)

#- update ghcr with the new image
podman login ghcr.io/kostkalab
podman push ghcr.io/kostkalab/aenmd_cli:$(git tag | tail -n 1)