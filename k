#!/usr/bin/bash

check() {
	# 
	# maybe check should just be inside open() ??? i don't know, man... i'll leave that for tomorrow
	#
	
	test -z "$(ls -A "$kdatabase/open")" && {
		open || exit 1
	}
}
open() {
	gocryptfs $kdatabase/closed $kdatabase/open || return 1
	return 0
}
create() {
	mkdir $kdatabase
	chmod 700 $kdatabase
	mkdir $kdatabase/closed
	mkdir $kdatabase/open
	gocryptfs -scryptn 21 -init $kdatabase/closed
	gocryptfs $kdatabase/closed $kdatabase/open
	# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
	# on this commands, there should be some error preventing, but i don't care since i am the only person who uses this. implement it if you want more people to use it =)
	
	cd $kdatabase/open || exit 1
	git init
	git config --local user.name "self"
	git config --local user.email ""
	generate example
	return 0
}
close() {
	fusermount -u $kdatabase/open || return 1
	return 0
}
header() { echo -e "\033[1m\033[92mTITLE\tUSERNAME\tCREATION\tMODIFICATION\tHASH\033[0m"; }
list() {
	check
	{
		header
		for file in $(ls $kdatabase/open/*); do 
			echo -ne "$(basename "$file")\t"
			echo -n $(sed -n '2p' "$file")
			echo -ne "\t$(sed -n '4p' "$file" | xargs -I{} date -I -d @{})"
			echo -ne "\t$(stat -c %Y "$file" | xargs -I{} date -I -d @{})"
			echo -e "\t$(cat "$file" | md5sum | head -c5)"
		done
	} | { 
		read -r header; 
		echo "$header"; 
		sort -k 1,1; 
	} | awk -F $'\t' 'NR==1 {print $0} NR>1 {
		hash=$5
		sum=0
		for (i=1; i<=length(hash); i++) {
			sum += ord(substr(hash, i, 1))
		}
		colors[1]="\033[31m"; colors[2]="\033[32m"; colors[3]="\033[33m"; colors[4]="\033[34m"; colors[5]="\033[35m"; colors[6]="\033[36m"; colors[7]="\033[91m"; colors[8]="\033[92m"; colors[9]="\033[93m"; colors[10]="\033[94m"; colors[11]="\033[95m"; colors[12]="\033[96m"; colors[13]="\033[37m"; colors[14]="\033[90m"
		color=colors[(sum % 14) + 1]  # Modulo operation to select color
		printf "%s\t%s\t\033[90m%s\033[0m\t\033[90m%s\033[0m\t%s%s\033[0m\n", $1, $2, $3, $4, color, hash
	}
	function ord(str) {
		return and(255, str)
	}' | column -t --separator $'\t'
}
list_menu() {
	check
	for file in $(ls $kdatabase/open/*); do echo -en "$(basename "$file")\t"; echo -n $(sed -n '2p' "$file"); echo; done
}
genkey() {
	tr -dc [:lower:][:digit:] < /dev/urandom | head -c 40
}
genusername() {
	awk 'BEGIN{srand(); split("bdfghjklmnpqrstvyz",consonants,""); split("aeiou",vowels,""); for(i=1;i<=3;i++) printf "%s%s",consonants[int(rand()*20)],vowels[int(rand()*5)]; for(i=1;i<=2;i++) printf "%s", int(rand()*10)}'
}
generate() {
	test -z "$@" && exit 1
	test -e $kdatabase/open/"$1" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
	title="$@"
	login=$(genusername)
	pass=$(genkey)
	totp=$(head -c 10 /dev/urandom | base32)
	echo -e "$pass\n$login\n$totp\n$(date +"%s")\n\n\n\n\n" > $kdatabase/open/"$title"
	cd $kdatabase/open
	git add $kdatabase/open/"$title"
	git commit -m 'generate()'
	echo -e "\e[32m$title generated\e[0m"
}
add() {
	check
	title="$1"
	echo -en "title \033[90m(example: google_account)\033[0m: "; read -r title
	echo "$title" | grep " " && {
		echo -e "\033[0;31mtitle shouldn't contain spaces\033[0m"
		exit 1
	}
	test -e $kdatabase/open/"$title" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
	echo -en "login \033[90m(example: bogus@gmail.com)\033[0m: "; read -r login
	echo -en "pass \033[90m(leave empty to auto-generate)\033[0m: "; read -sr pass
	echo ""
	echo -n "totp: "; read -sr totp
	echo ""
	
	[ "$login" = "" ] && login=$(genusername)
	[ "$pass" = "" ] && pass=$(genkey)

	echo -e "$pass\n$login\n$totp\n$(date +"%s")\n\n\n\n\n" > $kdatabase/open/"$title"
	cd $kdatabase/open
	git add $kdatabase/open/"$title"
	git commit -m 'add()'
	echo -e "\e[32mentry added\e[0m"
}
remove() {
	check
	found=$(get "$1" 1 1 | grep found: | sed 's/found: //') && {
		read -p "are you sure you want to remove $found? (y/n): " r
		[[ $r =~ ^(Y|y|yes)$ ]] && { 
			rm $kdatabase/open/"$found"
			cd $kdatabase/open
			git add $kdatabase/open/"$found"
			git commit -m 'remove()'
			echo -e "\e[32mremoved\e[0m"
		} || {
			echo -e "\033[0;31mcanceled\033[0m"
		}
	}
}
edit() {
	check
	found=$(get "$1" 1 1 | grep found: | sed 's/found: //') && {
		$EDITOR $kdatabase/open/"$found" 
		cd $kdatabase/open
		git add $kdatabase/open/"$found"
		git commit -m 'edit()'
	}
}
rename() {
	check
	found=$(get "$1" 1 1 | grep found: | sed 's/found: //') && {
		test -e $kdatabase/open/"$2" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
		read -p "are you sure you want to rename $found -> $2 ? (y/n): " r
		[[ $r =~ ^(Y|y|yes)$ ]] && { 
			mv -v $kdatabase/open/"$found" $kdatabase/open/"$2"
			cd $kdatabase/open
			git add $kdatabase/open/"$found"
			git add $kdatabase/open/"$2"
			git commit -m 'rename()'
		} || {
			echo -e "\033[0;31mcanceled\033[0m"
		}
	}
}
get() {
    check

	#
	# this function is the messiest thing in the universe, please don't look at it
	# 
	
	# look at that logic!!!
	#
	# get() {
	# 	echo -e "1\n2\n3\n4" | sed -n "${1},${2}p"
	# }
	# 
	# get $1 $2
	#
	# and now, for half a cent and a stupid logic, you have to write "get $1 $2 $2"
	#

	# (?) search for a entry name that matches
	
    candidates=$(ls $kdatabase/open | grep -i "$1") && {
	    test $(echo "$candidates" | wc -l) -eq 1 && {
	    	echo "found: $candidates"
	    	_return="$(sed -n "${2},${3}p" $kdatabase/open/"$candidates")"
	    	test "$3" = '$' && { print_note "$(echo "$_return" | fold -s)"; } || echo "$_return"
	   	    return 0
	    } || {
		    if [ -n "$candidates" ]; then
		        closest=$(echo "$candidates" | python3 -c "
import sys
import difflib
input_str = '$1'
candidates = sys.stdin.read().splitlines()
closest_match = difflib.get_close_matches(input_str, candidates, n=1)
if closest_match:
    print(closest_match[0])
	")
		        echo "found: $closest"
		        _return="$(sed -n "${2},${3}p" $kdatabase/open/"$closest")"
		        test "$3" = '$' && { print_note "$(echo -e "$_return" | fold -s)"; } || echo "$_return"
		        return 0
		    fi
	    }
    }

	# (?) before trying to search by content, try if the user tried using a hash:

	get_by_hash "$1"
	
	# (?) then, if nothing found, search for a matching password or entry content
	
    found=$(grep -irl "$1" $kdatabase/open/*  | head -n1)
    echo "found: $(basename $found)"
	_return="$(sed -n "${2},${3}p" $found)"
    test "$3" = '$' && { 
    	print_note "$(echo -e "$_return" | fold -s)"; 
    } || { 
   		echo "$_return";
   	} 
 
}
get_by_hash() {
	# i wanted to add this, but then you cannot write ONLY the beginning of a hash, like "78f" instead of "78fa1"
	# [[ ${#1} -eq 5 ]] && echo "True" || echo "False"
	
	for file in $kdatabase/open/*; do
	    if [ -f "$file" ]; then
	        hash=$(md5sum "$file" | head -c 5)
			
	        if echo "$hash" | grep -q ^"$1"; then
				echo "found: $(basename $file)"
	            head -n1 $file
	        fi
	    fi
	done
}
copy() {
	check
	get "$1" 1 1 | tail -n1 | tr -d '\n' | xclip -sel c
}
totp() {
	which=$(get "$1" 3 3)
	echo "$which" | head -n1
	oathtool -b --totp $(echo -n "$which" | tail -n1)
}
print_note() {
    local text="$1"
    local rows=$(echo "$text" | wc -l)
    local cols=$(echo "$text" | awk '{ if ( length > L ) { L=length } } END { print L }')

    local bg_color="\e[48;5;221m"
    local fg_color="\e[38;5;235m"
    local reset_color="\e[0m"

    printf "${bg_color}%*s${reset_color}\n" $((cols + 4)) ""

    while IFS= read -r line; do
        printf "${bg_color}  ${fg_color}%-*s  ${bg_color}${reset_color}\n" "$cols" "$line"
    done <<< "$text"

    printf "${bg_color}%*s${reset_color}\n" $((cols + 4)) ""
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
\033[1mpass/get\033[0m: retrieves the password for a specific entry, searching by entry name, login, password, hash or else
\033[1mnote\033[0m: retrieves the plain text note for a specific entry, searching by entry name, login, password, hash or else
\033[1mhash\033[0m: retrieves the password for a specific entry, searching by hash exclusively
\033[1mgenerate\033[0m: creates a new random generated entry (requires argument) 
\033[1mgen\033[0m: generates a user and password
\033[1mopen\033[0m: opens the encrypted database
\033[1mclose\033[0m: closes the encrypted database"
}

test -z $kdatabase && {
	source $HOME/.config/k
}

kdatabase=$(echo -n $kdatabase | sed 's:/*$::')

test -e $kdatabase || {
	echo -e "\033[0;31mno database exists at $kdatabase\033[0m"
	read -p "you can create one with \"k create\", do you want to continue? (y/n): " r
	[[ $r =~ ^(Y|y|yes)$ ]] && { 
		create
		exit
	} || exit 1

}

kdatabaseid=$(echo $kdatabase | b2sum | cut -b1-8)-$(basename $kdatabase)

case "$1" in
	"check") check;;
	"open") open;;
	"close") close;;
	"create") create;;
	"list") list;;"ls") list;;
	"list_menu") list_menu;;
	"generate") generate "${@:2}";;
	"add") add "$2";;
	"remove") remove "$2";;"rm") remove "$2";;
	"edit") edit "$2";;
	"rename") rename "$2" "$3";;"move") rename "$2" "$3";;"mv") rename "$2" "$3";;
	"pass") get "$2" 1 1;;"get") get "$2" 1 1;;
	"hash") get_by_hash "$2";;
	"login") get "$2" 2 2;;
	"note") get "$2" 10 "\$";;
	"totp") totp "$2";;
	"copy") copy "$2";;"c") copy "$2";;
	"gen") genusername; echo; genkey; echo;;
	*) usage; exit 2;;
esac
