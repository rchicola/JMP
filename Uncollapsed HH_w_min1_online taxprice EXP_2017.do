******************************************************************
*FIRST MEGA MERGE except panelists file
******************************************************************
*2017
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
save "E:\Demand Estimation\MEGA MERGE\mega_merge1_2017.dta"

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

******************************************************************
***TIME FOR THE BIG DROP!!!!!!!!!!!!!!!
drop if Online_at_All==0
******************************************************************
save "E:\Demand Estimation\INTENSIVE MARGIN (Online)\purchases of HH wMin1_Online_purch_2017.dta"



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


*********************************************************************************************
*GENERATE PRICES 
**********************************************************************************************
*In future , compare using  total price paid with tax implications with coupons
gen final_price_paid = total_price_paid - coupon_value
gen PerUnitCost = final_price_paid / quantity
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

**********************************************************************************************
*TRADITIONAL 
**********************************************************************************************
gen Traditional_item_lnP = .
*If item purchased in state w/ sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PUC_wCombTax) if NoSalesTax == 0 & channel_type!="Online Shopping"
*If item purchased in state w/OUT sales tax and wasn't bought online 
replace Traditional_item_lnP = ln(PerUnitCost) if NoSalesTax == 1 & channel_type!="Online Shopping"

**********************************************************************************************
*TOTAL EXPENSE 
**********************************************************************************************
gen EXP_item = PUC_applicable*quantity
*Sanity Check: Should always be larger than price excluding coupons from raw data
gen exp_diff = EXP_item - final_price_paid
*close enough?

*Generate total expense for each HH for all purchase line items in the panel year
bysort household_cd  : egen sum_exp = total(EXP_item)
*Compare to total_price_paid
bysort household_cd  : egen sum_tot_P_paid = total(total_price_paid)

**********************************************************************************************
*TRADITIONAL EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Traditional" brick and mortar in the panel year
bysort household_cd : egen exp_Trad = total(EXP_item) if Traditional == 1
*Replace missing values
replace exp_Trad = 0 if missing(exp_Trad)

**********************************************************************************************
*ONLINE EXPENSE 
**********************************************************************************************
*Generate total expense for each HH for all trips that were "Online" in the panel year
bysort household_cd : egen exp_Online = total(EXP_item) if Traditional == 0
*Replace missing values
replace exp_Online = 0 if missing(exp_Online)












