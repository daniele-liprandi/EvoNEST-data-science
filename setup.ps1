# EvoNEST Data Science Setup Script for Windows
# Double-click this file to run the setup
# Command-line usage: powershell -ExecutionPolicy Bypass -File setup.ps1 [-Uninstall]

param(
    [switch]$Uninstall
)

# Uninstall pixi
function Uninstall-Pixi {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Blue
    Write-Host "  Uninstalling Pixi" -ForegroundColor Blue
    Write-Host "========================================================" -ForegroundColor Blue
    Write-Host ""

    # Step 1: Clean pixi cache
    Write-Host "1️⃣  Cleaning pixi cache..." -ForegroundColor Yellow
    if (Get-Command pixi -ErrorAction SilentlyContinue) {
        & pixi clean cache 2>$null
        Write-Host "✅ Cache cleaned" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Pixi not in PATH, skipping cache clean" -ForegroundColor Yellow
    }

    # Step 2: Clean workspace environment
    Write-Host ""
    Write-Host "2️⃣  Cleaning workspace environment..." -ForegroundColor Yellow
    if ((Test-Path "pixi.lock") -or (Test-Path "pixi.toml")) {
        if (Get-Command pixi -ErrorAction SilentlyContinue) {
            & pixi clean 2>$null
            Write-Host "✅ Workspace cleaned" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠️  No pixi workspace found in current directory" -ForegroundColor Yellow
    }

    # Step 3: Remove pixi directory
    Write-Host ""
    Write-Host "3️⃣  Removing pixi installation directory..." -ForegroundColor Yellow
    $pixiDir = Join-Path $env:USERPROFILE ".pixi"
    if (Test-Path $pixiDir) {
        Remove-Item -Recurse -Force $pixiDir
        Write-Host "✅ Pixi directory removed" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Pixi directory not found at $pixiDir" -ForegroundColor Yellow
    }

    # Step 4: Remove workspace files
    Write-Host ""
    Write-Host "4️⃣  Removing workspace files..." -ForegroundColor Yellow
    if (Test-Path "pixi.toml") {
        Remove-Item -Force "pixi.toml"
        Write-Host "✅ pixi.toml removed" -ForegroundColor Green
    }
    if (Test-Path "pixi.lock") {
        Remove-Item -Force "pixi.lock"
        Write-Host "✅ pixi.lock removed" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "✅ Pixi uninstalled successfully" -ForegroundColor Green
    Write-Host "⚠️  Manual step required:" -ForegroundColor Yellow
    Write-Host "   Remove %UserProfile%\.pixi\bin from your PATH environment variable" -ForegroundColor Yellow
    Write-Host ""
}

# Uninstall R
function Uninstall-R {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Blue
    Write-Host "  Uninstalling R" -ForegroundColor Blue
    Write-Host "========================================================" -ForegroundColor Blue
    Write-Host ""

    Write-Host "⚠️  Automatic R uninstall is not available on Windows." -ForegroundColor Yellow
    Write-Host "Please uninstall R manually through:" -ForegroundColor Yellow
    Write-Host "  Settings > Apps > Apps & features > Search for 'R'" -ForegroundColor Yellow
    Write-Host ""
}

# Find RStudio installation
function Find-RStudio {
    $rstudioPaths = @(
        "C:\Program Files\RStudio\rstudio.exe",
        "C:\Program Files\RStudio\bin\rstudio.exe",
        "C:\Program Files (x86)\RStudio\rstudio.exe",
        "C:\Program Files (x86)\RStudio\bin\rstudio.exe",
        "$env:LOCALAPPDATA\Programs\RStudio\rstudio.exe"
    )

    foreach ($path in $rstudioPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    # Check if rstudio is in PATH
    if (Get-Command rstudio -ErrorAction SilentlyContinue) {
        return "rstudio"
    }

    return $null
}

# Open R Markdown file in RStudio
function Open-RStudio {
    $notebookPath = "src\R\Notebook.Rmd"
    
    if (-not (Test-Path $notebookPath)) {
        Write-Host "❌ R Notebook not found at $notebookPath" -ForegroundColor Red
        return $false
    }
    
    $rstudioPath = Find-RStudio
    if (-not $rstudioPath) {
        Write-Host "❌ RStudio not found" -ForegroundColor Red
        return $false
    }
    
    Write-Host "📖 Opening R Markdown notebook in RStudio..." -ForegroundColor Yellow
    
    $fullPath = Join-Path $PWD $notebookPath
    Start-Process $rstudioPath -ArgumentList $fullPath
    
    Write-Host "✅ RStudio launched with Notebook.Rmd" -ForegroundColor Green
    return $true
}

# Main uninstall flow
function Invoke-Uninstall {
    Write-Host "========================================================" -ForegroundColor Blue
    Write-Host "  EvoNEST Data Science Environment Uninstaller" -ForegroundColor Red
    Write-Host "========================================================" -ForegroundColor Blue
    Write-Host ""

    Write-Host "What would you like to uninstall?" -ForegroundColor Cyan
    Write-Host "  1. Python (pixi)" -ForegroundColor Green
    Write-Host "  2. R" -ForegroundColor Green
    Write-Host "  3. Both" -ForegroundColor Green
    Write-Host "  q. Quit" -ForegroundColor Green
    Write-Host ""

    $choice = Read-Host "Enter your choice (1, 2, 3, or q)"

    switch ($choice) {
        "1" {
            Uninstall-Pixi
        }
        "2" {
            Uninstall-R
        }
        "3" {
            $confirm = Read-Host "Are you sure you want to uninstall all environments? (y/N)"
            if ($confirm -eq "y" -or $confirm -eq "Y") {
                Uninstall-Pixi
                Uninstall-R
            } else {
                Write-Host "Cancelled" -ForegroundColor Yellow
            }
        }
        "q" {
            Write-Host "Exiting..." -ForegroundColor Yellow
            exit 0
        }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            Invoke-Uninstall
        }
    }
}

Write-Host "========================================================" -ForegroundColor Blue
Write-Host "  EvoNEST Data Science Environment Setup for Windows" -ForegroundColor Blue
Write-Host "========================================================" -ForegroundColor Blue
Write-Host ""

# Check if uninstall flag is set
if ($Uninstall) {
    Invoke-Uninstall
    exit 0
}

# Check if Git Bash is available
$gitBashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe",
    "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
)

$bashPath = $null
foreach ($path in $gitBashPaths) {
    if (Test-Path $path) {
        $bashPath = $path
        break
    }
}

if ($bashPath) {
    Write-Host "Found Git Bash at: $bashPath" -ForegroundColor Green
    Write-Host "Launching setup script..." -ForegroundColor Green
    Write-Host ""

    # Run the bash setup script, passing uninstall flag if specified
    if ($Uninstall) {
        & $bashPath -c "cd '$PWD' && bash setup/setup_language.sh --uninstall"
    } else {
        & $bashPath -c "cd '$PWD' && bash setup/setup_language.sh"
    }
} else {
    Write-Host "Git Bash not found. Running PowerShell-native setup..." -ForegroundColor Yellow
    Write-Host ""

    # Fallback: Direct PowerShell setup for Python with pixi
    Write-Host "Choose your environment:" -ForegroundColor Cyan
    Write-Host "  1. Python (with pixi and Jupyter Lab)" -ForegroundColor Green
    Write-Host "  2. R" -ForegroundColor Green
    Write-Host "  u. Uninstall" -ForegroundColor Green
    Write-Host "  q. Quit" -ForegroundColor Green
    Write-Host ""

    $choice = Read-Host "Enter your choice (1, 2, u, or q)"

    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "Setting up Python environment with pixi..." -ForegroundColor Cyan
            Write-Host ""

            # Check if pixi is installed
            $pixiInstalled = Get-Command pixi -ErrorAction SilentlyContinue

            if (-not $pixiInstalled) {
                Write-Host "Installing pixi package manager..." -ForegroundColor Yellow
                Invoke-Expression "& { $(Invoke-RestMethod https://pixi.sh/install.ps1) }"

                Write-Host ""
                Write-Host "Pixi installed successfully!" -ForegroundColor Green
                Write-Host "Please restart your terminal and run this script again." -ForegroundColor Yellow
                Write-Host ""
                pause
                exit 0
            } else {
                Write-Host "Pixi is already installed" -ForegroundColor Green
            }

            Write-Host ""
            Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
            pixi install

            if ($LASTEXITCODE -eq 0) {
                Write-Host ""
                Write-Host "Setup complete!" -ForegroundColor Green
                Write-Host ""
                Write-Host "You can now:" -ForegroundColor Cyan
                Write-Host "  pixi run fetch  - Fetch data from EvoNEST" -ForegroundColor Blue
                Write-Host "  pixi run lab    - Launch Jupyter Lab" -ForegroundColor Blue
                Write-Host ""

                $launch = Read-Host "Launch Jupyter Lab now? (y/n)"
                if ($launch -eq "y" -or $launch -eq "Y") {
                    pixi run lab
                }
            } else {
                Write-Host ""
                Write-Host "Failed to install dependencies" -ForegroundColor Red
                Write-Host ""
                pause
                exit 1
            }
        }
        "2" {
            Write-Host ""
            Write-Host "Setting up R environment..." -ForegroundColor Cyan
            Write-Host ""

            # Check if R is installed
            $rInstalled = Get-Command R -ErrorAction SilentlyContinue

            if (-not $rInstalled) {
                Write-Host "R is not installed on your system." -ForegroundColor Yellow
                Write-Host ""
                Write-Host "Please install R from: https://cran.r-project.org/bin/windows/base/" -ForegroundColor Yellow
                Write-Host "Then restart this script." -ForegroundColor Yellow
                Write-Host ""

                $openBrowser = Read-Host "Open download page in browser? (y/n)"
                if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
                    Start-Process "https://cran.r-project.org/bin/windows/base/"
                }
                pause
                exit 1
            } else {
                Write-Host "R is already installed" -ForegroundColor Green
            }

            # Check if RStudio is installed
            $rstudioPath = Find-RStudio
            $rstudioAvailable = $null -ne $rstudioPath

            if ($rstudioAvailable) {
                Write-Host "✅ RStudio is installed" -ForegroundColor Green
            } else {
                Write-Host "⚠️  RStudio not found" -ForegroundColor Yellow
                Write-Host "   Install RStudio from: https://posit.co/download/rstudio-desktop/" -ForegroundColor Yellow
            }

            Write-Host ""
            Write-Host "Required R packages:" -ForegroundColor Yellow
            Write-Host "  - httr"
            Write-Host "  - jsonlite"
            Write-Host "  - dplyr"
            Write-Host "  - ggplot2"
            Write-Host "  - tidyr"
            Write-Host "  - knitr"
            Write-Host ""
            Write-Host "Please install these packages by running in R:" -ForegroundColor Cyan
            Write-Host "  install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))" -ForegroundColor Blue
            Write-Host ""
            Write-Host "You can now:" -ForegroundColor Cyan
            Write-Host "  Rscript src/R/data_fetch.R  - Fetch data from EvoNEST" -ForegroundColor Blue
            if ($rstudioAvailable) {
                Write-Host "  Open src/R/Notebook.Rmd in RStudio - Interactive R Markdown workflow" -ForegroundColor Blue
            }
            Write-Host ""

            if ($rstudioAvailable) {
                Write-Host "What would you like to do?" -ForegroundColor Cyan
                Write-Host "  1. Open R Markdown notebook in RStudio (Recommended)" -ForegroundColor Green
                Write-Host "  2. Launch R console" -ForegroundColor Green
                Write-Host "  n. Nothing, I'll do it later" -ForegroundColor Green
                Write-Host ""

                $launchChoice = Read-Host "Enter your choice (1, 2, or n)"
                
                switch ($launchChoice) {
                    "1" {
                        Open-RStudio
                    }
                    "2" {
                        Write-Host ""
                        Write-Host "Starting R console..." -ForegroundColor Cyan
                        Write-Host "Run: install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))" -ForegroundColor Yellow
                        R
                    }
                    default {
                        Write-Host "👍 You can open src/R/Notebook.Rmd in RStudio later" -ForegroundColor Yellow
                    }
                }
            } else {
                $launch = Read-Host "Launch R console now? (y/n)"
                if ($launch -eq "y" -or $launch -eq "Y") {
                    Write-Host ""
                    Write-Host "Starting R console..." -ForegroundColor Cyan
                    Write-Host "Run: install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))" -ForegroundColor Yellow
                    R
                }
            }
        }
        "u" {
            Invoke-Uninstall
        }
        "q" {
            Write-Host "Exiting setup" -ForegroundColor Yellow
            exit 0
        }
        default {
            Write-Host "Invalid choice" -ForegroundColor Red
            pause
            exit 1
        }
    }
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
pause
