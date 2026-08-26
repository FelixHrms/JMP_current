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
