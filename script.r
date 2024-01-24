library(readr)
library(tidyverse)
library(skimr)
setwd("/Applications/Resit Programming with R")
sewerdata <- read.csv2('COVID-19_SewerWaterData_MunicipalitiesWeek.csv')
municipalities2022 <- read.csv2('Municipalities alphabetically 2022.csv')

sewerdata_2 <- sewerdata %>% 
  group_by(Region_name, Year) %>% 
  summarise(Avg = mean(RNA_flow_per_100000_weeklymean)) %>% 
  arrange(-Avg)

population_density <- read.csv2('Regionale_kerncijfers_Nederland_23012024_192144.csv')

glimpse(population_density)

names(population_density)[names(population_density) == "Regio.s"] <- "Region_name"
names(population_density)[names(population_density) == "Bevolking.Bevolkingssamenstelling.op.1.januari.Totale.bevolking..aantal."] <- "Population"
names(population_density)[names(population_density) == "Bevolking.Bevolkingssamenstelling.op.1.januari.Bevolkingsdichtheid..aantal.inwoners.per.km.."] <- "Population_Density"
names(population_density)[names(population_density) == "Perioden"] <- "Year"

population_density %>% 
  select(Region_name, Population, 

joined_data <- inner_join(sewerdata_2, population_density, by = c("Region_name", "Year"))

df1 <- municipalities2022 %>% rename(Region_name = MunicipalName)
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
