#!/bin/bash
set -e

# Paths
userConfPath="/etc/sftp/users.conf"
userConfPathLegacy="/etc/sftp-users.conf"
userConfFinalPath="/var/run/sftp/users.conf"

# Extended regular expression (ERE) for arguments
reUser='[A-Za-z0-9._][A-Za-z0-9._-]{0,31}' # POSIX.1-2008
rePass='[^:]{0,255}'
reUid='[[:digit:]]*'
reGid='[[:digit:]]*'
reDir='[^:]*'
reArgs="^($reUser)(:$rePass)(:e)?(:$reUid)?(:$reGid)?(:$reDir)?$"
reArgsMaybe="^[^:[:space:]]+:.*$" # Smallest indication of attempt to use argument
reArgSkip='^([[:blank:]]*#.*|[[:blank:]]*)$' # comment or empty line

function log() {
    echo "[entrypoint] $@"
}

function validateArg() {
    name="$1"
    val="$2"
    re="$3"

    if [[ "$val" =~ ^$re$ ]]; then
        return 0
    else
        log "ERROR: Invalid $name \"$val\", do not match required regex pattern: $re"
        return 1
    fi
}

function createUser() {
    log "Parsing user data: \"$@\""

    IFS=':' read -a args <<< $@

    skipIndex=0
    chpasswdOptions=""
    useraddOptions="--no-user-group --shell /bin/bash"

    user="${args[0]}"; validateArg "username" "$user" "$reUser" || return 1
    pass="${args[1]}"; validateArg "password" "$pass" "$rePass" || return 1

    if [ "${args[2]}" == "e" ]; then
        chpasswdOptions="-e"
        skipIndex=1
    fi

    uid="${args[$[$skipIndex+2]]}"; validateArg "UID" "$uid" "$reUid" || return 1
    gid="${args[$[$skipIndex+3]]}"; validateArg "GID" "$gid" "$reGid" || return 1
    dir="${args[$[$skipIndex+4]]}"; validateArg "dirs" "$dir" "$reDir" || return 1

    if getent passwd $user > /dev/null; then
        log "WARNING: User \"$user\" already exists. Skipping."
        return 0
    fi

    if [ -n "$uid" ]; then
        useraddOptions="$useraddOptions --non-unique --uid $uid"
    fi

    if [ -n "$gid" ]; then
        if ! getent group $gid > /dev/null; then
            groupadd --gid $gid "group_$gid"
        fi

        useraddOptions="$useraddOptions --gid $gid"
    fi

    useradd $useraddOptions $user
    mkdir -p /home/$user
    chown root:root /home/$user
    chmod 755 /home/$user

    # Retrieving user id to use it in chown commands instead of the user name
    # to avoid problems on alpine when the user name contains a '.'
    uid="$(id -u $user)"

    if [ -n "$pass" ]; then
        echo "$user:$pass" | chpasswd $chpasswdOptions
    else
        usermod -p "*" $user # disabled password
    fi

    if [ ! -f /home/$user/.vimrc ]; then
        mv /vimrc /home/$user/.vimrc
        chown $user:users /home/$user/.vimrc
    fi

    if [ ! -f /home/$user/.tmux.conf ]; then
        mv /tmux /home/$user/.tmux.conf
        chown $user:users /home/$user/.tmux.conf
    fi

    if [ -d /opt/user ]; then
        chown $user:users -R /opt/user
    fi

    # Make sure dirs exists
    if [ -n "$dir" ]; then
        IFS=',' read -a dirArgs <<< $dir
        for dirPath in ${dirArgs[@]}; do
            dirPath="/home/$user/$dirPath"
            if [ ! -d "$dirPath" ]; then
                log "Creating directory: $dirPath"
                mkdir -p $dirPath
                chown -R $uid:users $dirPath
            else
                log "Directory already exists: $dirPath"
            fi
        done
    fi
}

# Allow running other programs, e.g. bash
if [[ -z "$1" || "$1" =~ $reArgsMaybe ]]; then
    startSshd=true
else
    startSshd=false
