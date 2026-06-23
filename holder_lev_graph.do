********************************************************************************
* AMPLIFICATION vs REPO HAIRCUT  --  documenting the puzzle
*
* Finding: low |haircut| (high leverage) -> LESS amplification. The funds that can
* lever most transmit the policy shock least. This file visualises the SHAPE of
* that relationship in the SIGNED haircut, to distinguish:
*   - a V, symmetric around 0     -> |haircut| (capital intensity / leverage) is the
*                                    right object, as imposed by holder_leverage; or
*   - monotone in signed haircut  -> the effect is counterparty strength on a signed
*                                    scale and the |.| transform is mis-specified.
* 0 / unreported (cross-margined) haircuts are the special case, shown separately.
*
* WHY THE SLOPE / DIRECTIONAL CHANGE, NOT |delta_y|:
* "Amplification" is the sensitivity of the yield change to the shock, d(dy)/d(shock)
* -- the object in the regression triple. |delta_y| is a different thing: it mixes in
*   (i)   the size of each day's shock (big-surprise days move every bond),
*   (ii)  a bond's baseline volatility (long / illiquid bonds have larger |dy| every
*         day, shock or not), and
*   (iii) it discards the sign -- moving WITH the shock (amplification) vs AGAINST it.
* So |delta_y| would partly rank bonds by volatility and days by surprise size, not by
* policy sensitivity. Signing by the shock (delta_y * sign(shock)) and, in the FE
* version, estimating the slope, isolates the response to policy.
*
* Graph A (descriptive): mean directional yield change by signed-haircut bin.
* Graph B (FE-adjusted): per-bin pass-through slope from an interacted reghdfe,
*          matching the within-day x duration x country identification.
********************************************************************************
clear all
set more off

capture log close
log using "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Code/holder_lev_graph.log", replace text

*===============================================================================
* 1. IMPORT + PANEL SETUP  (mirrors holder_lev_analysis.do)
*===============================================================================
import delimited "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Data/monetary_policy_induced_position.csv", clear

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
    graph export "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Figures/amp_vs_haircut_descriptive.png", replace width(2200)
restore

*===============================================================================
* 6. GRAPH B -- FE-adjusted: per-bin pass-through slope d(delta_y)/d(shock)
*    within day x duration x country (duration_match) and bond (isin). The day FE
*    absorbs the shock's level, so the identified object is the DIFFERENCE in
*    pass-through across haircut bins -- exactly the V-vs-monotone question.
*===============================================================================
reghdfe delta_y ib1.hc_bin##c.ois_2y bid_ask_spread ctd_flag if insamp, ///
    absorb(duration_match isin) vce(cluster business_date isin)

tempfile ampslope
tempname P
postfile `P' int bin double(hcx slope lo hi) using "`ampslope'", replace
* base bin (1, most negative haircut): differential normalised to 0
quietly sum holder_haircut_pre if hc_bin==1 & insamp, meanonly
post `P' (1) (r(mean)) (0) (0) (0)
forvalues b = 2/20 {
    capture local sl = _b[`b'.hc_bin#c.ois_2y]
    if !_rc {
        local se = _se[`b'.hc_bin#c.ois_2y]
        quietly sum holder_haircut_pre if hc_bin==`b' & insamp, meanonly
        post `P' (`b') (r(mean)) (`sl') (`sl' - 1.96*`se') (`sl' + 1.96*`se')
    }
}
postclose `P'

preserve
    use "`ampslope'", clear
    twoway (rarea lo hi hcx, sort color(navy%20)) ///
           (line  slope hcx, sort lcolor(navy) lwidth(medthick)), ///
        yline(0, lpattern(dash) lcolor(gs8)) ///
        xline(0, lpattern(solid) lcolor(gs10)) ///
        ytitle("Pass-through slope vs base bin  {&Delta}[d({&Delta}y)/d(shock)]") ///
        xtitle("Holder-weighted signed repo haircut (predetermined)") ///
        legend(off) ///
        note("Within day x duration x country and bond FE. Slope relative to the" ///
             "most-negative-haircut bin (level absorbed by the day FE). 95% CI.") ///
        graphregion(color(white)) name(gB, replace)
    graph export "/Users/felixhermes/Library/CloudStorage/OneDrive-Personal/PhD/JobMarket/Figures/amp_vs_haircut_slope.png", replace width(2200)
restore

capture log close
