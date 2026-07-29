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

* 3.2 Decomposing release days a la Jarocinski-Karadi (poor man's sign split)
* Classify each release day by the comovement of the release shock and the
* EuroStoxx 50 return: opposite signs -> discount-rate-type news (yields up,
* stocks down); same sign -> growth-type news. Mirrors the paper's JK table
* for ECB events, applied within the release laboratory. Both components in
* one specification (they live on disjoint days) + Wald test of equality.
* eurostoxx50.csv is the ECB SDW export (reverse-chronological, header rows).

preserve
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\eurostoxx50.csv", clear varnames(nonames)
keep v1 v2
gen ddate = date(v1, "YMD")
drop if missing(ddate)
destring v2, replace force
sort ddate
gen double eq_ret = 100 * (v2 / v2[_n-1] - 1)
gen business_date = string(ddate, "%tdCCYY-NN-DD")
keep business_date eq_ret
tempfile stoxx
save `stoxx'
restore

foreach v in eq_ret disc_day growth_day shock_disc shock_growth comp_type ///
    hfb_disc hfb_gro hfi_disc hfi_gro {
    capture drop `v'
}
merge m:1 business_date using `stoxx', keep(master match) nogen

* guards required: in Stata a missing product compares as +inf, so an
* unmatched equity day would silently classify as growth-type without them
gen byte disc_day   = (macro_shock * eq_ret < 0) if !missing(macro_shock, eq_ret)
gen byte growth_day = (macro_shock * eq_ret > 0) if !missing(macro_shock, eq_ret)
gen double shock_disc   = macro_shock * disc_day
gen double shock_growth = macro_shock * growth_day

* composition: day counts and |shock| by component (balance check)
gen comp_type = .
replace comp_type = 1 if disc_day == 1
replace comp_type = 2 if growth_day == 1
label define comp 1 "discount-type" 2 "growth-type", replace
label values comp_type comp
egen day_tag = tag(business_date)
gen double abs_ms = abs(macro_shock)
tabstat abs_ms if day_tag & comp_type < ., by(comp_type) stat(n mean p50 max)
drop day_tag abs_ms

* binary (mirrors the paper's JK table) and intensity variants
gen double hfb_disc = hf_involved * shock_disc
gen double hfb_gro  = hf_involved * shock_growth
gen double hfi_disc = log_hf_intensity * shock_disc
gen double hfi_gro  = log_hf_intensity * shock_growth

reghdfe delta_y i.hf_involved hfb_disc hfb_gro ///
    duration bid_ask_spread ctd_flag, absorb(isin duration_match) vce(cluster business_date isin)
test hfb_disc == hfb_gro

reghdfe delta_y c.log_hf_intensity hfi_disc hfi_gro ///
    duration bid_ask_spread ctd_flag, absorb(duration_match isin) vce(cluster business_date isin)
test hfi_disc == hfi_gro

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
