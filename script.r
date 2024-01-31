# Setting working directory
setwd("path/to/working/directory")

# Loading required libraries
library(readr)
library(tidyverse)
library(skimr)
library(dplyr)
library(moderndive)
library(infer)
library(lubridate)
options(scipen = 999)

# Loading data files 
sewerdata <- read.csv2('Datafiles/COVID-19_SewerWaterData_MunicipalitiesWeek.csv')
municipalities <- read.csv2('Datafiles/municipalities_alphabetically_2022.csv')
population_density <- read.csv2('Datafiles/Regionale_kerncijfers_Nederland_23012024_192144.csv')

# Adjusting column names
names(sewerdata)[8:9] <- c("MunicipalName","RNA_flow")
colnames(population_density) <- c("Year", "MunicipalName", "Population", "PopulationDensity")

# #################### Clearing and adjusting dataframes

# Exploring dataframe columns
glimpse(sewerdata)
glimpse(municipalities)
glimpse(population_density)

# Exploring unique and missing data for loaded dataframes
data.frame(unique=sapply(sewerdata, function(x) sum(length(unique(x, na.rm = TRUE)))), 
           missing=sapply(sewerdata, function(x) sum(is.na(x) | x == 0)))
data.frame(unique=sapply(municipalities, function(x) sum(length(unique(x, na.rm = TRUE)))), 
           missing=sapply(municipalities, function(x) sum(is.na(x) | x == 0)))
data.frame(unique=sapply(population_density, function(x) sum(length(unique(x, na.rm = TRUE)))), 
           missing=sapply(population_density, function(x) sum(is.na(x) | x == 0)))

# Removing unused columns
sewerdata <- sewerdata[-c(1,2)]

# Removing missing observations
sewerdata <- sewerdata %>% drop_na(RNA_flow)
population_density <- population_density %>% drop_na(Population)

# Dividing RNA flow amount by 100,000 to receive weekly avg for one person
sewerdata$RNA_flow <- round(sewerdata$RNA_flow / 100000, digits = 3)
# Normalizing RNA flow to millions for clarity
sewerdata$RNA_flow <- round(sewerdata$RNA_flow / 1000000, digits = 3)

# Joining provincial names to sewer dataframe
municipalities <- subset(municipalities, 
                    select = c(MunicipalName, ProvincialName))
sewerdata <- inner_join(sewerdata, municipalities, by = "MunicipalName", na_matches = "na")

# Joining provincial names to population dataframe
population_density <- inner_join(population_density, municipalities, by = "MunicipalName", na_matches = "na")

# Ordering data frame by year and then by municipal name
population_density <- population_density[with(population_density, order(Year, MunicipalName)), ]

# #################### Exploration of summary statistics

# Counting number of municipalities number in each province
mun_per_province <- municipalities %>% 
  group_by(ProvincialName) %>% 
  summarise(count = n()) %>% 
  arrange(desc(count)) 
mun_per_province

# Plotting number of municipalities number in each province
mun_per_province %>% ggplot(aes(x = ProvincialName, y = count)) +
  geom_col() +
  labs(x = "Province", 
       y = "Number of municipalities",
       title = "Number of municipalities in each province")

# Scatterplot for population size vs. density
population_density %>% ggplot(aes(x = Population, y = PopulationDensity)) + 
  geom_point() +
  labs(x = "Population size", 
       y = "Population density",
       title = "Population size vs population density")

# Boxplotting population across provinces without outliers
population_density %>% filter(Population < 250000) %>% ggplot(aes(x = factor(ProvincialName), y = Population)) +
  geom_boxplot() + 
  labs(x = "Province", 
       y = "Population size",
       title = "Population size summary")

# Boxplotting population density across provinces without outliers
population_density %>% filter(Population < 250000) %>% ggplot(aes(x = factor(ProvincialName), y = PopulationDensity)) +
  geom_boxplot() + 
  labs(x = "Province", 
       y = "Population density",
       title = "Population density summary")

# Plotting population distribution
population_density %>% filter(Population < 250000) %>% ggplot(aes(x = Population)) + 
  geom_histogram(bins = 30) +
  labs(x = "Population", 
       y = "Number of observations",
       title = "Population distribution")


