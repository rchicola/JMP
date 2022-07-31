
******************************************************************
*2017
******************************************************************

******************************************************************
*FIRST MEGA MERGE except panelists file
******************************************************************
use "E:\NIELSEN data converted to dta\PURCHASES\purchases_2017.dta"
*MERGE WITH TRIPS
merge m:1 trip_code_uc using "E:\NIELSEN data converted to dta\TRIPS\trips_2017.dta"
keep if _merge==3
drop _merge
*MERGE WITH RETAILERS MASTER
merge m:1 retailer_code using "E:\MASTER FILES\retailers.dta"
keep if _merge==3
drop _merge
*MERGE WITH PRODUCT MASTER
merge m:1 upc upc_ver_uc using "E:\MASTER FILES\PRODUCTS_MASTER.dta"
keep if _merge==3
drop _merge
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2017.dta", replace

******************************************************************
*FILTER OUT THOSE WHO MADE AT LEAST 1 ONLINE PURCHASE
******************************************************************
*KEEP ONLY HHs who have at least one Online Purchase
*https://www.stata.com/support/faqs/data-management/create-variable-recording/
*Dummy Var for whether item purched row level was an Online purchase 
gen Online_item=.
replace Online_item=1 if channel_type== "Online Shopping"
replace Online_item=0 if channel_type!= "Online Shopping"
*If for a HH, if max val is 0, none of items purchased by HH were online. If max val is 1, at least one item row was an online purchase.
egen Online_at_All = max(Online_item), by(household_code)
*Looks Like it worked!
tab Online_at_All
* 40% of Items purchased in 2017 were purchased by households who bought at least one online item.
/*
Online_at_A |
         ll |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 | 39,415,929       59.31       59.31
          1 | 27,038,277       40.69      100.00
------------+-----------------------------------
      Total | 66,454,206      100.00
*/
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2017.dta", replace

******************************************************************
***TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
drop if Online_at_All==0
******************************************************************

save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\purchases of HH wMin1_Online_purch_2017.dta", replace

******************************************************************
*NOW MERGE WITH PANELIST FILE & STATE SALES TAX DATA 
******************************************************************
*PANELISTS
rename household_code household_cd
merge m:1 household_cd using "E:\NIELSEN data converted to dta\PANELISTS\panelists_2017.dta"
keep if _merge==3
drop _merge
*STATE SALES TAX RATES
merge m:1 fips_state_desc panel_year using "E:\Demand Estimation\Tax data\State Sales tax rates 2011 to 2020.dta"
keep if _merge==3
drop _merge
*STATE ONLINE SALES TAX COLLECTION/ADOPTION DATES
merge m:1 fips_state_desc using "E:\Demand Estimation\Tax data\Tax Foundation Onlines tax collection dates.dta"
keep if _merge==3
drop _merge


save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online Min1purch_HH w state sales tax 2017.dta", replace



**********************************************************************************************
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************

**********************************************************************************************
*GENERATE VARIABLES
**********************************************************************************************

*GENERATE TRADITIONAL DUMMY
generate Traditional = 1
replace Traditional = 0 if channel_type=="Online Shopping" & !missing(channel_type)

*RE-FORMAT PURCHASE DATE
gen purch3_date = date(purchase_date, "YMD")

*Generate variable to see if it is in a "control" no sales tax state (Montana, Oregon, Delaware, New Hampshire) 
gen NoSalesTax = 1 if Combined_TR == 0
replace NoSalesTax =0 if Combined_TR >  0
tab NoSalesTax 

*Generate Indicator Var. for whether item purchased was before or during/after Online Sales Tax Implemented
gen Post_Online_Tax=.
*If item purchased after Online tax date in a state that has a sales tax
replace Post_Online_Tax = 1 if   purch3_date >= TR_Start_Date & NoSalesTax==0
*Accounting for Items purchased in No Sales Tax states
replace Post_Online_Tax = 2 if NoSalesTax == 1
*Account for items purchased in states w/ sales tax, but BEFORE online sales tax law implementation
replace Post_Online_Tax = 0 if purch3_date < TR_Start_Date & NoSalesTax==0
tab Post_Online_Tax

*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
sum total_price_paid
count if total_price_paid<=0
*36,656  
*Using one penny for LN(0) problem in collapsing
replace total_price_paid=0.01 if total_price_paid<=0
*To avoid having more negatives, not adjusting for coupons. Looking at Sticker price

*Per Unit Cost
gen PerUnitCost = total_price_paid / quantity
*Using state TR + avg local
gen PUC_wCombTax = PerUnitCost * (1+Combined_TR)

*TAX EXPOSURE PRICE: Generate Price variable including tax if the item was exposed to Sales tax or not. 
gen PUC_applicable=.
*Item's price is just the PUC if bought in a a state w/out sales tax
replace PUC_applicable = PerUnitCost if Post_Online_Tax == 2
*Online Item's Price is PUC+state+local tax if bought in a state that has sales tax purchased after online taxation goods began.
replace PUC_applicable = PUC_wCombTax if channel_type=="Online Shopping" & Post_Online_Tax == 1
*Online item price just PUC (no sales tax) if it is in a state with Sales tax, but no online tax collection.
replace PUC_applicable = PerUnitCost if channel_type=="Online Shopping" & Post_Online_Tax == 0
*Tradtional item price in sales tax state 
replace PUC_applicable = PUC_wCombTax if channel_type!="Online Shopping" & NoSalesTax == 0
*Tradtional item price in state w/out sales tax
replace PUC_applicable =  PerUnitCost if channel_type!="Online Shopping" & NoSalesTax == 1

**********************************************************************************************
*ONLINE 
**********************************************************************************************
gen Online_item_lnP = .
*HH pays per unit cost with sales tax if the item was purchased on the day of or after the date online retail sales were collected for that HH's state  
replace Online_item_lnP =ln(PUC_wCombTax) if Post_Online_Tax == 1 & channel_type=="Online Shopping"
replace Online_item_lnP =ln(PerUnitCost) if Post_Online_Tax == 0 & channel_type=="Online Shopping"
*Replace missing values
replace Online_item_lnP = 0 if missing(Online_item_lnP)

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
*If item purchased in state w/ sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PUC_wCombTax) if NoSalesTax == 0 & channel_type!="Online Shopping"
*If item purchased in state w/OUT sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PerUnitCost) if NoSalesTax == 1 & channel_type!="Online Shopping"
*Replace missing values
replace Traditional_item_lnP = 0 if missing(Traditional_item_lnP)

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen EXP_item = PUC_applicable*quantity

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen  sum_exp =total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
count if exp_Trad==.

*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values
replace exp_Online = 0 if missing(exp_Online)


**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2017.dta", replace
**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
*Are you sure you want to collapse?
*Reaally Sure?
*Don't say I didn't warn you....

*Collapse the data to get HH level data for AIDS estimation
collapse exp_Online exp_Trad sum_exp sum_tot_P_paid Online_item_lnP Traditional_item_lnP ,by(household_cd)

*Hooray, looks ok!
/*
*I warned you
clear
use "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2017.dta"
*/

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online_purch_POST_COLLAPSE_2017.dta", replace

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************

*Check the Sum of Expenditure 
gen sum_exp_check = exp_Online + exp_Trad
gen Exp_check = 1 if sum_exp_check==sum_exp
replace Exp_check = 0 if sum_exp_check!=sum_exp
gen sum_dif = sum_exp - sum_exp_check

**********************************************************************************************
*GENERATE EXPENSE %_SHARES
**********************************************************************************************

*Use the sum_exp_check or else it won't add to 1 ; budget constraint violation!
gen expsh_Trad = exp_Trad / sum_exp_check
gen expsh_Online = exp_Online / sum_exp_check
format %14.0g expsh_Trad
format %14.0g expsh_Online
sum expsh_Online
sum expsh_Trad

**********************************************************************************************
*GENERATE PRICE INDEX
**********************************************************************************************

