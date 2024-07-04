#!/usr/bin/bash

check() {
	# 
	# maybe check should just be inside open() ??? i don't know, man... i'll leave that for tomorrow
	#
	
	test -z "$(ls -A "/tmp/$kdbid" 2>/dev/null)" && {
		open || exit 1
	}
}
open() {
	test -e $kdatabase/UNENCRYPTED_DONT_DELETE_THIS && {
		ln -s "$(realpath $kdatabase)"/encrypted /tmp/$kdbid
		echo "ln -s "$(realpath $kdatabase)"/encrypted /tmp/$kdbid"
	} || {
		mkdir /tmp/$kdbid 2>/dev/null
		chmod 700 /tmp/$kdbid
		gocryptfs $kdatabase/encrypted /tmp/$kdbid || return 1
	}
	return 0
}
create() {
echo -e "$(logo "k: DATABASE CREATION")
"
	mkdir $kdatabase
	chmod 700 $kdatabase
	mkdir $kdatabase/encrypted
	
	read -p "do you want to leave your database without encryption (not recommended)? (y/N): " r
	[[ $r =~ ^(Y|y|yes)$ ]] && {
		echo "encryption will not be used"
		touch $kdatabase/UNENCRYPTED_DONT_DELETE_THIS
		open
	} || {
		mkdir $kdatabase/encrypted
		mkdir /tmp/$kdbid
		chmod 700 /tmp/$kdbid

		gocryptfs -scryptn 21 -init $kdatabase/encrypted
		gocryptfs $kdatabase/encrypted /tmp/$kdbid
		# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
		# on this commands, there should be some error preventing, but i don't care since i am the only person who uses this. implement it if you want more people to use it =)
	}	
	
	cd /tmp/$kdbid || exit 1
	git init
	git config --local user.name "self"
	git config --local user.email ""
	generate example
	return 0
}
close() {
	test -e $kdatabase/UNENCRYPTED_DONT_DELETE_THIS && {
		rm /tmp/$kdbid
	} || {
		fusermount -u /tmp/$kdbid || return 1
	}
	return 0
}
header() { echo -e "\033[1m\033[92mTITLE\tUSERNAME\tCREATION\tMODIFICATION\tHASH\033[0m"; }
list() {
	check
	{
		header
		for file in $(ls /tmp/$kdbid/*); do 
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
	for file in $(ls /tmp/$kdbid/*); do echo -en "$(basename "$file")\t"; echo -n $(sed -n '2p' "$file"); echo; done
}
genkey() {
	random_char=$(case $(( $RANDOM % 3 )) in
	  0) echo '%' ;;
	  1) echo '&' ;;
	  2) echo '@' ;;
	esac)
	echo -n "${random_char}K"
	tr -dc [:lower:][:digit:] < /dev/urandom | head -c 40
}
genusername() {
    python -c "
import random

def generate_sequence(length):
    consonants = list('bdfghjklmnpqrstvwxz') * 3 + ['sn', 'sp', 'sk', 'st', 'kr', 'tr', 'gr', 'dr', 'pr', 'fr']
    vowels = 'aeiou'
    sequence = []
    for i in range(length):
        if i % 2 == 0:
            sequence.append(random.choice(consonants))
        else:
            sequence.append(random.choice(vowels))
    return ''.join(sequence)

length = 6
print(generate_sequence(length) + str(random.randint(10, 99)))
" | tr -d '\n'
}
generate() {
	test -z "$@" && exit 1
	test -e /tmp/$kdbid/"$1" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
	title="$@"
	pass=$(genkey)
	echo -e "$pass\n\n\n$(date +"%s")\n\n\n\n\n" > /tmp/$kdbid/"$title"
	cd /tmp/$kdbid
	git add /tmp/$kdbid/"$title"
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
	test -e /tmp/$kdbid/"$title" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
	echo -en "login \033[90m(example: bogus@gmail.com)\033[0m: "; read -r login
	echo -en "pass \033[90m(leave empty to auto-generate)\033[0m: "; read -sr pass
	echo ""
	echo -n "totp: "; read -sr totp
	echo ""
	
	[ "$login" = "" ] && login=$(genusername)
	[ "$pass" = "" ] && pass=$(genkey)

	echo -e "$pass\n$login\n$totp\n$(date +"%s")\n\n\n\n\n" > /tmp/$kdbid/"$title"
	cd /tmp/$kdbid
	git add /tmp/$kdbid/"$title"
	git commit -m 'add()'
	echo -e "\e[32mentry added\e[0m"
}
remove() {
	check
	found=$(get "$1" 1 1 | grep found: | sed 's/found: //') && {
		read -p "are you sure you want to remove $found? (y/n): " r
		[[ $r =~ ^(Y|y|yes)$ ]] && { 
			rm /tmp/$kdbid/"$found"
			cd /tmp/$kdbid
			git add /tmp/$kdbid/"$found"
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
		$EDITOR /tmp/$kdbid/"$found" 
		cd /tmp/$kdbid
		git add /tmp/$kdbid/"$found"
		git commit -m 'edit()'
	}
}
rename() {
	check
	found=$(get "$1" 1 1 | grep found: | sed 's/found: //') && {
		test -e /tmp/$kdbid/"$2" && { echo -e "\033[0;31mentry with same title already exists\033[0m"; exit 1; }
		read -p "are you sure you want to rename $found -> $2 ? (y/n): " r
		[[ $r =~ ^(Y|y|yes)$ ]] && { 
			mv -v /tmp/$kdbid/"$found" /tmp/$kdbid/"$2"
			cd /tmp/$kdbid
			git add /tmp/$kdbid/"$found"
			git add /tmp/$kdbid/"$2"
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
	
    candidates=$(ls /tmp/$kdbid | grep -i "$1") && {
	    test $(echo "$candidates" | wc -l) -eq 1 && {
	    	echo "found: $candidates"
	    	_return="$(sed -n "${2},${3}p" /tmp/$kdbid/"$candidates")"
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
		        _return="$(sed -n "${2},${3}p" /tmp/$kdbid/"$closest")"
		        test "$3" = '$' && { print_note "$(echo -e "$_return" | fold -s)"; } || echo "$_return"
		        return 0
		    fi
	    }
    }

	# (?) before trying to search by content, try if the user tried using a hash:

	get_by_hash "$1" && exit 0
	
	# (?) then, if nothing found, search for a matching password or entry content
	
    found=$(grep -irl "$1" /tmp/$kdbid/*  | head -n1)
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
	
	for file in /tmp/$kdbid/*; do
	    if [ -f "$file" ]; then
	        hash=$(md5sum "$file" | head -c 5)
			
	        if echo "$hash" | grep -q ^"$1"; then
				echo "found: $(basename $file)"
	            head -n1 $file
	            return 0
	        fi
	    fi
	done

	return 1
}
copy() {
	check
	entry="$(get "$1" 1 1)" || exit 1
	echo "$entry" | tail -n1 | tr -d '\n' | xclip -sel c
	echo "$entry" | head -n1 | sed 's/^found:/copied:/'
	echo -e "\033[0;33mCAREFUL: USING THE CLIPBOARD CAN MAKE ANY PROGRAM READ YOUR CREDENTIALS, THIS IN UNSAFE (FOR EXAMPLE IN ANY WEBSITE USING JAVASCRIPT). USE THIS ONLY WHEN STRICTLY NECESSARY\033[0m"
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
test_db_exists() {
	test -e $kdatabase || {
		echo -e "\033[0;31mno database exists at $kdatabase\033[0m"
		read -p "you can create one with \"k create\", do you want to continue? (y/n): " r
		[[ $r =~ ^(Y|y|yes)$ ]] && { 
			create
			return 1
		} || return 1
	
	}
	return 0
}
create_backup() {
	mkdir "$kdatabase"/backups 2>/dev/null
	i=1
	while true; do
	  file="$kdatabase"/backups/backup$i.tgz
	  if [ ! -f "$file" ]; then
	    exportdb "$kdatabase"/backups/backup$i
	    echo "backup saved as $file.tgz"
	    break
	  fi
	  ((i++))
	done
}
exportdb() {
	test -z "$1" && exit 1
	test_db_exists || exit 1
	if [ -f "$1".tgz ]; then
	    read -p "$1.tgz already exists, do you want to replace it? (y/n) " choice
	    case "$choice" in 
	      y|Y ) echo -e "\e[32mreplacing the existing file...\e[0m";;
	      n|N ) echo -e "\033[0;31mcanceled\033[0m"; exit 1;;
	      * ) echo -e "\033[0;31mcanceled\033[0m"; exit 1;;
	    esac
	fi
	tar -czf "$1".tgz -C $kdatabase/encrypted . && {
		echo "exported database at $1.tgz"
		exit 0
	}
	exit 1
}
importdb() {
	test -z "$1" && exit 1
	test -e $kdatabase && {
		echo -e "\033[0;31man existing database exists at $kdatabase! you should chose a \$kdatabase location which is empty\033[0m"
		exit 1
	}

	mkdir -p $kdatabase/encrypted
	tar -xf "$1" -C $kdatabase/encrypted && {
		mkdir /tmp/$kdbid
		echo "imported database to $kdatabase, open with 'k open'"
		exit 0
	}
	exit 1
}
exportraw() {
	echo -ne "\033[0;33mCAREFUL: THIS WILL EXPORT YOUR DATABASE WITHOUT ENCRYPTION, DO YOU WANT TO CONTINUE? (y/n): \033[0m"
	read r
	[[ $r =~ ^(Y|y|yes)$ ]] && { 
		tar -czf "$1".tgz -C /tmp/$kdbid . && {
			echo "exported raw database at $1"
			exit 0
		}
	}
	exit 1
}
logo() {
    local str_length=${#1}
    local width=$(tput cols)
    local space_length=$((width - str_length - 5))
    echo -e "
\e[44m $1$(printf "%-${space_length}s" "" | tr ' ' ' ')\e[0m\n"
}
usage() {
	echo -e "$(logo "k: HELP")
"

bold="\033[1m"
reset="\033[0m"

echo -e "${bold}list${reset}:                                      ${bold}generate${reset}:                                
  lists all entries (list_abc or             creates a new random generated entry 
list_menu for alphabetical order)          (requires argument) 
${bold}create${reset}:                                    ${bold}gen${reset}: 
  creates a new encrypted database           without adding a entry to the 
${bold}copy${reset}:                                      databse, generates a user and/or 
  copies the password of a specific        password
entry to the clipboard                     ${bold}open${reset}: 
${bold}add${reset}:                                         opens the encrypted database (which 
  adds a new entry                         is mounted in /tmp/)
${bold}remove${reset}:                                    ${bold}close${reset}: 
  removes an entry, searching by entry       closes the database (which is mounted 
name, login, password, hash or else        in /tmp/)
${bold}edit${reset}:                                      ${bold}export${reset}: 
  allows editing an existing entry,          exports the existing database (with 
searching by entry name, login,            current encryption) (which location 
password, hash or else                     specified in $kdatabase)
${bold}rename/move${reset}:                               ${bold}import${reset}: 
  renames an existing entry                  imports a exported database in .tgz 
${bold}login${reset}:                                     format into the current $kdatabase 
  retrieves the login username for a       location
specific entry                             ${bold}exportraw${reset}: 
${bold}pass/get${reset}:                                    exports the existing database WITHOUT 
  retrieves the password for a specific    ENCRYPTION, only for testing (which 
entry, searching by entry name, login,     location specified in $kdatabase)
password, hash or else                     ${bold}backup: 
${bold}note${reset}:                                        a simple command without parameters 
  retrieves the plain text note for a      that will export your database 
specific entry, searching by entry         (encrypted) in $kdatabase/backup.tgz)
name, login, password, hash or else
${bold}hash${reset}: 
  retrieves the password for a specific 
entry, searching by hash exclusively
" | sed 's/^/  /g'
}

test -z $kdatabase && {
	source $HOME/.config/k
}

kdatabase=$(echo -n $kdatabase | sed 's:/*$::')
kdbid=$(basename $kdatabase).kdb.$(echo $kdatabase | b2sum | cut -b1-8)

test "$1" != "import" && {
	test_db_exists || exit 1
} 

case "$1" in
	"get-dev") get "$2" "$3" "$4";;
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
	"key") get "$2" 5 5;;
	"totp") totp "$2";;
	"copy") copy "$2";;"c") copy "$2";;
	"note") get "$2" 10 "\$";;
	"gen") genusername; echo; genkey; echo; head -c 10 /dev/urandom | base32;;
	"export") exportdb "$2";;
	"import") importdb "$2";;
	"exportraw") exportraw "$2";;
	"backup") create_backup;;
	*) usage; exit 2;;
esac
