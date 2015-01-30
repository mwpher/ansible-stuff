#!/bin/sh

PYTHON_COMMAND='env ASSUME_ALWAYS_YES=YES pkg update; env ASSUME_ALWAYS_YES=YES pkg install python'

([ $# == '2' ] || exit)

if [ $1 == '-j' ]; then
	export ASSUME_ALWAYS_YES=YES
	sudo pkg -j $2 update;
	sudo pkg -j $2 install python;
	echo "$2 ansible_connection=jail ansible_python_interpreter=/usr/local/bin/python" > tmphosts
	sudo ansible-playbook one-time-setup.yml -i ./tmphosts
else
	if [ $1 == '-s' ]; then
		echo "$3 ansible_connection=paramiko ansible_ssh_user=$2 ansible_python_interpreter=/usr/local/bin/python" > tmphosts
	else
		ssh -t ${1}@${2} $PYTHON_COMMAND
		echo "temp ansible_ssh_host=$1 ansible_connection=paramiko ansible_ssh_user=$1 ansible_python_interpreter=/usr/local/bin/python" > tmphosts
	fi
	ansible-playbook one-time-setup.yml -ki ./tmphosts
fi
rm tmphosts
