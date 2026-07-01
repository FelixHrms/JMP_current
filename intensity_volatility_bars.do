********************************************************************************
* INTENSITY & VOLATILITY  —  Figure for Result 1 (slide walkthrough 1)
* "Bonds hedge funds hold are more volatile, but only on shock days"
*
* Input : Data\monetary_policy_induced_position.csv  (build\build_main_panel.ipynb)
* Output: Figures\intensity_volatility_bars.png
*
* Discrete, visual twin of the Table III spec in selection_volatility.do:
*     reghdfe abs_delta_y i.hf_involved##c.abs_shock ..., absorb(isin duration_match)
* Continuous HF intensity -> quartiles of hf_intensity_pre (+ a no-HF reference);
* the continuous |shock| -> a shock-day / regular-day split (shock_day = ois_2y != 0,
* matching the build notebook's day_type). Bars are ADJUSTED |dy| LEVELS, built as
*
*     level(q, day type) = observed no-HF mean(day type) + differential(q, day type)
*
* where the differential is the within-cell coefficient on quartile q relative to the
* no-HF category, absorbing duration x collateral-country x date (duration_match) and
* bond (isin) fixed effects. So each no-HF bar is the observed baseline volatility and
* the Q1-Q4 increments are FE-adjusted (net of duration x country x date x bond, plus
* the paper's bid_ask_spread / ctd_flag controls). Because date sits inside the FE, the
* increments are identified purely cross-sectionally within a day: flat on regular days
* (no selection), rising on shock days (amplification). 90% CIs on the increments.
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

* 2. Setup (mirrors selection_volatility.do)
gen duration_bin   = floor(duration / 2) * 2
gen duration_match = string(duration_bin) + "_" + business_date + "_" + collateral_country
gen abs_delta_y    = abs(delta_y)
gen shock_day      = (ois_2y != 0)          // shock day iff there is a monetary surprise

* 3. Hedge fund intensity buckets: quartiles among the involved, plus a no-HF reference
xtile hf_q = hf_intensity_pre if hf_intensity_pre > 0, nq(4)
replace hf_q = 0 if hf_intensity_pre == 0   // 0 = no hedge fund involvement (reference)
label define hf_q_lbl 0 "No HF" 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4"
label values hf_q hf_q_lbl
tab hf_q shock_day

* 4. Collect adjusted levels: no-HF baseline + FE-adjusted differential, by day type
tempname M
tempfile bars
postfile `M' daytype q level cilo cihi using `bars', replace

forvalues t = 0/1 {
    * observed baseline volatility for the no-HF reference on this day type
    summarize abs_delta_y if hf_q == 0 & shock_day == `t', meanonly
    local base = r(mean)
    post `M' (`t') (0) (`base') (.) (.)     // reference bar (anchor, no CI)

    * differentials vs no-HF within duration x country x date x bond cells
    * (drop isin below, or the two controls, for a leaner FE if preferred)
    reghdfe abs_delta_y ib0.hf_q bid_ask_spread ctd_flag if shock_day == `t', ///
        absorb(duration_match isin) vce(cluster business_date isin)
    forvalues q = 1/4 {
        local b  = _b[`q'.hf_q]
        local se = _se[`q'.hf_q]
        post `M' (`t') (`q') (`base'+`b') (`base'+`b'-1.64*`se') (`base'+`b'+1.64*`se')
    }
}
postclose `M'

* 5. Grouped bar chart: two bars per intensity bucket (regular vs shock days)
use `bars', clear
gen xpos = q*3 + cond(daytype == 1, 1.4, 0.6)   // 2 bars per bucket, buckets 3 apart

twoway (bar level xpos if daytype == 0, barwidth(0.7) color(navy)) ///
       (bar level xpos if daytype == 1, barwidth(0.7) color(cranberry)) ///
       (rcap cihi cilo xpos if daytype == 0, lcolor(gs7) msize(small)) ///
       (rcap cihi cilo xpos if daytype == 1, lcolor(gs7) msize(small)), ///
    xlabel(1 "No HF" 4 "Q1" 7 "Q2" 10 "Q3" 13 "Q4", noticks) ///
    ytitle("Adjusted |{&Delta}y| (bp)") xtitle("Hedge fund intensity (pre-shock)") ///
    legend(order(1 "Regular days" 2 "Shock days") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) plotregion(margin(b=0)) ///
    name(intensity_vol, replace)
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\intensity_volatility_bars.png", replace width(2000)
