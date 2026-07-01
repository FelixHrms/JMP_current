********************************************************************************
* POSITION ADJUSTMENT BY REGIME  —  Figure for Result 4 (symmetry)
* "Positions adjust in both regimes -> the yield response is symmetric"
*
* Input : Data\monetary_policy_induced_position.csv  (build\build_main_panel.ipynb)
* Output: Figures\position_adjustment_bars.png
*
* Two bars = the average change in the hedge fund's own book, in EUR bn, from the
* day before a shock (t-1) to 10 business days after (t+10):
*   bonds that were long  (is_long_pre)  -> change in borrowing_volume
*   bonds that were short (is_short_pre) -> change in lending_volume
* averaged within each regime:
*   Constraining (shock hurts): long & tightening, or short & easing
*   Relaxing     (shock helps): long & easing,     or short & tightening
* Raw averages. Nothing subtracted.
********************************************************************************

clear all

import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear

* One observation per bond-day, then a within-bond trading-day index for leads/lags
egen isin_id  = group(isin)
gen  date_num = date(business_date, "YMD")
format date_num %td
collapse (firstnm) borrowing_volume lending_volume is_long_pre is_short_pre ois_2y, by(isin_id date_num)
sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

* Change in the book over the window, in EUR bn (billions)
gen d_borrow = (F10.borrowing_volume - L1.borrowing_volume)/1e9
gen d_lend   = (F10.lending_volume   - L1.lending_volume)/1e9

* Each bond's own book: borrowing if it was long, lending if it was short
gen adj = .
replace adj = d_borrow if is_long_pre  == 1
replace adj = d_lend   if is_short_pre == 1

* Regime at the shock
gen regime = .
replace regime = 1 if is_long_pre  == 1 & ois_2y > 0   // constraining: long & tightening
replace regime = 1 if is_short_pre == 1 & ois_2y < 0   // constraining: short & easing
replace regime = 2 if is_long_pre  == 1 & ois_2y < 0   // relaxing: long & easing
replace regime = 2 if is_short_pre == 1 & ois_2y > 0   // relaxing: short & tightening
label define regime_lbl 1 "Constraining" 2 "Relaxing"
label values regime regime_lbl

* --- DIAGNOSTIC: is the negativity just background drift? -----------------------
* Average 10-day book change on NON-shock days (ois_2y==0). If these are negative
* too, the negative bars are a within-bond lifecycle drift (positions roll off as
* bonds age), not the shock. Compare with the shock-day averages just below.
di as txt "Non-shock days (background drift):"
summarize d_borrow if is_long_pre  == 1 & ois_2y == 0
summarize d_lend   if is_short_pre == 1 & ois_2y == 0
di as txt "Shock days:"
summarize d_borrow if is_long_pre  == 1 & ois_2y != 0
summarize d_lend   if is_short_pre == 1 & ois_2y != 0
* -------------------------------------------------------------------------------

keep if !missing(regime, adj)
tab regime

* Two bars: one average per regime
graph bar (mean) adj, over(regime) ///
    bar(1, color(navy)) blabel(bar, format(%9.3f)) ///
    ytitle("Avg change in book, day -1 to +10 (EUR bn)") ///
    graphregion(color(white)) name(pos_adj, replace)
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\position_adjustment_bars.png", replace width(2000)
