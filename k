#!/usr/bin/bash

create() {
	truncate -s 30M $kdatabase
	cryptsetup luksFormat $kdatabase
	sudo cryptsetup luksOpen $kdatabase kdatabase
	sudo mkfs.ext4 /dev/mapper/kdatabase || return 1
	return 0
}
open() {
	sudo cryptsetup luksOpen $kdatabase kdatabase 2>/dev/null && {
		sudo mkdir /mnt/kdatabase 2>/dev/null
		sudo chmod 700 /mnt/kdatabase
		sudo chown -R $USER:$USER /mnt/kdatabase
		sudo mount /dev/mapper/kdatabase /mnt/kdatabase || return 1
	}
	return 0
}
close() {
	sudo umount /mnt/kdatabase
	sudo cryptsetup luksClose kdatabase || return 1
	return 0
}
list() {
	open || exit 1
	for file in /mnt/kdatabase/*; do echo -en "$(basename "$file")\t"; echo -n $(sed -n '2p' "$file"); echo -e "\t$(stat -c %W "$file" | xargs -I{} date -I -d @{})"; done | column -t -s $'\t'
	
}
add() {
	open || exit 1
	echo -n "title: "; read title
	echo -n "login: "; read login
	echo -n "pass: "; read pass
	echo -e "$pass\n$login" > /mnt/kdatabase/$title
}
pass() {
	open || exit 1
	found=$(grep -rl $1 /mnt/kdatabase/*) && { echo "found: $(echo $found | sed 's#.*/##')"; cat $found | sed -n 1p; return 0; }
	found=$(ls /mnt/kdatabase | grep $1 | head -n1) && { echo "found: $found"; cat /mnt/kdatabase/$found | sed -n 1p; return 0; }
}
login() {
	open || exit 1
	found=$(grep -rl $1 /mnt/kdatabase/*) && { echo "found: $(echo $found | sed 's#.*/##')"; cat $found | sed -n 2p; return 0; }
	found=$(ls /mnt/kdatabase | grep $1 | head -n1) && { echo "found: $found"; cat /mnt/kdatabase/$found | sed -n 2p; return 0; }
}

test -z $kdatabase && {
	echo -e "\033[90mdefaulting to kdatabase=\$HOME/cornflakes\033[0m"
	kdatabase=$HOME/cornflakes
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
