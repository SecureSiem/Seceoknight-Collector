#!/usr/bin/env bash

# Seceoknight Security Platform Installer
# Based on Wazuh 4.11.2 - Customized for Seceoknight
# This script installs Wazuh Manager, Indexer (no dashboard), and custom rules/integrations

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# GitHub Configuration for custom rules/integrations
GITHUB_TOKEN="${GITHUB_TOKEN:-}"  # Set via environment variable or leave empty for public repos
REPO_OWNER="${REPO_OWNER:-SecureSiem}"
REPO_NAME="${REPO_NAME:-Seceoknight-Collector}"
BRANCH="${BRANCH:-main}"

# Wazuh version
readonly WAZUH_VERSION="4.14"
readonly WAZUH_INSTALLER_URL="https://packages.wazuh.com/4.14/wazuh-install.sh"

# Seceoknight branding
readonly SECEOKNIGHT_NAME="seceoknight"
readonly ORIGINAL_NAME="wazuh"

# Log file
readonly LOGFILE="/var/log/seceoknight-install.log"

# Function to print animated text
animate_text() {
    local text="$1"
    local color="${2:-$CYAN}"
    printf "${color}"
    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep 0.02
    done
    printf "${NC}\n"
    sleep 0.1
}

# Function to draw a progress bar
progress_bar() {
    local title="$1"
    local duration=${2:-3}
    local cols=$(($(tput cols) - 10))
    local space_padding=$(( (cols - ${#title}) / 2 ))

    printf "${BLUE}%${space_padding}s${BOLD}${title}${NC}\n"

    for ((i = 0; i <= cols; i++)); do
        sleep $(echo "scale=3; $duration/$cols" | bc 2>/dev/null || echo "0.01")
        printf "${GREEN}▓"
    done
    printf "${NC}\n"
}

# Function to display a spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    printf "${YELLOW}${BOLD} "
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b${NC}"
}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "${LOGFILE}"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOGFILE}"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOGFILE}"
}

# Function to download file from GitHub repository
download_from_github() {
    local github_path="$1"
    local destination="$2"
    
    local curl_opts="-sSL"
    if [ -n "$GITHUB_TOKEN" ]; then
        curl_opts="$curl_opts -H Authorization: token ${GITHUB_TOKEN}"
    fi
    
    curl $curl_opts \
         "https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/${github_path}" \
         -o "${destination}" 2>> "${LOGFILE}"
    
    return $?
}

# Function to display Seceoknight ASCII art
show_seceoknight_banner() {
    clear
    cat << "EOF"
███████╗███████╗ ██████╗███████╗ ██████╗ ██╗  ██╗███╗   ██╗██╗ ██████╗ ██╗  ██╗████████╗
██╔════╝██╔════╝██╔════╝██╔════╝██╔═══██╗██║ ██╔╝████╗  ██║██║██╔════╝ ██║  ██║╚══██╔══╝
███████╗█████╗  ██║     █████╗  ██║   ██║█████╔╝ ██╔██╗ ██║██║██║  ███╗███████║   ██║   
╚════██║██╔══╝  ██║     ██╔══╝  ██║   ██║██╔═██╗ ██║╚██╗██║██║██║   ██║██╔══██║   ██║   
███████║███████╗╚██████╗███████╗╚██████╔╝██║  ██╗██║ ╚████║██║╚██████╔╝██║  ██║   ██║   
╚══════╝╚══════╝ ╚═════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   
EOF
    echo ""
}

# Function for the watermark animation at the end
display_completion_watermark() {
    clear
    echo ""
    animate_text "           INSTALLATION COMPLETE           " "${GREEN}${BOLD}"
    echo ""
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════╗
║                    SECEOKNIGHT SECURITY PLATFORM                           ║
║                         Installation Complete                              ║
╚══════════════════════════════════════════════════════════════════════════╝
EOF
    echo ""
}

# Cleanup functions
cleanup_existing() {
    log_info "Cleaning up existing installations..."
    
    # Stop and disable existing services
    systemctl stop wazuh-manager.service &>/dev/null || true
    systemctl stop wazuh-indexer.service &>/dev/null || true
    systemctl stop wazuh-dashboard.service &>/dev/null || true
    systemctl stop filebeat.service &>/dev/null || true
    
    systemctl disable wazuh-manager.service &>/dev/null || true
    systemctl disable wazuh-indexer.service &>/dev/null || true
    systemctl disable wazuh-dashboard.service &>/dev/null || true
    systemctl disable filebeat.service &>/dev/null || true
    
    # Remove existing Seceoknight services if they exist
    if [ -f /etc/systemd/system/seceoknight-manager.service ]; then
        systemctl stop seceoknight-manager.service &>/dev/null || true
        systemctl disable seceoknight-manager.service &>/dev/null || true
        rm -f /etc/systemd/system/seceoknight-manager.service
    fi
    
    if [ -f /etc/systemd/system/seceoknight-indexer.service ]; then
        systemctl stop seceoknight-indexer.service &>/dev/null || true
        systemctl disable seceoknight-indexer.service &>/dev/null || true
        rm -f /etc/systemd/system/seceoknight-indexer.service
    fi
    
    if [ -f /etc/systemd/system/seceoknight-filebeat.service ]; then
        systemctl stop seceoknight-filebeat.service &>/dev/null || true
        systemctl disable seceoknight-filebeat.service &>/dev/null || true
        rm -f /etc/systemd/system/seceoknight-filebeat.service
    fi
    
    # Remove Wazuh Dashboard if installed
    if command -v apt-get &>/dev/null; then
        apt-get purge -y wazuh-dashboard &>/dev/null || true
    elif command -v yum &>/dev/null; then
        yum remove -y wazuh-dashboard &>/dev/null || true
    fi
    
    rm -rf /var/ossec/dashboard /etc/wazuh-dashboard /usr/share/wazuh-dashboard
    
    # Remove service files
    rm -f /etc/systemd/system/wazuh-dashboard.service
    rm -f /usr/lib/systemd/system/wazuh-dashboard.service
    rm -f /lib/systemd/system/wazuh-dashboard.service
    
    # Reload systemd
    systemctl daemon-reload &>/dev/null || true
    
    log_info "Cleanup completed"
}

# Rename service file function
rename_service_file() {
    local old_name="$1"
    local new_name="$2"
    local service_file=""
    
    # Find the service file
    if [ -f "/etc/systemd/system/${old_name}.service" ]; then
        service_file="/etc/systemd/system/${old_name}.service"
    elif [ -f "/usr/lib/systemd/system/${old_name}.service" ]; then
        service_file="/usr/lib/systemd/system/${old_name}.service"
    elif [ -f "/lib/systemd/system/${old_name}.service" ]; then
        service_file="/lib/systemd/system/${old_name}.service"
    fi
    
    if [ -n "$service_file" ]; then
        # Read the content and replace
        local new_file="${service_file/\/$old_name\./\/$new_name.}"
        sed -i "s/${old_name}/${new_name}/g" "$service_file"
        mv "$service_file" "$new_file"
        log_info "Renamed service: ${old_name} → ${new_name}"
    fi
}

# Generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-24
}

