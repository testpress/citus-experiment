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
    echo "Adding Citus repository with jammy as the release name..."
    echo "deb [arch=amd64] https://repos.citusdata.com/community/debian/ jammy main" | sudo tee /etc/apt/sources.list.d/citusdata_community.list
    wget --quiet -O - https://repos.citusdata.com/community/debian/KEY.gpg | sudo apt-key add -
}

add_citus_repository() {
    echo "Adding Citus repository with jammy as the release name..."
    echo "deb [arch=amd64] https://repos.citusdata.com/community/debian/ jammy main" | sudo tee /etc/apt/sources.list.d/citusdata_community.list
    # Download the GPG key directly to the trusted.gpg.d directory
    curl -fsSL https://repos.citusdata.com/community/debian/KEY.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/citus.gpg > /dev/null
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
