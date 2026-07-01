********************************************************************************
* POSITION ADJUSTMENT BY REGIME  —  Figure for Result 4 (symmetry)
* "Positions adjust in both regimes -> the yield response is symmetric"
*
* Input : Data\monetary_policy_induced_position.csv  (build\build_main_panel.ipynb)
* Output: Figures\position_adjustment_bars.png
*
* Two simple bars: the average change in the hedge fund's position SIZE around a
* shock (from the position held going into the shock through 10 business days
* after), split by regime. This is the h=10 endpoint of position_irf_momentum.do,
* shown as raw group means instead of the full impulse response.
*
* Regimes (as in Table VIII / position_irf_momentum.do):
*   Constraining = shock hurts the position: long & tightening, or short & easing
*   Relaxing     = shock helps the position: long & easing,    or short & tightening
*
* Outcome = change in position SIZE in EUR bn, |net_pos|(t+10) - |net_pos|(t-1).
* Using size (absolute value) keeps longs and shorts from cancelling within a
* regime: a shrinking long and a covering short both read as a negative change
* (deleveraging). net_pos is (borrowing - lending) in EUR bn.
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear

* 2. One observation per bond-day, then a within-bond trading-day index for leads/lags
egen isin_id  = group(isin)
gen  date_num = date(business_date, "YMD")
format date_num %td
collapse (firstnm) net_pos is_long_pre is_short_pre ois_2y, by(isin_id date_num)

sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

* 3. Change in position size from entering the shock (t-1) to 10 days after (t+10)
gen size       = abs(net_pos)              // position size, EUR bn
gen delta_size = F10.size - L1.size        // total change over the window, EUR bn

* 4. Regime at the shock (direction entering the shock x sign of the surprise)
gen regime = .
replace regime = 1 if ois_2y > 0 & is_long_pre  == 1   // constraining: long & tightening
replace regime = 1 if ois_2y < 0 & is_short_pre == 1   // constraining: short & easing
replace regime = 2 if ois_2y > 0 & is_short_pre == 1   // relaxing: short & tightening
replace regime = 2 if ois_2y < 0 & is_long_pre  == 1   // relaxing: long & easing
label define regime_lbl 1 "Constraining" 2 "Relaxing"
label values regime regime_lbl

* keep shock events (nonzero surprise, HF holds the bond) with a computable window
keep if !missing(regime) & !missing(delta_size)
tab regime

* 5. Average adjustment per regime, with 90% confidence whiskers
collapse (mean) mean_ds=delta_size (semean) se_ds=delta_size (count) n=delta_size, by(regime)
gen hi = mean_ds + 1.64*se_ds
gen lo = mean_ds - 1.64*se_ds

* 6. Two simple bars
twoway (bar mean_ds regime if regime == 1, barwidth(0.6) color(navy)) ///
       (bar mean_ds regime if regime == 2, barwidth(0.6) color(maroon)) ///
       (rcap hi lo regime, lcolor(gs7) msize(small)), ///
    yline(0, lcolor(black) lwidth(thin)) ///
    xlabel(1 "Constraining" 2 "Relaxing", noticks) xscale(range(0.5 2.5)) ///
    ytitle("Change in position size over 10 days (EUR bn)") xtitle("") ///
    legend(off) graphregion(color(white)) name(pos_adj, replace)
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\position_adjustment_bars.png", replace width(2000)
