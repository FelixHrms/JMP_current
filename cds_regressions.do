clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Empirics\\cds_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)


* 2. Baseline regression
reghdfe delta_y i.hf_involved##c.cds_shock_raw bid_ask_spread ctd_flag, vce(cluster business_date isin)
reghdfe delta_y i.hf_involved##c.cds_shock_raw bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.cds_shock_raw bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)

reghdfe delta_y c.log_hf_intensity##c.cds_shock_raw bid_ask_spread ctd_flag ///
    if (cds_shock_raw > 0 & hf_intensity_long > 0) ///
 | (cds_shock_raw < 0 & hf_intensity_short > 0) ///
 | (cds_shock_raw == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.cds_shock_raw bid_ask_spread ctd_flag ///
    if (cds_shock_raw > 0 & hf_intensity_short > 0) ///
    | (cds_shock_raw < 0 & hf_intensity_long > 0) ///
	| (cds_shock_raw == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)
	
	

	
* Orthogonality of positions
* 1. Import the data
import delimited "C:\Users\hermesf\Projects\JobMarket\Empirics\cds_induced_position.csv", clear

* 2. Convert to Stata date
gen date_num = date(business_date, "YMD")
format date_num %td

* 3. Collapse to daily market-level panel
collapse (mean) cds_shock_raw (sum) net_pos, by(date_num)

* 4. Sort by date and create a business-day index
sort date_num
gen bday = _n

* 5. Set time series with business-day frequency
tsset bday

* 6. Create lagged positioning using the full business-day panel
gen lag_net_pos = L.net_pos

* 7. Restrict to ECB meeting days and test orthogonality
keep if cds_shock_raw != 0
reg cds_shock_raw lag_net_pos, robust
