********************************************************************************
* APPENDIX ROBUSTNESS  —  monetary-policy specifications
********************************************************************************
* Input : Data\monetary_policy_induced_position.csv  and  ..._country.csv
* Produces: Appendix Tables A1 (expanded sample), A2 (placebo), A3 (orthogonality), A6 (excl. CTD)

********************************************************************************
* APPENDIX TABLE A2 — Placebo (shock dates shifted 15 trading days)
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)

* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.placebo_shock duration bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.placebo_shock duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)


* Constraining regime
reghdfe delta_y c.log_hf_intensity##c.placebo_shock duration bid_ask_spread ctd_flag ///
    if (placebo_shock > 0 & hf_intensity_long > 0) ///
 | (placebo_shock < 0 & hf_intensity_short > 0) ///
 | (placebo_shock == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.placebo_shock duration bid_ask_spread ctd_flag ///
    if (placebo_shock > 0 & hf_intensity_short > 0) ///
    | (placebo_shock < 0 & hf_intensity_long > 0) ///
	| (placebo_shock == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

********************************************************************************
* APPENDIX TABLE A6 — Excluding CTD bonds
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

keep if ctd_flag == 0

gen log_hf_intensity = log(1 + hf_intensity_pre)


* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread, absorb(duration_match isin) vce(cluster business_date isin)

reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ///
    if (ois_2y > 0 & hf_intensity_long > 0) ///
 | (ois_2y < 0 & hf_intensity_short > 0) ///
 | (ois_2y == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ///
    if (ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0) ///
	| (ois_2y == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

********************************************************************************
* APPENDIX TABLE A1 — Expanded sovereign sample (DE, IT, FR, ES)
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position_country.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)


* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)

reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_long > 0) ///
 | (ois_2y < 0 & hf_intensity_short > 0) ///
 | (ois_2y == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0) ///
	| (ois_2y == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

********************************************************************************
* APPENDIX TABLE A3 — Orthogonality of HF positioning to the MP surprise
********************************************************************************

* Orthogonality of positions
* 1. Import the data
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear

* 2. Convert to Stata date
gen date_num = date(business_date, "YMD")
format date_num %td

* 3. Collapse to daily market-level panel
collapse (mean) ois_2y (sum) net_pos, by(date_num)

* 4. Sort by date and create a business-day index
sort date_num
gen bday = _n

* 5. Set time series with business-day frequency
tsset bday

* 6. Create lagged positioning using the full business-day panel
gen lag_net_pos = L.net_pos

* 7. Restrict to ECB meeting days and test orthogonality
keep if ois_2y != 0
reg ois_2y lag_net_pos, robust
