********************************************************************************
*MEGA MERGE 2: PANEL YEARS 2004 to 2017
********************************************************************************
clear all 

forvalues t = 2004(1)2017  {
	*MERGE PURCHASES WITH TRIPS
	use "F:\NIELSEN data converted to dta\PURCHASES\purchases_`t'.dta"
	merge m:1 trip_code_uc using "F:\NIELSEN data converted to dta\TRIPS\trips_`t'.dta"
	keep if _merge == 3
	drop _merge
	*MERGE RETAILER TO TRIPS TO GET channel_type category "Online Shopping" 
	merge m:1 retailer_code using "F:\MASTER FILES\retailers.dta"
	keep if _merge==3
	drop _merge
	*MERGE PURCHASES & TRIPS W/ PANELISTS
	rename household_code household_cd
	merge m:1 household_cd using "F:\NIELSEN data converted to dta\PANELISTS\panelists_`t'.dta",
	keep if _merge==3
	drop _merge

	save "F:\MEGA MERGE 2\Merge_Purch_Trips_Panelists_`t'.dta", replace

}




********************************************************************************
*DESCRIPTIVE STATISTICS
********************************************************************************
cd "F:\Demand Estimation\MEGA MERGE\Descriptive Stats"

forvalues t = 2011(1)2017  {
	clear all
	use "F:\MEGA MERGE 2\Merge_Purch_Trips_Panelists_`t'.dta"

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
	egen Online_at_All = max(Online_purch_item), by(household_cd)

	*Online Characteristics
	tabout Online_at_All if panel_year == `t' using Online_Shopper_`t'.xls, stats()

}

*HH General Characteristics


*HH Male_head Characteristics
sum male_head_employment male_head_education male_head_occupation male_head_birth

table male_head_occupation male_head_education, matcell(Male_Head_1) 

matrix list Male_Head_1

return list

*HH Female_head Characteristics









