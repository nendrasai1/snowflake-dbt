setwd("~/scratch/slack_stats")
install.packages('readr')
install.packages('stringr')
                 
   
library(stringr)
library(readr)
library(tibble)

file_path <- paste0('./data/raw/', dir('data/raw'))
raw <- read_csv(file_path,
                col_types = cols(.default = 'c',
                                 Date = 'D'))


clean_names <- function(list_names) {
  list_names %>%
    tolower() %>%
    str_replace('\\,', ' in') %>%
    str_replace('\\-', '\\_') %>%
    str_replace_all('\\s', '\\_')
}
clean <- as_tibble(raw, .name_repair = clean_names)
file_name <- paste0('sheetload_gitlab_slack_data_', Sys.Date(), '.csv')
write_csv(clean, paste0('./data/clean/', file_name))
