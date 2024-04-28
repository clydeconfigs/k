#!/usr/bin/bash

create() {
	truncate -s 30M $database
	cryptsetup luksFormat $database
	sudo cryptsetup luksOpen $database k_database
	sudo mkfs.ext4 /dev/mapper/k_database
}
open() {
	sudo cryptsetup luksOpen $database k_database 2>/dev/null && {
		sudo mkdir /mnt/k_database 2>/dev/null
		sudo chown -R $USER:$USER /mnt/k_database
		sudo mount /dev/mapper/k_database /mnt/k_database || exit 1
	}
	return 0
}
list() {
	open || exit 1
	ls /mnt/k_database
}
add() {
	open || exit 1
	touch /mnt/k_database/$RANDOM$RANDOM
}

database=cornflakes

case $1 in
	"open") open;;
	"create") create;;
	"list") list;;
	"add") add;;
esac
