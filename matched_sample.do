********************************************************************************
* MATCHED SAMPLE
* Input : Data\monetary_policy_induced_position.csv  (writes match_*.dta intermediates to Data\)
* Produces: Table IV col 5 (matched estimate)  +  Figure 4a (IR_baseline) & 4b (IR_baseline_decomposition)
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

encode hf_category, gen(hf_cat)
encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

keep if duration >= 0


* Count HF and non-HF bonds per matching cell
bysort duration_match: egen n_hf = total(hf_involved == 1)
bysort duration_match: egen n_nohf = total(hf_involved == 0)

gen has_hf = (n_hf > 0)
gen has_nohf = (n_nohf > 0)
tab has_hf has_nohf


* Step 1: Separate HF and non-HF, keep only matchable cells
preserve
    keep if has_hf == 1 & has_nohf == 1
    
    * Create a within-cell bond identifier
    gen obs_id = _n
    
    * Save HF and non-HF separately
    save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", replace
    
    keep if hf_involved == 1
    keep obs_id duration_match isin bid_ask_spread
    rename (obs_id isin bid_ask_spread) (hf_obs_id hf_isin hf_bas)
    save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\hf_bonds.dta", replace
    
    use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", clear
    keep if hf_involved == 0
    keep obs_id duration_match isin bid_ask_spread
    rename (obs_id isin bid_ask_spread) (nohf_obs_id nohf_isin nohf_bas)
    save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\nohf_bonds.dta", replace
restore


* Go back to the with-replacement version
use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\hf_bonds.dta", clear
joinby duration_match using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\nohf_bonds.dta"
gen bas_distance = abs(hf_bas - nohf_bas)

* Keep nearest match for each HF bond (with replacement)
bysort hf_obs_id (bas_distance): keep if _n == 1

* Apply caliper
drop if bas_distance > 0.827

count


* Save the match mapping
keep hf_obs_id hf_isin nohf_obs_id nohf_isin duration_match bas_distance
gen pair_id = _n
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map.dta", replace







use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map.dta", clear

* --- HF side ---
rename hf_obs_id obs_id
merge m:1 obs_id using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", ///
    keepusing(delta_y ois_2y bid_ask_spread ctd_flag hf_involved duration_match) ///
    keep(match) nogenerate
    
* Tag as treated
gen treated = 1
gen pair = pair_id

* Save HF side
rename obs_id hf_obs_id
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\hf_side.dta", replace

* --- Non-HF side ---
use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map.dta", clear
rename nohf_obs_id obs_id
merge m:1 obs_id using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", ///
    keepusing(delta_y ois_2y bid_ask_spread ctd_flag hf_involved duration_match) ///
    keep(match) nogenerate

gen treated = 0
gen pair = pair_id

rename obs_id nohf_obs_id
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\nohf_side.dta", replace

* --- Stack ---
use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\hf_side.dta", clear
append using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\nohf_side.dta"

save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_panel.dta", replace
count



* --- TABLE IV col 5: matched-sample estimate ---
reghdfe delta_y c.treated##c.ois_2y ctd_flag, ///
    absorb(pair_id) vce(cluster duration_match nohf_isin)
	
	
	
	
	
	
	
	
*********************************************
** HERE WE START WITH LOCAL PROJECTIONS**
********************************************	
	
use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map.dta", clear

* We need to recover the business_date for each pair
* Merge back to get it from the full data
rename hf_obs_id obs_id
merge m:1 obs_id using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", ///
    keepusing(business_date ois_2y) keep(match) nogenerate
rename obs_id hf_obs_id

* Check
list pair_id hf_isin nohf_isin business_date ois_2y in 1/10




save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map_dated.dta", replace

* Now load the original data to get the yield time series
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

* Keep only what we need
keep isin business_date yld_mid
duplicates drop isin business_date, force

* Create a numeric date for sorting
gen date_num = date(business_date, "YMD")
format date_num %td

* Create sequential business day counter per ISIN
sort isin date_num
by isin: gen bday_time = _n

save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\yield_panel.dta", replace



use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map_dated.dta", clear

* Merge to get bday_time for the HF bond on the match date
rename hf_isin isin
merge m:1 isin business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\yield_panel.dta", ///
    keepusing(bday_time) keep(match) nogenerate
rename bday_time hf_bday_t0
rename isin hf_isin

