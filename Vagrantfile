require 'json'

# Construct box name and URL from distro and version.
def get_box(dist, version)
  dist    ||= "precise"
  version ||= "20130712"

  name  = "govuk_dev_#{dist}64_#{version}"
  url   = "http://gds-boxes.s3.amazonaws.com/#{name}.box"

  return name, url
end

# Load node definitions from the JSON in the vcloud-templates repo parallel
# to this.
def nodes_from_json
  json_dir = File.expand_path("../../vcloud-templates/machines", __FILE__)
  json_local = File.expand_path("../nodes.local.json", __FILE__)

  unless File.exists?(json_dir)
    puts "Unable to find nodes in 'vcloud-templates' repo"
    puts
    return {}
  end

  json_files = Dir.glob(
    File.join(json_dir, "**", "*.json")
  )

  nodes = Hash[
    json_files.map { |json_file|
      node = JSON.parse(File.read(json_file))
      name = node["vm_name"] + "." + node["zone"]

      # Ignore physical attributes.
      node.delete("memory")
      node.delete("num_cores")

      [name, node]
    }
  ]

  # Local JSON file can override node properties like "memory".
  if File.exists?(json_local)
    nodes_local = JSON.parse(File.read(json_local))
    nodes_local.each { |k,v| nodes[k].merge!(v) if nodes.has_key?(k) }
  end

  nodes
end

if Vagrant::VERSION < "1.1.0"
  $stderr.puts "WARNING: Using old Vagrantfile format! Please upgrade to Vagrant >1.1.\n"
  Vagrant::Config.run do |config|
    vagrant_config(config, 1)
  end
else
  Vagrant.configure("2") do |config|
    vagrant_config(config, 2)
  end
end

def vagrant_config(config, version)
  nodes_from_json.each do |node_name, node_opts|
    config.vm.define node_name do |c|
      box_name, box_url = get_box(
        node_opts["box_dist"],
        node_opts["box_version"]
      )
      c.vm.box = box_name
      c.vm.box_url = box_url

      if version < 2
        c.vm.host_name = node_name
      else
        c.vm.hostname = node_name
      end

      if version < 2
        c.vm.network :hostonly,
          node_opts["ip"],
          :netmask => "255.255.000.000"
      else
        c.vm.network :private_network, {
          :ip => node_opts["ip"],
          :netmask => "255.255.000.000"
        }
      end

      modifyvm_args = ['modifyvm', :id]

      # Mitigate boot hangs.
      modifyvm_args << "--rtcuseutc" << "on"

      # Isolate guests from host networking.
      modifyvm_args << "--natdnsproxy1" << "on"
      modifyvm_args << "--natdnshostresolver1" << "on"

      if node_opts.has_key?("memory")
        modifyvm_args << "--memory" << node_opts["memory"]
      end

      if version < 2
        c.vm.customize(modifyvm_args)
      else
        c.vm.provider(:virtualbox) { |vb| vb.customize(modifyvm_args) }
      end

      c.ssh.forward_agent = true

      if version < 2
        c.vm.share_folder "govuk", "/var/govuk", "..", :nfs => true
        c.vm.share_folder "extdata",
          "/tmp/vagrant-puppet/extdata",
          "../puppet/extdata"
      else
        c.vm.synced_folder "..", "/var/govuk", :nfs => true
        c.vm.synced_folder "../puppet/extdata", "/tmp/vagrant-puppet/extdata"
      end

      # Additional shared folders for Puppet Master nodes.
      # These can't been NFS because OSX won't export overlapping paths.
      if node_opts["class"] == "puppetmaster" or node_opts["class"] == "puppet"
        if version < 2
          c.vm.share_folder "pm-puppet",
            "/usr/share/puppet/production/current",
            "../puppet"
        else
          c.vm.synced_folder "../puppet", "/usr/share/puppet/production/current"
        end
      end

      c.vm.provision :puppet do |puppet|
        puppet.manifest_file = "site.pp"
        puppet.manifests_path = "../puppet/manifests"
        puppet.module_path = [
          "../puppet/modules",
          "../puppet/vendor/modules",
        ]
        puppet.options = ["--environment", "vagrant"]
        puppet.facter = {
          :govuk_class => node_opts["class"],
          :govuk_provider => "sky",
          :govuk_platform => "staging",
        }
      end
    end
  end
end
