# EvoNEST Data Science

[![Python](https://img.shields.io/badge/Python-3.8%2B-blue.svg)](https://www.python.org/)
[![R](https://img.shields.io/badge/R-4.0%2B-276DC3.svg)](https://www.r-project.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Pixi](https://img.shields.io/badge/Pixi-Package%20Manager-orange.svg)](https://pixi.sh/)

A bilingual (Python/R) data analysis pipeline for processing and analysing tensile test experiments on spider silk samples from the EvoNEST API. This repository provides parallel implementations in both languages with identical functionality, enabling researchers to work with their preferred computational environment whilst maintaining reproducibility and consistency across analyses.

## Overview

This pipeline processes stress-strain curve data from spider silk tensile tests, performing polynomial fitting, fracture detection, and hierarchical outlier analysis. The system is designed for both experienced data scientists and novice researchers through interactive notebooks and command-line scripts.

## Installation

### Quick Setup Script (Optional)

For an interactive setup experience on **Linux/macOS**, or **Windows with Git Bash/WSL**, use the provided setup script:

```bash
bash setup/setup_language.sh
```

This script will:

- Detect your operating system
- Install pixi (for Python) or check R installation
- Guide you through dependency installation
- Optionally launch Jupyter Lab or R console

> **Note for Windows users**: The setup script requires bash (available via Git Bash or WSL). If you don't have these installed, the manual setup instructions below work directly in PowerShell or Command Prompt.

### Manual Setup Instructions

#### Python Environment

The Python environment uses [Pixi](https://pixi.sh/) for dependency management, providing reproducible cross-platform installations.

```bash
# Install pixi (if not already installed)
# Linux/macOS:
curl -fsSL https://pixi.sh/install.sh | bash

# Windows (PowerShell):
iwr -useb https://pixi.sh/install.ps1 | iex

# Install project dependencies
pixi install

# Verify installation
pixi run lab  # Launches Jupyter Lab
```

#### R Environment

Install R from [CRAN](https://cran.r-project.org/), then install required packages:

```r
install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))
```

**Recommended**: Use [RStudio](https://posit.co/download/rstudio-desktop/) for an integrated development environment.

## Folder Structure

```text
EvoNEST-data-science/
├── config/
│   ├── evonest_config.json               # Configuration for data fetching
│   ├── process_mechanics_config.json     # Configuration for mechanical data processing
│   └── analyse_outliers_config.json      # Configuration for outlier analysis
├── downloaded_data/                      # Raw data from API
│   ├── experiments_data.json             # Tensile test experiments
│   ├── traits_data.json                  # Sample traits measurements
│   └── samples_data.json                 # Sample metadata
├── processed_data/                       # Processed results
│   ├── fit_data.json                     # Polynomial coefficients and metrics
│   ├── outlier_analysis.json             # Detailed hierarchical outlier analysis
│   ├── outlier_analysis.log              # Analysis log with full details
│   ├── outlier_experiments.csv           # Summary of flagged outlier experiments
│   └── plot_*.png                        # Optional: stress-strain curve plots
├── _python_scripts/                      # Python scripts
│   ├── data_fetch.py                     # Fetch data from EvoNEST API
│   ├── process_mechanical_data.py        # Process tensile test data
│   ├── analyse_data.py                   # Build structured data tables
│   ├── analyse_outliers.py               # Analyze outliers using sigma detection
│   └── Notebook.ipynb                    # Interactive Jupyter notebook
├── _r_scripts/                           # R scripts (equivalent functionality)
│   ├── data_fetch.R                      # Fetch data from EvoNEST API
│   ├── process_mechanical_data.R         # Process tensile test data
│   ├── analyse_data.R                    # Build structured data tables
│   ├── analyse_outliers.R                # Analyze outliers using sigma detection
│   └── Notebook.Rmd                      # Interactive R Markdown notebook
├── setup/
│   └── setup_language.sh                 # Interactive setup script for both environments
└── pixi.toml                             # Python dependency configuration
```

## Data Pipeline

### Step 1: Data Acquisition

Execute `data_fetch.py` or `data_fetch.R` to retrieve data from the EvoNEST API:

- Configure API credentials and fetch options
- Downloads raw data to `downloaded_data/` directory
- Retrieves samples, traits, and experimental measurements

### Step 2: Mechanical Data Processing

Execute `process_mechanical_data.py` or `process_mechanical_data.R` to analyse tensile test data:

- Detects fracture points in stress-strain curves using configurable thresholds
- Fits polynomial models (configurable degree) to experimental data
- Calculates goodness-of-fit metrics (R², RMSE, residuals)
- Optionally generates and saves stress-strain curve visualisations
- Outputs polynomial coefficients to `processed_data/fit_data.json`

### Step 3: Data Table Construction

Execute `analyse_data.py` or `analyse_data.R` to organise data into structured tables:

- Loads samples, traits, and processed experimental data
- Constructs three primary DataFrames/tibbles:
  - `samples_df`: Sample metadata (organisms, silk samples, taxonomy, geographical location)
  - `traits_df`: Trait measurements (diameter, mechanical properties, morphological characteristics)
  - `experiments_df`: Processed experiments with polynomial fits and statistical metrics
- Provides comprehensive summary statistics
- Establishes foundation for exploratory data analysis and visualisation

### Step 4: Hierarchical Outlier Analysis

Execute `analyse_outliers.py` or `analyse_outliers.R` to perform hierarchical outlier detection:

- Groups data hierarchically: Family → Species → Subsample Type
- Applies sigma-based detection (1σ, 2σ, 3σ) for each trait within groups
- Identifies experiments with elevated proportions of outlier traits
- Configuration via `config/analyse_outliers_config.json`:
  - `outlier_trait_threshold`: Proportion of traits flagged as outliers to identify suspect experiments (default: 0.3)
  - `sigma_level`: Standard deviation threshold for outlier detection (default: 2)
- Generates multiple outputs:
  - `processed_data/outlier_analysis.json`: Comprehensive hierarchical analysis with group statistics
  - `processed_data/outlier_experiments.csv`: Tabulated summary of flagged experiments
  - `processed_data/outlier_analysis.log`: Detailed analysis log with full statistical breakdowns (R implementation only)

## Interactive Notebooks for Researchers

For researchers new to computational analysis, interactive notebooks are provided that guide users through the complete pipeline with step-by-step instructions:

### Python: Jupyter Notebook

The `_python_scripts/EvoNEST_Pipeline.ipynb` notebook provides an integrated interface encompassing all four pipeline stages:

**Usage**:

1. Launch Jupyter Lab: `pixi run lab`
2. Execute each cell sequentially using `Shift+Enter`
3. Follow configuration prompts as required

**Features**:

- Interactive data exploration with pandas DataFrames
- Example visualisations using matplotlib and seaborn
- Statistical summary tables for each data structure
- Modifiable analysis templates for custom research questions

### R: R Markdown Notebook

The `_r_scripts/EvoNEST_Pipeline.Rmd` notebook provides equivalent functionality for R users:

**Usage**:

1. Open the file in RStudio
2. Render complete HTML report via "Knit", or
3. Execute individual chunks using the green play button (▶)
4. Follow configuration prompts as required

**Features**:

- Interactive data exploration with tidyverse tibbles
- Example visualisations using ggplot2
- Statistical summary tables with knitr formatting
- Modifiable analysis templates for custom research questions

Both notebooks include:

- Comprehensive documentation for each pipeline stage
- Automatic data loading into analysis-ready structures
- Example code demonstrating common visualisation and statistical analyses
- Templates for custom exploratory data analysis
