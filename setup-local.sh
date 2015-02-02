#!/bin/sh

SYSTYPE=`uname`
ANSIBLE_PUBKEY='ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDNZmhL0Afq47vdTUTEVJNfSu+Q7tNYXmCD1R9qOZh9F9pStEf2P3FrpdGhpZkzhsS+wi0gw7WUX7KW2fiiFARTt+KYT9FZBjAzNaob0hKTO0bV9k5981WdPVbiVK00PaRP+uAeOMVpU56hr7kOp5DwsnzBWDuMinuggfQrFFxFYC/OyZuz5DWCcQbNbhYlDM903hWVm3WzWNyN2vH+FF4Ty2TJYbqqfAlul/weK9x3Di5fPbw6EMmy2nbqnu6rj5DKxUMtQdQ8irXlKP6tL9erfaiELHgmLyD64B5/C4CBKUqS1UnA0QS5WDmRI0vysNjKODg5/zX/NZe7Qvo4EnAxxW/OLvL/27LNWERc2K/l98Hg5mafLBVsDKCsJU6DruuG0kOz4yvwF4r4KgQDSU/QwxXKKg+OGenAYE/4LrfrpmHeITtkwfWcMKR8W8X6jBvIK7N+jfCK1alp4yOJbOLQbmnn5N+YhrrgpchHHufRuXHaWa2iZOVZafA1xGvPw5xsafTrr1MKsRf3U8p7W2Q/CBMOKNk8beouTPBvGzFdU76K9upoY1wIUaHwyboz0fnodqOP+DCirbBUbcQx7sw/667lZ3lps9Fc2AdL5nXgzxNM5kEly/gi8fhevKQ5iwh+4Z58LYaD2IaSkM4h/SaPFAV0iKKIkj3kNYyXwQSiAQ== Ansible key'
SUDOERS='# Setup sudoreplay
Defaults log_output
Defaults!/usr/bin/sudoreplay !log_output
Defaults!/usr/local/bin/sudoreplay !log_output
Defaults!/sbin/reboot !log_output

# make sure ansible works right
Defaults:ansible !requiretty
Defaults:ansible !lecture

root ALL=(ALL) ALL

#%wheel ALL=(ALL) ALL

%wheel ALL=(ALL) NOPASSWD: ALL

## Read drop-in files from /usr/local/etc/sudoers.d
## (the "#" here does not indicate a comment)
#includedir /usr/local/etc/sudoers.d'

if [ "$SYSTYPE" = "FreeBSD" ]; then
		env ASSUME_ALWAYS_YES=YES pkg install python sudo
		pw useradd ansible -m -G wheel -w none
		mkdir /home/ansible/.ssh
		echo "$ANSIBLE_PUBKEY" \
			> /home/ansible/.ssh/authorized_keys
		service sshd start
		echo "$SUDOERS" > /tmp/mysudoers
		if visudo -cqf /tmp/mysudoers; then
			cat /tmp/mysudoers > /usr/local/etc/sudoers
		else
			echo 'SUDOERS FILE INSTALL FAILED!'
			visudo -cf /tmp/mysudoers
		fi
		echo 'Done'
else
		echo 'wat do'
		echo "SYSTYPE = $SYSTYPE"
fi
