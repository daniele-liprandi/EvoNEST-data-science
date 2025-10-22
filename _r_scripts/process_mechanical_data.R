#!/usr/bin/env Rscript

# EvoNEST Mechanical Data Processing Script
# Processes tensile test data and fits polynomial models to stress-strain curves
# Manages configuration in config/process_mechanics_config.json

# Try to load required packages, install if missing
required_packages <- c("here", "ggplot2", "tidyverse", "jsonlite", "R6")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = FALSE)) {
    cat("Installing", pkg, "...\n")
    install.packages(pkg)
  }
}

library(here)
library(jsonlite)
library(ggplot2)
library(tidyverse)
library(R6)

# Helper operators
`%||%` <- function(x, y) if (is.null(x)) y else x
`%+%` <- function(x, y) paste0(x, y)

#' Configuration Manager Class
#' Manages persistent configuration for mechanical data processing
ConfigManager <- R6::R6Class("ConfigManager",
  public = list(
    config_dir = NULL,
    config_file = NULL,
    config = NULL,
    
    initialize = function() {
      self$config_dir <- here::here("config")
      self$config_file <- here::here("config", "process_mechanics_config.json")
      self$config <- self$load_config()
    },
    
    load_config = function() {
      default_config <- list(
        fracture_detection = list(
          stop_max_stress = FALSE,
          drop_threshold = 0.9,
          min_points = 1
        ),
        processing = list(
          polynomial_degree = 1,
          show_plots = FALSE,
          save_plots = FALSE,
          max_experiments = NULL
        ),
        output = list(
          output_dir = "processed_data"
        )
      )
      
      if (file.exists(self$config_file)) {
        tryCatch({
          saved_config <- jsonlite::read_json(self$config_file)
          config <- self$merge_configs(default_config, saved_config)
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
        dir.create(self$config_dir, showWarnings = FALSE, recursive = TRUE)
        jsonlite::write_json(self$config, self$config_file, pretty = TRUE)
        cat(sprintf("✅ Configuration saved to %s\n", self$config_file))
        return(TRUE)
      }, error = function(e) {
        cat(sprintf("⚠️  Warning: Could not save config: %s\n", e$message))
        return(FALSE)
      })
    },
    
    merge_configs = function(default, saved) {
      for (key in names(saved)) {
        if (key %in% names(default) && is.list(default[[key]]) && is.list(saved[[key]])) {
          default[[key]] <- self$merge_configs(default[[key]], saved[[key]])
        } else {
          default[[key]] <- saved[[key]]
        }
      }
      return(default)
    },
    
    interactive_setup = function() {
      self$print_header("EvoNEST Mechanical Data Processing Configuration")
      
      config_exists <- file.exists(self$config_file)
      
      if (config_exists) {
        cat("\n📋 Found existing configuration:\n")
        self$print_current_config()
        cat("\n" %+% strrep("─", 80) %+% "\n")
        
        use_existing <- self$prompt_yes_no("Use existing configuration?", default = TRUE)
        
        if (use_existing) {
          cat("\n✅ Using saved configuration\n")
          return(self$config)
        }
      }
      
      # Setup fracture detection
      cat("\n" %+% strrep("═", 80) %+% "\n")
      self$setup_fracture_detection(config_exists)
      
      # Setup processing parameters
      cat("\n" %+% strrep("═", 80) %+% "\n")
      self$setup_processing_parameters(config_exists)
      
      # Setup output directory
      cat("\n" %+% strrep("═", 80) %+% "\n")
      self$setup_output_directory(config_exists)
      
      # Save configuration
      cat("\n" %+% strrep("─", 80) %+% "\n")
      if (self$prompt_yes_no("Save this configuration for future use?", default = TRUE)) {
        self$save_config()
      } else {
        cat("⚠️  Configuration will be used for this session only\n")
      }
      
      return(self$config)
    },
    
    setup_fracture_detection = function(config_exists) {
      self$print_section("Fracture Detection")
      
      stop_max_stress <- self$prompt_yes_no(
        "Stop analysis at maximum stress point?",
        default = self$config$fracture_detection$stop_max_stress
      )
      self$config$fracture_detection$stop_max_stress <<- stop_max_stress
      
      if (!stop_max_stress) {
        drop_threshold <- self$prompt_float(
          "Drop threshold for fracture detection (0.0-1.0)",
          default = self$config$fracture_detection$drop_threshold,
          min_val = 0.0,
          max_val = 1.0
        )
        self$config$fracture_detection$drop_threshold <<- drop_threshold
      }
    },
    
    setup_processing_parameters = function(config_exists) {
      self$print_section("Processing Parameters")
      
      poly_degree <- self$prompt_int(
        "Polynomial degree for fitting",
        default = self$config$processing$polynomial_degree,
        min_val = 1,
        max_val = 10
      )
      self$config$processing$polynomial_degree <<- poly_degree
      
      show_plots <- self$prompt_yes_no(
        "Show plots during processing?",
        default = self$config$processing$show_plots
      )
      self$config$processing$show_plots <<- show_plots
      
      save_plots <- self$prompt_yes_no(
        "Save plots to file?",
        default = self$config$processing$save_plots
      )
      self$config$processing$save_plots <<- save_plots
      
      max_exp_input <- readline("Maximum experiments to process (press Enter for all): ")
      if (nchar(trimws(max_exp_input)) > 0) {
        tryCatch({
          self$config$processing$max_experiments <<- as.integer(max_exp_input)
        }, error = function(e) {
          cat("❌ Invalid input, using all experiments\n")
          self$config$processing$max_experiments <<- NULL
        })
      } else {
        self$config$processing$max_experiments <<- NULL
      }
    },
    
    setup_output_directory = function(config_exists) {
      self$print_section("Output Directory")
      
      output_dir <- self$prompt_input(
        "Output directory for processed data",
        default = self$config$output$output_dir,
        required = TRUE
      )
      self$config$output$output_dir <<- output_dir
    },
    
    print_current_config = function() {
      cat("\n┌─ Fracture Detection ───────────────────────────────────\n")
      cat(sprintf("│ Stop at Max Stress: %s\n", self$config$fracture_detection$stop_max_stress))
      cat(sprintf("│ Drop Threshold:     %.2f\n", self$config$fracture_detection$drop_threshold))
      
      cat("\n├─ Processing Parameters ───────────────────────────────\n")
      cat(sprintf("│ Polynomial Degree:  %d\n", self$config$processing$polynomial_degree))
      cat(sprintf("│ Show Plots:         %s\n", self$config$processing$show_plots))
      cat(sprintf("│ Save Plots:         %s\n", self$config$processing$save_plots))
      max_exp <- self$config$processing$max_experiments
      max_exp_str <- if (is.null(max_exp)) "All" else as.character(max_exp)
      cat(sprintf("│ Max Experiments:    %s\n", max_exp_str))
      
      cat("\n├─ Output ──────────────────────────────────────────────\n")
      cat(sprintf("│ Output Directory:   %s\n", self$config$output$output_dir))
      cat("└────────────────────────────────────────────────────────\n")
    },
    
    print_header = function(title) {
      cat("\n╔" %+% strrep("═", 78) %+% "╗\n")
      cat(sprintf("║%s║\n", strrep(" ", 39 - nchar(title) %/% 2) %+% title %+% strrep(" ", 39 - nchar(title) %/% 2)))
      cat("╚" %+% strrep("═", 78) %+% "╝\n")
    },
    
    print_section = function(title) {
      cat("\n┌─ " %+% title %+% " " %+% strrep("─", 74 - nchar(title)) %+% "\n")
    },
    
    prompt_input = function(prompt, default = NULL, required = FALSE) {
      if (!is.null(default)) {
        prompt_text <- sprintf("%s [%s]: ", prompt, default)
      } else {
        prompt_text <- sprintf("%s: ", prompt)
      }
      
      repeat {
        value <- trimws(readline(prompt_text))
        
        if (nchar(value) == 0 && !is.null(default)) {
          return(default)
        } else if (nchar(value) == 0 && required) {
          cat("❌ This field is required!\n")
          next
        } else if (nchar(value) > 0) {
          return(value)
        } else {
          return("")
        }
      }
    },
    
    prompt_yes_no = function(prompt, default = TRUE) {
      default_text <- if (default) "Y/n" else "y/N"
      prompt_text <- sprintf("%s [%s]: ", prompt, default_text)
      
      repeat {
        value <- tolower(trimws(readline(prompt_text)))
        
        if (nchar(value) == 0) {
          return(default)
        } else if (value %in% c("y", "yes")) {
          return(TRUE)
        } else if (value %in% c("n", "no")) {
          return(FALSE)
        } else {
          cat("❌ Please enter 'y' or 'n'\n")
        }
      }
    },
    
    prompt_int = function(prompt, default = 1, min_val = NULL, max_val = NULL) {
      repeat {
        value <- trimws(readline(sprintf("%s [%d]: ", prompt, default)))
        
        if (nchar(value) == 0) {
          return(default)
        }
        
        tryCatch({
          int_val <- suppressWarnings(as.integer(value))
          
          if (is.na(int_val)) {
            cat("❌ Please enter a valid integer\n")
            next
          }
          
          if (!is.null(min_val) && int_val < min_val) {
            cat(sprintf("❌ Must be at least %d\n", min_val))
            next
          }
          if (!is.null(max_val) && int_val > max_val) {
            cat(sprintf("❌ Must be at most %d\n", max_val))
            next
          }
          
          return(int_val)
        }, error = function(e) {
          cat("❌ Please enter a valid integer\n")
        })
      }
    },
    
    prompt_float = function(prompt, default = 0.9, min_val = NULL, max_val = NULL) {
      repeat {
        value <- trimws(readline(sprintf("%s [%.2f]: ", prompt, default)))
        
        if (nchar(value) == 0) {
          return(default)
        }
        
        tryCatch({
          float_val <- suppressWarnings(as.numeric(value))
          
          if (is.na(float_val)) {
            cat("❌ Please enter a valid number\n")
            next
          }
          
          if (!is.null(min_val) && float_val < min_val) {
            cat(sprintf("❌ Must be at least %.2f\n", min_val))
            next
          }
          if (!is.null(max_val) && float_val > max_val) {
            cat(sprintf("❌ Must be at most %.2f\n", max_val))
            next
          }
          
          return(float_val)
        }, error = function(e) {
          cat("❌ Please enter a valid number\n")
        })
      }
    }
  )
)

# ---------------------------------------------------------------------------- #
#                                   MECHANICS                                  #
# ---------------------------------------------------------------------------- #


#' Mechanical Data Processor Class
#' Processes mechanical test data and fits polynomial models
MechanicalDataProcessor <- R6::R6Class("MechanicalDataProcessor",
  public = list(
    config = NULL,
    output_dir = NULL,
    
    initialize = function(config) {
      self$config <- config
      self$output_dir <- here::here(config$output$output_dir)
      dir.create(self$output_dir, showWarnings = FALSE, recursive = TRUE)
    },
    
    detect_fracture_point = function(strain, stress) {
      if (length(stress) < self$config$fracture_detection$min_points + 10) {
        return(NULL)
      }
      
      max_stress_idx <- which.max(stress)
      max_stress <- stress[max_stress_idx]
      
      if (self$config$fracture_detection$stop_max_stress) {
        return(max_stress_idx)
      }
      
      # Look for fracture after maximum stress
      for (i in seq(max_stress_idx, length(stress) - self$config$fracture_detection$min_points)) {
        if (stress[i] < max_stress * (1 - self$config$fracture_detection$drop_threshold)) {
          return(i)
        }
      }
      
      return(NULL)
    },
    
    trim_curve_to_fracture = function(strain, stress) {
      zero_strain_idx <- which.min(abs(strain))
      fracture_idx <- self$detect_fracture_point(strain, stress)
      
      if (is.null(fracture_idx)) {
        end_idx <- length(strain)
        fracture_detected <- FALSE
      } else {
        end_idx <- fracture_idx
        fracture_detected <- TRUE
      }
      
      trimmed_strain <- strain[zero_strain_idx:end_idx]
      trimmed_stress <- stress[zero_strain_idx:end_idx]
      
      trim_info <- list(
        original_points = length(strain),
        trimmed_points = length(trimmed_strain),
        zero_strain_idx = zero_strain_idx,
        fracture_idx = fracture_idx,
        fracture_detected = fracture_detected,
        strain_range = c(min(trimmed_strain), max(trimmed_strain)),
        stress_range = c(min(trimmed_stress), max(trimmed_stress)),
        max_stress = if (length(trimmed_stress) > 0) max(trimmed_stress) else 0
      )
      
      return(list(
        strain = trimmed_strain,
        stress = trimmed_stress,
        trim_info = trim_info
      ))
    },
    
    # ---------------------------------------------------------------------------- #
    #           Extract the stress strain curve from the experiment json           #
    # ---------------------------------------------------------------------------- #
    extract_stress_strain_data = function(experiment) {
      tryCatch({
        raw_data <- experiment$rawData %||% list()
        
        strain_obj <- raw_data$EngineeringStrain %||% list()
        stress_obj <- raw_data$EngineeringStress %||% list()
        
        strain_data <- strain_obj$values %||% list()
        stress_data <- stress_obj$values %||% list()
        
        strain_clean <- c()
        stress_clean <- c()
        
        for (i in seq_len(min(length(strain_data), length(stress_data)))) {
          if (!is.null(strain_data[[i]]) && !is.null(stress_data[[i]])) {
            strain_clean <- c(strain_clean, strain_data[[i]])
            stress_clean <- c(stress_clean, stress_data[[i]])
          }
        }
        
        strain_array <- as.numeric(strain_clean)
        stress_array <- as.numeric(stress_clean)
        
        sample_name <- experiment$metadata$name %||% "Unknown"
        
        trimmed <- self$trim_curve_to_fracture(strain_array, stress_array)
        
        return(list(
          strain = trimmed$strain,
          stress = trimmed$stress,
          sample_name = sample_name,
          trim_info = trimmed$trim_info
        ))
      }, error = function(e) {
        cat(sprintf("  ⚠️  Error extracting data: %s\n", e$message))
        return(NULL)
      })
    },
    
    fit_polynomial_to_experiment = function(data, experiment_id) {
      tryCatch({
        experiments <- data$experiments
        if (!(experiment_id %in% names(experiments))) {
          return(NULL)
        }
        
        experiment <- experiments[[experiment_id]]
        extracted <- self$extract_stress_strain_data(experiment)
        
        if (is.null(extracted) || length(extracted$strain) < 10) {
          return(NULL)
        }
        
        strain <- extracted$strain
        stress <- extracted$stress
        sample_name <- extracted$sample_name
        trim_info <- extracted$trim_info
        
        # Fit polynomial
        poly_fit <- lm(stress ~ poly(strain, self$config$processing$polynomial_degree, raw = TRUE))
        
        # Calculate R-squared
        ss_res <- sum((stress - fitted(poly_fit))^2)
        ss_tot <- sum((stress - mean(stress))^2)
        r_squared <- 1 - (ss_res / ss_tot)
        
        # Extract coefficients
        coefs <- as.numeric(coef(poly_fit))
        
        metadata <- experiment$metadata %||% list()
        mech_props <- experiment$mechanicalProperties %||% list()
        
        # Build sample chain info
        sample_chain <- experiment$sampleChain %||% list()
        family <- if (length(sample_chain) > 0) (sample_chain[[1]]$family %||% NULL) else NULL
        genus <- if (length(sample_chain) > 0) (sample_chain[[1]]$genus %||% NULL) else NULL
        species <- if (length(sample_chain) > 0) (sample_chain[[1]]$species %||% NULL) else NULL
        subsampletype <- if (length(sample_chain) > 0) (sample_chain[[1]]$subsampletype %||% NULL) else NULL
        
        # Build associated traits list
        associatedTraits <- list()
        if (!is.null(experiment$associatedTraits)) {
          for (trait in experiment$associatedTraits) {
            trait_obj <- list(
              measurement = trait$measurement,
              type = trait$type,
              equipment = trait$equipment,
              note = trait$note %||% trait$notes
            )
            
            if (trait$type == "diameter") {
              trait_obj$detail <- trait$detail
              trait_obj$nfibres <- trait$nfibres
            }
            
            associatedTraits[[length(associatedTraits) + 1]] <- trait_obj
          }
        }
        
        result <- list(
          experiment_id = experiment_id,
          sample_name = sample_name,
          type = metadata$type %||% "tensile_test",
          date = metadata$date,
          polynomial_coefficients = coefs,
          r_squared = r_squared,
          data_points = length(strain),
          strain_range = c(min(strain), max(strain)),
          stress_range = c(min(stress), max(stress)),
          fracture_detected = trim_info$fracture_detected,
          max_stress = trim_info$max_stress,
          trim_info = trim_info,
          specimenDiameter = mech_props$specimenDiameter,
          strainAtBreak = mech_props$strainAtBreak,
          stressAtBreak = mech_props$stressAtBreak,
          toughness = mech_props$toughness,
          offsetYieldStrain = mech_props$offsetYieldStrain,
          offsetYieldStress = mech_props$offsetYieldStress,
          modulus = mech_props$modulus,
          specimenName = mech_props$specimenName,
          strainRate = mech_props$strainRate,
          responsible = metadata$responsible,
          notes = metadata$notes,
          equipment = metadata$equipment,
          family = family,
          genus = genus,
          species = species,
          subsampletype = subsampletype,
          associatedTraits = associatedTraits,
          sampleChain = sample_chain
        )
        
        # Remove NULL values
        result <- Filter(Negate(is.null), result)
        
        return(result)
      }, error = function(e) {
        cat(sprintf("  ⚠️  Error processing experiment %s: %s\n", experiment_id, e$message))
        return(NULL)
      })
    },
    
    plot_stress_strain = function(strain, stress, sample_name, trim_info = NULL) {
      tryCatch({
        df <- data.frame(strain = strain, stress = stress)
        
        # Fit polynomial for plotting
        poly_fit <- lm(stress ~ poly(strain, self$config$processing$polynomial_degree, raw = TRUE))
        
        strain_smooth <- seq(min(strain), max(strain), length.out = 300)
        stress_fit <- predict(poly_fit, newdata = data.frame(strain = strain_smooth))
        
        fit_df <- data.frame(strain = strain_smooth, stress = stress_fit)
        
        r_squared <- 1 - (sum((stress - fitted(poly_fit))^2) / sum((stress - mean(stress))^2))
        
        p <- ggplot(df, aes(x = strain, y = stress)) +
          geom_point(alpha = 0.7, color = "blue", size = 2) +
          geom_line(data = fit_df, aes(x = strain, y = stress), color = "red", size = 1) +
          labs(
            x = "Engineering Strain",
            y = "Engineering Stress (MPa)",
            title = sprintf("Stress-Strain Curve: %s\n(Trimmed from strain=0 to fracture)", sample_name)
          ) +
          theme_minimal() +
          theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 14))
        
        return(p)
      }, error = function(e) {
        cat(sprintf("  ⚠️  Error creating plot: %s\n", e$message))
        return(NULL)
      })
    },
    
    process_all_experiments = function(data) {
      experiments <- data$experiments
      experiment_ids <- names(experiments)
      
      max_exp <- self$config$processing$max_experiments
      if (!is.null(max_exp)) {
        experiment_ids <- head(experiment_ids, max_exp)
      }
      
      results <- list()
      processed <- 0
      failed <- 0
      
      cat(sprintf("\n📊 Processing %d experiments...\n", length(experiment_ids)))
      
      # Create progress bar
      pb <- txtProgressBar(min = 0, max = length(experiment_ids), style = 3, width = 50)
      
      for (i in seq_along(experiment_ids)) {
        exp_id <- experiment_ids[i]
        
        result <- self$fit_polynomial_to_experiment(data, exp_id)
        
        if (!is.null(result)) {
          results[[length(results) + 1]] <- result
          processed <- processed + 1
          
          if (self$config$processing$save_plots) {
            extracted <- self$extract_stress_strain_data(experiments[[exp_id]])
            if (!is.null(extracted)) {
              p <- self$plot_stress_strain(extracted$strain, extracted$stress, 
                                          extracted$sample_name, extracted$trim_info)
              if (!is.null(p)) {
                # Build filename with taxonomic information
                sample_chain <- experiments[[exp_id]]$sampleChain %||% list()
                family <- if (length(sample_chain) > 0) (sample_chain[[1]]$family %||% 'unknown') else 'unknown'
                genus <- if (length(sample_chain) > 0) (sample_chain[[1]]$genus %||% 'unknown') else 'unknown'
                species <- if (length(sample_chain) > 0) (sample_chain[[1]]$species %||% 'unknown') else 'unknown'
                
                # Clean names for filesystem (replace spaces and special chars)
                family <- gsub("[/ ]", "_", as.character(family))
                genus <- gsub("[/ ]", "_", as.character(genus))
                species <- gsub("[/ ]", "_", as.character(species))
                
                plot_file <- file.path(self$output_dir, sprintf("%s_%s_%s_%s.png", family, genus, species, exp_id))
                suppressMessages(ggsave(plot_file, p, width = 12, height = 8, dpi = 150))
              }
            }
          }
        } else {
          failed <- failed + 1
        }
        
        # Update progress bar
        setTxtProgressBar(pb, i)
      }
      
      close(pb)
      
      cat(sprintf("\n✅ Completed: %d successful, %d failed out of %d experiments\n", 
                  processed, failed, length(experiment_ids)))
      
      return(results)
    },
    
    save_results = function(results, filename = "fit_data.json") {
      output_data <- list(
        metadata = list(
          total_experiments = length(results),
          polynomial_degree = self$config$processing$polynomial_degree,
          processing_date = "2025-10-21",
          fracture_detection = self$config$fracture_detection
        ),
        experiments = list()
      )
      
      for (result in results) {
        exp_id <- result$experiment_id
        output_data$experiments[[exp_id]] <- result
      }
      
      output_path <- file.path(self$output_dir, filename)
      jsonlite::write_json(output_data, output_path, pretty = TRUE, auto_unbox = TRUE)
      
      cat(sprintf("\n💾 Results saved to %s\n", output_path))
      return(output_path)
    }
  )
)

