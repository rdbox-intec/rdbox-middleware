#!/bin/bash

if [ $# != 3 ]; then
  echo "Invalid Argment."
  echo " You need to specify the version number. (like 0.0.1)"
  echo " You need to specify Architect. (like armhf, amd64)"
  echo " You neet to specify git branch. (like master, feature/app, develop...)"
  exit 1
fi

version_no=$1
architect_code=$2
branch=$3

git pull origin "${branch}"
git checkout "${branch}"
commit_id=$(git rev-parse HEAD)
git archive --format=tar.gz --prefix=rdbox/ -o ../rdbox_"${version_no}".orig.tar.gz "${commit_id}"

cd ../rdbox-middleware-deb/ || exit
git branch --delete dfsg_clean
git branch dfsg_clean upstream
git checkout master
git tag -d upstream/"${version_no}"
gbp import-orig --no-merge -u "${version_no}" --pristine-tar ../rdbox_"${version_no}".orig.tar.gz
git checkout dfsg_clean
git pull --no-edit . upstream
git checkout master
git pull --no-edit . dfsg_clean
rm -rf ../build-area/
if ! gbp buildpackage --git-pristine-tar-commit --git-export-dir=../build-area -S -sd;
then
  echo "Retry Over."
  exit 1
fi

# need sudo
if [ "$architect_code" = "armhf" ]; then
  sudo OS=raspbian DIST=buster ARCH=armhf pbuilder --build ../build-area/rdbox_"${version_no}".dsc
elif [ "$architect_code" = "amd64" ]; then
  sudo OS=debian DIST=buster ARCH=amd64 pbuilder --build ../build-area/rdbox_"${version_no}".dsc
else
  sudo OS=raspbian DIST=buster ARCH=armhf pbuilder --build ../build-area/rdbox_"${version_no}".dsc
fi