*Generate the Price Index weighted by amount spent on Online/Traditional goods
gen P_index = (Traditional_item_lnP * expsh_Trad ) + (Online_item_lnP*expsh_Online)
*
**Real Prices X/P term from Eq8 Deaton , but not real prices in the sense of comparing to prices in a base year
gen Real_Exp = sum_exp / P_index 
gen ln_Real_Exp = ln(Real_Exp)


save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2017.dta",replace


*********************************************************************************************
*AIDS  BASIC regressions
*********************************************************************************************
use "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2017.dta",replace

***  i=1 Traditional Expense Share 
reg expsh_Trad  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Trad_2017 

***  i=2 Online Expense Share 
reg expsh_Online  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Online_2017
***Same gamma coefficients!!! yea!

****TABLES
esttab expsh_Trad_2017 expsh_Online_2017  using Trad_Online_taxes2017.rtf, rtf  se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Trad & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace

esttab expsh_Trad_2017 expsh_Online_2017  using Trad_Online_taxes2017.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Traditional & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace






******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************







******************************************************************
*2016
******************************************************************
******************************************************************
*FIRST MEGA MERGE except panelists file
******************************************************************
use "E:\NIELSEN data converted to dta\PURCHASES\purchases_2016.dta"
*MERGE WITH TRIPS
merge m:1 trip_code_uc using "E:\NIELSEN data converted to dta\TRIPS\trips_2016.dta"
keep if _merge==3
drop _merge
*MERGE WITH RETAILERS MASTER
merge m:1 retailer_code using "E:\MASTER FILES\retailers.dta"
keep if _merge==3
drop _merge
*MERGE WITH PRODUCT MASTER
merge m:1 upc upc_ver_uc using "E:\MASTER FILES\PRODUCTS_MASTER.dta"
keep if _merge==3
drop _merge
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2016.dta", replace
******************************************************************
*FILTER OUT THOSE WHO MADE AT LEAST 1 ONLINE PURCHASE
******************************************************************
*KEEP ONLY HHs who have at least one Online Purchase
*Dummy Var for whether item purched row level was an Online purchase 
gen Online_item=.
replace Online_item=1 if channel_type== "Online Shopping"
replace Online_item=0 if channel_type!= "Online Shopping"
*If for a HH, if max val is 0, none of items purchased by HH were online. If max val is 1, at least one item row was an online purchase.
egen Online_at_All = max(Online_item), by(household_code)
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2016.dta", replace
******************************************************************
***TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
drop if Online_at_All==0
******************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\purchases of HH wMin1_Online_purch_2016.dta", replace
******************************************************************
*NOW MERGE WITH PANELIST FILE & STATE SALES TAX DATA 
******************************************************************
*PANELISTS
rename household_code household_cd
merge m:1 household_cd using "E:\NIELSEN data converted to dta\PANELISTS\panelists_2016.dta"
keep if _merge==3
drop _merge
*STATE SALES TAX RATES
merge m:1 fips_state_desc panel_year using "E:\Demand Estimation\Tax data\State Sales tax rates 2011 to 2020.dta"
keep if _merge==3
drop _merge
*STATE ONLINE SALES TAX COLLECTION/ADOPTION DATES
merge m:1 fips_state_desc using "E:\Demand Estimation\Tax data\Tax Foundation Onlines tax collection dates.dta"
keep if _merge==3
drop _merge



save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online Min1purch_HH w state sales tax 2016.dta", replace
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************

**********************************************************************************************
*GENERATE VARIABLES
**********************************************************************************************

*GENERATE TRADITIONAL DUMMY
generate Traditional = 1
replace Traditional = 0 if channel_type=="Online Shopping" & !missing(channel_type)

*RE-FORMAT PURCHASE DATE
gen purch3_date = date(purchase_date, "YMD")

*Generate variable to see if it is in a "control" no sales tax state (Montana, Oregon, Delaware, New Hampshire) 
gen NoSalesTax = 1 if Combined_TR == 0
replace NoSalesTax =0 if Combined_TR >  0
tab NoSalesTax 

*Generate Indicator Var. for whether item purchased was before or during/after Online Sales Tax Implemented
gen Post_Online_Tax=.
*If item purchased after Online tax date in a state that has a sales tax
replace Post_Online_Tax = 1 if   purch3_date >= TR_Start_Date & NoSalesTax==0
*Accounting for Items purchased in No Sales Tax states
replace Post_Online_Tax = 2 if NoSalesTax == 1
*Account for items purchased in states w/ sales tax, but BEFORE online sales tax law implementation
replace Post_Online_Tax = 0 if purch3_date < TR_Start_Date & NoSalesTax==0
tab Post_Online_Tax

*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
sum total_price_paid
count if total_price_paid<=0
*36,656  
*Using one penny for LN(0) problem in collapsing
replace total_price_paid=0.01 if total_price_paid<=0
*To avoid having more negatives, not adjusting for coupons. Looking at Sticker price

*Per Unit Cost
gen PerUnitCost = total_price_paid / quantity
*Using state TR + avg local
gen PUC_wCombTax = PerUnitCost * (1+Combined_TR)


*TAX EXPOSURE PRICE: Generate Price variable including tax if the item was exposed to Sales tax or not. 
gen PUC_applicable=.
*Item's price is just the PUC if bought in a a state w/out sales tax
replace PUC_applicable = PerUnitCost if Post_Online_Tax == 2
*Online Item's Price is PUC+state+local tax if bought in a state that has sales tax purchased after online taxation goods began.
replace PUC_applicable = PUC_wCombTax if channel_type=="Online Shopping" & Post_Online_Tax == 1
*Online item price just PUC (no sales tax) if it is in a state with Sales tax, but no online tax collection.
replace PUC_applicable = PerUnitCost if channel_type=="Online Shopping" & Post_Online_Tax == 0
*Tradtional item price in sales tax state 
replace PUC_applicable = PUC_wCombTax if channel_type!="Online Shopping" & NoSalesTax == 0
*Tradtional item price in state w/out sales tax
replace PUC_applicable =  PerUnitCost if channel_type!="Online Shopping" & NoSalesTax == 1

**********************************************************************************************
*ONLINE 
**********************************************************************************************
gen Online_item_lnP = .
*HH pays per unit cost with sales tax if the item was purchased on the day of or after the date online retail sales were collected for that HH's state  
replace Online_item_lnP =ln(PUC_wCombTax) if Post_Online_Tax == 1 & channel_type=="Online Shopping"
replace Online_item_lnP =ln(PerUnitCost) if Post_Online_Tax == 0 & channel_type=="Online Shopping"
*Replace missing values
replace Online_item_lnP = 0 if missing(Online_item_lnP)

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
*If item purchased in state w/ sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PUC_wCombTax) if NoSalesTax == 0 & channel_type!="Online Shopping"
*If item purchased in state w/OUT sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PerUnitCost) if NoSalesTax == 1 & channel_type!="Online Shopping"
*Replace missing values
replace Traditional_item_lnP = 0 if missing(Traditional_item_lnP)

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen EXP_item = PUC_applicable*quantity

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen  sum_exp =total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
count if exp_Trad==.

*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values

replace exp_Online = 0 if missing(exp_Online)



**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2016.dta", replace
**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************

*Collapse the data to get HH level data for AIDS estimation
collapse exp_Online exp_Trad sum_exp sum_tot_P_paid Online_item_lnP Traditional_item_lnP ,by(household_cd)

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online_purch_POST_COLLAPSE_2016.dta",replace
**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
*Check the Sum of Expenditure 
gen sum_exp_check = exp_Online + exp_Trad
gen Exp_check = 1 if sum_exp_check==sum_exp
replace Exp_check = 0 if sum_exp_check!=sum_exp
gen sum_dif = sum_exp - sum_exp_check

