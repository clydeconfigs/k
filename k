#!/usr/bin/bash

mkdir_and_mount_and_chmod_and_chown_and_rm_lost+found() {
	sudo mkdir /mnt/$kdatabaseid 2>/dev/null
	sudo mount /dev/mapper/$kdatabaseid /mnt/$kdatabaseid || return 1
	sudo chmod 700 /mnt/$kdatabaseid
	sudo chown -R $USER:$USER /mnt/$kdatabaseid
	rm -r /mnt/$kdatabaseid/lost+found 2>/dev/null
}
create() {
	truncate -s 30M $kdatabase
	cryptsetup luksFormat $kdatabase
	sudo cryptsetup luksOpen $kdatabase $kdatabaseid
	sudo mkfs.ext4 /dev/mapper/$kdatabaseid
	mkdir_and_mount_and_chmod_and_chown_and_rm_lost+found
	return 0
}
open() {
	test -e /dev/mapper/$kdatabaseid && return 0
	sudo cryptsetup luksOpen $kdatabase $kdatabaseid 2>/dev/null && {
		mkdir_and_mount_and_chmod_and_chown_and_rm_lost+found
	}
	return 0
}
close() {
	sudo umount /mnt/$kdatabaseid
	sudo cryptsetup luksClose $kdatabaseid || return 1
	return 0
}
list() {
	open || exit 1
	for file in /mnt/$kdatabaseid/*; do echo -en "$(basename "$file")\t"; echo -n $(sed -n '2p' "$file"); echo -e "\t$(stat -c %W "$file" | xargs -I{} date -I -d @{})"; done | column -t -s $'\t'
	
}
generate() {
	test -z $1 && exit 1
	title=$1
	login=$(awk 'BEGIN{srand(); split("bdfghjklmnpqrstvyz",consonants,""); split("aeiou",vowels,""); for(i=1;i<=3;i++) printf "%s%s",consonants[int(rand()*20)],vowels[int(rand()*5)]; for(i=1;i<=2;i++) printf "%s", int(rand()*10)}')
	pass=$(tr -dc [:graph:] < /dev/urandom | head -c 20)
	echo -e "$pass\n$login" > /mnt/$kdatabaseid/$title
	echo -e "\e[32m$title generated\e[0m"
}
add() {
	open || exit 1
	echo -n "title: "; read title
	test -e /mnt/$kdatabaseid/$title && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
	echo -n "login: "; read login
	echo -n "pass: "; read pass

	[ "$pass" = "g" ] && pass=$(tr -dc [:graph:] < /dev/urandom | head -c 20)
	[ "$login" = "g" ] && login=$(awk 'BEGIN{srand(); split("bdfghjklmnpqrstvyz",consonants,""); split("aeiou",vowels,""); for(i=1;i<=3;i++) printf "%s%s",consonants[int(rand()*20)],vowels[int(rand()*5)]; for(i=1;i<=2;i++) printf "%s", int(rand()*10)}')

	echo -e "$pass\n$login" > /mnt/$kdatabaseid/$title
	echo -e "\e[32mentry added\e[0m"
}
remove() {
	found=$(get $1 | grep found: | sed 's/found: //') && {
		read -p "are you sure you want to remove $found? (y/n): " r
		[[ $r =~ ^(Y|y|yes)$ ]] && { 
			rm /mnt/$kdatabaseid/$found; echo "removed"; 
		} || {
			echo "canceled"
		}
	}
}
edit() {
	found=$(get $1 | grep found: | sed 's/found: //') && {
		$EDITOR /mnt/$kdatabaseid/$found 
	}
}
rename() {
	found=$(get $1 | grep found: | sed 's/found: //') && {
		mv /mnt/$kdatabaseid/$found /mnt/$kdatabaseid/$2
	}
}
get() {
  open || exit 1
  found=$(grep -irl $1 /mnt/$kdatabaseid/*) && { echo "found: $(echo $found | sed 's#.*/##')"; cat $found | sed -n ${2}p; return 0; }
  found=$(ls /mnt/$kdatabaseid | grep -i $1 | head -n1) && { echo "found: $found"; cat /mnt/$kdatabaseid/$found | sed -n ${2}p; return 0; }
  return 1
}
copy() {
  get $1 2 | tail -n1 | tr -d '\n' | xclip -sel c
}

test -z $kdatabase && {
	echo -e "\033[90mdefaulting to kdatabase=\$HOME/cornflakes\033[0m"
	kdatabase=$HOME/cornflakes
}

kdatabaseid=$(echo $kdatabase | b2sum | cut -b1-16)

case $1 in
	"open") open;;
	"close") close;;
	"create") create;;
	"list") list;;
	"generate") generate $2;;
	"add") add;;
	"remove") remove $2;;
	"edit") edit $2;;
	"rename") rename $2 $3;;
	"pass") get $2 1;;
	"login") get $2 2;;
	"get") get $2 1;;
	"copy") copy $2;;
	*) exit 2;;
esac
