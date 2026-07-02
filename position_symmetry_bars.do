********************************************************************************
* WITHIN-EVENT BOOK GAP  —  diagnostic for the slide 8 walkthrough figure
* "The effect is symmetric, whether the shock helps or hurts the position"
*
* Input : Data\monetary_policy_induced_position.csv  (build\build_main_panel.ipynb)
* Output: console only for now, no figure until the diagnostic passes
*
* Why this design. The raw two-bar version (see git history of this file) put
* both regimes deep in negative territory because aggregate books shrink after
* announcements no matter which side the shock favors (common de-grossing) and
* because several event windows cross quarter ends, where repo books contract
* mechanically by billions. Differencing WITHIN the event removes everything
* that hits both books in the same window, and working in percent of the book
* entering the shock removes the long/short size asymmetry.
*
* Object of interest, one number per shock event
*   gap = %change of the book the shock favors  -  %change of the book it hurts
* over the window t-1 to t+H. The mechanism predicts gap > 0.
*
* The diagnostic passes if the mean gap is positive and significant, survives
* dropping quarter-end windows, is positive for tightening and easing
* separately, and ideally scales with the size of the surprise. Then the slide
* shows it as a single headline statistic rather than two fragile bars.
********************************************************************************

clear all

local H 10   // event window end, business days after the shock

* 1. Aggregate to one observation per day, the sector's long and short book
import delimited "C:\Users\hermesf\Projects\JobMarket\Data\monetary_policy_induced_position.csv", clear
gen date_num = date(business_date, "YMD")
format date_num %td
collapse (sum) long_book=borrowing_volume short_book=lending_volume ///
         (firstnm) ois_2y, by(date_num)
replace long_book  = long_book/1e9
replace short_book = short_book/1e9

sort date_num
gen bday = _n
tsset bday

* 2. Window changes from t-1 to t+H, in EUR bn and in percent of the book
*    entering the shock
gen d_long_bn   = F`H'.long_book  - L1.long_book
gen d_short_bn  = F`H'.short_book - L1.short_book
gen d_long_pct  = 100 * d_long_bn  / L1.long_book
gen d_short_pct = 100 * d_short_bn / L1.short_book

* flag windows that cross a quarter end, where repo books contract mechanically
gen qend = qofd(F`H'.date_num) != qofd(L1.date_num) if !missing(F`H'.date_num, L1.date_num)

* book-specific percent drift on non-shock days, in case the two books trend at
* different rates (windows overlapping a shock mildly contaminate this, accepted)
quietly summarize d_long_pct if ois_2y == 0
local drift_long = r(mean)
quietly summarize d_short_pct if ois_2y == 0
local drift_short = r(mean)
di as txt "Percent drift per window, long book:  " %5.2f `drift_long'
di as txt "Percent drift per window, short book: " %5.2f `drift_short'

* 3. Shock events. The sign of the surprise says which book it favors
keep if ois_2y != 0 & !missing(d_long_pct, d_short_pct)
gen tightening = ois_2y > 0
gen abs_shock  = abs(ois_2y)

gen pct_relax = cond(tightening, d_short_pct, d_long_pct)   // favored book
gen pct_cons  = cond(tightening, d_long_pct,  d_short_pct)  // hurt book

* within-event gap, raw and net of the differential drift of the two books
gen gap_pct     = pct_relax - pct_cons
gen gap_pct_adj = gap_pct - cond(tightening, `drift_short' - `drift_long', ///
                                             `drift_long'  - `drift_short')

* 4. Per-event listing, to spot dominant events (December windows in particular)
format ois_2y %6.2f
format d_long_bn d_short_bn %7.2f
format d_long_pct d_short_pct gap_pct gap_pct_adj %6.1f
list date_num ois_2y d_long_bn d_short_bn d_long_pct d_short_pct ///
     gap_pct qend, sep(0) noobs

* 5. The headline candidate
di as txt _n "Gap, all events (favored minus hurt book, percent):"
ttest gap_pct == 0
di as txt _n "Gap net of differential book drift:"
ttest gap_pct_adj == 0
di as txt _n "Excluding windows that cross a quarter end:"
ttest gap_pct == 0 if qend == 0
di as txt _n "Tightening surprises only:"
ttest gap_pct == 0 if tightening == 1
di as txt _n "Easing surprises only:"
ttest gap_pct == 0 if tightening == 0
di as txt _n "Median as an outlier check:"
summarize gap_pct, detail
di as txt _n "Does the gap scale with the size of the surprise:"
reg gap_pct abs_shock, robust
