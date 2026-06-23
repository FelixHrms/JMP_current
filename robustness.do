********MON POL

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

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

	
	
	
	
	
********WITHOUT CTD

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

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
	
	
	
********ONLY CTD

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

keep if ctd_flag == 1


* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.hf_intensity_pre##c.ois_2y bid_ask_spread, absorb(duration_match isin) vce(cluster business_date isin)

reghdfe delta_y c.hf_intensity_pre##c.ois_2y bid_ask_spread ///
    if (ois_2y > 0 & hf_intensity_long > 0) ///
 | (ois_2y < 0 & hf_intensity_short > 0) ///
 | (ois_2y == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.hf_intensity_pre##c.ois_2y bid_ask_spread ///
    if (ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0) ///
	| (ois_2y == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)
	
	
	
	
	
	
********COUNTRIES

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position_country.csv", clear

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

	
	
	
	
* Orthogonality of positions
* 1. Import the data
import delimited "C:\Users\hermesf\Projects\JobMarket\Empirics\monetary_policy_induced_position.csv", clear

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
	
	
	
	
	
* shock thresholds
* 1. Import the data
import delimited "C:\Users\hermesf\Projects\JobMarket\Empirics\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

* Shock terciles by absolute magnitude
gen abs_shock = abs(ois_2y)
xtile shock_tercile = abs_shock if abs_shock > 0, nq(3)
replace shock_tercile = 0 if abs_shock == 0

gen shock_T1 = mp_pm * (shock_tercile == 1)
gen shock_T2 = mp_pm * (shock_tercile == 2)
gen shock_T3 = mp_pm * (shock_tercile == 3)

* Pooled
reghdfe delta_y c.hf_intensity_pre##c.shock_T1 c.hf_intensity_pre##c.shock_T2 c.hf_intensity_pre##c.shock_T3 ///
    c.hf_intensity_pre bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test c.hf_intensity_pre#c.shock_T1 = c.hf_intensity_pre#c.shock_T3

* Constraining regime
reghdfe delta_y c.hf_intensity_pre##c.shock_T1 c.hf_intensity_pre##c.shock_T2 c.hf_intensity_pre##c.shock_T3 ///
    c.hf_intensity_pre bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_long > 0) ///
 | (ois_2y < 0 & hf_intensity_short > 0) ///
 | (ois_2y == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)
test c.hf_intensity_pre#c.shock_T1 = c.hf_intensity_pre#c.shock_T3

* Relaxing regime
reghdfe delta_y c.hf_intensity_pre##c.shock_T1 c.hf_intensity_pre##c.shock_T2 c.hf_intensity_pre##c.shock_T3 ///
    c.hf_intensity_pre bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0) ///
	| (ois_2y == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)
test c.hf_intensity_pre#c.shock_T1 = c.hf_intensity_pre#c.shock_T3
	
	
summarize abs_shock if abs_shock > 0, detail	
local shock_cutoff = r(p50)
display "Using cutoff: `shock_cutoff' bps"

* Small vs large shock indicators
gen small_shock = ois_2y * (abs_shock > 0 & abs_shock <= 10)
gen large_shock = ois_2y * (abs_shock > 10)

* Constraining regime only
reghdfe delta_y c.hf_intensity_pre##c.small_shock c.hf_intensity_pre##c.large_shock ///
    c.hf_intensity_pre bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_long > 0) ///
 | (ois_2y < 0 & hf_intensity_short > 0) ///
 | (ois_2y == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

test c.hf_intensity_pre#c.small_shock = c.hf_intensity_pre#c.large_shock
	
	
**************USING OIS


********MON POL

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date


* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.ois_2y residual_bond_maturity bid_ask_spread ctd_flag, absorb(benchmark_date isin) vce(cluster business_date isin)




*2.2 intensity
clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date

reghdfe delta_y c.hf_intensity_pre##c.ois_2y residual_bond_maturity bid_ask_spread ctd_flag, absorb(benchmark_date isin) vce(cluster business_date isin)




* 3. Positive and negative shocks
clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date

reghdfe delta_y c.hf_intensity_pre##c.ois_2y residual_bond_maturity bid_ask_spread ctd_flag if shock >= 0, absorb(benchmark_date isin) vce(cluster business_date isin)

reghdfe delta_y c.hf_intensity_pre##c.ois_2y residual_bond_maturity bid_ask_spread ctd_flag if shock <= 0, absorb(benchmark_date isin) vce(cluster business_date isin)

	



* 4. Including positioning
clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date

reghdfe delta_y ///
    c.hf_intensity_long##c.ois_2y ///
    c.hf_intensity_short##c.ois_2y ///
    residual_bond_maturity bid_ask_spread ctd_flag ///
	if shock >= 0, ///
    absorb(benchmark_date isin) vce(cluster business_date isin)
	
reghdfe delta_y ///
    c.hf_intensity_long##c.ois_2y ///
    c.hf_intensity_short##c.ois_2y ///
    residual_bond_maturity bid_ask_spread ctd_flag ///
	if shock <= 0, ///
    absorb(benchmark_date isin) vce(cluster business_date isin)

	

	

* 5. Core-periphery
reghdfe delta_y ///
    c.hf_intensity_long##c.ois_2y##i.col_cntr ///
    c.hf_intensity_short##c.ois_2y##i.col_cntr ///
    residual_bond_maturity bid_ask_spread ctd_flag ///
	if shock >= 0, ///
    absorb(benchmark_date isin) vce(cluster business_date isin)
	
reghdfe delta_y ///
    c.hf_intensity_long##c.ois_2y##i.col_cntr ///
    c.hf_intensity_short##c.ois_2y##i.col_cntr ///
    residual_bond_maturity bid_ask_spread ctd_flag ///
	if shock <= 0, ///
    absorb(benchmark_date isin) vce(cluster business_date isin)
	





	
* Volatility old
********MON POL

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen benchmark_date = series + "_" + business_date
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country


* Encode ISIN for panel operations
encode isin, gen(isin_num)

* Sort and set panel
sort isin_num business_date
by isin_num: gen t = _n
xtset isin_num t

* Realized volatility: standard deviation of delta_y over prior 20 trading days
by isin_num: gen delta_y_sq = delta_y^2
rangestat (sd) realized_vol = delta_y, by(isin_num) interval(t -20 -1)

sum realized_vol, meanonly
gen realized_vol_dm = realized_vol - r(mean)

reghdfe delta_y i.hf_involved##c.shock##c.realized_vol_dm residual_bond_maturity bid_ask_spread ctd_flag, absorb(isin benchmark_date) vce(cluster business_date isin)



