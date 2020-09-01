#!/bin/bash

if [ $# != 2 ]; then
  echo "Invalid Argment."
  echo " You need to specify the version number. (like 0.0.1)"
  echo " You need to specify Architect. (like armhf, amd64)"
  exit 1
fi

version_no=$1
architect_code=$2

if ! gbp buildpackage -p"$(pwd)"/gpg-passphrase.sh --git-pristine-tar-commit --git-export-dir=../build-area -S -sd;
then
  echo "Retry Over."
  exit 1
fi

# need sudo
if [ "$architect_code" = "armhf" ]; then
  sudo OS=raspbian DIST=buster ARCH=armhf pbuilder --build ../build-area/rdbox_"${version_no}".dsc
elif [ "$architect_code" = "amd64" ]; then
  sudo OS=debian DIST=buster ARCH=amd64 pbuilder --build ../build-area/rdbox_"${version_no}".dsc
elif [ "$architect_code" = "arm64" ]; then
  sudo OS=raspbian DIST=buster ARCH=arm64 pbuilder --build ../build-area/rdbox_"${version_no}".dsc
else
  sudo OS=raspbian DIST=buster ARCH=armhf pbuilder --build ../build-area/rdbox_"${version_no}".dsc
fi

exit 0