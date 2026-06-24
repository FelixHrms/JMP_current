********************************************************************************
* HOLDER-WEIGHTED FUND DIRECTIONALITY AND YIELD AMPLIFICATION
* Produces: Table IX (directionality)  +  Figure 6 (holder_dir_timeseries)  +  Figure 7a/7b (IR_holder_dir_hedged/_directional)
* holder_dir in [0,1] is the holdings-weighted DV01-directionality of a bond's HF
* holders (0 = hedged carry / relative value, 1 = directional). It varies across
* bonds within a day, so the tests are identified within day, free of the cycle.
* NOTE: every fund here is a hedge fund, so the contrast is HF-held-hedged vs
* HF-held-directional, against a baseline of bonds with no HF activity.
********************************************************************************
clear all
set more off

capture log close
log using "C:\Users\hermesf\Projects\JobMarket\Empirics\holder_dir_analysis.log", replace text

*===============================================================================
* 1. IMPORT
*===============================================================================
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen duration_bin   = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

* Panel setup (sequential day counter per bond, robust to calendar gaps)
egen isin_id  = group(isin)
gen date_num  = date(business_date, "YMD")
format date_num %td
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time


*===============================================================================
* 2. CREATE THE MEASURE
*===============================================================================
* Predetermine holder_dir: 5-day trailing mean over the prior ACTIVE days only
* (idle days are missing and skipped, so they do not pull the average).
gen hd_sum = 0
gen hd_cnt = 0
forvalues k = 1/5 {
    replace hd_sum = hd_sum + L`k'.holder_dir if !missing(L`k'.holder_dir)
    replace hd_cnt = hd_cnt + 1              if !missing(L`k'.holder_dir)
}
gen holder_dir_pre = hd_sum / hd_cnt if hd_cnt > 0
drop hd_sum hd_cnt

gen present = (hf_intensity_pre > 0)

* hd: holder_dir, set to 0 for no-HF bonds so they remain the zero-intensity
* baseline (their log_hf_intensity is 0, so every interaction term is 0 anyway).
gen hd = holder_dir_pre
replace hd = 0 if present == 0

* Median of holder_dir among HF-held bonds (fixed once, reused below)
sum holder_dir_pre if present, detail
scalar hd_med = r(p50)

* Categorical: 0 = no HF, 1 = hedged-held, 2 = directional-held
gen hf_dir3 = 0
replace hf_dir3 = 1 if present & holder_dir_pre <= hd_med & !missing(holder_dir_pre)
replace hf_dir3 = 2 if present & holder_dir_pre >  hd_med & !missing(holder_dir_pre)
replace hf_dir3 = . if present & missing(holder_dir_pre)
label define hf_dir3_lbl 0 "No HF" 1 "Hedged-held" 2 "Directional-held"
label values hf_dir3 hf_dir3_lbl

* Quartiles of holder_dir among HF-held bonds, vs the no-HF baseline (= 0)
xtile hd_q = holder_dir_pre if present & !missing(holder_dir_pre), nq(4)
gen hf_dirq = 0
replace hf_dirq = hd_q if present & !missing(hd_q)
replace hf_dirq = . if present & missing(holder_dir_pre)
label define hf_dirq_lbl 0 "No HF" 1 "Q1 hedged" 2 "Q2" 3 "Q3" 4 "Q4 directional"
label values hf_dirq hf_dirq_lbl

* Binary regime tag for the local projections (hedged vs directional held)
gen hd_high = .
replace hd_high = 0 if present & holder_dir_pre <= hd_med & !missing(holder_dir_pre)
replace hd_high = 1 if present & holder_dir_pre >  hd_med & !missing(holder_dir_pre)


*===============================================================================
* 3. DESCRIPTIVES (does the measure make sense?)
*===============================================================================
di _n "==== holder_dir (active bond-days) ===="
count if !missing(holder_dir)
sum holder_dir if !missing(holder_dir), detail
tabstat holder_dir if !missing(holder_dir), by(collateral_country) stat(mean p50 sd n)

* Within-cell variation: confirms identification is within day (across bonds in a cell)
bysort duration_match: egen hd_sd_cell = sd(holder_dir)
sum hd_sd_cell if !missing(hd_sd_cell), detail

* Composition of the hedged vs directional groups. This explains the LP terminal-level
* gap: directional-held bonds sit in the hiking regime (high pass-through), hedged-held
* in the calm carry periods (lower pass-through).
gen year = year(date_num)
di _n "Country mix of hedged-held (1) vs directional-held (2):"
tab hf_dir3 collateral_country if inlist(hf_dir3, 1, 2), row
di _n "Period mix by year (column shares within each group):"
tab year hf_dir3 if inlist(hf_dir3, 1, 2), col
drop year

* Aggregate time series of the measure (positioning-weighted) -> should mirror the
* regime shifts in Figure 1: low (hedged carry) in calm periods, high (directional)
* through the hiking cycle.
gen gross_w = gross_long + gross_short
preserve
    keep if !missing(holder_dir) & gross_w > 0
    collapse (mean) holder_dir_agg = holder_dir [aw=gross_w], by(date_num)
    twoway (line holder_dir_agg date_num, lwidth(medthick) color(navy)), ///
        ytitle("Aggregate holder directionality") xtitle("") ///
        yline(0.5, lcolor(gs10) lpattern(dash)) ///
        graphregion(color(white)) name(g_ts, replace)
    graph export "C:\Users\hermesf\Projects\JobMarket\Figures\holder_dir_timeseries.png", replace width(2000)
restore


*===============================================================================
* 4. SPECIFICATIONS
*===============================================================================

* (1) Continuous: hd enters ONLY through HF intensity (no free hd or hd#shock).
* Object of interest: log_hf_intensity # ois_2y # hd  (expect positive).
reghdfe delta_y c.log_hf_intensity##c.ois_2y ///
    c.log_hf_intensity#c.hd c.log_hf_intensity#c.ois_2y#c.hd ///
    bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* (2) Categorical: no-HF baseline vs hedged-held vs directional-held.
reghdfe delta_y i.hf_dir3##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_dir3#c.ois_2y = 2.hf_dir3#c.ois_2y

* (3) Quartiles of holder_dir vs no-HF baseline (dose-response).
reghdfe delta_y i.hf_dirq##c.ois_2y bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test 1.hf_dirq#c.ois_2y = 4.hf_dirq#c.ois_2y


*===============================================================================
* 5. LOCAL PROJECTIONS, MATCHED DECOMPOSITION (mirrors paper Figure 4b)
* Self-contained: re-imports and rebuilds the measure, matches each HF bond to a
* nearest non-HF bond (same duration x country x date cell, closest bid-ask,
* caliper 0.827, with replacement), tags by holder regime, then traces cumulative
* yield responses of HF vs matched non-HF legs by horizon. Two graphs (hedged and
* directional) are saved independently.
*===============================================================================
clear all
set more off

import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen duration_bin   = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
keep if duration >= 0

* Panel + predetermined holder regime (5-day trailing mean over prior active days)
egen isin_id = group(isin)
gen date_num = date(business_date, "YMD")
format date_num %td
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

gen hd_sum = 0
gen hd_cnt = 0
forvalues k = 1/5 {
    replace hd_sum = hd_sum + L`k'.holder_dir if !missing(L`k'.holder_dir)
    replace hd_cnt = hd_cnt + 1              if !missing(L`k'.holder_dir)
}
gen holder_dir_pre = hd_sum / hd_cnt if hd_cnt > 0
drop hd_sum hd_cnt
sum holder_dir_pre if hf_intensity_pre > 0, detail
scalar hd_med = r(p50)
gen hd_high = .
replace hd_high = 0 if hf_intensity_pre > 0 & holder_dir_pre <= hd_med & !missing(holder_dir_pre)
replace hd_high = 1 if hf_intensity_pre > 0 & holder_dir_pre >  hd_med & !missing(holder_dir_pre)

* Matchable cells (both HF and non-HF present)
bysort duration_match: egen n_hf   = total(hf_involved == 1)
bysort duration_match: egen n_nohf = total(hf_involved == 0)
gen obs_id = _n

tempfile full hfb nohfb mapp ypanel
save `full', replace

* HF bonds (carry the holder regime tag)
preserve
    keep if hf_involved == 1 & n_hf > 0 & n_nohf > 0
    keep obs_id duration_match isin bid_ask_spread business_date ois_2y hd_high
    rename obs_id hf_obs_id
    rename isin hf_isin
    rename bid_ask_spread hf_bas
    save `hfb', replace
restore

* Non-HF bonds
preserve
    keep if hf_involved == 0 & n_hf > 0 & n_nohf > 0
    keep obs_id duration_match isin bid_ask_spread
    rename obs_id nohf_obs_id
    rename isin nohf_isin
    rename bid_ask_spread nohf_bas
    save `nohfb', replace
restore

* Nearest non-HF match per HF bond by bid-ask (caliper 0.827, with replacement)
use `hfb', clear
joinby duration_match using `nohfb'
gen bas_distance = abs(hf_bas - nohf_bas)
bysort hf_obs_id (bas_distance): keep if _n == 1
drop if bas_distance > 0.827
gen pair_id = _n
keep pair_id hf_isin nohf_isin duration_match business_date ois_2y hd_high
save `mapp', replace

* Yield panel with sequential business-day counter
use `full', clear
keep isin business_date yld_mid date_num
duplicates drop isin business_date, force
sort isin date_num
by isin: gen bday_time = _n
save `ypanel', replace

* t0 business-day index for both legs (same match date)
use `mapp', clear
rename hf_isin isin
merge m:1 isin business_date using `ypanel', keepusing(bday_time) keep(match) nogenerate
rename bday_time hf_bday_t0
rename isin hf_isin
rename nohf_isin isin
merge m:1 isin business_date using `ypanel', keepusing(bday_time) keep(match) nogenerate
rename bday_time nohf_bday_t0
rename isin nohf_isin

* Expand across horizons -5..10
expand 16
bysort pair_id: gen horizon = _n - 6
gen hf_bday_h    = hf_bday_t0   + horizon
gen nohf_bday_h  = nohf_bday_t0 + horizon
gen hf_bday_L1   = hf_bday_t0   - 1
gen nohf_bday_L1 = nohf_bday_t0 - 1

* HF yield at horizon
rename hf_isin isin
rename hf_bday_h bday_time
merge m:1 isin bday_time using `ypanel', keepusing(yld_mid) keep(master match) nogenerate
rename yld_mid hf_yld_h
rename bday_time hf_bday_h
rename isin hf_isin
* HF yield at L1
rename hf_isin isin
rename hf_bday_L1 bday_time
merge m:1 isin bday_time using `ypanel', keepusing(yld_mid) keep(master match) nogenerate
rename yld_mid hf_yld_L1
rename bday_time hf_bday_L1
rename isin hf_isin
* Non-HF yield at horizon
rename nohf_isin isin
rename nohf_bday_h bday_time
merge m:1 isin bday_time using `ypanel', keepusing(yld_mid) keep(master match) nogenerate
rename yld_mid nohf_yld_h
rename bday_time nohf_bday_h
rename isin nohf_isin
* Non-HF yield at L1
rename nohf_isin isin
rename nohf_bday_L1 bday_time
merge m:1 isin bday_time using `ypanel', keepusing(yld_mid) keep(master match) nogenerate
rename yld_mid nohf_yld_L1
rename bday_time nohf_bday_L1
rename isin nohf_isin

gen hf_cumul_dy   = (hf_yld_h   - hf_yld_L1)   * 100
gen nohf_cumul_dy = (nohf_yld_h - nohf_yld_L1) * 100

* LP by horizon, split by holder regime (cluster on duration_match as in the paper)
tempname mh2
tempfile lpm
postfile `mh2' grp horizon beta_hf se_hf beta_nohf se_nohf using `lpm', replace
quietly forvalues g = 0/1 {
    forvalues h = -5/10 {
        reg hf_cumul_dy   ois_2y if horizon == `h' & hd_high == `g', vce(cluster duration_match)
        local bhf = _b[ois_2y]
        local shf = _se[ois_2y]
        reg nohf_cumul_dy ois_2y if horizon == `h' & hd_high == `g', vce(cluster duration_match)
        local bnh = _b[ois_2y]
        local snh = _se[ois_2y]
        post `mh2' (`g') (`h') (`bhf') (`shf') (`bnh') (`snh')
    }
}
postclose `mh2'

use `lpm', clear
foreach v in hf nohf {
    gen ci_up_`v' = beta_`v' + 1.64*se_`v'
    gen ci_lo_`v' = beta_`v' - 1.64*se_`v'
}

* (A) Hedged-held -> saved on its own
twoway (rarea ci_up_hf ci_lo_hf horizon if grp==0, color(red%20) lwidth(none)) ///
       (rarea ci_up_nohf ci_lo_nohf horizon if grp==0, color(blue%20) lwidth(none)) ///
       (line beta_hf horizon if grp==0, color(cranberry) lwidth(thick)) ///
       (line beta_nohf horizon if grp==0, color(navy) lwidth(thick) lpattern(dash)), ///
    yline(0, lcolor(black) lpattern(dash)) xline(0, lcolor(gs10) lpattern(dot)) ///
    ytitle("Cumulative yield response per bp shock") xtitle("Days since shock") ///
    xlabel(-5(1)10) title("Hedged-held") name(lpm_hedged, replace) ///
    legend(order(3 "HF bonds" 4 "Matched non-HF bonds") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white))
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\IR_holder_dir_hedged.png", replace width(2000)

* (B) Directional-held -> saved on its own
twoway (rarea ci_up_hf ci_lo_hf horizon if grp==1, color(red%20) lwidth(none)) ///
       (rarea ci_up_nohf ci_lo_nohf horizon if grp==1, color(blue%20) lwidth(none)) ///
       (line beta_hf horizon if grp==1, color(cranberry) lwidth(thick)) ///
       (line beta_nohf horizon if grp==1, color(navy) lwidth(thick) lpattern(dash)), ///
    yline(0, lcolor(black) lpattern(dash)) xline(0, lcolor(gs10) lpattern(dot)) ///
    ytitle("Cumulative yield response per bp shock") xtitle("Days since shock") ///
    xlabel(-5(1)10) title("Directional-held") name(lpm_directional, replace) ///
    legend(order(3 "HF bonds" 4 "Matched non-HF bonds") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white))
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\IR_holder_dir_directional.png", replace width(2000)


capture log close
