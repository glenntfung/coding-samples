library(haven)
library(tidyverse)
library(zoo)

rm(list = ls())

setwd("C:/Users/fengz/Desktop")

set.seed(1101213126) 

wind <- read_dta('append/windinfo.dta')
colnames(wind)[colnames(wind) == "industry"] <- "Industry"
wind$Industry <- as.character(wind$Industry)
wind$Symbol <- as.factor(wind$Symbol)
wind <- data.frame(wind)

statement <- read_dta('tr/statement_time.dta')
statement <- subset(statement, select = c(Symbol, AccouPeri, ActRelDate))
colnames(statement)[colnames(statement) == "AccouPeri"] <- "AccountPeriod"
colnames(statement)[colnames(statement) == "ActRelDate"] <- "ActualReportDate"
statement$ActualReportDate <- as.Date(statement$ActualReportDate)
statement$AccountPeriod <- as.Date(statement$AccountPeriod)
statement$Symbol <- as.character(statement$Symbol)
statement <- data.frame(statement)

calender <- read_dta('append/calendar.dta')
calender <- subset(calender, select = c(Clddt, State))
colnames(calender)[colnames(calender) == "Clddt"] <- "TradingDate"
calender$TradingDate <- as.Date(calender$TradingDate)
calender$State <- as.factor(calender$State)
calender <- distinct(calender, TradingDate, .keep_all = TRUE)
calender <- data.frame(calender)

# return data
return <- read_dta('append/stockreturn_alld.dta')
return <- subset(return, select = c(Trddt, Symbol, Dretwd, Dretnd))
colnames(return)[colnames(return) == "Trddt"] <- "TradingDate"
colnames(return)[colnames(return) == "Dretwd"] <- "ReturnWCD"
colnames(return)[colnames(return) == "Dretnd"] <- "ReturnNCD"
return$TradingDate <- as.Date(return$TradingDate)
return$TradingMonth <- format(as.Date(return$TradingDate), "%Y-%m")
return$ReturnWCD <- as.numeric(return$ReturnWCD)
return$ReturnNCD <- as.numeric(return$ReturnNCD)
return$Symbol <- as.character(return$Symbol)
return <- data.frame(return)

return <- return[!(return$TradingDate < as.Date("2004-01-01") | 
                     return$TradingDate > as.Date("2012-12-31")), ]

factors <- read_dta('append/4fm.dta')
factors <- filter(factors, MarkettypeID == "P9715")
factors <- subset(factors, select= c(TradingMonth, RiskPremium1, SMB1, HML1, UMD1))
colnames(factors)[colnames(factors) == "RiskPremium1"] <- "MKT"
colnames(factors)[colnames(factors) == "SMB1"] <- "SMB"
colnames(factors)[colnames(factors) == "HML1"] <- "HML"
colnames(factors)[colnames(factors) == "UMD1"] <- "UMD"
factors$MKT <- as.numeric(factors$MKT)
factors$SMB <- as.numeric(factors$SMB)
factors$HML <- as.numeric(factors$HML)
factors$UMD <- as.numeric(factors$UMD)
factors <- data.frame(factors)

rfrate <- read_dta('append/riskfree_rate.dta')
rfrate <- subset(rfrate, select = c(TradingDate, InterestRateDaily))
rfrate$TradingDate <- as.Date(rfrate$TradingDate)
rfrate$InterestRateDaily <- as.numeric(rfrate$InterestRateDaily)
colnames(rfrate)[colnames(rfrate) == "InterestRateDaily"] <- "Rf"
rfrate <- data.frame(rfrate)


replication.statement <- 
  statement[!(statement$AccountPeriod < as.Date("2005-01-01") | 
                statement$AccountPeriod > as.Date("2011-12-31")), ]


replication.statement <- spread(replication.statement, AccountPeriod, 
                                ActualReportDate)

replication.statement <- na.omit(replication.statement)

replication.statement <- merge(replication.statement, wind, by = "Symbol")

replication.statement <- replication.statement[replication.statement$Industry != 
                                                 "Telecommunications", ]

temp <- subset(calender, select = c(TradingDate, Daywk, State))
temp <- temp[!duplicated(temp$TradingDate),]
return <- merge(return, temp, by = c('TradingDate'), all.x = TRUE)
return <- filter(return, State != "C")
return <- subset(return, select = -c(Daywk, State))
rm(temp)

