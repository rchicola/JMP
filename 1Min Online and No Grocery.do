
*CREATE POOLED PURCHASE LEVEL DATA 2011 to 2017 ,collapse on HH
  
********************************************************************************
*INTENSTIVE MARGIN LOOP: MERGE PURCHASES WITH TRIP & RETAIL.
*THEN APPLY THE ONLINE Minimum Trip Condition 
********************************************************************************
forvalues t = 2011(1)2017  {

	use "E:\NIELSEN data converted to dta\PURCHASES\purchases_`t'.dta"

	merge m:1 trip_code_uc using "E:\NIELSEN data converted to dta\TRIPS\trips_`t'.dta"
	keep if _merge==3
	drop _merge

	*MERGE RETAILER TO TRIPS TO GET channel_type category "Online Shopping" 
	merge m:1 retailer_code using "E:\MASTER FILES\retailers.dta"
	keep if _merge==3
	drop _merge

	*Using channel_type, make Indicator Var. for whether purchase item bought was "Online"
	gen Online_purch_item =.
	replace Online_purch_item = 1 if channel_type== "Online Shopping"
	replace Online_purch_item  = 0 if channel_type!= "Online Shopping"

	*Using channel_type, make Indicator Var. for whether purchase item bought was "Traditional"
	gen Trad_purch_item =.
	replace Trad_purch_item = 1 if channel_type!= "Online Shopping"
	replace Trad_purch_item  = 0 if channel_type== "Online Shopping"

	*ONLINE 1 PURCHASE MIN. CONDITION:  If Max val is 0, none of trips by HH were online. 
	*If max val is 1, at least one item row was an online purchase.
	egen Online_at_All = max(Online_purch_item), by(household_code)

	*TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
	drop if Online_at_All==0
	
	drop if channel_type == "Grocery"
	

	save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min_1_Online item_No Grocery_`t'.dta",replace

}
********************************************************************************

********************************************************************************
*MERGE PANELIST STATE OF RESIDENCE & TAX ADOPTION DATES & STATE SALES TAX RATES
********************************************************************************
clear

forvalues t = 2011(1)2017  {
	use "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min_1_Online item_No Grocery_`t'.dta"
	rename household_code household_cd
	merge m:1 household_cd using "E:\NIELSEN data converted to dta\PANELISTS\panelists_`t'.dta", keepusing(fips_state_desc)
	keep if _merge==3
	drop _merge

	merge m:1 fips_state_desc using "E:\Demand Estimation\Tax data\Tax Foundation Onlines tax collection dates.dta"
	keep if _merge==3
	drop _merge

	merge m:1 fips_state_desc  panel_year using "E:\Demand Estimation\INTENSIVE MARGIN (Online)\State Sales Tax Rates 2011 to 2020.dta"
	keep if _merge==3
	drop _merge
	*********************************************************
	*PER UNIT COST CALCULATION: Per Nielsen manual
	*********************************************************
	gen final_price_paid = total_price_paid - coupon_value 
	gen PUC = final_price_paid /quantity
		
	save "E:\Demand Estimation\Tax data\Min1_On_purch_No Grocery_wTAXdates_`t'.dta", replace

}
********************************************************************************


********************************************************************************
*CREATE PRICE AND EXPENSE VARIABLES & THEN COLLAPSE on HH
********************************************************************************
clear 

