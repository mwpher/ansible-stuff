#!/bin/sh

PYTHON_COMMAND='env ASSUME_ALWAYS_YES=YES pkg update; env ASSUME_ALWAYS_YES=YES pkg install python'
echo $@ $#

([ $# == '2' ] || exit)

if [ $1 == '-j' ]; then
	sudo ezjail-admin start $2
	export ASSUME_ALWAYS_YES=YES
	sudo pkg -j $2 update;
	sudo pkg -j $2 install python;
	echo "$2 ansible_connection=jail ansible_python_interpreter=/usr/local/bin/python" > tmphosts
	sudo ansible-playbook one-time-setup.yml -i ./tmphosts
else
	ssh -t ${1}@${2} $PYTHON_COMMAND
	echo "$2 ansible_connection=paramiko ansible_ssh_user=$1 ansible_python_interpreter=/usr/local/bin/python" > tmphosts
	ansible-playbook one-time-setup.yml -ki ./tmphosts
fi
rm tmphosts