* Merge to get bday_time for the non-HF bond on the match date
rename nohf_isin isin
merge m:1 isin business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\yield_panel.dta", ///
    keepusing(bday_time) keep(match) nogenerate
rename bday_time nohf_bday_t0
rename isin nohf_isin

save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map_timed.dta", replace
count



use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map_timed.dta", clear

* Expand each pair across horizons -2 to 10
expand 21
bysort pair_id: gen horizon = _n - 11  // gives -2 to 10

* Compute the bday_time we need for each bond at each horizon
gen hf_bday_lookup = hf_bday_t0 + horizon
gen nohf_bday_lookup = nohf_bday_t0 + horizon

* Also need the L1 yield (t=-1) for cumulative changes
gen hf_bday_L1 = hf_bday_t0 - 1
gen nohf_bday_L1 = nohf_bday_t0 - 1

save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_expanded.dta", replace
count



use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_expanded.dta", clear

* --- HF bond yield at horizon ---
rename hf_isin isin
rename hf_bday_lookup bday_time
merge m:1 isin bday_time using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\yield_panel.dta", ///
    keepusing(yld_mid) keep(master match) nogenerate
rename yld_mid hf_yld_h
rename bday_time hf_bday_lookup
rename isin hf_isin

* --- HF bond yield at L1 ---
rename hf_isin isin
rename hf_bday_L1 bday_time
merge m:1 isin bday_time using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\yield_panel.dta", ///
    keepusing(yld_mid) keep(master match) nogenerate
rename yld_mid hf_yld_L1
rename bday_time hf_bday_L1
rename isin hf_isin

* --- Non-HF bond yield at horizon ---
rename nohf_isin isin
rename nohf_bday_lookup bday_time
merge m:1 isin bday_time using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\yield_panel.dta", ///
    keepusing(yld_mid) keep(master match) nogenerate
rename yld_mid nohf_yld_h
rename bday_time nohf_bday_lookup
rename isin nohf_isin

* --- Non-HF bond yield at L1 ---
rename nohf_isin isin
rename nohf_bday_L1 bday_time
merge m:1 isin bday_time using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\yield_panel.dta", ///
    keepusing(yld_mid) keep(master match) nogenerate
rename yld_mid nohf_yld_L1
rename bday_time nohf_bday_L1
rename isin nohf_isin

save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_yields.dta", replace




use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_yields.dta", clear

* Cumulative yield change in bps for each bond
gen hf_cumul_dy = (hf_yld_h - hf_yld_L1) * 100
gen nohf_cumul_dy = (nohf_yld_h - nohf_yld_L1) * 100

* The matched difference
gen diff_dy = hf_cumul_dy - nohf_cumul_dy

* Check missingness
count if missing(hf_cumul_dy)
count if missing(nohf_cumul_dy)

save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_yields.dta", replace





use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_yields.dta", clear

tempname memhold
tempfile matched_results
postfile `memhold' horizon beta se using `matched_results', replace

quietly forvalues h = -5/10 {
    reg diff_dy ois_2y if horizon == `h', vce(cluster duration_match)
    post `memhold' (`h') (_b[ois_2y]) (_se[ois_2y])
}
postclose `memhold'

preserve
    use `matched_results', clear
    
    gen ci_up = beta + 1.64*se
    gen ci_lo = beta - 1.64*se
    
    twoway (rarea ci_up ci_lo horizon, color(red%20) lwidth(none)) ///
           (line beta horizon, color(cranberry) lwidth(thick)), ///
           yline(0, lcolor(black) lpattern(dash)) ///
           ytitle("Matched Yield Difference (bps)") ///
           xtitle("Days since Shock (Horizon)") ///
           xlabel(-5(1)10) ///
           legend(off) ///
           graphregion(color(white))
    graph export "C:\Users\hermesf\Projects\JobMarket\Figures\IR_baseline.png", replace width(2000)
restore




use "C:\Users\hermesf\Projects\JobMarket\Data\match_yields.dta", clear

tempname memhold
tempfile lp_results
postfile `memhold' horizon beta_hf se_hf beta_nonhf se_nonhf ///
    beta_diff se_diff using `lp_results', replace

