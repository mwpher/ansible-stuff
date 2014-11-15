#!/bin/sh
echo $@ $#

(($# == 2) || exit)

#ssh -t ${1}@${2} 'env ASSUME_ALWAYS_YES=YES pkg bootstrap; pkg update; pkg install python'
echo "$2" > tmphosts
ansible-playbook one-time-setup.yml -ki ./tmphosts
rm tmphosts

echo '

Done!'
