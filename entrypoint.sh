#!/bin/sh -x
#

tmp_path=${tmp_path:-"/tmp"}
BORG_PASSPHRASE=${BORG_PASSPHRASE:-'verylongandsecure'}
#mysql_db_containers=${mysql_db_containers:-"foo bar baz"}
backup_paths=${backup_paths:-"foo bar baz"}
borg_remote=${borg_remote:-"BORG_RELOCATED_REPO_ACCESS_IS_OK=yes BORG_RSH=\"ssh -i /tmp/key -o StrictHostKeyChecking=no\" BORG_PASSPHRASE=$BORG_PASSPHRASE /tmp/borg"}
INTERVAL=${INTERVAL:-86400}
host=${host:-"nya.foo.bar"}
port=${port:-1337}
remote_user=${remote_user:-"foo"}
remote_host=${remote_host:-"bla.foo.bar"}
remote_port=${remote_port:-22}

sshremote="ssh -p $remote_port -o StrictHostKeyChecking=no -i /key/private.key $remote_user@$remote_host"

rip_dbs()
{
	username=$1

	echo Now ripping DBs

	for name in $mysql_db_containers; do 
		echo ripping DB: $name
		$sshremote "docker exec $name /bin/sh -c '/usr/bin/mysqldump --all-databases --password=\$MYSQL_ROOT_PASSWORD' > $tmp_path/$name.sql"
		$sshremote $borg_remote create \
			--verbose --filter AME \
			--list --stats --show-rc \
			--compression zstd,5 --exclude-caches \
			ssh://$username@$host:$port/repo::$name-{hostname}-{now} \
			$tmp_path/$name.sql 2>&1
		$sshremote rm $tmp_path/$name.sql
	done
}

file_exist_remote()
{

	$sshremote test $1;
	return $?
}

rip_repos()
{
	username=$1

	echo Now ripping paths
	
	if [ ! -z $bacup_paths ]; then

		$sshremote $borg_remote create \
			--verbose --filter AME \
			--list --stats --show-rc \
			--compression zstd,5 --exclude-caches \
			ssh://$username@$host:$port/repo::'{hostname}-{now}' \
			$backup_paths 2>&1
	fi
}

create_user()
{
	u_name=$1
	passw=`head -3 /dev/urandom | tr -cd '[:alnum:]' | cut -c -10`
	adduser -D -h /home/$u_name --uid 1000 $u_name 
	passwd $u_name -d $passw
	# change to groups later
	chown -R $u_name:$u_name /repo
	mkdir /home/$u_name/.ssh
	ssh-keygen -t ed25519 -f /home/$u_name/.ssh/foo -q -P ""
	cat /home/$u_name/.ssh/foo.pub >> /home/$u_name/.ssh/authorized_keys	
	scp -i /key/private.key -P $remote_port -o StrictHostKeyChecking=no /home/$u_name/.ssh/foo $remote_user@$remote_host:/tmp/key
}

del_user()
{
	u_name=$1
	deluser --remove-home $u_name
	$sshremote rm /tmp/key
}

init()
{
	if [ ! -f /borg/borg_x86_64 ]; then
		wget https://github.com/borgbackup/borg/releases/download/1.1.11/borg-linux64 -O /borg/borg_x86_64
	fi
	if [ ! -f /borg/borg_armv67 ]; then
		wget https://dl.bintray.com/borg-binary-builder/borg-binaries/borg-1.1.11-armv6 -O /borg/borg_armv67
	fi
	if [ ! -f /borg/borg_arm64 ]; then
		wget https://dl.bintray.com/borg-binary-builder/borg-binaries/borg-1.1.11-arm64 -O /borg/borg_arm64
	fi
	chmod +x /borg/borg_x86_64
	chmod +x /borg/borg_armv67
	chmod +x /borg/borg_arm64
	borg init --encryption=repokey-blake2 /repo
	ssh-keygen -f /borg/ssh_host_ed25519_key -N '' -t ed25519
	/usr/sbin/sshd -h /borg/ssh_host_ed25519_key &
	chown -R root:root /key
	chmod 600 /key/private.key 
}


put_borg()
{
	username=$1
	
	echo shipping my executables

	if ! file_exist_remote /tmp/borg; then
	
		binary=borg_x86_64
		arch=`$sshremote uname -m`
	
		if [[ "$arch" =~ "armv6" ]] || [[ "$arch" =~ "armv7" ]]; then
			binary=borg_armv67
		fi

		if [[ "$arch" =~ "armv8" ]] || [[ "$arch" =~ "arm64" ]]; then
			binary=borg_arm64
		fi

		scp -i /key/private.key -P $remote_port -o StrictHostKeyChecking=no /borg/$binary $remote_user@$remote_host:/tmp/borg
	fi
}


init
while true; do
	user_name=`head -3 /dev/urandom | tr -cd '[:alnum:]' | cut -c -10`
	create_user $user_name		
	put_borg $user_name
	rip_repos $user_name
	rip_dbs $user_name
	del_user $user_name
	sleep $INTERVAL

done 
