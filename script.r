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

# Loading data files 
sewerdata <- read.csv2('Datafiles/COVID-19_SewerWaterData_MunicipalitiesWeek.csv')
municipalities <- read.csv2('Datafiles/municipalities_alphabetically_2022.csv')
population_density <- read.csv2('Datafiles/Regionale_kerncijfers_Nederland_23012024_192144.csv')
public_holidays <- read.csv2('Datafiles/public_holidays.csv')

# Adjusting column names
names(sewerdata)[8:9] <- c("MunicipalName","RNA_flow")
colnames(population_density) <- c("Year", "MunicipalName", "Population", "PopulationDensity")
names(public_holidays)[1] <- "PublicHoliday"

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

# Understanding number of municipalities number in each province
mun_per_province <- municipalities %>% 
  group_by(ProvincialName) %>% 
  summarise(count = n()) %>% 
  arrange(desc(count)) 
mun_per_province

# TODO

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

# Adding week number and year to each public holiday
public_holidays$Week <- lubridate::week(dmy(public_holidays$Date))
public_holidays$Year <- lubridate::year(dmy(public_holidays$Date))

# Making a distinct list of week-year pairs
public_holidays_distinct <- distinct(public_holidays, Week, Year, .keep_all = TRUE)
public_holidays_distinct$Date <- NULL

# Exploring holidays distribution over the weeks
public_holidays %>% ggplot(aes(x = Week, y = Year)) +
  geom_jitter(alpha = 0.5)

# Clustering spring holidays
Q <- quantile(public_holidays$Week, probs=c(.25, .75), na.rm = FALSE)
iqr <- IQR(public_holidays$Week)
spring_holidays <- subset(public_holidays, public_holidays$Week > (Q[1] - 1.5*iqr) & public_holidays$Week < (Q[2]+1.5*iqr))


# Order sewer data by municipality, year and week
sewer_ordered <- sewerdata[with(sewerdata, order(MunicipalName, Year, Week)), ]

# Calculating the RNA flow delta between weeks
sewer_ordered$delta <- with(sewer_ordered,
                            ifelse(MunicipalName == lag(MunicipalName), 
                                   RNA_flow - lag(RNA_flow), NA))

# Grouping sewer RNA flow by weeks and summing up deltas across all municipalities
weekly_group <- sewer_ordered %>% filter(Year > 2020) %>% 
  group_by(Week) %>%
  summarise(obs = n(),
            mean_RNA = mean(RNA_flow), 
            max_RNA = max(RNA_flow),
            min_RNA = min(RNA_flow),
            sum_delta = sum(delta)) %>%
  arrange(desc(mean_RNA))

# Plotting delta sum of RNA flow throughout the weeks 
weekly_group %>% ggplot(aes(x = Week, y = sum_delta)) +
  geom_jitter(alpha = 0.5) +
  labs(x = "Week number", 
       y = "Mean RNA flow",
       title = "Relation of delta RNA flow sum to weeks during the year") +
  geom_vline(data = spring_holidays, aes(xintercept = Week), linetype="dotted", color = "blue") +
  geom_smooth(method = "lm", se = FALSE)

# Sub-setting a spring slice of and summing up deltas across all municipalities
spring_slice <- sewer_ordered %>% subset(Week %in% spring_holidays$Week) %>%
  group_by(Week) %>%
  summarise(obs = n(),
            mean_RNA = mean(RNA_flow), 
            max_RNA = max(RNA_flow),
            min_RNA = min(RNA_flow),
            sum_delta = sum(delta)) %>%
  arrange(desc(mean_RNA))

# Plotting delta sum of RNA flow throughout the spring slice 
spring_slice %>% ggplot(aes(x = Week, y = sum_delta)) +
  geom_jitter(alpha = 0.5) +
  labs(x = "Week number", 
       y = "Mean RNA flow",
       title = "Relation of delta RNA flow sum to weeks during the year") +
  geom_smooth(method = "lm", se = FALSE)


# Fit regression model
model_02 <- lm(sum_delta ~ Week, data = spring_slice)

# Get regression table
get_regression_table(model_02)

# Making null distribution
null_dist_02 <- spring_slice %>% 
  specify(formula = sum_delta ~ Week) %>% 
  hypothesize(null = "independence") %>% 
  generate(reps = 1000, type = "permute") %>% 
  calculate(stat = "correlation")


# Observation difference proportion
obp_02  <- spring_slice %>% 
  specify(formula = sum_delta ~ Week) %>%
  calculate(stat = "correlation")

# Visualizing null distribution
visualize(null_dist_02, bins = 20) + 
  shade_p_value(obs_stat = obp_02, direction = "both")


##########################################


# Exploring summary statistics for sewer data
sewer_summary <- sewerdata %>%
  group_by(ProvincialName) %>%
  summarise(
    count = n(),                    # Count of observations
    mean_RNA = mean(RNA_flow),      # Average of RNA flow for the province/year
    median_RNA = median(RNA_flow),  # Median of RNA flow for the province/year
    sd_RNA = sd(RNA_flow)) %>%      # Standard deviation of RNA flow for the province/year
  arrange(desc(mean_RNA))           # highest mean per province at the top

sewer_summary


## Plotting the cumulative RNA flow across within each province over 4 years 

