********************************************************************************
* SELECTION & VOLATILITY
* Input : Data\monetary_policy_induced_position.csv
* Produces: Table III (bond volatility & HF presence)  +  Table II (HF bond selection)
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen collateral_date = collateral_country + "_" + business_date
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen abs_delta_y = abs(delta_y)
gen abs_shock = abs(ois_2y)


* --- TABLE III: bond volatility & HF presence (|dy| on HF x |shock|) ---
reghdfe abs_delta_y i.hf_involved##c.abs_shock, vce(cluster business_date isin)
reghdfe abs_delta_y i.hf_involved##c.abs_shock duration bid_ask_spread ctd_flag, vce(cluster business_date isin)
reghdfe abs_delta_y i.hf_involved##c.abs_shock duration bid_ask_spread ctd_flag, absorb(business_date isin) vce(cluster business_date isin)
reghdfe abs_delta_y i.hf_involved##c.abs_shock bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)


* --- TABLE II: HF bond selection (linear probability model of HF involvement) ---
reghdfe hf_involved duration bid_ask_spread amt_issued ctd_flag, vce(cluster business_date isin)
reghdfe hf_involved duration bid_ask_spread amt_issued ctd_flag, absorb(collateral_country) vce(cluster business_date isin)
reghdfe hf_involved duration bid_ask_spread amt_issued ctd_flag, absorb(collateral_date) vce(cluster business_date isin)

