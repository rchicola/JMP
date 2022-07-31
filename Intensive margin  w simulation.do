clear all

*onlineShare_it =a + b taxOnline_it + c taxTradit + d controls_it + e_it
use "E:\UNR_Houston_SBA_USB_backup11.20.2021\2nd year\Pooled Collapsed 1Min_Online 2011 to 2017.dta"

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

gen LN_Med_Online_PUC = ln(Median_On_PUC) 
gen LN_Med_Trad_PUC = ln(Median_Trad_PUC)
*PRICE INDEX WITHOUT TAX ADJUSTMENTS
gen LN_NoTax_Pindex = (ST_avg_NoTax_On_EXPSH * LN_Med_Online_PUC) + (ST_avg_NoTax_Trad_EXPSH * LN_Med_Trad_PUC)
*LOG Variable Variants
gen LN_NoTax_Tot_EXP  = ln(NoTax_Tot_EXP)
gen LN_NoTax_Real_EXP = LN_NoTax_Tot_EXP - LN_NoTax_Pindex
*gen LN_NoTax_Real_EXP2 = ln(NoTax_Tot_EXP/NoTax_Pindex)

 
 
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

****Get Standard errors (clear and re run )
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP 
predictnl ONLINE_EXP_SH_Hat2 = _b[_cons]+_b[LN_Med_On_PUCtax]*LN_Med_On_PUCtax  +  _b[LN_Med_Trad_PUCtax] *LN_Med_Trad_PUCtax+ _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP, se(stderror1)
sum ONLINE_EXP_SH_Hat2 stderror1




************************************************************************
*Simulation of 10% price increase of online goods but 1HH avg
************************************************************************
*For collapse use casewise deletion https://www.stata.com/manuals13/miglossary.pdf
*Run regression to get coeff in e enviro

reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP 
*Only run if you want to collapse to 1 observation!
*collapse ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax    LN_TaxAdj_Real_EXP LN_PUCtax_10perinc, cw

*Factual
gen y_hat_fact = _b[_cons] + _b[LN_Med_On_PUCtax]*LN_Med_On_PUCtax + _b[LN_Med_Trad_PUCtax]*LN_Med_Trad_PUCtax  + _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP 
dis y_hat_fact
*Counterfactual 10%inc
gen y_hat_cf2 = _b[_cons] + _b[LN_Med_On_PUCtax]*LN_PUCtax_10perinc + _b[LN_Med_Trad_PUCtax]*LN_Med_Trad_PUCtax  + _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP 
dis y_hat_cf2 

*Factual
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP 
predictnl ONLINE_EXP_SH_Hat3 = _b[_cons]+_b[LN_Med_On_PUCtax]*LN_Med_On_PUCtax  +  _b[LN_Med_Trad_PUCtax] *LN_Med_Trad_PUCtax+ _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP, se(stderror3)
sum ONLINE_EXP_SH_Hat3 stderror3
*Counterfactual 10%inc
predictnl ONLINE_EXP_SH_Hat4 = _b[_cons]+_b[LN_Med_On_PUCtax]*LN_PUCtax_10perinc  +  _b[LN_Med_Trad_PUCtax] *LN_Med_Trad_PUCtax+ _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP, se(stderror4)
sum ONLINE_EXP_SH_Hat4 stderror4

************************************************************************
*Simulation of 5% price increase of online goods but 1HH avg
************************************************************************
*Var for 5% increase
gen LN_PUCtax_5perinc =  ln(Median_On_PUCtax * 1.05)
ameans LN_PUCtax_5perinc 
sum LN_PUCtax_5perinc

reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP 

*Factual
reg  ONLINE_EXP_SH   LN_Med_On_PUCtax    LN_Med_Trad_PUCtax     LN_TaxAdj_Real_EXP 
predictnl ONLINE_EXP_SH_Hat3 = _b[_cons]+_b[LN_Med_On_PUCtax]*LN_Med_On_PUCtax  +  _b[LN_Med_Trad_PUCtax] *LN_Med_Trad_PUCtax+ _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP, se(stderror3)
asdoc sum ONLINE_EXP_SH_Hat3 stderror3 , dec(7)
*Counterfactual 5%inc
predictnl ONLINE_EXP_SH_Hat5 = _b[_cons]+_b[LN_Med_On_PUCtax]*LN_PUCtax_5perinc  +  _b[LN_Med_Trad_PUCtax] *LN_Med_Trad_PUCtax+ _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP, se(stderror5)
sum ONLINE_EXP_SH_Hat5 stderror5


*Factual always the same but maybe do a loop for increasing by percent

*INCREASE LOOP
forvalues perc = 1/10 {
	gen LN_PUCtax_Inc_`perc' =  ln(Median_On_PUCtax *(1+ (`perc'/100)))
	predictnl ON_EXP_SH_Incr_Hat_`perc' = _b[_cons]+_b[LN_Med_On_PUCtax]*LN_PUCtax_Inc_`perc'  +  _b[LN_Med_Trad_PUCtax] *LN_Med_Trad_PUCtax+ _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP, se(stder_incr_`perc')
asdoc sum ON_EXP_SH_Incr_Hat_`perc' stder_incr_`perc' , dec(7)

}


*DECREASE LOOP
forvalues perc = 1/10 {
	gen LN_PUCtax_Decr_`perc' =  ln(Median_On_PUCtax *(1-(`perc'/100)))
	predictnl ON_EXP_SH_Decr_Hat_`perc' = _b[_cons]+_b[LN_Med_On_PUCtax]*LN_PUCtax_Decr_`perc'  +  _b[LN_Med_Trad_PUCtax] *LN_Med_Trad_PUCtax+ _b[LN_TaxAdj_Real_EXP]*LN_TaxAdj_Real_EXP, se(stder_decr_`perc')
asdoc sum ON_EXP_SH_Decr_Hat_`perc' stder_decr_`perc'

}

