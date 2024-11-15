#!/bin/bash

# Ensure server_type is set
ensure_server_type() {
    if [[ -z "$server_type" ]]; then
        while true; do
            read -p "Is this server a coordinator (c) or worker (w)? " server_type
            if [[ "$server_type" == "c" || "$server_type" == "w" ]]; then
                break
            else
                echo "Invalid input. Please enter 'c' for coordinator or 'w' for worker."
            fi
        done
    fi
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
    ensure_server_type
    echo "Configuring PostgreSQL to load Citus extension and set listen addresses..."
    sudo sed -i "s/^#shared_preload_libraries = ''/shared_preload_libraries = 'citus'/" /etc/postgresql/16/main/postgresql.conf
    sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/16/main/postgresql.conf

    # If this is a worker node, ask for the coordinator IP and configure pg_hba.conf
    if [[ "$server_type" == "w" ]]; then
        read -p "Enter the IP address of the coordinator node: " coordinator_ip
        read -p "Choose authentication method for coordinator access ('trust' or 'md5'): " auth_method
        echo "Allowing connections from the coordinator in pg_hba.conf with $auth_method authentication..."
        echo "host    all             all             ${coordinator_ip}/32          ${auth_method}" | sudo tee -a /etc/postgresql/16/main/pg_hba.conf
    fi

    # Restart PostgreSQL to apply changes
    echo "Restarting PostgreSQL to apply configuration changes..."
    sudo systemctl restart postgresql
}

# Configure authentication on workers, and output instructions if md5 is used
configure_authentication() {
    ensure_server_type

    if [[ "$server_type" == "w" ]]; then
        read -p "Choose authentication method for coordinator access ('trust' or 'md5'): " auth_method

        if [[ "$auth_method" == "md5" ]]; then
            read -s -p "Enter a password for the postgres user: " postgres_password
            echo
            sudo -i -u postgres psql -c "ALTER USER postgres PASSWORD '$postgres_password';"
            echo "Worker node configured with md5 authentication. Please make a note of the IP and password to set up .pgpass on the coordinator."
            echo "Worker IP: $(hostname -I | awk '{print $1}'), Password: $postgres_password"
        fi
    fi
}

# Prompt the coordinator to configure .pgpass if workers use md5
setup_pgpass_on_coordinator() {
    ensure_server_type
    if [[ "$server_type" == "c" ]]; then
        read -p "Do any of the worker nodes use md5 authentication? (y/n): " md5_required
        if [[ "$md5_required" == "y" ]]; then
            # Create .pgpass file on coordinator
            echo "Setting up .pgpass for worker connections..."
            touch ~/.pgpass
            chmod 600 ~/.pgpass

            # Prompt for each worker's IP and password
            read -p "Enter the number of worker nodes with md5 authentication: " num_nodes
            for (( i=1; i<=num_nodes; i++ )); do
                read -p "Enter IP address for worker node $i: " worker_ip
                read -p "Enter postgres password for worker at $worker_ip: " postgres_password
                echo "$worker_ip:5432:*:postgres:$postgres_password" >> ~/.pgpass
            done
        fi
    fi
}

# Create Citus extension in PostgreSQL if this is a coordinator node
create_citus_extension() {
    ensure_server_type
    if [[ "$server_type" == "c" ]]; then
        echo "Creating Citus extension on the coordinator..."
        sudo -i -u postgres psql -c "CREATE EXTENSION citus;"
    fi
}

# Add worker nodes to the Citus cluster on the coordinator
add_citus_nodes() {
    ensure_server_type
    if [[ "$server_type" == "c" ]]; then
        read -p "Enter the number of worker nodes to add: " num_nodes

        for (( i=1; i<=num_nodes; i++ )); do
            read -p "Enter IP address for worker node $i: " node_ip
            echo "Adding worker node with IP $node_ip to the cluster..."
            sudo -i -u postgres psql -c "SELECT * FROM master_add_node('$node_ip', 5432);"
        done

        echo "Listing all nodes in the Citus cluster:"
        sudo -i -u postgres psql -c "SELECT * FROM citus_nodes;"
    fi
}

# Execute all functions in sequence
main() {
    ensure_server_type
    update_packages
    install_postgresql
    add_citus_repository
    update_packages
    install_citus_extension
    configure_postgresql
    configure_authentication
    setup_pgpass_on_coordinator
    create_citus_extension
    add_citus_nodes
    echo "Installation and setup completed successfully!"
}

# Run the main function
main