**********************************************************************************************
*GENERATE EXPENSE %_SHARES
**********************************************************************************************
*Use the sum_exp_check or else it won't add to 1 ; budget constraint violation!
gen expsh_Trad = exp_Trad / sum_exp_check
gen expsh_Online = exp_Online / sum_exp_check
format %14.0g expsh_Trad
format %14.0g expsh_Online
sum expsh_Online
sum expsh_Trad
**********************************************************************************************
*GENERATE PRICE INDEX
**********************************************************************************************
*Generate the Price Index weighted by amount spent on Online/Traditional goods
gen P_index = (Traditional_item_lnP * expsh_Trad ) + (Online_item_lnP*expsh_Online)
**Real Prices X/P term from Eq8 Deaton , but not real prices in the sense of comparing to prices in a base year
gen Real_Exp = sum_exp / P_index 
gen ln_Real_Exp = ln(Real_Exp)
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2016.dta",replace

*********************************************************************************************
*AIDS  BASIC regressions
*********************************************************************************************

***  i=1 Traditional Expense Share 
reg expsh_Trad  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Trad_2016 

***  i=2 Online Expense Share 
reg expsh_Online  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Online_2016
***Same gamma coefficients!!! yea!

****TABLES
esttab expsh_Trad_2016 expsh_Online_2016  using Trad_Online_taxes2016.rtf, rtf  se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Trad & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace

esttab expsh_Trad_2016 expsh_Online_2016  using Trad_Online_taxes2016.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Traditional & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace





******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************











******************************************************************
*2015
******************************************************************
******************************************************************
*FIRST MEGA MERGE except panelists file
******************************************************************
use "E:\NIELSEN data converted to dta\PURCHASES\purchases_2015.dta"
*MERGE WITH TRIPS
merge m:1 trip_code_uc using "E:\NIELSEN data converted to dta\TRIPS\trips_2015.dta"
keep if _merge==3
drop _merge
*MERGE WITH RETAILERS MASTER
merge m:1 retailer_code using "E:\MASTER FILES\retailers.dta"
keep if _merge==3
drop _merge
*MERGE WITH PRODUCT MASTER
merge m:1 upc upc_ver_uc using "E:\MASTER FILES\PRODUCTS_MASTER.dta"
keep if _merge==3
drop _merge
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2015.dta", replace
******************************************************************
*FILTER OUT THOSE WHO MADE AT LEAST 1 ONLINE PURCHASE
******************************************************************
*KEEP ONLY HHs who have at least one Online Purchase
*Dummy Var for whether item purched row level was an Online purchase 
gen Online_item=.
replace Online_item=1 if channel_type== "Online Shopping"
replace Online_item=0 if channel_type!= "Online Shopping"
*If for a HH, if max val is 0, none of items purchased by HH were online. If max val is 1, at least one item row was an online purchase.
egen Online_at_All = max(Online_item), by(household_code)
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2015.dta", replace
******************************************************************
***TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
drop if Online_at_All==0
******************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\purchases of HH wMin1_Online_purch_2015.dta", replace
******************************************************************
*NOW MERGE WITH PANELIST FILE & STATE SALES TAX DATA 
******************************************************************
*PANELISTS
rename household_code household_cd
merge m:1 household_cd using "E:\NIELSEN data converted to dta\PANELISTS\panelists_2015.dta"
keep if _merge==3
drop _merge
*STATE SALES TAX RATES
merge m:1 fips_state_desc panel_year using "E:\Demand Estimation\Tax data\State Sales tax rates 2011 to 2020.dta"
keep if _merge==3
drop _merge
*STATE ONLINE SALES TAX COLLECTION/ADOPTION DATES
merge m:1 fips_state_desc using "E:\Demand Estimation\Tax data\Tax Foundation Onlines tax collection dates.dta"
keep if _merge==3
drop _merge



save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online Min1purch_HH w state sales tax 2015.dta", replace
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************

**********************************************************************************************
*GENERATE VARIABLES
**********************************************************************************************

*GENERATE TRADITIONAL DUMMY
generate Traditional = 1
replace Traditional = 0 if channel_type=="Online Shopping" & !missing(channel_type)

*RE-FORMAT PURCHASE DATE
gen purch3_date = date(purchase_date, "YMD")

*Generate variable to see if it is in a "control" no sales tax state (Montana, Oregon, Delaware, New Hampshire) 
gen NoSalesTax = 1 if Combined_TR == 0
replace NoSalesTax =0 if Combined_TR >  0
tab NoSalesTax 

*Generate Indicator Var. for whether item purchased was before or during/after Online Sales Tax Implemented
gen Post_Online_Tax=.
*If item purchased after Online tax date in a state that has a sales tax
replace Post_Online_Tax = 1 if   purch3_date >= TR_Start_Date & NoSalesTax==0
*Accounting for Items purchased in No Sales Tax states
replace Post_Online_Tax = 2 if NoSalesTax == 1
*Account for items purchased in states w/ sales tax, but BEFORE online sales tax law implementation
replace Post_Online_Tax = 0 if purch3_date < TR_Start_Date & NoSalesTax==0
tab Post_Online_Tax

*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
sum total_price_paid
count if total_price_paid<=0
*36,656  
*Using one penny for LN(0) problem in collapsing
replace total_price_paid=0.01 if total_price_paid<=0
*To avoid having more negatives, not adjusting for coupons. Looking at Sticker price

*Per Unit Cost
gen PerUnitCost = total_price_paid / quantity
*Using state TR + avg local
gen PUC_wCombTax = PerUnitCost * (1+Combined_TR)


*TAX EXPOSURE PRICE: Generate Price variable including tax if the item was exposed to Sales tax or not. 
gen PUC_applicable=.
*Item's price is just the PUC if bought in a a state w/out sales tax
replace PUC_applicable = PerUnitCost if Post_Online_Tax == 2
*Online Item's Price is PUC+state+local tax if bought in a state that has sales tax purchased after online taxation goods began.
replace PUC_applicable = PUC_wCombTax if channel_type=="Online Shopping" & Post_Online_Tax == 1
*Online item price just PUC (no sales tax) if it is in a state with Sales tax, but no online tax collection.
replace PUC_applicable = PerUnitCost if channel_type=="Online Shopping" & Post_Online_Tax == 0
*Tradtional item price in sales tax state 
replace PUC_applicable = PUC_wCombTax if channel_type!="Online Shopping" & NoSalesTax == 0
*Tradtional item price in state w/out sales tax
replace PUC_applicable =  PerUnitCost if channel_type!="Online Shopping" & NoSalesTax == 1

**********************************************************************************************
*ONLINE 
**********************************************************************************************
gen Online_item_lnP = .
*HH pays per unit cost with sales tax if the item was purchased on the day of or after the date online retail sales were collected for that HH's state  
replace Online_item_lnP =ln(PUC_wCombTax) if Post_Online_Tax == 1 & channel_type=="Online Shopping"
replace Online_item_lnP =ln(PerUnitCost) if Post_Online_Tax == 0 & channel_type=="Online Shopping"
*Replace missing values
replace Online_item_lnP = 0 if missing(Online_item_lnP)

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
*If item purchased in state w/ sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PUC_wCombTax) if NoSalesTax == 0 & channel_type!="Online Shopping"
*If item purchased in state w/OUT sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PerUnitCost) if NoSalesTax == 1 & channel_type!="Online Shopping"
*Replace missing values
replace Traditional_item_lnP = 0 if missing(Traditional_item_lnP)

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen EXP_item = PUC_applicable*quantity

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen  sum_exp =total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
count if exp_Trad==.

*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values

replace exp_Online = 0 if missing(exp_Online)



**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2015.dta", replace
**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************

