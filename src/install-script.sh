#!/bin/bash
# install.sh - Main installation script that collects user input and starts the container

# Prompt for configuration values
read -rp "Enter container name [apex]: " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-apex}

read -rp "Enter host port for Oracle DB [8521]: " DB_PORT
DB_PORT=${DB_PORT:-8521}

read -rp "Enter host port for Enterprise Manager [8500]: " EM_PORT
EM_PORT=${EM_PORT:-8500}

read -rp "Enter host port for ORDS [8023]: " ORDS_PORT
ORDS_PORT=${ORDS_PORT:-8023}

read -rp "Enter host port for ORDS HTTPS [9043]: " ORDS_SSL_PORT
ORDS_SSL_PORT=${ORDS_SSL_PORT:-9043}

read -rp "Enter host port for SSH [9922]: " SSH_PORT
SSH_PORT=${SSH_PORT:-9922}

read -rp "Enter email address for APEX admin: " APEX_EMAIL
email_regex="^(([-a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~]+|(\"([][,:;<>\&@a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~-]|(\\\\[\\ \"]))+\"))\.)*([-a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~]+|(\"([][,:;<>\&@a-zA-Z0-9\!#\$%\&\'*+/=?^_\`{\|}~-]|(\\\\[\\ \"]))+\"))@\w((-|\w)*\w)*\.(\w((-|\w)*\w)*\.)*\w{2,4}$"

while [[ ! "$APEX_EMAIL" =~ $email_regex ]]; do
    echo "Invalid email format. Please try again."
    read -r -p "Enter email address for APEX admin: " APEX_EMAIL
done

validate_password() {
    local password=$1
    local error_message=""
    
    # Check length (12-30 bytes)
    if [[ ${#password} -lt 12 || ${#password} -gt 30 ]]; then
        error_message="Password must be between 12 and 30 characters long.\n"
    fi
    
    # Check for at least one digit
    if [[ ! $password =~ [0-9] ]]; then
        error_message+="Password must contain at least one digit.\n"
    fi
    
    # Check for at least one uppercase letter
    if [[ ! $password =~ [A-Z] ]]; then
        error_message+="Password must contain at least one uppercase letter.\n"
    fi
    
    # Check for at least one lowercase letter
    if [[ ! $password =~ [a-z] ]]; then
        error_message+="Password must contain at least one lowercase letter.\n"
    fi
    
    # Check for special characters
    if [[ ! $password =~ [\$\#\_\!\@\%\^\&\*] ]]; then
        error_message+="Password must contain at least one special character (\$, #, _, !, @, %, ^, &, *).\n"
    fi
    
    # Check if password is a common word (basic check)
    if grep -iw "^${password}$" /usr/share/dict/words 2>/dev/null; then
        error_message+="Password cannot be a common word.\n"
    fi
    
    # Check for double quotes within password
    if [[ $password == *\"* ]]; then
        error_message+="Password cannot contain double quotation marks.\n"
    fi
    
    # Check if password needs to be quoted
    local needs_quotes=false
    if [[ $password =~ ^[0-9] || $password =~ ^[\$\#\_\!\@\%\^\&\*] || $password =~ [^a-zA-Z0-9\$\#\_\!\@\%\^\&\*] ]]; then
        needs_quotes=true
    fi
    
    if [[ -n "$error_message" ]]; then
        echo -e "$error_message"
        return 1
    fi
    
    if $needs_quotes; then
        echo "Note: This password will need to be quoted in SQL statements."
    fi
    
    return 0
}

# Database password prompt with validation
while true; do
    read -r -s -p "Enter Oracle database password: " DB_PASSWORD
    echo
    if validate_password "$DB_PASSWORD"; then
        break
    fi
done

# APEX admin password prompt with validation
while true; do
    read -r -s -p "Enter APEX admin password: " APEX_PASSWORD
    echo
    if validate_password "$APEX_PASSWORD"; then
        break
    fi
done

# Create temporary file with configurations
cat > config.env << EOL
APEX_EMAIL=$APEX_EMAIL
DB_PASSWORD=$DB_PASSWORD
APEX_PASSWORD=$APEX_PASSWORD
EOL

# Create the container
docker create -it \
    --name "$CONTAINER_NAME" \
    -p "${DB_PORT}":1521 \
    -p "${EM_PORT}":5500 \
    -p "${ORDS_PORT}":8080 \
    -p "${ORDS_SSL_PORT}":8443 \
    -p "${SSH_PORT}":22 \
    -e ORACLE_PWD="$DB_PASSWORD" \
    container-registry.oracle.com/database/free:latest
    
# Copy the installation scripts and config
docker cp apex-install-script.sh "${CONTAINER_NAME}":/home/oracle/
docker cp startup-script.sh "${CONTAINER_NAME}":/opt/oracle/scripts/startup/
docker cp config.env "${CONTAINER_NAME}":/home/oracle/

# Remove the temporary config file
rm config.env

# Start the container
docker start "$CONTAINER_NAME"

echo "Container ${CONTAINER_NAME} has been created and started."
echo "APEX installation will begin automatically."
echo "You can monitor the installation progress with:"
echo "docker logs -f ${CONTAINER_NAME}"

loginctl enable-linger $UID