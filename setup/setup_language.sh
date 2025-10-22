#!/usr/bin/env bash
# setup_language.sh - Cross-platform language selection and setup for EvoNEST
# Detects OS, asks user preference (Python/R), and sets up the environment

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
detect_os() {
    # Check for Windows environment variables first (works in WSL, Git Bash, etc.)
    if [[ -n "$WINDIR" ]] || [[ -n "$windir" ]] || [[ -n "$SYSTEMROOT" ]]; then
        OS="Windows"
    # Check if running in WSL (reports linux-gnu but has /mnt/c)
    elif [[ -d "/mnt/c/Windows" ]] || [[ -d "/mnt/c/windows" ]]; then
        OS="Windows"
    # Check OSTYPE for MSYS/Cygwin
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        OS="Windows"
    # Check uname for Git Bash and other environments
    elif [[ "$(uname -r)" == *"Microsoft"* ]] || [[ "$(uname -r)" == *"microsoft"* ]]; then
        OS="Windows"
    else
        case "$(uname -s)" in
            Linux*)     OS="Linux";;
            Darwin*)    OS="Mac";;
            CYGWIN*)    OS="Windows";;
            MINGW*)     OS="Windows";;
            MSYS*)      OS="Windows";;
            *)          OS="Unknown";;
        esac
    fi
    echo -e "${BLUE}📋 Detected OS: $OS${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Find pixi executable (may be in Windows PATH but not bash PATH)
find_pixi() {
    # First check if it's in bash PATH
    if command_exists pixi; then
        echo "pixi"
        return 0
    fi
    
    # On Windows, try pixi.exe
    if command_exists pixi.exe; then
        echo "pixi.exe"
        return 0
    fi
    
    # Check common Windows installation locations
    if [[ "$OS" == "Windows" ]]; then
        local pixi_paths=(
            "$HOME/.pixi/bin/pixi"
            "$HOME/.pixi/bin/pixi.exe"
            "/mnt/c/Users/$USER/.pixi/bin/pixi.exe"
            "/c/Users/$USER/.pixi/bin/pixi.exe"
        )
        
        for path in "${pixi_paths[@]}"; do
            if [ -f "$path" ]; then
                echo "$path"
                return 0
            fi
        done
    fi
    
    return 1
}

# Install pixi for Python workflow
install_pixi() {
    echo -e "${YELLOW}📦 Installing pixi package manager...${NC}"
    
    if [[ "$OS" == "Windows" ]]; then
        # For Windows, use PowerShell installer
        powershell -c "iwr -useb https://pixi.sh/install.ps1 | iex"
    else
        # For Mac/Linux, use curl installer
        curl -fsSL https://pixi.sh/install.sh | bash
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Pixi installed successfully${NC}"
        echo -e "${YELLOW}⚠️  Please restart your terminal and run this script again${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to install pixi${NC}"
        return 1
    fi
}

# Setup Python environment with pixi
setup_python() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🐍 Setting up Python environment with pixi${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
    
    # Check if pixi is installed
    local pixi_cmd=$(find_pixi)
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}⚠️  Pixi not found${NC}"
        install_pixi
        exit 0  # Exit to let user restart terminal
    else
        echo -e "${GREEN}✅ Pixi is already installed: $pixi_cmd${NC}"
    fi
    
    # Run pixi init if pixi.toml doesn't exist
    if [ ! -f "pixi.toml" ]; then
        echo -e "\n${YELLOW}⚙️  Initializing pixi project...${NC}"
        "$pixi_cmd" init
    
# Update pixi.toml if it doesn't exist
        echo -e "${YELLOW}📝 Creating pixi.toml configuration...${NC}"
        cat > pixi.toml << 'EOF'
[project]
name = "evonest-data-science"
version = "0.1.0"
description = "Data science tools for EvoNEST platform"
channels = ["conda-forge"]
platforms = ["win-64", "linux-64", "osx-64", "osx-arm64"]

[dependencies]
python = ">=3.10"
requests = ">=2.31.0"
pandas = ">=2.0.0"
numpy = ">=1.24.0"
jupyterlab = ">=4.0.0"
matplotlib = ">=3.7.0"
seaborn = ">=0.12.0"

[tasks]
fetch = "python src/python/data_fetch.py"
lab = "jupyter lab"
EOF
        echo -e "${GREEN}✅ pixi.toml created${NC}"
    fi
    
    # Install dependencies
    echo -e "\n${YELLOW}📦 Installing Python dependencies...${NC}"
    "$pixi_cmd" install
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Python environment ready${NC}"
        echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}🚀 Setup complete! You can now:${NC}"
        echo -e "   ${BLUE}$pixi_cmd run fetch${NC}  - Fetch data from EvoNEST"
        echo -e "   ${BLUE}$pixi_cmd run lab${NC}    - Launch Jupyter Lab"
        echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
        
        # Ask if user wants to launch Jupyter Lab
        read -p "Launch Jupyter Lab now? (y/n): " launch
        if [[ "$launch" == "y" || "$launch" == "Y" ]]; then
            "$pixi_cmd" run lab
        fi
    else
        echo -e "${RED}❌ Failed to install dependencies${NC}"
        exit 1
    fi
}

