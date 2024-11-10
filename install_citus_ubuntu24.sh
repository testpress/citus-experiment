#!/bin/bash

# Prompt and validate server type (coordinator or worker)
prompt_server_type() {
    while true; do
        read -p "Is this server a coordinator (c) or worker (w)? " server_type
        if [[ "$server_type" == "c" || "$server_type" == "w" ]]; then
            break
        else
            echo "Invalid input. Please enter 'c' for coordinator or 'w' for worker."
        fi
    done
}

# Update package lists
update_packages() {
    echo "Updating packages..."
    sudo apt update -y
}

# Install PostgreSQL 16 from the default Ubuntu repository
install_postgresql() {
    echo "Installing PostgreSQL 16..."
    sudo apt install -y postgresql-16
}

# Add Citus repository with a fixed release name (jammy)
add_citus_repository() {
    # Ensure the keyrings directory exists
    sudo mkdir -p /etc/apt/keyrings

    echo "Adding Citus GPG key..."
    sudo curl -sSL https://repos.citusdata.com/community/gpgkey | sudo gpg --dearmor -o /etc/apt/keyrings/citusdata.gpg

    if [ $? -ne 0 ]; then
        echo "Failed to add Citus GPG key. Check your permissions and try again."
        return 1
    fi

    echo "Adding Citus repository to sources list..."
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/citusdata.gpg] https://repos.citusdata.com/community/ubuntu/ jammy main" | sudo tee /etc/apt/sources.list.d/citusdata_community.list > /dev/null

    echo "Updating package list..."
    sudo apt-get update -y > /dev/null

    echo "Citus repository added successfully!"
}

# Install Citus extension for PostgreSQL 16
install_citus_extension() {
    echo "Installing Citus 12.1 for PostgreSQL 16..."
    sudo apt install -y postgresql-16-citus-12.1
}

# Configure PostgreSQL to preload the Citus extension, set listen_addresses, and update pg_hba.conf
configure_postgresql() {
    echo "Configuring PostgreSQL to load Citus extension and set listen addresses..."
    sudo sed -i "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'citus'/" /etc/postgresql/16/main/postgresql.conf
    sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/16/main/postgresql.conf

    # If this is a worker node, ask for the coordinator IP and configure pg_hba.conf
    if [[ "$server_type" == "w" ]]; then
        read -p "Enter the IP address of the coordinator node: " coordinator_ip
        echo "Allowing connections from the coordinator in pg_hba.conf..."
        echo "host    all             all             ${coordinator_ip}/32          md5" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
    fi

    # Restart PostgreSQL to apply changes
    echo "Restarting PostgreSQL to apply configuration changes..."
    sudo systemctl restart postgresql
}

# Create Citus extension in PostgreSQL if this is a coordinator node
create_citus_extension() {
    if [[ "$server_type" == "c" ]]; then
        echo "Creating Citus extension on the coordinator..."
        sudo -i -u postgres psql -c "CREATE EXTENSION citus;"
    fi
}

# Execute all functions in sequence
main() {
    prompt_server_type
    update_packages
    install_postgresql
    add_citus_repository
    update_packages
    install_citus_extension
    configure_postgresql
    create_citus_extension
    echo "Installation and setup completed successfully!"
}

# Run the main function
main
