********************************************************************************
* TAIL-DAY SHOCKS  —  large unscheduled rate moves + amplification regressions
********************************************************************************
* Input : Data\release_shocks.csv   (daily OIS + ecb_day flags, from notebook)
*         Data\macro_shock.dta      (release-explained component, Section 1 of
*                                    release_shocks.do)
*         Data\vix.csv              (V2X, as in make_cds_shocks.do)
*         Data\monetary_policy_induced_position.csv   (bond panel)
* Output: Data\tail_shock.dta / .csv + amplification table (binary, intensity,
*         constraining, relaxing) + orthogonality test + narrative day list
*
* Construction mirrors make_cds_shocks.do, with ONE deviation: the series
* entering the residualization is the UNEXPLAINED daily OIS change
* u = d_ois2y_bp - macro_shock, i.e. net of the release-explained component
* (and ECB days carry macro_shock = . so they drop out mechanically). Tail
* days are therefore large UNSCHEDULED rate moves by construction - no
* double-counting with the release laboratory, no overlap with the MP one.
* Run each section top-to-bottom in one go (Section 1 uses preserve/tempfile).
********************************************************************************

clear all

********************************************************************************
* 1. Build the tail shock
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\release_shocks.csv", clear
keep date d_ois2y_bp ecb_day n_releases
rename date business_date
merge 1:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.dta", keep(master match) nogen

gen ddate = date(business_date, "YMD")
format ddate %td
sort ddate

* V2X (lagged predictor)
preserve
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\vix.csv", clear
gen ddate = date(date, "DMY")
format ddate %td
drop date
rename v2tx v2x
gen dv2x = v2x - v2x[_n-1]
keep ddate dv2x
tempfile v2x
save `v2x'
restore
merge 1:1 ddate using `v2x', keep(master match) nogen

* HF positioning (lagged predictor): aggregate net position across the panel
preserve
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
collapse (sum) net_pos, by(business_date)
rename net_pos hf_net
tempfile hf
save `hf'
restore
merge 1:1 business_date using `hf', keep(master match) nogen
sort ddate

* unexplained daily OIS change (missing on ECB days by construction)
gen u = d_ois2y_bp - macro_shock

gen L_u    = u[_n-1]
gen L_dv2x = dv2x[_n-1]
gen L_hf   = hf_net[_n-1] / 1e9          // EUR bn
gen gap    = ddate - ddate[_n-1]

* Residualization
reg u L_u L_dv2x L_hf
predict tail_resid, residuals
replace tail_resid = . if gap > 5        // exclude changes spanning > a long weekend

* burn-in guard
gen tindex = _n
replace tail_resid = . if tindex <= 30

*--- Raw-threshold shock definition (2/98, as in make_cds_shocks.do) ---
_pctile tail_resid, p(2 98)
gen tail_day = (tail_resid < r(r1) | tail_resid > r(r2)) if !missing(tail_resid)

*--- Purge monetary-event overlap (ECB day and adjacent days) ---
gen byte ecb_window = ecb_day
replace ecb_window = 1 if ecb_day[_n-1] == 1 | ecb_day[_n+1] == 1
replace tail_day = . if ecb_window == 1

gen tail_shock = 0 if tail_day == 0
replace tail_shock = tail_resid if tail_day == 1

* narrative validation list: every selected day, largest first ->
* appendix table mapping each tail day to its event (rule -> narrative,
* never the reverse; exclusions only by the ex-ante rules above)
count if tail_day == 1
gsort -tail_day ddate
list business_date tail_resid d_ois2y_bp macro_shock if tail_day == 1, noobs clean

sort ddate
keep business_date tail_shock
export delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\tail_shock.csv", replace
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\tail_shock.dta", replace

********************************************************************************
* 2. Merge into the bond panel + amplification regressions
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\tail_shock.dta", keep(match) nogen

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)

* 2.1 Baseline regression
reghdfe delta_y i.hf_involved##c.tail_shock duration bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.tail_shock duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)


* Constraining regime
reghdfe delta_y c.log_hf_intensity##c.tail_shock duration bid_ask_spread ctd_flag ///
    if (tail_shock > 0 & tail_shock < . & hf_intensity_long > 0) ///
 | (tail_shock < 0 & hf_intensity_short > 0) ///
 | (tail_shock == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.tail_shock duration bid_ask_spread ctd_flag ///
    if (tail_shock > 0 & tail_shock < . & hf_intensity_short > 0) ///
    | (tail_shock < 0 & hf_intensity_long > 0) ///
	| (tail_shock == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

********************************************************************************
* 3. Orthogonality of HF positioning to the tail shock
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\tail_shock.dta", keep(match) nogen

* 2. Convert to Stata date
gen date_num = date(business_date, "YMD")
format date_num %td

* 3. Collapse to daily market-level panel
collapse (mean) tail_shock (sum) net_pos, by(date_num)

* 4. Sort by date and create a business-day index
sort date_num
gen bday = _n

* 5. Set time series with business-day frequency
tsset bday

* 6. Create lagged positioning using the full business-day panel
gen lag_net_pos = L.net_pos

* 7. Restrict to tail days and test orthogonality
keep if tail_shock != 0 & !missing(tail_shock)
reg tail_shock lag_net_pos, robust
