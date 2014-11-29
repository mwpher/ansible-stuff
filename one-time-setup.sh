#!/bin/sh
echo $@ $#

(($# == 2) || exit)

ssh -t ${1}@${2} 'env ASSUME_ALWAYS_YES=YES pkg bootstrap; env ASSUME_ALWAYS_YES=YES pkg update; env ASSUME_ALWAYS_YES=YES pkg install python'
echo "$2 ansible_ssh_user=$1 ansible_python_interpreter=/usr/local/bin/python" > tmphosts
ansible-playbook one-time-setup.yml -ki ./tmphosts
rm tmphosts