ggplot(sewerdata %>% filter(Year == 2021, Week == 1) , aes(x = as.factor(ProvincialName), y = RNA_flow)) +
  geom_boxplot() +
  labs(title = "RNA flow, week 1 2021",
       x = "Province",
       y = "RNA flow (hundreds of billions)") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

ggplot(population_density %>% filter(Year == 2021) , aes(x = as.factor(ProvincialName), y = PopulationDensity)) +
  geom_boxplot() +
  labs(title = "Population Density 2021",
       x = "Province",
       y = "Density of habitants") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

ggplot(sewerdata %>% filter(Year == 2022, Week == 1) , aes(x = as.factor(ProvincialName), y = RNA_flow)) +
  geom_boxplot() +
  labs(title = "RNA flow, week 37 2021",
       x = "Province",
       y = "RNA flow (hundreds of billions)") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

ggplot(sewerdata %>% filter(Year == 2023, Week == 1) , aes(x = as.factor(ProvincialName), y = RNA_flow)) +
  geom_boxplot() +
  labs(title = "RNA flow, week 37 2022",
       x = "Province",
       y = "RNA flow (hundreds of billions)") +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))



population_summary <- population_density %>%
  group_by(ProvincialName, Year) %>%
  summarise(
    population = sum(Population),  # Median density for province/year
    mean_desity = mean(PopulationDensity),      # Average density for province/year
    sd_desity = sd(Population)) %>%      # Standard deviation density for province/year
  arrange(Year)                          # most observations per municipality at the top

population_summary

#################### OLD SCRIPT ###################################



sewerdata_2 <- sewerdata %>% 
  group_by(Region_name, Year) %>% 
  summarise(Avg = mean(RNA_flow)) %>% 
  arrange(-Avg)



glimpse(population_density)


population_density %>% 
  select(Region_name, Population, joined_data <- inner_join(sewerdata_2, population_density, by = c("Region_name", "Year")))

df1 <- municipalities %>% rename(Region_name = MunicipalName)
sewer_mu <- merge(sewerdata, df1, by = "Region_name")
sewer_mu
glimpse(sewer_mu)
skim(sewer_mu)

num_years <- unique(sewer_mu$Year)
num_years
#How many regions in the dataframe? 
num_regions <- unique(sewer_mu$Region_name)
num_regions

#How many provinces are in the dataframe?
provinces <- unique(sewer_mu$ProvincialName)
provinces

#RNA value per province
agg_data <- sewer_mu %>%
  group_by(ProvincialName) %>%
  summarise(total_RNA = sum(RNA_flow_per_100000_weeklymean, na.rm = TRUE))
agg_data

#skim on 4 variables
sewer_mu %>% select(Region_name, Year, RNA_flow_per_100000_weeklymean,ProvincialName) %>% skim()

#Value of RNA with start date
ggplot(sewer_mu, aes(x= Week, y = RNA_flow_per_100000_weeklymean)) +  
  geom_col() + labs(x = "Start_date", y = "RNA_flow_per_100000_weeklymean", title = "Start Date RNA" )

ggplot(data = agg_data, aes(x= Year, y = total_RNA))
+geom_bar()
+facet_grid(ProvincialName~.)

ggplot(data = agg_data, aes(x= ProvincialName, y = total_RNA)) + geom_col() +labs(x = "ProvincialName", y = "total_RNA", title = "RNA Value per Province")+
  theme(axis.text.x = element_text(angle = 60, hjust =1))+
  facet_grid


#RNA value per province
ggplot(agg_data, aes(x = ProvincialName, y = total_RNA, fill = ProvincialName)) +
  geom_bar(stat = "identity") +
  labs(title = "Total RNA Values by Province",
       x = "ProvincialName",
       y = "total_RNA") +
  theme_minimal()

#Adding year to the dataframe agg_data
agg_data <- sewer_mu %>%
  group_by(ProvincialName, Year) %>%
  summarise(total_RNA = sum(RNA_flow_per_100000_weeklymean, na.rm = TRUE))
agg_data

#Creating a barplot for total RNA values by Province
ggplot(agg_data, aes(x = ProvincialName, y = total_RNA, fill = as.factor(Year))) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Total RNA Values by Province",
       x = "ProvincialName",
       y = "total_RNA",
       fill = "Year") +
  theme_minimal()

#From the barplot we can see that the year with the highest RNA values is 2022 & 2023.

#Adding week to agg_data
agg_data <- sewer_mu %>%
  group_by(ProvincialName, Year, Week) %>%
  summarise(total_RNA = sum(RNA_flow_per_100000_weeklymean, na.rm = TRUE))
agg_data

#In which weeks of top 3 highest provinces are the most RNA values?
max_rna_per_year <- sewerdata %>%
  group_by(Year) %>%
  filter( RNA_flow_per_100000_weeklymean == max(RNA_flow_per_100000_weeklymean, na.rm = TRUE)) %>%
  select(Year, Week, RNA_flow_per_100000_weeklymean)
max_rna_per_year

#Visualize the results using a scatterplot
ggplot(max_rna_per_year, aes(x = Year, y = Week, size = RNA_flow_per_100000_weeklymean )) +
  geom_point() +
  labs(title = "Weeks with Highest RNA Values per Year",
       x = "Year",
       y = "Week",
       size = "RNA_flow_per_100000_weeklymean") +
  theme_minimal()

sewer_mu %>% arrange(Start_date)
         