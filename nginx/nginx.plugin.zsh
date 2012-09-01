: ${NGINX_DIR:=/etc/nginx}

if [ $use_sudo -eq 1 ]; then
    sudo="sudo"
else
    sudo=""
fi

# nginx basic completition

_nginx_get_en_command_list () {
    ls -a $NGINX_DIR/sites-available | awk '/^[a-z][a-z.-]+$/ { print $1 }'
}

_nginx_get_dis_command_list () {
    ls -a $NGINX_DIR/sites-enabled | awk '/^[a-z][a-z.-]+$/ { print $1 }'
}

_nginx_en () {
   compadd `_nginx_get_en_command_list`
}

_nginx_dis () {
   compadd `_nginx_get_dis_command_list`
}

# Enabling a site
en () {
    if [ ! $1 ]; then
        echo "\033[337;41m\nThe name of the vhost is required!\n\033[0m";
        return
    fi
    
    if [ ! -e $NGINX_DIR/sites-available/$1 ]; then
        echo "\033[31m$1\033[0m doesn't exist";
        return
    fi

    if [ ! -e $NGINX_DIR/sites-enabled/$1 ]; then
  	    $sudo ln -s $NGINX_DIR/sites-available/$1 $NGINX_DIR/sites-enabled/$1;
	    if [ -e /etc/nginx/sites-enabled/$1 ]; then
        	echo "\033[32m$1\033[0m successfully enabled";
        else
            echo "An error occured during the enabling of \033[31m$1\033[0m";
        fi
    else
        echo "\033[31m$1\033[0m is already enabled";
    fi
}
compdef _nginx_en en

# Disabling a site
dis () {
    if [ ! $1 ]; then
        echo "\033[337;41m\nThe name of the vhost is required!\n\033[0m";
        return
    fi

    if [ ! -e $NGINX_DIR/sites-enabled/$1 ]; then
        echo "\033[31m$1\033[0m doesn't exist";
    else
	    $sudo rm -f $NGINX_DIR/sites-enabled/$1;
	    if [ ! -e $NGINX_DIR/sites-enabled/$1 ]; then
        	echo "\033[32m$1\033[0m successfully disabled";
        else
            echo "An error occured during the disabling of \033[31m$1\033[0m";
        fi
    fi
}
compdef _nginx_dis dis

# Completition of vhost
_nginx_get_possible_vhost_list () {
    ls -a $HOME/www | awk '/^[^.][a-z0-9._]+$/ { print $1 }'
}

_nginx_vhost () {
   compadd `_nginx_get_possible_vhost_list`
}

# Parsing arguments
vhost () {
    while getopts ":lu:nwh" option
    do
      case $option in
        l ) ls $NGINX_DIR/sites-enabled; return ;;
        u ) user=$OPTARG; shift 2 ;;
        n ) enable=0; shift 1 ;;
        w ) write_hosts=1; shift 1 ;;
        h ) _vhost_usage; return ;;
      esac
    done
    
    vhost=${@: -1}
    
    : ${user:=$USER}
    : ${enable:=1}
    : ${write_hosts:=0}
    
    if [ ! $vhost ]; then
        echo "\033[337;41m\nThe name of the vhost is required!\n\033[0m"
        return
    fi
    
    _vhost_generate $vhost $user
    
    if [ $enable -eq 1 ]; then
        en $vhost
    fi
    
    if [ $write_hosts -eq 1 ]; then
        _write_hosts $vhost
    fi
}
compdef _nginx_vhost vhost

_vhost_usage () {
    echo "Usage: vhost [options] [vhost_name]"
    echo
    echo "Options"
    echo "  -l   Lists enabled vhosts"
    echo "  -u   Sets the user - defaults to the current user ($USER)"
    echo "  -n   Does not enable the generated vhost"
    echo "  -w   Write the vhost to the /etc/hosts file pointing to 127.0.0.1 (writes it at the end of the first line actually)"
    echo "  -h   Get this help message"
    return
}

# Generate config file
_vhost_generate () {
    user=$(cat /etc/passwd | grep $2 | awk -F : '{print $1 }')
    
    if [ ! $user ]; then
      echo "User \033[31m$2\033[0m doesn't have an account on \033[33m$HOST\033[0m"
      return
    fi

    echo "Generating \033[32m$1\033[0m vhost for \033[33m$user\033[0m user"
        
    user_id=$(cat /etc/passwd | grep $2 | awk -F : '{print $3 }')
    pool_port=1$user_id
    : ${NGINX_VHOST_TEMPLATE:=$ZSH/plugins/nginx/templates/symfony2_vhost}
    
    conf=$(sed -e 's/{vhost}/'$1'/g' -e 's/{user}/'$user'/g' -e 's/{pool_port}/'$pool_port'/g' $NGINX_VHOST_TEMPLATE )
    
    echo $conf > $1.tmp
    $sudo mv $1.tmp $NGINX_DIR/sites-available/$1
    
    if [ -e $NGINX_DIR/sites-available/$1 ]; then
        echo "\033[32m$1\033[0m vhost has been successfully created"
    else
        echo "An error occured during the creating of \033[31m$1\033[0m vhost"
    fi
}

# Write the /etc/hosts file
_write_hosts () {
    temp=$HOME/hosts.temp
    exec < /etc/hosts
	while read line
	do
		if [ -e $temp ]; then
			echo "$line" >> $temp;
		else
			echo "$line $1" > $temp;		
		fi
	done
	
	$sudo mv $temp /etc/hosts;
	
	"\033[32m$1\033[0m vhost has been successfully written in /etc/hosts"
}

alias ngt="$sudo nginx -t"
alias ngr="$sudo service nginx restart"
