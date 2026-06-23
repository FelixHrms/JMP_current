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

* HF-held bonds on shock days; yield change signed with the shock (higher = more amplification)
gen present       = (hf_intensity_pre > 0)
gen byte shockday = !missing(ois_2y) & ois_2y != 0
gen dy_dir        = delta_y * sign(ois_2y)

* fixed-width signed-haircut bins over [-1, 1]; NULL haircuts excluded, literal 0 kept
local w = 0.1
preserve
    keep if present & !missing(hc_pre) & shockday & !missing(dy_dir) & inrange(hc_pre, -1, 1)
    gen int binid = floor(hc_pre/`w')
    collapse (mean) dy_dir, by(binid)
    gen hc_x = binid*`w' + `w'/2
    twoway (connected dy_dir hc_x, sort lcolor(navy) mcolor(navy) msize(small)), ///
        xline(0, lcolor(gs12)) ///
        ytitle("{&Delta}y {&times} sign(shock)") xtitle("Signed repo haircut") ///
        legend(off) graphregion(color(white)) name(gA, replace)
    graph export "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Figures/amp_vs_haircut_descriptive.png", replace width(2200)
restore
