#!/usr/bin/env Rscript

# EvoNEST Data Fetch Script
# Fetches data from EvoNEST API and saves to downloaded_data/
# Manages configuration in config/evonest_config.json

# Try to load required packages, install if missing
required_packages <- c("here", "R6", "jsonlite", "curl")

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = FALSE)) {
    cat("Installing", pkg, "...\n")
    install.packages(pkg)
  }
}

library(here)
library(R6)
library(jsonlite)
library(curl)

# ============================================================================
# Configuration Manager
# ============================================================================

ConfigManager <- R6::R6Class(
  "ConfigManager",
  public = list(
    config_dir = NULL,
    config_file = NULL,
    config = NULL,
    
    initialize = function() {
      # Set paths using here::here()
      self$config_dir <- here::here("config")
      self$config_file <- here::here("config", "evonest_config.json")

      # Create config directory if it doesn't exist
      dir.create(self$config_dir, showWarnings = FALSE, recursive = TRUE)

      self$config <- self$load_config()
    },
    
    load_config = function() {
      if (file.exists(self$config_file)) {
        tryCatch({
          saved_config <- fromJSON(self$config_file)
          # Merge with defaults
          return(private$merge_configs(private$default_config(), saved_config))
        }, error = function(e) {
          cat("⚠️  Warning: Could not read config file, using defaults\n")
          return(private$default_config())
        })
      } else {
        return(private$default_config())
      }
    },
    
    save_config = function() {
      tryCatch({
        dir.create(self$config_dir, showWarnings = FALSE, recursive = TRUE)
        write_json(self$config, self$config_file, pretty = TRUE)
        cat("✅ Configuration saved to", self$config_file, "\n")
        return(TRUE)
      }, error = function(e) {
        cat("⚠️  Warning: Could not save config:", e$message, "\n")
        return(FALSE)
      })
    },
    
    has_api_credentials = function() {
      api_key <- self$config$api$api_key
      database <- self$config$api$database
      return(!is.null(api_key) && api_key != "" && !is.null(database))
    },
    
    interactive_setup = function() {
      private$print_header("EvoNEST Data Fetch Configuration")
      
      config_exists <- file.exists(self$config_file)
      
      if (config_exists && self$has_api_credentials()) {
        cat("\n📋 Found existing configuration:\n")
        private$print_current_config()
        cat("\n", strrep("─", 80), "\n", sep = "")
        
        use_existing <- private$prompt_yes_no("Use existing configuration?", default = TRUE)
        
        if (use_existing) {
          cat("\n✅ Using saved configuration\n")
          return(self$config)
        }
      }
      
      # Setup API credentials
      cat("\n", strrep("═", 80), "\n", sep = "")
      private$setup_api_credentials(config_exists)
      
      # Setup fetch options
      cat("\n", strrep("═", 80), "\n", sep = "")
      configure_options <- private$prompt_yes_no("Configure advanced fetch options?", default = FALSE)
      
      if (configure_options) {
        private$setup_fetch_options()
      } else {
        cat("\n✅ Using default fetch options\n")
      }
      
      # Save configuration
      cat("\n", strrep("─", 80), "\n", sep = "")
      if (private$prompt_yes_no("Save this configuration for future use?", default = TRUE)) {
        self$save_config()
      } else {
        cat("⚠️  Configuration will be used for this session only\n")
      }
      
      return(self$config)
    }
  ),
  
  private = list(
    default_config = function() {
      list(
        api = list(
          api_key = "",
          database = "supersilk",
          base_url = "https://evonest.zoologie.uni-greifswald.de"
        ),
        fetch_options = list(
          include_related = FALSE,
          include_raw_data = FALSE,
          include_original = FALSE,
          include_sample_features = TRUE
        )
      )
    },
    
    merge_configs = function(default, saved) {
      for (key in names(saved)) {
        if (key %in% names(default) && is.list(default[[key]]) && is.list(saved[[key]])) {
          default[[key]] <- private$merge_configs(default[[key]], saved[[key]])
        } else {
          default[[key]] <- saved[[key]]
        }
      }
      return(default)
    },
    
    setup_api_credentials = function(config_exists) {
      private$print_section("API Credentials")
      
      # API Key
      current_key <- self$config$api$api_key
      if (!is.null(current_key) && current_key != "" && config_exists) {
        if (nchar(current_key) > 12) {
          masked_key <- paste0(substr(current_key, 1, 8), "...", substr(current_key, nchar(current_key) - 3, nchar(current_key)))
        } else {
          masked_key <- "***"
        }
        cat("\nCurrent API key:", masked_key, "\n")
      }
      
      api_key <- private$prompt_input("Enter API key (format: evo_xxxxx)", default = current_key, required = TRUE)
      self$config$api$api_key <<- api_key
      
      # Database
      current_db <- self$config$api$database
      database <- private$prompt_input("Enter database name", default = current_db, required = TRUE)
      self$config$api$database <<- database
    },
    
    setup_fetch_options = function() {
      private$print_section("Fetch Options")
      
      include_related <- private$prompt_yes_no(
        "Include related/parent chain information?",
        default = self$config$fetch_options$include_related
      )
      self$config$fetch_options$include_related <<- include_related
      
      include_raw_data <- private$prompt_yes_no(
        "Include raw experimental data?",
        default = self$config$fetch_options$include_raw_data
      )
      self$config$fetch_options$include_raw_data <<- include_raw_data
      
      include_original <- private$prompt_yes_no(
        "Include original unprocessed data?",
        default = self$config$fetch_options$include_original
      )
      self$config$fetch_options$include_original <<- include_original
    },
    
    print_current_config = function() {
      cat("\n┌─ API Settings ──────────────────────────────────────────\n")
      api_key <- self$config$api$api_key
      if (!is.null(api_key) && api_key != "" && nchar(api_key) > 12) {
        masked_key <- paste0(substr(api_key, 1, 8), "...", substr(api_key, nchar(api_key) - 3, nchar(api_key)))
      } else {
        masked_key <- "Not set"
      }
      cat("│ API Key: ", masked_key, "\n")
      cat("│ Database:", self$config$api$database, "\n")
      
      cat("\n├─ Fetch Options ────────────────────────────────────────\n")
      cat("│ Include Related:    ", self$config$fetch_options$include_related, "\n")
      cat("│ Include Raw Data:   ", self$config$fetch_options$include_raw_data, "\n")
      cat("│ Include Original:   ", self$config$fetch_options$include_original, "\n")
      cat("└────────────────────────────────────────────────────────\n")
    },
    
    print_header = function(title) {
      cat("\n╔", strrep("═", 78), "╗\n", sep = "")
      cat("║", format(title, width = 78, justify = "centre"), "║\n", sep = "")
      cat("╚", strrep("═", 78), "╝\n", sep = "")
    },
    
    print_section = function(title) {
      remaining <- 74 - nchar(title)
      cat("\n┌─ ", title, " ", strrep("─", remaining), "\n", sep = "")
    },
    
    prompt_input = function(prompt, default = NULL, required = FALSE) {
      if (!is.null(default)) {
        prompt_text <- paste0(prompt, " [", default, "]: ")
      } else {
        prompt_text <- paste0(prompt, ": ")
      }
      
      while (TRUE) {
        value <- trimws(readline(prompt_text))
        
        if (value == "" && !is.null(default)) {
          return(default)
        } else if (value == "" && required) {
          cat("❌ This field is required!\n")
          next
        } else if (value != "") {
          return(value)
        } else {
          return("")
        }
      }
    },
    
    prompt_yes_no = function(prompt, default = TRUE) {
      default_text <- if (default) "Y/n" else "y/N"
      prompt_text <- paste0(prompt, " [", default_text, "]: ")
      
      while (TRUE) {
        value <- tolower(trimws(readline(prompt_text)))
        
        if (value == "") {
          return(default)
        } else if (value %in% c("y", "yes")) {
          return(TRUE)
        } else if (value %in% c("n", "no")) {
          return(FALSE)
        } else {
          cat("❌ Please enter 'y' or 'n'\n")
        }
      }
    }
  )
)


