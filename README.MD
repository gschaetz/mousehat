# Mousehat

This project aims at setting up a linux desktop in an automated fashion.  It is 
currently focused on Debian Linux and GNOME 3 desktop.  

## Getting Started

These instructions will get you a copy of the project up and running on your local machine. The project contains a /testvm directory that will help you setup this project for testing and/or working out of a virtualbox vm.  

### Prerequisites

If you are going to run this in virtualbox you will need to run the following command:

```
vagrant plugin install vagrant-vbguest
```

### Installing in a VM

This section will help you get the project up and running in your VM.   

1) Clone the repo to your local machine:  
```
git@github.com:gschaetz/desktop-ansible.git 
```

2) Copy the example yaml files from (project dir)/destop-ansible-settings/ into a new project if you haven't done so already.  These files are the unique customizations for your desktop.  Example files will work for demo purposes or just to get started.

3) Go to (project dir)/testvm
```
cd (project dir)/testvm
```

4) Install the vagrant plugin if you haven't already
```
vagrant plugin install vagrant-vbguest
```

5) Run vagrant to start the VM 
```
vagrant up
```

6) Go into the VM and go to /home/vagrant/ansible/
```
cd /home/vagrant/ansible/
``

7) Run the desktop setup config.  If you want to supply your own application setting files use the -s flag.  
```
./runplay.sh

./runplay.sh -s /home/.desktop/mysettings
```

8) Restart the VM using vagrant reload for some of the options to take.  Most of these are the GNOME settings.  You do this where your ran vagrant up.
```
vagrant reload
```

### Installing on Native Linux

This section will help you get the project up and running on your Linux desktop.   

1) Update ansible to the latest version some features are not available before 2.4 and debian is still on an older version
```
deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367
sudo apt-get update
sudo apt-get install ansible
```

1) Clone the repo to your local machine:  
```
cd ~
git@github.com:gschaetz/desktop-ansible.git 
```

2) Creata a .desktop folder if it doesn't exist
```
mkdir .desktop
```

3) Copy the example yaml files from (project dir)/destop-ansible-settings/ into a new project if you haven't done so already.  These files are the unique customizations for your desktop.  Example files will work for demo purposes or just to get started.

4) Go into the project directory /home/(user)/desktop-ansible/ansible/
```
cd ~/desktop-ansible/ansible/ 
```

5) Run the desktop setup config.  If you want to supply your own application setting files use the -s flag.  
```
./runplay.sh

./runplay.sh -s /home/.desktop/mysettings
```

## Running the tests

Tests haven't been added yet, but we are looking to these using molecule. 

## Built With

* [Ansible](https://www.ansible.com/) - The automation framework used

## License

This project is licensed under the MIT License - see the LICENSE.MD file for details
