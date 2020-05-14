# Remote Borg

Lets you setup a local repo and pulls data from a configured machine.

## Mysql & MariaDB

Dumps databases inside docker containers from `mariadb` or `mysql` repos on dockerhub

### Usage

Set the environment variable to the names of the mysql containers, you would like to backup

'''
    environment:
      - mysql_db_containers="container0 container1 container2"
'''

If you don't want to backup mysql containers, leave it blank

'''
    environment:
      - mysql_db_containers=
'''

## Usage

At the target machine, that you want to backup, create a user account that is accessible via ssh with the 'private.key' file, that you mount to the container. For database backups add this user to the docker group:

'''
useradd -m borg
mkdir -p /home/borg/.ssh
ssh-keygen -t ed25519 -f /home/borg/.ssh/private.key
mv /home/borg/.ssh/private.key.pub /home/borg/.ssh/authorized_keys
usermod -aG docker borg
'''

The target machine's address and SSH port must be configured as environment variables
'''
    environment:
      - remote_user=borg
      - remote_port=22
      - remote_host=machine.lan
'''
The container's address:port must be reachable from the target machine, and known to the container via environment variables:

'''
    environment:
      - port=222
      - host=backup_server.lan
'''

The paths that should be backuped are configured like so:


'''
    environment:
      - backup_paths ="/etc /var/porn /srv/leaks"
'''

If you don't want to backup any paths, leave it blank

'''
    environment:
      - backup_paths=
'''

The Borg Passphrase should be set and has a default value.

## platforms

automatically detected platforms are x86_64 & armv6/7/8
