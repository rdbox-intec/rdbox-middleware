#!/bin/bash

if [ $# != 2 ]; then
  echo "Invalid Argment."
  echo " You need to specify the version number. (like 0.0.1)"
  echo " You need to specify Architect. (like armhf, amd64)"
  exit 1
fi

version_no=$1
architect_code=$2

if [ -z ${BINTRAY_API_GPGKEY+x} ] ; then
  echo "Invalid Environment variable"
  echo " Set the environment variable BINTRAY_API_GPGKEY."
  exit 2
fi

if [ -z ${BINTRAY_API_SECRET+x} ] ; then
  echo "Invalid Environment variable"
  echo " Set the environment variable BINTRAY_API_SECRET."
  echo " It is a string of user name and API key concatenated with :"
  echo " Example: username:APIKEYr0524klolmeodjal44a"
  exit 3
fi

if [ "$architect_code" = "armhf" ]; then
  curl -sX POST -H 'Content-Type: application/json' -H 'cache-control: no-cache' -d '{"name": "v'${version_no}'", "vcs_tag": "v'${version_no}'", "released": "'$(TZ=UTC date +%Y-%m-%dT%H:%M:%S.000Z)'"}' --user "${BINTRAY_API_SECRET}" https://bintray.com/api/v1/packages/rdbox/deb/rdbox-middleware/versions | jq
  curl -sX PUT -T /var/cache/pbuilder/raspbian-buster-armhf/result/rdbox_${version_no}_armhf.deb -H 'X-Bintray-Debian-Distribution: buster' -H 'X-Bintray-Debian-Component: main' -H 'X-Bintray-Debian-Architecture: armhf'  --user "${BINTRAY_API_SECRET}" https://bintray.com/api/v1/content/rdbox/deb/rdbox-middleware/v${version_no}/pool/r/rdbox-middleware/rdbox_${version_no}_armhf.deb | jq
  curl -sX POST -H 'cache-control: no-cache' --user "${BINTRAY_API_SECRET}" https://bintray.com/api/v1/content/rdbox/deb/rdbox-middleware/${version_no}/publish | jq
  curl -sX POST -H "X-GPG-PASSPHRASE: ${BINTRAY_API_GPGKEY}" --user "${BINTRAY_API_SECRET}" https://api.bintray.com/calc_metadata/rdbox/deb/ | jq
elif [ "$architect_code" = "amd64" ]; then
  curl -sX POST -H 'Content-Type: application/json' -H 'cache-control: no-cache' -d '{"name": "v'${version_no}'", "vcs_tag": "v'${version_no}'", "released": "'$(TZ=UTC date +%Y-%m-%dT%H:%M:%S.000Z)'"}' --user "${BINTRAY_API_SECRET}" https://bintray.com/api/v1/packages/rdbox/deb/rdbox-middleware/versions | jq
  curl -sX PUT -T /var/cache/pbuilder/debian-buster-amd64/result/rdbox_${version_no}_amd64.deb -H 'X-Bintray-Debian-Distribution: buster' -H 'X-Bintray-Debian-Component: main' -H 'X-Bintray-Debian-Architecture: amd64'  --user "${BINTRAY_API_SECRET}" https://bintray.com/api/v1/content/rdbox/deb/rdbox-middleware/v${version_no}/pool/r/rdbox-middleware/rdbox_${version_no}_amd64.deb | jq
  curl -sX POST -H 'cache-control: no-cache' --user "${BINTRAY_API_SECRET}" https://bintray.com/api/v1/content/rdbox/deb/rdbox-middleware/${version_no}/publish | jq
  curl -sX POST -H "X-GPG-PASSPHRASE: ${BINTRAY_API_GPGKEY}" --user "${BINTRAY_API_SECRET}" https://api.bintray.com/calc_metadata/rdbox/deb/ | jq
else
  echo "Invalid Architect"
fi