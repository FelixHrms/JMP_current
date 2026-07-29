********************************************************************************
* MACRO-RELEASE SHOCKS  —  first stage + amplification regressions
********************************************************************************
* Input : Data\release_shocks.csv        (built by build_release_shocks.ipynb)
*         Data\release_types_meta.csv    (release-type map: relevance, sigma, n)
*         Data\monetary_policy_induced_position.csv   (bond panel)
* Produces: first-stage gamma table, Data\macro_shock.csv,
*           release-shock amplification table (binary, intensity,
*           constraining regime, relaxing regime) + orthogonality test
********************************************************************************

clear all

********************************************************************************
* 1. First stage: daily 2y OIS change on standardised release surprises
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\release_shocks.csv", clear

* Regressor set: relevance >= 50, >= 10 release days in window, one print per
* simultaneous bundle (flash-CPI trio, GDP QoQ/YoY, retail MoM/YoY, IP MoM/YoY,
* PMI composite = derived from Mfg + Services). Full map: release_types_meta.csv.
* Robustness: replace the list with s_* (fitted value barely moves; individual
* gammas inside bundles are not separately interpretable).
* ECB monetary event days are excluded: those days keep the EA-MPD shock.
* The 38 in-window ecb_day flags must line up with the paper's EA-MPD events.
reg d_ois2y_bp                                                ///
    s_eccpest      s_cpexemuy_p   s_eccpemuy_f                /// CPI: flash headline YoY, flash core YoY, final headline YoY
    s_mpmiezma_p   s_mpmiezsa_p                               /// PMI flash: manufacturing, services
    s_mpmiezma_f   s_mpmiezsa_f                               /// PMI final: manufacturing, services
    s_eugnemuq_a   s_eugnemuq_f                               /// GDP QoQ: advance, final
    s_umrtemu      s_euccemu_p                                /// unemployment rate, consumer confidence flash
    s_euitemum     s_rssaemum                                 /// industrial production MoM, retail sales MoM
    s_euppemuy     s_ecmam3yy                                 /// PPI YoY, M3 YoY
    if ecb_day == 0, vce(robust)

* Daily macro shock (bp) = fitted news component, net of the constant
predict double macro_shock, xb
replace macro_shock = macro_shock - _b[_cons]
* exact zero for days whose releases all fall outside the regressor set:
* float dust from the constant subtraction otherwise counts as a "nonzero"
* shock and lands in tercile 1 (1e-9-sized regressor -> degenerate estimates)
replace macro_shock = 0 if abs(macro_shock) < 1e-6
replace macro_shock = 0 if n_releases == 0
replace macro_shock = . if ecb_day == 1

* sanity: distribution of the shock on release days
summarize macro_shock if n_releases > 0 & ecb_day == 0, detail

rename date business_date
keep business_date macro_shock
export delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.csv", replace
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.dta", replace

********************************************************************************
* 2. Merge into the bond panel
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

* keep(match): drops panel days outside the release-shock coverage
* (before 2021-01-05 / after 2025-10-23). ECB days merge with macro_shock
* missing and fall out of the regressions automatically.
* Requires Section 1 to have been run once (creates macro_shock.dta).
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.dta", keep(match) nogen

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

gen log_hf_intensity = log(1 + hf_intensity_pre)

********************************************************************************
* 3. Amplification regressions (release-shock analogue of the MP baseline)
********************************************************************************

* 3.1 Baseline regression
reghdfe delta_y i.hf_involved##c.macro_shock duration bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
reghdfe delta_y c.log_hf_intensity##c.macro_shock duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)


* Constraining regime
reghdfe delta_y c.log_hf_intensity##c.macro_shock duration bid_ask_spread ctd_flag ///
    if (macro_shock > 0 & macro_shock < . & hf_intensity_long > 0) ///
 | (macro_shock < 0 & hf_intensity_short > 0) ///
 | (macro_shock == 0) ///
 | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* Relaxing regime
