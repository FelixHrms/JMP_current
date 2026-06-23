*** Amplification vs repo haircut -- descriptive (restored to the original)
clear all
set more off

* edit this one line if the project folder moves
global proj "C:/Users/hermesf/Projects/JobMarket/Empirics"

capture log close
log using "$proj/holder_lev_graph.log", replace text

*===============================================================================
* 1. IMPORT + PANEL SETUP  (mirrors holder_lev_analysis.do)
*===============================================================================
import delimited "$proj/monetary_policy_induced_position.csv", clear

encode collateral_country, gen(col_cntr)
gen duration_bin   = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen log_hf_intensity = log(1 + hf_intensity_pre)

egen isin_id  = group(isin)
gen date_num  = date(business_date, "YMD")
format date_num %td
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

*===============================================================================
* 2. PREDETERMINED SIGNED HAIRCUT  (5-day trailing mean over prior ACTIVE days,
*    matching how the regressors are built in holder_lev_analysis.do)
*===============================================================================
foreach v in holder_haircut holder_leverage {
    capture confirm variable `v'
    if _rc {
        di as error "`v' not found -- re-run empirics_v1.ipynb to regenerate the CSV"
        exit 111
    }
    gen `v'_sum = 0
    gen `v'_cnt = 0
    forvalues k = 1/5 {
        replace `v'_sum = `v'_sum + L`k'.`v' if !missing(L`k'.`v')
        replace `v'_cnt = `v'_cnt + 1        if !missing(L`k'.`v')
    }
    gen `v'_pre = `v'_sum / `v'_cnt if `v'_cnt > 0
    drop `v'_sum `v'_cnt
}

gen present = (hf_intensity_pre > 0)

* Graph sample: HF-held bonds with a (predetermined) signed haircut. The special
* 0/unreported group is "present & missing(holder_haircut_pre)" -> shown separately.
gen byte insamp = present & !missing(holder_haircut_pre)

*===============================================================================
* 3. SHOCK DAYS + DIRECTIONAL YIELD CHANGE
*===============================================================================
* ois_2y is the same 2-year OIS surprise used in the regressions. Shock days =
* non-zero, non-missing surprise. If ois_2y is a daily change rather than an
* event-day surprise, raise `shockcut' to focus on large moves / announcements.
local shockcut = 0
gen byte shockday = !missing(ois_2y) & abs(ois_2y) > `shockcut'

* yield change in the DIRECTION of the shock: >0 means the bond moved with policy
gen dy_dir = delta_y * sign(ois_2y)

*===============================================================================
* 4. SIGNED-HAIRCUT BINS  (equal mass -> robust to haircut units)
*===============================================================================
xtile hc_bin = holder_haircut_pre if insamp, nq(20)

*===============================================================================
* 5. GRAPH A -- descriptive: directional yield change by signed-haircut bin
*===============================================================================
* no-HF baseline (the regression's reference group) for orientation
quietly sum dy_dir if present==0 & shockday
local base = r(mean)

* the special 0/unreported group, plotted as a single marker at haircut = 0
quietly sum dy_dir if present & missing(holder_haircut_pre) & shockday
local zero_dir = r(mean)
local zero_n   = r(N)

preserve
    keep if insamp & shockday & !missing(dy_dir)
    collapse (mean) dy_dir hc_x = holder_haircut_pre (count) n = dy_dir, by(hc_bin)
    gen byte iszero = 0
    if `zero_n' > 0 {
        local k = _N + 1
        set obs `k'
        replace iszero = 1          in `k'
        replace hc_x   = 0          in `k'
        replace dy_dir = `zero_dir' in `k'
    }
    twoway (connected dy_dir hc_x if iszero==0, sort lcolor(navy) mcolor(navy) msize(small)) ///
           (scatter   dy_dir hc_x if iszero==1, msymbol(D) mcolor(cranberry) msize(large)), ///
        yline(`base', lpattern(dash) lcolor(gs8)) ///
        xline(0, lpattern(solid) lcolor(gs10)) ///
        ytitle("Mean directional yield change  {&Delta}y {&times} sign(shock)") ///
        xtitle("Holder-weighted signed repo haircut (predetermined)") ///
        legend(order(1 "HF-held, by haircut" 2 "0 / unreported haircut") rows(1)) ///
        note("Dashed grey: no-HF baseline. Shock days only. Higher = more amplification.") ///
        graphregion(color(white)) name(gA, replace)
    graph export "$proj/amp_vs_haircut_descriptive.png", replace width(2200)
restore

capture log close