# ---------------------------------------------------------------------------- #
#                                 FILE LOADING                                 #
# ---------------------------------------------------------------------------- #

#' Load experiments data from JSON file
load_experiments_data <- function(json_file_path) {
  tryCatch({
    data <- jsonlite::read_json(json_file_path)
    
    if (!("experiments" %in% names(data))) {
      stop("JSON file must contain 'experiments' key")
    }
    
    return(data)
  }, error = function(e) {
    if (grepl("No such file", e$message)) {
      cat(sprintf("❌ Error: File not found: %s\n", json_file_path))
    } else {
      cat(sprintf("❌ Error: Invalid JSON in %s\n", json_file_path))
    }
    stop(e)
  })
}

# ---------------------------------------------------------------------------- #
#                                 MAIN FUNCTION                                #
# ---------------------------------------------------------------------------- #

#' Main function to process mechanical data
main <- function() {
  cat("\n" %+% strrep("═", 80) %+% "\n")
  cat("EvoNEST Mechanical Data Processing - R\n")
  cat(strrep("═", 80) %+% "\n")
  
  # Load or setup configuration
  config_manager <- ConfigManager$new()
  config <- config_manager$interactive_setup()
  
  cat("\n╔" %+% strrep("═", 78) %+% "╗\n")
  cat(sprintf("║%s║\n", strrep(" ", 20) %+% "Processing Configuration" %+% strrep(" ", 34)))
  cat("╚" %+% strrep("═", 78) %+% "╝\n")
  
  proc <- config$processing
  fd <- config$fracture_detection
  cat(sprintf("\n📊 Polynomial Degree: %d\n", proc$polynomial_degree))
  cat(sprintf("🔍 Stop at Max Stress: %s\n", fd$stop_max_stress))
  cat(sprintf("📁 Output Directory: %s\n", config$output$output_dir))
  cat(sprintf("📈 Show Plots: %s\n", proc$show_plots))
  cat(sprintf("💾 Save Plots: %s\n", proc$save_plots))
  cat("\n" %+% strrep("─", 80) %+% "\n")
  
  # Create processor
  processor <- MechanicalDataProcessor$new(config)
  
  tryCatch({
    # Load experiments data
    data_path <- here::here("downloaded_data", "experiments_data.json")
    cat(sprintf("\n📂 Loading experiments from: %s\n", data_path))
    data <- load_experiments_data(data_path)
    cat(sprintf("✅ Loaded %d experiments\n", length(data$experiments)))
    
    # Process all experiments
    results <- processor$process_all_experiments(data)
    
    # Save results
    processor$save_results(results, "fit_data.json")
    
    cat("\n" %+% strrep("═", 80) %+% "\n")
    cat("✅ Processing complete!\n")
    cat(strrep("═", 80) %+% "\n\n")
  }, error = function(e) {
    #cat(sprintf("\n❌ Error: %s\n", e$message))
  })
}

# Run main if this script is executed directly
if (identical(environment(), globalenv())) {
  main()
}
