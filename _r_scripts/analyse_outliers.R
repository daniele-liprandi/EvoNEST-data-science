#!/usr/bin/env Rscript

# EvoNEST Outlier Analysis Script
# Analyzes experimental data for outliers using sigma-based detection
# Performs hierarchical analysis grouping by Family > Species > Subsample Type
# Manages configuration in config/analyse_outliers_config.json

# Try to load required packages, install if missing
required_packages <- c("here", "tidyverse", "jsonlite", "R6")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = FALSE)) {
    cat("Installing", pkg, "...\n")
    install.packages(pkg)
  }
}

library(tidyverse)
library(jsonlite)
library(here)
library(R6)

# Helper operators
`%||%` <- function(x, y) if (is.null(x)) y else x


# Logger utility =============================================================

Logger <- R6::R6Class(
  "Logger",
  public = list(
    log_file = NULL,
    
    initialize = function(log_file) {
      self$log_file <- log_file
      # Clear previous log if exists
      if (file.exists(log_file)) {
        file.remove(log_file)
      }
    },
    
    write = function(message) {
      write(message, file = self$log_file, append = TRUE)
    },
    
    section = function(title) {
      msg <- paste0("\n", strrep("=", 80), "\n", title, "\n", strrep("=", 80), "\n")
      self$write(msg)
    },
    
    info = function(message) {
      self$write(paste0("[INFO] ", message, "\n"))
    },
    
    subsection = function(title) {
      msg <- paste0("\n", title, "\n", strrep("-", 40), "\n")
      self$write(msg)
    }
  )
)


# Config Manager Class =========================================================

ConfigManager <- R6::R6Class(
  "ConfigManager",
  public = list(
    config_file = NULL,
    config = NULL,
    
    initialize = function() {
      self$config_file <- here::here("config", "analyse_outliers_config.json")
      self$config <- self$load_config()
    },
    
    load_config = function() {
      default_config <- list(
        analysis = list(
          outlier_trait_threshold = 0.3,
          sigma_level = 2
        ),
        output = list(
          output_dir = "processed_data",
          analysis_file = "outlier_analysis.json",
          experiments_file = "outlier_experiments.csv"
        )
      )
      
      if (file.exists(self$config_file)) {
        tryCatch({
          saved_config <- jsonlite::read_json(self$config_file)
          # Merge with defaults
          config <- self$merge_configs(default_config, saved_config)
          cat("✓ Configuration loaded from", self$config_file, "\n")
          return(config)
        }, error = function(e) {
          cat("⚠ Warning: Could not read config file, using defaults\n")
          return(default_config)
        })
      } else {
        cat("⚠ Warning: Config file not found, using defaults\n")
        return(default_config)
      }
    },
    
    merge_configs = function(default, saved) {
      for (key in names(saved)) {
        if (key %in% names(default) && 
            is.list(default[[key]]) && is.list(saved[[key]])) {
          default[[key]] <- self$merge_configs(default[[key]], saved[[key]])
        } else {
          default[[key]] <- saved[[key]]
        }
      }
      return(default)
    }
  )
)


# Outlier Analyzer Class ======================================================

