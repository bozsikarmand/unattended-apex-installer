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
while [[ ! $APEX_EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; do
    echo "Invalid email format. Please try again."
    read -r -p "Enter email address for APEX admin: " APEX_EMAIL
done

read -r -s -p "Enter Oracle database password: " DB_PASSWORD
echo
while [[ ${#DB_PASSWORD} -lt 8 ]]; do
    echo "Password must be at least 8 characters long"
    read -r -s -p "Enter Oracle database password: " DB_PASSWORD
    echo
done

read -r -s -p "Enter APEX admin password: " APEX_PASSWORD
echo
# Fixed password validation with properly escaped special characters
while [[ ${#APEX_PASSWORD} -lt 12 ]] || \
      [[ ! $APEX_PASSWORD =~ [A-Z] ]] || \
      [[ ! $APEX_PASSWORD =~ [a-z] ]] || \
      [[ ! $APEX_PASSWORD =~ [0-9] ]] || \
      [[ ! $APEX_PASSWORD =~ [\!\@\#\$\%\^\&\*] ]]; do
    echo "Password must contain at least 12 characters, including uppercase, lowercase, numbers, and special characters (!@#$%^&*)"
    read -r -s -p "Enter APEX admin password: " APEX_PASSWORD
    echo
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
