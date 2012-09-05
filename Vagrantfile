# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  config.vm.box = "precise64"
  config.vm.host_name = 'coroutine.local'
  config.vm.share_folder "puppet-files", "/etc/puppet/files", "./files"
  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "manifests"
    puppet.module_path = 'modules'
    puppet.manifest_file  = "coroutine.pp"
    puppet.options = ["--fileserverconfig=/vagrant/fileserver.conf"]
  end

end
