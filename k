#!/usr/bin/bash

check() {
	test ! -e /dev/mapper/$kdatabaseid && {
		open
	}
	test -z "$(ls /mnt/$kdatabaseid)" && {
		echo -e "\033[0;31mno entries yet... create one to list them\033[0m"
		exit 1
	}
}
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
	cd /mnt/$kdatabaseid || exit 1
	git init
	git config --local user.name "self"
	git config --local user.email ""
	generate example
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
list_abc() {
	check
	open || exit 1
	{
		echo -e "\033[1mtitle\tusername\tcreation\tmodification\033[0m"
		for file in /mnt/$kdatabaseid/*; do
			echo -ne "$(basename "$file")\t"
			echo -n $(sed -n '2p' "$file")
			echo -ne "\t$(sed -n '4p' "$file" | xargs -I{} date -I -d @{})"
			echo -e "\t$(stat -c %Y "$file" | xargs -I{} date -I -d @{})"
		done 
	} | column -t -s $'\t'
}
list_bydate() {
	check
	open || exit 1
	{
		echo -e "\033[1mtitle\tusername\tcreation\tmodification\033[0m"
		for file in /mnt/$kdatabaseid/*; do 
			echo -ne "$(basename "$file")\t"
			echo -n $(sed -n '2p' "$file")
			echo -ne "\t$(sed -n '4p' "$file" | xargs -I{} date -I -d @{})"
			echo -e "\t$(stat -c %Y "$file" | xargs -I{} date -I -d @{})"
		done
	} | { 
		read -r header; 
		echo "$header"; 
		sort -k 4,4; 
	} | column -t -s $'\t'
}
list_menu() {
	check
	open || exit 1
	for file in /mnt/$kdatabaseid/*; do echo -en "$(basename "$file")\t"; echo -n $(sed -n '2p' "$file"); echo; done
}
genkey() {
	tr -dc [:lower:][:digit:] < /dev/urandom | head -c 40
}
genusername() {
	awk 'BEGIN{srand(); split("bdfghjklmnpqrstvyz",consonants,""); split("aeiou",vowels,""); for(i=1;i<=3;i++) printf "%s%s",consonants[int(rand()*20)],vowels[int(rand()*5)]; for(i=1;i<=2;i++) printf "%s", int(rand()*10)}'
}
generate() {
	test -z "$@" && exit 1
	test -e /mnt/$kdatabaseid/"$1" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
	title="$@"
	login=$(genusername)
	pass=$(genkey)
	totp=$(head -c 10 /dev/urandom | base32)
	echo -e "$pass\n$login\n$totp\n$(date +"%s")" > /mnt/$kdatabaseid/"$title"
	git add /mnt/$kdatabaseid/"$title"
	git commit -m 'generate()'
	echo -e "\e[32m$title generated\e[0m"
}
add() {
	open || exit 1
	echo -n "title: "; read -r title
	test -e /mnt/$kdatabaseid/"$title" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
	echo -n "login: "; read -r login
	echo -n "pass: "; read -sr pass
	echo ""
	echo -n "totp: "; read -sr totp
	echo ""
	
	[ "$login" = "gen" ] && login=$(genusername)
	[ "$pass" = "gen" ] && pass=$(genkey)

	echo -e "$pass\n$login\n$totp\n$(date +"%s")" > /mnt/$kdatabaseid/"$title"
	git add /mnt/$kdatabaseid/"$title"
	git commit -m 'add()'
	echo -e "\e[32mentry added\e[0m"
}
remove() {
	check
	found=$(get "$1" | grep found: | sed 's/found: //') && {
		read -p "are you sure you want to remove $found? (y/n): " r
		[[ $r =~ ^(Y|y|yes)$ ]] && { 
			rm /mnt/$kdatabaseid/"$found"
			git add /mnt/$kdatabaseid/"$found"
			git commit -m 'remove()'
			echo -e "\e[32mremoved\e[0m"
		} || {
			echo "\033[0;31mcanceled\033[0m"
		}
	}
}
edit() {
	check
	found=$(get "$1" | grep found: | sed 's/found: //') && {
		$EDITOR /mnt/$kdatabaseid/"$found" 
		git add /mnt/$kdatabaseid/"$found"
		git commit -m 'edit()'
	}
}
rename() {
	check
	found=$(get "$1" | grep found: | sed 's/found: //') && {
		test -e /mnt/$kdatabaseid/"$2" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
		mv -v /mnt/$kdatabaseid/"$found" /mnt/$kdatabaseid/"$2"
		git add /mnt/$kdatabaseid/"$found"
		git add /mnt/$kdatabaseid/"$2"
		git commit -m 'rename()'
	}
}
get() {
	check
	open || exit 1
	found=$(ls /mnt/$kdatabaseid | grep -i "$1") && { found=$(echo "$found" | head -n1); echo "found: $found"; cat /mnt/$kdatabaseid/"$found" | sed -n ${2}p; return 0; }
	found=$(grep -irl "$1" /mnt/$kdatabaseid/*) && { found=$(echo "$found" | head -n1); echo "found: $(echo "$found" | sed 's#.*/##')"; cat "$found" | sed -n ${2}p; return 0; }
	return 1
}
copy() {
	check
	get "$1" 1 | tail -n1 | tr -d '\n' | xclip -sel c
}
totp() {
	which=$(get "$1" 3)
	echo "$which" | head -n1
	oathtool -b --totp $(echo -n "$which" | tail -n1)
}
usage() {
	echo -e "\033[1mlist\033[0m: lists all entries (list_abc or list_menu for alphabetical order)
\033[1mcreate\033[0m: creates a new encrypted database
\033[1mcopy\033[0m: copies the password of a specific entry to the clipboard
\033[1madd\033[0m: adds a new entry
\033[1mremove\033[0m: removes an entry
\033[1medit\033[0m: allows editing an existing entry
\033[1mrename/move\033[0m: renames an existing entry
\033[1mlogin\033[0m: retrieves the login username for a specific entry
\033[1mpass/get\033[0m: retrieves the password for a specific entry
\033[1mgenerate\033[0m: creates a new random generated entry (requires argument) 
\033[1mgen\033[0m: generates a user and password
\033[1mopen\033[0m: opens the encrypted database
\033[1mclose\033[0m: closes the encrypted database"
}

test -z $kdatabase && {
	source $HOME/.config/k
}

kdatabaseid=$(echo $kdatabase | b2sum | cut -b1-8)-$(basename $kdatabase)

case "$1" in
	"open") open;;
	"close") close;;
	"create") create;;
	"list") list_bydate;;"ls") list_bydate;;
	"list_abc") list_abc;;
	"list_menu") list_menu;;
	"generate") generate "${@:2}";;
	"add") add;;
	"remove") remove "$2";;"rm") remove "$2";;
	"edit") edit "$2";;
	"rename") rename "$2" "$3";;"move") rename "$2" "$3";;"mv") rename "$2" "$3";;
	"pass") get "$2" 1;;"get") get "$2" 1;;
	"login") get "$2" 2;;
	"totp") totp "$2";;
	"copy") copy "$2";;"c") copy "$2";;
	"gen") genusername; echo; genkey; echo;;
	*) usage; exit 2;;
esac
