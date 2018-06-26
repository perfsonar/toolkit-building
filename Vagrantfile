# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  # Build a build machine as the default
  config.vm.define "ps-toolkit-build-el7", primary: true, autostart: true do |build|
    # set box to official CentOS 7 image
    build.vm.box = "centos/7"
    # explcitly set shared folder to virtualbox type. If not set will choose rsync 
    # which is just a one-way share that is less useful in this context
    build.vm.synced_folder ".", "/vagrant", type: "virtualbox"
    # Set hostname
    build.vm.hostname = "ps-toolkit-build-el7"
    
    # Enable IPv4. Cannot be directly before or after line that sets IPv6 address. Looks
    # to be a strange bug where IPv6 and IPv4 mixed-up by vagrant otherwise and one 
    #interface will appear not to have an address. If you look at network-scripts file
    # you will see a mangled result where IPv4 is set for IPv6 or vice versa
    build.vm.network "private_network", ip: "10.2.2.10"
    
    # Enable IPv6. Currently only supports setting via static IP. Address below in the
    # reserved local address range for IPv6
    build.vm.network "private_network", ip: "fdac:218a:75e5:69c9::b0"
    
    #Disable selinux
    build.vm.provision "shell", inline: <<-SHELL
        sed -i s/SELINUX=enforcing/SELINUX=permissive/g /etc/selinux/config
    SHELL
    
    #reload VM since selinux requires reboot. Requires `vagrant plugin install vagrant-reload`
    build.vm.provision :reload
    
    #Install all requirements and perform initial setup
    build.vm.provision "shell", inline: <<-SHELL
    
        ## install yum dependencies
        yum install -y epel-release
        yum clean all
        yum install -y gcc\
            kernel-devel\
            kernel-headers\
            dkms\
            make\
            bzip2\
            perl\
            mock\
            git\
            rpm-build\
            rpmdevtools\
            httpd\
            createrepo\
            genisoimage\
            yum-utils\
            createrepo\
            mkisofs\
            wget\
            git\
            syslinux\
            isomd5sum
        
        #Setup chroot
        cd /vagrant/scripts
        ./build_chroot.sh /home/vagrant/chroot x86_64 7
    SHELL
  end
end