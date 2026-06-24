********************************************************************************
* HAIRCUT MARGIN AND YIELD AMPLIFICATION
* Inputs : Data\haircut_bondday.csv  (bond-day margin + components, from
*          haircut_components.do)  and  Data\monetary_policy_induced_position.csv
* Tests whether the amplification depends on the haircut margin and which
* component drives it. The moderator enters ONLY through HF intensity (it is
* defined only for HF-held bonds), with bond and duration x country x date FE,
* mirroring the directionality specification. Components are STANDARDIZED, so the
* triple interactions are comparable per standard deviation.
*
* Component sign map (margin = |haircut|, higher = LESS leverage):
*   fund_comp   : fund-side margin   -> bargaining power / fund counterparty risk
*   dealer_comp : dealer-side margin -> dealer market power
*   bond_comp   : bond-side margin   -> collateral risk
*   resid_comp  : margin orthogonal to ALL of the above -> the leverage
*                 COUNTERFACTUAL. A NEGATIVE triple here means a lower haircut
*                 still amplifies once market power and collateral are netted out,
*                 i.e. the pure leverage channel survives.
* NB resid_comp carries measurement noise -> its coefficient is attenuated
* toward zero. Inference is conditional on the estimated components (generated
* regressors); a two-stage block bootstrap is the proper SE fix (later).
********************************************************************************

clear all
set more off

*-------------------------------------------------------------------------------
* Merge bond-day margins onto the main panel
*-------------------------------------------------------------------------------
tempfile bondday
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\haircut_bondday.csv", clear
save `bondday'

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

*-------------------------------------------------------------------------------
* Predetermine (5-day trailing mean over prior ACTIVE days), then standardize
* among HF bond-days. No-HF bond-days are set to 0 (their log_hf_intensity is 0,
* so every interaction term is 0 there anyway).
*-------------------------------------------------------------------------------
foreach v in margin fund_comp dealer_comp bond_comp resid_comp {
    gen `v'_s = 0
    gen `v'_n = 0
    forvalues k = 1/5 {
        replace `v'_s = `v'_s + L`k'.`v' if !missing(L`k'.`v')
        replace `v'_n = `v'_n + 1        if !missing(L`k'.`v')
    }
    gen `v'_pre = `v'_s / `v'_n if `v'_n > 0
    drop `v'_s `v'_n
    quietly sum `v'_pre if hf_intensity_pre > 0
    gen z_`v' = (`v'_pre - r(mean)) / r(sd) if hf_intensity_pre > 0
    replace z_`v' = 0 if hf_intensity_pre == 0
}

*===============================================================================
* (a) Realized margin: does the haircut as a whole moderate amplification?
*===============================================================================
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.z_margin ///
    c.log_hf_intensity#c.ois_2y#c.z_margin ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

*===============================================================================
* (b) Full decomposition: fund + dealer + collateral + residual (counterfactual)
*     Watch the triple interactions:
*       fund / dealer : market-power channels   (found positive)
*       bond          : collateral-risk channel (third leg of the hypothesis)
*       resid         : leverage counterfactual  (expected NEGATIVE)
*===============================================================================
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.z_fund_comp    c.log_hf_intensity#c.ois_2y#c.z_fund_comp ///
    c.log_hf_intensity#c.z_dealer_comp  c.log_hf_intensity#c.ois_2y#c.z_dealer_comp ///
    c.log_hf_intensity#c.z_bond_comp    c.log_hf_intensity#c.ois_2y#c.z_bond_comp ///
    c.log_hf_intensity#c.z_resid_comp   c.log_hf_intensity#c.ois_2y#c.z_resid_comp ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
