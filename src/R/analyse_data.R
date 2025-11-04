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
        jsonlite::write_json(self$config, self$config_file, pretty = TRUE, auto_unbox = TRUE)
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
  # Use simplifyVector = FALSE to preserve the JSON structure correctly
  samples_json <- fromJSON(file.path(data_dir, "samples_data.json"), simplifyVector = FALSE)
  cat(sprintf("  ✓ Loaded %d samples\n", length(samples_json$samples)))

  # Load traits data
  traits_json <- fromJSON(file.path(data_dir, "traits_data.json"), simplifyVector = FALSE)
  cat(sprintf("  ✓ Loaded %d traits\n", length(traits_json$traits)))

  # Load processed experiments data
  experiments_json <- fromJSON(file.path(processed_dir, "hierarchical_experiment_data_no_curves.json"), simplifyVector = FALSE)
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
      # Remove complex nested structures that can't be flattened
      if ("logbook" %in% names(.x)) {
        .x[["logbook"]] <- NULL  # Remove for now, too complex
      }
      if ("secondaryItems" %in% names(.x)) {
        .x[["secondaryItems"]] <- NULL
      }
      if ("filesId" %in% names(.x)) {
        .x[["filesId"]] <- NULL
      }
      
      # Convert all single-element lists to atomic values
      # This handles fields like "type": ["animal"] -> "type": "animal"
      .x <- lapply(.x, function(field) {
        if (is.list(field) && length(field) == 1 && !is.list(field[[1]])) {
          return(field[[1]])
        }
        return(field)
      })
      
      # Return as tibble
      as_tibble(.x)
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
      if ("sample" %in% names(.x) && !is.null(.x[["sample"]])) {
        sample_data <- .x[["sample"]]
        .x[["sample"]] <- NULL
        # Add selected sample fields with prefix - use NA_character_ for consistent typing
        .x[["sample.name"]] <- sample_data[["name"]] %||% NA_character_
        .x[["sample.type"]] <- sample_data[["type"]] %||% NA_character_
        .x[["sample.family"]] <- sample_data[["family"]] %||% NA_character_
        .x[["sample.genus"]] <- sample_data[["genus"]] %||% NA_character_
        .x[["sample.species"]] <- sample_data[["species"]] %||% NA_character_
        .x[["sample.nomenclature"]] <- sample_data[["nomenclature"]] %||% NA_character_
        .x[["sample.subsampletype"]] <- sample_data[["subsampletype"]] %||% NA_character_
      }
      
      # Remove all complex nested structures that might cause issues
      fields_to_remove <- c("logbook", "filesId", "secondaryItems", "diameterConversion")
      for (field in fields_to_remove) {
        if (field %in% names(.x)) {
          .x[[field]] <- NULL
        }
      }
      
      # Handle listvals - convert to string representation
      if ("listvals" %in% names(.x) && !is.null(.x[["listvals"]])) {
        listvals_data <- .x[["listvals"]]
        # Check if it's an empty object (named list with no elements or all NULL)
        if (is.list(listvals_data) && (length(listvals_data) == 0 || !is.null(names(listvals_data)))) {
          # Empty object or named list - set to empty string
          .x[["listvals"]] <- ""
        } else if (is.list(listvals_data) && length(listvals_data) > 0) {
          # Convert array to comma-separated string
          vals <- unlist(listvals_data)
          .x[["listvals"]] <- paste(as.character(vals), collapse = ", ")
        } else {
          .x[["listvals"]] <- ""
        }
      }
      
      # Convert all single-element lists to atomic values
      .x <- lapply(.x, function(field) {
        if (is.list(field) && length(field) == 1 && !is.list(field[[1]])) {
          return(field[[1]])
        }
        return(field)
      })
      
      # Remove any remaining nested list/object fields that aren't simple values
      .x <- .x[sapply(.x, function(field) {
        # Keep if it's not a list, or if it's a character/numeric/logical vector
        !is.list(field) || is.null(field)
      })]
      
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

  # Helper function to extract value from potential single-element list
  extract_value <- function(x) {
    if (is.list(x) && length(x) == 1 && !is.list(x[[1]])) {
      return(x[[1]])
    }
    return(x)
  }

  # Convert experiments nested list to data frame
  experiments_list <- names(experiments_json$experiments) %>%
    map_df(~{
      exp_data <- experiments_json$experiments[[.x]]

      # Create base record with flattened data
      exp_record <- tibble(
        experiment_id = .x,
        sample_name = extract_value(exp_data$sample_name) %||% NA,
        type = extract_value(exp_data$type) %||% NA,
        date = extract_value(exp_data$date) %||% NA,
        r_squared = extract_value(exp_data$r_squared) %||% NA,
        data_points = extract_value(exp_data$data_points) %||% NA,
        fracture_detected = extract_value(exp_data$fracture_detected) %||% NA,
        max_stress = extract_value(exp_data$max_stress) %||% NA,
        responsible = extract_value(exp_data$responsible) %||% NA,
        notes = extract_value(exp_data$notes) %||% NA,
        equipment = extract_value(exp_data$equipment) %||% NA,
        family = extract_value(exp_data$family) %||% NA,
        genus = extract_value(exp_data$genus) %||% NA,
        species = extract_value(exp_data$species) %||% NA,
        subsampletype = extract_value(exp_data$subsampletype) %||% NA
      )

      # Add strain and stress ranges
      strain_range <- extract_value(exp_data$strain_range)
      if (!is.null(strain_range) && length(strain_range) >= 2) {
        exp_record$strain_min <- strain_range[[1]]
        exp_record$strain_max <- strain_range[[2]]
      }
      stress_range <- extract_value(exp_data$stress_range)
      if (!is.null(stress_range) && length(stress_range) >= 2) {
        exp_record$stress_min <- stress_range[[1]]
        exp_record$stress_max <- stress_range[[2]]
      }

      # Store polynomial coefficients as list column
      poly_coeffs <- extract_value(exp_data$polynomial_coefficients)
      if (is.list(poly_coeffs) && !is.null(poly_coeffs)) {
        exp_record$polynomial_coefficients <- list(unlist(poly_coeffs))
      } else {
        exp_record$polynomial_coefficients <- list(poly_coeffs)
      }

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

  # Assign to global environment so they're available after sourcing
  assign("samples_df", samples_df, envir = .GlobalEnv)
  assign("traits_df", traits_df, envir = .GlobalEnv)
  assign("experiments_df", experiments_df, envir = .GlobalEnv)

  # Return results invisibly
  invisible(list(
    samples_df = samples_df,
    traits_df = traits_df,
    experiments_df = experiments_df
  ))
}


# Run main function
main()
