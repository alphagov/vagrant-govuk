#!/bin/bash
set -eu

apt-get -qq update
apt-get -qqy install lxc lxc-templates redir cgroup-lite

if ! which vagrant >/dev/null; then
  VAGRANT_DEB="vagrant_1.6.5_x86_64.deb"
  wget -q https://dl.bintray.com/mitchellh/vagrant/${VAGRANT_DEB}
  dpkg -i ${VAGRANT_DEB}
  sudo -iu vagrant vagrant plugin install vagrant-lxc
  sudo -iu vagrant vagrant plugin install vagrant-cachier
fi