reghdfe delta_y c.log_hf_intensity##c.macro_shock duration bid_ask_spread ctd_flag ///
    if (macro_shock > 0 & macro_shock < . & hf_intensity_short > 0) ///
    | (macro_shock < 0 & hf_intensity_long > 0) ///
	| (macro_shock == 0) ///
    | (hf_intensity_pre == 0), ///
    absorb(duration_match isin) vce(cluster business_date isin)

* 3.2 Shock-size buckets (non-linearity within the release laboratory)
* Fixed bp thresholds instead of quantile cuts: the |shock| distribution is
* quasi-sparse, so equal-count buckets (terciles/quartiles) place all but one
* bucket inside the sub-1bp dead zone where adjustment costs predict no
* rebalancing. Economically anchored grid:
*   bucket 0 : no news              (baseline)
*   bucket 1 : 0   < |shock| <= 1bp (dead zone -> mechanism predicts ~0)
*   bucket 2 : 1bp < |shock| <= 2bp (trading zone)
*   bucket 3 : 2bp < |shock| <= 4bp (trading zone)
*   bucket 4 :       |shock| >  4bp (trading zone, few days but weight ~ shock^2)
* The linearity test is b2 = b3 = b4 (within the trading zone); bucket 1 is
* the placebo region. Robustness: shift the grid (0.5/1.5/3) or quartiles
* within the trading zone. Guard "& macro_shock < ." everywhere: abs(.) > x
* is true in Stata. Binary analogue: swap log_hf_intensity for hf_involved.
gen shock_bucket = .
replace shock_bucket = 0 if macro_shock == 0
replace shock_bucket = 1 if abs(macro_shock) > 0 & abs(macro_shock) <= 1 & macro_shock < .
replace shock_bucket = 2 if abs(macro_shock) > 1 & abs(macro_shock) <= 2 & macro_shock < .
replace shock_bucket = 3 if abs(macro_shock) > 2 & abs(macro_shock) <= 4 & macro_shock < .
replace shock_bucket = 4 if abs(macro_shock) > 4 & macro_shock < .

* day counts per bucket (report alongside the table)
egen day_tag = tag(business_date)
tab shock_bucket if day_tag, missing
drop day_tag

forvalues b = 1/4 {
    gen hf_b`b'      = log_hf_intensity * (shock_bucket == `b')
    gen hfshock_b`b' = log_hf_intensity * macro_shock * (shock_bucket == `b')
}

reghdfe delta_y c.log_hf_intensity hf_b? hfshock_b? ///
    duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)
test hfshock_b1 == 0                                  // dead zone: mechanism predicts zero
test (hfshock_b2 == hfshock_b3) (hfshock_b3 == hfshock_b4)   // linearity within trading zone

* continuous convexity check: does the amplification per bp rise with |shock|?
* hfshock_size > 0 => convex; = 0 => the amplification share is size-invariant.
gen hfshock      = log_hf_intensity * macro_shock
gen hf_size      = log_hf_intensity * abs(macro_shock)
gen hfshock_size = log_hf_intensity * macro_shock * abs(macro_shock)

reghdfe delta_y c.log_hf_intensity hf_size hfshock hfshock_size ///
    duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)

********************************************************************************
* 4. Orthogonality of HF positioning to the release shock
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.dta", keep(match) nogen

* 2. Convert to Stata date
gen date_num = date(business_date, "YMD")
format date_num %td

* 3. Collapse to daily market-level panel
collapse (mean) macro_shock (sum) net_pos, by(date_num)

* 4. Sort by date and create a business-day index
sort date_num
gen bday = _n

* 5. Set time series with business-day frequency
tsset bday

* 6. Create lagged positioning using the full business-day panel
gen lag_net_pos = L.net_pos

* 7. Restrict to release days and test orthogonality
keep if macro_shock != 0 & !missing(macro_shock)
reg macro_shock lag_net_pos, robust
