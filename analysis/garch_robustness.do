********************************************************************************
* GARCH ROBUSTNESS
* Input : Data\monetary_policy_induced_position.csv  ->  builds Data\garch_panel.dta
* Produces: Table X (amplification on GARCH-standardized yield changes)
********************************************************************************

clear all
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
encode isin, gen(isin_id)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

* Date variable for tsset
gen date_num = date(business_date, "YMD")
format date_num %td

* Sequential business-day index per bond, required for arch
sort isin_id date_num
by isin_id: gen bday_t = _n
tsset isin_id bday_t

* Flag shock days (ois_2y is non-zero on event days, zero otherwise)
gen shock_day = (ois_2y != 0)

* Container for fitted conditional variance
gen sigma2_hat = .

* Loop GARCH(1,1) over bonds with enough non-shock observations
levelsof isin_id, local(bonds)
local nbonds: word count `bonds'
display "Estimating GARCH for `nbonds' bonds..."

quietly {
    foreach b of local bonds {
        count if isin_id == `b' & shock_day == 0 & !missing(delta_y)
        if r(N) >= 250 {
            capture arch delta_y if isin_id == `b' & shock_day == 0, ///
                arch(1) garch(1) vce(robust)
            if _rc == 0 {
                * Predict conditional variance for ALL days of this bond
                capture predict double sig2_tmp if isin_id == `b', variance
                if _rc == 0 {
                    replace sigma2_hat = sig2_tmp if isin_id == `b'
                    drop sig2_tmp
                }
            }
        }
    }
}

gen sigma_hat = sqrt(sigma2_hat)

* Standardised yield change
gen delta_y_std = delta_y / sigma_hat

* Diagnostics
count if missing(sigma_hat)
sum sigma_hat, detail

sum sigma_hat, detail
replace sigma_hat = . if sigma_hat > r(p99)
replace delta_y_std = delta_y / sigma_hat


* After the GARCH loop and sigma_hat / delta_y_std are constructed
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\garch_panel.dta", replace

clear all
use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\garch_panel.dta", clear

* Re-run baseline on standardised LHS
reghdfe delta_y_std i.hf_involved##c.ois_2y, vce(cluster business_date isin)
reghdfe delta_y_std i.hf_involved##c.ois_2y duration bid_ask_spread ctd_flag, vce(cluster business_date isin)
reghdfe delta_y_std i.hf_involved##c.ois_2y duration bid_ask_spread ctd_flag, absorb(business_date isin) vce(cluster business_date isin)
reghdfe delta_y_std i.hf_involved##c.ois_2y bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)

gen log_hf_intensity = log(1 + hf_intensity_pre)

reghdfe delta_y_std i.hf_involved##c.ois_2y bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y_std c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)

reghdfe delta_y_std c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_long > 0) ///
 | (ois_2y < 0 & hf_intensity_short > 0) ///
 | (ois_2y == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y_std c.log_hf_intensity##c.ois_2y bid_ask_spread ctd_flag ///
    if (ois_2y > 0 & hf_intensity_short > 0) ///
    | (ois_2y < 0 & hf_intensity_long > 0) ///
	| (ois_2y == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)


sum sigma_hat