************************************************************
*QUAIDS test
************************************************************
*quaids ONLINE_EXP_SH Trad_EXP_SH, anot(5) lnprices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)
*must specify at least 3 expenditure shares

************************************************************
*AIDSILLS COMMAND --- NO CONTROLS
************************************************************
*https://journals.sagepub.com/doi/pdf/10.1177/1536867X1501500214
*!!!!!!!command needs LEVELS, can't do the logs, see stata help materials!
************************************************************
*UNCONSTRAINED MODELS
************************************************************
*Using Stone's Price Index-->iteration(0)
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) iteration(0) dec(5)
aidsills_pred On_ExpSH_1, equation(ONLINE_EXP_SH)
dis On_ExpSH_1
eststo AIDS_ILLS_1
esttab using "C:\Users\Randall\Desktop\2nd yr paper\2nd year working paper\AIDS_ILLS_1.csv", se replace

*Base Model "Proper Unconstrained"-->iteration(0) estimates the linearized version of the model, where a(.) is replaced by the Stone price index and b(.) = 1.  The default is iteration(50)
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) dec(5)
aidsills_pred On_ExpSH_2, equation(ONLINE_EXP_SH)
dis On_ExpSH_2
*Check matricies dimensions; ereturn list; return list
*Store & Output to CSV
eststo AIDS_ILLS_2
esttab using "C:\Users\Randall\Desktop\2nd yr paper\2nd year working paper\AIDS_ILLS_2.csv", se replace

*Quadratic
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) quadratic dec(5)
aidsills_pred On_ExpSH_3, equation(ONLINE_EXP_SH)
dis On_ExpSH_3
test [ONLINE_EXP_SH]gamma_lnMedian_On_PUCtax = [Trad_EXP_SH]gamma_lnMedian_Trad_PUCtax 

************************************************************
*HOMOGENEITY CONSTRAINED MODELS
************************************************************
*Using Stone's Price Index-->iteration(0)
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity iteration(0) dec(5)
aidsills_pred On_ExpSH_4, equation(ONLINE_EXP_SH)
dis On_ExpSH_4
eststo AIDS_ILLS_4
esttab using "C:\Users\Randall\Desktop\2nd yr paper\2nd year working paper\AIDS_ILLS_4.csv", se replace

*"Proper"-->iteration(0) estimates the linearized version of the model, where a(.) is replaced by the Stone price index and b(.) = 1.  The default is iteration(50)
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity dec(5)
aidsills_pred On_ExpSH_5, equation(ONLINE_EXP_SH)
dis On_ExpSH_5
*Check matricies dimensions; ereturn list; return list
*Store & Output to CSV
eststo AIDS_ILLS_5
esttab using "C:\Users\Randall\Desktop\2nd yr paper\2nd year working paper\AIDS_ILLS_5.csv", se replace

*Quadratic
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) quadratic homogeneity dec(5)
aidsills_pred On_ExpSH_6, equation(ONLINE_EXP_SH)
dis On_ExpSH_6

************************************************************
*HOMOGENEITY AND SYMMETRY CONSTRAINED MODELS
************************************************************
*symmetry indicates that the log price-parameters must satisfy the homogeneity and symmetry constraints; a symmetry chi-squared test is provided when the homogeneity constrained model is fit.
*Using Stone's Price Index-->iteration(0)
aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) symmetry iteration(0) tolerance(1e-5)
*"Proper"-->iteration(0) estimates the linearized version of the model, where a(.) is replaced by the Stone price index and b(.) = 1.  The default is iteration(50)
aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) symmetry tolerance(1e-2)
*Quadratic
aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) quadratic symmetry tolerance(1e-25) iteration(120)

















************************************************************
*AIDSILLS COMMAND --- WITH CONTROLS!
************************************************************
*Some varnames are too long because aidsills command adds 'alpha_', throws error
*AltVars
gen age_and_pres_of_kids = age_and_presence_of_children
global HH_general_1 "household_income household_size type_of_residence household_composition age_and_pres_of_kids race hispanic_origin" 
gen HH_internet = household_internet_connection
global HH_Home_1 " kitchen_appliances tv_items HH_internet"

************************************************************
*BASE QUADRATIC
************************************************************
aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) quadratic





*UNCONSTRAINED MODELS--- WITH CONTROLS!
************************************************************
*Using Stone's Price Index-->iteration(0)
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  iteration(0) dec(5)
*Base Model "Proper Unconstrained"
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) dec(5)

************************************************************************************************************************
************************************************************************************************************************
*Quadratic Unconstrained
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  quadratic dec(5)
eststo Quad_UnConstrained_pooled
aidsills_vif
preserve
quietly log using Unconstr_Elas, name(log1) text
aidsills_elas 
log close log1
insheet using "Unconstr_Elas.log", clear
gen obs=_n
levelsof obs if regexm(v1, "PREDICTED"), local(start)
levelsof obs if regexm(v1, "log close log1"), local(end)
keep if inrange(obs, `start', `=`end'-1')
drop obs
export excel using Unconstr_Elasticity, replace

*Quadratic Homogeneity Constrained
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  quadratic homogeneity dec(5)
eststo Quad_Homogeneity_pooled
aidsills_vif
preserve
quietly log using Homog_Elas, name(log2) text
aidsills_elas 
log close log2
insheet using "Homog_Elas.log", clear
gen obs=_n
levelsof obs if regexm(v1, "PREDICTED"), local(start)
levelsof obs if regexm(v1, "log close log2"), local(end)
keep if inrange(obs, `start', `=`end'-1')
drop obs
export excel using Homog_Elasticity, replace

*Quadratic Homogeneity + Symmetry Constrained       (symmetry command also imposes homogeneity)
*asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) quadratic symmetry dec(5)
*eststo Quad_symmmetry_pooled
*aidsills_elas
*aidsills_vif
****SYMMETRY DOES NOT HOLD

esttab Quad_UnConstrained_pooled Quad_Homogeneity_pooled using Quad_UnCon_Homo.csv , se label replace  
esttab Quad_UnConstrained_pooled Quad_Homogeneity_pooled using Quad_UnCon_Homo.tex , se label replace