# Generate or use provided JWT secret
get_jwt_secret() {
    # If JWT_SECRET environment variable is set, use it
    # Otherwise, generate a random one
    if [ -n "$JWT_SECRET" ]; then
        echo "$JWT_SECRET"
    else
        openssl rand -hex 32
    fi
}

# Create dashboard configuration
create_dashboard_config() {
    local server_ip="$1"
    local api_password="$2"
    local indexer_password="$3"
    local jwt_secret="$4"
    
    # Create API configuration directory
    mkdir -p /var/ossec/api/configuration
    
    # Create dashboard.env file
    cat > /var/ossec/api/configuration/dashboard.env <<EOF
# Seceoknight Dashboard Connection Configuration
# Generated on $(date)
# Copy these values to your custom dashboard's .env file

# Wazuh API Configuration
WAZUH_HOST=${server_ip}
WAZUH_PORT=55000
WAZUH_USERNAME=wazuh
WAZUH_PASSWORD=${api_password}

# JWT Secret (for dashboard authentication)
JWT_SECRET=${jwt_secret}

# OpenSearch Configuration
OPENSEARCH_HOST=${server_ip}
OPENSEARCH_PORT=9200
OPENSEARCH_USERNAME=admin
OPENSEARCH_PASSWORD=${indexer_password}
EOF
    
    chmod 600 /var/ossec/api/configuration/dashboard.env
    chown root:wazuh /var/ossec/api/configuration/dashboard.env 2>/dev/null || true
    
    # Create JSON version
    cat > /var/ossec/api/configuration/dashboard.json <<EOF
{
  "wazuh": {
    "host": "${server_ip}",
    "port": 55000,
    "username": "wazuh",
    "password": "${api_password}"
  },
  "jwt": {
    "secret": "${jwt_secret}"
  },
  "opensearch": {
    "host": "${server_ip}",
    "port": 9200,
    "username": "admin",
    "password": "${indexer_password}"
  }
}
EOF
    
    chmod 600 /var/ossec/api/configuration/dashboard.json
    chown root:wazuh /var/ossec/api/configuration/dashboard.json 2>/dev/null || true
    
    log_info "Dashboard configuration files created"
}

