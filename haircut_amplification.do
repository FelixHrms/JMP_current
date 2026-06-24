********************************************************************************
* HAIRCUT MARGIN AND YIELD AMPLIFICATION
* Inputs : Data\haircut_cells.csv, Data\haircut_fund_fe.csv,
*          Data\haircut_dealer_fe.csv      (from haircut_components.do)
*          Data\monetary_policy_induced_position.csv   (main panel)
* Builds bond-day haircut margins (position-weighted across the funds/dealers
* active in the bond) and tests whether the amplification depends on them:
*   (a) realized margin  -> does "lower haircut => more amplification" hold raw?
*   (b) fund vs dealer components -> does market power / counterparty risk make
*       the two sides act in different directions?
* Mirrors the directionality specification: the moderator enters only through
* HF intensity (it is defined only for HF-held bonds), with bond and
* duration x country x date fixed effects.
********************************************************************************

clear all
set more off

*===============================================================================
* 1. BOND-DAY HAIRCUT MARGINS (position-weighted across active funds/dealers)
*===============================================================================
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\haircut_cells.csv", clear
gen abs_haircut = abs(haircut)
drop if missing(abs_haircut)
tempfile cells
save `cells'

import delimited "C:\Users\hermesf\Projects\JobMarket\Data\haircut_fund_fe.csv", clear
keep fund_id fund_fe
tempfile fundfe
save `fundfe'

import delimited "C:\Users\hermesf\Projects\JobMarket\Data\haircut_dealer_fe.csv", clear
keep dealer_id dealer_fe
tempfile dealerfe
save `dealerfe'

use `cells', clear
merge m:1 fund_id   using `fundfe',   keep(master match) nogen
merge m:1 dealer_id using `dealerfe', keep(master match) nogen

* Volume-weighted bond-day margin and its fund/dealer components
collapse (mean) fund_comp=fund_fe dealer_comp=dealer_fe margin=abs_haircut ///
    [aw=nominal_euro], by(business_date isin)
tempfile bondday
save `bondday'

*===============================================================================
* 2. MERGE ONTO MAIN PANEL + PREDETERMINE (5-day trailing, as for holder_dir)
*===============================================================================
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear
merge m:1 business_date isin using `bondday', keep(master match) nogen

encode collateral_country, gen(col_cntr)
gen duration_bin   = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

egen isin_id = group(isin)
gen date_num = date(business_date, "YMD")
format date_num %td
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

* Predetermined 5-day trailing mean over prior ACTIVE days; 0 for no-HF bond-days
* (their log_hf_intensity is 0 there, so every interaction term is 0 anyway).
foreach v in margin fund_comp dealer_comp {
    gen `v'_s = 0
    gen `v'_n = 0
    forvalues k = 1/5 {
        replace `v'_s = `v'_s + L`k'.`v' if !missing(L`k'.`v')
        replace `v'_n = `v'_n + 1        if !missing(L`k'.`v')
    }
    gen `v'_pre = `v'_s / `v'_n if `v'_n > 0
    drop `v'_s `v'_n
    replace `v'_pre = 0 if hf_intensity_pre == 0
}

*===============================================================================
* 3. AMPLIFICATION CONDITIONAL ON THE MARGIN
* Coefficient of interest is the triple interaction (Intensity x Shock x margin).
* Sign convention: margin = |haircut|, so HIGHER margin = LESS leverage. A
* NEGATIVE triple coefficient => higher margin dampens amplification, i.e. the
* "lower haircut => more amplification" mechanism holds; a positive/zero one
* means it breaks once that piece of the margin is isolated.
* NB inference is conditional on the estimated components (generated regressors);
* a two-stage block bootstrap over fund/dealer FE is the proper SE fix.
*===============================================================================

* (a) realized margin
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.margin_pre ///
    c.log_hf_intensity#c.ois_2y#c.margin_pre ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* (b) fund vs dealer components of the margin
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.fund_comp_pre    c.log_hf_intensity#c.ois_2y#c.fund_comp_pre ///
    c.log_hf_intensity#c.dealer_comp_pre  c.log_hf_intensity#c.ois_2y#c.dealer_comp_pre ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
