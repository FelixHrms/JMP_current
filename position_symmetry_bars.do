********************************************************************************
* AGGREGATE BOOK ADJUSTMENT BY REGIME  —  Figure for Result 3 (slide walkthrough 3)
* "The effect is symmetric, whether the shock helps or hurts the position"
*
* Input : Data\monetary_policy_induced_position.csv  (build\build_main_panel.ipynb)
* Output: Figures\position_symmetry_bars.png
*
* One aggregate sector book per day and side. Cash borrowing (repo against the
* bond) finances the LONG side, cash lending (reverse repo) sources bonds for
* the SHORT side. A surprise hits both books at once and its sign says which
* one it hurts:
*   tightening -> long book constrained,  short book relaxed
*   easing     -> short book constrained, long book relaxed
* Two bars: the average change of the constrained and the relaxed book from the
* day before the shock (t-1) to H business days after (t+H), in EUR bn.
*
* Lesson from the deleted bond-level version (position_adjustment_bars.do): raw
* bond-level changes are dominated by positions rolling off as bonds age, which
* made both bars negative. Aggregating per day nets roll-offs across bonds, and
* the remaining trend in the sector footprint is removed by subtracting the
* average change over non-shock windows of the same length. Raw and adjusted
* means are both printed below for comparison.
********************************************************************************

clear all

local H 10   // event window end, business days after the shock

* 1. Import and aggregate to one observation per day, the sector's long and
*    short book in EUR bn
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear
gen date_num = date(business_date, "YMD")
format date_num %td
collapse (sum) long_book=borrowing_volume short_book=lending_volume ///
         (firstnm) ois_2y, by(date_num)
replace long_book  = long_book/1e9
replace short_book = short_book/1e9

* 2. Trading-day index for leads and lags
sort date_num
gen bday = _n
tsset bday

* 3. Book changes over the event window, t-1 to t+H, in EUR bn
gen d_long  = F`H'.long_book  - L1.long_book
gen d_short = F`H'.short_book - L1.short_book

* 4. Background drift, the same change measured on non-shock days. The sector
*    footprint trends over the sample, so the no-reaction counterfactual is
*    not zero.
quietly summarize d_long  if ois_2y == 0
local drift_long = r(mean)
quietly summarize d_short if ois_2y == 0
local drift_short = r(mean)
local W = `H' + 1
di as txt "Drift over a `W'-day window, long book:  " %6.3f `drift_long'  " EUR bn"
di as txt "Drift over a `W'-day window, short book: " %6.3f `drift_short' " EUR bn"

* 5. Regime per shock day. Constraining is the book the shock moves against,
*    relaxing the book it moves in favor of. Every shock day contributes one
*    observation to each bar.
gen     d_cons  = d_long  - `drift_long'  if ois_2y > 0
replace d_cons  = d_short - `drift_short' if ois_2y < 0
gen     d_relax = d_short - `drift_short' if ois_2y > 0
replace d_relax = d_long  - `drift_long'  if ois_2y < 0
keep if ois_2y != 0 & !missing(d_cons, d_relax)

* Diagnostics: event counts, raw means (drift added back), adjusted means
quietly count if ois_2y > 0
di as txt "Tightening surprises: " r(N)
quietly count if ois_2y < 0
di as txt "Easing surprises:     " r(N)
di as txt "Drift-adjusted book changes by regime (EUR bn):"
summarize d_cons d_relax
* If the EUR bn bars look lopsided because the long book is much larger than
* the short book, switch the outcome to percent of the book entering the shock:
* replace d_long/d_short in step 3 by
*   gen d_long  = 100*(F`H'.long_book  - L1.long_book) /L1.long_book
*   gen d_short = 100*(F`H'.short_book - L1.short_book)/L1.short_book
* and relabel the y axis accordingly.

* 6. Two bars in the deck's regime colors, constraining red, relaxing green
keep d_cons d_relax
stack d_cons d_relax, into(adj) clear
rename _stack regime
collapse (mean) adj, by(regime)
format adj %5.2f
gen vpos = cond(adj >= 0, 12, 6)   // value label above positive, below negative

twoway (bar adj regime if regime == 1, barwidth(0.6) color("196 61 33")) ///
       (bar adj regime if regime == 2, barwidth(0.6) color("0 128 96")) ///
       (scatter adj regime, msymbol(none) mlabel(adj) mlabvposition(vpos) ///
            mlabcolor(black) mlabsize(medium)), ///
    yline(0, lcolor(black) lwidth(thin)) ///
    xlabel(1 `""Constraining" "shock moves against the book""' ///
           2 `""Relaxing" "shock moves in favor""', noticks labsize(medsmall)) ///
    xscale(range(0.4 2.6)) xtitle("") ///
    ytitle("Change in aggregate positions, day -1 to +`H' (EUR bn)") ///
    note("Average across monetary surprises 2021 to 2025, net of the average" ///
         "change over non-shock windows of the same length.", size(vsmall) color(gs7)) ///
    legend(off) graphregion(color(white))
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\position_symmetry_bars.png", replace width(2000)
