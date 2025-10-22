# EvoNEST Data Science

<div align="center">
  <img src="_images/EvoNEST_DS.png" alt="EvoNEST Data Science Logo" width="400">

[![Python](https://img.shields.io/badge/Python-3.8%2B-blue.svg)](https://www.python.org/)
[![R](https://img.shields.io/badge/R-4.0%2B-276DC3.svg)](https://www.r-project.org/)
[![License](https://img.shields.io/badge/License-AGPL%203.0-orange.svg)](https://opensource.org/licenses/AGPL-3.0)
[![Pixi](https://img.shields.io/badge/Pixi-Package%20Manager-orange.svg)](https://pixi.sh/)

</div>

A bilingual (Python/R) data analysis pipeline for processing and analysing tensile test experiments on biological samples from the EvoNEST API. This repository provides parallel implementations in both languages with identical functionality.

## Overview

This collection of computational tools help downloading and processing samples, traits and mechanical experiments. The repository is dedicated to the EVO|MEC laboratory instance of EvoNEST, but can be adapted to other instances. It performs performing polynomial fitting of stress strain curves, hierarchical outlier analysis, and provides an intro to visualization.

## Installation

> **Note**: If you already have R installed and prefer to use your existing installation, see the [Using Existing R Installation](#using-existing-r-installation) section below.

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

### Using Existing R Installation

If you already have R installed on your system and want to use it instead of installing through the setup script:

1. **Copy the R scripts folder** to your preferred working directory:
   ```bash
   cp -r src/R /path/to/your/workspace/
   ```

2. **Copy the configuration folder**:
   ```bash
   cp -r config /path/to/your/workspace/
   ```

3. **Install required R packages**:
   ```r
   install.packages(c('httr', 'jsonlite', 'dplyr', 'ggplot2', 'tidyr', 'knitr'))
   ```

You can then run the scripts directly from your R environment. The Python components (`src/python/`, `pixi.toml`) are not required if you're exclusively using R.

## Pipeline

### Step 1: Data Acquisition

Execute `data_fetch.py` or `data_fetch.R` to retrieve data from the EvoNEST API:

- Configure API credentials and fetch options. To retrieve API credentials, go to your user inside EvoNEST by pressing your avatar in the top right corner, then navigate to "API Keys" and generate a new key.
- Downloads raw data to `downloaded_data/` directory
- Retrieves samples, traits, and experimental measurements

### Step 2: Mechanical Data Processing

Execute `process_mechanical_data.py` or `process_mechanical_data.R` to analyse tensile test data:

- Detects fracture points in stress-strain curves using configurable thresholds
- Fits polynomial models (configurable degree) to experimental data
- Calculates goodness-of-fit metrics (R², RMSE, residuals)
- Optionally generates and saves stress-strain curve visualisations
- Outputs polynomial coefficients to `processed_data/hierarchical_experiment_data_no_curves.json`

### Step 3: Data Table Construction

Execute `analyse_data.py` or `analyse_data.R` to organise data into structured tables:

- Loads samples, traits, and processed experimental data
- Constructs three primary DataFrames/tibbles:
  - `samples_df`: Sample metadata (organisms, silk samples, taxonomy, geographical location)
  - `traits_df`: Trait measurements (diameter, mechanical properties, morphological characteristics)
  - `experiments_df`: Processed experiments with polynomial fits and statistical metrics
- Provides summary statistics
- Foundation for exploratory data analysis and visualisation

### Step 4: Hierarchical Outlier Analysis

Execute `analyse_outliers.py` or `analyse_outliers.R` to perform hierarchical outlier detection:

- Groups data hierarchically: Family → Species → Subsample Type
- Applies sigma-based detection (1σ, 2σ, 3σ) for each trait within groups
- Identifies experiments with elevated proportions of outlier traits
- Configuration via `config/analyse_outliers_config.json`:
  - `outlier_trait_threshold`: Proportion of traits flagged as outliers to identify suspect experiments (default: 0.3)
  - `sigma_level`: Standard deviation threshold for outlier detection (default: 2)
- Generates outputs:
  - `processed_data/outlier_analysis.json`: Hierarchical analysis with group statistics
  - `processed_data/outlier_experiments.csv`: Summary of flagged experiments

## Interactive Notebooks
Interactive notebooks guide users through the pipeline with step-by-step instructions:

### Python: Jupyter Notebook

The `src/python/Notebook.ipynb` notebook provides an integrated interface encompassing all four pipeline stages:

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

The `src/R/Notebook.Rmd` notebook provides equivalent functionality for R users:

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

- Documentation for each pipeline stage
- Data loading into analysis-ready structures
- Example code for visualisation and statistical analyses
- Templates for exploratory data analysis
