use rst_12, clear

* global restrictions
* urban hukou 
drop if A8B1 != 1


* drop the 1989 wave
drop if WAVE == 1989


* drop the in-shool people
* in the educ_12 dataset
drop if A13 != 0
* save to educ_12

* in the rst_12 dataset
merge 1:1 IDind WAVE using educ_12 
drop if _merge != 3
drop _merge

save rst_12.dta, replace


* drop the out-of-range ages
use surveys_pub_12, clear
rename wave WAVE 
save surveys_pub_12.dta, replace

use rst_12 data, clear
merge 1:1 IDind WAVE using surveys_pub_12 
drop if _merge != 3
drop _merge
drop if age < 18
drop if age > 55

save rst_12 data, replace


* drop no-income people
use wages_12, clear
* since some people have two jobs, we have to add both wages up
* drop the negative incomes
drop if C8 < 0
sort WAVE IDind
drop if JOB !=2
save secondarywage_12.dta, replace

use wages_12 data, clear
* drop the negative incomes
drop if C8 < 0
sort WAVE IDind
rename C8 C8F
* drop the secondary ones
drop if JOB ==2
* merge the secondary wage information
merge 1:1 IDind WAVE using secondarywage_12 
drop _merge

* generate the total wage data
gen C8T = cond(missing(C8F), 0, C8F) + cond(missing(C8), 0, C8)

* keep positive incomes
drop if C8T <= 0
save wages_12.dta, replace

* append wages to the rst_12 dataset
use rst_12 data
merge 1:1 IDind WAVE using wages_12 
drop if _merge != 3
drop _merge


* drop those without spouse data
* this automatically drops those who are not married
use rst_12
drop if missing(IDind_s)
save rst_12.dta, replace


* process gender information
use relationmast_pub_00, clear
drop Rel_type MP REL_1 REL_2 hhid
drop IDind_1 SEX_1  
rename IDind_2 IDind
rename SEX_2 SEX
save relationmast_pub_00_2.dta, replace

use relationmast_pub_00, clear
drop Rel_type MP REL_1 REL_2 hhid
drop IDind_2 SEX_2 
rename IDind_1 IDind
rename SEX_1 SEX
save relationmast_pub_00_1.dta, replace

* append the datasets
append using relationmast_pub_00_2

* drop duplicates
duplicates report IDind SEX 
duplicates report IDind
 
sort IDind SEX
quietly by IDind SEX: gen dup = cond(_N==1,0,_n)
tabulate dup
drop if dup > 1
drop dup 
save relationmast_pub_00.dta, replace


* match gender information
use rst_12, clear
merge m:1 IDind using relationmast_pub_00 
drop if _merge != 3
drop _merge

* save the time used data
* merge time used data
duplicates report WAVE IDind
merge 1:1 IDind WAVE using timea_12 
drop if _merge != 3
drop _merge
save rst_12.dta, replace



* vairables construction
* sex ratio
* 1990 census
* give each observation a unique id
gen long id = _n
* count target observations
egen population = tag(provcn sex age id)
collapse  (sum) population, by(provcn sex age)
save 1990sexratio.dta, replace

* 2000 census
* give each observation a unique id
gen long id = _n
* count target observations
egen population = tag(province r3 age1 id)
collapse  (sum) population, by(province r3 age1)

* matching both census
* renaming 
rename population population2
rename province provcn
rename age1 age
rename r3 sex
save 2000sexratio.dta, replace

use 1990sexratio, clear
merge 1:1 provcn sex age using 2000sexratio
* Note: here we have a couple of unmatched, the reason is that, due to geological administrative change, Chongqing did not become a municipality (like Beijing / Shanghai, do not belong to a province) until 1997. So in 2000, we have one more province than 1990. Dropping Chongqing in 2000 is appropriate, since it was added in the CHNS data in 2011, requiring ratios only from the 2005 census. 

* drop Chongqing in 2000 and those extremely old ages
drop if _merge != 3
drop _merge

* drop the non-target ages
drop if age > 59
drop if age < 16
save 12sexratio.dta, replace

* change the data to one with two variables (male and female) each year
drop if sex == 1
rename population population_f
rename population2 population2_f
svae female12.dta, replace

use 12sexratio, clear
drop if sex == 2
rename population population_m
rename population2 population2_m
save male12.dta, replace

* merge both genders
merge 1:1 provcn age using female12

