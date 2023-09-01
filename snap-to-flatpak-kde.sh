#!/bin/bash

# Check if script is run as sudo user
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as a sudo user" 
   exit 1
fi

# Function to display step messages
show_step() {
    echo "============================================================================="
    echo "$1..."
    echo "============================================================================="
}

# Function to show a progress bar
show_progress() {
    local current="$1"
    local total="$2"
    local percentage=$((current * 100 / total))
    printf "\r[%-50s] %d%%" "$(printf '=' "$percentage")" "$percentage"
}

# Show introduction
echo "============================================================================="
echo "This script will perform the following actions :"
echo "1. List current snap packages."
echo "2. Remove snap packages until none are left."
echo "3. Remove snapd package permanently."
echo "4. Prevent the downloading of snap packages by creating a preference file."
echo "5. Install KDE Software center."
echo "6. Install Firefox from Mozilla's official repositories."
echo "7. Enable auto updates of Firefox from Mozilla repositories."
echo "8. Add support for Flatpak apps."
echo "============================================================================="

# Ask the user for confirmation, whether to run the script or not?
while true; do
    read -p "Do you want to proceed? (yes/no): " choice
    case "$choice" in
        [Yy]|[Yy][Ee][Ss])
            echo "Continuing with the script..."
            break
            ;;
        [Nn]|[Nn][Oo])
            echo "Exiting script."
            exit
            ;;
        *)
            echo "Invalid choice. Please enter 'yes' or 'no'."
            ;;
    esac
done

# Loop to remove all snap packages
while [ "$(snap list | wc -l)" -gt 1 ]; do
    # Step 1: List current snap packages
    show_step "Listing current snap packages"
    snap list --all

    # Step 2: Remove all snap packages
    show_step "Removing all snap packages"
    snap_list=$(snap list | awk '{if(NR>1) print $1}')
    total_snaps=$(echo "$snap_list" | wc -l)
    current_snap=0
    for snap in $snap_list; do
        current_snap=$((current_snap + 1))
        sudo snap remove --purge $snap
        show_progress $current_snap $total_snaps
        echo "  Snap '$snap' uninstalled."
        snap list --all
    done
    echo # Print newline after progress bar

    # Step 3: Remove snapd package permanently
    show_step "Removing snapd package permanently"
    sudo apt purge snapd -y
done

echo "'Ahh... finally, snapd has been removed completely from the system'"
sleep 2

# Step 4: Prevent snap package downloads
show_step "Preventing snap package downloads"
sudo tee /etc/apt/preferences.d/nosnap.pref > /dev/null <<EOF
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF

# Step 5: Update apt repositories
echo "Updating system repositories"
sudo apt update

# Step 6: Install KDE Software
show_step "Installing KDE Software Centre"
sudo apt install plasma-discover -y

# Step 7: Install Firefox from Mozilla repositories
show_step "Installing Firefox from Mozilla repositories"

# Step 7.1: Adding Mozilla repositories
sudo add-apt-repository ppa:mozillateam/ppa

# Step 7.2: Update apt repositories
sudo apt update

# Step 7.3: Install Firefox
sudo apt install -t 'o=LP-PPA-mozillateam' firefox -y

# Step 7.3: Enable automatic updates
echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:${distro_codename}";' | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

# Step 8: Creating preferencee file for Firefox updates from Mozilla repositories
show_step "Setting up Firefox updates from Mozilla repositories"
sudo tee /etc/apt/preferences.d/mozillateamppa > /dev/null <<EOF
Package: firefox*
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 501
EOF

# Step 9: Update apt repositories
sudo apt update

# Step 10: Installing Flatpak support
show_step "Adding support for Flatpak apps"
echo "Installing required packages"
sudo apt install flatpak -y

# Step 10.1: Install the Discover Flatpak backend
sudo apt install plasma-discover-backend-flatpak -y

# Step 10.2: Add the Flathub repository
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# Step 10.3: Update the flatpak
flatpak update
sleep 5

# Final message
echo "============================================================================="
echo "Script completed successfully!"
echo "You can now use KDE Software center to manage applications and install Flatpak apps."
echo "============================================================================="