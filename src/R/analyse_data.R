#!/usr/bin/env Rscript

# EvoNEST Data Analysis - Table Building Script
# Loads data from EvoNEST and processes it into structured tables for analysis
# Manages configuration in config/analyse_data_config.json

# Try to load required packages, install if missing
required_packages <- c("here", "tidyverse", "jsonlite", "R6")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = FALSE)) {
    cat("Installing", pkg, "...\n")
    install.packages(pkg)
  }
}

# Load libraries
suppressPackageStartupMessages({
  library(tidyverse)
  library(jsonlite)
  library(here)
  library(R6)
})

# Helper operators
`%||%` <- function(x, y) if (is.null(x)) y else x


# Configuration Manager ======================================================

ConfigManager <- R6::R6Class(
  "ConfigManager",
  public = list(
    config_file = NULL,
    config = NULL,

    initialize = function() {
      self$config_file <- here::here("config", "analyse_data_config.json")
      self$config <- self$load_config()
    },

    load_config = function() {
      default_config <- list(
        paths = list(
          downloaded_data_dir = "downloaded_data",
          processed_data_dir = "processed_data"
        ),
        output = list(
          save_tables = FALSE,
          output_format = "csv"
        )
      )

      if (file.exists(self$config_file)) {
        tryCatch({
          saved_config <- jsonlite::read_json(self$config_file)
          # Merge with defaults
          config <- private$merge_configs(default_config, saved_config)
          return(config)
        }, error = function(e) {
          cat("⚠️  Warning: Could not read config file, using defaults\n")
          return(default_config)
        })
      } else {
        return(default_config)
      }
    },

    save_config = function() {
      tryCatch({
        config_dir <- dirname(self$config_file)
        dir.create(config_dir, showWarnings = FALSE, recursive = TRUE)
        jsonlite::write_json(self$config, self$config_file, pretty = TRUE)
        cat(sprintf("✅ Configuration saved to %s\n", self$config_file))
        return(TRUE)
      }, error = function(e) {
        cat(sprintf("⚠️  Warning: Could not save config: %s\n", e$message))
        return(FALSE)
      })
    }
  ),

  private = list(
    merge_configs = function(default, saved) {
      for (key in names(saved)) {
        if (key %in% names(default) &&
            is.list(default[[key]]) && is.list(saved[[key]])) {
          default[[key]] <- private$merge_configs(default[[key]], saved[[key]])
        } else {
          default[[key]] <- saved[[key]]
        }
      }
      return(default)
    }
  )
)


# Data Loading Functions =====================================================

load_data <- function(config) {
  cat("📂 Loading data files...\n")

  # Define data paths from config
  data_dir <- here::here(config$paths$downloaded_data_dir)
  processed_dir <- here::here(config$paths$processed_data_dir)

  # Load samples data
  samples_json <- fromJSON(file.path(data_dir, "samples_data.json"))
  cat(sprintf("  ✓ Loaded %d samples\n", length(samples_json$samples)))

  # Load traits data
  traits_json <- fromJSON(file.path(data_dir, "traits_data.json"))
  cat(sprintf("  ✓ Loaded %d traits\n", length(traits_json$traits)))

  # Load processed experiments data
  experiments_json <- fromJSON(file.path(processed_dir, "hierarchical_experiment_data_no_curves.json"))
  cat(sprintf("  ✓ Loaded %d experiments\n",
              length(experiments_json$experiments)))

  cat("\n")

  return(list(
    samples = samples_json,
    traits = traits_json,
    experiments = experiments_json
  ))
}


# Table Building Functions ===================================================

build_samples_table <- function(samples_json) {
  cat("🔨 Building samples table...\n")

  # Convert samples list to data frame
  samples_df <- samples_json$samples %>%
    map_df(~{
      # Handle nested lists/logbook by converting to strings
      .x$logbook <- if(!is.null(.x$logbook)) list(.x$logbook) else NA
      .x
    })

  cat(sprintf("  ✓ Samples DataFrame: %d rows × %d columns\n",
              nrow(samples_df), ncol(samples_df)))

  # Display sample types distribution
  if ("type" %in% colnames(samples_df)) {
    sample_types <- table(samples_df$type)
    cat("  Sample types:\n")
    for (type_name in names(sample_types)) {
      cat(sprintf("    - %s: %d\n", type_name, sample_types[type_name]))
    }
  }

  cat("\n")
  return(samples_df)
}


build_traits_table <- function(traits_json) {
  cat("🔨 Building traits table...\n")

  # Convert traits list to data frame
  traits_df <- traits_json$traits %>%
    map_df(~{
      # Flatten nested sample data
      if (!is.null(.x$sample)) {
        sample_data <- .x$sample
        .x$sample <- NULL
        # Add selected sample fields with prefix
        .x$sample_name <- sample_data$name
        .x$sample_type <- sample_data$type
        .x$sample_family <- sample_data$family
        .x$sample_genus <- sample_data$genus
        .x$sample_species <- sample_data$species
      }
      # Convert listvals to string representation if present
      if (!is.null(.x$listvals)) {
        .x$listvals <- list(.x$listvals)
      }
      .x
    })

  cat(sprintf("  ✓ Traits DataFrame: %d rows × %d columns\n",
              nrow(traits_df), ncol(traits_df)))

  # Display trait types distribution
  if ("type" %in% colnames(traits_df)) {
    trait_types <- table(traits_df$type)
    cat(sprintf("  Trait types: %d unique types\n", length(trait_types)))
    # Show top 5 trait types
    top_traits <- sort(trait_types, decreasing = TRUE)[1:min(5, length(trait_types))]
    cat("  Top trait types:\n")
    for (i in seq_along(top_traits)) {
      cat(sprintf("    - %s: %d\n", names(top_traits)[i], top_traits[i]))
    }
  }

  cat("\n")
  return(traits_df)
}


