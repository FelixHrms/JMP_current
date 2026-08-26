********************************************************************************
* MATCHED-PAIR BALANCE
* Requires: matched_sample.do must have been run first, so that
*           Data\match_map.dta and Data\matched_sample_full.dta exist.
*           This file only READS those intermediates; it changes nothing.
* Produces: Appendix Table (matched-pair balance, tab:pair_balance)
*           + "typical pair" statistics for the in-text example sentence.
* Note    : Bond age, benchmark and on-the-run status are not in the panel
*           (would require an issue-date pull from Bloomberg). Balance is
*           reported for the characteristics the panel carries.
********************************************************************************

clear all

* 1. Pair map: one row per HF bond-day with its matched non-HF control
use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map.dta", clear

* 2. Characteristics of the HF side
rename hf_obs_id obs_id
merge m:1 obs_id using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", ///
    keepusing(business_date collateral_country duration residual_bond_maturity ///
              amt_issued bid_ask_spread yld_mid ctd_flag) ///
    keep(match) nogenerate
rename (duration residual_bond_maturity amt_issued bid_ask_spread yld_mid ctd_flag) ///
       (hf_duration hf_resmat hf_amt hf_bas hf_yld hf_ctd)
rename obs_id hf_obs_id

* 3. Characteristics of the non-HF side (same cell, so same date and country)
rename nohf_obs_id obs_id
merge m:1 obs_id using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", ///
    keepusing(duration residual_bond_maturity amt_issued bid_ask_spread yld_mid ctd_flag) ///
    keep(match) nogenerate
rename (duration residual_bond_maturity amt_issued bid_ask_spread yld_mid ctd_flag) ///
       (nohf_duration nohf_resmat nohf_amt nohf_bas nohf_yld nohf_ctd)
rename obs_id nohf_obs_id

* 4. Within-pair differences (HF minus matched non-HF)
foreach v in duration resmat amt bas yld ctd {
    gen d_`v'  = hf_`v' - nohf_`v'
    gen ad_`v' = abs(d_`v')
}
gen ctd_mismatch = (hf_ctd != nohf_ctd)

********************************************************************************
* 5. Balance table
*    Columns: HF mean | non-HF mean | mean diff | median |diff| | std. diff | p
*    p-value from a constant-only regression of the within-pair difference,
*    clustered by business date (pairs on the same day are not independent).
*    Std. diff = mean diff / sqrt((Var_HF + Var_nonHF)/2).
********************************************************************************

matrix B = J(6, 6, .)
matrix rownames B = Duration ResMaturity AmtIssued BidAsk Yield CTD
matrix colnames B = HF_mean nonHF_mean mean_diff med_absdiff std_diff p_value

local i = 1
foreach v in duration resmat amt bas yld ctd {
    quietly summarize hf_`v'
    matrix B[`i',1] = r(mean)
    local var_hf = r(Var)
    quietly summarize nohf_`v'
    matrix B[`i',2] = r(mean)
    local var_nohf = r(Var)
    quietly summarize d_`v'
    matrix B[`i',3] = r(mean)
    matrix B[`i',5] = r(mean) / sqrt((`var_hf' + `var_nohf')/2)
    quietly summarize ad_`v', detail
    matrix B[`i',4] = r(p50)
    quietly reg d_`v', vce(cluster business_date)
    matrix B[`i',6] = 2*ttail(e(df_r), abs(_b[_cons]/_se[_cons]))
    local ++i
}

matrix list B, format(%9.4f)

* CTD mismatch rate (share of pairs where the two bonds differ in CTD status)
summarize ctd_mismatch

********************************************************************************
* 6. Sample composition
********************************************************************************

count
egen tag_hf   = tag(hf_isin)
egen tag_nohf = tag(nohf_isin)
egen tag_date = tag(business_date)
count if tag_hf
count if tag_nohf
count if tag_date

********************************************************************************
* 7. "Typical pair" statistics for the in-text example sentence
*    (medians of levels on both sides and of the absolute within-pair gaps)
********************************************************************************