# Plotting overall trend of RNA flow count across all municipalities
sewerdata %>% group_by(Year, Week) %>% summarise(total_rna = sum(RNA_flow)) %>% 
  ggplot(aes(x = interaction(Year, Week, sep = "-", lex.order = TRUE), y = total_rna)) + 
  geom_col() +
  labs(x = "Year-Week", 
       y = "Cumulative RNA flow",
       title = "Trend of RNA Flow over time") + 
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))


# #################### Results of the data analysis

###################### Question 1

# Mean RNA value per province
rna_per_province <- sewerdata %>%
  group_by(ProvincialName) %>%
  summarise(mean_RNA = mean(RNA_flow)) %>%
  arrange(desc(mean_RNA))
rna_per_province

# Mean density per province
density_per_province <- population_density %>%
  group_by(ProvincialName) %>%
  summarise(
    mean_desity = mean(PopulationDensity)) %>%
  arrange(desc(mean_desity))

# Joining mean aggregates
aggr_rna_density <- inner_join(rna_per_province, density_per_province, by = "ProvincialName", na_matches = "na")

# Plotting the linear regression between mean province density and mean RNA measurement
aggr_rna_density %>% ggplot(aes(x = mean_desity, y = mean_RNA)) +
  geom_jitter(alpha = 0.5) +
  labs(x = "Mean province density", 
       y = "Mean RNA particles per habitant (millions)",
       title = "Relationship between RNA particles measurments and province population density") + 
  geom_smooth(method = "lm", se = FALSE)

# Mean RNA value per municipality
rna_per_municipality <- sewerdata %>%
  group_by(MunicipalName) %>%
  summarise(mean_RNA = mean(RNA_flow)) %>%
  arrange(desc(mean_RNA))
rna_per_municipality

# Mean density per municipality
density_per_municipality <- population_density %>%
  group_by(MunicipalName) %>%
  summarise(
    mean_desity = mean(PopulationDensity)) %>%
  arrange(desc(mean_desity))

# Joining mean aggregates
aggr_rna_density_mun <- inner_join(rna_per_municipality, density_per_municipality, by = "MunicipalName", na_matches = "na")

# Plotting the linear regression between mean municipality density and mean RNA measurement
aggr_rna_density_mun %>% ggplot(aes(x = mean_desity, y = mean_RNA)) +
  geom_jitter(alpha = 0.5) +
  labs(x = "Mean municipality density", 
       y = "Mean RNA particles per habitant (millions)",
       title = "Relationship between RNA particles measurments and municipality population density") + 
  geom_smooth(method = "lm", se = FALSE)

# Fit regression model
model_01 <- lm(mean_RNA ~ mean_desity, data = aggr_rna_density_mun)

# Get regression table
get_regression_table(model_01)

# Making null distribution
null_dist_01 <- aggr_rna_density_mun %>% 
  specify(formula = mean_RNA ~ mean_desity) %>% 
  hypothesize(null = "independence") %>% 
  generate(reps = 1000, type = "permute") %>% 
  calculate(stat = "correlation")

# Observation difference proportion
obp_01  <- aggr_rna_density_mun %>% 
  specify(formula = mean_RNA ~ mean_desity) %>%
  calculate(stat = "correlation")

# Visualizing null distribution
visualize(null_dist_01, bins = 20) + 
  shade_p_value(obs_stat = obp_01, direction = "both")

# Making a yearly slice of sewer data observations for each municipality
yearly_slice <- sewerdata %>% 
  filter(Week == 37) %>% 
  inner_join(population_density %>% subset(select = c("MunicipalName","Year","PopulationDensity")))

# Plotting the facceted linear regression between municipal density and RNA measurements
yearly_slice %>% ggplot(aes(x = PopulationDensity, y = RNA_flow)) +
  geom_jitter(alpha = 0.5) +
  labs(x = "Density", 
       y = "RNA particles (hundreds of billions)",
       title = "Relationship between RNA particles measurments and population density") + 
  geom_smooth(method = "lm", se = FALSE) +
  facet_wrap(vars(Year), nrow = 4)

###################### Question 2

# Order sewer data by municipality, year and week
sewer_ordered <- sewerdata[with(sewerdata, order(MunicipalName, Year, Week)), ]

# Calculating the RNA flow delta between weeks
sewer_ordered$delta <- with(sewer_ordered,
                            ifelse(MunicipalName == lag(MunicipalName), 
                                   RNA_flow - lag(RNA_flow), NA))