build_experiments_table <- function(experiments_json) {
  cat("🔨 Building experiments table...\n")

  # Convert experiments nested list to data frame
  experiments_list <- names(experiments_json$experiments) %>%
    map_df(~{
      exp_data <- experiments_json$experiments[[.x]]

      # Create base record with flattened data
      exp_record <- tibble(
        experiment_id = .x,
        sample_name = exp_data$sample_name %||% NA,
        type = exp_data$type %||% NA,
        date = exp_data$date %||% NA,
        r_squared = exp_data$r_squared %||% NA,
        data_points = exp_data$data_points %||% NA,
        fracture_detected = exp_data$fracture_detected %||% NA,
        max_stress = exp_data$max_stress %||% NA,
        responsible = exp_data$responsible %||% NA,
        notes = exp_data$notes %||% NA,
        equipment = exp_data$equipment %||% NA,
        family = exp_data$family %||% NA,
        genus = exp_data$genus %||% NA,
        species = exp_data$species %||% NA,
        subsampletype = exp_data$subsampletype %||% NA
      )

      # Add strain and stress ranges
      if (!is.null(exp_data$strain_range)) {
        exp_record$strain_min <- exp_data$strain_range[1]
        exp_record$strain_max <- exp_data$strain_range[2]
      }
      if (!is.null(exp_data$stress_range)) {
        exp_record$stress_min <- exp_data$stress_range[1]
        exp_record$stress_max <- exp_data$stress_range[2]
      }

      # Store polynomial coefficients as list column
      exp_record$polynomial_coefficients <- list(exp_data$polynomial_coefficients)

      exp_record
    })

  experiments_df <- experiments_list

  cat(sprintf("  ✓ Experiments DataFrame: %d rows × %d columns\n",
              nrow(experiments_df), ncol(experiments_df)))

  cat("\n")
  return(experiments_df)
}


# Summary Functions ==========================================================

print_summary <- function(samples_df, traits_df, experiments_df) {
  cat(strrep("=", 80), "\n")
  cat("DATA SUMMARY\n")
  cat(strrep("=", 80), "\n\n")

  cat("📊 SAMPLES\n")
  cat(sprintf("  Total samples: %d\n", nrow(samples_df)))
  if ("type" %in% colnames(samples_df)) {
    sample_counts <- table(samples_df$type)
    cat("  Sample types:\n")
    for (type_name in names(sample_counts)) {
      cat(sprintf("    - %s: %d\n", type_name, sample_counts[type_name]))
    }
  }
  if ("family" %in% colnames(samples_df)) {
    cat(sprintf("  Families represented: %d\n",
                length(unique(samples_df$family[!is.na(samples_df$family)]))))
  }

  cat("\n🔬 TRAITS\n")
  cat(sprintf("  Total traits: %d\n", nrow(traits_df)))
  if ("type" %in% colnames(traits_df)) {
    cat(sprintf("  Trait types: %d unique types\n",
                length(unique(traits_df$type[!is.na(traits_df$type)]))))
  }

  cat("\n⚗️ EXPERIMENTS\n")
  cat(sprintf("  Total experiments: %d\n", nrow(experiments_df)))
  if ("r_squared" %in% colnames(experiments_df)) {
    cat(sprintf("  Average R²: %.4f\n",
                mean(experiments_df$r_squared, na.rm = TRUE)))
  }
  if ("fracture_detected" %in% colnames(experiments_df)) {
    cat(sprintf("  Fracture detected: %d / %d\n",
                sum(experiments_df$fracture_detected, na.rm = TRUE),
                nrow(experiments_df)))
  }
  if ("family" %in% colnames(experiments_df)) {
    cat(sprintf("  Families tested: %d\n",
                length(unique(experiments_df$family[!is.na(experiments_df$family)]))))
  }

  cat("\n")
  cat(strrep("=", 80), "\n")
}


# Main Function ==============================================================

main <- function() {
  cat("\n", strrep("═", 80), "\n", sep = "")
  cat("EvoNEST Data Analysis - Building Data Tables\n")
  cat(strrep("═", 80), "\n\n", sep = "")

  # Load configuration
  config_manager <- ConfigManager$new()
  config <- config_manager$config

  # Load data
  data <- load_data(config)

  # Build tables
  samples_df <- build_samples_table(data$samples)
  traits_df <- build_traits_table(data$traits)
  experiments_df <- build_experiments_table(data$experiments)

  # Print summary
  print_summary(samples_df, traits_df, experiments_df)

  cat("\n✅ Data tables built successfully!\n")
  cat("   Available objects: samples_df, traits_df, experiments_df\n")
  cat("\n💡 Next steps: Explore data and create visualizations with ggplot2\n")
  cat(strrep("═", 80), "\n\n", sep = "")

  # Return results invisibly so they're available in the environment
  invisible(list(
    samples_df = samples_df,
    traits_df = traits_df,
    experiments_df = experiments_df
  ))
}


# Run main function
main()
