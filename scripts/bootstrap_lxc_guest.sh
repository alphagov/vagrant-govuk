#!/bin/bash
set -e

. /etc/lsb-release
APT_PL="/etc/apt/sources.list.d/puppetlabs.list"
APT_PPA="/etc/apt/sources.list.d/govuk-ppa.list"
APT_MIRROR="http://apt.production.alphagov.co.uk"

if [ ! -f $APT_PL -o ! -f $APT_PPA ]; then
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EC5FE1A937E3ACBB
  echo "deb [arch=amd64] ${APT_MIRROR}/puppetlabs-${DISTRIB_CODENAME} ${DISTRIB_CODENAME} main" > $APT_PL
  echo "deb [arch=amd64] ${APT_MIRROR}/govuk/ppa/preview ${DISTRIB_CODENAME} main" > $APT_PPA
  apt-get -qq update
fi

if [ ! -f /usr/bin/ruby1.9.1 ]; then
  apt-get -qqy install ruby1.9.3
fi

if [ $(readlink /usr/bin/ruby) != "ruby1.9.1" ]; then
  update-alternatives --set ruby /usr/bin/ruby1.9.1
fi

if [ ! -f /usr/bin/puppet ]; then
  apt-get -qqy install puppet ruby-hiera-eyaml-gpg
fi
