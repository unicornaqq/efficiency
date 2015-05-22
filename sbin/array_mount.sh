#!/bin/sh
mount_array(){
    swarm $1 | grep -e "Lab IP SP[AB]" > /tmp/array_ip.txt
    while read line
    do
        IFS=":" 
        for i in $line; do
            if [[ $i =~ Terminal ]]; then
                IFS=" "
                for item in $i; do
                    if [[ $item =~ [0-9]+ ]]; then
                        IP=$item
                    elif [[ $item =~ SP. ]]; then
                        DIR=$1_$item
                        echo "New mount point has been added ~/mnt/$DIR"
                        mkdir -p ~/mnt/$DIR
                        sshfs root@$IP:/ ~/mnt/$DIR 
                    else
                        Nothing=$item
                    fi
                done
            fi
        done
    done </tmp/array_ip.txt
    rm -fr /tmp/array_ip.txt
}

unmount_array(){
    if [[ $1 == all ]]; then
        pattern=SP
    else
        pattern=$1
    fi

    for dir in $(find ~/mnt -maxdepth 1 -type d)
    do
        if [[ $dir =~ $pattern ]]; then
            fusermount -u $dir
            rm -fr $dir
        fi
    done
}

array_name=$2
option=$1
case $option in
    -m)
        mount_array $array_name
    ;;

    -u)
        unmount_array $array_name
    ;;

    -c)
        unmount_array all 
    ;;

    *)
        echo "usage: array_mount.sh -m|-u BR-H1002 or -c"
        exit 1
esac