*Collapse the data to get HH level data for AIDS estimation
collapse exp_Online exp_Trad sum_exp sum_tot_P_paid Online_item_lnP Traditional_item_lnP ,by(household_cd)

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online_purch_POST_COLLAPSE_2015.dta", replace

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
*Check the Sum of Expenditure 
gen sum_exp_check = exp_Online + exp_Trad
gen Exp_check = 1 if sum_exp_check==sum_exp
replace Exp_check = 0 if sum_exp_check!=sum_exp
gen sum_dif = sum_exp - sum_exp_check

**********************************************************************************************
*GENERATE EXPENSE %_SHARES
**********************************************************************************************
*Use the sum_exp_check or else it won't add to 1 ; budget constraint violation!
gen expsh_Trad = exp_Trad / sum_exp_check
gen expsh_Online = exp_Online / sum_exp_check
format %14.0g expsh_Trad
format %14.0g expsh_Online
sum expsh_Online
sum expsh_Trad
**********************************************************************************************
*GENERATE PRICE INDEX
**********************************************************************************************
*Generate the Price Index weighted by amount spent on Online/Traditional goods
gen P_index = (Traditional_item_lnP * expsh_Trad ) + (Online_item_lnP*expsh_Online)
**Real Prices X/P term from Eq8 Deaton , but not real prices in the sense of comparing to prices in a base year
gen Real_Exp = sum_exp / P_index 
gen ln_Real_Exp = ln(Real_Exp)
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2015.dta", replace


*********************************************************************************************
*AIDS  BASIC regressions
*********************************************************************************************

***  i=1 Traditional Expense Share 
reg expsh_Trad  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Trad_2015

***  i=2 Online Expense Share 
reg expsh_Online  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Online_2015
***Same gamma coefficients!!! yea!

****TABLES
esttab expsh_Trad_2015 expsh_Online_2015  using Trad_Online_taxes2015.rtf, rtf  se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Trad & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace

esttab expsh_Trad_2015 expsh_Online_2015  using Trad_Online_taxes2015.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Traditional & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace






******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************











******************************************************************
*2014
******************************************************************
******************************************************************
*FIRST MEGA MERGE except panelists file
******************************************************************
use "E:\NIELSEN data converted to dta\PURCHASES\purchases_2014.dta"
*MERGE WITH TRIPS
merge m:1 trip_code_uc using "E:\NIELSEN data converted to dta\TRIPS\trips_2014.dta"
keep if _merge==3
drop _merge
*MERGE WITH RETAILERS MASTER
merge m:1 retailer_code using "E:\MASTER FILES\retailers.dta"
keep if _merge==3
drop _merge
*MERGE WITH PRODUCT MASTER
merge m:1 upc upc_ver_uc using "E:\MASTER FILES\PRODUCTS_MASTER.dta"
keep if _merge==3
drop _merge
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2014.dta", replace
******************************************************************
*FILTER OUT THOSE WHO MADE AT LEAST 1 ONLINE PURCHASE
******************************************************************
*KEEP ONLY HHs who have at least one Online Purchase
*Dummy Var for whether item purched row level was an Online purchase 
gen Online_item=.
replace Online_item=1 if channel_type== "Online Shopping"
replace Online_item=0 if channel_type!= "Online Shopping"
*If for a HH, if max val is 0, none of items purchased by HH were online. If max val is 1, at least one item row was an online purchase.
egen Online_at_All = max(Online_item), by(household_code)
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2014.dta", replace
******************************************************************
***TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
drop if Online_at_All==0
******************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\purchases of HH wMin1_Online_purch_2014.dta", replace
******************************************************************
*NOW MERGE WITH PANELIST FILE & STATE SALES TAX DATA 
******************************************************************
*PANELISTS
rename household_code household_cd
merge m:1 household_cd using "E:\NIELSEN data converted to dta\PANELISTS\panelists_2014.dta"
keep if _merge==3
drop _merge
*STATE SALES TAX RATES
merge m:1 fips_state_desc panel_year using "E:\Demand Estimation\Tax data\State Sales tax rates 2011 to 2020.dta"
keep if _merge==3
drop _merge
*STATE ONLINE SALES TAX COLLECTION/ADOPTION DATES
merge m:1 fips_state_desc using "E:\Demand Estimation\Tax data\Tax Foundation Onlines tax collection dates.dta"
keep if _merge==3
drop _merge



save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online Min1purch_HH w state sales tax 2014.dta", replace
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************

**********************************************************************************************
*GENERATE VARIABLES
**********************************************************************************************

*GENERATE TRADITIONAL DUMMY
generate Traditional = 1
replace Traditional = 0 if channel_type=="Online Shopping" & !missing(channel_type)

*RE-FORMAT PURCHASE DATE
gen purch3_date = date(purchase_date, "YMD")

*Generate variable to see if it is in a "control" no sales tax state (Montana, Oregon, Delaware, New Hampshire) 
gen NoSalesTax = 1 if Combined_TR == 0
replace NoSalesTax =0 if Combined_TR >  0
tab NoSalesTax 

*Generate Indicator Var. for whether item purchased was before or during/after Online Sales Tax Implemented
gen Post_Online_Tax=.
*If item purchased after Online tax date in a state that has a sales tax
replace Post_Online_Tax = 1 if   purch3_date >= TR_Start_Date & NoSalesTax==0
*Accounting for Items purchased in No Sales Tax states
replace Post_Online_Tax = 2 if NoSalesTax == 1
*Account for items purchased in states w/ sales tax, but BEFORE online sales tax law implementation
replace Post_Online_Tax = 0 if purch3_date < TR_Start_Date & NoSalesTax==0
tab Post_Online_Tax

*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
sum total_price_paid
count if total_price_paid<=0
*36,656  
*Using one penny for LN(0) problem in collapsing
replace total_price_paid=0.01 if total_price_paid<=0
*To avoid having more negatives, not adjusting for coupons. Looking at Sticker price

*Per Unit Cost
gen PerUnitCost = total_price_paid / quantity
*Using state TR + avg local
gen PUC_wCombTax = PerUnitCost * (1+Combined_TR)


*TAX EXPOSURE PRICE: Generate Price variable including tax if the item was exposed to Sales tax or not. 
gen PUC_applicable=.
*Item's price is just the PUC if bought in a a state w/out sales tax
replace PUC_applicable = PerUnitCost if Post_Online_Tax == 2
*Online Item's Price is PUC+state+local tax if bought in a state that has sales tax purchased after online taxation goods began.
replace PUC_applicable = PUC_wCombTax if channel_type=="Online Shopping" & Post_Online_Tax == 1
*Online item price just PUC (no sales tax) if it is in a state with Sales tax, but no online tax collection.
replace PUC_applicable = PerUnitCost if channel_type=="Online Shopping" & Post_Online_Tax == 0
*Tradtional item price in sales tax state 
replace PUC_applicable = PUC_wCombTax if channel_type!="Online Shopping" & NoSalesTax == 0
*Tradtional item price in state w/out sales tax
replace PUC_applicable =  PerUnitCost if channel_type!="Online Shopping" & NoSalesTax == 1

**********************************************************************************************
*ONLINE 
**********************************************************************************************
gen Online_item_lnP = .
*HH pays per unit cost with sales tax if the item was purchased on the day of or after the date online retail sales were collected for that HH's state  
replace Online_item_lnP =ln(PUC_wCombTax) if Post_Online_Tax == 1 & channel_type=="Online Shopping"
replace Online_item_lnP =ln(PerUnitCost) if Post_Online_Tax == 0 & channel_type=="Online Shopping"
*Replace missing values
replace Online_item_lnP = 0 if missing(Online_item_lnP)

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
*If item purchased in state w/ sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PUC_wCombTax) if NoSalesTax == 0 & channel_type!="Online Shopping"
*If item purchased in state w/OUT sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PerUnitCost) if NoSalesTax == 1 & channel_type!="Online Shopping"
*Replace missing values
replace Traditional_item_lnP = 0 if missing(Traditional_item_lnP)

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen EXP_item = PUC_applicable*quantity

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen  sum_exp =total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
count if exp_Trad==.

*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values