***********************************************************************************************
*Simulation 2
***********************************************************************************************


*Factual--> Quadratic Unconstrained
***********************************************************************************************
aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  quadratic

aidsills_pred ON_EXP_SH_HAT,equation(ONLINE_EXP_SH)
sum ON_EXP_SH_HAT

aidsills_pred ON_EXP_SH_RESID,equation(ONLINE_EXP_SH) residuals
sum ON_EXP_SH_RESID


return list
ereturn list

matrix list e(b)
matrix list e(V)
matrix list e(alpha)
matrix list e(gamma)
matrix list e(beta)
matrix list e(lambda)

tempvar CoeffToUse
tempname b V lambda beta ggamma aalpha

matrix b = e(b)
matrix V = e(V)
matrix lambda = e(lambda)
matrix ggamma = e(gamma) 
matrix aaplha = e(alpha)

mkmat Median_On_PUCtax Median_Trad_PUCtax, matrix(PriceVector)

eststo Quad_UnConstrained_pooled

*Counterfactuals--> Quadratic Unconstrained
***********************************************************************************************
*INCREASE LOOP
forvalues perc = 0/10 {
	gen ln_On_PUCtax_Inc_`perc' =  ln(Median_On_PUCtax *(1+ (`perc'/100)))
	predictnl ON_EXP_SH_Incr_Hat_`perc' = ///
	_b[alpha_cons]+_b[gamma_lnMedian_On_PUCtax]*ln_On_PUCtax_Inc_`perc'  +  _b[gamma_lnMedian_Trad_PUCtax] *ln(Median_Trad_PUCtax) ///
	+ _b[beta_lnx]*ln(Tot_EXP) 	+ _b[lambda_lnx2]*ln(Tot_EXP)^2 ///
	+ _b[alpha_household_income]*household_income + _b[alpha_household_size]*household_size + _b[alpha_type_of_residence]*type_of_residence + _b[alpha_household_composition]*household_composition ///
	+ _b[alpha_age_and_pres_of_kids]*age_and_pres_of_kids + _b[alpha_race]*race + _b[alpha_hispanic_origin]*hispanic_origin  ///
	+ _b[alpha_male_head_age]*male_head_age + _b[alpha_male_head_employment]*male_head_employment + _b[alpha_male_head_education]*male_head_education + _b[alpha_male_head_occupation]* male_head_occupation ///
	+ _b[alpha_female_head_age]*female_head_age + _b[alpha_female_head_employment]*female_head_employment + _b[alpha_female_head_education]*female_head_education + _b[alpha_female_head_occupation]*female_head_occupation ///
	+ _b[alpha_kitchen_appliances]*kitchen_appliances + _b[alpha_tv_items]*tv_items + _b[alpha_HH_internet]*HH_internet , se(stder_incr_`perc')
	 
asdoc sum ON_EXP_SH_Incr_Hat_`perc' stder_incr_`perc' , dec(7)

}

          
*DECREASE LOOP
forvalues perc = 0/10 {
	gen ln_On_PUCtax_Decr_`perc' =  ln(Median_On_PUCtax *(1- (`perc'/100)))
	predictnl ON_EXP_SH_Decr_Hat_`perc' = ///
	_b[alpha_cons]+_b[gamma_lnMedian_On_PUCtax]*ln_On_PUCtax_Decr_`perc'  +  _b[gamma_lnMedian_Trad_PUCtax] *ln(Median_Trad_PUCtax) ///
	+ _b[beta_lnx]*ln(Tot_EXP) 	+ _b[lambda_lnx2]*ln(Tot_EXP)^2 ///
	+ _b[alpha_household_income]*household_income + _b[alpha_household_size]*household_size + _b[alpha_type_of_residence]*type_of_residence + _b[alpha_household_composition]*household_composition ///
	+ _b[alpha_age_and_pres_of_kids]*age_and_pres_of_kids + _b[alpha_race]*race + _b[alpha_hispanic_origin]*hispanic_origin  ///
	+ _b[alpha_male_head_age]*male_head_age + _b[alpha_male_head_employment]*male_head_employment + _b[alpha_male_head_education]*male_head_education + _b[alpha_male_head_occupation]* male_head_occupation ///
	+ _b[alpha_female_head_age]*female_head_age + _b[alpha_female_head_employment]*female_head_employment + _b[alpha_female_head_education]*female_head_education + _b[alpha_female_head_occupation]*female_head_occupation ///
	+ _b[alpha_kitchen_appliances]*kitchen_appliances + _b[alpha_tv_items]*tv_items + _b[alpha_HH_internet]*HH_internet , se(stder_decr_`perc')
	 
asdoc sum ON_EXP_SH_Decr_Hat_`perc' stder_decr_`perc' , dec(7)
}








*Factual--> Proper Unconstrained
***********************************************************************************************
aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  
*Counterfactuals--> Quadratic Unconstrained
***********************************************************************************************
*INCREASE LOOP
forvalues perc = 0/10 {
	gen ln_On_PUCtax_Inc_`perc' =  ln(Median_On_PUCtax *(1+ (`perc'/100)))
	predictnl ON_EXP_SH_Incr_Hat_`perc' = ///
	_b[alpha_cons]+_b[gamma_lnMedian_On_PUCtax]*ln_On_PUCtax_Inc_`perc'  +  _b[gamma_lnMedian_Trad_PUCtax] *ln(Median_Trad_PUCtax) ///
	+ _b[beta_lnx]*ln(Tot_EXP) 	///
	+ _b[alpha_household_income]*household_income + _b[alpha_household_size]*household_size + _b[alpha_type_of_residence]*type_of_residence + _b[alpha_household_composition]*household_composition ///
	+ _b[alpha_age_and_pres_of_kids]*age_and_pres_of_kids + _b[alpha_race]*race + _b[alpha_hispanic_origin]*hispanic_origin  ///
	+ _b[alpha_male_head_age]*male_head_age + _b[alpha_male_head_employment]*male_head_employment + _b[alpha_male_head_education]*male_head_education + _b[alpha_male_head_occupation]* male_head_occupation ///
	+ _b[alpha_female_head_age]*female_head_age + _b[alpha_female_head_employment]*female_head_employment + _b[alpha_female_head_education]*female_head_education + _b[alpha_female_head_occupation]*female_head_occupation ///
	+ _b[alpha_kitchen_appliances]*kitchen_appliances + _b[alpha_tv_items]*tv_items + _b[alpha_HH_internet]*HH_internet , se(stder_incr_`perc')
	 
asdoc sum ON_EXP_SH_Incr_Hat_`perc' stder_incr_`perc' , dec(7)

}

          
*DECREASE LOOP
forvalues perc = 0/10 {
	gen ln_On_PUCtax_Decr_`perc' =  ln(Median_On_PUCtax *(1- (`perc'/100)))
	predictnl ON_EXP_SH_Decr_Hat_`perc' = ///
	_b[alpha_cons]+_b[gamma_lnMedian_On_PUCtax]*ln_On_PUCtax_Decr_`perc'  +  _b[gamma_lnMedian_Trad_PUCtax] *ln(Median_Trad_PUCtax) ///
	+ _b[beta_lnx]*ln(Tot_EXP) 	///
	+ _b[alpha_household_income]*household_income + _b[alpha_household_size]*household_size + _b[alpha_type_of_residence]*type_of_residence + _b[alpha_household_composition]*household_composition ///
	+ _b[alpha_age_and_pres_of_kids]*age_and_pres_of_kids + _b[alpha_race]*race + _b[alpha_hispanic_origin]*hispanic_origin  ///
	+ _b[alpha_male_head_age]*male_head_age + _b[alpha_male_head_employment]*male_head_employment + _b[alpha_male_head_education]*male_head_education + _b[alpha_male_head_occupation]* male_head_occupation ///
	+ _b[alpha_female_head_age]*female_head_age + _b[alpha_female_head_employment]*female_head_employment + _b[alpha_female_head_education]*female_head_education + _b[alpha_female_head_occupation]*female_head_occupation ///
	+ _b[alpha_kitchen_appliances]*kitchen_appliances + _b[alpha_tv_items]*tv_items + _b[alpha_HH_internet]*HH_internet , se(stder_decr_`perc')
	 
asdoc sum ON_EXP_SH_Decr_Hat_`perc' stder_decr_`perc' , dec(7)
}




**********************************************************************************************
*NO ONLINE SALES TAX Simulation 

***********************************************************************************************
*Counterfactuals--> ONLINE SALES TAXES NEVER IMPLEMENTED-->Using Median_On_PUC   Pro
**********************************************************************************************

*INCREASE LOOP
forvalues perc = 0/10 {
	gen ln_On_PUC_No_tax_Inc_`perc' =  ln(Median_On_PUC *(1+ (`perc'/100)))
	predictnl ON_EXP_SH_Incr_Hat_NoTax_`perc' = ///
	_b[alpha_cons]+_b[gamma_lnMedian_On_PUCtax]*ln_On_PUC_No_tax_Inc_`perc'  +  _b[gamma_lnMedian_Trad_PUCtax] *ln(Median_Trad_PUCtax) ///
	+ _b[beta_lnx]*ln(Tot_EXP)  ///
	+ _b[alpha_household_income]*household_income + _b[alpha_household_size]*household_size + _b[alpha_type_of_residence]*type_of_residence + _b[alpha_household_composition]*household_composition ///
	+ _b[alpha_age_and_pres_of_kids]*age_and_pres_of_kids + _b[alpha_race]*race + _b[alpha_hispanic_origin]*hispanic_origin  ///
	+ _b[alpha_male_head_age]*male_head_age + _b[alpha_male_head_employment]*male_head_employment + _b[alpha_male_head_education]*male_head_education + _b[alpha_male_head_occupation]* male_head_occupation ///
	+ _b[alpha_female_head_age]*female_head_age + _b[alpha_female_head_employment]*female_head_employment + _b[alpha_female_head_education]*female_head_education + _b[alpha_female_head_occupation]*female_head_occupation ///
	+ _b[alpha_kitchen_appliances]*kitchen_appliances + _b[alpha_tv_items]*tv_items + _b[alpha_HH_internet]*HH_internet , se(stder_inc_`perc')
	 
asdoc sum ON_EXP_SH_Incr_Hat_NoTax_`perc' stder_inc_`perc' , dec(7)

}

*DECREASE LOOP
forvalues perc = 0/10 {
	gen ln_On_PUC_No_tax_Decr_`perc' =  ln(Median_On_PUC *(1- (`perc'/100)))
	predictnl ON_EXP_SH_Decr_Hat_NoTax_`perc' = ///
	_b[alpha_cons]+_b[gamma_lnMedian_On_PUCtax]*ln_On_PUC_No_tax_Decr_`perc'  +  _b[gamma_lnMedian_Trad_PUCtax] *ln(Median_Trad_PUCtax) ///
	+ _b[beta_lnx]*ln(Tot_EXP)  ///
	+ _b[alpha_household_income]*household_income + _b[alpha_household_size]*household_size + _b[alpha_type_of_residence]*type_of_residence + _b[alpha_household_composition]*household_composition ///
	+ _b[alpha_age_and_pres_of_kids]*age_and_pres_of_kids + _b[alpha_race]*race + _b[alpha_hispanic_origin]*hispanic_origin  ///
	+ _b[alpha_male_head_age]*male_head_age + _b[alpha_male_head_employment]*male_head_employment + _b[alpha_male_head_education]*male_head_education + _b[alpha_male_head_occupation]* male_head_occupation ///
	+ _b[alpha_female_head_age]*female_head_age + _b[alpha_female_head_employment]*female_head_employment + _b[alpha_female_head_education]*female_head_education + _b[alpha_female_head_occupation]*female_head_occupation ///
	+ _b[alpha_kitchen_appliances]*kitchen_appliances + _b[alpha_tv_items]*tv_items + _b[alpha_HH_internet]*HH_internet , se(stder_dec_`perc')
	 
asdoc sum ON_EXP_SH_Decr_Hat_NoTax_`perc' stder_dec_`perc' , dec(7)
}



*Factual--> Proper Homogeneity
***********************************************************************************************
aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  homogeneity 
*Counterfactuals--> Quadratic Unconstrained
***********************************************************************************************
*INCREASE LOOP
forvalues perc = 1/10 {
	gen ln_On_PUCtax_Inc_`perc' =  ln(Median_On_PUCtax *(1+ (`perc'/100)))
	predictnl ON_EXP_SH_Incr_Hat_`perc' = ///
	_b[alpha_cons]+_b[gamma_lnMedian_On_PUCtax]*ln_On_PUCtax_Inc_`perc'  +  _b[gamma_lnMedian_Trad_PUCtax] *ln(Median_Trad_PUCtax) ///
	+ _b[beta_lnx]*ln(Tot_EXP) 	///
	+ _b[alpha_household_income]*household_income + _b[alpha_household_size]*household_size + _b[alpha_type_of_residence]*type_of_residence + _b[alpha_household_composition]*household_composition ///
	+ _b[alpha_age_and_pres_of_kids]*age_and_pres_of_kids + _b[alpha_race]*race + _b[alpha_hispanic_origin]*hispanic_origin  ///
	+ _b[alpha_male_head_age]*male_head_age + _b[alpha_male_head_employment]*male_head_employment + _b[alpha_male_head_education]*male_head_education + _b[alpha_male_head_occupation]* male_head_occupation ///
	+ _b[alpha_female_head_age]*female_head_age + _b[alpha_female_head_employment]*female_head_employment + _b[alpha_female_head_education]*female_head_education + _b[alpha_female_head_occupation]*female_head_occupation ///
	+ _b[alpha_kitchen_appliances]*kitchen_appliances + _b[alpha_tv_items]*tv_items + _b[alpha_HH_internet]*HH_internet , se(stder_incr_`perc')
	 
asdoc sum ON_EXP_SH_Incr_Hat_`perc' stder_incr_`perc' , dec(7)

}

          
*DECREASE LOOP
forvalues perc = 1/10 {
	gen ln_On_PUCtax_Decr_`perc' =  ln(Median_On_PUCtax *(1- (`perc'/100)))
	predictnl ON_EXP_SH_Decr_Hat_`perc' = ///
	_b[alpha_cons]+_b[gamma_lnMedian_On_PUCtax]*ln_On_PUCtax_Decr_`perc'  +  _b[gamma_lnMedian_Trad_PUCtax] *ln(Median_Trad_PUCtax) ///
	+ _b[beta_lnx]*ln(Tot_EXP) 	///
	+ _b[alpha_household_income]*household_income + _b[alpha_household_size]*household_size + _b[alpha_type_of_residence]*type_of_residence + _b[alpha_household_composition]*household_composition ///
	+ _b[alpha_age_and_pres_of_kids]*age_and_pres_of_kids + _b[alpha_race]*race + _b[alpha_hispanic_origin]*hispanic_origin  ///
	+ _b[alpha_male_head_age]*male_head_age + _b[alpha_male_head_employment]*male_head_employment + _b[alpha_male_head_education]*male_head_education + _b[alpha_male_head_occupation]* male_head_occupation ///
	+ _b[alpha_female_head_age]*female_head_age + _b[alpha_female_head_employment]*female_head_employment + _b[alpha_female_head_education]*female_head_education + _b[alpha_female_head_occupation]*female_head_occupation ///
	+ _b[alpha_kitchen_appliances]*kitchen_appliances + _b[alpha_tv_items]*tv_items + _b[alpha_HH_internet]*HH_internet , se(stder_decr_`perc')
	 
asdoc sum ON_EXP_SH_Decr_Hat_`perc' stder_decr_`perc' , dec(7)
}


drop ln_On_PUCtax_Inc_1 ln_On_PUCtax_Inc_2 ln_On_PUCtax_Inc_3 ln_On_PUCtax_Inc_4 ln_On_PUCtax_Inc_5 ln_On_PUCtax_Inc_6 ln_On_PUCtax_Inc_7 ln_On_PUCtax_Inc_8 ln_On_PUCtax_Inc_9 ln_On_PUCtax_Inc_10

drop stder_incr_1 stder_incr_2 stder_incr_3 stder_incr_4 stder_incr_5 stder_incr_6 stder_incr_7 stder_incr_8 stder_incr_9 stder_incr_10

drop ON_EXP_SH_Incr_Hat_1 ON_EXP_SH_Incr_Hat_2 ON_EXP_SH_Incr_Hat_3 ON_EXP_SH_Incr_Hat_4 ON_EXP_SH_Incr_Hat_5 ON_EXP_SH_Incr_Hat_6 ON_EXP_SH_Incr_Hat_7 ON_EXP_SH_Incr_Hat_8 ON_EXP_SH_Incr_Hat_9 ON_EXP_SH_Incr_Hat_10

************************************************************************************************************************
************************************************************************************************************************
*Unconstrained LOOPS for panel years

*Stone
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd)  iteration(0)
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'_Stone  , equation(ONLINE_EXP_SH)
eststo Stone_aidsills_`panel_yr'

}
esttab Stone_aidsills_2011 Stone_aidsills_2012 Stone_aidsills_2013 Stone_aidsills_2014 Stone_aidsills_2015 Stone_aidsills_2016 Stone_aidsills_2017 using Quad_aidsills_IndivYr.csv , se label replace 


*Proper
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd) 
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'_Proper  , equation(ONLINE_EXP_SH)
eststo Proper_aidsills_`panel_yr'
}
esttab Proper_aidsills_2011 Proper_aidsills_2012 Proper_aidsills_2013 Proper_aidsills_2014 Proper_aidsills_2015 Proper_aidsills_2016 Proper_aidsills_2017 using Proper_aidsills_IndivYr.csv , se label replace 

*Quadratic
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd)  quadratic 
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'  , equation(ONLINE_EXP_SH)
eststo Quad_aidsills_`panel_yr'
}
esttab Quad_aidsills_2011 Quad_aidsills_2012 Quad_aidsills_2013 Quad_aidsills_2014 Quad_aidsills_2015 Quad_aidsills_2016 Quad_aidsills_2017 using Quad_aidsills_IndivYr.csv , se label replace 
*esttab On_Exp_Sh_hat_2011 On_Exp_Sh_hat_2012 On_Exp_Sh_hat_2013 On_Exp_Sh_hat_2014 On_Exp_Sh_hat_2015 On_Exp_Sh_hat_2016 On_Exp_Sh_hat_2017 using Q_aidsills_IndYr_pred_OnExpsh.csv , se label replace 




*HOMOGENEITY CONSTRAINED MODELS--- WITH CONTROLS!
************************************************************
*Using Stone's Price Index-->iteration(0)
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  iteration(0) dec(5)
*Base Model "Proper Unconstrained"
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) dec(5)

*Quadratic
asdoc aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  quadratic dec(5)

aidsills_elas 

*HOMOGENEITY constrained LOOPS for panel years

*Stone
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd)  iteration(0)
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'_Stone  , equation(ONLINE_EXP_SH)
eststo Stone_Homo_`panel_yr'

}
esttab Stone_Homo_2011 Stone_aidsills_2012 Stone_Homo_2013 Stone_Homo_2014 Stone_aidsills_2015 Stone_Homo_2016 Stone_Homo_2017 using Quad_Homo_IndivYr.csv , se label replace 


*Proper
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd) 
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'_Proper  , equation(ONLINE_EXP_SH)
eststo Proper_Homo_`panel_yr'
}
esttab Proper_Homo_2011 Proper_Homo_2012 Proper_Homo_2013 Proper_Homo_2014 Proper_Homo_2015 Proper_Homo_2016 Proper_Homo_2017 using Proper_Homo_IndivYr.csv , se label replace 

*Quadratic
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd)  quadratic 
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'  , equation(ONLINE_EXP_SH)
eststo Quad_Homo_`panel_yr'
}
esttab Quad_Homo_2011 Quad_Homo_2012 Quad_Homo_2013 Quad_Homo_2014 Quad_Homo_2015 Quad_Homo_2016 Quad_Homo_2017 using Quad_Homo_IndivYr.csv , se label replace 
*esttab On_Exp_Sh_hat_2011 On_Exp_Sh_hat_2012 On_Exp_Sh_hat_2013 On_Exp_Sh_hat_2014 On_Exp_Sh_hat_2015 On_Exp_Sh_hat_2016 On_Exp_Sh_hat_2017 using Q_aidsills_IndYr_pred_OnExpsh.csv , se label replace 












*HOMOGENEITY AND SYMMETRY CONSTRAINED MODELS--- WITH CONTROLS!
************************************************************
*Using Stone's Price Index-->iteration(0)
aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) symmetry intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  iteration(0) 
*Base Model "Proper Unconstrained" 
aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) symmetry intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) 
*Quadratic
aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) symmetry intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})  quadratic 