# Download and install custom rules
install_custom_rules() {
    log_info "Installing custom rules..."
    animate_text "→ Installing Seceoknight rules..." "${CYAN}"
    
    # Define local_rules.xml and local_decoder.xml to download (Wazuh creates directories by default)
    # Repo structure: Local/local_rules.xml and Decoder/local_decoder.xml
    local RULES=(
        "Local/local_rules.xml:/var/ossec/etc/rules/local_rules.xml"
        "Decoder/local_decoder.xml:/var/ossec/etc/decoders/local_decoder.xml"
    )
    
    local downloaded=0
    local failed=0
    
    for rule in "${RULES[@]}"; do
        IFS=':' read -r src dest <<< "$rule"
        if download_from_github "$src" "$dest"; then
            # local_rules.xml: 777 permissions (rwxrwxrwx), wazuh:wazuh ownership
            chmod 777 "$dest" 2>/dev/null || true
            chown wazuh:wazuh "$dest" 2>/dev/null || true
            log_info "Downloaded: $src (permissions: 777, owner: wazuh:wazuh)"
            downloaded=$((downloaded + 1))
        else
            log_warn "Failed to download: $src"
            failed=$((failed + 1))
        fi
    done
    
    log_info "Rules installed: $downloaded, Failed: $failed"
}

# Configure external access
configure_external_access() {
    log_info "Configuring external access..."
    
    # Update OpenSearch to listen on all interfaces
    if [ -f /etc/wazuh-indexer/opensearch.yml ]; then
        # Ensure network.host is set to 0.0.0.0
        if grep -q "^network.host:" /etc/wazuh-indexer/opensearch.yml; then
            sed -i 's/^network.host:.*/network.host: 0.0.0.0/' /etc/wazuh-indexer/opensearch.yml
        else
            echo "network.host: 0.0.0.0" >> /etc/wazuh-indexer/opensearch.yml
        fi
        log_info "OpenSearch configured to listen on all interfaces"
    fi
    
    # Configure firewall if ufw is available
    if command -v ufw &>/dev/null; then
        ufw allow 9200/tcp &>/dev/null || true
        ufw allow 55000/tcp &>/dev/null || true
        ufw allow 1514/tcp &>/dev/null || true
        ufw allow 1515/tcp &>/dev/null || true
        log_info "Firewall rules added (ufw)"
    fi
    
    # Configure firewall if firewalld is available
    if command -v firewall-cmd &>/dev/null; then
        firewall-cmd --permanent --add-port=9200/tcp &>/dev/null || true
        firewall-cmd --permanent --add-port=55000/tcp &>/dev/null || true
        firewall-cmd --permanent --add-port=1514/tcp &>/dev/null || true
        firewall-cmd --permanent --add-port=1515/tcp &>/dev/null || true
        firewall-cmd --reload &>/dev/null || true
        log_info "Firewall rules added (firewalld)"
    fi
}