* generate lag/lead variables in ages for males and females within each province
by provcn: gen lead1m1 = population_m[_n+1]
by provcn: gen lead2m1 = population_m[_n+2]
by provcn: gen lead3m1 = population_m[_n+3]
by provcn: gen lead4m1 = population_m[_n+4]

by provcn: gen lead1m2 = population2_m[_n+1]
by provcn: gen lead2m2 = population2_m[_n+2]
by provcn: gen lead3m2 = population2_m[_n+3]
by provcn: gen lead4m2 = population2_m[_n+4]

by provcn: gen lead1f1 = population_f[_n+1]
by provcn: gen lead2f1 = population_f[_n+2]
by provcn: gen lag1f1 = population_f[_n-1]
by provcn: gen lag2f1 = population_f[_n-2]

by provcn: gen lead1f2 = population2_f[_n+1]
by provcn: gen lead2f2 = population2_f[_n+2]
by provcn: gen lag1f2 = population2_f[_n-1]
by provcn: gen lag2f2 = population2_f[_n-2]

* compute sex ratio for each age and province
* with 2-year age gap and 5-year window
gen sr1 = (lead1m1 + lead2m1 + lead3m1 + lead4m1 + population_m) / (lead1f1 + lead2f1 + lag1f1 + lag2f1 + population_f)

gen sr2 = (lead1m2 + lead2m2 + lead3m2 + lead4m2 + population2_m) / (lead1f2 + lead2f2 + lag1f2 + lag2f2 + population2_f)

* drop missing values - those ages only for computation but no in the range of consideration
drop if missing(sr1)
drop if missing(sr2)
drop lead1m1 lead2m1 lead3m1 lead4m1 population_m lead1f1 lead2f1 lag1f1 lag2f1 population_f lead1m2 lead2m2 lead3m2 lead4m2 population2_m lead1f2 lead2f2 lag1f2 lag2f2 population2_f
drop _merge sex

rename provcn t1

* match the waves of the CHNS data
* 1991
rename sr1 sr
drop sr2
gen WAVE = 1991
save sexratio1991.dta, replace

* 1993
replace WAVE = 1993
save sexratio1993.dta, replace

* 1997
drop sr1
rename sr2 sr 
gen WAVE = 1997
save sexratio1997.dta, replace

* 2000
replace WAVE = 2000
save sexratio2000.dta, replace

* process the 2005 census data to get provincal gender ratio
* generate provincal code (numeric)
gen province_num = floor(dz_code / 100)

* compute gender ratio
* give each observation a unique id
gen long idind = _n
* count target observations
tab age
egen population = tag(province_num r3 age id)
collapse  (sum) population, by(province_num r3 age)

rename province_num provcn
rename r3 sex

* drop the non-target ages
drop if age > 59
drop if age < 16

sort provcn age sex

save 2005sexratio.dta, replace

* change the data to one with two variables (male and female) each year
drop if sex != 2
rename population population_f
save female.dta, replace

drop if sex != 1
rename population population_m
save male.dta, replace

* merge both genders
merge 1:1 provcn age using female

* generate lag/lead variables in ages for males and females within each province
by provcn: gen lead1m1 = population_m[_n+1]
by provcn: gen lead2m1 = population_m[_n+2]
by provcn: gen lead3m1 = population_m[_n+3]
by provcn: gen lead4m1 = population_m[_n+4]

by provcn: gen lead1f1 = population_f[_n+1]
by provcn: gen lead2f1 = population_f[_n+2]
by provcn: gen lag1f1 = population_f[_n-1]
by provcn: gen lag2f1 = population_f[_n-2]

* compute sex ratio for each age and province
* with 2-year age gap and 5-year window
gen sr = (lead1m1 + lead2m1 + lead3m1 + lead4m1 + population_m) / (lead1f1 + lead2f1 + lag1f1 + lag2f1 + population_f)

* drop missing values - those ages only for computation but no in the range of consideration
drop if missing(sr)
drop lead1m1 lead2m1 lead3m1 lead4m1 population_m lead1f1 lead2f1 lag1f1 lag2f1 population_f
drop _merge sex

rename provcn t1

* 2004
gen WAVE = 2004
save sexratio2004.dta, replace

* 2009
replace WAVE = 2009
save sexratio2009.dta, replace

* 2011
replace WAVE = 2011
save sexratio2011.dta, replace

