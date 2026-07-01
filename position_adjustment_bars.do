********************************************************************************
* POSITION ADJUSTMENT BY REGIME  —  Figure for Result 4 (symmetry)
* "Positions adjust in both regimes -> the yield response is symmetric"
*
* Input : Data\monetary_policy_induced_position.csv  (build\build_main_panel.ipynb)
* Output: Figures\position_adjustment_bars.png
*
* Two bars: the average adjustment of the hedge fund's book over the 10 business
* days after a shock, for the constraining vs the relaxing regime.
*   borrowing_volume = long book,  lending_volume = short book (each in EUR bn).
*   Relaxing    (shock helps): long & easing,     or short & tightening
*   Constraining(shock hurts): long & tightening, or short & easing
*
* The raw 10-day change in a book is negative for every group, because measuring a
* forward change conditional on the book existing (pre > 0) mechanically mean-reverts
* down (and HF books trend down over the sample). To put "0 = no shock effect", each
* observation is expressed RELATIVE TO THE AVERAGE 10-DAY CHANGE ON NON-SHOCK DAYS
* for the same positions, so that common drift cancels out. Raw means, no CIs.
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear

* 2. One observation per bond-day, then a within-bond trading-day index for leads/lags
egen isin_id  = group(isin)
gen  date_num = date(business_date, "YMD")
format date_num %td
collapse (firstnm) borrowing_volume lending_volume ois_2y, by(isin_id date_num)

sort isin_id date_num
by isin_id: gen bday_time = _n
xtset isin_id bday_time

* 3. Books in EUR bn, and their change over the window (entering shock -> +10 days)
replace borrowing_volume = borrowing_volume/1e9
replace lending_volume   = lending_volume/1e9

gen pre_borrow = L1.borrowing_volume
gen pre_lend   = L1.lending_volume
gen d_borrow   = F10.borrowing_volume - L1.borrowing_volume
gen d_lend     = F10.lending_volume   - L1.lending_volume

* 4. Net out the normal-day drift (same positions) so 0 = no shock effect
summarize d_borrow if pre_borrow > 0 & ois_2y == 0
gen exc_borrow = d_borrow - r(mean)
summarize d_lend   if pre_lend   > 0 & ois_2y == 0
gen exc_lend   = d_lend   - r(mean)

* 5. Stack the two books, tag each shock event by regime (1 = constraining, 2 = relaxing)
preserve
    keep if pre_borrow > 0 & ois_2y != 0
    gen adj    = exc_borrow
    gen regime = cond(ois_2y < 0, 2, 1)   // long: easing -> relaxing, tightening -> constraining
    keep adj regime
    tempfile tb
    save `tb'
restore
keep if pre_lend > 0 & ois_2y != 0
gen adj    = exc_lend
gen regime = cond(ois_2y > 0, 2, 1)       // short: tightening -> relaxing, easing -> constraining
keep adj regime
append using `tb'

label define regime_lbl 1 "Constraining" 2 "Relaxing"
label values regime regime_lbl

* 6. Two simple bars
collapse (mean) adj, by(regime)

twoway (bar adj regime if regime == 1, barwidth(0.6) color(cranberry)) ///
       (bar adj regime if regime == 2, barwidth(0.6) color(forest_green)), ///
    yline(0, lcolor(black) lwidth(thin)) ///
    xlabel(1 "Constraining" 2 "Relaxing", noticks) xscale(range(0.5 2.5)) ///
    ytitle("Change in book volume over 10 days (EUR bn)") ///
    subtitle("relative to a normal (non-shock) day", size(small) color(gs7)) xtitle("") ///
    legend(off) graphregion(color(white)) name(pos_adj, replace)
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\position_adjustment_bars.png", replace width(2000)