fi

# Backward compatibility with legacy config path
if [ ! -f "$userConfPath" -a -f "$userConfPathLegacy" ]; then
    mkdir -p "$(dirname $userConfPath)"
    ln -s "$userConfPathLegacy" "$userConfPath"
fi

# Create users only on first run
if [ ! -f "$userConfFinalPath" ]; then
    mkdir -p "$(dirname $userConfFinalPath)"

    # Append mounted config to final config
    if [ -f "$userConfPath" ]; then
        cat "$userConfPath" | grep -v -E "$reArgSkip" > "$userConfFinalPath"
    fi

    if $startSshd; then
        # Append users from arguments to final config
        for user in "$@"; do
            echo "$user" >> "$userConfFinalPath"
        done
    fi

    if [ -n "$SFTP_USERS" ]; then
        # Append users from environment variable to final config
        usersFromEnv=($SFTP_USERS) # as array
        for user in "${usersFromEnv[@]}"; do
            echo "$user" >> "$userConfFinalPath"
        done
    fi

    # Check that we have users in config
    if [[ -f "$userConfFinalPath" && "$(cat "$userConfFinalPath" | wc -l)" > 0 ]]; then
        # Import users from final conf file
        while IFS= read -r user || [[ -n "$user" ]]; do
            createUser "$user"
        done < "$userConfFinalPath"
    elif $startSshd; then
        log "FATAL: No users provided!"
        exit 3
    fi
fi

/usr/bin/ruby /usr/local/bin/init_bastion.rb
/usr/bin/ruby /usr/local/bin/load_ssh_keys.rb

# Generate unique ssh keys for this container, if needed
if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
    echo "Missing ED25519 Host Key, generating..."
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
fi
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "Missing RSA Host Key, generating..."   
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ''
fi

# Source custom scripts, if any
if [ -d /etc/sftp.d ]; then
    for f in /etc/sftp.d/*; do
        if [ -x "$f" ]; then
            log "Running $f ..."
            $f
        else
            log "Could not run $f, because it's missing execute permission (+x)."
        fi
    done
    unset f
fi

sudo -u sftpuser cat << 'EOF' > /home/sftpuser/.profile
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF

sudo -u sftpuser echo "export METADATA_AUTH=${METADATA_AUTH}" >> /home/sftpuser/.bashrc
sudo -u sftpuser echo "export METADATA_URL=${METADATA_URL}" >> /home/sftpuser/.bashrc
sudo -u sftpuser echo "export METADATA_SERVICE=${METADATA_SERVICE}" >> /home/sftpuser/.bashrc

chown sftpuser:users /home/sftpuser/.profile
chown sftpuser:users /home/sftpuser/.bashrc

log "Configuring Relay for PHP"

RELAY_INI_DIR=/etc/php/8.2/mods-available/
RELAY_EXT_DIR=$(/usr/bin/php-config --extension-dir)
RELAY_INI="${RELAY_INI_DIR}relay.ini"

if [ -f /usr/src/relay/relay-pkg.so ]; then
    # if $PHP_INI_DIR/60-relay.ini does not exist, cp relay.ini to $PHP_INI_DIR/60-relay.ini
    # Allow customizations outside of the defined env vars.
    if [ ! -f "$RELAY_INI" ]; then
        cp /usr/src/relay/relay.ini "$RELAY_INI"
        /usr/sbin/phpenmod relay
    fi
    cp "/usr/src/relay/relay-pkg.so" "$RELAY_EXT_DIR/relay.so"
fi

sudo -u sftpuser /usr/bin/wp package install wp-cli/profile-command:@stable || true

# run everything in /scripts
if [ -d /opt/user/startup-scripts ]; then
    for f in /opt/user/startup-scripts/*; do
        if [ -x "$f" ]; then
            log "Running $f ..."
            $f || true
        else
            log "Could not run $f."
        fi
    done
    unset f
fi

if $startSshd; then
    log "Executing sshd"
    exec /usr/sbin/sshd -D -e
else
    log "Executing $@"
    exec "$@"
fi