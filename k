#!/usr/bin/bash

create() {
	truncate -s 30M $database
	cryptsetup luksFormat $database
	sudo cryptsetup luksOpen $database k_database
	sudo mkfs.ext4 /dev/mapper/k_database || return 1
	return 0
}
open() {
	sudo cryptsetup luksOpen $database k_database 2>/dev/null && {
		sudo mkdir /mnt/k_database 2>/dev/null
		sudo chmod 700 /mnt/k_database
		sudo chown -R $USER:$USER /mnt/k_database
		sudo mount /dev/mapper/k_database /mnt/k_database || return 1
	}
	return 0
}
close() {
	sudo umount /mnt/k_database
	sudo cryptsetup luksClose k_database || return 1
	return 0
}
list() {
	open || exit 1
	for file in /mnt/k_database/*; do echo -en "$(basename "$file")\t"; echo -n $(sed -n '2p' "$file"); echo -e "\t$(stat -c %W "$file" | xargs -I{} date -I -d @{})"; done | column -t -s $'\t'
	
}
add() {
	open || exit 1
	echo -n "title: "; read title
	echo -n "login: "; read login
	echo -n "pass: "; read pass
	echo -e "$pass\n$login" > /mnt/k_database/$title
}
pass() {
	open || exit 1
	echo "found: $(grep -rl $1 /mnt/k_database/* | sed 's#.*/##')"
	cat $(grep -rl $1 /mnt/k_database/*) | sed -n 1p
}
login() {
	open || exit 1
	cat $(grep -rl $1 /mnt/k_database/*) | sed -n 2p
}

test -z $database && {
	echo "set full path for environment variable \$database, defaulting to \"\$HOME/cornflakes\""
	database=$HOME/cornflakes
}

case $1 in
	"open") open;;
	"close") close;;
	"create") create;;
	"list") list;;
	"add") add;;
	"pass") pass $2;;
	"login") login $2;;
esac