# ============================================================================
# EvoNEST Client
# ============================================================================

EvoNESTClient <- R6::R6Class(
  "EvoNESTClient",
  public = list(
    api_key = NULL,
    database = NULL,
    base_url = NULL,
    
    initialize = function(api_key, database, base_url = "https://evonest.zoologie.uni-greifswald.de") {
      self$api_key <- api_key
      self$database <- database
      self$base_url <- base_url
      cat("✅ EvoNEST Client initialized for database:", database, "\n")
    },
    
    get_samples = function(include_related = FALSE, sample_type = NULL, family = NULL) {
      cat("📊 Fetching samples from EvoNEST API...\n")
      
      # Build query string
      params <- list(database = self$database)
      if (include_related) params$related <- "true"
      if (!is.null(sample_type)) params$type <- sample_type
      if (!is.null(family)) params$family <- family
      
      url <- private$build_url(self$base_url, "/api/samples/ext", params)
      
      tryCatch({
        result <- private$make_request(url)
        if (is.null(result)) return(NULL)
        
        samples <- result$data
        cat("✅ Successfully retrieved", length(samples$samples), "samples\n\n")
        return(samples)
      }, error = function(e) {
        cat("❌ Request error:", e$message, "\n")
        return(NULL)
      })
    },
    
    get_traits = function(include_sample_features = TRUE) {
      cat("📊 Fetching traits from EvoNEST API...\n")
      
      params <- list(
        database = self$database,
        includeSampleFeatures = tolower(as.character(include_sample_features))
      )
      
      url <- private$build_url(self$base_url, "/api/traits/ext", params)
      
      tryCatch({
        result <- private$make_request(url)
        if (is.null(result)) return(NULL)
        
        traits <- result$data
        cat("✅ Successfully retrieved", length(traits$traits), "traits\n\n")
        return(traits)
      }, error = function(e) {
        cat("❌ Request error:", e$message, "\n")
        return(NULL)
      })
    },
    
    get_experiments = function(include_raw_data = FALSE, include_original = FALSE, include_related = FALSE) {
      cat("📊 Fetching experiments from EvoNEST API...\n")
      
      params <- list(database = self$database)
      if (include_raw_data) params$includeRawData <- "true"
      if (include_original) params$includeOriginal <- "true"
      if (include_related) params$includeRelated <- "true"
      
      url <- private$build_url(self$base_url, "/api/experiments/ext", params)
      
      tryCatch({
        result <- private$make_request(url)
        if (is.null(result)) return(NULL)
        
        experiments <- result$data
        cat("✅ Successfully retrieved", length(experiments$experiments), "experiments\n\n")
        return(experiments)
      }, error = function(e) {
        cat("❌ Request error:", e$message, "\n")
        return(NULL)
      })
    }
  ),
  
  private = list(
    make_request = function(url) {
      tryCatch({
        # Use curl to make the request
        h <- curl::new_handle()
        # Set headers properly with named list
        headers <- c(
          "Authorization" = paste0("Bearer ", self$api_key),
          "Content-Type" = "application/json"
        )
        curl::handle_setheaders(h, .list = headers)
        
        response <- curl::curl_fetch_memory(url, handle = h)
        
        # Check status code
        status_code <- response$status_code
        
        if (status_code == 401) {
          cat("❌ Authentication failed. API key may be invalid.\n")
          return(NULL)
        } else if (status_code == 403) {
          cat("❌ Access denied. Check your API key and database permissions.\n")
          return(NULL)
        } else if (status_code == 500) {
          cat("❌ Server error. Database connection may be unavailable.\n")
          return(NULL)
        } else if (status_code != 200) {
          cat("❌ Error: Status code", status_code, "\n")
          return(NULL)
        }
        
        # Parse JSON response
        response_text <- rawToChar(response$content)
        data <- fromJSON(response_text)
        
        return(list(status_code = status_code, data = data))
      }, error = function(e) {
        cat("❌ Request error:", e$message, "\n")
        return(NULL)
      })
    },
    
    build_url = function(base_url, endpoint, params) {
      url <- paste0(base_url, endpoint)
      
      # Build query string
      if (length(params) > 0) {
        query_parts <- character(0)
        for (i in seq_along(params)) {
          key <- names(params)[i]
          value <- params[[i]]
          query_parts <- c(query_parts, paste0(key, "=", curl::curl_escape(as.character(value))))
        }
        url <- paste0(url, "?", paste(query_parts, collapse = "&"))
      }
      
      return(url)
    }
  )
)


