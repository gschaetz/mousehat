# Mousehat

This project aims at setting up a linux desktop in an automated fashion.  It is 
currently focused on Debian Linux and GNOME 3 desktop.  

## Getting Started

These instructions will get you a copy of the project up and running on your local machine. The project contains a /testvm directory that will help you setup this project for testing and/or working out of a virtualbox vm.  

## Requirements

1) su to root
2) Install sudo `apt-get install sudo
3) Install ansible `apt-get install ansible`
4) Install git `apt-get install git`
4) Add your user to sudo group `usermod -aG sudo username`
5) Add your user to /etc/sudoers to make it so they don't have a pasword to sudo. Add the following `username ALL=(ALL) NOPASSWD: ALL`
6) You will need to install ansible > 2.7.  On debian the default repo has an older version of ansible that will not work with the custom_role feature.  If you want this feature you will need to install a newer feature.  I tested it on 2.7.9.  

## vmware

1) install vmware tools: `sudo apt-get install open-vm-tools`
2) install vmsare tools desktop: `sudo apt-get install open-vm-tools-desktop`
3) reboot

### Install

1) git clone this repo: `git clone https://github.com/gschaetz/mousehat.git`
2) Use the built in settings to start or build your own off of mousehat/ansible/desktop-ansible/settings
3) Run the desktop setup config.  If you want to supply your own application setting files use the -s flag.  
```
./runplay.sh

./runplay.sh -s /mysettings
```

## Built With

* [Ansible](https://www.ansible.com/) - The automation framework used

## License

This project is licensed under the MIT License - see the LICENSE.MD file for details