* merge all ratios 
use sexratio1991, clear
append using sexratio1993
append using sexratio1997
append using sexratio2000
append using sexratio2004
append using sexratio2009
append using sexratio2011
save sexratio.dta, replace

* indicator variable for families with child(ren) aged less than 6
use surveys_pub_12
drop if age >= 6
drop Idind line commid t1 t2 t3 t4 t5 stratum urban t7 individual physical diet biomaker toenail
gen DUMMYCHILD6 = 1 

* since we only need the indicator of having or not, one record for each household is sufficient, drop duplicates for hhid
sort hhid WAVE
quietly by hhid WAVE: gen dup = cond(_N==1,0,_n)
tabulate dup
drop if dup > 1
drop dup age
save DUMMYCHILD6.dta, replace

* merge the DUMMYCHILD6
use rst_12, clear
merge m:1 hhid WAVE using DUMMYCHILD6 
replace DUMMYCHILD6 = 0 if DUMMYCHILD6 == .


* additional variables
* time multipliers to convert things in weekly average terms
summarize K3 K5 K7 K13

* drop negative values of time
drop if K13 < 0
drop if K7 < 0
drop if K5 < 0
drop if K3 < 0

* buying food
gen K3AD = 7
replace K3AD = 1 if K3A == 2

* preparing food
gen K5AD = 7
replace K5AD = 1 if K5A == 2

* washing clothes
gen K7AD = 7
replace K7AD = 1 if K7A == 2

* caring for child(ren)
gen K13AD = 7
replace K13AD = 1 if K13A == 2

* DUMMY: caring for child(ren) under 6 or not
* this is not equivalent to the DUMMYCHILD6, since, intuitively, the couple may not care for the child(ren) aged below 6 even if the child(ren) exist(s), their parents may do the job for them, so this dummy is only used for child-care time computation
* make the category "unknown" as missing
replace K7D = . if K7D == 9


* time used share
* buying food
gen TBF = K3AD * K3 
replace TBF = 0 if TBF == .

* preparing food
gen TPF = K5 * K5AD 
replace TPF = 0 if TPF == .

* washing clothes
gen TWC = K7 * K7AD
replace TWC = 0 if TWC == .

* caring for child(ren)
* treat the time caring for child(ren) as 0 if not cared for child under 6
gen TCFC6 = K7D * K13AD * K13
replace TCFC6 = 0 if TCFC6 == .

* total time spent 
gen TTU = TBF + TCFC6 + TPF + TWC
drop if missing(IDind)
save rst_12.dta, replace

* time share 
* generate spouses' time used for housework
drop if SEX == 2
drop IDind 
rename IDind_s IDind
rename TTU TTUM
keep IDind WAVE TTUM
replace TTUM = 0 if TTUM == .
drop if missing(IDind)
save maletimeused.dta, replace

* match couples' time
use rst_12, clear
drop _merge
merge 1:1 IDind WAVE using maletimeused 
drop _merge

* generate the dependent vairable
gen TTUS = TTU / (TTUM + TTU)


* income share
* individual annual income
gen AI = 12 * C8T

* get household annual income 
* here i just assume the household annual income just comes from the couple since the B2E in the oinc_12 data is missing too much 
drop if missing(IDind)
drop if SEX == 2
drop IDind 
rename IDind_s IDind
rename AI AIM
keep IDind WAVE AIM
save maleinc.dta, replace

use rst_12, clear
merge 1:1 IDind WAVE using maleinc

* annual income share 
gen AIS = AI / (AIM + AI)


* h-women dummy 
* generate median income by province and year
bysort WAVE t1 : egen income_median = median(AI)

* generate the h-women dummy
gen HWOMEN = 0
replace HWOMEN = 1 if AI >= income_median


* log sex ratio
* merging dataset
* Chongqing's code is different from the one in the census
* here i follow the census and change the ones in the CHNS data 
replace t1 = 50 if t1 == 55
merge m:1 t1 WAVE age using sexratio 

* log sex ratio
gen logsr = log(sr)
drop if AI == .

* interaction of log sex ratio and the h-women dummy 
gen logsrth = logsr * HWOMEN

* h-women dummy for 10 percent percentile
bysort WAVE T1: egen p90 = pctile(AI), p(90)
gen HWOMEN2 = (AI >= p90)
bysort WAVE T1: egen p80 = pctile(AI), p(80)
gen HWOMEN3 = (AI >= p80)
bysort WAVE T1: egen p70 = pctile(AI), p(70)
gen HWOMEN4 = (AI >= p70)
bysort WAVE T1: egen p60 = pctile(AI), p(60)
gen HWOMEN5 = (AI >= p60)

