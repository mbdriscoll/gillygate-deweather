#!/usr/bin/env Rscript

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 1) {
  stop("Usage: Rscript apply-deweather.r <input_file>")
}

input_file <- args[1]
output_file <- sub("(\\.[^.]+)$", "_normalised\\1", input_file)

library(dplyr)
library(readr)
library(gbm)
library(purrr)
library(foreach)
library(doParallel)
library(tibble)
library(deweather)

input_data <- read_csv(input_file, col_types = cols(
  date = col_datetime(format = "")
))

pollutants <- c("nox", "no2", "no")
met_vars <- c("ws", "wd", "air_temp", "RH")

run_deweather <- function(data, pollutant, met_vars) {
  #model_vars <- c("trend", met_vars, "hour", "weekday")
  model_vars <- c("trend", met_vars)
  
  model <- buildMod(
    input_data = data,
    vars = model_vars,
    pollutant = pollutant,
    sam.size = nrow(data),
    n.trees = 300,
    shrinkage = 0.05,
    interaction.depth = 5,
    bag.fraction = 0.5,
    n.minobsinnode = 10,
    cv.folds = 0,
    B = 100,
    n.core = 32
  )
  
  norm_data <- metSim(
    dw_model = model,
    metVars = met_vars,
    n.core = 4,
    B = 200
  )
  
  return(norm_data)
}

for (pollutant in pollutants) {
  norm_result <- run_deweather(input_data, pollutant, met_vars)
  
  input_data <- left_join(
    input_data,
    norm_result %>% rename_with(~ paste0(pollutant, "_norm"), -date),
    by = "date"
  )
}

write_csv(input_data, output_file)
cat(sprintf("Output saved to: %s\n", output_file))