OutlierAnalyzer <- R6::R6Class(
  "OutlierAnalyzer",
  public = list(
    input_file = NULL,
    config_mgr = NULL,
    config = NULL,
    outlier_trait_threshold = NULL,
    sigma_level = NULL,
    output_dir = NULL,
    data = NULL,
    experiments_df = NULL,
    logger = NULL,
    
    initialize = function(input_file = "processed_data/fit_data.json", 
                         config_manager = NULL,
                         logger = NULL) {
      self$input_file <- input_file
      self$config_mgr <- if (is.null(config_manager)) {
        ConfigManager$new()
      } else {
        config_manager
      }
      
      self$config <- self$config_mgr$config
      self$outlier_trait_threshold <- self$config$analysis$outlier_trait_threshold
      self$sigma_level <- self$config$analysis$sigma_level
      self$output_dir <- self$config$output$output_dir
      self$logger <- logger
    },
    
    load_data = function() {
      input_path <- here::here(self$input_file)
      self$data <- jsonlite::read_json(input_path)
      
      cat("Loaded", self$data$metadata$total_experiments, "experiments\n")
      cat("Polynomial degree:", self$data$metadata$polynomial_degree, "\n")
    },
    
    prepare_dataframe = function() {
      records <- list()
      
      for (exp_id in names(self$data$experiments)) {
        exp_data <- self$data$experiments[[exp_id]]
        
        # Build basic record
        record <- list(
          experiment_id = exp_id,
          sample_name = exp_data$sample_name %||% NA_character_,
          family = exp_data$family %||% NA_character_,
          genus = exp_data$genus %||% NA_character_,
          species = exp_data$species %||% NA_character_,
          name = if (!is.null(exp_data$genus) && !is.null(exp_data$species)) {
            paste(exp_data$genus, exp_data$species)
          } else {
            NA_character_
          },
          subsampletype = exp_data$subsampletype %||% NA_character_,
          type = exp_data$type %||% NA_character_,
          r_squared = as.numeric(exp_data$r_squared %||% NA)
        )
        
        # Add polynomial coefficients
        poly_coeffs <- exp_data$polynomial_coefficients %||% list()
        for (i in seq_along(poly_coeffs)) {
          coeff_name <- paste0("coeff_", i - 1)
          # Ensure coefficients are numeric; convert NULL to NA
          coeff_val <- poly_coeffs[[i]]
          if (is.null(coeff_val)) {
            record[[coeff_name]] <- NA_real_
          } else {
            record[[coeff_name]] <- as.numeric(coeff_val)
          }
        }
        
        # Extract traits - aggregate multiple measurements of same type
        traits <- exp_data$associatedTraits %||% list()
        traits_dict <- list()
        
        for (trait in traits) {
          trait_type <- trait$type
          measurement <- trait$measurement
          
          if (!is.null(trait_type) && !is.null(measurement)) {
            # Convert to numeric
            numeric_val <- suppressWarnings(as.numeric(measurement))
            
            # Collect all measurements for this trait type
            if (!(trait_type %in% names(traits_dict))) {
              traits_dict[[trait_type]] <- c()
            }
            traits_dict[[trait_type]] <- c(traits_dict[[trait_type]], numeric_val)
          }
        }
        
        # Store aggregated traits (take mean if multiple measurements)
        for (trait_type in names(traits_dict)) {
          measurements <- traits_dict[[trait_type]]
          # Filter out NA values
          valid_measurements <- measurements[!is.na(measurements)]
          
          col_name <- paste0("trait_", trait_type)
          if (length(valid_measurements) > 0) {
            # Take the mean of multiple measurements, or single value if only one
            record[[col_name]] <- mean(valid_measurements)
          } else {
            record[[col_name]] <- NA_real_
          }
        }
        
        records[[length(records) + 1]] <- record
      }
      
      # Convert to dataframe
      self$experiments_df <- bind_rows(records)
      
      cat("\nDataFrame created with", nrow(self$experiments_df), "experiments\n")
      cat("Columns:", paste(names(self$experiments_df), collapse = ", "), "\n")
    },
    
    calculate_statistics_for_group = function(group_df, column) {
      values <- group_df[[column]]
      values <- values[!is.na(values)]
      
      if (length(values) == 0) {
        return(NULL)
      }
      
      mean_val <- mean(values)
      std_val <- sd(values)
      
      list(
        column = column,
        count = length(values),
        mean = mean_val,
        std = std_val,
        min = min(values),
        max = max(values),
        median = median(values),
        sigma_1_low = mean_val - std_val,
        sigma_1_high = mean_val + std_val,
        sigma_2_low = mean_val - 2 * std_val,
        sigma_2_high = mean_val + 2 * std_val,
        sigma_3_low = mean_val - 3 * std_val,
        sigma_3_high = mean_val + 3 * std_val
      )
    },
    
    find_outliers_in_group = function(group_df, column, stats, sigma_level = 1) {
      if (is.null(stats)) {
        return(tibble())
      }
      
      low_threshold <- stats[[paste0("sigma_", sigma_level, "_low")]]
      high_threshold <- stats[[paste0("sigma_", sigma_level, "_high")]]
      
      outliers <- group_df %>%
        filter(!is.na(.data[[column]])) %>%
        filter(.data[[column]] < low_threshold | .data[[column]] > high_threshold) %>%
        mutate(
          value = .data[[column]],
          deviation = (.data[[column]] - stats$mean) / stats$std,
          abs_deviation = abs(deviation)
        ) %>%
        arrange(desc(abs_deviation)) %>%
        select(
          experiment_id, sample_name, family, name, subsampletype, 
          value, deviation
        )
      
      return(outliers)
    },
    
    identify_outlier_experiments = function(results, sigma_level = 2) {
      outlier_experiments <- list()
      
      for (group_key in names(results)) {
        group_data <- results[[group_key]]
        family <- group_data$family
        name <- group_data$name
        subsampletype <- group_data$subsampletype
        
        experiment_outlier_count <- list()
        total_traits <- length(group_data$traits)
        
        if (total_traits == 0) next
        
        for (trait in names(group_data$traits)) {
          analysis <- group_data$traits[[trait]]
          outliers <- analysis[[paste0("outliers_", sigma_level, "sigma")]]
          
          for (i in seq_len(nrow(outliers))) {
            exp_id <- outliers$experiment_id[i]
            
            if (!(exp_id %in% names(experiment_outlier_count))) {
              experiment_outlier_count[[exp_id]] <- list(
                count = 0,
                sample_name = outliers$sample_name[i],
                family = family,
                name = name,
                subsampletype = subsampletype,
                outlier_trait_list = c()
              )
            }
            
            experiment_outlier_count[[exp_id]]$count <- 
              experiment_outlier_count[[exp_id]]$count + 1
            experiment_outlier_count[[exp_id]]$outlier_trait_list <- 
              c(experiment_outlier_count[[exp_id]]$outlier_trait_list, trait)
          }
        }
        
        for (exp_id in names(experiment_outlier_count)) {
          data <- experiment_outlier_count[[exp_id]]
          outlier_percentage <- data$count / total_traits
          
          if (outlier_percentage >= self$outlier_trait_threshold) {
            outlier_experiments[[length(outlier_experiments) + 1]] <- list(
              experiment_id = exp_id,
              sample_name = data$sample_name,
              family = data$family,
              name = data$name,
              subsampletype = data$subsampletype,
              outlier_traits = data$count,
              total_traits = total_traits,
              outlier_percentage = outlier_percentage,
              sigma_level = sigma_level,
              outlier_trait_list = paste(data$outlier_trait_list, collapse = ", ")
            )
          }
        }
      }
      
      if (length(outlier_experiments) == 0) {
        return(tibble())
      }
      
      df <- bind_rows(outlier_experiments)
      df <- df %>% arrange(desc(outlier_percentage))
      
      return(df)
    },
    
    analyze_all_traits = function() {
      traits_to_analyze <- c()
      
      # Add r_squared
      if ("r_squared" %in% names(self$experiments_df)) {
        traits_to_analyze <- c(traits_to_analyze, "r_squared")
      }
      
      # Add polynomial coefficients
      poly_degree <- self$data$metadata$polynomial_degree
      for (i in 0:poly_degree) {
        col_name <- paste0("coeff_", i)
        if (col_name %in% names(self$experiments_df)) {
          traits_to_analyze <- c(traits_to_analyze, col_name)
        }
      }
      
      # Add trait columns
      trait_columns <- names(self$experiments_df)[
        startsWith(names(self$experiments_df), "trait_")
      ]
      traits_to_analyze <- c(traits_to_analyze, trait_columns)
      
      results <- list()
      
      if (!is.null(self$logger)) {
        self$logger$section("HIERARCHICAL STATISTICAL ANALYSIS OF TENSILE TEST DATA")
        self$logger$info(paste("Analyzing", length(traits_to_analyze), "traits"))
        self$logger$info("Grouping by: Family > Species (name) > Subsample Type")
      }
      
      cat("Analyzing traits")
      
      # Group by family, name, subsampletype
      grouped <- self$experiments_df %>%
        group_by(family, name, subsampletype, .drop = FALSE)
      
      groups_list <- group_split(grouped)
      pb <- txtProgressBar(min = 0, max = length(groups_list), style = 3, 
                          title = "Analyzing groups", width = 50)
      
      for (idx in seq_along(groups_list)) {
        group_info <- groups_list[[idx]]
        setTxtProgressBar(pb, idx)
        
        family <- unique(group_info$family)[1]
        name <- unique(group_info$name)[1]
        subsampletype <- unique(group_info$subsampletype)[1]
        
        if (nrow(group_info) < 2) next
        
        group_key <- paste(family, name, subsampletype, sep = "_")
        
        results[[group_key]] <- list(
          family = family,
          name = name,
          subsampletype = subsampletype,
          sample_count = nrow(group_info),
          traits = list()
        )
        
        for (trait in traits_to_analyze) {
          if (!(trait %in% names(group_info))) next
          
          stats <- self$calculate_statistics_for_group(group_info, trait)
          if (is.null(stats) || stats$count < 2) next
          
          results[[group_key]]$traits[[trait]] <- list(
            statistics = stats,
            outliers_1sigma = self$find_outliers_in_group(
              group_info, trait, stats, sigma_level = 1
            ),
            outliers_2sigma = self$find_outliers_in_group(
              group_info, trait, stats, sigma_level = 2
            ),
            outliers_3sigma = self$find_outliers_in_group(
              group_info, trait, stats, sigma_level = 3
            )
          )
        }
      }
      close(pb)
      
      return(results)
    },
    
    print_analysis_report = function(results) {
      if (!is.null(self$logger)) {
        for (group_key in names(results)) {
          group_data <- results[[group_key]]
          family <- group_data$family
          name <- group_data$name
          subsampletype <- group_data$subsampletype
          sample_count <- group_data$sample_count
          
          self$logger$subsection(paste("GROUP:", family, ">", name, ">", subsampletype))
          self$logger$info(paste("Samples:", sample_count))
          
          traits_with_1sigma <- 0
          traits_with_2sigma <- 0
          traits_with_3sigma <- 0
          total_traits <- length(group_data$traits)
          
          for (trait in names(group_data$traits)) {
            analysis <- group_data$traits[[trait]]
            if (nrow(analysis$outliers_1sigma) > 0) traits_with_1sigma <- traits_with_1sigma + 1
            if (nrow(analysis$outliers_2sigma) > 0) traits_with_2sigma <- traits_with_2sigma + 1
            if (nrow(analysis$outliers_3sigma) > 0) traits_with_3sigma <- traits_with_3sigma + 1
          }
          
          self$logger$info(paste("1σ outliers:", traits_with_1sigma, "/", total_traits))
          self$logger$info(paste("2σ outliers:", traits_with_2sigma, "/", total_traits))
          self$logger$info(paste("3σ outliers:", traits_with_3sigma, "/", total_traits))
          
          for (trait in names(group_data$traits)) {
            analysis <- group_data$traits[[trait]]
            has_outliers <- (nrow(analysis$outliers_1sigma) > 0 ||
                            nrow(analysis$outliers_2sigma) > 0 ||
                            nrow(analysis$outliers_3sigma) > 0)
            
            if (!has_outliers) next
            
            stats <- analysis$statistics
            self$logger$info(paste("Trait:", trait))
            self$logger$info(sprintf("  Mean ± Std: %.4f ± %.4f (n=%d)",
                                    stats$mean, stats$std, stats$count))
            
            for (sigma_level in 1:3) {
              outliers <- analysis[[paste0("outliers_", sigma_level, "sigma")]]
              
              if (nrow(outliers) > 0) {
                self$logger$info(sprintf("  %dσ outliers (%d)", sigma_level, nrow(outliers)))
                
                n_show <- min(5, nrow(outliers))
                for (i in 1:n_show) {
                  self$logger$info(sprintf("    %-30s | Value: %10.4f | %6.2fσ",
                                          substr(outliers$sample_name[i], 1, 30),
                                          outliers$value[i],
                                          outliers$deviation[i]))
                }
                
                if (nrow(outliers) > 5) {
                  self$logger$info(sprintf("    ... and %d more", nrow(outliers) - 5))
                }
              }
            }
          }
        }
      }
    },
    
    save_outlier_report = function(results) {
      output_data <- list(
        metadata = list(
          analysis_date = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
          source_file = self$input_file,
          total_experiments = nrow(self$experiments_df),
          polynomial_degree = self$data$metadata$polynomial_degree,
          grouping = "family > name > subsampletype",
          total_groups = length(results),
          outlier_trait_threshold = self$outlier_trait_threshold,
          sigma_level = self$sigma_level
        ),
        groups = list()
      )
      
      for (group_key in names(results)) {
        group_data <- results[[group_key]]
        family <- group_data$family
        name <- group_data$name
        subsampletype <- group_data$subsampletype
        
        traits_output <- list()
        
        for (trait in names(group_data$traits)) {
          analysis <- group_data$traits[[trait]]
          stats <- analysis$statistics
          
          outliers_1sigma <- if (nrow(analysis$outliers_1sigma) > 0) {
            analysis$outliers_1sigma %>% as.list() %>% list()
          } else {
            list()
          }
          
          outliers_2sigma <- if (nrow(analysis$outliers_2sigma) > 0) {
            analysis$outliers_2sigma %>% as.list() %>% list()
          } else {
            list()
          }
          
          outliers_3sigma <- if (nrow(analysis$outliers_3sigma) > 0) {
            analysis$outliers_3sigma %>% as.list() %>% list()
          } else {
            list()
          }
          
          traits_output[[trait]] <- list(
            statistics = list(
              count = stats$count,
              mean = stats$mean,
              std = stats$std,
              min = stats$min,
              max = stats$max,
              median = stats$median,
              sigma_ranges = list(
                sigma_1 = c(stats$sigma_1_low, stats$sigma_1_high),
                sigma_2 = c(stats$sigma_2_low, stats$sigma_2_high),
                sigma_3 = c(stats$sigma_3_low, stats$sigma_3_high)
              )
            ),
            outliers = list(
              sigma_1 = outliers_1sigma,
              sigma_2 = outliers_2sigma,
              sigma_3 = outliers_3sigma
            )
          )
        }
        
        output_data$groups[[group_key]] <- list(
          family = if (is.na(family)) NULL else family,
          name = if (is.na(name)) NULL else name,
          subsampletype = if (is.na(subsampletype)) NULL else subsampletype,
          sample_count = group_data$sample_count,
          traits = traits_output
        )
      }
      
      output_path <- here::here(self$output_dir)
      dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
      
      analysis_file <- file.path(output_path, self$config$output$analysis_file)
      
      write_json(output_data, analysis_file, pretty = TRUE)
      
      if (!is.null(self$logger)) {
        self$logger$info(paste("Outlier analysis saved to:", analysis_file))
      }
    },
    
    run_analysis = function() {
      self$load_data()
      self$prepare_dataframe()
      results <- self$analyze_all_traits()
      self$print_analysis_report(results)
      
      cat("\n✓ Analysis complete. Identifying outlier experiments...\n")
      
      outlier_exps <- self$identify_outlier_experiments(
        results, sigma_level = self$sigma_level
      )
      
      if (nrow(outlier_exps) > 0) {
        cat("✓ Found", nrow(outlier_exps), "outlier experiments\n\n")
        
        output_path <- here::here(self$output_dir)
        dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
        outlier_file <- file.path(output_path, self$config$output$experiments_file)
        
        write_csv(outlier_exps, outlier_file)
        
        # Print to console
        cat(strrep("=", 80), "\n", sep = "")
        cat("OUTLIER EXPERIMENTS (≥", 
            sprintf("%.0f", self$outlier_trait_threshold * 100),
            "% traits beyond ", self$sigma_level, "σ)\n", sep = "")
        cat(strrep("=", 80), "\n\n", sep = "")
        
        for (i in 1:nrow(outlier_exps)) {
          row <- outlier_exps[i, ]
          cat(sprintf("  %-40s | %-25s | %2d/%2d traits (%5.1f%%)\n",
                     substr(row$sample_name, 1, 40),
                     substr(row$name, 1, 25),
                     row$outlier_traits,
                     row$total_traits,
                     row$outlier_percentage * 100))
        }
        
        cat("\nSaved to:", outlier_file, "\n")
        
        # Also log to file
        if (!is.null(self$logger)) {
          self$logger$section("OUTLIER EXPERIMENTS")
          self$logger$info(paste("Found", nrow(outlier_exps), "experiments with ≥",
                                sprintf("%.0f", self$outlier_trait_threshold * 100),
                                "% outlier traits"))
          
          for (i in 1:nrow(outlier_exps)) {
            row <- outlier_exps[i, ]
            self$logger$info(sprintf("%-40s | %-25s | %2d/%2d traits (%5.1f%%)",
                                    substr(row$sample_name, 1, 40),
                                    substr(row$name, 1, 25),
                                    row$outlier_traits,
                                    row$total_traits,
                                    row$outlier_percentage * 100))
          }
          
          self$logger$info(paste("Outlier experiments saved to:", outlier_file))
        }
      } else {
        cat("No experiments found with ≥",
            sprintf("%.0f", self$outlier_trait_threshold * 100),
            "% outlier traits\n")
        
        if (!is.null(self$logger)) {
          self$logger$info(paste("No experiments found with ≥",
                                sprintf("%.0f", self$outlier_trait_threshold * 100),
                                "% outlier traits"))
        }
      }
      
      self$save_outlier_report(results)
      
      return(list(results = results, outlier_exps = outlier_exps))
    }
  )
)