* interaction of log sex ratio and the h-women dummy 
gen logsrth1 = logsr * HWOMEN2
gen logsrth2 = logsr * HWOMEN3
gen logsrth3 = logsr * HWOMEN4
gen logsrth4 = logsr * HWOMEN5


* regression 
* robust standard errors clustered at the province level
* table 4 column 1
regress TTUS logsr HWOMEN logsrth i.WAVE i.T1 if SEX == 2, vce(cluster T1)
outreg2 using table4.doc, replace
* table 4 column 2
regress TTUS logsr HWOMEN logsrth AIS i.WAVE i.T1 if SEX == 2, vce(cluster T1)
outreg2 using table4.doc, append
* table 4 column 3
regress TTUS logsr HWOMEN logsrth AIS i.WAVE i.T1 if SEX == 2 & DUMMYCHILD6 == 0, vce(cluster T1)
outreg2 using table4.doc, append

* 10%
* a-table 14 column 1
regress TTUS logsr HWOMEN2 logsrth1 i.WAVE i.T1 i.AI i.age i.A12 if SEX == 2, vce(cluster T1)
outreg2 using 10atalbe14.doc, replace
* a-table 14 column 2
regress TTUS logsr HWOMEN2 logsrth1 AIS i.WAVE i.T1 i.age i.AI i.A12 i.AIM if SEX == 2, vce(cluster T1)
outreg2 using 10atalbe14.doc, append
* a-table 14 column 3
regress TTUS logsr HWOMEN2 logsrth1 AIS i.WAVE i.T1 i.age i.AI i.A12 i.AIM if SEX == 2 & DUMMYCHILD6 == 0, vce(cluster T1)
outreg2 using 10atalbe14.doc, append

* 20% 
* a-table 14 column 1
regress TTUS logsr HWOMEN3 logsrth2 i.WAVE i.T1 i.AI i.age i.A12 if SEX == 2, vce(cluster T1)
outreg2 using 20atalbe14.doc, replace
* a-table 14 column 2
regress TTUS logsr HWOMEN3 logsrth2 AIS i.WAVE i.T1 i.age i.AI i.A12 i.AIM if SEX == 2, vce(cluster T1)
outreg2 using 20atalbe14.doc, append
* a-table 14 column 3
regress TTUS logsr HWOMEN3 logsrth2 AIS i.WAVE i.T1 i.age i.AI i.A12 i.AIM if SEX == 2 & DUMMYCHILD6 == 0, vce(cluster T1)
outreg2 using 20atalbe14.doc, append

* 30%
* a-table 14 column 1
regress TTUS logsr HWOMEN4 logsrth3 i.WAVE i.T1 i.AI i.age i.A12 if SEX == 2, vce(cluster T1)
outreg2 using 30atalbe14.doc, replace
* a-table 14 column 2
regress TTUS logsr HWOMEN4 logsrth3 AIS i.WAVE i.T1 i.age i.AI i.A12 i.AIM if SEX == 2, vce(cluster T1)
outreg2 using 30atalbe14.doc, append
* a-table 14 column 3
regress TTUS logsr HWOMEN4 logsrth3 AIS i.WAVE i.T1 i.age i.AI i.A12 i.AIM if SEX == 2 & DUMMYCHILD6 == 0, vce(cluster T1)
outreg2 using 30atalbe14.doc, append

* 40%
* a-table 14 column 1
regress TTUS logsr HWOMEN5 logsrth4 i.WAVE i.T1 i.AI i.age i.A12 if SEX == 2, vce(cluster T1)
outreg2 using 40atalbe14.doc, replace
* a-table 14 column 2
regress TTUS logsr HWOMEN5 logsrth4 AIS i.WAVE i.T1 i.age i.AI i.A12 i.AIM if SEX == 2, vce(cluster T1)
outreg2 using 40atalbe14.doc, append
* a-table 14 column 3
regress TTUS logsr HWOMEN5 logsrth4 AIS i.WAVE i.T1 i.age i.AI i.A12 i.AIM if SEX == 2 & DUMMYCHILD6 == 0, vce(cluster T1)
outreg2 using 40atalbe14.doc, append



