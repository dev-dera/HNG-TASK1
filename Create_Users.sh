#!/bin/bash

# create log file and secure password file with permissions
LOG_FILE="/var/log/user_management.log"                                                                                                                         
PASSWORD_FILE="/var/secure/user_passwords.txt"

# ensure the script is run as root
if [[ "$(id -u)" -ne 0 ]]; then
	echo "This script must be run as root."
	exit 1
fi

#Ensure the log file exists
touch "$LOG_FILE"

#Setup password file
if [[ ! -d "/var/secure" ]]; then
	mkdir /var/secure
fi
if [[ ! -f "$PASSWORD_FILE" ]]; then
	touch "$PASSWORD_FILE"
	chmod 600 "$PASSWORD_file"
fi

#check if the input file is provided
if [[ -z "$1" ]]; then
    echo "Usage: bash create_users.sh <name-of-text-file>"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: No input file provided." >> "$LOG_FILE"
    exit 1
fi

# Read the input file line by line
while IFS=';' read -r username groups; do
    # Skip empty lines
    [[ -z "$username" ]] && continue

    # Remove whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Create user if not exists
    if ! id "$username" &>/dev/null; then
        # Create the user with a home directory
        useradd -m -s /bin/bash "$username"
        if [[ $? -ne 0 ]]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: Failed to create user $username." >> "$LOG_FILE"
            continue
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: User $username created." >> "$LOG_FILE"

        # Generate a random password for the user
        password=$(openssl rand -base64 12)
        echo "$username:$password" | chpasswd

        # Save the password to the secure password file
        echo "$username,$password" >> "$PASSWORD_FILE"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: Password for user $username generated and stored." >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: User $username already exists." >> "$LOG_FILE"
    fi

    # Create groups and add user to them
    IFS=',' read -ra group_list <<< "$groups"
    for group in "${group_list[@]}"; do
        group=$(echo "$group" | xargs)
        # Create group if not exists
        if ! getent group "$group" >/dev/null; then
            groupadd "$group"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: Group $group created." >> "$LOG_FILE"
        fi
        # Add user to the group
        usermod -a -G "$group" "$username"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: User $username added to group $group." >> "$LOG_FILE"
    done

    # Set ownership and permissions for the home directory
    chown -R "$username:$username" "/home/$username"
    chmod 700 "/home/$username"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: Home directory for user $username set up with appropriate permissions." >> "$LOG_FILE"

done < "$1"

echo "$(date '+%Y-%m-%d %H:%M:%S') - INFO: User creation script completed." >> "$LOG_FILE"

exit 0
