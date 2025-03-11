#!/usr/bin/env Rscript

# Script to download weather station and air quality data
# Usage: Rscript download_met_aq_data.R <met_station> <aq_station_code> [years_back] [aq_source]
# Example: Rscript download_met_aq_data.R EGXZ YK7 3 aqe

options(tibble.width = Inf)  # Display all columns
options(tibble.print_max = Inf)  # Display all rows
options(pillar.min_title_chars = Inf)  # Prevent column name truncation

# Load required packages
suppressPackageStartupMessages({
  library(worldmet)
  library(openair)
  library(tidyverse)
  library(lubridate)
})

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 2) {
  cat("Usage: Rscript download_met_aq_data.R <met_station> <aq_station_code> [years_back] [aq_source]\n")
  cat("Example: Rscript download_met_aq_data.R EGXZ YK7 3 aqe\n")
  quit(status = 1)
}

met_station <- args[1]
aq_code <- args[2]
years_back <- ifelse(length(args) >= 3, as.numeric(args[3]), 5) # Default to 5 years if not specified
aq_source <- ifelse(length(args) >= 4, args[4], "aqe") # Default to "aqe" source if not specified

# Calculate years to download
current_year <- year(Sys.Date())
years_to_download <- (current_year - years_back + 1):current_year

cat("Parameters:\n")
cat("- Meteorological station:", met_station, "\n")
cat("- Air quality station code:", aq_code, "\n")
cat("- Time period:", years_back, "years (", min(years_to_download), "-", max(years_to_download), ")\n")
cat("- Air quality source:", aq_source, "\n\n")

# Find meteorological station code based on call sign
get_met_code <- function(call_sign) {
  # Get all metadata
  meta_data <- getMeta()
  
  # Filter by call sign
  station_info <- meta_data %>% 
    filter(call == call_sign)
  
  if (nrow(station_info) == 0) {
    stop("Meteorological station not found. Use worldmet::getMeta() to find available stations.")
  }
  
  # Return the code of the first matching station
  return(station_info$code[1])
}

# Function to verify air quality site code exists
verify_aq_code <- function(site_code) {
  sites <- importMeta()
  
  # Check if code exists
  site_match <- sites %>% 
    filter(code == site_code)
  
  if (nrow(site_match) == 0) {
    warning("Air quality station code not found in metadata. The code may be valid but not in the current metadata.")
    return(site_code)
  }
  
  # Print info about the matched site
  cat("Air quality station info:\n")
  print(site_match %>% select(code, site, site_type, latitude, longitude))
  
  return(site_code)
}

# Get station codes
tryCatch({
  cat("Finding meteorological station code...\n")
  met_code <- get_met_code(met_station)
  cat("Found meteorological station code:", met_code, "\n")
  
  cat("Verifying air quality station code...\n")
  aq_code <- verify_aq_code(aq_code)
  cat("Using air quality station code:", aq_code, "\n\n")
}, error = function(e) {
  cat("Error:", e$message, "\n")
  quit(status = 1)
})

# Download meteorological data
cat("Downloading meteorological data...\n")
met_data <- lapply(years_to_download, function(year) {
  cat("  Downloading met data for year", year, "\n")
  tryCatch(
    importNOAA(code = met_code, year = year),
    error = function(e) {
      cat("    Error downloading met data for year", year, ":", e$message, "\n")
      return(NULL)
    }
  )
}) %>% bind_rows()

if (nrow(met_data) == 0) {
  stop("No meteorological data was downloaded.")
}

cat("Downloaded", nrow(met_data), "meteorological data records\n\n")

# Download air quality data using importUKAQ instead of importAURN
cat("Downloading air quality data...\n")
aq_data <- lapply(years_to_download, function(year) {
  cat("  Downloading air quality data for year", year, "\n")
  tryCatch(
    importUKAQ(site = aq_code, year = year, source = aq_source),
    error = function(e) {
      cat("    Error downloading air quality data for year", year, ":", e$message, "\n")
      return(NULL)
    }
  )
}) %>% bind_rows()

if (nrow(aq_data) == 0) {
  stop("No air quality data was downloaded.")
}

cat("Downloaded", nrow(aq_data), "air quality data records\n\n")

# Merge the datasets
cat("Merging datasets...\n")

# Remove existing meteorological variables from AQ data if they exist
met_vars <- c("ws", "wd", "air_temp")
cols_to_remove <- intersect(names(aq_data), met_vars)

if (length(cols_to_remove) > 0) {
  aq_data <- aq_data %>% select(-all_of(cols_to_remove))
}

# Merge datasets
merged_data <- left_join(aq_data, met_data, by = "date")

cat("Final dataset has", nrow(merged_data), "rows and", ncol(merged_data), "columns\n\n")

# Create output filename
output_file <- paste0(
  "met_", met_station, "_aq_", aq_code, "_", aq_source, "_", 
  min(years_to_download), "_to_", max(years_to_download), ".csv"
)

# Save to CSV
cat("Saving data to", output_file, "...\n")
write_csv(merged_data, output_file)
cat("Done!\n")

# Print summary of data
cat("\nSummary of data (first 5 rows):\n")
print(head(merged_data, 5))

cat("\nAvailable variables:\n")
cat(paste(names(merged_data), collapse = ", "), "\n")
