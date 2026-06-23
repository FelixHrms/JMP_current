*** Amplification vs signed repo haircut (descriptive, equal-mass bins)
clear all
set more off

* edit this one line if the project folder moves
global proj "C:/Users/hermesf/Projects/JobMarket/Empirics"

import delimited "$proj/monetary_policy_induced_position.csv", clear

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

* distribution of the nonzero haircut + count of zero-margin bonds -> see log
sum hc_pre if insamp & hc_pre != 0, detail
count if insamp & hc_pre == 0

* zero-margin (literal 0) summary on the full sample, shown as its own point
quietly sum dy_dir if insamp & hc_pre == 0
local z_dir = r(mean)
local z_n   = r(N)

* equal-mass bins over NONZERO haircuts (0 is a mass point -> kept separate)
local nq = 20
xtile hc_bin = hc_pre if insamp & hc_pre != 0, nq(`nq')

preserve
    keep if insamp & hc_pre != 0 & !missing(hc_bin)
    collapse (mean) dy_dir (mean) hc_mean = hc_pre (count) n = dy_dir, by(hc_bin)
    sort hc_bin
    list hc_bin hc_mean n, sep(0) noobs

    * even-spaced axis = bin rank; label a few ticks with the actual haircut value
    gen double xpos = hc_bin
    local xlab ""
    foreach b in 1 5 10 15 `nq' {
        quietly count if hc_bin == `b'
        if r(N) {
            quietly sum hc_mean if hc_bin == `b', meanonly
            local v = string(r(mean), "%4.2f")
            local xlab `xlab' `b' "`v'"
        }
    }

    * place the zero-margin point at its rank (between the negative and positive bins)
    quietly count if hc_mean < 0
    local zx = r(N) + 0.5
    gen byte iszero = 0
    if `z_n' > 0 {
        local k = _N + 1
        set obs `k'
        replace xpos   = `zx'    in `k'
        replace dy_dir = `z_dir' in `k'
        replace iszero = 1       in `k'
    }

    twoway (connected dy_dir xpos if iszero==0, sort lcolor(navy) mcolor(navy) msize(small)) ///
           (scatter   dy_dir xpos if iszero==1, msymbol(D) mcolor(cranberry) msize(large)), ///
        yline(0, lcolor(gs12)) ///
        ytitle("{&Delta}y {&times} sign(shock)") ///
        xtitle("Signed repo haircut (equal-mass bins, value at tick)") ///
        xlabel(`xlab', labsize(small)) ///
        legend(order(1 "Haircut {&ne} 0" 2 "Zero margin") rows(1) position(6) region(lcolor(none))) ///
        graphregion(color(white)) name(gA, replace)
    graph export "$proj/amp_vs_haircut_descriptive.png", replace width(2200)
restore