replace exp_Online = 0 if missing(exp_Online)



**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2014.dta", replace
**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************

*Collapse the data to get HH level data for AIDS estimation
collapse exp_Online exp_Trad sum_exp sum_tot_P_paid Online_item_lnP Traditional_item_lnP ,by(household_cd)

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online_purch_POST_COLLAPSE_2014.dta", replace

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
*Check the Sum of Expenditure 
gen sum_exp_check = exp_Online + exp_Trad
gen Exp_check = 1 if sum_exp_check==sum_exp
replace Exp_check = 0 if sum_exp_check!=sum_exp
gen sum_dif = sum_exp - sum_exp_check

**********************************************************************************************
*GENERATE EXPENSE %_SHARES
**********************************************************************************************
*Use the sum_exp_check or else it won't add to 1 ; budget constraint violation!
gen expsh_Trad = exp_Trad / sum_exp_check
gen expsh_Online = exp_Online / sum_exp_check
format %14.0g expsh_Trad
format %14.0g expsh_Online
sum expsh_Online
sum expsh_Trad
**********************************************************************************************
*GENERATE PRICE INDEX
**********************************************************************************************
*Generate the Price Index weighted by amount spent on Online/Traditional goods
gen P_index = (Traditional_item_lnP * expsh_Trad ) + (Online_item_lnP*expsh_Online)
**Real Prices X/P term from Eq8 Deaton , but not real prices in the sense of comparing to prices in a base year
gen Real_Exp = sum_exp / P_index 
gen ln_Real_Exp = ln(Real_Exp)
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2014.dta", replace


*********************************************************************************************
*AIDS  BASIC regressions
*********************************************************************************************

***  i=1 Traditional Expense Share 
reg expsh_Trad  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Trad_2014 

***  i=2 Online Expense Share 
reg expsh_Online  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Online_2014
***Same gamma coefficients!!! yea!

****TABLES
esttab expsh_Trad_2014 expsh_Online_2014  using Trad_Online_taxes2014.rtf, rtf  se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Trad & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace

esttab expsh_Trad_2014 expsh_Online_2014  using Trad_Online_taxes2014.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Traditional & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace





******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************










******************************************************************





******************************************************************
*2013
******************************************************************

******************************************************************
*FIRST MEGA MERGE except panelists file
******************************************************************
use "E:\NIELSEN data converted to dta\PURCHASES\purchases_2013.dta"
*MERGE WITH TRIPS
merge m:1 trip_code_uc using "E:\NIELSEN data converted to dta\TRIPS\trips_2013.dta"
keep if _merge==3
drop _merge
*MERGE WITH RETAILERS MASTER
merge m:1 retailer_code using "E:\MASTER FILES\retailers.dta"
keep if _merge==3
drop _merge
*MERGE WITH PRODUCT MASTER
merge m:1 upc upc_ver_uc using "E:\MASTER FILES\PRODUCTS_MASTER.dta"
keep if _merge==3
drop _merge
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2013.dta", replace
******************************************************************
*FILTER OUT THOSE WHO MADE AT LEAST 1 ONLINE PURCHASE
******************************************************************
*KEEP ONLY HHs who have at least one Online Purchase
*Dummy Var for whether item purched row level was an Online purchase 
gen Online_item=.
replace Online_item=1 if channel_type== "Online Shopping"
replace Online_item=0 if channel_type!= "Online Shopping"
*If for a HH, if max val is 0, none of items purchased by HH were online. If max val is 1, at least one item row was an online purchase.
egen Online_at_All = max(Online_item), by(household_code)
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2013.dta", replace
******************************************************************
***TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
drop if Online_at_All==0
******************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\purchases of HH wMin1_Online_purch_2013.dta", replace
******************************************************************
*NOW MERGE WITH PANELIST FILE & STATE SALES TAX DATA 
******************************************************************
*PANELISTS
rename household_code household_cd
merge m:1 household_cd using "E:\NIELSEN data converted to dta\PANELISTS\panelists_2013.dta"
keep if _merge==3
drop _merge
*STATE SALES TAX RATES
merge m:1 fips_state_desc panel_year using "E:\Demand Estimation\Tax data\State Sales tax rates 2011 to 2020.dta"
keep if _merge==3
drop _merge
*STATE ONLINE SALES TAX COLLECTION/ADOPTION DATES
merge m:1 fips_state_desc using "E:\Demand Estimation\Tax data\Tax Foundation Onlines tax collection dates.dta"
keep if _merge==3
drop _merge



save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online Min1purch_HH w state sales tax 2013.dta", replace
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************

**********************************************************************************************
*GENERATE VARIABLES
**********************************************************************************************

*GENERATE TRADITIONAL DUMMY
generate Traditional = 1
replace Traditional = 0 if channel_type=="Online Shopping" & !missing(channel_type)

*RE-FORMAT PURCHASE DATE
gen purch3_date = date(purchase_date, "YMD")

*Generate variable to see if it is in a "control" no sales tax state (Montana, Oregon, Delaware, New Hampshire) 
gen NoSalesTax = 1 if Combined_TR == 0
replace NoSalesTax =0 if Combined_TR >  0
tab NoSalesTax 

*Generate Indicator Var. for whether item purchased was before or during/after Online Sales Tax Implemented
gen Post_Online_Tax=.
*If item purchased after Online tax date in a state that has a sales tax
replace Post_Online_Tax = 1 if   purch3_date >= TR_Start_Date & NoSalesTax==0
*Accounting for Items purchased in No Sales Tax states
replace Post_Online_Tax = 2 if NoSalesTax == 1
*Account for items purchased in states w/ sales tax, but BEFORE online sales tax law implementation
replace Post_Online_Tax = 0 if purch3_date < TR_Start_Date & NoSalesTax==0
tab Post_Online_Tax

*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
sum total_price_paid
count if total_price_paid<=0
*36,656  
*Using one penny for LN(0) problem in collapsing
replace total_price_paid=0.01 if total_price_paid<=0
*To avoid having more negatives, not adjusting for coupons. Looking at Sticker price

*Per Unit Cost
gen PerUnitCost = total_price_paid / quantity
*Using state TR + avg local
gen PUC_wCombTax = PerUnitCost * (1+Combined_TR)


*TAX EXPOSURE PRICE: Generate Price variable including tax if the item was exposed to Sales tax or not. 
gen PUC_applicable=.
*Item's price is just the PUC if bought in a a state w/out sales tax
replace PUC_applicable = PerUnitCost if Post_Online_Tax == 2
*Online Item's Price is PUC+state+local tax if bought in a state that has sales tax purchased after online taxation goods began.
replace PUC_applicable = PUC_wCombTax if channel_type=="Online Shopping" & Post_Online_Tax == 1
*Online item price just PUC (no sales tax) if it is in a state with Sales tax, but no online tax collection.
replace PUC_applicable = PerUnitCost if channel_type=="Online Shopping" & Post_Online_Tax == 0
*Tradtional item price in sales tax state 
replace PUC_applicable = PUC_wCombTax if channel_type!="Online Shopping" & NoSalesTax == 0
*Tradtional item price in state w/out sales tax
replace PUC_applicable =  PerUnitCost if channel_type!="Online Shopping" & NoSalesTax == 1

**********************************************************************************************
*ONLINE 
**********************************************************************************************
gen Online_item_lnP = .
*HH pays per unit cost with sales tax if the item was purchased on the day of or after the date online retail sales were collected for that HH's state  
replace Online_item_lnP =ln(PUC_wCombTax) if Post_Online_Tax == 1 & channel_type=="Online Shopping"
replace Online_item_lnP =ln(PerUnitCost) if Post_Online_Tax == 0 & channel_type=="Online Shopping"
*Replace missing values
replace Online_item_lnP = 0 if missing(Online_item_lnP)

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
*If item purchased in state w/ sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PUC_wCombTax) if NoSalesTax == 0 & channel_type!="Online Shopping"
*If item purchased in state w/OUT sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PerUnitCost) if NoSalesTax == 1 & channel_type!="Online Shopping"
*Replace missing values
replace Traditional_item_lnP = 0 if missing(Traditional_item_lnP)

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen EXP_item = PUC_applicable*quantity

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen  sum_exp =total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
count if exp_Trad==.