return <- merge(return, factors, by = "TradingMonth", all.x = TRUE)
return <- merge(return, rfrate, by = "TradingDate", all.x = TRUE)

return$RWRf <- return$ReturnWCD - return$Rf
return$RNRf <- return$ReturnNCD - return$Rf


# Function to calculate abnormal return using rolling window regression for each stock
calculate_abnormal_return <- function(stock_data) {
  abnormal_returns <- c()
  unique_dates <- unique(stock_data$TradingDate)
  
  for (i in 1:length(unique_dates)) {
    current_date <- unique_dates[i]
    past_year_data <- subset(stock_data, TradingDate >= (current_date - 250) & TradingDate <= current_date)
    
    if (nrow(past_year_data) >= 100) {  # Minimum data points required for regression
      model <- lm(RWRf ~ MKT + SMB + HML + UMD, data = past_year_data)
      abnormal_return <- residuals(model)
      abnormal_returns <- c(abnormal_returns, tail(abnormal_return, 1))
    } else {
      abnormal_returns <- c(abnormal_returns, NA)
    }
  }
  
  return(abnormal_returns)
}

# Calculate abnormal returns for each stock
unique_stocks <- unique(return$Symbol)
abnormal_returns_matrix <- matrix(NA, nrow = length(unique_stocks), ncol = length(unique(return$TradingDate)))
rownames(abnormal_returns_matrix) <- unique_stocks
colnames(abnormal_returns_matrix) <- unique(return$TradingDate)

for (stock in unique_stocks) {
  stock_data <- subset(return, Symbol == stock)
  stock_abnormal_returns <- calculate_abnormal_return(stock_data)
  abnormal_returns_matrix[stock, match(unique(stock_data$TradingDate), colnames(abnormal_returns_matrix))] <- stock_abnormal_returns
}

# Convert matrix to a data frame
abnormal_returns_df <- as.data.frame(t(abnormal_returns_matrix))
abnormal_returns_df$TradingDate <- as.Date(as.numeric(rownames(abnormal_returns_df)), origin = "1970-01-01")

# Melt the data frame to long format
library(reshape2)  # Make sure 'reshape2' package is installed
return1 <- melt(abnormal_returns_df, id.vars = "TradingDate", variable.name = "Symbol", value.name = "AR")

# Filter 'data' to include only combinations present in the melted dataframe
filtered_data <- subset(data, stock_symbol %in% unique(abnormal_returns_df$stock_symbol) & date %in% unique(abnormal_returns_df$date))

# Melt the filtered data frame to long format
library(reshape2)  # Make sure 'reshape2' package is installed
final_abnormal_returns_df <- melt(abnormal_returns_df, id.vars = "date", variable.name = "stock_symbol", value.name = "abnormal_return")

# Filter melted data based on filtered 'data'
final_abnormal_returns_df <- final_abnormal_returns_df[final_abnormal_returns_df$stock_symbol %in% unique(filtered_data$stock_symbol) & final_abnormal_returns_df$date %in% unique(filtered_data$date), ]

return <- return %>% drop_na(AR)

return <- subset(return, select = -c(bm.rate))
write_dta(
  return,
  "return.dta"
)

return <- arrange(return, Symbol, TradingDate)

return <- return %>% 
  arrange(Symbol, TradingDate) %>%
  group_by(Symbol) %>%
  mutate(bef = rollapply(AR, 16, sum, align = "right", fill = NA)) %>%
  ungroup()

return <- return %>% 
  arrange(Symbol, TradingDate) %>%
  group_by(Symbol) %>%
  mutate(aft = rollapply(AR, 6, sum, align = "left", fill = NA)) %>%
  ungroup()

return$carr <- (return$bef - return$AR) / 
  (return$bef + return$aft - 2 * return$AR) 

return <- subset(return, select = -c(bef, aft))

return$bm.rate <- rnorm(nrow(return))

replication.statement <- gather(replication.statement, AccountPeriod, 
                                ActualReportDate, "2005-03-31":"2011-12-31", 
                                na.rm = TRUE, factor_key=TRUE)

