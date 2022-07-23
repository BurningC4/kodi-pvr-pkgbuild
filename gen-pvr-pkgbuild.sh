#!/bin/bash

pushd $(dirname "$(realpath "${BASH_SOURCE[0]}")") > /dev/null

mkdir temp
KODI_RELEASE=$(curl -s -H "Accept: application/vnd.github.v3+json" 'https://api.github.com/repos/xbmc/xbmc/releases/latest' | jq -r .target_commitish)
echo "Latest Kodi release is $KODI_RELEASE"
curl -s -H "Accept: application/vnd.github.v3+json" -o temp/repos.json https://api.github.com/orgs/kodi-pvr/repos

for REPONAME in $(cat temp/repos.json | jq -r .[].name | grep -v "pvr-scripts") ; do
  DESCRIPTION=$(cat temp/repos.json | jq -r ".[] | select(.name == \"$REPONAME\") | .description" | sed "s/http.*//g" | sed "s/[ \t]*$//g")
  PKGNAME=kodi-addon-$(echo $REPONAME | sed "s/\./-/g")
  GITVER=$(curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/kodi-pvr/$REPONAME/branches | jq -r ".[] | select(.name == \"$KODI_RELEASE\") | .commit.sha")
  OLD_GITVER=$(curl -sL https://github.com/BurningC4/kodi-pvr-pkgbuild/raw/release/$PKGNAME/PKGBUILD | grep source | grep https | sed "s/.*archive\///g" | sed "s/\.tar.gz.*//g")
  if [[ $GITVER ]];then
    if [[ $OLD_GITVER != $GITVER ]]; then
      mkdir -p temp/$PKGNAME
      sudo touch temp/$PKGNAME/{PKGVER,PKGREL}
      PKGVER=$(curl -sL https://github.com/kodi-pvr/$REPONAME/raw/$KODI_RELEASE/$REPONAME/addon.xml.in | grep "\s\sversion=" | sed "s/.*=\"//g" | sed "s/\".*//g")
      echo $PKGVER > temp/$PKGNAME/PKGVER
      echo "$PKGNAME has new version!"
      OLD_PKGVER=$(curl -sL https://github.com/BurningC4/kodi-pvr-pkgbuild/raw/release/$PKGNAME/PKGBUILD | grep "pkgver=" | sed "s/pkgver=//g")
      if [[ $PKGVER == $OLD_PKGVER ]]; then
        OLD_PKGREL=$(curl -sL https://github.com/BurningC4/kodi-pvr-pkgbuild/raw/release/$PKGNAME/PKGBUILD | grep "pkgrel=" | sed "s/pkgrel=//g")
        PKGREL=$(($OLD_PKGREL+1))
        echo $PKGREL > temp/$PKGNAME/PKGREL
      else
        PKGREL=1
        echo $PKGREL > temp/$PKGNAME/PKGREL
      fi
    else
      echo "$PKGNAME is up to date!"
      PKGREL=$OLD_PKGREL
      echo $PKGREL > temp/$PKGNAME/PKGREL
    fi
    mkdir -p release/$PKGNAME
    curl -sLo temp/$PKGNAME/$REPONAME.tar.gz https://github.com/kodi-pvr/"$REPONAME"/archive/"$GITVER".tar.gz
    SHA512=$(sha512sum temp/$PKGNAME/$REPONAME.tar.gz | sed "s/  .*//g")
  else
    echo "$REPONAME has no branch for KODI $KODI_RELEASE. Won't generate/upgrade and will be deleted."
    continue
  fi
  PKGVER=$(cat temp/$PKGNAME/PKGVER)
  PKGREL=$(cat temp/$PKGNAME/PKGREL)
  echo $PKGNAME now $PKGVER-$PKGREL
  cat PKGBUILD.txt | sed "s/_PKGNAME_/$PKGNAME/g" | sed "s/_PKGVER_/$PKGVER/g" | sed "s/_PKGREL_/$PKGREL/g" | sed "s/_DESCRIPTION_/$DESCRIPTION/g" | sed "s/_REPONAME_/$REPONAME/g" | sed "s/_GITVER_/$GITVER/g" | sed "s/_SHA512_/$SHA512/g" > release/$PKGNAME/PKGBUILD
done
ls -R temp
popd > /dev/null