*HOMOGENEITY & SYMMETRY constrained LOOP for panel years

*Stone
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) symmetry intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd)  iteration(0)
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'_Stone  , equation(ONLINE_EXP_SH)
eststo Stone_HomoSym_`panel_yr'

}
esttab Stone_HomoSym_2011 Stone_HomoSym_2012 Stone_HomoSym_2013 Stone_HomoSym_2014 Stone_HomoSym_2015 Stone_HomoSym_2016 Stone_HomoSym_2017 using Quad_HomoSym_IndivYr.csv , se label replace 


*Proper
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) symmetry intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd) 
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'_Proper  , equation(ONLINE_EXP_SH)
eststo Proper_HomoSym_`panel_yr'
}
esttab Proper_HomoSym_2011 Proper_HomoSym_2012 Proper_aidsills_2013 Proper_HomoSym_2014 Proper_HomoSym_2015 Proper_HomoSym_2016 Proper_HomoSym_2017 using Proper_HomoSym_IndivYr.csv , se label replace 

*Quadratic
forvalues panel_yr= 2011/2017 {
aidsills ONLINE_EXP_SH Trad_EXP_SH  if panel_year == `panel_yr' , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) symmetry intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1} fips_state_cd)  quadratic 
aidsills_elas if panel_year == `panel_yr'
aidsills_pred On_Exp_Sh_hat_`panel_yr'  , equation(ONLINE_EXP_SH)
eststo Quad_HomoSym_`panel_yr'
}
esttab Quad_HomoSym_2011 Quad_HomoSym_2012 Quad_HomoSym_2013 Quad_HomoSym_2014 Quad_HomoSym_2015 Quad_HomoSym_2016 Quad_HomoSym_2017 using Quad_HomoSym_IndivYr.csv , se label replace 
*esttab On_Exp_Sh_hat_2011 On_Exp_Sh_hat_2012 On_Exp_Sh_hat_2013 On_Exp_Sh_hat_2014 On_Exp_Sh_hat_2015 On_Exp_Sh_hat_2016 On_Exp_Sh_hat_2017 using Q_aidsills_IndYr_pred_OnExpsh.csv , se label replace 