# Display final summary
display_summary() {
    local server_ip=$(hostname -I | awk '{print $1}')
    
    # Read passwords from dashboard.env if available
    local wazuh_password=""
    local jwt_secret=""
    local opensearch_password=""
    
    if [ -f /var/ossec/api/configuration/dashboard.env ]; then
        wazuh_password=$(grep "WAZUH_PASSWORD=" /var/ossec/api/configuration/dashboard.env | cut -d'=' -f2-)
        jwt_secret=$(grep "JWT_SECRET=" /var/ossec/api/configuration/dashboard.env | cut -d'=' -f2-)
        opensearch_password=$(grep "OPENSEARCH_PASSWORD=" /var/ossec/api/configuration/dashboard.env | cut -d'=' -f2-)
    fi
    
    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║              SECEOKNIGHT INSTALLATION COMPLETE!                      ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Services Status Section
    echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  SERVICES STATUS                                                    │${NC}"
    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    local indexer_status=$(systemctl is-active seceoknight-indexer.service 2>/dev/null || echo "unknown")
    local manager_status=$(systemctl is-active seceoknight-manager.service 2>/dev/null || echo "unknown")
    local filebeat_status=$(systemctl is-active seceoknight-filebeat.service 2>/dev/null || echo "unknown")
    
    echo -e "  ${GREEN}●${NC} Seceoknight Indexer:  ${BOLD}${indexer_status}${NC}"
    echo -e "  ${GREEN}●${NC} Seceoknight Manager:  ${BOLD}${manager_status}${NC}"
    echo -e "  ${GREEN}●${NC} Seceoknight Filebeat: ${BOLD}${filebeat_status}${NC}"
    echo ""
    
    # Server Information Section
    echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  SERVER INFORMATION                                                 │${NC}"
    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${YELLOW}Server IP:${NC}     ${BOLD}${server_ip}${NC}"
    echo -e "  ${YELLOW}Server Host:${NC}   ${BOLD}https://${server_ip}${NC}"
    echo ""
    
    # Connection Endpoints Section
    echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  CONNECTION ENDPOINTS FOR YOUR CUSTOM DASHBOARD                     │${NC}"
    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${MAGENTA}OpenSearch API:${NC}  ${BOLD}https://${server_ip}:9200${NC}"
    echo -e "  ${MAGENTA}Wazuh API:${NC}       ${BOLD}https://${server_ip}:55000${NC}"
    echo ""
    
    # Dashboard Configuration Section
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}║        COPY THESE VALUES TO YOUR CUSTOM DASHBOARD .env FILE          ║${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}# ═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}# WAZUH API CONFIGURATION${NC}"
    echo -e "${CYAN}# ═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}WAZUH_HOST=${server_ip}${NC}"
    echo -e "${GREEN}WAZUH_PORT=55000${NC}"
    echo -e "${GREEN}WAZUH_USERNAME=wazuh${NC}"
    echo -e "${GREEN}WAZUH_PASSWORD=${wazuh_password}${NC}"
    echo ""
    
    echo -e "${CYAN}# ═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}# JWT AUTHENTICATION (for dashboard session management)${NC}"
    echo -e "${CYAN}# ═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}JWT_SECRET=${jwt_secret}${NC}"
    echo ""
    
    echo -e "${CYAN}# ═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}# OPENSEARCH CONFIGURATION (for alerts and logs)${NC}"
    echo -e "${CYAN}# ═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}OPENSEARCH_HOST=${server_ip}${NC}"
    echo -e "${GREEN}OPENSEARCH_PORT=9200${NC}"
    echo -e "${GREEN}OPENSEARCH_USERNAME=admin${NC}"
    echo -e "${GREEN}OPENSEARCH_PASSWORD=${opensearch_password}${NC}"
    echo ""
    
    echo -e "${YELLOW}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Configuration Files Section
    echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  CONFIGURATION FILES LOCATION                                       │${NC}"
    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${YELLOW}Environment file:${NC}  /var/ossec/api/configuration/dashboard.env"
    echo -e "  ${YELLOW}JSON file:${NC}         /var/ossec/api/configuration/dashboard.json"
    echo ""
    echo -e "  ${CYAN}To copy to your dashboard server:${NC}"
    echo -e "  ${BOLD}scp /var/ossec/api/configuration/dashboard.env user@dashboard-server:/path/to/dashboard/${NC}"
    echo ""
    
    # Index Information Section
    echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  INDEX INFORMATION (for your dashboard queries)                      │${NC}"
    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${YELLOW}Alert Indices:${NC}     wazuh-alerts-4.x-*"
    echo -e "  ${YELLOW}Archive Indices:${NC}  wazuh-archives-4.x-*"
    echo -e "  ${YELLOW}Monitoring:${NC}       .wazuh-*"
    echo ""
    
    # Important Notes Section
    echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  IMPORTANT NOTES                                                    │${NC}"
    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} Copy the configuration values above to your dashboard's .env file"
    echo -e "  ${YELLOW}2.${NC} Ensure your dashboard server can reach these ports:"
    echo -e "     • ${BOLD}https://${server_ip}:9200${NC} (OpenSearch - for alerts/logs)"
    echo -e "     • ${BOLD}https://${server_ip}:55000${NC} (Wazuh API - for agents/status)"
    echo -e "  ${YELLOW}3.${NC} Configure firewall to allow connections from your dashboard IP:"
    echo -e "     • ${BOLD}ufw allow from <dashboard-ip> to any port 9200,55000${NC}"
    echo -e "  ${YELLOW}4.${NC} Test API connection from dashboard server:"
    echo -e "     • ${BOLD}curl -k -u wazuh:${wazuh_password} https://${server_ip}:55000/${NC}"
    echo -e "  ${YELLOW}5.${NC} Test OpenSearch connection from dashboard server:"
    echo -e "     • ${BOLD}curl -k -u admin:${opensearch_password} https://${server_ip}:9200/${NC}"
    echo ""
    
    # Service Management Section
    echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  SERVICE MANAGEMENT COMMANDS                                        │${NC}"
    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${YELLOW}Check status:${NC}"
    echo -e "    ${BOLD}systemctl status seceoknight-indexer${NC}"
    echo -e "    ${BOLD}systemctl status seceoknight-manager${NC}"
    echo -e "    ${BOLD}systemctl status seceoknight-filebeat${NC}"
    echo ""
    echo -e "  ${YELLOW}Restart services:${NC}"
    echo -e "    ${BOLD}systemctl restart seceoknight-indexer${NC}"
    echo -e "    ${BOLD}systemctl restart seceoknight-manager${NC}"
    echo -e "    ${BOLD}systemctl restart seceoknight-filebeat${NC}"
    echo ""
    
    # Log File Location
    echo -e "${CYAN}${BOLD}┌─────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}${BOLD}│  LOG FILE                                                           │${NC}"
    echo -e "${CYAN}${BOLD}└─────────────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${YELLOW}Installation log:${NC} ${BOLD}${LOGFILE}${NC}"
    echo -e "  ${YELLOW}View logs:${NC}        ${BOLD}tail -f ${LOGFILE}${NC}"
    echo ""
    
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║              SECEOKNIGHT IS READY FOR YOUR DASHBOARD!               ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ==================== MAIN INSTALLATION ====================

