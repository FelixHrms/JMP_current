********************************************************************************
* DEALER ROBUSTNESS
* Input : Data\monetary_policy_induced_position_dealers.csv  (built by build\build_dealer_panel.ipynb)
* Produces: Table VI (amplification within dealer behavior)
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position_dealers.csv", clear

encode collateral_country, gen(col_cntr)
gen dealer_date = dealer_id + "_" + business_date
gen duration_bin = floor(duration / 2) * 2
gen dealer_date_country = dealer_id + "_" + business_date + "_" + collateral_country
gen dealer_date_duration = dealer_id + "_" + business_date + "_" + string(duration_bin) + "_" + collateral_country


reghdfe delta_y i.hf_involved##c.ois_2y duration bid_ask_spread ctd_flag, absorb(dealer_date isin) vce(cluster dealer_id business_date isin)
reghdfe delta_y i.hf_involved##c.ois_2y duration bid_ask_spread ctd_flag, absorb(dealer_date_country isin) vce(cluster dealer_id business_date isin)
reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread ctd_flag, absorb(dealer_date_duration isin) vce(cluster dealer_id business_date isin)
reghdfe delta_y i.hf_involved##c.ois_2y##c.cds_change_5d bid_ask_spread ctd_flag, absorb(dealer_date_duration isin) vce(cluster dealer_id business_date isin)