************************************************************
***Instrumental Variable (I.V. Testing) --> INCOME
************************************************************

*Put household income variable from categoy form into midpoint of income category's range.
tab household_income
/*
Household Income - the values represent ranges of total household income for the full year that is 2 years prior to the Panel Year.
Under $5000	--> 3
$5000-$7999	--> 4
$8000-$9999	--> 6
$10,000-$11,999 --> 8
$12,000-$14,999 --> 10
$15,000-$19,999 --> 11
$20,000-$24,999 --> 13
$25,000-$29,999 --> 15
$30,000-$34,999 --> 16
$35,000-$39,999 --> 17
$40,000-$44,999 --> 18
$45,000-$49,999 --> 19
$50,000-$59,999 --> 21
$60,000-$69,999 --> 23
$70,000-$99,999 --> 26
$100,000 + --> 27 (Note: in 2004-2005, and again in 2010) “27” is the highest value and refers to anything $100,000 and above
$100,000 - $124,999 --> 27 (this value applies to this range ONLY in 2006-2009)
$125,000 - $149,999 --> 28 (value only present 2006-2009)
$150,000 - $199,999 --> 29 (value only present 2006-2009)
$200,000 + -->30 (value only present 2006-2009)
*/

gen HH_Income = 0 if household_income == .
replace HH_Income = ((5000+0)/2) if household_income == 3
replace HH_Income = ((5000+7999)/2) if household_income == 4
replace HH_Income = ((8000+9999)/2) if household_income == 6
replace HH_Income = ((10000+11999)/2) if household_income == 8
replace HH_Income = ((12000+14999)/2) if household_income == 10
replace HH_Income = ((15000+19999 )/2) if household_income == 11
replace HH_Income = ((20000+24999)/2) if household_income == 13
replace HH_Income = ((25000+29999)/2) if household_income == 15
replace HH_Income = ((30000+34999)/2) if household_income == 16
replace HH_Income = ((35000+39999)/2) if household_income == 17
replace HH_Income = ((40000+44999)/2) if household_income == 18
replace HH_Income = ((45000+49999)/2) if household_income == 19
replace HH_Income = ((50000+59999)/2) if household_income == 21
replace HH_Income = ((60000+69999)/2) if household_income == 23
replace HH_Income = ((70000+99999)/2) if household_income == 26
/*
replace HH_Income = 100000 if household_income==27 & (panel_year==2004 | panel_year==2005 | panel_year==2010) 

replace HH_Income = ((100000+124999)/2) if household_income == 27 & (panel_year == 2006 | panel_year == 2007 |panel_year == 2008 | panel_year == 2009)
replace HH_Income = ((125000+149999)/2) if household_income == 28 & (panel_year == 2006 | panel_year == 2007 |panel_year == 2008 | panel_year == 2009)
replace HH_Income = ((150000+199999)/2) if household_income == 29 & (panel_year == 2006 | panel_year == 2007 |panel_year == 2008 | panel_year == 2009)
replace HH_Income = 200000 if household_income == 30 & (panel_year == 2006 | panel_year == 2007 |panel_year == 2009)
*/
replace HH_Income = 100000 if household_income==27