# Find R executable
find_r() {
    # On Windows, R is often not in PATH, so check common installation locations
    if [[ "$OS" == "Windows" ]]; then
        # First check if R is in PATH
        if command_exists R; then
            echo "R"
            return 0
        fi
        
        # Check Unix-style paths (for WSL/Git Bash)
        # WSL uses /mnt/c/, Git Bash uses /c/
        local base_paths=("/mnt/c" "/c")
        
        for base in "${base_paths[@]}"; do
            # Check if R directory exists with any version
            if [ -d "$base/Program Files/R" ]; then
                # Look for R.exe in any R-* subdirectory
                for r_dir in "$base/Program Files/R/R-"*; do
                    if [ -f "$r_dir/bin/R.exe" ]; then
                        echo "$r_dir/bin/R.exe"
                        return 0
                    fi
                done
            fi
        done
        
        return 1
    else
        # On Unix-like systems, check PATH
        if command_exists R; then
            echo "R"
            return 0
        else
            return 1
        fi
    fi
}

# Check if R is installed
check_r() {
    local r_cmd=$(find_r)
    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Install R based on OS
install_r() {
    echo -e "${YELLOW}📦 Installing R...${NC}"
    
    case "$OS" in
        Linux)
            if command_exists apt-get; then
                echo -e "${BLUE}Using apt package manager${NC}"
                sudo apt-get update
                sudo apt-get install -y r-base r-base-dev
            elif command_exists yum; then
                echo -e "${BLUE}Using yum package manager${NC}"
                sudo yum install -y R
            elif command_exists dnf; then
                echo -e "${BLUE}Using dnf package manager${NC}"
                sudo dnf install -y R
            else
                echo -e "${RED}❌ No supported package manager found${NC}"
                echo -e "${YELLOW}Please install R manually from: https://cran.r-project.org/${NC}"
                return 1
            fi
            ;;
        Mac)
            if command_exists brew; then
                echo -e "${BLUE}Using Homebrew${NC}"
                brew install r
            else
                echo -e "${RED}❌ Homebrew not found${NC}"
                echo -e "${YELLOW}Please install R manually from: https://cran.r-project.org/bin/macosx/${NC}"
                return 1
            fi
            ;;
        Windows)
            echo -e "${YELLOW}Please install R manually from: https://cran.r-project.org/bin/windows/base/${NC}"
            echo -e "${YELLOW}After installation, restart this script${NC}"
            return 1
            ;;
        *)
            echo -e "${RED}❌ Unsupported OS${NC}"
            return 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ R installed successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to install R${NC}"
        return 1
    fi
}

# Setup R environment
setup_r() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}📊 Setting up R environment${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

    # Check if R is installed
    if ! check_r; then
        echo -e "${YELLOW}⚠️  R not found${NC}"
        install_r
        if [ $? -ne 0 ]; then
            exit 1
        fi
    else
        echo -e "${GREEN}✅ R is already installed${NC}"
    fi

    # Display R package installation instructions
    echo -e "\n${YELLOW}📦 Required R packages:${NC}"
    echo -e "   • httr"
    echo -e "   • jsonlite"
    echo -e "   • dplyr"
    echo -e "   • ggplot2"
    echo -e "   • tidyr"
    echo -e "   • knitr"

    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}⚠️  R package installation${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

    echo -e "Please install the required packages using one of these methods:\n"

    echo -e "${GREEN}Option 1: RStudio (Recommended)${NC}"
    echo -e "  1. Open RStudio"
    echo -e "  2. Run in the console:"
    echo -e "     ${BLUE}install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))${NC}\n"

    echo -e "${GREEN}Option 2: R Console${NC}"
    echo -e "  1. Open R or Rscript"
    echo -e "  2. Run:"
    echo -e "     ${BLUE}install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))${NC}\n"

    echo -e "${GREEN}Option 3: VSCode with R Extension${NC}"
    echo -e "  1. Install the 'R' extension in VSCode"
    echo -e "  2. Open the R terminal and run the install command above\n"

    echo -e "${GREEN}✅ R environment ready${NC}"
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 After installing packages, you can:${NC}"
    echo -e "   ${BLUE}Rscript src/R/data_fetch.R${NC}  - Fetch data from EvoNEST"
    echo -e "   ${BLUE}R${NC}                              - Launch R console"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"

    # Ask if user wants to launch R
    read -p "Launch R console now? (y/n): " launch
    if [[ "$launch" == "y" || "$launch" == "Y" ]]; then
        echo -e "${BLUE}Starting R console...${NC}"
        echo -e "${YELLOW}Run: install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))${NC}"
        echo -e "${YELLOW}Then: source('src/R/data_fetch.R')${NC}\n"
        R
    fi
}

# Main script
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}🚀 EvoNEST Data Science Environment Setup${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
    
    # Detect OS
    detect_os
    
    # Ask user for preference
    echo -e "\n${BLUE}📊 Choose your environment:${NC}"
    echo -e "   ${GREEN}1${NC}. Python (with pixi and Jupyter Lab)"
    echo -e "   ${GREEN}2${NC}. R"
    echo -e "   ${GREEN}3${NC}. Both (install both environments)"
    echo -e "   ${GREEN}q${NC}. Quit"
    
    while true; do
        read -p $'\n'"Enter your choice (1, 2, 3, or q): " choice
        
        case "$choice" in
            1)
                setup_python
                break
                ;;
            2)
                setup_r
                break
                ;;
            3)
                setup_python
                echo -e "\n${BLUE}Now setting up R...${NC}"
                sleep 2
                setup_r
                break
                ;;
            q|Q)
                echo -e "${YELLOW}👋 Exiting setup${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Please enter 1, 2, 3, or q${NC}"
                ;;
        esac
    done
    
    echo -e "\n${GREEN}✅ Setup complete!${NC}\n"
}

# Run main function
main
