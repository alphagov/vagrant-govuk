# -*- mode: ruby -*-
# vi: set ft=ruby :

require_relative 'load_nodes'

min_required_vagrant_version = '1.3.0'

# Construct box name and URL from distro and version.
def get_box(dist, version, provider)
  dist    ||= "precise"
  version ||= "20141112"

  if provider == "vmware_fusion"
    name  = "govuk_dev_#{dist}64_vmware_fusion_#{version}"
  else
    name  = "govuk_dev_#{dist}64_#{version}"
  end
  url   = "http://gds-boxes.s3.amazonaws.com/#{name}.box"

  return name, url
end

if Vagrant::VERSION < min_required_vagrant_version
  $stderr.puts "ERROR: Puppet now requires Vagrant version >=#{min_required_vagrant_version}. Please upgrade.\n"
  exit 1
end

nodes = load_nodes()
nodes['lxc'] = {
  'ip'       => '172.16.13.10',
  'memory'   => 1024,
  'box_dist' => 'trusty',
}

Vagrant.configure("2") do |config|
  # Enable vagrant-cachier if available.
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.auto_detect = true
  end

  nodes.each do |node_name, node_opts|
    config.vm.define node_name do |c|
      box_name, box_url = get_box(
        node_opts["box_dist"],
        node_opts["box_version"],
        "virtualbox"
      )
      c.vm.box = box_name
      c.vm.box_url = box_url
      c.vm.hostname = "#{node_name}.development"
      c.vm.network :private_network, {
        :ip => node_opts["ip"],
        :netmask => "255.255.000.000"
      }

      c.vm.provider(:virtualbox) { |vb|
        vb.customize([
          'modifyvm', :id,
          # Mitigate boot hangs.
          "--rtcuseutc", "on",
          # Isolate guests from host networking.
          "--natdnsproxy1", "on",
          "--natdnshostresolver1", "on",
        ])

        if node_opts.has_key?("memory")
          vb.memory = node_opts["memory"]
        end
      }

      c.vm.provider(:vmware_fusion) do |vf, override|
        if node_opts.has_key?("memory")
          vf.vmx["memsize"] = node_opts["memory"]
        end
        vf.vmx["displayName"] = node_name
        override.vm.box, override.vm.box_url = get_box(
          node_opts["box_dist"],
          node_opts["box_version"],
          "vmware_fusion"
        )
      end

      if ENV['VAGRANT_GOVUK_NFS'] == "no"
        c.vm.synced_folder "..", "/var/govuk"
      else
        c.vm.synced_folder "..", "/var/govuk", :nfs => true
      end

      # These can't be NFS because OSX won't export overlapping paths.
      c.vm.synced_folder "../puppet/gpg", "/etc/puppet/gpg"
      # Additional shared folders for Puppet Master nodes.
      if node_name =~ /^puppetmaster/
        c.vm.synced_folder "../puppet", "/usr/share/puppet/production/current"
      end

      if node_name == 'lxc'
        c.vm.provision :shell, :inline => "/vagrant/scripts/bootstrap_lxc_host.sh"
      else
        # run a script to partition extra disks for lvm if they exist.
        c.vm.provision :shell, :inline => "/var/govuk/puppet/tools/partition-disks"
        c.vm.provision :shell, :inline => "ENVIRONMENT=vagrant /var/govuk/puppet/tools/puppet-apply #{ENV['VAGRANT_GOVUK_PUPPET_OPTIONS']}"
      end
    end
  end
end
