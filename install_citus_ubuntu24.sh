#!/bin/bash

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

# Configure PostgreSQL to preload the Citus extension
configure_postgresql() {
    echo "Configuring PostgreSQL to load Citus extension..."
    sudo sed -i "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'citus'/" /etc/postgresql/16/main/postgresql.conf
    sudo systemctl restart postgresql
}

# Create Citus extension in PostgreSQL
create_citus_extension() {
    echo "Creating Citus extension..."
    sudo -u postgres psql -c "CREATE EXTENSION citus;"
}

# Execute all functions in sequence
main() {
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