tab household_income
tab HH_Income


*Using Stone's Price Index-->iteration(0)
************************************************************
*No Controls
eststo IV_INCOME_1: quietly  aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivexpenditure(HH_Income)  iteration(0) 
*With Controls
*Perfect Colinearity Warning! -> Need to remove household_income from HH_general_1
global HH_general_2 "household_size type_of_residence household_composition age_and_pres_of_kids race hispanic_origin" 
eststo IV_INCOME_2: quietly  aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) ivexpenditure(HH_Income) intercept(${HH_general_2} ${Male_HH} ${Female_HH} ${HH_Home_1})  iteration(0) 


*Base Model "Proper Unconstrained"
************************************************************
*No Controls
eststo IV_INCOME_3: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivexpenditure(HH_Income) 
*With Controls
eststo IV_INCOME_4: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) ivexpenditure(HH_Income) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})

*Quadratic 
************************************************************
*No Controls
eststo IV_INCOME_5: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) ivexpenditure(HH_Income) quadratic
*With Controls
eststo IV_INCOME_6: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH, prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) ivexpenditure(HH_Income) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) quadratic


*Output No Control variants (odd labels) with same stone,proper,quaids pattern
esttab IV_INCOME_1 IV_INCOME_3 IV_INCOME_5 using IV_INCOME_NO_CONTROLS.tex 
esttab IV_INCOME_1 IV_INCOME_3 IV_INCOME_5 using IV_INCOME_NO_CONTROLS.csv
*Output With Control variants (even labels) with same stone,proper,quaids pattern
esttab IV_INCOME_2 IV_INCOME_4 IV_INCOME_6 using IV_INCOME_W_CONTROLS.tex
esttab IV_INCOME_2 IV_INCOME_4 IV_INCOME_6 using IV_INCOME_W_CONTROLS.csv




