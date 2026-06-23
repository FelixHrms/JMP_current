*** Amplification vs signed repo haircut (descriptive)
clear all
set more off

import delimited "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Data/monetary_policy_induced_position.csv", clear

* panel (for the trailing-mean lag operator)
egen isin_id = group(isin)
gen date_num = date(business_date, "YMD")
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

* predetermined signed haircut: 5-day trailing mean over prior active days
gen hc_sum = 0
gen hc_cnt = 0
forvalues k = 1/5 {
    replace hc_sum = hc_sum + L`k'.holder_haircut if !missing(L`k'.holder_haircut)
    replace hc_cnt = hc_cnt + 1                    if !missing(L`k'.holder_haircut)
}
gen hc_pre = hc_sum / hc_cnt if hc_cnt > 0
drop hc_sum hc_cnt

* HF-held bonds on shock days; yield change signed with the shock
gen present       = (hf_intensity_pre > 0)
gen byte shockday = !missing(ois_2y) & ois_2y != 0
gen dy_dir        = delta_y * sign(ois_2y)
gen byte insamp   = present & !missing(hc_pre) & shockday & !missing(dy_dir)

* distribution + count of literal zero-margin bonds (NULLs already excluded) -> see log
sum hc_pre if insamp & hc_pre != 0, detail
count if insamp & hc_pre == 0

* equal-width bins over the central mass (1st-99th pct of the nonzero haircut).
* hard-set `lo'/`hi'/`nb' if you prefer a fixed range (e.g. -1/1).
quietly sum hc_pre if insamp & hc_pre != 0, detail
local lo = r(p1)
local hi = r(p99)
local nb = 25
local w  = (`hi' - `lo') / `nb'

quietly sum dy_dir if insamp & hc_pre == 0
local z_dir = r(mean)
local z_n   = r(N)

preserve
    keep if insamp & hc_pre != 0 & inrange(hc_pre, `lo', `hi')
    gen int binid = floor((hc_pre - `lo') / `w')
    collapse (mean) dy_dir, by(binid)
    gen hc_x = `lo' + (binid + 0.5) * `w'
    gen byte iszero = 0
    if `z_n' > 0 {
        local k = _N + 1
        set obs `k'
        replace iszero = 1       in `k'
        replace hc_x   = 0       in `k'
        replace dy_dir = `z_dir' in `k'
    }
    twoway (connected dy_dir hc_x if iszero==0, sort lcolor(navy) mcolor(navy) msize(small)) ///
           (scatter   dy_dir hc_x if iszero==1, msymbol(D) mcolor(cranberry) msize(large)), ///
        xline(0, lcolor(gs12)) ///
        ytitle("{&Delta}y {&times} sign(shock)") xtitle("Signed repo haircut") ///
        legend(order(1 "Haircut {&ne} 0" 2 "Zero margin (= 0)") rows(1) position(6) region(lcolor(none))) ///
        graphregion(color(white)) name(gA, replace)
    graph export "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Figures/amp_vs_haircut_descriptive.png", replace width(2200)
restore
