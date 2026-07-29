********************************************************************************
* UNIFIED SIZE PROFILE  —  pooled shock, estimated threshold, flatness test
********************************************************************************
* Input : Data\release_shocks.csv, Data\macro_shock.dta, Data\tail_shock.dta,
*         Data\monetary_policy_induced_position.csv
* Output: Data\pooled_shock.dta, Data\threshold_grid.csv (SSR profile over tau),
*         unified threshold table (flat slope above tau-hat, convexity term,
*         policy-type premium) — replaces the patchwork exhibit.
*
* Design: ONE daily shock series S on a consistent daily measurement basis:
*   release days -> fitted release shock; tail days -> residualized unscheduled
*   component; ECB days -> daily OIS change (intraday EA-MPD variant as
*   robustness in Section 4); components are mutually exclusive by construction.
* The activation threshold tau is ESTIMATED by grid search (Hansen-style
* threshold regression), not imposed. Run sections top-to-bottom.
********************************************************************************

clear all

********************************************************************************
* 1. Pooled daily shock series
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\release_shocks.csv", clear
keep date d_ois2y_bp ecb_day n_releases
rename date business_date
merge 1:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\macro_shock.dta", keep(master match) nogen
merge 1:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\tail_shock.dta", keep(master match) nogen

gen double S = 0
replace S = S + macro_shock if !missing(macro_shock)     // release-explained news
replace S = S + tail_shock  if !missing(tail_shock)      // unscheduled tail news
replace S = d_ois2y_bp      if ecb_day == 1              // MP events, daily basis

* source tag for the type split (mutually exclusive by construction; a day
* with both release and tail components is tagged by its larger part)
gen byte policy_day = (ecb_day == 1)
gen src = "none"
replace src = "release" if !missing(macro_shock) & macro_shock != 0
replace src = "tail"    if !missing(tail_shock)  & tail_shock  != 0 ///
    & abs(tail_shock) > abs(cond(missing(macro_shock), 0, macro_shock))
replace src = "policy"  if ecb_day == 1
tab src

keep business_date S policy_day
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\pooled_shock.dta", replace

********************************************************************************
* 2. Threshold estimation by grid search
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\pooled_shock.dta", keep(match) nogen

encode collateral_country, gen(col_cntr)
gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

* grid over tau (bp). Clustering does not affect RSS -> plain absorb in the
* loop for speed; clustered inference at tau-hat in Section 3.
gen double thr_shock = .
tempname results
postfile `results' tau rss beta using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\threshold_grid_post.dta", replace
foreach tau of numlist 0(0.2)3 {
    quietly replace thr_shock = S * (abs(S) > `tau')
    quietly reghdfe delta_y c.log_hf_intensity##c.thr_shock duration bid_ask_spread ctd_flag, ///
        absorb(duration_match isin)
    post `results' (`tau') (e(rss)) (_b[c.log_hf_intensity#c.thr_shock])
    di as text "tau = " %4.1f `tau' "   rss = " %14.2f e(rss) ///
        "   beta = " %7.4f _b[c.log_hf_intensity#c.thr_shock]
}
postclose `results'

preserve
use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\threshold_grid_post.dta", clear
sort rss
list in 1/5, noobs clean          // tau-hat = top row
export delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\threshold_grid.csv", replace
restore

********************************************************************************
* 3. Unified specification at tau-hat
********************************************************************************
* Set from the grid output above, then run this section.
local tauhat = 1.0        // <-- REPLACE with the argmin tau from Section 2

replace thr_shock = S * (abs(S) > `tauhat')

* 3.1 headline: flat slope above the estimated threshold
reghdfe delta_y c.log_hf_intensity##c.thr_shock duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* 3.2 flatness above the threshold: convexity term in one spec
gen double thr_size   = thr_shock * abs(S)
gen double hf_absthr  = log_hf_intensity * abs(thr_shock)
reghdfe delta_y c.log_hf_intensity c.log_hf_intensity#c.thr_shock hf_absthr ///
    c.log_hf_intensity#c.thr_size duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)

* 3.3 type premium inside the same spec: policy days vs news/risk days
gen double thr_policy = thr_shock * policy_day
gen double hf_policy  = log_hf_intensity * policy_day
reghdfe delta_y c.log_hf_intensity hf_policy c.log_hf_intensity#c.thr_shock ///
    c.log_hf_intensity#c.thr_policy duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
test c.log_hf_intensity#c.thr_policy == 0     // policy premium

********************************************************************************
* 4. Robustness: intraday EA-MPD measurement on ECB days
********************************************************************************
* The panel's ois_2y is the intraday MP surprise (0 off-meetings).
gen double S_intra = S
replace S_intra = ois_2y if policy_day == 1
gen double thr_intra = S_intra * (abs(S_intra) > `tauhat')
reghdfe delta_y c.log_hf_intensity##c.thr_intra duration bid_ask_spread ctd_flag, ///
    absorb(duration_match isin) vce(cluster business_date isin)