metricdays <- rep(0, length(replication.statement$ActualReportDate))
for(i in 1:length(replication.statement$ActualReportDate)){
  dif <- replication.statement$ActualReportDate[i] - 
    filter(return, State == "O")$TradingDate
  dif <- ifelse(dif <= 0, dif, NA)
  ind  <- which.max(dif)
  metricdays[i] <- filter(calender, State == "O")$TradingDate[ind]
}
metricdays <- as.Date(metricdays, origin = "1970-01-01")

library(dplyr)

replication.statement$ActualReportDate <- as.Date(replication.statement$ActualReportDate)
return$TradingDate <- as.Date(return$TradingDate)

# Initialize an empty vector to store results
nearest_future_date1_list <- vector("list", length = nrow(replication.statement))

# Loop through each row in df2
for (i in 1:nrow(replication.statement)) {
  current_symbol <- replication.statement$Symbol[i]
  current_date2 <- replication.statement$ActualReportDate[i]
  
  # Check if date2 is in date1 for the same symbol
  date_in_date1 <- current_date2 %in% return$TradingDate[return$Symbol == current_symbol]
  
  if (!date_in_date1) {
    # Subset df1 to find matching symbols and future dates
    symbol_matches <- return$Symbol == current_symbol
    future_dates <- return$TradingDate[symbol_matches & return$TradingDate > current_date2]
    
    # Find the nearest future date1
    if (length(future_dates) > 0) {
      nearest_future_date1 <- min(future_dates)
      nearest_future_date1_list[[i]] <- nearest_future_date1
    } else {
      nearest_future_date1_list[[i]] <- NA
    }
  } else {
    # If date2 is in date1, retain the same date2 value
    nearest_future_date1_list[[i]] <- current_date2
  }
}

# Add the nearest_future_date1 to df2
replication.statement$TradingDate <- unlist(nearest_future_date1_list)
replication.statement$TradingDate <- as.Date(replication.statement$TradingDate)


replication.statement$TradingDate <- metricdays

rm(metricdays, dif, i, ind)

carr.matrix <- merge(replication.statement, return, 
                     by = c('TradingDate', 'Symbol'), all.x = TRUE)
carr.matrix$bm.rate[is.na(carr.matrix$carr)] <- NA
carr.matrix <- carr.matrix %>% 
  arrange(AccountPeriod, Industry, -carr) %>%
  group_by(AccountPeriod, Industry) %>%
  mutate(real.rank = rank(-carr, ties.method = "first")) %>% 
  ungroup()
carr.matrix$real.rank[is.na(carr.matrix$carr)] <- NA

carr.matrix <- carr.matrix %>% 
  arrange(AccountPeriod, Industry, -bm.rate) %>%
  group_by(AccountPeriod, Industry) %>%
  mutate(bm.rank = rank(-bm.rate, ties.method = "first")) %>%
  ungroup()
carr.matrix$bm.rank[is.na(carr.matrix$carr)] <- NA

carr.matrix.real <- subset(carr.matrix, select = c(AccountPeriod, Symbol, 
                                                   real.rank, Industry))
carr.matrix.bm <- subset(carr.matrix, select = c(AccountPeriod, Symbol, 
                                                 bm.rank, Industry))

carr.matrix.real <- spread(carr.matrix.real, AccountPeriod, real.rank)
carr.matrix.bm <- spread(carr.matrix.bm, AccountPeriod, bm.rank)

carr.matrix.real <- carr.matrix.real %>% 
  mutate(sum = rowSums(pick("2005-03-31":"2011-12-31"), na.rm = TRUE))
carr.matrix.bm <- carr.matrix.bm %>% 
  mutate(sum = rowSums(pick("2005-03-31":"2011-12-31"), na.rm = TRUE))

cut <- 0.15

carr.matrix.real <- carr.matrix.real %>% 
  arrange(Industry) %>%
  group_by(Industry) %>%
  mutate(cut1 = ceiling(n() * cut) ) %>%
  mutate(cut2 = floor(n() * (1 - cut))) %>%
  ungroup()
carr.matrix.bm <- carr.matrix.bm %>% 
  arrange(Industry) %>%
  group_by(Industry) %>%
  mutate(cut1 = ceiling(n() * cut) ) %>%
  mutate(cut2 = floor(n() * (1 - cut))) %>%
  ungroup()

carr.top.rl <- carr.matrix.real %>%
  arrange(Industry, sum) %>%
  group_by(Industry) %>%
  mutate(rank = rank(sum, ties.method = "first")) %>%
  filter(rank <= cut1) %>%
  ungroup()