quietly forvalues h = -5/10 {
    reg hf_cumul_dy ois_2y if horizon == `h', vce(cluster duration_match)
    local b_hf = _b[ois_2y]
    local s_hf = _se[ois_2y]
    
    reg nohf_cumul_dy ois_2y if horizon == `h', vce(cluster duration_match)
    local b_nh = _b[ois_2y]
    local s_nh = _se[ois_2y]
    
    reg diff_dy ois_2y if horizon == `h', vce(cluster duration_match)
    local b_d = _b[ois_2y]
    local s_d = _se[ois_2y]
    
    post `memhold' (`h') (`b_hf') (`s_hf') (`b_nh') (`s_nh') (`b_d') (`s_d')
}
postclose `memhold'

preserve
    use `lp_results', clear
    
    foreach v in hf nonhf diff {
        gen ci_up_`v' = beta_`v' + 1.64*se_`v'
        gen ci_lo_`v' = beta_`v' - 1.64*se_`v'
    }
    
    twoway (rarea ci_up_hf ci_lo_hf horizon, color(red%20) lwidth(none)) ///
           (rarea ci_up_nonhf ci_lo_nonhf horizon, color(blue%20) lwidth(none)) ///
           (line beta_hf horizon, color(cranberry) lwidth(thick)) ///
           (line beta_nonhf horizon, color(navy) lwidth(thick) lpattern(dash)), ///
           yline(0, lcolor(black) lpattern(dash)) ///
           xline(0, lcolor(gs10) lpattern(dot)) ///
           ytitle("Cumulative Yield Response per bp Shock") ///
           xtitle("Days since Shock (Horizon)") ///
           xlabel(-5(1)10) ///
           legend(order(3 "HF bonds" 4 "Matched non-HF bonds") ///
                  rows(1) position(6) region(lstyle(none))) ///
           graphregion(color(white))
    graph export "C:\Users\hermesf\Projects\JobMarket\Figures\IR_baseline_decomposition.png", replace width(2000)
restore




*********************************************
** OVERSHOOTING VIEW OF THE DECOMPOSITION LP **
*********************************************
* Re-centers the HF and matched non-HF response paths from the decomposition above
* on a single SETTLED anchor: the level both legs converge to in the late window
* (horizons 5..10), pooled across the two legs. One constant is subtracted from BOTH
* legs, so the HF-vs-non-HF level gap is preserved -- the matched non-HF leg traces
* its approach up to the settled line, while HF rises ABOVE that same line on impact
* and decays back to it (overshooting). Pre-event horizons are dropped. Reuses the
* betas estimated just above (tempfile `lp_results'); nothing is re-estimated, each
* path is only shifted by that constant, and the CI bands are the per-horizon bands
* shifted by the same constant.
preserve
    use `lp_results', clear

    * Settled anchor = mean response over the late window (horizons 5..10), pooled
    * equally across the two legs. Subtract this single constant from both legs.
    foreach v in hf nonhf {
        egen mean_`v' = mean(cond(inrange(horizon, 5, 10), beta_`v', .))
    }
    gen ref_all = (mean_hf + mean_nonhf) / 2
    foreach v in hf nonhf {
        gen os_beta_`v' = beta_`v' - ref_all
        gen os_ci_up_`v' = os_beta_`v' + 1.64*se_`v'
        gen os_ci_lo_`v' = os_beta_`v' - 1.64*se_`v'
    }
    drop if horizon < 0

    twoway (rarea os_ci_up_hf os_ci_lo_hf horizon, color(red%20) lwidth(none)) ///
           (rarea os_ci_up_nonhf os_ci_lo_nonhf horizon, color(blue%20) lwidth(none)) ///
           (line os_beta_hf horizon, color(cranberry) lwidth(thick)) ///
           (line os_beta_nonhf horizon, color(navy) lwidth(thick) lpattern(dash)), ///
           yline(0, lcolor(black) lpattern(dash)) ///
           ytitle("Cumulative yield response relative to" "5-10 day average, per bp shock") ///
           xtitle("Days since Shock (Horizon)") ///
           xlabel(0(1)10) ///
           subtitle("Relative to shared settled level (days 5-10, both legs)") ///
           legend(order(3 "HF bonds" 4 "Matched non-HF bonds") ///
                  rows(1) position(6) region(lstyle(none))) ///
           graphregion(color(white))
    graph export "C:\Users\hermesf\Projects\JobMarket\Figures\IR_baseline_decomposition_overshoot.png", replace width(2000)
restore







