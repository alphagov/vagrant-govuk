#!/bin/bash
set -eu

apt-get -qq update
apt-get -qqy install lxc lxc-templates redir cgroup-lite

modprobe ip6_tables
if ! grep -qsx ip6_tables /etc/modules; then
  echo ip6_tables >> /etc/modules
fi

if ! which vagrant >/dev/null; then
  VAGRANT_DEB="vagrant_1.6.5_x86_64.deb"
  wget -q https://dl.bintray.com/mitchellh/vagrant/${VAGRANT_DEB}
  dpkg -i ${VAGRANT_DEB}
  sudo -iu vagrant vagrant plugin install vagrant-lxc
  sudo -iu vagrant vagrant plugin install vagrant-cachier
fi

sudo -iu vagrant bash <<EOS
  if ! grep -qs VAGRANT_DEFAULT_PROVIDER ~/.bashrc; then
    cat <<EOF >> ~/.bashrc

export VAGRANT_DEFAULT_PROVIDER="lxc"
export VAGRANT_GOVUK_NFS="no"
cd /var/govuk/vagrant-govuk
EOF
  fi
EOS