# Marking whether RNA flow was increased comparing to previous week
sewer_ordered$IncreaseRNA <- with(sewer_ordered,
                                  ifelse(MunicipalName == lag(MunicipalName), 
                                         ifelse(RNA_flow > lag(RNA_flow), TRUE, FALSE), NA))

# Grouping sewer RNA flow by year-weeks, summing up observations of RNA flow increase across municipalities
weekly_group <- sewer_ordered %>% drop_na(IncreaseRNA)  %>% 
  group_by(Year, Week) %>%
  summarise(inc = sum(IncreaseRNA),            # amount of observations when RNA flow increased comparing with previous week
            obs = n(),                         # amount of observations for year-week pair
            percent = sum(IncreaseRNA) / n(),  # percent of increase observations vs total for year-week
            sd = sd(IncreaseRNA)) %>%          # spread of observed increase across municipalities
  arrange(desc(obs))

# Shifting rightmost weeks to the left from the 0 to make clear plot for seasons
weekly_group$Week <- with(weekly_group, ifelse(Week %in% 52:53, -1, 
                                                 ifelse(Week == 51, -2, 
                                                        ifelse(Week == 50, -3, ifelse(Week == 49, -4, Week)))))
# Shifted to the left weeks assigned to the next year
weekly_group$Year <- with(weekly_group, ifelse(Week < 0, Year + 1, Year))

# Assigning seasons to weeks 
weekly_group$season <- with(weekly_group, ifelse(Week %in% 10:22, "Spring", 
                                              ifelse(Week %in% 23:35, "Summer", 
                                                  ifelse(Week %in% 36:48, "Fall", "Winter"))))
weekly_group$season_num <- with(weekly_group, ifelse(Week %in% 10:22, 02, 
                                                 ifelse(Week %in% 23:35, 03, 
                                                        ifelse(Week %in% 36:48, 04, 01))))

# Plotting percentage of RNA flow increase throughout the weeks in year facets
weekly_group %>%  ggplot(aes(x = Week, y = percent)) +
  geom_jitter(alpha = 0.5) +
  labs(x = "Week number", 
       y = "Observed increase in RNA flow (percentage)",
       title = "Increase of RNA flow observed on weeks during the year (faceted)") +
  facet_wrap(vars(Year), nrow = 5) +
  geom_vline(xintercept = 10, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 23, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 36, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 49, linetype="dotted", color = "blue")
  
# Plotting percentage of RNA flow increase throughout the weeks in flat graph
weekly_group %>% group_by(Week) %>% ggplot(aes(x = Week, y = percent, color=Year)) +
  geom_point() +
  labs(x = "Week number", 
       y = "Observed increase in RNA flow (percentage)",
       title = "Increase of RNA flow observed on weeks during the year (flat)") +
  geom_vline(xintercept = 10, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 23, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 36, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 49, linetype="dotted", color = "blue") +
  geom_smooth(method = "lm", se = FALSE)

# Plotting percentage of RNA flow increase throughout the seasons
weekly_group %>% ggplot(aes(x = Week, y = percent, color=Year)) + 
  geom_point() +
  labs(x = "Week number", 
       y = "Observed increase in RNA flow (percentage)",
       title = "Increase of RNA flow observed (seasonal correlation)") +
  geom_smooth(aes(group=season), method="lm", show.legend = TRUE) +
  geom_vline(xintercept = 10, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 23, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 36, linetype="dotted", color = "blue") +
  geom_vline(xintercept = 49, linetype="dotted", color = "blue") 

# Plotting spread of RNA flow increase percentage over seasons
weekly_group %>% ggplot(aes(x = season, y = percent, color=Year)) + 
  geom_point() +
  labs(x = "Season", 
       y = "Observed increase in RNA flow (spread)",
       title = "Spread of RNA flow increase observed") 


# Fit regression model
model_02 <- lm(sd ~ season_num, data = weekly_group)

# Get regression table
get_regression_table(model_02)

# Making null distribution
null_dist_02 <- weekly_group %>% 
  specify(formula = sd ~ season_num) %>% 
  hypothesize(null = "independence") %>% 
  generate(reps = 1000, type = "permute") %>% 
  calculate(stat = "correlation")

# Observation difference proportion
obp_02  <- weekly_group %>% 
  specify(formula = sd ~ season_num) %>%
  calculate(stat = "correlation")

# Visualizing null distribution
visualize(null_dist_02, bins = 20) + 
  shade_p_value(obs_stat = obp_02, direction = "both")


##########################################


