********************************************************************************
* ANNOUNCEMENT-LEVEL EVIDENCE  (discussant slide 19)
* Requires: matched_sample.do must have been run, so that Data\match_map.dta
*           and Data\matched_sample_full.dta exist. Reads intermediates only.
* Produces: (1) Figure: per-announcement matched HF differential vs surprise
*               (Figures\Announcement_scatter.png) + day-level slope;
*           (2) Randomization inference on the shock dates (fast, day level;
*               Figures\RI_distribution.png + exact p-value);
*           (3) Leave-one-out estimates of the baseline specification
*               (Table IV Column 4), dropping one announcement at a time.
*               NOTE: section (3) runs 38 reghdfe's on the full panel and is
*               the slow block (~15-40 min); (1) and (2) run in ~2 minutes.
********************************************************************************

clear all

********************************************************************************
* 1. Daily series of the matched HF-minus-control differential (all days)
********************************************************************************

use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\match_map.dta", clear

rename hf_obs_id obs_id
merge m:1 obs_id using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", ///
    keepusing(business_date ois_2y delta_y) keep(match) nogenerate
rename delta_y hf_dy
rename obs_id hf_obs_id

rename nohf_obs_id obs_id
merge m:1 obs_id using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\matched_sample_full.dta", ///
    keepusing(delta_y) keep(match) nogenerate
rename delta_y nohf_dy
rename obs_id nohf_obs_id

gen d_pair = hf_dy - nohf_dy

collapse (mean) D = d_pair ois_2y (count) n_pairs = d_pair, by(business_date)

gen date_num = date(business_date, "YMD")
format date_num %td
gen year = year(date_num)
gen is_ann = (ois_2y != 0)

save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\daily_differential.dta", replace

********************************************************************************
* 2. Figure: one point per announcement + day-level slope
*    Marker size proportional to the number of pairs behind each point.
********************************************************************************

use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\daily_differential.dta", clear
keep if is_ann

quietly count
di as text "number of announcements : " as result r(N)

* Day-level slope (should be close to the matched panel estimate)
reg D ois_2y, robust
local b_actual = _b[ois_2y]
di as text "day-level slope         : " as result %9.4f `b_actual'

* Pair-weighted slope, for reference
reg D ois_2y [aweight = n_pairs], robust

twoway (scatter D ois_2y [aweight = n_pairs], ///
            msymbol(circle_hollow) mcolor(cranberry) mlwidth(medthick)) ///
       (lfit D ois_2y, lcolor(navy) lwidth(medthick)), ///
       yline(0, lcolor(gs10) lpattern(dash)) ///
       xline(0, lcolor(gs10) lpattern(dash)) ///
       ytitle("Matched HF {&minus} non-HF yield change (bps)") ///
       xtitle("Monetary policy surprise (bps)") ///
       legend(off) ///
       graphregion(color(white))
graph export "C:\\Users\\hermesf\\Projects\\JobMarket\\Figures\\Announcement_scatter.png", replace width(2000)

********************************************************************************
* 3. Randomization inference on the shock dates
*    Under the null, the announcement dates are arbitrary: draw the same
*    number of placebo days per calendar year from non-announcement days,
*    assign them that year's actual surprise values, re-estimate the
*    day-level slope. Exact p-value = share of |placebo slopes| >= |actual|.
********************************************************************************

local RIREPS = 1000

* Actual surprises, indexed within year
use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\daily_differential.dta", clear
keep if is_ann
sort year date_num
by year: gen j = _n
keep year j ois_2y
rename ois_2y s_actual
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\ann_surprises.dta", replace

use "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\daily_differential.dta", clear

set seed 20260826
tempname RI
tempfile ri_out
postfile `RI' rep b using `ri_out', replace

forvalues r = 1/`RIREPS' {
    quietly {
        preserve
            keep if is_ann == 0
            gen u = runiform()
            sort year u
            by year: gen j = _n
            merge 1:1 year j using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\ann_surprises.dta", ///
                keep(match) nogenerate
            reg D s_actual
            post `RI' (`r') (_b[s_actual])
        restore
    }
}
postclose `RI'

use `ri_out', clear
summarize b, detail
count if abs(b) >= abs(`b_actual')
local p_ri = r(N) / `RIREPS'
di as text "actual day-level slope   : " as result %9.4f `b_actual'
di as text "randomization p-value    : " as result %9.4f `p_ri'

histogram b, bin(50) color(navy%50) ///
    xline(`b_actual', lcolor(cranberry) lwidth(thick)) ///
    xtitle("Placebo day-level slope") ytitle("Density") ///
    graphregion(color(white)) legend(off)
graph export "C:\\Users\\hermesf\\Projects\\JobMarket\\Figures\\RI_distribution.png", replace width(2000)

********************************************************************************
* 4. Leave-one-out: baseline specification (Table IV Column 4), dropping one
*    announcement day at a time.  SLOW BLOCK: 38 reghdfe's on the full panel.
********************************************************************************

import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

gen duration_bin = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country

levelsof business_date if ois_2y != 0, local(anndates)

tempname LOO
tempfile loo_out
postfile `LOO' str12 dropped b se using `loo_out', replace

foreach d of local anndates {
    quietly reghdfe delta_y i.hf_involved##c.ois_2y bid_ask_spread ctd_flag ///
        if business_date != "`d'", ///
        absorb(isin duration_match) vce(cluster business_date isin)
    post `LOO' ("`d'") (_b[1.hf_involved#c.ois_2y]) (_se[1.hf_involved#c.ois_2y])
    di as text "dropped `d' : " as result %7.4f _b[1.hf_involved#c.ois_2y]
}
postclose `LOO'

use `loo_out', clear
gen t = b / se
summarize b, detail
sort b
list dropped b se t in 1/5
gsort -b
list dropped b se t in 1/5
quietly count if abs(t) < 2.576
di as text "estimates losing 1% significance when one announcement is dropped : " as result r(N)