************************************************************
***Instrumental Variable (I.V. Testing) --> PRICES (taxed prices as IV)
************************************************************


*Using Stone's Price Index-->iteration(0)
************************************************************
*No Controls
eststo IV_PRICES_1: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax)  iteration(0) 

*With Controls
eststo IV_PRICES_2: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax) iteration(0)  intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})

*Base Model "Proper Unconstrained"
************************************************************
*No Controls
eststo IV_PRICES_3: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax)  
*With Controls
eststo IV_PRICES_4: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})

*Quadratic 
************************************************************
*No Controls
eststo IV_PRICES_5: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax)  quadratic
*With Controls
eststo IV_PRICES_6: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) quadratic


*CSV & Tex Output No Control variants (odd labels) with same stone,proper,quaids pattern
esttab IV_PRICES_1 IV_PRICES_3 IV_PRICES_5 using IV_PRICES_NO_CONTROLS.tex 
esttab IV_PRICES_1 IV_PRICES_3 IV_PRICES_5 using IV_PRICES_NO_CONTROLS.csv
*Output With Control variants (even labels) with same stone,proper,quaids pattern
esttab IV_PRICES_2 IV_PRICES_4 IV_PRICES_6 using IV_PRICES_W_CONTROLS.tex
esttab IV_PRICES_2 IV_PRICES_4 IV_PRICES_6 using IV_PRICES_W_CONTROLS.csv



