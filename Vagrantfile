Vagrant.configure("2") do |config|
  config.vm.box = "bento/fedora-28"
  
  config.vm.provider "virtualbox" do |vb|
    vb.customize [
      "modifyvm", :id,
      "--cpuexecutioncap", "50",
      "--memory", "4096",
    ]

    vb.customize [
      "setextradata", :id,
      "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"
    ]
  end

  config.vm.provision "shell", path: 'vagrant-config/provision.sh'
end