# ============================================================================
# Utility Functions
# ============================================================================

save_data <- function(data, filename) {
  # Use here::here() for path
  output_dir <- here::here("downloaded_data")

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  output_file <- file.path(output_dir, filename)

  tryCatch({
    write_json(data, output_file, pretty = TRUE)
    cat("💾 Data saved to", output_file, "\n")
    return(TRUE)
  }, error = function(e) {
    cat("❌ Error saving data:", e$message, "\n")
    return(FALSE)
  })
}


# ============================================================================
# Main Function
# ============================================================================

main <- function() {
  cat("\n", strrep("═", 80), "\n", sep = "")
  cat("EvoNEST Data Fetch - R\n")
  cat(strrep("═", 80), "\n", sep = "")
  
  # Load or setup configuration
  config_manager <- ConfigManager$new()
  config <- config_manager$interactive_setup()
  
  api_key <- config$api$api_key
  database <- config$api$database
  base_url <- config$api$base_url
  
  if (api_key == "" || is.null(database) || database == "") {
    cat("\n❌ Error: API key and database are required!\n")
    return(invisible(NULL))
  }
  
  # Create client
  cat("\n", strrep("═", 80), "\n", sep = "")
  client <- EvoNESTClient$new(api_key = api_key, database = database, base_url = base_url)
  
  tryCatch({
    fetch_opts <- config$fetch_options
    
    # Fetch samples
    cat("\n", strrep("=", 80), "\n", sep = "")
    cat("FETCHING SAMPLES\n")
    cat(strrep("=", 80), "\n\n", sep = "")
    
    samples <- client$get_samples(include_related = fetch_opts$include_related)
    if (!is.null(samples)) {
      save_data(samples, "samples_data.json")
    }
    
    # Fetch traits
    cat("\n", strrep("=", 80), "\n", sep = "")
    cat("FETCHING TRAITS\n")
    cat(strrep("=", 80), "\n\n", sep = "")
    
    traits <- client$get_traits(include_sample_features = fetch_opts$include_sample_features)
    if (!is.null(traits)) {
      save_data(traits, "traits_data.json")
    }
    
    # Fetch experiments
    cat("\n", strrep("=", 80), "\n", sep = "")
    cat("FETCHING EXPERIMENTS\n")
    cat(strrep("=", 80), "\n\n", sep = "")
    
    experiments <- client$get_experiments(
      include_raw_data = fetch_opts$include_raw_data,
      include_original = fetch_opts$include_original,
      include_related = TRUE
    )
    
    if (!is.null(experiments)) {
      save_data(experiments, "experiments_data.json")
    }
    
    cat("\n", strrep("=", 80), "\n", sep = "")
    cat("✅ Data fetch complete!\n")
    cat(strrep("=", 80), "\n", sep = "")
  }, error = function(e) {
    cat("\n❌ Error during data fetch:", e$message, "\n")
    traceback()
  })
}

# Run main function
main()
