#!/bin/sh
set -e

PYTHON_COMMAND='env ASSUME_ALWAYS_YES=YES pkg update -f; env ASSUME_ALWAYS_YES=YES pkg install python'

([ $# == '2' ] || exit)

if [ $1 == '-j' ]; then
	sudo jexec $2 /bin/sh -c "$PYTHON_COMMAND"
	echo "$2 ansible_connection=jail" > tmphosts
	sudo ansible-playbook one-time-setup.yml -i ./tmphosts
else
	if [ $1 == '-s' ]; then
		echo "$3 ansible_connection=paramiko ansible_ssh_user=$2 ansible_python_interpreter=/usr/local/bin/python" > tmphosts
	else
		ssh -t ${1}@${2} $PYTHON_COMMAND
		echo "$2 ansible_connection=paramiko ansible_ssh_user=$1 ansible_python_interpreter=/usr/local/bin/python" > tmphosts
	fi
	ansible-playbook one-time-setup.yml -ki ./tmphosts
fi
rm tmphosts