# Initialize log
mkdir -p "$(dirname "$LOGFILE")"
echo "=== Seceoknight Installation Started $(date) ===" > "$LOGFILE"

# Show banner
show_seceoknight_banner
animate_text "============ Preparing to install Seceoknight ============" "${BLUE}${BOLD}"

# Cleanup existing installations
cleanup_existing

# Download Wazuh installer
animate_text "============ Downloading Wazuh Installer ============" "${BLUE}${BOLD}"
progress_bar "Downloading Core Components" 3

curl -sSL "$WAZUH_INSTALLER_URL" -o /tmp/wazuh-install.sh >> "$LOGFILE" 2>&1

if [ ! -f /tmp/wazuh-install.sh ]; then
    log_error "Failed to download Wazuh installer"
    exit 1
fi

chmod +x /tmp/wazuh-install.sh
log_info "Wazuh installer downloaded successfully"

# Run Wazuh installer (all-in-one mode, ignore minimum requirements)
animate_text "→ Installing Seceoknight Core..." "${GREEN}"
bash /tmp/wazuh-install.sh -a -i -o >> "$LOGFILE" 2>&1 &
install_pid=$!
spinner $install_pid
wait $install_pid
install_status=$?

if [ $install_status -ne 0 ]; then
    log_error "Wazuh installation failed. Check ${LOGFILE} for details."
    exit 1
