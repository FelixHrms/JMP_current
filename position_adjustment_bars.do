********************************************************************************
* POSITION ADJUSTMENT BY BOOK & SHOCK  —  Figure for Result 4 (symmetry)
* "The favoured book grows, the hurt book shrinks -> symmetric adjustment"
*
* Input : Data\monetary_policy_induced_position.csv  (build\build_main_panel.ipynb)
* Output: Figures\position_adjustment_bars.png
*
* Simple descriptive chart. For each shock event we track the gross book directly:
*   borrowing_volume = long book,  lending_volume = short book.
* We plot the average change in each book's volume over the 10 business days after a
* shock (from the level entering the shock, t-1, to t+10), split by whether the
* shock helps or hurts that book:
*   Borrowing (long) : favourable = easing (ois_2y<0),  hurting = tightening (ois_2y>0)
*   Lending  (short) : favourable = tightening (ois_2y>0), hurting = easing (ois_2y<0)
* Expectation: favourable -> volume rises, hurting -> volume falls, symmetrically
* across the two books. Volumes are converted to EUR bn. Raw group means, 90% CIs.
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

* 3. Volumes in EUR bn, and their change over the window (entering shock -> +10 days)
replace borrowing_volume = borrowing_volume/1e9
replace lending_volume   = lending_volume/1e9

gen pre_borrow = L1.borrowing_volume
gen pre_lend   = L1.lending_volume
gen d_borrow   = F10.borrowing_volume - L1.borrowing_volume
gen d_lend     = F10.lending_volume   - L1.lending_volume

* 4. Average change per book x shock (only where the book exists entering the shock)
*    book: 1 = borrowing (long), 2 = lending (short);  fav: 1 = favourable, 0 = hurting
tempname M
tempfile bars
postfile `M' book fav mean se n using `bars', replace

summarize d_borrow if pre_borrow > 0 & ois_2y < 0        // long, favourable (easing)
post `M' (1) (1) (r(mean)) (r(sd)/sqrt(r(N))) (r(N))
summarize d_borrow if pre_borrow > 0 & ois_2y > 0        // long, hurting (tightening)
post `M' (1) (0) (r(mean)) (r(sd)/sqrt(r(N))) (r(N))
summarize d_lend   if pre_lend   > 0 & ois_2y > 0        // short, favourable (tightening)
post `M' (2) (1) (r(mean)) (r(sd)/sqrt(r(N))) (r(N))
summarize d_lend   if pre_lend   > 0 & ois_2y < 0        // short, hurting (easing)
post `M' (2) (0) (r(mean)) (r(sd)/sqrt(r(N))) (r(N))
postclose `M'

* 5. Four bars, grouped by book, coloured by favourable vs hurting
use `bars', clear
gen hi = mean + 1.64*se
gen lo = mean - 1.64*se
gen xpos = .
replace xpos = 1 if book == 1 & fav == 1
replace xpos = 2 if book == 1 & fav == 0
replace xpos = 4 if book == 2 & fav == 1
replace xpos = 5 if book == 2 & fav == 0

twoway (bar mean xpos if fav == 1, barwidth(0.8) color(forest_green)) ///
       (bar mean xpos if fav == 0, barwidth(0.8) color(cranberry)) ///
       (rcap hi lo xpos, lcolor(gs7) msize(small)), ///
    yline(0, lcolor(black) lwidth(thin)) ///
    xlabel(1.5 "Borrowing (long book)" 4.5 "Lending (short book)", noticks) ///
    xscale(range(0.3 5.7)) ///
    ytitle("Change in volume over 10 days (EUR bn)") xtitle("") ///
    legend(order(1 "Favourable shock" 2 "Hurting shock") rows(1) position(6) region(lstyle(none))) ///
    graphregion(color(white)) name(vol_adj, replace)
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\position_adjustment_bars.png", replace width(2000)
