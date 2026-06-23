*** Amplification vs signed repo haircut: V (|haircut|/leverage) or monotone?
clear all
set more off

import delimited "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Data/monetary_policy_induced_position.csv", clear

* panel
gen duration_bin   = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
egen isin_id  = group(isin)
gen date_num  = date(business_date, "YMD")
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

gen present     = (hf_intensity_pre > 0)
gen byte insamp = present & !missing(hc_pre)

* shock days + yield change signed with the shock (higher = more amplification)
gen byte shockday = !missing(ois_2y) & ois_2y != 0
gen dy_dir = delta_y * sign(ois_2y)

* equal-mass signed-haircut bins
xtile hc_bin = hc_pre if insamp, nq(20)


*** Graph A: directional yield change by signed-haircut bin
quietly sum dy_dir if present & missing(hc_pre) & shockday
local zero_dir = r(mean)
local zero_n   = r(N)

preserve
    keep if insamp & shockday & !missing(dy_dir)
    collapse (mean) dy_dir hc_x=hc_pre, by(hc_bin)
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
        xline(0, lcolor(gs12)) ///
        ytitle("{&Delta}y {&times} sign(shock)") xtitle("Signed repo haircut") ///
        legend(order(1 "HF-held" 2 "0 / unreported") rows(1) position(6) region(lcolor(none))) ///
        graphregion(color(white)) name(gA, replace)
    graph export "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Figures/amp_vs_haircut_descriptive.png", replace width(2200)
restore


*** Graph B: FE-adjusted pass-through slope by signed-haircut bin
reghdfe delta_y ib1.hc_bin##c.ois_2y bid_ask_spread ctd_flag if insamp, ///
    absorb(duration_match isin) vce(cluster business_date isin)

tempfile ampslope
tempname P
postfile `P' int bin double(hcx slope lo hi) using "`ampslope'", replace
quietly sum hc_pre if hc_bin==1 & insamp, meanonly
post `P' (1) (r(mean)) (0) (0) (0)
forvalues b = 2/20 {
    capture local sl = _b[`b'.hc_bin#c.ois_2y]
    if !_rc {
        local se = _se[`b'.hc_bin#c.ois_2y]
        quietly sum hc_pre if hc_bin==`b' & insamp, meanonly
        post `P' (`b') (r(mean)) (`sl') (`sl' - 1.96*`se') (`sl' + 1.96*`se')
    }
}
postclose `P'

preserve
    use "`ampslope'", clear
    twoway (rarea lo hi hcx, sort color(navy%20)) ///
           (line  slope hcx, sort lcolor(navy) lwidth(medthick)), ///
        yline(0, lcolor(gs12)) xline(0, lcolor(gs12)) ///
        ytitle("Pass-through slope (vs base bin)") xtitle("Signed repo haircut") ///
        legend(off) graphregion(color(white)) name(gB, replace)
    graph export "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Figures/amp_vs_haircut_slope.png", replace width(2200)
restore