forvalues t = 2011(1)2017  {
	use  "E:\Demand Estimation\Tax data\Min1_On_purch_No Grocery_wTAXdates_`t'.dta"

	*STATE SALES TAX IN STATE ?
	gen Yes_SalesTax = .
	replace  Yes_SalesTax = 0 if Combined_TR ==0
	replace Yes_SalesTax =1 if Combined_TR > 0

	*WAS THE ITEM PURCHASED BEFORE OR AFTER THE ADOPTION DATE?
	gen purch_date = date(purchase_date, "YMD")

	gen PostTaxPurch = .
	*Purch is in a sales tax state but item was purchased BEFORE the Adoption date
	replace PostTaxPurch = 0 if Yes_SalesTax == 1 & purch_date < TR_Start_Date
	*Purch is in a sales tax state and the item was purchased AFTER the Adoption date.
	replace PostTaxPurch = 1 if Yes_SalesTax ==1 & purch_date >= TR_Start_Date
	
	*********************************************************************
	*PRICES	
	*********************************************************************
	*ADJUSTING PUC FOR SALES TAXES
	gen PUC_taxAdj =.
	*No Adjustment needed for purchased items in states without sales tax
	replace PUC_taxAdj = PUC if Yes_SalesTax == 0 
	*Adjust PUC w sales tax if item is a Traditional good bought in a sales tax state. 
	replace PUC_taxAdj = PUC *(1+Combined_TR) if channel_type != "Online Shopping" & Yes_SalesTax == 1
	*Adjust PUC w sales tax if item is a Online good AND it was bought after the Adoption date
	replace PUC_taxAdj = PUC *(1+Combined_TR) if channel_type == "Online Shopping" & PostTaxPurch ==1
	*No Adjustment needed for Online item purchased in a state w/ sales tax bu BEFORE the Adoption date
	replace PUC_taxAdj = PUC if channel_type == "Online Shopping" & PostTaxPurch == 0

	*WITH TAXES:	MEDIAN PRICE OF ONLINE AND TRADITIONAL ITEMS 
	bysort fips_state_desc : egen Median_On_PUCtax = median(PUC_taxAdj) if channel_type == "Online Shopping" 
	bysort fips_state_desc : egen Median_Trad_PUCtax = median(PUC_taxAdj) if channel_type != "Online Shopping" 

	*WITHOUT TAXES:		MEDIAN PRICE OF ONLINE AND TRADITIONAL ITEMS 
	bysort fips_state_desc : egen Median_On_PUC = median(PUC) if channel_type == "Online Shopping" 
	bysort fips_state_desc : egen Median_Trad_PUC = median(PUC) if channel_type != "Online Shopping" 

	*********************************************************************
	*WITH TAXES:	ONLINE & TRADITIONAL Expenditures  
	*Quantity times tax adjusted PUC
	gen Tot_Tax_Adj_Item_EXP = PUC_taxAdj * quantity 

	*TOTAL EXPENSE 
	bysort household_cd : egen Tot_EXP = total(Tot_Tax_Adj_Item_EXP)
	*TRADITIONAL EXPENSE 
	bysort household_cd : egen Trad_EXP = total(Tot_Tax_Adj_Item_EXP) if channel_type != "Online Shopping" 
	*ONLINE EXPENSE 
	bysort household_cd : egen Online_EXP = total(Tot_Tax_Adj_Item_EXP) if channel_type == "Online Shopping"
	
	*********************************************************************
	*WITHOUT TAXES :	ONLINE & TRADITIONAL Expenditures 
	*Quantity times PUC
	gen Tot_NoTax_EXP = PUC * quantity 
	*TOTAL EXPENSE 
	bysort household_cd : egen NoTax_Tot_EXP = total(Tot_NoTax_EXP)
	*TRADITIONAL EXPENSE 
	bysort household_cd : egen NoTax_Trad_EXP = total(Tot_NoTax_EXP) if channel_type != "Online Shopping" 
	*ONLINE EXPENSE 
	bysort household_cd : egen NoTax_Online_EXP = total(Tot_NoTax_EXP) if channel_type == "Online Shopping"
	
								
	save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_item_taxadj_prices_No Grocery_EXP_`t'.dta", replace						
	collapse  Median_On_PUC    Median_Trad_PUC   Median_On_PUCtax   Median_Trad_PUCtax  Tot_EXP Online_EXP  Trad_EXP  NoTax_Tot_EXP NoTax_Trad_EXP NoTax_Online_EXP, by(household_cd)						

	gen panel_year = `t'									
	save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_taxadj_P_No_Grocery_EXP_COLLAPSED_`t'.dta" , replace
	
}
********************************************************************************






clear

use "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_taxadj_P_No_Grocery_EXP_COLLAPSED_2017.dta"

append using "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_taxadj_P_No_Grocery_EXP_COLLAPSED_2016.dta" "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_taxadj_P_No_Grocery_EXP_COLLAPSED_2015.dta" "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_taxadj_P_No_Grocery_EXP_COLLAPSED_2014.dta" "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_item_taxadj_prices_No Grocery_EXP_2013.dta" "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_taxadj_P_No_Grocery_EXP_COLLAPSED_2012.dta" "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Min1_On_taxadj_P_No_Grocery_EXP_COLLAPSED_2011.dta"





*CREATE EXPENDITURE SHARES
gen ONLINE_EXP_SH = Online_EXP / Tot_EXP
gen Trad_EXP_SH =  Trad_EXP / Tot_EXP
gen Cum_sh = ONLINE_EXP_SH + Trad_EXP_SH

*CREATE NO TAX  EXPENDITURE SHARES
gen NoTax_ON_EXP_SH = NoTax_Online_EXP / NoTax_Tot_EXP
gen NoTax_Trad_EXP_SH = NoTax_Trad_EXP / NoTax_Tot_EXP
gen NoTax_Cum_sh = NoTax_ON_EXP_SH + NoTax_Trad_EXP_SH

*RE-MERGE HH & Tax data lost in collapse, need state for P index state year avgs
merge 1:m panel_year  household_cd using "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Panelists 2008 to 2017 Appended.dta"
keep if _merge==3
drop _merge

merge m:1 panel_year fips_state_desc using "E:\Demand Estimation\INTENSIVE MARGIN (Online)\State Sales Tax Rates 2011  to 2020.dta"
keep if _merge==3
drop _merge

merge m:1 fips_state_desc using "E:\Demand Estimation\INTENSIVE MARGIN (Online)\State Online Sales Tax Adoption Dates.dta"
keep if _merge==3
drop _merge


*CREATE STATE \ YEAR PRICE INDEX

*STATE / YEAR AVG EXPENSE SHARE
bysort panel_year fips_state_desc : egen ST_avg_On_exp = mean(Online_EXP)
bysort panel_year fips_state_desc : egen ST_avg_Trad_exp = mean(Trad_EXP)
bysort panel_year fips_state_desc : egen ST_avg_Tot_exp = mean(Tot_EXP)

*STATE / YEAR AVG EXPENSE SHARE
gen ST_avg_On_EXPSH = ST_avg_On_exp/ ST_avg_Tot_exp
gen ST_avg_Trad_EXPSH = ST_avg_Trad_exp/ ST_avg_Tot_exp


*STATE / YEAR AVG NO TAX PUC EXPENSE SHARE
bysort panel_year fips_state_desc : egen ST_avg_NoTax_On_exp = mean(NoTax_ON_EXP_SH)
bysort panel_year fips_state_desc : egen ST_avg_NoTax_Trad_exp = mean(NoTax_Trad_EXP_SH)
bysort panel_year fips_state_desc : egen ST_avg_NoTax_Tot_exp = mean(NoTax_Cum_sh)

*STATE / YEAR AVG NO TAX EXPENSE SHARE
gen ST_avg_NoTax_On_EXPSH = ST_avg_NoTax_On_exp / ST_avg_NoTax_Tot_exp
gen ST_avg_NoTax_Trad_EXPSH = ST_avg_NoTax_Trad_ex/ ST_avg_NoTax_Tot_exp



gen NoSalesTax =.
replace NoSalesTax =1 if Combined_TR==0
replace NoSalesTax =0 if Combined_TR>0

gen TR_Start_YR = year(TR_Start_Date)

*Were Online Taxes Adopted this Year?
gen Tax_Online =.
replace Tax_Online = 1 if panel_year >= TR_Start_YR 
replace Tax_Online = 0 if panel_year < TR_Start_YR 

save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Pooled Collapsed 1Min_Online No Grocery 2011 to 2017.dta", replace













clear 
*********************************************************************************
*PROF. FOSSEN'S SUGGESTED REGRESSION
*********************************************************************************
*onlineShare_it =a + b taxOnline_it + c taxTradit + d controls_it + e_it
use "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Pooled Collapsed 1Min_Online 2011 to 2017.dta"

xtset household_cd panel_year 

svyset [pw=projection_factor], strata(household_cd)

*  b taxOnline_it
gen TaxOnline_it = Combined_TR if Tax_Online ==1
replace TaxOnline_it = 0 if Tax_Online == 0

* c taxTrad_it :Combined_TR is the State + Avg Local Sales Tax (From TAX FOUNDATION)
gen TaxTrad_it = Combined_TR 

*d controls_it
global Male_HH  " male_head_age male_head_employment male_head_education male_head_occupation"
global Female_HH "female_head_age female_head_employment female_head_education female_head_occupation"
global HH_general "household_income household_size type_of_residence household_composition age_and_presence_of_children race hispanic_origin" 
global HH_Home " kitchen_appliances tv_items household_internet_connection "


*USING ONLINE Expense Share W/Out Tax Adjustment to PUC
*********************************************************************************
*No Controls other than State/Year FE
reg NoTax_ON_EXP_SH    TaxOnline_it   TaxTrad_it   i.fips_state_cd   i.panel_year [pweight=projection_factor]
eststo NoTax_ON_EXP_SH_1
*Same but w/ HH Cluster
reg NoTax_ON_EXP_SH  TaxOnline_it   TaxTrad_it   i.fips_state_cd   i.panel_year  [pweight=projection_factor] , cluster(household_cd)
eststo NoTax_ON_EXP_SH_2
*W/ Controls & cluster
reg NoTax_ON_EXP_SH  TaxOnline_it   TaxTrad_it ${HH_general} i.fips_state_cd   i.panel_year [pweight=projection_factor] , cluster(household_cd)
eststo  NoTax_ON_EXP_SH_3

esttab NoTax_ON_EXP_SH_1  NoTax_ON_EXP_SH_2  NoTax_ON_EXP_SH_3  using  NoTaxOnExpSH.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("Expense Share No Tax Adj to PUC") replace

esttab NoTax_ON_EXP_SH_1  NoTax_ON_EXP_SH_2  NoTax_ON_EXP_SH_3  using  NoTaxOnExpSH.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title("Expense Share No Tax Adj to PUC") replace



*USING ONLINE Expense Share WITH Tax Adjustment to PUC
*********************************************************************************
*No Controls other than State/Year FE
reg ONLINE_EXP_SH   TaxOnline_it   TaxTrad_it   i.fips_state_cd   i.panel_year [pweight=projection_factor]
eststo TaxAdj_ON_EXP_SH_1
*Same but w/ HH Cluster
reg ONLINE_EXP_SH     TaxOnline_it   TaxTrad_it   i.fips_state_cd   i.panel_year [pweight=projection_factor], cluster(household_cd)
eststo TaxAdj_ON_EXP_SH_2
*W/ Controls & cluster
reg ONLINE_EXP_SH     TaxOnline_it   TaxTrad_it   ${HH_general}  i.fips_state_cd   i.panel_year [pweight=projection_factor], cluster(household_cd)
eststo TaxAdj_ON_EXP_SH_3


esttab TaxAdj_ON_EXP_SH_1  TaxAdj_ON_EXP_SH_2   TaxAdj_ON_EXP_SH_3  using  TaxAdj_OnlineExpSH.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("Expense Share WITH Tax Adj to PUC") replace

esttab TaxAdj_ON_EXP_SH_1  TaxAdj_ON_EXP_SH_2   TaxAdj_ON_EXP_SH_3  using  TaxAdj_OnlineExpSH.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title("Expense Share WITH Tax Adj to PUC") replace


 
 
 
 
 
 
 
*********************************************************************************
*DEMAND SYSTEM ESTIMATES
*********************************************************************************
 
*USING ONLINE Expense Share W/Out Tax Adjustment to PUC
*********************************************************************************

gen LN_Med_Online_PUC = ln(Median_On_PUC) 
gen LN_Med_Trad_PUC = ln(Median_Trad_PUC)
*PRICE INDEX WITHOUT TAX ADJUSTMENTS
gen LN_NoTax_Pindex = (ST_avg_NoTax_On_EXPSH * LN_Med_Online_PUC) + (ST_avg_NoTax_Trad_EXPSH * LN_Med_Trad_PUC)
*LOG Variable Variants
gen LN_NoTax_Tot_EXP  = ln(NoTax_Tot_EXP)
gen LN_NoTax_Real_EXP = LN_NoTax_Tot_EXP - LN_NoTax_Pindex
*gen LN_NoTax_Real_EXP2 = ln(NoTax_Tot_EXP/NoTax_Pindex)





*NO TAX  AIDS REGRESSIONS**************
*VERY naive basic AIDS
reg  NoTax_ON_EXP_SH     LN_Med_Online_PUC     LN_Med_Trad_PUC    LN_NoTax_Real_EXP 
eststo AIDS_NoTax_1
*With State/Year Fixed Effects
reg  NoTax_ON_EXP_SH     LN_Med_Online_PUC     LN_Med_Trad_PUC    LN_NoTax_Real_EXP  i.fips_state_cd i.panel_year 
eststo AIDS_NoTax_2
*State/Year FE + projection factor pweights & HH cluster
reg  NoTax_ON_EXP_SH     LN_Med_Online_PUC     LN_Med_Trad_PUC    LN_NoTax_Real_EXP  i.fips_state_cd i.panel_year  [pweight=projection_factor], cluster(household_cd)
eststo AIDS_NoTax_3
 *HH Deomog. +......STate/Year FE + projection factor pweights & HH cluster
reg  NoTax_ON_EXP_SH     LN_Med_Online_PUC     LN_Med_Trad_PUC    LN_NoTax_Real_EXP ${HH_general} i.fips_state_cd i.panel_year  [pweight=projection_factor], cluster(household_cd)
eststo AIDS_NoTax_4
 *ALL DEMOG. 
 reg  NoTax_ON_EXP_SH     LN_Med_Online_PUC     LN_Med_Trad_PUC    LN_NoTax_Real_EXP ${HH_general} ${Male_HH} ${Female_HH} ${HH_Home}  i.fips_state_cd i.panel_year  [pweight=projection_factor], cluster(household_cd)
 eststo AIDS_NoTax_5
 
 
 
 
 
 
*USING ONLINE Expense Share WITH Tax Adjustment to PUC
*********************************************************************************

gen LN_Med_On_PUCtax = ln(Median_On_PUCtax) 
gen LN_Med_Trad_PUCtax = ln(Median_Trad_PUCtax)
*PRICE INDEX WITH TAX ADJUSTMENTS
gen  LN_TaxAdj_Pindex  = (ST_avg_On_EXPSH * LN_Med_Online_PUC) + (ST_avg_Trad_EXPSH * LN_Med_Trad_PUC)
*Nolog
gen TaxAdj_Pindex = (ST_avg_On_EXPSH * Median_On_PUCtax) + (ST_avg_Trad_EXPSH * Median_On_PUCtax)
*LOG Variable Variants
gen LN_TaxAdj_Tot_EXP  = ln(Tot_EXP)
*REAL EXPENDITURE
gen LN_TaxAdj_Real_EXP = LN_TaxAdj_Tot_EXP - LN_TaxAdj_Pindex








*WITH TAX  AIDS REGRESSIONS**************
*VERY naive basic AIDS
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP 
eststo AIDS_TaxAdj_1
    *With State/Year Fixed Effects
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP     i.fips_state_cd   i.panel_year 
eststo AIDS_TaxAdj_2
*STate/Year FE + projection factor pweights & HH cluster
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP     i.fips_state_cd   i.panel_year  [pweight=projection_factor], cluster(household_cd)
eststo AIDS_TaxAdj_3
*HH Deomog. +......STate/Year FE + projection factor pweights & HH cluster
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP  ${HH_general}   i.fips_state_cd   i.panel_year  [pweight=projection_factor], cluster(household_cd)
eststo AIDS_TaxAdj_4
*ALL DEMOG. 
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP  ${HH_general}  ${Male_HH} ${Female_HH} ${HH_Home}  i.fips_state_cd   i.panel_year  [pweight=projection_factor], cluster(household_cd)
eststo AIDS_TaxAdj_5

*NO pweight but otherwise 'ALL DEMOG.'
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP  ${HH_general}  ${Male_HH} ${Female_HH} ${HH_Home}  i.fips_state_cd   i.panel_year  , cluster(household_cd)
eststo AIDS_TaxAdj_6




************************************************************************
*Simulation of 10% price increase of online goods
************************************************************************

*Var for 10% increase
gen LN_PUCtax_10perinc =  ln(Median_On_PUCtax * 1.1)
ameans LN_PUCtax_10perinc 
sum LN_PUCtax_10perinc

*Demonstrative Example (Original)
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP 
predict ONLINE_EXP_SH_Hat, xb
sum ONLINE_EXP_SH_Hat
ameans ONLINE_EXP_SH_Hat

dis _b[_cons] _b[LN_Med_On_PUCtax] _b[LN_Med_Trad_PUCtax] _b[LN_TaxAdj_Real_EXP]

gen y_hat_cf = _b[_cons] + _b[LN_Med_On_PUCtax]*LN_PUCtax_10perinc + _b[LN_Med_Trad_PUCtax]*LN_Med_Trad_PUCtax  + _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP 
sum y_hat_cf


*lincom .1731756 + -.0123695*LN_PUCtax_10perinc + .0377341*LN_Med_Trad_PUCtax + -.0193404*LN_TaxAdj_Real_EXP 
sum LN_PUCtax_10perinc LN_Med_Trad_PUCtax LN_TaxAdj_Real_EXP
*Using means fromm sum command above  1.580762 .9914987  7.61825 
lincom .1731756 + -.0123695*  + .0377341*LN_Med_Trad_PUCtax + -.0193404*LN_TaxAdj_Real_EXP 



gen hat_diff = y_hat_cf - ONLINE_EXP_SH_Hat
display hat_diff


















*Simplest / Naive case************************************************************
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP 

*Pre 10% price increase prediction "Prediction 1", after running "ALL DEMOG." specification
predict ONLINE_EXP_SH_hat1 , xb
display ONLINE_EXP_SH_hat1 
sum ONLINE_EXP_SH_hat1
tsline ONLINE_EXP_SH  ONLINE_EXP_SH_hat1

eststo ONLINE_EXP_SH_hat1_outtable
esttab ONLINE_EXP_SH_hat1_outtable using  Predicted_OnEXPsh_1.tex, title("Predicted Online Expense Share") replace
outreg2 using On_Exp_Sh_hat1.tex, replace sum(log) 
estpost summarize ONLINE_EXP_SH_hat1 


*Vars for AVGs
egen LN_TaxAdj_Real_EXP_AVG = mean(LN_TaxAdj_Real_EXP)
egen LN_Med_On_PUCtax_AVG = mean(LN_Med_On_PUCtax)
egen LN_Med_On_PUCtax_10perinc_AVG = mean(LN_Med_On_PUCtax_10perinc)
egen LN_Med_Trad_PUCtax_AVG = mean(LN_Med_Trad_PUCtax)

*On averages
gen ONLINE_EXP_SH_plus10_AVG = _b[_cons] + _b[LN_Med_On_PUCtax]*LN_Med_On_PUCtax_10perinc_AVG + _b[LN_Med_Trad_PUCtax]*LN_Med_Trad_PUCtax_AVG + _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP_AVG
dis ONLINE_EXP_SH_plus10_AVG
sum ONLINE_EXP_SH_plus10_AVG

predict ON_EXP_SH_plus10_AVG_hat
dis ON_EXP_SH_plus10_AVG_hat
sum ON_EXP_SH_plus10_AVG_hat

dis _b[LN_Med_On_PUCtax] _b[LN_Med_Trad_PUCtax]

gen ONLINE_EXP_SH_plus10 = _b[_cons] + _b[LN_Med_On_PUCtax]*LN_Med_On_PUCtax_10perinc + _b[LN_Med_Trad_PUCtax]*LN_Med_Trad_PUCtax + _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP

sum ONLINE_EXP_SH_plus10
predict ONLINE_EXP_SH_plus10_hat

*Post 10% increase prediction "Prediction 2", incorrect don't reg on fake data but curious shits n giggles
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax_10perinc    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP  ${HH_general}  ${Male_HH} ${Female_HH} ${HH_Home}  i.fips_state_cd   i.panel_year  [pweight=projection_factor], cluster(household_cd)
eststo AIDS_TaxAdj_6

predict ONLINE_EXP_SH_hat2 
display ONLINE_EXP_SH_hat2
sum ONLINE_EXP_SH_hat2



household_income household_size type_of_residence household_composition age_and_presence_of_children race hispanic_origin














*Traditional equation to get Betaj for elasticity calc

reg Trad_EXP_SH LN_Med_On_PUCtax    LN_Med_Trad_PUCtax  LN_TaxAdj_Real_EXP  ${HH_general}  ${Male_HH} ${Female_HH} ${HH_Home}  i.fips_state_cd   i.panel_year  [pweight=projection_factor], cluster(household_cd)


median ONLINE_EXP_SH, by(panel_year)
median Trad_EXP_SH, by(panel_year)
sum ONLINE_EXP_SH
sum Trad_EXP_SH

gen No_log_RealExp = Tot_EXP/TaxAdj_Pindex
sum No_log_RealExp


/*
*Adding Tax Variables
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax   LN_TaxAdj_Real_EXP  TR_Start_YR  Combined_TR   TR_Start_YR##Combined_TR ${HH_general}  ${Male_HH} ${Female_HH} ${HH_Home}  i.fips_state_cd   i.panel_year  [pweight=projection_factor], cluster(household_cd)
eststo AIDS_TaxAdj_6
*/


*Adding INFLATION

merge m:1 panel_year using "E:\Demand Estimation\INTENSIVE MARGIN (Online)\CPI  Annual Inflation 2011 to 2017.dta"
keep if _merge==3
drop _merge

reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax   LN_TaxAdj_Real_EXP  TR_Start_YR  Combined_TR  CPI_Food ${HH_general}  ${Male_HH} ${Female_HH} ${HH_Home}  i.fips_state_cd   i.panel_year  [pweight=projection_factor], cluster(household_cd)
eststo AIDS_TaxAdj_7



**************************************************
*AIDS TABLES
**************************************************

*Naive EXample

esttab   AIDS_TaxAdj_1  using  AIDStax1.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("Expense Share AIDS Naive Tax Adj PUC ") replace



*1st REG No Tax Tax Compare
esttab AIDS_NoTax_1   AIDS_TaxAdj_1  using  AIDS1.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("Expense Share AIDS Naive NO Tax and Tax Adj PUC Comparison") replace
esttab AIDS_NoTax_1   AIDS_TaxAdj_1  using  AIDS1.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title("Expense Share AIDS Naive NO Tax and Tax Adj PUC Comparison") replace

*2nd REG No Tax / Tax Compare
esttab AIDS_NoTax_2   AIDS_TaxAdj_2  using  AIDS2.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. AIDS State and Year Fixed Effects NO Tax and Tax Adj PUC Comparison") replace
esttab AIDS_NoTax_2   AIDS_TaxAdj_2  using  AIDS2.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. AIDS State and Year Fixed Effects NO Tax and Tax Adj PUC Comparison") replace
esttab AIDS_NoTax_2   AIDS_TaxAdj_2  using  AIDS2.csv, csv se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. AIDS State and Year Fixed Effects NO Tax and Tax Adj PUC Comparison") replace

*3rd REG No Tax / Tax Compare
esttab AIDS_NoTax_3   AIDS_TaxAdj_3  using  AIDS3.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. AIDS State/Year F.E. + HH Cluster + Sample Weights Tax/NoTax PUC Comparison") replace
esttab AIDS_NoTax_3   AIDS_TaxAdj_3  using  AIDS3.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. AIDS State/Year F.E. + HH Cluster + Sample Weights Tax/NoTax PUC Comparison") replace
esttab AIDS_NoTax_3   AIDS_TaxAdj_3  using  AIDS3.csv, csv se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. AIDS State/Year F.E. + HH Cluster + Sample Weights Tax/NoTax PUC Comparison") replace

*4th REG No Tax / Tax Compare
esttab AIDS_NoTax_4   AIDS_TaxAdj_4  using  AIDS4.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. +..+ HH General Demog Tax/NoTax PUC Comparison") replace
esttab AIDS_NoTax_4   AIDS_TaxAdj_4  using  AIDS4.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. +..+ HH General Demog Tax/NoTax PUC Comparison") replace
esttab AIDS_NoTax_4   AIDS_TaxAdj_4  using  AIDS4.csv, csv se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. +..+ HH General Demog Tax/NoTax PUC Comparison") replace

*5th REG No Tax / Tax Compare
esttab AIDS_NoTax_5   AIDS_TaxAdj_5  using  AIDS5.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. +..+ All HH Demog Tax/NoTax PUC Comparison") replace
esttab AIDS_NoTax_5   AIDS_TaxAdj_5  using  AIDS5.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. +..+ All HH Demog Tax/NoTax PUC Comparison") replace
esttab AIDS_NoTax_5   AIDS_TaxAdj_5  using  AIDS5.csv, csv se star(* 0.10 ** 0.05 *** 0.01) title("Exp.Sh. +..+ All HH Demog Tax/NoTax PUC Comparison") replace














*NO TAX Regs
esttab AIDS_NoTax_2   AIDS_TaxAdj_3  using  AIDS2_3.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("No Taxes: State/Year F.E. and S/Y F.E.  projection factor & HH cluster") replace
esttab AIDS_NoTax_2   AIDS_TaxAdj_3  using  AIDS2_3.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title(" State/Year F.E.  and   S/Y F.E.  projection factor & HH cluster") replace




*NO TAX Regs
esttab AIDS_NoTax_2   AIDS_TaxAdj_3  using  AIDS2_3.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("No Taxes: State/Year F.E. and S/Y F.E.  projection factor & HH cluster") replace
esttab AIDS_NoTax_2   AIDS_TaxAdj_3  using  AIDS2_3.rtf, rtf se star(* 0.10 ** 0.05 *** 0.01) title(" State/Year F.E.  and   S/Y F.E.  projection factor & HH cluster") replace

**************************************************
*MAPS and Descriptive Statistics
**************************************************
twoway connected ST_avg_On_EXPSH ST_avg_Trad_EXPSH  panel_year

ssc install maptile
ssc install spmap
ssc install project
ssc install shp2dta.pkg

project, setup
project , setmaster("C:\Program Files\Stata16\ado\personal\geo_state_creation\build_state.do")
project build_state, build



maptile_install using "E:\Demand Estimation\geo_state_creation"
maptile_install using "C:\Program Files\Stata16\ado\personal\geo_state_creation"
maptile_install using "C:\Program Files\Stata16\ado\personal\geo_state_creation.zip"


maptile  ST_avg_On_EXPSH if panel_year==2011,   geography(build_state)