*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values

replace exp_Online = 0 if missing(exp_Online)



**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2013.dta", replace
**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************

*Collapse the data to get HH level data for AIDS estimation
collapse exp_Online exp_Trad sum_exp sum_tot_P_paid Online_item_lnP Traditional_item_lnP ,by(household_cd)

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online_purch_POST_COLLAPSE_2013.dta", replace

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
*Check the Sum of Expenditure 
gen sum_exp_check = exp_Online + exp_Trad
gen Exp_check = 1 if sum_exp_check==sum_exp
replace Exp_check = 0 if sum_exp_check!=sum_exp
gen sum_dif = sum_exp - sum_exp_check

**********************************************************************************************
*GENERATE EXPENSE %_SHARES
**********************************************************************************************
*Use the sum_exp_check or else it won't add to 1 ; budget constraint violation!
gen expsh_Trad = exp_Trad / sum_exp_check
gen expsh_Online = exp_Online / sum_exp_check
format %14.0g expsh_Trad
format %14.0g expsh_Online
sum expsh_Online
sum expsh_Trad
**********************************************************************************************
*GENERATE PRICE INDEX
**********************************************************************************************
*Generate the Price Index weighted by amount spent on Online/Traditional goods
gen P_index = (Traditional_item_lnP * expsh_Trad ) + (Online_item_lnP*expsh_Online)
**Real Prices X/P term from Eq8 Deaton , but not real prices in the sense of comparing to prices in a base year
gen Real_Exp = sum_exp / P_index 
gen ln_Real_Exp = ln(Real_Exp)
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2013.dta", replace


*********************************************************************************************
*AIDS  BASIC regressions
*********************************************************************************************

***  i=1 Traditional Expense Share 
reg expsh_Trad  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Trad_2013 

***  i=2 Online Expense Share 
reg expsh_Online  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Online_2013
***Same gamma coefficients!!! yea!

****TABLES
esttab expsh_Trad_2013 expsh_Online_2013  using Trad_Online_taxes2013.rtf, rtf  se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Trad & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace

esttab expsh_Trad_2013 expsh_Online_2013 using Trad_Online_taxes2013.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Traditional & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace









 
******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************










******************************************************************
*2012
******************************************************************
******************************************************************
*FIRST MEGA MERGE except panelists file
******************************************************************
use "E:\NIELSEN data converted to dta\PURCHASES\purchases_2012.dta"
*MERGE WITH TRIPS
merge m:1 trip_code_uc using "E:\NIELSEN data converted to dta\TRIPS\trips_2012.dta"
keep if _merge==3
drop _merge
*MERGE WITH RETAILERS MASTER
merge m:1 retailer_code using "E:\MASTER FILES\retailers.dta"
keep if _merge==3
drop _merge
*MERGE WITH PRODUCT MASTER
merge m:1 upc upc_ver_uc using "E:\MASTER FILES\PRODUCTS_MASTER.dta"
keep if _merge==3
drop _merge
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2012.dta", replace
******************************************************************
*FILTER OUT THOSE WHO MADE AT LEAST 1 ONLINE PURCHASE
******************************************************************
*KEEP ONLY HHs who have at least one Online Purchase
*Dummy Var for whether item purched row level was an Online purchase 
gen Online_item=.
replace Online_item=1 if channel_type== "Online Shopping"
replace Online_item=0 if channel_type!= "Online Shopping"
*If for a HH, if max val is 0, none of items purchased by HH were online. If max val is 1, at least one item row was an online purchase.
egen Online_at_All = max(Online_item), by(household_code)
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2012.dta", replace
******************************************************************
***TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
drop if Online_at_All==0
******************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\purchases of HH wMin1_Online_purch_2012.dta", replace
******************************************************************
*NOW MERGE WITH PANELIST FILE & STATE SALES TAX DATA 
******************************************************************
*PANELISTS
rename household_code household_cd
merge m:1 household_cd using "E:\NIELSEN data converted to dta\PANELISTS\panelists_2012.dta"
keep if _merge==3
drop _merge
*STATE SALES TAX RATES
merge m:1 fips_state_desc panel_year using "E:\Demand Estimation\Tax data\State Sales tax rates 2011 to 2020.dta"
keep if _merge==3
drop _merge
*STATE ONLINE SALES TAX COLLECTION/ADOPTION DATES
merge m:1 fips_state_desc using "E:\Demand Estimation\Tax data\Tax Foundation Onlines tax collection dates.dta"
keep if _merge==3
drop _merge



save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online Min1purch_HH w state sales tax 2012.dta", replace
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************

**********************************************************************************************
*GENERATE VARIABLES
**********************************************************************************************

*GENERATE TRADITIONAL DUMMY
generate Traditional = 1
replace Traditional = 0 if channel_type=="Online Shopping" & !missing(channel_type)

*RE-FORMAT PURCHASE DATE
gen purch3_date = date(purchase_date, "YMD")

*Generate variable to see if it is in a "control" no sales tax state (Montana, Oregon, Delaware, New Hampshire) 
gen NoSalesTax = 1 if Combined_TR == 0
replace NoSalesTax =0 if Combined_TR >  0
tab NoSalesTax 

*Generate Indicator Var. for whether item purchased was before or during/after Online Sales Tax Implemented
gen Post_Online_Tax=.
*If item purchased after Online tax date in a state that has a sales tax
replace Post_Online_Tax = 1 if   purch3_date >= TR_Start_Date & NoSalesTax==0
*Accounting for Items purchased in No Sales Tax states
replace Post_Online_Tax = 2 if NoSalesTax == 1
*Account for items purchased in states w/ sales tax, but BEFORE online sales tax law implementation
replace Post_Online_Tax = 0 if purch3_date < TR_Start_Date & NoSalesTax==0
tab Post_Online_Tax

*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
sum total_price_paid
count if total_price_paid<=0
*36,656  
*Using one penny for LN(0) problem in collapsing
replace total_price_paid=0.01 if total_price_paid<=0
*To avoid having more negatives, not adjusting for coupons. Looking at Sticker price

*Per Unit Cost
gen PerUnitCost = total_price_paid / quantity
*Using state TR + avg local
gen PUC_wCombTax = PerUnitCost * (1+Combined_TR)


*TAX EXPOSURE PRICE: Generate Price variable including tax if the item was exposed to Sales tax or not. 
gen PUC_applicable=.
*Item's price is just the PUC if bought in a a state w/out sales tax
replace PUC_applicable = PerUnitCost if Post_Online_Tax == 2
*Online Item's Price is PUC+state+local tax if bought in a state that has sales tax purchased after online taxation goods began.
replace PUC_applicable = PUC_wCombTax if channel_type=="Online Shopping" & Post_Online_Tax == 1
*Online item price just PUC (no sales tax) if it is in a state with Sales tax, but no online tax collection.
replace PUC_applicable = PerUnitCost if channel_type=="Online Shopping" & Post_Online_Tax == 0
*Tradtional item price in sales tax state 
replace PUC_applicable = PUC_wCombTax if channel_type!="Online Shopping" & NoSalesTax == 0
*Tradtional item price in state w/out sales tax
replace PUC_applicable =  PerUnitCost if channel_type!="Online Shopping" & NoSalesTax == 1

