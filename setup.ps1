# EvoNEST Data Science Setup Script for Windows
# Double-click this file to run the setup

Write-Host "========================================================" -ForegroundColor Blue
Write-Host "  EvoNEST Data Science Environment Setup for Windows" -ForegroundColor Blue
Write-Host "========================================================" -ForegroundColor Blue
Write-Host ""

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

    # Run the bash setup script
    & $bashPath -c "cd '$PWD' && bash setup/setup_language.sh"
} else {
    Write-Host "Git Bash not found. Running PowerShell-native setup..." -ForegroundColor Yellow
    Write-Host ""

    # Fallback: Direct PowerShell setup for Python with pixi
    Write-Host "Choose your environment:" -ForegroundColor Cyan
    Write-Host "  1. Python (with pixi and Jupyter Lab)" -ForegroundColor Green
    Write-Host "  2. R" -ForegroundColor Green
    Write-Host "  q. Quit" -ForegroundColor Green
    Write-Host ""

    $choice = Read-Host "Enter your choice (1, 2, or q)"

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
            Write-Host "After installing packages, you can run:" -ForegroundColor Cyan
            Write-Host "  Rscript src/R/data_fetch.R  - Fetch data from EvoNEST" -ForegroundColor Blue
            Write-Host ""

            $launch = Read-Host "Launch R console now? (y/n)"
            if ($launch -eq "y" -or $launch -eq "Y") {
                Write-Host ""
                Write-Host "Starting R console..." -ForegroundColor Cyan
                Write-Host "Run: install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))" -ForegroundColor Yellow
                R
            }
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
