********************************************************************************
* INTENSITY & VOLATILITY  —  Figure for Result 1 (slide walkthrough 1)
* "Bonds hedge funds hold are more volatile"
*
* Input : Data\monetary_policy_induced_position.csv  (build\build_main_panel.ipynb)
* Output: Figures\intensity_volatility_bars.png
*
* Simple version: average absolute daily yield change |dy| across five hedge fund
* intensity buckets (no-HF reference + quartiles of hf_intensity_pre). No day-type
* split, no fixed effects -- just group means.
********************************************************************************

clear all

* 1. Import the data
import delimited "C:\\Users\\hermesf\\Projects\\JobMarket\\Data\\monetary_policy_induced_position.csv", clear

* 2. Absolute daily yield change
gen abs_delta_y = abs(delta_y)

* 3. Hedge fund intensity buckets: quartiles among the involved, plus a no-HF reference
xtile hf_q = hf_intensity_pre if hf_intensity_pre > 0, nq(4)
replace hf_q = 0 if hf_intensity_pre == 0   // 0 = no hedge fund involvement (reference)
label define hf_q_lbl 0 "No HF" 1 "Q1" 2 "Q2" 3 "Q3" 4 "Q4"
label values hf_q hf_q_lbl

* 4. Simple bar chart of average |dy| by intensity bucket
graph bar (mean) abs_delta_y, over(hf_q) ///
    bar(1, color(navy)) ///
    blabel(bar, format(%4.2f)) ///
    ytitle("Average |{&Delta}y| (bp)") ///
    graphregion(color(white))
graph export "C:\Users\hermesf\Projects\JobMarket\Figures\intensity_volatility_bars.png", replace width(2000)