**********************************************************************************************
*ONLINE 
**********************************************************************************************
gen Online_item_lnP = .
*HH pays per unit cost with sales tax if the item was purchased on the day of or after the date online retail sales were collected for that HH's state  
replace Online_item_lnP =ln(PUC_wCombTax) if Post_Online_Tax == 1 & channel_type=="Online Shopping"
replace Online_item_lnP =ln(PerUnitCost) if Post_Online_Tax == 0 & channel_type=="Online Shopping"
*Replace missing values
replace Online_item_lnP = 0 if missing(Online_item_lnP)

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
*If item purchased in state w/ sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PUC_wCombTax) if NoSalesTax == 0 & channel_type!="Online Shopping"
*If item purchased in state w/OUT sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PerUnitCost) if NoSalesTax == 1 & channel_type!="Online Shopping"
*Replace missing values
replace Traditional_item_lnP = 0 if missing(Traditional_item_lnP)

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen EXP_item = PUC_applicable*quantity

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen  sum_exp =total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
count if exp_Trad==.

*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values

replace exp_Online = 0 if missing(exp_Online)



**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2012.dta", replace
**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************

*Collapse the data to get HH level data for AIDS estimation
collapse exp_Online exp_Trad sum_exp sum_tot_P_paid Online_item_lnP Traditional_item_lnP ,by(household_cd)

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online_purch_POST_COLLAPSE_2012.dta",replace
**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
*Check the Sum of Expenditure 
gen sum_exp_check = exp_Online + exp_Trad
gen Exp_check = 1 if sum_exp_check==sum_exp
replace Exp_check = 0 if sum_exp_check!=sum_exp
gen sum_dif = sum_exp - sum_exp_check

**********************************************************************************************
*GENERATE EXPENSE %_SHARES
**********************************************************************************************
*Use the sum_exp_check or else it won't add to 1 ; budget constraint violation!
gen expsh_Trad = exp_Trad / sum_exp_check
gen expsh_Online = exp_Online / sum_exp_check
format %14.0g expsh_Trad
format %14.0g expsh_Online
sum expsh_Online
sum expsh_Trad
**********************************************************************************************
*GENERATE PRICE INDEX
**********************************************************************************************
*Generate the Price Index weighted by amount spent on Online/Traditional goods
gen P_index = (Traditional_item_lnP * expsh_Trad ) + (Online_item_lnP*expsh_Online)
**Real Prices X/P term from Eq8 Deaton , but not real prices in the sense of comparing to prices in a base year
gen Real_Exp = sum_exp / P_index 
gen ln_Real_Exp = ln(Real_Exp)
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2012.dta",replace

*********************************************************************************************
*AIDS  BASIC regressions
*********************************************************************************************

***  i=1 Traditional Expense Share 
reg expsh_Trad  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Trad_2012

***  i=2 Online Expense Share 
reg expsh_Online  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Online_2012
***Same gamma coefficients!!! yea!

****TABLES
esttab expsh_Trad_2012 expsh_Online_2012  using Trad_Online_taxes2012.rtf, rtf  se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Trad & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace

esttab expsh_Trad_2012 expsh_Online_2012  using Trad_Online_taxes2012.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Traditional & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace





******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************




******************************************************************
*2011
******************************************************************
******************************************************************
*FIRST MEGA MERGE except panelists file
******************************************************************
use "E:\NIELSEN data converted to dta\PURCHASES\purchases_2011.dta"
*MERGE WITH TRIPS
merge m:1 trip_code_uc using "E:\NIELSEN data converted to dta\TRIPS\trips_2011.dta"
keep if _merge==3
drop _merge
*MERGE WITH RETAILERS MASTER
merge m:1 retailer_code using "E:\MASTER FILES\retailers.dta"
keep if _merge==3
drop _merge
*MERGE WITH PRODUCT MASTER
merge m:1 upc upc_ver_uc using "E:\MASTER FILES\PRODUCTS_MASTER.dta"
keep if _merge==3
drop _merge
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2011.dta", replace
******************************************************************
*FILTER OUT THOSE WHO MADE AT LEAST 1 ONLINE PURCHASE
******************************************************************
*KEEP ONLY HHs who have at least one Online Purchase
*Dummy Var for whether item purched row level was an Online purchase 
gen Online_item=.
replace Online_item=1 if channel_type== "Online Shopping"
replace Online_item=0 if channel_type!= "Online Shopping"
*If for a HH, if max val is 0, none of items purchased by HH were online. If max val is 1, at least one item row was an online purchase.
egen Online_at_All = max(Online_item), by(household_code)



save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2011.dta", replace
******************************************************************
***TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
drop if Online_at_All==0
******************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\purchases of HH wMin1_Online_purch_2011.dta", replace
******************************************************************
*NOW MERGE WITH PANELIST FILE & STATE SALES TAX DATA 
******************************************************************
*PANELISTS
rename household_code household_cd
merge m:1 household_cd using "E:\NIELSEN data converted to dta\PANELISTS\panelists_2011.dta"
keep if _merge==3
drop _merge
*STATE SALES TAX RATES
merge m:1 fips_state_desc panel_year using "E:\Demand Estimation\Tax data\State Sales tax rates 2011 to 2020.dta"
keep if _merge==3
drop _merge
*STATE ONLINE SALES TAX COLLECTION/ADOPTION DATES
merge m:1 fips_state_desc using "E:\Demand Estimation\Tax data\Tax Foundation Onlines tax collection dates.dta"
keep if _merge==3
drop _merge



save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online Min1purch_HH w state sales tax 2011.dta", replace
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************

**********************************************************************************************
*GENERATE VARIABLES
**********************************************************************************************

*GENERATE TRADITIONAL DUMMY
generate Traditional = 1
replace Traditional = 0 if channel_type=="Online Shopping" & !missing(channel_type)

*RE-FORMAT PURCHASE DATE
gen purch3_date = date(purchase_date, "YMD")

*Generate variable to see if it is in a "control" no sales tax state (Montana, Oregon, Delaware, New Hampshire) 
gen NoSalesTax = 1 if Combined_TR == 0
replace NoSalesTax =0 if Combined_TR >  0
tab NoSalesTax 

*Generate Indicator Var. for whether item purchased was before or during/after Online Sales Tax Implemented
gen Post_Online_Tax=.
*If item purchased after Online tax date in a state that has a sales tax
replace Post_Online_Tax = 1 if   purch3_date >= TR_Start_Date & NoSalesTax==0
*Accounting for Items purchased in No Sales Tax states
replace Post_Online_Tax = 2 if NoSalesTax == 1
*Account for items purchased in states w/ sales tax, but BEFORE online sales tax law implementation
replace Post_Online_Tax = 0 if purch3_date < TR_Start_Date & NoSalesTax==0
tab Post_Online_Tax

*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
sum total_price_paid
count if total_price_paid<=0
*36,656  
*Using one penny for LN(0) problem in collapsing
replace total_price_paid=0.01 if total_price_paid<=0
*To avoid having more negatives, not adjusting for coupons. Looking at Sticker price

*Per Unit Cost
gen PerUnitCost = total_price_paid / quantity
*Using state TR + avg local
gen PUC_wCombTax = PerUnitCost * (1+Combined_TR)


*TAX EXPOSURE PRICE: Generate Price variable including tax if the item was exposed to Sales tax or not. 
gen PUC_applicable=.
*Item's price is just the PUC if bought in a a state w/out sales tax
replace PUC_applicable = PerUnitCost if Post_Online_Tax == 2
*Online Item's Price is PUC+state+local tax if bought in a state that has sales tax purchased after online taxation goods began.
replace PUC_applicable = PUC_wCombTax if channel_type=="Online Shopping" & Post_Online_Tax == 1
*Online item price just PUC (no sales tax) if it is in a state with Sales tax, but no online tax collection.
replace PUC_applicable = PerUnitCost if channel_type=="Online Shopping" & Post_Online_Tax == 0
*Tradtional item price in sales tax state 
replace PUC_applicable = PUC_wCombTax if channel_type!="Online Shopping" & NoSalesTax == 0
*Tradtional item price in state w/out sales tax
replace PUC_applicable =  PerUnitCost if channel_type!="Online Shopping" & NoSalesTax == 1