# Main function ===============================================================

main <- function() {
  cat("\n")
  cat(strrep("=", 80), "\n", sep = "")
  cat("EvoNEST OUTLIER ANALYSIS (R Version)\n")
  cat(strrep("=", 80), "\n\n")
  
  config_mgr <- ConfigManager$new()
  
  cat("Configuration:\n")
  cat("  ✓ Outlier trait threshold:", 
      sprintf("%.0f", config_mgr$config$analysis$outlier_trait_threshold * 100), "%\n")
  cat("  ✓ Sigma level:", config_mgr$config$analysis$sigma_level, "\n")
  cat("  ✓ Output directory:", config_mgr$config$output$output_dir, "\n\n")
  
  # Initialize logger
  output_path <- here::here(config_mgr$config$output$output_dir)
  dir.create(output_path, showWarnings = FALSE, recursive = TRUE)
  log_file <- file.path(output_path, "outlier_analysis.log")
  logger <- Logger$new(log_file)
  
  logger$section("EvoNEST OUTLIER ANALYSIS")
  logger$info(paste("Analysis date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
  logger$info(paste("Outlier trait threshold:", config_mgr$config$analysis$outlier_trait_threshold * 100, "%"))
  logger$info(paste("Sigma level:", config_mgr$config$analysis$sigma_level))
  
  analyzer <- OutlierAnalyzer$new(config_manager = config_mgr, logger = logger)
  results_list <- analyzer$run_analysis()
  results <- results_list$results
  outlier_exps <- results_list$outlier_exps
  
  # Print summary to console
  total_groups <- length(results)
  total_samples <- sum(sapply(results, function(x) x$sample_count))
  
  groups_with_1sigma <- 0
  groups_with_2sigma <- 0
  groups_with_3sigma <- 0
  
  for (group_data in results) {
    has_1sigma <- any(sapply(group_data$traits, 
                             function(x) nrow(x$outliers_1sigma) > 0))
    has_2sigma <- any(sapply(group_data$traits, 
                             function(x) nrow(x$outliers_2sigma) > 0))
    has_3sigma <- any(sapply(group_data$traits, 
                             function(x) nrow(x$outliers_3sigma) > 0))
    
    if (has_1sigma) groups_with_1sigma <- groups_with_1sigma + 1
    if (has_2sigma) groups_with_2sigma <- groups_with_2sigma + 1
    if (has_3sigma) groups_with_3sigma <- groups_with_3sigma + 1
  }
  
  cat("\n", strrep("=", 80), "\n", sep = "")
  cat("SUMMARY\n")
  cat(strrep("=", 80), "\n")
  cat("  Total groups analyzed:", total_groups, "\n")
  cat("  Total samples:", total_samples, "\n")
  cat("  Groups with 1σ outliers:", groups_with_1sigma, "\n")
  cat("  Groups with 2σ outliers:", groups_with_2sigma, "\n")
  cat("  Groups with 3σ outliers:", groups_with_3sigma, "\n")
  cat("\n  Outlier experiments (≥",
      sprintf("%.0f", config_mgr$config$analysis$outlier_trait_threshold * 100),
      "% traits beyond ", config_mgr$config$analysis$sigma_level, "σ): ",
      nrow(outlier_exps), "\n", sep = "")
}


main()
