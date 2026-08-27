********************************************************************************
* WINNERS VS NEWCOMERS  (discussant slides 14-18: what drives the
* winning-side expansion?)
* Question: after a favorable shock, does the position expansion come from
* the funds whose books WON (incumbents re-levering freed collateral,
* proportional to their gain) or from funds with no prior book (entry,
* consistent with trend-chasing)?
* Gain proxy on the observed book: -net_dv01(pre) x surprise. The margin
* account of the repo book is driven by the observed positions, so this is
* the P&L object the collateral channel runs on; total fund P&L is neither
* observed nor needed.
* Inputs: Data\fund_day_directionality.csv (fund-day net/gross DV01),
*         Data\monetary_policy_induced_position.csv (daily surprise).
********************************************************************************

clear all

* 1. Daily surprise series
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear
keep business_date ois_2y
duplicates drop business_date, force
save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\shock_daily.dta", replace

* 2. Fund-day panel, filled with zero rows for inactive fund-days so that
*    exits, re-entries, and entries are visible
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\fund_day_directionality.csv", clear
keep business_date fund_id net_dv01 gross_dv01
gen date_num = date(business_date, "YMD")
format date_num %td

* trading-day calendar
preserve
    duplicates drop business_date, force
    keep business_date date_num
    sort date_num
    gen tday = _n
    save "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\tday_map.dta", replace
restore
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\tday_map.dta", ///
    keepusing(tday) nogenerate

egen fid = group(fund_id)
xtset fid tday
tsfill, full
replace net_dv01   = 0 if missing(net_dv01)
replace gross_dv01 = 0 if missing(gross_dv01)
* recover dates on filled rows
drop business_date date_num
merge m:1 tday using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\tday_map.dta", ///
    keepusing(business_date date_num) nogenerate
merge m:1 business_date using "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\shock_daily.dta", ///
    keep(match master) nogenerate
replace ois_2y = 0 if missing(ois_2y)

* 3. Pre-shock book (5-day trailing means) and the gain on the observed book
sort fid tday
by fid: gen net_pre   = (L1.net_dv01 + L2.net_dv01 + L3.net_dv01 + L4.net_dv01 + L5.net_dv01) / 5
by fid: gen gross_pre = (L1.gross_dv01 + L2.gross_dv01 + L3.gross_dv01 + L4.gross_dv01 + L5.gross_dv01) / 5

* gain in EUR per bp of surprise: yields up (s>0) benefit net-short books
gen gain = -net_pre * ois_2y

gen incumbent = (gross_pre > 0)
gen winner = (gain > 0) if incumbent & ois_2y != 0
gen loser  = (gain < 0) if incumbent & ois_2y != 0

* scale the gain by the book so large and small funds are comparable:
* gain_scaled = -(net_pre/gross_pre) x surprise, in [-|s|, |s|]
gen gain_scaled = -(net_pre / gross_pre) * ois_2y if incumbent

********************************************************************************
* 4. INCUMBENTS: book expansion after announcements as a function of the gain
*    Outcome: log change in gross DV01 from the pre-shock book to t+h.
*    Leverage-management prediction: expansion increasing in the (scaled)
*    gain; trend-chasing predicts a response to the shock regardless of the
*    prior book, which the gain_scaled term nets out by construction.
********************************************************************************

forvalues h = 0/10 {
    by fid: gen gross_h`h' = F`h'.gross_dv01
    gen dlog_gross_h`h' = ln(gross_h`h') - ln(gross_pre) if incumbent & gross_h`h' > 0
}

tempname INC
tempfile inc_out
postfile `INC' horizon b se using `inc_out', replace
forvalues h = 0/10 {
    quietly reg dlog_gross_h`h' gain_scaled if ois_2y != 0 & incumbent, ///
        vce(cluster business_date)
    post `INC' (`h') (_b[gain_scaled]) (_se[gain_scaled])
    di as text "h=`h' : " as result %8.4f _b[gain_scaled] ///
       as text "  (" as result %8.4f _se[gain_scaled] as text ")"
}
postclose `INC'

preserve
    use `inc_out', clear
    gen up = b + 1.64*se
    gen lo = b - 1.64*se
    twoway (rarea up lo horizon, color(navy%20) lwidth(none)) ///
           (line b horizon, color(navy) lwidth(thick)), ///
           yline(0, lcolor(black) lpattern(dash)) ///
           ytitle("Book expansion per unit of scaled gain") ///
           xtitle("Days since announcement") xlabel(0(1)10) legend(off) ///
           graphregion(color(white))
    graph export "C:\\Users\\hermesf\\Projects\\JobMarket\\Figures\\IR_incumbent_gain.png", replace width(2000)
restore

********************************************************************************
* 5. ENTRANTS: do funds with no prior book enter after announcements?
*    Trend-chasing predicts entry (with the move); the leverage channel
*    predicts nothing, since a fund without a book has no gain and no freed
*    collateral.
********************************************************************************

* entry within 5 days: any positive gross between t and t+5
gen entered5 = 0
forvalues h = 0/5 {
    replace entered5 = 1 if gross_h`h' > 0 & !missing(gross_h`h') & incumbent == 0
}

* entry probability on announcement vs non-announcement days
gen is_ann = (ois_2y != 0)
gen abs_s = abs(ois_2y)
reg entered5 is_ann if incumbent == 0, vce(cluster business_date)
reg entered5 abs_s if incumbent == 0 & is_ann, vce(cluster business_date)

* direction of entry: does the new net lean WITH the realized move
* (net_dv01 < 0 after s > 0)? Chasing predicts a share above one half.
gen first_net = .
forvalues h = 0/5 {
    by fid: replace first_net = F`h'.net_dv01 if missing(first_net) ///
        & F`h'.gross_dv01 > 0 & !missing(F`h'.gross_dv01) & incumbent == 0
}
gen with_move = (sign(first_net) == -sign(ois_2y)) if entered5 & is_ann & first_net != 0
di as text _n "==== share of entries leaning with the realized move ===="
summarize with_move

********************************************************************************
* 6. DECOMPOSITION: whose gross expansion is it?
*    Aggregate change in gross DV01 from t-1 to t+5 around announcements,
*    split into winning incumbents, losing incumbents, and entrants.
********************************************************************************

gen dgross5 = gross_h5 - gross_pre if !missing(gross_h5)
gen grp = .
replace grp = 1 if incumbent & winner == 1
replace grp = 2 if incumbent & loser == 1
replace grp = 3 if incumbent == 0
label define grp_lbl 1 "Winning incumbents" 2 "Losing incumbents" 3 "Entrants"
label values grp grp_lbl

preserve
    keep if is_ann & !missing(dgross5) & !missing(grp)
    gen dgross5_pos = max(dgross5, 0)
    collapse (sum) dgross5 dgross5_pos, by(grp)
    di as text _n "==== net and gross-positive DV01 change t-1 to t+5, by group ===="
    list, noobs
restore