************************************************************
***Instrumental Variable (I.V. Testing) --> BOTH 
************************************************************

*Using Stone's Price Index-->iteration(0)
************************************************************
*No Controls
eststo IV_BOTH_1: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax) ivexpenditure(HH_Income) iteration(0) 
*With Controls
eststo IV_BOTH_2: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax) ivexpenditure(HH_Income) iteration(0)  intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})

*Base Model "Proper Unconstrained"
************************************************************
*No Controls
eststo IV_BOTH_3: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax)  ivexpenditure(HH_Income)
*With Controls
eststo IV_BOTH_4: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax) ivexpenditure(HH_Income) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})

*Quadratic 
************************************************************
*No Controls
eststo IV_BOTH_5: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax) ivexpenditure(HH_Income) quadratic
*With Controls
eststo IV_BOTH_6: quietly aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUC Median_Trad_PUC) expenditure(Tot_EXP)  ivprices(Median_On_PUCtax Median_Trad_PUCtax) ivexpenditure(HH_Income) intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) quadratic


*CSV & Tex Output No Control variants (odd labels) with same stone,proper,quaids pattern
esttab IV_BOTH_1 IV_BOTH_3 IV_BOTH_5 using IV_BOTH_NO_CONTROLS.tex 
esttab IV_BOTH_1 IV_BOTH_3 IV_BOTH_5 using IV_BOTH_NO_CONTROLS.csv
*Output With Control variants (even labels) with same stone,proper,quaids pattern
esttab IV_BOTH_2 IV_BOTH_4 IV_BOTH_6 using IV_BOTH_W_CONTROLS.tex
esttab IV_BOTH_2 IV_BOTH_4 IV_BOTH_6 using IV_BOTH_W_CONTROLS.csv




************************************************************
***Instrumental Variable (I.V. Testing) --> PRICES (Using Smartphone data)
************************************************************
**PEW smartpohone data missing 2017 so only 2011-2016 available

*Drop 2017 from Expenditure data and save as new doc
drop if panel_year == 2017
*(24,034 observations deleted)
save "F:\UNR_Houston_SBA_USB_backup11.20.2021\2nd year\Pooled Collapsed 1Min_Online 2011 to 2016 w_Smartphone.dta"
clear
import excel "F:\UNR_Houston_SBA_USB_backup11.20.2021\2nd year\Smartphone Usage.xlsx", sheet("Selected AVGS") firstrow
save "F:\UNR_Houston_SBA_USB_backup11.20.2021\2nd year\Smartphone Usage.dta"
use "F:\UNR_Houston_SBA_USB_backup11.20.2021\2nd year\Pooled Collapsed 1Min_Online 2011 to 2016 w_Smartphone.dta"
merge m:1 panel_year using "F:\UNR_Houston_SBA_USB_backup11.20.2021\2nd year\Smartphone Usage.dta"
drop _merge


************************************************************
*SMARTPHONE I.V. prices
************************************************************


*Using Stone's Price Index-->iteration(0)
************************************************************
*No Controls
eststo IV_SMART_1: aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivprices(SmartphoneAVG CellPhoneAVG)  iteration(0) 

*With Controls
eststo IV_SMART_2: aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivprices(SmartphoneAVG CellPhoneAVG) iteration(0)  intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})

*Base Model "Proper Unconstrained"
************************************************************
*No Controls
eststo IV_SMART_3: aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivprices(SmartphoneAVG CellPhoneAVG)   

*With Controls
eststo IV_SMART_4: aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivprices(SmartphoneAVG CellPhoneAVG)   intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1})

*Quadratic 
************************************************************
*No Controls
eststo IV_SMART_5: aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivprices(SmartphoneAVG CellPhoneAVG) quadratic 

*With Controls
eststo IV_SMART_6: aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivprices(SmartphoneAVG CellPhoneAVG)   intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) quadratic 


esttab IV_SMART_1 IV_SMART_2 IV_SMART_3 IV_SMART_4 IV_SMART_5 IV_SMART_6 using Smartphone_IV.csv, se



*Adding Expenditure IV
************************************************************
eststo IV_SMART_7: aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP)  ivprices(SmartphoneAVG CellPhoneAVG)   intercept(${HH_general_1} ${Male_HH} ${Female_HH} ${HH_Home_1}) quadratic homogeneity











*With Homogeneity Condition
aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) homogeneity 
aidsills_pred On_ExpSH_????, equation(ONLINE_EXP_SH)
dis On_ExpSH_????
eststo AIDS_ILLS_????
esttab using "C:\Users\Randall\Desktop\2nd yr paper\2nd year working paper\AIDS_ILLS_3.csv", se replace

*With Symmetry Condition
aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) tolerance(1e-5) symmetry 
*At 9th iteration: "invalid numlist has elements outside of allowed range
test [ONLINE_EXP_SH]gamma_lnMedian_Trad_PUCtax=[Trad_EXP_SH]gamma_lnMedian_On_PUCtax 


*QUADRATIC CASE
************************************************************

aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) quadratic 

*With Homogeneity Condition
aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) quadratic homogeneity 

*Quadratic w/ homogen with Demographic Variables
*aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_Trad_PUCtax ONLINE_EXP_SH) expenditure(Tot_EXP) intercept(${HH_general}  ${Male_HH} ${Female_HH} ${HH_Home}) quadratic homogeneity 
*alpha_age_and_presence_of_children invalid name Var name too long?

aidsills ONLINE_EXP_SH Trad_EXP_SH , prices(Median_On_PUCtax Median_Trad_PUCtax) expenditure(Tot_EXP) intercept(${HH2_general}  ${Male_HH} ${Female_HH} ${HH2_Home}) quadratic homogeneity 

*No age/presence of children
global HH2_general "household_income household_size type_of_residence household_composition  race hispanic_origin" 
*No household_internet_connection
global HH2_Home " kitchen_appliances tv_items  " 







































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