carr.top.bm <- carr.matrix.bm %>% 
  arrange(Industry, sum) %>%
  group_by(Industry) %>%
  mutate(rank = rank(sum, ties.method = "first")) %>%
  filter(rank <= cut1) %>%
  ungroup()

carr.bot.rl <- carr.matrix.real %>%
  arrange(Industry, sum) %>%
  group_by(Industry) %>%
  mutate(rank = rank(sum, ties.method = "first")) %>%
  filter(rank >= cut2) %>%
  ungroup()

carr.bot.bm <- carr.matrix.bm %>% 
  arrange(Industry, sum) %>%
  group_by(Industry) %>%
  mutate(rank = rank(sum, ties.method = "first")) %>%
  filter(rank >= cut2) %>%
  ungroup()

carr.top.rl <- gather(carr.top.rl, AccountPeriod, ranks, 
                      "2005-03-31":"2011-12-31", na.rm = TRUE, factor_key=TRUE)

carr.top.bm <- gather(carr.top.bm, AccountPeriod, ranks, 
                      "2005-03-31":"2011-12-31", na.rm = TRUE, factor_key=TRUE)


carr.bot.rl <- gather(carr.bot.rl, AccountPeriod, ranks, 
                      "2005-03-31":"2011-12-31", na.rm = TRUE, factor_key=TRUE)

carr.bot.bm <- gather(carr.bot.bm, AccountPeriod, ranks, 
                      "2005-03-31":"2011-12-31", na.rm = TRUE, factor_key=TRUE)

indus <- c("Consumer Discretionary", "Consumer Staples", "Energy", 
           "Financials", "Health Care", "Industrials", 
           "Information Technology", "Materials", "Real Estate", 
           "Utilities")

carrtb <- data.frame(matrix(nrow = 2, ncol = 10))
colnames(carrtb) <- indus
rownames(carrtb) <- c("Test Stat.", "p-Value")
carrtoprb <- carrtb
carrbotrb <- carrtb

for (i in indus) {
  carrtoprb[2, colnames(carrtoprb) == i] <- 
    ks.boot(as.numeric(unlist(filter(carr.top.bm, Industry == i)[,8])), 
            as.numeric(unlist(filter(carr.top.rl, 
                                     Industry == i)[,8])),nboots = 10000)$ks.boot.pvalue
}

for (i in indus) {
  carrbotrb[2, colnames(carrtoprb) == i] <- 
    ks.boot(as.numeric(unlist(filter(carr.bot.bm, Industry == i)[,8])), 
            as.numeric(unlist(filter(carr.bot.rl, 
                                     Industry == i)[,8])),nboots = 10000)$ks.boot.pvalue
}

round(carrtoprb, 4)
round(carrbotrb, 4)

for (i in indus) {
  carrtb[2, colnames(carrtb) == i] <- 
    ks.boot(as.numeric(unlist(filter(carr.bot.rl, Industry == i)[,8])), 
            as.numeric(unlist(filter(carr.top.rl, 
                                     Industry == i)[,8])),nboots = 10000)$ks.boot.pvalue
}

for (i in indus) {
  p <- ggplot() + 
    geom_line(data = filter(carr.top.rl, Industry == i), 
              aes(ranks, color = "Real top"), 
              stat = "ecdf", pad = FALSE) + 
    geom_line(data = filter(carr.top.bm, Industry == i), 
              aes(ranks, color = "Benchmark top"), 
              stat = "ecdf", pad = FALSE) + 
    geom_line(data = filter(carr.bot.rl, Industry == i), 
              aes(ranks, color = "Real bottom"), 
              stat = "ecdf", pad = FALSE) + 
    geom_line(data = filter(carr.bot.bm, Industry == i), 
              aes(ranks, color = "Benchmark bottom"), 
              stat = "ecdf", pad = FALSE) + 
    xlab("Rank") + 
    ylab("Percentage") + 
    labs(title="") + 
    scale_colour_manual("", 
                        values = c("Real top" = "red", "Benchmark top" = "green", 
                                   "Real bottom" = "blue", 
                                   "Benchmark bottom" = "black")) +
    theme_minimal()
  ggsave(p, file=paste0("graph/car_", i,".png"), 
         width = 16, height = 11, units = "cm")
}
