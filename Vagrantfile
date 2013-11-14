require 'json'
require 'yaml'

min_required_vagrant_version = '1.2.3'

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

# Load node definitions from the YAML file used by vcloud-tools
def nodes_from_yaml
  #Expects the yaml definitions to be in the directory below
  yaml_dir = File.expand_path('../../govuk-provisioning/production/vapps_definition/', __FILE__)
  unless File.exists?(yaml_dir)
    puts "Unable to find nodes in 'govuk-provisioning' repo"
    puts
    return {}
  end
  

  yaml_files = Dir.glob(
    File.join(yaml_dir, "*.yaml")
  )

  yaml_nodes = Hash[ yaml_files.flat_map { |yaml_file|
      vapp_sets = YAML::load(File.read(yaml_file))["vdcs"][0]['vapp_sets']
      vapp_sets.map{ |vapp_set|
        
        vapp = vapp_set["vapps"][0]
        zone = vapp["networks"][0].downcase 
        name = vapp["name"] + "."  + zone
        #Build the node, parsing the yam file as required
        node = {}
        node["role"] = "client"
        node["ip"] = vapp["vm"]["network_connections"][0]["ip_address"]
        node["zone"] = zone
        
        if  vapp.has_key?("name")        
            node["vm_name"] = vapp["name"]
        elsif
            puts "No name found"
            next
        end
        node["class"] = vapp["vm"]["bootstrap"]["vars"]["class"]
        if vapp["vm"].has_key?("extra_disks") and !vapp["vm"]["extra_disks"].nil?
            node["extra_disks"] = vapp["vm"]["extra_disks"]
        end
        
        [name, node]
      }
      
    }
  ]
  yaml_nodes
           
end

if Vagrant::VERSION < min_required_vagrant_version
  $stderr.puts "ERROR: Puppet now requires Vagrant version >=#{min_required_vagrant_version}. Please upgrade.\n"
  exit 1
end

Vagrant.configure("2") do |config|
  nodes_from_yaml.each do |node_name, node_opts|
    config.vm.define node_name do |c|
      box_name, box_url = get_box(
        node_opts["box_dist"],
        node_opts["box_version"]
      )
      c.vm.box = box_name
      c.vm.box_url = box_url
      c.vm.hostname = node_name
      c.vm.network :private_network, {
        :ip => node_opts["ip"],
        :netmask => "255.255.000.000"
      }

      modifyvm_args = ['modifyvm', :id]

      # Mitigate boot hangs.
      modifyvm_args << "--rtcuseutc" << "on"

      # Isolate guests from host networking.
      modifyvm_args << "--natdnsproxy1" << "on"
      modifyvm_args << "--natdnshostresolver1" << "on"

      if node_opts.has_key?("memory")
        modifyvm_args << "--memory" << node_opts["memory"]
      end
      
      c.vm.provider(:virtualbox) { |vb| 
        vb.customize(modifyvm_args)
        #Adding some code to check if the VM needs extra disks 
        
        if node_opts.has_key?("extra_disks") and !node_opts["extra_disks"].nil?
            i = 0
            for disk in node_opts["extra_disks"] do
                file_to_disk = "/tmp/exra_disk_" + node_opts["vm_name"] + i.to_s + ".vdi"
                i += 1
                #Default Disk size
                size = 512
        
                vb.customize(['createhd', '--filename', file_to_disk, '--size', size,  "--format", "vdi"])
                vb.customize(['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk])
            end
        end
      }

      c.vm.synced_folder "..", "/var/govuk", :nfs => true
      c.vm.synced_folder "../puppet/extdata", "/tmp/vagrant-puppet/extdata"

      # Additional shared folders for Puppet Master nodes.
      # These can't be NFS because OSX won't export overlapping paths.
      if node_opts["class"] == "puppetmaster" or node_opts["class"] == "puppet"
        c.vm.synced_folder "../puppet", "/usr/share/puppet/production/current"
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