foreach v in duration bas {
    quietly summarize hf_`v', detail
    di as text "median HF `v'      : " as result %9.3f r(p50)
    quietly summarize nohf_`v', detail
    di as text "median non-HF `v'  : " as result %9.3f r(p50)
    quietly summarize ad_`v', detail
    di as text "median |gap| `v'   : " as result %9.3f r(p50) ///
       as text "   (p75: " as result %9.3f r(p75) as text ")"
}

********************************************************************************
* 8. ROBUSTNESS: WELL-MATCHED PAIRS ONLY
*    The balance table shows the bid-ask gap within pairs is one-sided: the
*    control is almost always the (somewhat) less liquid bond of the cell.
*    Re-estimate the matched regression (Table IV, Column 5) on pairs that
*    are tightly matched on liquidity. bas_distance is carried into
*    matched_panel.dta from the match map, so no re-matching is needed.
********************************************************************************

use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_panel.dta", clear

summarize bas_distance, detail
local gap_p25 = r(p25)
local gap_p50 = r(p50)
di as text "bid-ask gap p25: " as result %9.4f `gap_p25' ///
   as text "   p50: " as result %9.4f `gap_p50'

* (1) Replication of Table IV, Column 5 (full matched sample)
reghdfe delta_y c.treated##c.ois_2y ctd_flag, ///
    absorb(pair_id) vce(cluster duration_match nohf_isin)

* (2) Pairs with bid-ask gap <= 0.10 euro
reghdfe delta_y c.treated##c.ois_2y ctd_flag if bas_distance <= 0.10, ///
    absorb(pair_id) vce(cluster duration_match nohf_isin)

* (3) Pairs with bid-ask gap below the median gap
reghdfe delta_y c.treated##c.ois_2y ctd_flag if bas_distance <= `gap_p50', ///
    absorb(pair_id) vce(cluster duration_match nohf_isin)

* (4) Pairs with bid-ask gap below the 25th-percentile gap (near-exact matches)
reghdfe delta_y c.treated##c.ois_2y ctd_flag if bas_distance <= `gap_p25', ///
    absorb(pair_id) vce(cluster duration_match nohf_isin)

* (5) Full matched sample, letting the shock response vary with liquidity
*     (discussant slide 12: bid-ask x shock interaction). The ois_2y main
*     effect is absorbed by the pair FE, as in the baseline.
reghdfe delta_y c.treated##c.ois_2y c.bid_ask_spread##c.ois_2y ctd_flag, ///
    absorb(pair_id) vce(cluster duration_match nohf_isin)

********************************************************************************
* 9. ROBUSTNESS: SHOCK RESPONSE VARYING WITH ALL IMBALANCED CHARACTERISTICS
*    The balance table shows within-pair imbalances in bid-ask spread,
*    residual maturity, and amount issued. This section lets the shock
*    response vary with all three at once in the matched regression, so the
*    treated x shock coefficient is identified only from HF status, not from
*    any of these characteristics. Residual maturity and amount issued are
*    not carried in matched_panel.dta, so merge them in first via obs_id.
********************************************************************************

use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_panel.dta", clear

* Each row's obs_id: the HF side kept hf_obs_id, the non-HF side nohf_obs_id
gen obs_id = cond(treated == 1, hf_obs_id, nohf_obs_id)
merge m:1 obs_id using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", ///
    keepusing(residual_bond_maturity amt_issued) ///
    keep(match) nogenerate

* (6) Kitchen sink: bid-ask, residual maturity, and amount issued all
*     interacted with the shock (main effects included; ois_2y main effect
*     absorbed by the pair FE)
reghdfe delta_y c.treated##c.ois_2y ///
    c.bid_ask_spread##c.ois_2y ///
    c.residual_bond_maturity##c.ois_2y ///
    c.amt_issued##c.ois_2y ///
    ctd_flag, ///
    absorb(pair_id) vce(cluster duration_match nohf_isin)