**********************************************************************************************
*ONLINE 
**********************************************************************************************
gen Online_item_lnP = .
*HH pays per unit cost with sales tax if the item was purchased on the day of or after the date online retail sales were collected for that HH's state  
replace Online_item_lnP =ln(PUC_wCombTax) if Post_Online_Tax == 1 & channel_type=="Online Shopping"
replace Online_item_lnP =ln(PerUnitCost) if Post_Online_Tax == 0 & channel_type=="Online Shopping"
*Replace missing values
replace Online_item_lnP = 0 if missing(Online_item_lnP)

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
*If item purchased in state w/ sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PUC_wCombTax) if NoSalesTax == 0 & channel_type!="Online Shopping"
*If item purchased in state w/OUT sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PerUnitCost) if NoSalesTax == 1 & channel_type!="Online Shopping"
*Replace missing values
replace Traditional_item_lnP = 0 if missing(Traditional_item_lnP)

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen EXP_item = PUC_applicable*quantity

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen  sum_exp =total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
count if exp_Trad==.

*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values

replace exp_Online = 0 if missing(exp_Online)



**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2011.dta", replace
**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************

*Collapse the data to get HH level data for AIDS estimation
collapse exp_Online exp_Trad sum_exp sum_tot_P_paid Online_item_lnP Traditional_item_lnP ,by(household_cd)

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online_purch_POST_COLLAPSE_2011.dta",replace
**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
*Check the Sum of Expenditure 
gen sum_exp_check = exp_Online + exp_Trad
gen Exp_check = 1 if sum_exp_check==sum_exp
replace Exp_check = 0 if sum_exp_check!=sum_exp
gen sum_dif = sum_exp - sum_exp_check

**********************************************************************************************
*GENERATE EXPENSE %_SHARES
**********************************************************************************************
*Use the sum_exp_check or else it won't add to 1 ; budget constraint violation!
gen expsh_Trad = exp_Trad / sum_exp_check
gen expsh_Online = exp_Online / sum_exp_check
format %14.0g expsh_Trad
format %14.0g expsh_Online
sum expsh_Online
sum expsh_Trad
**********************************************************************************************
*GENERATE PRICE INDEX
**********************************************************************************************
*Generate the Price Index weighted by amount spent on Online/Traditional goods
gen P_index = (Traditional_item_lnP * expsh_Trad ) + (Online_item_lnP*expsh_Online)
**Real Prices X/P term from Eq8 Deaton , but not real prices in the sense of comparing to prices in a base year
gen Real_Exp = sum_exp / P_index 
gen ln_Real_Exp = ln(Real_Exp)
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2011.dta",replace

*********************************************************************************************
*AIDS  BASIC regressions
*********************************************************************************************

***  i=1 Traditional Expense Share 
reg expsh_Trad  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Trad_2011 

***  i=2 Online Expense Share 
reg expsh_Online  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Online_2011
***Same gamma coefficients!!! yea!

****TABLES
esttab expsh_Trad_2011 expsh_Online_2011  using Trad_Online_taxes2011.rtf, rtf  se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Trad & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace

esttab expsh_Trad_2011 expsh_Online_2011  using Trad_Online_taxes2011.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Traditional & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace






******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************










******************************************************************
******************************************************************
******************************************************************
******************************************************************
******************************************************************
*RERUN Without taxes on Prices


******************************************************************
*2017
******************************************************************

*********************************************************************************************
**********************************************************************************************
**********************************************************************************************
**********************************************************************************************
use"E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online Min1purch_HH w state sales tax 2017.dta"

**********************************************************************************************
*GENERATE VARIABLES
**********************************************************************************************

*GENERATE TRADITIONAL DUMMY
generate Traditional = 1
replace Traditional = 0 if channel_type=="Online Shopping" & !missing(channel_type)

*RE-FORMAT PURCHASE DATE
gen purch3_date = date(purchase_date, "YMD")


*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
sum total_price_paid
count if total_price_paid<=0
*36,656  
*Using one penny for LN(0) problem in collapsing
replace total_price_paid=0.01 if total_price_paid<=0
*To avoid having more negatives, not adjusting for coupons. Looking at Sticker price

*Per Unit Cost
gen PerUnitCost = total_price_paid / quantity

**********************************************************************************************
*ONLINE 
**********************************************************************************************
gen Online_item_lnP = .
replace Online_item_lnP =ln(PerUnitCost) if channel_type=="Online Shopping"
*Replace missing values
replace Online_item_lnP = 0 if missing(Online_item_lnP)

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
replace Traditional_item_lnP = ln(PerUnitCost) if channel_type!="Online Shopping"
*Replace missing values
replace Traditional_item_lnP = 0 if missing(PerUnitCost)

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen untaxed_EXP_item = PerUnitCost*quantity

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen  sum_exp =total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
count if exp_Trad==.

*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values
replace exp_Online = 0 if missing(exp_Online)


**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online NOtaxprice EXP_2017.dta", replace
**********************************************************************************************
*ADD ANYTHING ELSE WANTED/NEEDED BEFORE COLLAPSING !!!!!
**********************************************************************************************
*Are you sure you want to collapse?
*Reaally Sure?
*Don't say I didn't warn you....

*Collapse the data to get HH level data for AIDS estimation
collapse exp_Online exp_Trad sum_exp sum_tot_P_paid Online_item_lnP Traditional_item_lnP ,by(household_cd)

*Hooray, looks ok!
/*
*I warned you
clear
use "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Uncollapsed HH_w_min1_online taxprice EXP_2017.dta"
*/

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\Online_NOTAXpurch_POST_COLLAPSE_2017.dta", replace

**********************************************************************************************
*SAVE POST-COLLAPSE
**********************************************************************************************

*Check the Sum of Expenditure 
gen sum_exp_check = exp_Online + exp_Trad
gen Exp_check = 1 if sum_exp_check==sum_exp
replace Exp_check = 0 if sum_exp_check!=sum_exp
gen sum_dif = sum_exp - sum_exp_check

**********************************************************************************************
*GENERATE EXPENSE %_SHARES
**********************************************************************************************

*Use the sum_exp_check or else it won't add to 1 ; budget constraint violation!
gen expsh_Trad = exp_Trad / sum_exp_check
gen expsh_Online = exp_Online / sum_exp_check
format %14.0g expsh_Trad
format %14.0g expsh_Online
sum expsh_Online
sum expsh_Trad

**********************************************************************************************
*GENERATE PRICE INDEX
**********************************************************************************************

*Generate the Price Index weighted by amount spent on Online/Traditional goods
gen P_index = (Traditional_item_lnP * expsh_Trad ) + (Online_item_lnP*expsh_Online)
*
**Real Prices X/P term from Eq8 Deaton , but not real prices in the sense of comparing to prices in a base year
gen Real_Exp = sum_exp / P_index 
gen ln_Real_Exp = ln(Real_Exp)


save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2017.dta",replace


*********************************************************************************************
*AIDS  BASIC regressions
*********************************************************************************************
use "E:\Demand Estimation\INTENSIVE MARGIN (Online)\On_pur_POST_COLLAP_w Pindex_2017.dta",replace

***  i=1 Traditional Expense Share 
reg expsh_Trad  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Trad_2017 

***  i=2 Online Expense Share 
reg expsh_Online  Online_item_lnP Traditional_item_lnP ln_Real_Exp
eststo expsh_Online_2017
***Same gamma coefficients!!! yea!

****TABLES
esttab expsh_Trad_2017 expsh_Online_2017  using Trad_Online_taxes2017.rtf, rtf  se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Trad & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace

esttab expsh_Trad_2017 expsh_Online_2017  using Trad_Online_taxes2017.tex, tex se star(* 0.10 ** 0.05 *** 0.01) title("AIDS with only Traditional & Online baskets")  mtitle( Traditional Online) scalars(N r2 pval F) replace