fi

log_info "Core installation completed successfully"

# Post-installation configuration
progress_bar "Configuring Seceoknight" 2

# Generate passwords
animate_text "→ Generating security credentials..." "${MAGENTA}"
API_PASSWORD=$(generate_password)
INDEXER_PASSWORD=$(generate_password)
JWT_SECRET=$(get_jwt_secret)
SERVER_IP=$(hostname -I | awk '{print $1}')

if [ -n "$JWT_SECRET" ]; then
    log_info "Using provided JWT_SECRET from environment"
else
    log_info "Generated random JWT_SECRET"
fi

log_info "Security credentials generated"

# Rename services
animate_text "→ Configuring Seceoknight services..." "${CYAN}"
rename_service_file "wazuh-manager" "seceoknight-manager"
rename_service_file "wazuh-indexer" "seceoknight-indexer"
rename_service_file "filebeat" "seceoknight-filebeat"

# Reload systemd
systemctl daemon-reload >> "$LOGFILE" 2>&1

# Update API and indexer passwords
log_info "Configuring API credentials..."
/var/ossec/bin/wazuh-keystore -f api -k username -v "wazuh" >> "$LOGFILE" 2>&1
/var/ossec/bin/wazuh-keystore -f api -k password -v "$API_PASSWORD" >> "$LOGFILE" 2>&1

# Update indexer password in OpenSearch
if [ -f /etc/wazuh-indexer/opensearch-security/internal_users.yml ]; then
    HASH=$(/usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "$INDEXER_PASSWORD" 2>/dev/null | tail -1)
    sed -i "s|hash:.*|hash: \"$HASH\"|" /etc/wazuh-indexer/opensearch-security/internal_users.yml
    log_info "Indexer password updated"
fi

# Run security admin script
/usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
    -cd /etc/wazuh-indexer/opensearch-security \
    -icl -p 9200 -nhnv \
    -cacert /etc/wazuh-indexer/certs/root-ca.pem \
    -cert /etc/wazuh-indexer/certs/admin.pem \
    -key /etc/wazuh-indexer/certs/admin-key.pem \
    -h 127.0.0.1 >> "$LOGFILE" 2>&1 || true

# Configure external access
configure_external_access

# Create dashboard configuration
create_dashboard_config "$SERVER_IP" "$API_PASSWORD" "$INDEXER_PASSWORD" "$JWT_SECRET"

# Download custom rules
install_custom_rules

# Start services
animate_text "→ Starting Seceoknight services..." "${GREEN}"
systemctl enable seceoknight-indexer.service >> "$LOGFILE" 2>&1
systemctl start seceoknight-indexer.service >> "$LOGFILE" 2>&1
sleep 5

systemctl enable seceoknight-manager.service >> "$LOGFILE" 2>&1
systemctl start seceoknight-manager.service >> "$LOGFILE" 2>&1
sleep 2

systemctl enable seceoknight-filebeat.service >> "$LOGFILE" 2>&1
systemctl start seceoknight-filebeat.service >> "$LOGFILE" 2>&1

# Clean up
rm -f /tmp/wazuh-install.sh

# Display completion
display_completion_watermark
display_summary

exit 0
