*--- Layer 1: Residualize ΔCDS into its unanticipated component ---

* CDS
import delimited "C:\Users\hermesf\Projects\JobMarket\Empirics\cds_ecb.csv", clear
drop if missing(date) & missing(cds)
gen ddate = date(date, "DMY")
format ddate %td
drop date
rename ddate date
sort date

* V2X (lagged predictor)
preserve
import delimited "C:\Users\hermesf\Projects\JobMarket\Empirics\vix.csv", clear
gen ddate = date(date, "DMY")
format ddate %td
drop date
rename ddate date
rename v2tx v2x
gen dv2x = v2x - v2x[_n-1]
keep date dv2x
tempfile v2x
save `v2x'
restore
merge 1:1 date using `v2x', keep(master match) nogen

* HF positioning (lagged predictor)
preserve
import delimited "C:\Users\hermesf\Projects\JobMarket\Empirics\it_position.csv", clear
gen ddate = date(business_date, "YMD")
format ddate %td
drop business_date
rename ddate date
drop if missing(date) & missing(net_pos)
keep date net_pos
rename net_pos hf_net
tempfile hf
save `hf'
restore
merge 1:1 date using `hf', keep(master match) nogen
sort date

drop if missing(hf_net)                 // drop holiday/no-repo days
sort date
gen dcds = cds - cds[_n-1]              // change across consecutive trading days

gen L_hf = hf_net[_n-1]
replace L_hf = L_hf / 1e9              // € bn

sort date
gen L_dcds = dcds[_n-1]
gen L_dv2x = dv2x[_n-1]

gen gap = date - date[_n-1]

* Residualization
reg dcds L_dcds L_dv2x L_hf
predict cds_shock_raw, residuals
replace cds_shock_raw = . if gap > 5     // exclude changes spanning > a long weekend

* row index for the burn-in guard
gen tindex = _n

*--- Raw-threshold shock definition ---
_pctile cds_shock_raw, p(2 98)
gen cds_shock_day = (cds_shock_raw < r(r1) | cds_shock_raw > r(r2)) ///
    if !missing(cds_shock_raw)
replace cds_shock_day = . if tindex <= 30
count if cds_shock_day == 1

*--- Purge monetary-event overlap ---
preserve
import excel "C:\Users\hermesf\Projects\JobMarket\Data\altavilla.xlsx", ///
    sheet("Monetary Event Window") firstrow clear
gen ecb_day = date(date, "DMY")
format ecb_day %td
keep ecb_day
drop if missing(ecb_day)
duplicates drop
gen byte ecb_event = 1
tempfile ecb
save `ecb'
restore

sort date
rename date d
gen ecb_day = d
merge m:1 ecb_day using `ecb', keep(master match) nogen
rename d date
replace ecb_event = 0 if missing(ecb_event)
sort date
gen byte ecb_window = ecb_event
replace ecb_window = 1 if ecb_event[_n-1]==1 | ecb_event[_n+1]==1

*--- Export clean shock days ---
keep if cds_shock_day == 1 & ecb_window == 0
keep date cds_shock_raw
export delimited using "C:\Users\hermesf\Projects\JobMarket\Empirics\cds_shock.csv", replace
count