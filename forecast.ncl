load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shea_util.ncl"
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/BB_utils.ncl"
; load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/shapefile_utils.ncl"

; I don't think this did anything.
; TODO remove after checking if it
; does impact stdout/stderr
; err = NhlGetErrorObjectId()
; setvalues err
;   "errLevel" : "Fatal"          ; only report Fatal errors
; end setvalues

begin

; TODO Paths we will need:
; - input data directory (netCDF files etc)
; - "filedir" seems to copy some statically-needed stuff
;   which we may not have from Brian yet.
; - scratch working directory
; - output directory
;   * Almost all instances of hardcoded /var/www/html
;   * ware pointing to /var/www/html/maps/ which is probably
;   * the same as the output directory.  (300 out of 303 refs).

; This is defined in the documentation currently as
; "Directory where NCAR Graphics HLU and NCL
; example data files are installed."
; TODO.  Can probably make it point elsewhere for normal updates
; so we're not poking around in system installs for
; normal maintenance, after we're sure what's being loaded
; there.
data_dir = ncargpath("data")

; How is HOME environment / location used?
; What files live here and how are they used?
; this is either $HOME or /var/www/html.
; filedir = "/var/www/html/"
; ^ This seems to be a second source directory
; for file inputs.
; Updated, this appear to be another kind
; of scratch location where temporary text files
; used in processing are created.
; so this should also go into a nonce space.
; scan for instances of asciiwrite to find
; where this are created.
; needs a trailing slash?
; TODO manage trailing/slashes etc everywhere
;filedir = "/tmp/eapi/"

; Define the output directory (see comments above
; re: /var/www/html/maps/
; this should be unique for each run.
output_dir = getenv("NCL_OUTPUT_DIR")
filedir = output_dir ; these are the same for our purposes

if(ismissing(output_dir)) then
  print("NCL_OUTPUT_DIR not defined, exiting.")
  exit()
end if

xyear = toint(systemfunc("date +'%Y'"))
xmonth = toint(systemfunc("date +'%m'"))
xday = toint(systemfunc("date +'%d'"))
xhour = toint(systemfunc("date +'%H'"))

; TODO this has some special date handling to examine later
currentYear = xyear
if (xmonth.eq.1.and.xday.le.3) then
currentYear = xyear - 1
end if

; TODO this has some special date handling to examine later
currentMonth = xmonth - 2
; TODO this fails when the data aren't ready by the 3rd.
if (xday.gt.3) then
  currentMonth = xmonth - 1
end if


;***********************************************************
; Change the lines below as new data come in. If only some
; data sets are updated, this allows the program to run
; by keeping the current date such that all data sets have
; a minimum amount of data. The few lines of code above
; set the current year and month. If there's a problem,
; you can manuall set it below.
;***********************************************************
; TODO @kyle verify this isn't from our branching work
; or part of what we need to do to maintain this tool over time
  ;currentMonth = 3          ; most recent month with data
  ;currentYear = 2020        ; most recent year with data
;***********************************************************


  theMaxDimsizes = ((currentYear - 1948) * 12) + currentMonth





cr = tochar(10)

winner=""

webinput = isdefined("fromweb")

shapefile_name = data_dir + "/shapes/SeaIceBasinTestDD.shp"
slp_file = addfile(data_dir + "/downloads/slp.mon.mean.nc","r")
hgt_file = addfile(data_dir + "/downloads/hgt.mon.mean.nc","r")
ice_file = addfile(data_dir + "/downloads/icec.sfc.mon.mean.nc","r")
t2m_file = addfile(data_dir + "/downloads/air.mon.mean.nc","r")
t925_file = addfile(data_dir + "/downloads/air.mon.mean.pres.nc","r")
ersst_file = addfile(data_dir + "/downloads/sst.mnmean.v5.nc","r")

if(webinput.eq.False) then
  ; TODO @kyle does variable mean we've never
  ; properly tested the correlations?!
  justcorrelations = 0

  ; TODO figure out whats up with txtareayesno
  txtareayesno = 2

  ; TODO note duplication between this and definitions below
  ; when the app is launched from the web (= command line options)
  txtarea = "1948,134"+cr+"1949,134"+cr+"1950,126"+cr+"1951,120"+cr+"1952,133"+cr+"1953,119"+cr+"1954,126"+cr+"1955,129"+cr+"1956,122"+cr+"1957,125"+cr+"1958,119"+cr+"1959,128"+cr+"1960,123"+cr+"1961,125"+cr+"1962,132"+cr+"1963,125"+cr+"1964,141"+cr+"1965,127"+cr+"1966,128"+cr+"1967,124"+cr+"1968,129"+cr+"1969,118"+cr+"1970,124"+cr+"1971,128"+cr+"1972,131"+cr+"1973,124"+cr+"1974,126"+cr+"1975,130"+cr+"1976,123"+cr+"1977,126"+cr+"1978,120"+cr+"1979,120"+cr+"1980,120"+cr+"1981,120"+cr+"1982,130"+cr+"1983,119"+cr+"1984,130"+cr+"1985,131"+cr+"1986,128"+cr+"1987,125"+cr+"1988,118"+cr+"1989,121"+cr+"1990,114"+cr+"1991,121"+cr+"1992,135"+cr+"1993,113"+cr+"1994,119"+cr+"1995,116"+cr+"1996,126"+cr+"1997,120"+cr+"1998,110"+cr+"1999,119"+cr+"2000,122"+cr+"2001,128"+cr+"2002,127"+cr+"2003,119"+cr+"2004,115"+cr+"2005,118"+cr+"2006,122"+cr+"2007,117"+cr+"2008,127"+cr+"2009,121"+cr+"2010,119"+cr+"2011,124"+cr+"2012,114"+cr+"2013,140"+cr+"2014,115"+cr+"2015,114"+cr+"2016,114"+cr+"2017,121"+cr+"2018,"+cr+"2019,"+cr+"2020,"+cr+"2021,"+cr+"2022,"+cr+"2023,"+cr+"2024,"+cr+"2025,"+cr+"2026,"+cr+"2027,"
  asciiwrite (filedir+"special_ascii.txt" , txtarea)
  zz = systemfunc("mv -f "+filedir+"special_ascii.txt "+output_dir+"/special_ascii.txt")
end if

if(webinput.eq.True) then
  ; TODO xref input var txtareayesno in PHP script,
  ; ~line 682 this may be hardcoded to 2.  Find out why
  ; and if we can delete unused code here.
  if (txtareayesno.eq.2) then
    txtarea = "1948,134"+cr+"1949,134"+cr+"1950,126"+cr+"1951,120"+cr+"1952,133"+cr+"1953,119"+cr+"1954,126"+cr+"1955,129"+cr+"1956,122"+cr+"1957,125"+cr+"1958,119"+cr+"1959,128"+cr+"1960,123"+cr+"1961,125"+cr+"1962,132"+cr+"1963,125"+cr+"1964,141"+cr+"1965,127"+cr+"1966,128"+cr+"1967,124"+cr+"1968,129"+cr+"1969,118"+cr+"1970,124"+cr+"1971,128"+cr+"1972,131"+cr+"1973,124"+cr+"1974,126"+cr+"1975,130"+cr+"1976,123"+cr+"1977,126"+cr+"1978,120"+cr+"1979,120"+cr+"1980,120"+cr+"1981,120"+cr+"1982,130"+cr+"1983,119"+cr+"1984,130"+cr+"1985,131"+cr+"1986,128"+cr+"1987,125"+cr+"1988,118"+cr+"1989,121"+cr+"1990,114"+cr+"1991,121"+cr+"1992,135"+cr+"1993,113"+cr+"1994,119"+cr+"1995,116"+cr+"1996,126"+cr+"1997,120"+cr+"1998,110"+cr+"1999,119"+cr+"2000,122"+cr+"2001,128"+cr+"2002,127"+cr+"2003,119"+cr+"2004,115"+cr+"2005,118"+cr+"2006,122"+cr+"2007,117"+cr+"2008,127"+cr+"2009,121"+cr+"2010,119"+cr+"2011,124"+cr+"2012,114"+cr+"2013,140"+cr+"2014,115"+cr+"2015,114"+cr+"2016,114"+cr+"2017,121"+cr+"2018,"+cr+"2019,"+cr+"2020,"+cr+"2021,"+cr+"2022,"+cr+"2023,"+cr+"2024,"+cr+"2025,"+cr+"2026,"+cr+"2027,"
  end if
  if (txtareayesno.eq.1) then
    txtarea=str_sub_str(tostring(txtarea),tostring(" "),tostring(cr))
  end if
  if (txtareayesno.eq.0) then
    txtarea = "1948,134"+cr+"1949,134"+cr+"1950,126"+cr+"1951,120"+cr+"1952,133"+cr+"1953,119"+cr+"1954,126"+cr+"1955,129"+cr+"1956,122"+cr+"1957,125"+cr+"1958,119"+cr+"1959,128"+cr+"1960,123"+cr+"1961,125"+cr+"1962,132"+cr+"1963,125"+cr+"1964,141"+cr+"1965,127"+cr+"1966,128"+cr+"1967,124"+cr+"1968,129"+cr+"1969,118"+cr+"1970,124"+cr+"1971,128"+cr+"1972,131"+cr+"1973,124"+cr+"1974,126"+cr+"1975,130"+cr+"1976,123"+cr+"1977,126"+cr+"1978,120"+cr+"1979,120"+cr+"1980,120"+cr+"1981,120"+cr+"1982,130"+cr+"1983,119"+cr+"1984,130"+cr+"1985,131"+cr+"1986,128"+cr+"1987,125"+cr+"1988,118"+cr+"1989,121"+cr+"1990,114"+cr+"1991,121"+cr+"1992,135"+cr+"1993,113"+cr+"1994,119"+cr+"1995,116"+cr+"1996,126"+cr+"1997,120"+cr+"1998,110"+cr+"1999,119"+cr+"2000,122"+cr+"2001,128"+cr+"2002,127"+cr+"2003,119"+cr+"2004,115"+cr+"2005,118"+cr+"2006,122"+cr+"2007,117"+cr+"2008,127"+cr+"2009,121"+cr+"2010,119"+cr+"2011,124"+cr+"2012,114"+cr+"2013,140"+cr+"2014,115"+cr+"2015,114"+cr+"2016,114"+cr+"2017,121"+cr+"2018,"+cr+"2019,"+cr+"2020,"+cr+"2021,"+cr+"2022,"+cr+"2023,"+cr+"2024,"+cr+"2025,"+cr+"2026,"+cr+"2027,"
    specialnum = 0
  end if
  asciiwrite (filedir+"special_ascii.txt" , txtarea)

end if

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Get PDO, NPM, SOI, and Sea Ice Values from .csv file
;;;  (Section 5)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  index_file =       data_dir + "/csv/Indicies.csv"
  seaiceascii_file = data_dir + "/csv/seaiceextent.csv"
  lines       = asciiread(index_file,-1,"string")
  numrows     = dimsizes(lines)
  strs2       = str_split_csv (lines, ",", 0)
  seaice_csv = new(numrows,float)
  pdo_csv    = new(numrows,float)
  npm_csv    = new(numrows,float)
  soi_csv    = new(numrows,float)
  year_csv    = new(numrows,float)
  other_csv    = new(numrows,float)
  do tt = 0, numrows-1
    year_csv(tt) = tofloat(strs2(tt,0))
    seaice_csv(tt) = tofloat(strs2(tt,2))
    pdo_csv(tt) = tofloat(strs2(tt,3))
    npm_csv(tt) = tofloat(strs2(tt,4))
    soi_csv(tt) = tofloat(strs2(tt,5))
    other_csv(tt) = tofloat(strs2(tt,6))
  end do
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Get all the program parameters from the
;;;  file called "parameters1.csv".
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
if (webinput.eq.False) then
  parameters_file =         data_dir + "/csv/parameters1.csv"
  values_1d2 = asciiread(parameters_file,-1,"string")
  strs3   = str_split_csv (values_1d2, ",", 0)
  nums3   = toint (strs3)                    ;
  nums3@_FillValue = -9999
  numcols3     = 23
  numrows3     = dimsizes(values_1d2)
end if
if (webinput.eq.True) then
  ; TODO document the impact on the visualizations
  ; from this fixed parameter
  numrows3 = 1    ; if the input comes from the web, only do one iteration of outside loop
end if
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end the section reading list of
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; coordinates from boxcoordsX.csv


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Now we loop through every set of box coordinates, look for analogs,
;;;  and make plots. The variable "ty" is the index for the boxcoordsX
;;;  list. "End Do" is right before "End" statement. (Section 7)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
allYears = ""
do ty=0,numrows3-1


if (webinput.eq.False) then
  usermonth = nums3(ty,0)
  useryear  = nums3(ty,1)
  ; TODO what's this?
  if (useryear .eq. 8888)
    exit
  end if
  exmth     = nums3(ty,2)
  fmnths    = nums3(ty,3)
  fmnths2   = nums3(ty,4)
  heightlev = toint(nums3(ty,5))
  templev   = toint(nums3(ty,6))
  variable  = nums3(ty,7)                       ; 1=slp  2 = z500  3=t2m  4=t925  5=sst
  slpwgt    = tofloat(nums3(ty,8)) / 100.0
  h500wgt   = tofloat(nums3(ty,9)) / 100.0
  t2mwgt    = tofloat(nums3(ty,10)) / 100.0
  t925wgt   = tofloat(nums3(ty,11)) / 100.0
  sstwgt    = tofloat(nums3(ty,12)) / 100.0
  y1        = nums3(ty,16)                      ; low latitude of analysis box (-90 to +90)
  y2        = nums3(ty,17)                      ; high latitude of analysis box (-90 to +90)
  x1        = nums3(ty,18)                      ; left longitude of analysis box (0 to 360)
  x2        = nums3(ty,19)                      ; right longitude of analysis box (0 to 360)
  AK1       = nums3(ty,20)                      ; low latitude of forecast box (-90 to +90)
  AK2       = nums3(ty,21)                      ; high latitude of forecast box (-90 to +90)
  AK3       = nums3(ty,22)                      ; left longitude of forecast box (0 to 360)
  AK4       = nums3(ty,23)                      ; right longitude of forecast box (0 to 360)
  ID        = nums3(ty,24)                      ; ID Number for organization
  detrend   = nums3(ty,25)                      ; 0 = no   1 = yes
  autoWgt   = nums3(ty,26)                      ; 0 = user weights   1 = use auto weighting
  indexchoice = 0
  specialnum = 1
  doNMME = False
end if


; TODO remove unused stuff
pearsons = 0



domanual = isdefined("manualyesno")

numAnalogsToUse = 5

if (webinput.eq.True) then
  numAnalogsToUse = howmanyyears
end if










  slp      = mon_fullyear( slp_file->slp(0:theMaxDimsizes-1,:,:), 0)   ; all times on file
  h500     = mon_fullyear( hgt_file->hgt(0:theMaxDimsizes-1,heightlev,:,:), 0)   ; all times on file
  t2m      = mon_fullyear( t2m_file->air(0:theMaxDimsizes-1,:,:), 0)   ; all times on file
  t925     = mon_fullyear( t925_file->air(0:theMaxDimsizes-1,templev,:,:), 0)   ; all times on file
  icec     = mon_fullyear( ice_file->icec(0:theMaxDimsizes-1,:,:), 0)   ; all times on file
  sst      = mon_fullyear( ersst_file->sst(1128:1128+theMaxDimsizes-1,:,:), 0)   ; all times on file

  precip_file = addfile(data_dir + "/downloads/precip.mon.anom.nc","r")

  precip   = mon_fullyear( precip_file->precip(0:theMaxDimsizes-2,:,:), 0)          ; use this line is precip has not updated yet
  if (xday.ge.7) then
    precip   = mon_fullyear( precip_file->precip(0:theMaxDimsizes-1,:,:), 0)         ; use this line is precip has updated
  end if


  if (variable.eq.6) then
    delete(icec)
    delete(ice_file)
    icec = precip
    ice_file = precip_file
  end if

  ; reshape SST to be the same dimentions as other R1 variables
  sstnew = ReshapeR1("sst",sst,slp)
  sstnew@long_name = sst@long_name
  sstnew@units = sst@units
  delete(sst)
  sst = sstnew
  delete(sstnew)

  ; reshape ICEC or Precip to be the same dimentions as other R1 variables
  if (variable.lt.6) then
    icecnew = ReshapeR1("ice",icec,slp)
  end if
  if (variable.eq.6) then
    icecnew = ReshapeR1("precip",icec,slp)
  end if
  icecnew@long_name = icec@long_name
  icecnew@units = icec@units
  delete(icec)
  icec = icecnew
  delete(icecnew)




  R1size = dimsizes(slp)


  if (detrend.eq.1) then
    slpdtrend = slp
    slpdtrend = dtrend_msg_n(ispan(0,R1size(0)-1,1),slp,False,False,0)
    h500dtrend = h500
    h500dtrend = dtrend_msg_n(ispan(0,R1size(0)-1,1),h500,False,False,0)
    t2mdtrend = t2m
    t2mdtrend = dtrend_msg_n(ispan(0,R1size(0)-1,1),t2m,False,False,0)
    t925dtrend = t925
    t925dtrend = dtrend_msg_n(ispan(0,R1size(0)-1,1),t925,False,False,0)
    sstdtrend = sst
    sstdtrend = dtrend_msg_n(ispan(0,R1size(0)-1,1),sst,False,False,0)
    icecdtrend = icec
    icecdtrend = dtrend_msg_n(ispan(0,R1size(0)-1,1),icec,False,False,0)
    slp = slpdtrend
    h500 = h500dtrend
    t2m = t2mdtrend
    t925 = t925dtrend
    icec = icecdtrend
    sst = sstdtrend
    delete(slpdtrend)
    delete(h500dtrend)
    delete(t2mdtrend)
    delete(t925dtrend)
    delete(icecdtrend)
    delete(sstdtrend)
  end if


  slp_rm = mon_fullyear(rmMonAnnCycTLL(slp),0)
  h500_rm = mon_fullyear(rmMonAnnCycTLL(h500),0)
  t2m_rm = mon_fullyear(rmMonAnnCycTLL(t2m),0)
  t925_rm = mon_fullyear(rmMonAnnCycTLL(t925),0)
  sst_rm = mon_fullyear(rmMonAnnCycTLL(sst),0)
  icec_rm = mon_fullyear(rmMonAnnCycTLL(icec),0)

  slp_std = dim_standardize_n_Wrap(slp_rm(:,:,:), 1, 0)
  h500_std = dim_standardize_n_Wrap(h500_rm(:,:,:), 1, 0)
  t2m_std = dim_standardize_n_Wrap(t2m_rm(:,:,:), 1, 0)
  t925_std = dim_standardize_n_Wrap(t925_rm(:,:,:), 1, 0)

  xc = sst_rm(0:theMaxDimsizes-1,:,:)
  xc = 1.0
  xd = sst_rm(0:theMaxDimsizes-1,:,:)
  xd@_FillValue = 0.0
  delete(xd@_FillValue)
  sst_std = dim_standardize_n_Wrap(xd, 1, 0)
  sst_std = sst_std * xc
  delete(xc)
  delete(xd)

  xc = icec_rm(0:theMaxDimsizes-1,:,:)
  xc = 1.0
  xd = icec_rm(0:theMaxDimsizes-1,:,:)
  xd@_FillValue = 0.0
  delete(xd@_FillValue)
  ice_std = dim_standardize_n_Wrap(xd, 1, 0)
  ice_std = ice_std * xc
  delete(xc)
  delete(xd)

  sst_std2 = mon_fullyear(sst_std,0)
  ice_std2 = mon_fullyear(ice_std,0)
  delete(sst_std)
  delete(ice_std)
  sst_std = sst_std2
  ice_std = ice_std2
  delete(sst_std2)
  delete(ice_std2)


if(webinput.eq.True) then
  ; TODO eventually we can sanity-check inputs
  ; to this script one more time at the start,
  ; but that's for after more cleanup of this codebase.
  if(variable.eq.0) then
    print("Please select a theme to map.")
    exit
  end if
  slpwgt    = tofloat(slpwgt1) / 100.0
  h500wgt   = tofloat(h500wgt1) / 100.0
  t2mwgt    = tofloat(t2mwgt1) / 100.0
  t925wgt   = tofloat(t925wgt1) / 100.0
  sstwgt    = tofloat(sstwgt1) / 100.0
  doNMME = False
end if
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end the file name section


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; generate eofs section

if (currentYear.le.2019) then
  backout = 0
end if
if (currentYear.ge.2020) then
  backout = 12 - currentMonth
end if







;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  The next block is where the index values for climatology
;;;  are determined.  (Section 3)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  yrStrt = 1948                                        ; Beginning year of .nc file
  yrLast = currentYear                                 ; Last COMPLETE year of .nc file
  if (currentMonth.lt.12) then
    yrLast = currentYear - 1                           ; Last COMPLETE year of .nc file
  end if
  datayears = yrLast-yrStrt+1
  yrStrtClm = 1981                                     ; change number for different climate begin period
  yrLastClm = 2010                                     ; change number for different climate end period
  yrStrtsstClm = 1981                                  ; change number for different climate begin period
  yrLastsstClm = 2010                                  ; change number for different climate end period
  yrStrtIceClm = 1979                                  ; change number for different ice concentration climate begin period
  yrLastIceClm = currentYear                           ; change number for different ice concentration climate end period
  if (currentMonth.lt.12) then
    yrLastIceClm = currentYear - 1
  end if



  YYYYMM    = cd_calendar(slp_file->time, -1)
  iStrt  = ind(YYYYMM.eq.(yrStrt*100+ 1))              ; start index for all years
  iLast  = ind(YYYYMM.eq.(yrLast*100+12))              ; last index for all years

  iclmStrt  = ind(YYYYMM.eq.(yrStrtClm*100+ 1))        ; start index for climatology
  iclmLast  = ind(YYYYMM.eq.(yrLastClm*100+12))        ; last index for climatology
  isstclmStrt  = ind(YYYYMM.eq.(yrStrtsstClm*100+ 1))        ; start index for climatology
  isstclmLast  = ind(YYYYMM.eq.(yrLastsstClm*100+12))        ; last index for climatology
  iIceclmStrt  = ind(YYYYMM.eq.(yrStrtIceClm*100+ 1))  ; start index for ice concentration climatology
  iIceclmLast  = ind(YYYYMM.eq.(yrLastIceClm*100+12))  ; last index for ice concentration climatology

  TIME   = slp_file->time
  YYYYMM   = cd_calendar(TIME,-1)/100                 ; entire file
  iYYYYMM  = ind(YYYYMM.ge.iStrt .and. YYYYMM.le.iLast)
  iClmYYYYMM  = ind(YYYYMM.ge.iclmStrt .and. YYYYMM.le.iclmLast)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  Create a 12-month (3 repeating 12-month) climo array. The arrays
;;;  are typically 12-month but since we want to look both backward
;;;  and forward, we need these values repeated. (Section 4)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  slpClm12 = clmMonTLL( slp_file->slp(iclmStrt:iclmLast,:,:) )
  slpClma = array_append_record(clmMonTLL( slp_file->slp(iclmStrt:iclmLast,:,:) ),clmMonTLL( slp_file->slp(iclmStrt:iclmLast,:,:) ),0)
  slpClm = array_append_record(slpClma,clmMonTLL( slp_file->slp(iclmStrt:iclmLast,:,:) ),0)

  slpClm12b = clmMonTLL( slp_std(iclmStrt:iclmLast,:,:) )
  slpClmab = array_append_record(clmMonTLL( slp_std(iclmStrt:iclmLast,:,:) ),clmMonTLL( slp_std(iclmStrt:iclmLast,:,:) ),0)
  slpClmb = array_append_record(slpClmab,clmMonTLL( slp_std(iclmStrt:iclmLast,:,:) ),0)

  t2mClm12 = clmMonTLL( t2m_file->air(iclmStrt:iclmLast,:,:) )
  t2mClma = array_append_record(clmMonTLL( t2m_file->air(iclmStrt:iclmLast,:,:) ) ,clmMonTLL( t2m_file->air(iclmStrt:iclmLast,:,:) ),0)
  t2mClm = array_append_record(t2mClma ,clmMonTLL( t2m_file->air(iclmStrt:iclmLast,:,:) ),0)

  t2mClm12b = clmMonTLL( t2m_std(iclmStrt:iclmLast,:,:) )
  t2mClmab = array_append_record(clmMonTLL( t2m_std(iclmStrt:iclmLast,:,:) ) ,clmMonTLL( t2m_std(iclmStrt:iclmLast,:,:) ),0)
  t2mClmb = array_append_record(t2mClmab ,clmMonTLL( t2m_std(iclmStrt:iclmLast,:,:) ),0)

  t925Clm12 = clmMonTLL( t925_file->air(iclmStrt:iclmLast,templev,:,:) )
  t925Clma = array_append_record(clmMonTLL( t925_file->air(iclmStrt:iclmLast,templev,:,:) ) ,clmMonTLL( t925_file->air(iclmStrt:iclmLast,templev,:,:) ),0)
  t925Clm = array_append_record(t925Clma ,clmMonTLL( t925_file->air(iclmStrt:iclmLast,templev,:,:) ),0)

  t925Clm12b = clmMonTLL( t925_std(iclmStrt:iclmLast,:,:) )
  t925Clmab = array_append_record(clmMonTLL( t925_std(iclmStrt:iclmLast,:,:) ) ,clmMonTLL( t925_std(iclmStrt:iclmLast,:,:) ),0)
  t925Clmb = array_append_record(t925Clmab ,clmMonTLL( t925_std(iclmStrt:iclmLast,:,:) ),0)

  h500Clm12 = clmMonTLL( hgt_file->hgt(iclmStrt:iclmLast,heightlev,:,:) )
  h500Clma = array_append_record(clmMonTLL( hgt_file->hgt(iclmStrt:iclmLast,heightlev,:,:) ), clmMonTLL( hgt_file->hgt(iclmStrt:iclmLast,heightlev,:,:) ),0)
  h500Clm = array_append_record(h500Clma, clmMonTLL( hgt_file->hgt(iclmStrt:iclmLast,heightlev,:,:) ),0)

  h500Clm12b = clmMonTLL( h500_std(iclmStrt:iclmLast,:,:) )
  h500Clmab = array_append_record(clmMonTLL( h500_std(iclmStrt:iclmLast,:,:) ), clmMonTLL( h500_std(iclmStrt:iclmLast,:,:) ),0)
  h500Clmb = array_append_record(h500Clmab, clmMonTLL( h500_std(iclmStrt:iclmLast,:,:) ),0)

  sstClm12 = clmMonTLL( sst(iclmStrt:iclmLast,:,:) )
  sstClma = array_append_record(clmMonTLL( sst(iclmStrt:iclmLast,:,:) ),clmMonTLL( sst(iclmStrt:iclmLast,:,:) ),0)
  sstClm = array_append_record(sstClma,clmMonTLL( sst(iclmStrt:iclmLast,:,:) ),0)

  sstClm12b = clmMonTLL( sst_std(iclmStrt:iclmLast,:,:) )
  sstClmab = array_append_record(clmMonTLL( sst_std(iclmStrt:iclmLast,:,:) ),clmMonTLL( sst_std(iclmStrt:iclmLast,:,:) ),0)
  sstClmb = array_append_record(sstClmab,clmMonTLL( sst_std(iclmStrt:iclmLast,:,:) ),0)

;  if (variable.lt.6) then
;    iceClm12 = clmMonTLL( ice_file->icec(iclmStrt:iclmLast,:,:) )
;    iceClma = array_append_record(clmMonTLL( ice_file->icec(iclmStrt:iclmLast,:,:) ),clmMonTLL( ice_file->icec(iclmStrt:iclmLast,:,:) ),0)
;    iceClm = array_append_record(iceClma,clmMonTLL( ice_file->icec(iclmStrt:iclmLast,:,:) ),0)
;  end if
;  if (variable.eq.6) then
;    iceClm12 = clmMonTLL( ice_file->precip(iclmStrt:iclmLast,:,:) )
;    iceClma = array_append_record(clmMonTLL( ice_file->precip(iclmStrt:iclmLast,:,:) ),clmMonTLL( ice_file->precip(iclmStrt:iclmLast,:,:) ),0)
;    iceClm = array_append_record(iceClma,clmMonTLL( ice_file->precip(iclmStrt:iclmLast,:,:) ),0)
;  end if

  iceClm12 = clmMonTLL( icec(iclmStrt:iclmLast,:,:) )
  iceClma = array_append_record(clmMonTLL( icec(iclmStrt:iclmLast,:,:) ),clmMonTLL( icec(iclmStrt:iclmLast,:,:) ),0)
  iceClm = array_append_record(iceClma,clmMonTLL( icec(iclmStrt:iclmLast,:,:) ),0)

  iceClm12b = clmMonTLL( ice_std(iclmStrt:iclmLast,:,:) )
  iceClmab = array_append_record(clmMonTLL( ice_std(iclmStrt:iclmLast,:,:) ),clmMonTLL( ice_std(iclmStrt:iclmLast,:,:) ),0)
  iceClmb = array_append_record(iceClmab,clmMonTLL( ice_std(iclmStrt:iclmLast,:,:) ),0)

  oneVal = slpClm
  oneVal = (/ 0.0 /)








totalDims = theMaxDimsizes


totalDimsM1 = totalDims - 1     ; 818 with Mar 2016 data
totalDimsM2 = totalDims - 2     ; 817 with Mar 2016 data






  exmth = exmth - 1          ; subtract 1 so that it can be used in array indicies
  exmthlabel = exmth + 1     ; this is just a label for a print out
  d = fmnths+fmnths2
  monthRangeString1 = MonthStr1(usermonth-exmth,usermonth,useryear,2)
  monthRangeString2 = MonthStr1(usermonth+fmnths,usermonth+fmnths+fmnths2-1,useryear, 2)
  useryearString1 = useryear
  useryearString2 = useryear
  if ((usermonth+fmnths+fmnths2-1) .gt. 12) then
    useryearString2 = useryear + 1
  end if
  ;compare = 803+usermonth + fmnths + fmnths2 - 1    ; change 803 to 815 in 2016
  ;compare = 815+usermonth + fmnths + fmnths2 - 1    ; change 803 to 815 in 2016
  compare = 863+usermonth + fmnths + fmnths2 - 1    ; change 803 to 815 in 2016  ; change to 851 in 2019


; thetime variable is the index location of the month/year that the user entered
  thetime = ((useryear-1948) * 12) + usermonth - 1  ; as of Mar 2016, there are 819 months (0 to 818)

  AKstring = "CONUS" ; enter the name for the area (e.g., Alaska, Arctic, etc.)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end the user input section


  if (exmth.gt.0) then
    rngStr1 = month_Name(usermonth)+" "+useryear+" (incl prev "+exmth+" months)~C~Climatology: "+yrStrtClm+" to "+yrLastClm
    rngStr2 = "Analogs for " + month_Name(usermonth)+" "+useryear+" (incl prev "+exmth+" months)"
  end if

  if (exmth.eq.0) then
    rngStr1 = month_Name(usermonth)+" "+useryear+"~C~Climatology: "+yrStrtClm+" to "+yrLastClm
    rngStr2 = "Analogs for " + month_Name(usermonth)+" "+useryear
  end if


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end the section creating
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; monthly climate normal arrays


  lat_box = (/y2,  y1, y1, y2, y2/)
  lon_box = (/x1, x1,  x2, x2, x1/)
  boxStr = "Lat: "+y1+" to "+y2+" & Lon: "+x1+" to "+x2
  AKlat_box = (/AK2, AK2, AK1, AK1, AK2/)
  AKlon_box = (/AK4, AK3, AK3, AK4, AK4/)

;; below is most of the string to contain the output image filename
fname_pre = "Output_"+tostring(x1)+ "_"+tostring(y1) + "_"+tostring(x2) + "_"+tostring(y2)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end the section setting analysis
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; and comparison box coords.




;;;; *************** Create selection polygon.

  useshapefile = 55
  if (useshapefile.eq.99) then
    file_ak = ncargpath("data") + "/shp/AK_Box_Test.shp"
    shapename="Test Box"
    shapenameshort="Test_Box"

    opt = True
    opt@return_mask = True

    var = slp_std(0:,:,:)
    dimsizes_var = dimsizes(var)
    numlat = dimsizes_var(1)
    numlon = dimsizes_var(2)
    lonmidpoint = toint(numlon/2)
    varlats = var&lat
    varlons1 = var&lon
    varlons = varlons1 - 180


    data = new((/numlat,numlon/),integer)
    data!0 = "lat"
    data!1 = "lon"
    data&lat = varlats
    data&lon = varlons
    data@long_name = "Mask"
    data@_FillValue = -9999
    data = 1


    ak_mask = shapefile_mask_data(data,file_ak,opt)
    copy_VarMeta(data,ak_mask)

    varlons2 = where(varlons.lt.0,varlons+360,varlons)
    ak_mask&lon = varlons2

    ak_mask2 = where(ak_mask.eq.1,ak_mask,2)                      ;inside polygon has values = 1, outside = 2
    copy_VarMeta(ak_mask,ak_mask2)

    ak_mask3 = ak_mask2
    ak_mask3(:,0:lonmidpoint-1) = ak_mask2(:,lonmidpoint:numlon-1)
    ak_mask3(:,lonmidpoint:numlon-1) = ak_mask2(:,0:lonmidpoint-1)
    ak_mask3&lat@units = "degrees_north"
    ak_mask3&lon@units = "degrees_east"
    the_mask = ak_mask3


    x_sel = mask(var,the_mask,1)

    delete([/ak_mask,ak_mask2,ak_mask3,var,data/])

    delete(varlats)
    delete(varlons)
    delete(varlons1)
    delete(varlons2)

    Shaperes = True
    Shaperes = SetBoxRes("cyan")


    mytime = slp&time
    mylat = slp&lat
    mylon = slp&lon
    slp_sel = mask(slp_std,the_mask,1)
    t2m_sel = mask(t2m_std,the_mask,1)
    h500_sel = mask(h500_std,the_mask,1)
    t925_sel = mask(t925_std,the_mask,1)
    sst_sel = mask(sst_std,the_mask,1)

    slp_sel!0 = "time"
    slp_sel!1 = "lat"
    slp_sel!2 = "lon"

    t2m_sel!0 = "time"
    t2m_sel!1 = "lat"
    t2m_sel!2 = "lon"

    h500_sel!0 = "time"
    h500_sel!1 = "lat"
    h500_sel!2 = "lon"

    slp_sel!0 = "time"
    slp_sel!1 = "lat"
    slp_sel!2 = "lon"

    t925_sel!0 = "time"
    t925_sel!1 = "lat"
    t925_sel!2 = "lon"

    sst_sel!0 = "time"
    sst_sel!1 = "lat"
    sst_sel!2 = "lon"

    slp_sellat=mylat
    jjlat=cos((4.*atan(1.)/180.)*mylat)

    jjsizes = dimsizes(slp_sel)

  end if

;;;******************** end define Selection Polygon


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Now find the analogs. Uses the 'exmth' variable defined earlier
;;; to see how many months to look at. The average of the absolute
;;; values of the differences are computed for each month/year and the user
;;; selected month/year; e.g., if usermonth is July (7), useryear=1975, and
;;; exmonth is 1, find values for 6&7/48, 6&7/49, 6&7/50, through 6&7/2014. (Section 8)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




  YearArray = new(80,float)
  slpArray1 = new(80,float)
  slpArray2 = new(80,float)
  slpArray3 = new(80,float)
  slpArray3b = new(80,float)
  slpArray3c = new(80,float)
  slpArray4 = new(80,float)
  slpArray5 = new(80,float)
  h500Array1 = new(80,float)  ; all 1's are each yearly month minus usermonth
  h500Array2 = new(80,float)  ; all 2's are the actual yearly month values
  h500Array3 = new(80,float)  ; all 3's are each yearly month minus usermonth divided by std. dev. of annual averages
  h500Array3b = new(80,float) ; all 3b's are each yearly month minus usermonth divided by std. dev. of each point (using built-in function)
  h500Array3c = new(80,float) ; all 3b's are each yearly month minus usermonth divided by std. dev. of each point (using built-in function)
  h500Array4 = new(80,float)  ; all 4's are the same as 3b's
  h500Array5 = new(80,float)
  t2mArray1 = new(80,float)
  t2mArray2 = new(80,float)
  t2mArray3 = new(80,float)
  t2mArray3b = new(80,float)
  t2mArray3c = new(80,float)
  t2mArray4 = new(80,float)
  t2mArray5 = new(80,float)
  t925Array1 = new(80,float)
  t925Array2 = new(80,float)
  t925Array3 = new(80,float)
  t925Array3b = new(80,float)
  t925Array3c = new(80,float)
  t925Array4 = new(80,float)
  t925Array5 = new(80,float)
  sstArray1 = new(80,float)
  sstArray2 = new(80,float)
  sstArray3 = new(80,float)
  sstArray3b = new(80,float)
  sstArray3c = new(80,float)
  sstArray4 = new(80,float)
  sstArray5 = new(80,float)
  iceArray1 = new(80,float)
  iceArray2 = new(80,float)
  iceArray3 = new(80,float)
  iceArray3b = new(80,float)
  iceArray3c = new(80,float)
  iceArray4 = new(80,float)
  iceArray5 = new(80,float)
  weightedArray1 = new(80,float)
  weightedArraySpecial = new(80,float)
  slpArray1(0) = 9999.0
  h500Array1(0) = 9999.0
  t2mArray1(0) = 9999.0
  t925Array1(0) = 9999.0
  sstArray1(0) = 9999.0
  iceArray1(0) = 9999.0
  weightedArray1(0) = 9999.0
  weightedArraySpecial(0) = 9999.0
  slpRMSArray  = new(80,float)
  h500RMSArray  = new(80,float)
  t2mRMSArray  = new(80,float)
  t925RMSArray  = new(80,float)
  sstRMSArray  = new(80,float)
  iceRMSArray  = new(80,float)

  YearArray@_FillValue = 9999.0
  weightedArray1@_FillValue = 9999.0
  weightedArraySpecial@_FillValue = 9999.0
  slpArray3b@_FillValue = 9999.0
  h500Array3b@_FillValue=9999.0
  t925Array3b@_FillValue=9999.0
  t2mArray3b@_FillValue=9999.0
  sstArray3b@_FillValue=9999.0
  iceArray3b@_FillValue=9999.0
  slpArray3c@_FillValue = 9999.0
  h500Array3c@_FillValue=9999.0
  t925Array3c@_FillValue=9999.0
  t2mArray3c@_FillValue=9999.0
  sstArray3c@_FillValue=9999.0
  iceArray3c@_FillValue=9999.0




;; How many years do we look at? For example, if you are assessing
;; December 2015 data for a January 2016 projection, you can't use
;; the December 2015 data when looking at how past years have played
;; out.

fj = usermonth+fmnths+fmnths2-1

currentMonth2 = currentMonth + 12

if (fj.le.currentMonth) then
  NumAnalysisYears = currentYear - 1948
end if
if (fj.gt.currentMonth) then
  NumAnalysisYears = currentYear - 1948 - 1
end if
if (fj.gt.currentMonth .and.fj.le.currentMonth2) then
  NumAnalysisYears = currentYear - 1948 - 1
end if
if (fj.gt.currentMonth2) then
  NumAnalysisYears = currentYear - 1948 - 2
end if





;; 1's are raw values
;; 2's are SDs from normal
slpAnalysisBlue1 = new(NumAnalysisYears,float)
h500AnalysisBlue1 = new(NumAnalysisYears,float)
t2mAnalysisBlue1 = new(NumAnalysisYears,float)
t925AnalysisBlue1 = new(NumAnalysisYears,float)
sstAnalysisBlue1 = new(NumAnalysisYears,float)
iceAnalysisBlue1 = new(NumAnalysisYears,float)
slpAnalysisRed1 = new(NumAnalysisYears,float)
h500AnalysisRed1 = new(NumAnalysisYears,float)
t2mAnalysisRed1 = new(NumAnalysisYears,float)
t925AnalysisRed1 = new(NumAnalysisYears,float)
sstAnalysisRed1 = new(NumAnalysisYears,float)
iceAnalysisRed1 = new(NumAnalysisYears,float)
otherAnalysis1 = new(NumAnalysisYears,float)
pdoAnalysis1 = new(NumAnalysisYears,float)
npmAnalysis1 = new(NumAnalysisYears,float)
soiAnalysis1 = new(NumAnalysisYears,float)

slpAnalysisBlue2 = new(NumAnalysisYears,float)
h500AnalysisBlue2 = new(NumAnalysisYears,float)
t2mAnalysisBlue2 = new(NumAnalysisYears,float)
t925AnalysisBlue2 = new(NumAnalysisYears,float)
sstAnalysisBlue2 = new(NumAnalysisYears,float)
iceAnalysisBlue2 = new(NumAnalysisYears,float)
slpAnalysisRed2 = new(NumAnalysisYears,float)
h500AnalysisRed2 = new(NumAnalysisYears,float)
t2mAnalysisRed2 = new(NumAnalysisYears,float)
t925AnalysisRed2 = new(NumAnalysisYears,float)
sstAnalysisRed2 = new(NumAnalysisYears,float)
iceAnalysisRed2 = new(NumAnalysisYears,float)
weightedAnalysisBlue2 = new(NumAnalysisYears,float)
weightedAnalysisRed2 = new(NumAnalysisYears,float)

mySLPCorArray = slp(0:NumAnalysisYears-1,:,:)
myH500CorArray = h500(0:NumAnalysisYears-1,:,:)
myT2MCorArray = t2m(0:NumAnalysisYears-1,:,:)
myT925CorArray = t925(0:NumAnalysisYears-1,:,:)
mySSTCorArray = sst(0:NumAnalysisYears-1,:,:)
myICECorArray = icec(0:NumAnalysisYears-1,:,:)
mySLPCorArray@_FillValue = -9999
myH500CorArray@_FillValue = -9999
myT2MCorArray@_FillValue = -9999
myT925CorArray@_FillValue = -9999
mySSTCorArray@_FillValue = -9999
myICECorArray@_FillValue = -9999
mySLPCorArray(:,:,:) = mySLPCorArray@_FillValue
myH500CorArray(:,:,:) = myH500CorArray@_FillValue
myT2MCorArray(:,:,:) = myT2MCorArray@_FillValue
myT925CorArray(:,:,:) = myT925CorArray@_FillValue
mySSTCorArray(:,:,:) = mySSTCorArray@_FillValue
myICECorArray(:,:,:) = myICECorArray@_FillValue

myT2MCorArray_z = t2m(0:NumAnalysisYears-1,:,:)
myT2MCorArray_z@_FillValue = -9999
myT2MCorArray_z(:,:,:) = myT2MCorArray_z@_FillValue
myH500CorArray_z = h500(0:NumAnalysisYears-1,:,:)
myH500CorArray_z@_FillValue = -9999
myH500CorArray_z(:,:,:) = myH500CorArray_z@_FillValue
myT925CorArray_z = t925(0:NumAnalysisYears-1,:,:)
myT925CorArray_z@_FillValue = -9999
myT925CorArray_z(:,:,:) = myT925CorArray_z@_FillValue
mySLPCorArray_z = slp(0:NumAnalysisYears-1,:,:)
mySLPCorArray_z@_FillValue = -9999
mySLPCorArray_z(:,:,:) = mySLPCorArray_z@_FillValue
mySSTCorArray_z = sst(0:NumAnalysisYears-1,:,:)
mySSTCorArray_z@_FillValue = -9999
mySSTCorArray_z(:,:,:) = mySSTCorArray_z@_FillValue

myT2MCorArray_std = t2m;(0:NumAnalysisYears-1,:,:)
myT2MCorArray_std@_FillValue = -9999
myT2MCorArray_std(:,:,:) = myT2MCorArray_std@_FillValue
myH500CorArray_std = h500_std(0:NumAnalysisYears-1,:,:)
myH500CorArray_std@_FillValue = -9999
myH500CorArray_std(:,:,:) = myH500CorArray_std@_FillValue
myT925CorArray_std = t925_std(0:NumAnalysisYears-1,:,:)
myT925CorArray_std@_FillValue = -9999
myT925CorArray_std(:,:,:) = myT925CorArray_std@_FillValue
mySLPCorArray_std = slp_std(0:NumAnalysisYears-1,:,:)
mySLPCorArray_std@_FillValue = -9999
mySLPCorArray_std(:,:,:) = mySLPCorArray_std@_FillValue
mySSTCorArray_std = sst_std(0:NumAnalysisYears-1,:,:)
mySSTCorArray_std@_FillValue = -9999
mySSTCorArray_std(:,:,:) = mySSTCorArray_std@_FillValue


corArray1 = new(NumAnalysisYears,float)

yearArrayRedBlue = new(NumAnalysisYears,float)

;*******************************
;*******************************
;**  Special Array Info  *******
;*******************************
;*******************************
doSpecial = True
specialArray0 = new(80,float)
specialArray1 = new(80,float)
specialArray0@_FillValue = 9999.0
specialArray1@_FillValue = 9999.0

specialnum=11

if (specialnum.eq.1) then
  special_file =       data_dir + "/csv/nenana.csv"
  specialText = "Nenana Breakup Date"
end if

if (specialnum.eq.2) then
  special_file =       data_dir + "/csv/fairbanksm20.csv"
  specialText = "Fairbanks Days -20F"
end if

if (specialnum.eq.3) then
   special_file =       data_dir + "/csv/fairbanksdepth.csv"
  specialText = "Fairbanks Oct-Mar Snow Depth"
end if

if (specialnum.eq.4) then
  special_file =       data_dir + "/csv/eagleflow.csv"
  specialText = "Sept Flow of Yukon at Eagle"
end if

if (specialnum.eq.5) then
  special_file =       data_dir + "/csv/alaskadjftemps.csv"
  specialText = "Alaska Dec-Feb Temp"
end if

if (specialnum.eq.6) then
  special_file =       data_dir + "/csv/alaskadjfprecip.csv"
  specialText = "Alaska Dec-Feb Precip"
end if

if (specialnum.eq.7) then
  special_file =       data_dir + "/csv/anchoragesnow.csv"
  specialText = "Anchorage Seasonal Snowfall"
end if

if (specialnum.eq.8) then
  special_file =       data_dir + "/csv/beringicemaxdate.csv"
  specialText = "Bering Sea Max Ice Date"
end if

if (specialnum.eq.9) then
  special_file =       data_dir + "/csv/beringicemaxkm.csv"
  specialText = "Bering Sea Max Square KM"
end if

if (specialnum.eq.10) then
  special_file =       data_dir + "/csv/ace.csv"
  specialText = "Atlantic Tropical ACE"
end if

if (specialnum.eq.11) then
  special_file =       data_dir + "/csv/septicedepart.csv"
  specialText = "Sept Sea Ice Depat Trend"
end if



if (specialnum.eq.0) then
  special_file = output_dir+"/special_ascii.txt"
  ;specialText = "Lightning Strikes"
  ;specialText = "Sept Sea Ice Extent"
  specialText = "User-Specified Correlation"
end if

if (specialnum.eq.99) then
  special_file = output_dir+"/special_ascii.txt"   ; this is a dummy file that isn't actually used
  specialText = "User-Specified Correlation"
end if

special_lines       = asciiread(special_file,-1,"string")
special_numrows     = dimsizes(special_lines)
special_strs2       = str_split_csv (special_lines, ",", 0)

do ttt = 0, special_numrows-1
  specialArray0(ttt) = tofloat(special_strs2(ttt,0))
  specialArray1(ttt) = tofloat(special_strs2(ttt,1))
end do

specialAnalysis0 = new(NumAnalysisYears,float)
specialAnalysis1 = new(NumAnalysisYears,float)
specialAnalysis0@_FillValue = 9999.0
specialAnalysis1@_FillValue = 9999.0
asciiwrite (filedir+"specialname.txt" , specialText)
;*******************************
;*******************************

;; this do loop calculates raw values for the variables
do k = 0, NumAnalysisYears-1
  jk = (k*12) -1 + usermonth + 12 + fmnths + fmnths2 - 1
  ki = (k*12) + usermonth - 1 + 12
  m1 = ki-exmth
  m2=ki
  myYear = k+1949
  yearArrayRedBlue = myYear


  isx = isdefined("x")
  if (isx.eq.True)then
    delete(x)
  end if
  x=slp_std(ki-exmth:ki,{y1:y2},{x1:x2})
  y=slpClmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  xlat=x&lat
  clat=cos((4.*atan(1.)/180.)*xlat)

  aveval = 0.
  do kl = 0, exmth
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
    ;aveval = aveval + pattern_cor(x(kl,:,:), y(kl,:,:), clat, 0)
  end do
  slpAnalysisBlue1(k) = aveval / (exmth + 1) / 1.0
  mySLPCorArray(k,:,:) = dim_avg_n_Wrap(slp(ki-exmth:ki,:,:),0)
  mySLPCorArray_z(k,:,:) = dim_avg_n_Wrap(slp(ki+fmnths:ki+fmnths+fmnths2-1,:,:),0)

  x=h500_std(ki-exmth:ki,{y1:y2},{x1:x2})
  y=h500Clmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  aveval = 0.
  do kl = 0, exmth
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  h500AnalysisBlue1(k) = aveval / (exmth + 1) / 1.0
  myH500CorArray(k,:,:) = dim_avg_n_Wrap(h500(ki-exmth:ki,:,:),0)
  myH500CorArray_z(k,:,:) = dim_avg_n_Wrap(h500(ki+fmnths:ki+fmnths+fmnths2-1,:,:),0)

  x=t2m_std(ki-exmth:ki,{y1:y2},{x1:x2})
  y=t2mClmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  aveval = 0.
  do kl = 0, exmth
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  t2mAnalysisBlue1(k) = aveval / (exmth + 1) / 1.0
  myT2MCorArray(k,:,:) = dim_avg_n_Wrap(t2m(ki-exmth:ki,:,:),0)
  myT2MCorArray_z(k,:,:) = dim_avg_n_Wrap(t2m(ki+fmnths:ki+fmnths+fmnths2-1,:,:),0)

  x=t925_std(ki-exmth:ki,{y1:y2},{x1:x2})
  y=t925Clmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  aveval = 0.
  do kl = 0, exmth
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  t925AnalysisBlue1(k) = aveval / (exmth + 1) / 1.0
  myT925CorArray(k,:,:) = dim_avg_n_Wrap(t925(ki-exmth:ki,:,:),0)
  myT925CorArray_z(k,:,:) = dim_avg_n_Wrap(t925(ki+fmnths:ki+fmnths+fmnths2-1,:,:),0)



  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)
  x=sst_std(ki-exmth:ki,{y1:y2},{x1:x2})
  y=sstClmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  xlat=x&lat
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do kl = 0, exmth
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  sstAnalysisBlue1(k) = aveval / (exmth + 1) / 1.0
  mySSTCorArray(k,:,:) = dim_avg_n_Wrap(sst(ki-exmth:ki,:,:),0)


  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)
  if (variable.lt.6) then
    x=ice_std(ki-exmth:ki,{60:90},{0:360})
    y=iceClmb(usermonth+12-1-exmth:usermonth+12-1,{60:90},{0:360})
  end if
  if (variable.eq.6) then
    x=ice_std(ki-exmth:ki,{y1:y2},{x1:x2})
    y=iceClmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  end if
  xlat=x&lat
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do kl = 0, exmth
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  iceAnalysisBlue1(k) = aveval / (exmth + 1) / 1.0
  myICECorArray(k,:,:) = dim_avg_n_Wrap(icec(ki-exmth:ki,:,:),0)
  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)




;*****

  x=slp_std(ki+fmnths:ki+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=slpClmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do kl = 0, fmnths2-1
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  slpAnalysisRed1(k) = aveval / (fmnths2-1 + 1) / 1.0

  x=h500_std(ki+fmnths:ki+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=h500Clmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  aveval = 0.
  do kl = 0, fmnths2-1
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  h500AnalysisRed1(k) = aveval / (fmnths2-1 + 1) / 1.0

  x=t2m_std(ki+fmnths:ki+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=t2mClmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  aveval = 0.
  do kl = 0, fmnths2-1
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  t2mAnalysisRed1(k) = aveval / (fmnths2-1 + 1) / 1.0

  x=t925_std(ki+fmnths:ki+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=t925Clmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  aveval = 0.
  do kl = 0, fmnths2-1
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  t925AnalysisRed1(k) = aveval / (fmnths2-1 + 1) / 1.0

  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)
  x=sst_std(ki+fmnths:ki+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=sstClmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do kl = 0, fmnths2-1
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  sstAnalysisRed1(k) = aveval / (fmnths2-1 + 1) / 1.0

  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)
  if (variable.lt.6) then
    x=ice_std(ki+fmnths:ki+fmnths+fmnths2-1,{60:90},{0:360})
    y=iceClmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{60:90},{0:360})
  end if
  if (variable.eq.6) then
    x=ice_std(ki+fmnths:ki+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
    y=iceClmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  end if
  xlat=x&lat
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do kl = 0, fmnths2-1
    aveval = aveval + wgt_areaave(x(kl,:,:),clat,1.0,0); - wgt_areaave(y(kl,:,:),clat,1.0,0)
  end do
  iceAnalysisRed1(k) = aveval / (fmnths2-1 + 1) / 1.0
  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)

  specialAnalysis0(k) = specialArray0(k+1)
  specialAnalysis1(k) = specialArray1(k+1)
end do


;******************************************************************
; The next ~125 lines is for making correlation plots
; TODO -- Rick said that both he and Brian found this
; code to not be useful (they only use the case where
; justcorrelations === 3), maybe delete as experimental.
if (justcorrelations.ge.1.and.justcorrelations.le.2) then
  wtypebig1           = "png"
  wtypebig1@wkWidth  = 1400
  wtypebig1@wkHeight = 1400
  wtypebig2           = "png"
  wtypebig2@wkWidth  = 1400
  wtypebig2@wkHeight = 1400
  wks_cor1 = gsn_open_wks(wtypebig1,filedir+"cor_big1")
  wks_cor2 = gsn_open_wks(wtypebig2,filedir+"cor_big2")
  if(justcorrelations.eq.1) then
    rescor1 = SetRes3(0.2,1,"sig")
    rescor2 = SetRes3(0.2,1,"sig")
  end if
  if(justcorrelations.eq.2) then
    rescor1 = SetRes4(0.2)
    rescor2 = SetRes4(0.2)
  end if
  if (variable.eq.1) then
    rcor1  = escorc(mySLPCorArray(lat|:,lon|:,time|:),myT2MCorArray(lat|:,lon|:,time|:))
    rcor2  = escorc(mySLPCorArray(lat|:,lon|:,time|:),myT2MCorArray_z(lat|:,lon|:,time|:))
    copy_VarCoords(slp(0,:,:), rcor1)
    copy_VarMeta(slp(0,:,:), rcor1)
    copy_VarCoords(slp(0,:,:), rcor2)
    copy_VarMeta(slp(0,:,:), rcor2)
    rescor1@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" SLP~C~And "+monthRangeString1+" 2-M Temps (Pearson's R)"
    rescor2@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" SLP~C~And "+monthRangeString2+" 2-M Temps (Pearson's R)"
    if (detrend.eq.1)
      rescor1@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" SLP~C~And "+monthRangeString1+" 2-M Temps (Pearson's R*)"
      rescor2@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" SLP~C~And "+monthRangeString2+" 2-M Temps (Pearson's R*)"
    end if
  end if
  if (variable.eq.2) then
    rcor1  = escorc(myH500CorArray(lat|:,lon|:,time|:),myT2MCorArray(lat|:,lon|:,time|:))
    rcor2  = escorc(myH500CorArray(lat|:,lon|:,time|:),myT2MCorArray_z(lat|:,lon|:,time|:))
    copy_VarCoords(h500(0,:,:), rcor1)
    copy_VarMeta(h500(0,:,:), rcor1)
    copy_VarCoords(h500(0,:,:), rcor2)
    copy_VarMeta(h500(0,:,:), rcor2)
    rescor1@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Z"+getlev(heightlev)+" Heights~C~And "+monthRangeString1+" 2-M Temps (Pearson's R)"
    rescor2@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Z"+getlev(heightlev)+" Heights~C~And "+monthRangeString2+" 2-M Temps (Pearson's R)"
    if (detrend.eq.1)
      rescor1@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Z"+getlev(heightlev)+" Heights~C~And "+monthRangeString1+" 2-M Temps (Pearson's R*)"
      rescor2@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Z"+getlev(heightlev)+" Heights~C~And "+monthRangeString2+" 2-M Temps (Pearson's R*)"
    end if
  end if
  if (variable.eq.3) then
    rcor1  = escorc(myT2MCorArray(lat|:,lon|:,time|:),myT2MCorArray(lat|:,lon|:,time|:))
    rcor2  = escorc(myT2MCorArray(lat|:,lon|:,time|:),myT2MCorArray_z(lat|:,lon|:,time|:))
    copy_VarCoords(t2m(0,:,:), rcor1)
    copy_VarMeta(t2m(0,:,:), rcor1)
    copy_VarCoords(t2m(0,:,:), rcor2)
    copy_VarMeta(t2m(0,:,:), rcor2)
    rescor1@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Temps~C~And "+monthRangeString1+" 2-M Temps (Pearson's R)"
    rescor2@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Temps~C~And "+monthRangeString2+" 2-M Temps (Pearson's R)"
    if (detrend.eq.1)
      rescor1@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Temps~C~And "+monthRangeString1+" 2-M Temps (Pearson's R*)"
      rescor2@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Temps~C~And "+monthRangeString2+" 2-M Temps (Pearson's R*)"
    end if
  end if
  if (variable.eq.4) then
    rcor1  = escorc(myT925CorArray(lat|:,lon|:,time|:),myT2MCorArray(lat|:,lon|:,time|:))
    rcor2  = escorc(myT925CorArray(lat|:,lon|:,time|:),myT2MCorArray_z(lat|:,lon|:,time|:))
    copy_VarCoords(t925(0,:,:), rcor1)
    copy_VarMeta(t925(0,:,:), rcor1)
    copy_VarCoords(t925(0,:,:), rcor2)
    copy_VarMeta(t925(0,:,:), rcor2)
    rescor1@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Z"+getlev(templev)+" Temps~C~And "+monthRangeString1+" 2-M Temps (Pearson's R)"
    rescor2@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Z"+getlev(templev)+" Temps~C~And "+monthRangeString2+" 2-M Temps (Pearson's R)"
    if (detrend.eq.1)
      rescor1@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Z"+getlev(templev)+" Temps~C~And "+monthRangeString1+" 2-M Temps (Pearson's R*)"
      rescor2@tiXAxisString = "Correlation Sig. of "+monthRangeString1+" Z"+getlev(templev)+" Temps~C~And "+monthRangeString2+" 2-M Temps (Pearson's R*)"
    end if
  end if


  if(justcorrelations.eq.2) then
    rcor3 = (/ rcor1 * rcor1 /)
    rcor4 = (/ rcor2 * rcor2 /)
    copy_VarCoords(rcor1, rcor3)
    copy_VarMeta(rcor1, rcor3)
    copy_VarCoords(rcor2, rcor4)
    copy_VarMeta(rcor2, rcor4)
    delete(rcor1)
    delete(rcor2)
    rcor1 = rcor3
    rcor2 = rcor4
    delete(rcor3)
    delete(rcor4)
  end if

  if (variable.le.4) then
    rcor1({88},{150}) = 1.0
    rcor2({88},{150}) = 1.0
    rcor1({-88},{150}) = -1.0
    rcor2({-88},{150}) = -1.0
    if(justcorrelations.eq.2)
      rcor1({-88},{150}) = 0.0
      rcor2({-88},{150}) = 0.0
    end if
    rcor1@long_name = " "
    rcor1@short_name = " "
    rcor1@units = " "
    rcor2@long_name = " "
    rcor2@short_name = " "
    rcor2@units = " "
    rescor1@tiMainFontHeightF  = 0.012
    rescor1@lbTitleFontHeightF= .012
    rescor1@lbLabelFontHeightF= .01
    rescor2@tiMainFontHeightF  = 0.012
    rescor2@lbTitleFontHeightF= .012
    rescor2@lbLabelFontHeightF= .01
    plot90 = gsn_csm_contour_map_polar(wks_cor1,rcor1,rescor1)
    draw(plot90)
    frame(wks_cor1)
    delete(wks_cor1)
    delete(rcor1)
    delete(rescor1)
    delete(plot90)
    zz = systemfunc("mv -f "+filedir+"cor_big1.png "+output_dir+"/cor_big1_a.png")
    zz = systemfunc("convert "+output_dir+"/cor_big1_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/cor_big1.jpg")
    zz = systemfunc("rm -f "+output_dir+"/cor_big1_a.png")

    plot90 = gsn_csm_contour_map_polar(wks_cor2,rcor2,rescor2)
    draw(plot90)
    frame(wks_cor2)
    delete(wks_cor2)
    delete(rcor2)
    delete(rescor2)
    delete(plot90)
    zz = systemfunc("mv -f "+filedir+"cor_big2.png "+output_dir+"/cor_big2_a.png")
    zz = systemfunc("convert "+output_dir+"/cor_big2_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/cor_big2.jpg")
    zz = systemfunc("rm -f "+output_dir+"/cor_big2_a.png")
  end if

  ; TODO -- we may need to adapt the GUI so the
  ; correlation plots only take the minimum
  ; inputs required for that workflow.
  print("It appears that you only wanted to make a few correlation plots. Here they are:")
  print("")
  exit

end if



;;&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

; check to see if there are missing values in SST and ICEC
cr1 = yrStrtClm-yrStrt-1
cr2 = yrLastClm-yrStrt-1

sb1 = 0
sr1 = 0
do df = cr1, cr2
  if(.not.ismissing(sstAnalysisBlue1(df))) then
    sb1 = sb1 + 1
  end if
  if(.not.ismissing(sstAnalysisRed1(df))) then
    sr1 = sr1 + 1
  end if
end do

ib1 = 0
ir1 = 0
do df = cr1, cr2
  if(.not.ismissing(sstAnalysisBlue1(df))) then
    ib1 = ib1 + 1
  end if
  if(.not.ismissing(sstAnalysisRed1(df))) then
    ir1 = ir1 + 1
  end if
end do
; ****************************


slp_blue_ave_sd = stddev(slpAnalysisBlue1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
h500_blue_ave_sd = stddev(h500AnalysisBlue1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
t2m_blue_ave_sd = stddev(t2mAnalysisBlue1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
t925_blue_ave_sd = stddev(t925AnalysisBlue1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
ice_blue_ave_sd = stddev(iceAnalysisBlue1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))

if (sb1.gt.0) then
  sst_blue_ave_sd = stddev(sstAnalysisBlue1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
end if
if (sb1.eq.0) then
  sst_blue_ave_sd = 1
end if

slp_red_ave_sd = stddev(slpAnalysisRed1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
h500_red_ave_sd = stddev(h500AnalysisRed1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
t2m_red_ave_sd = stddev(t2mAnalysisRed1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
t925_red_ave_sd = stddev(t925AnalysisRed1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
ice_red_ave_sd = stddev(iceAnalysisRed1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))

if (sr1.gt.0) then
  sst_red_ave_sd = stddev(sstAnalysisRed1(yrStrtClm-yrStrt-1:yrLastClm-yrStrt-1))
end if
if (sr1.eq.0) then
  sst_red_ave_sd = 1
end if



;; this do loop calculates average std. devs from normal for each
;; point and squares the (actual value - normal value) / std.dev .
do m = 0, NumAnalysisYears-1
  mi = (m*12) + usermonth - 1 + 12
  m1 = mi-exmth
  m2 = mi
  x=slp_std(mi-exmth:mi,{y1:y2},{x1:x2})
  xlat=x&lat
  ;y=slpClmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  y=oneVal(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, exmth
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  slpAnalysisBlue2(m) = aveval / (exmth + 1) / 1.0
  mySLPCorArray(m,:,:) = dim_avg_n_Wrap(slp(mi-exmth:mi,:,:),0)

  x=h500_std(mi-exmth:mi,{y1:y2},{x1:x2})
  ;y=h500Clmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  y=oneVal(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  aveval = 0.
  do ml = 0, exmth
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  h500AnalysisBlue2(m) = aveval / (exmth + 1) / 1.0
  myH500CorArray(m,:,:) = dim_avg_n_Wrap(h500(mi-exmth:mi,:,:),0)

  x=t2m_std(mi-exmth:mi,{y1:y2},{x1:x2})
  ;y=t2mClmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  y=oneVal(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  aveval = 0.
  do ml = 0, exmth
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  t2mAnalysisBlue2(m) = aveval / (exmth + 1) / 1.0
  myT2MCorArray(m,:,:) = dim_avg_n_Wrap(t2m(mi-exmth:mi,:,:),0)

  x=t925_std(mi-exmth:mi,{y1:y2},{x1:x2})
  ;y=t925Clmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  y=oneVal(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  aveval = 0.
  do ml = 0, exmth
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  t925AnalysisBlue2(m) = aveval / (exmth + 1) / 1.0
  myT925CorArray(m,:,:) = dim_avg_n_Wrap(t925(mi-exmth:mi,:,:),0)

  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)
  x=sst_std(mi-exmth:mi,{y1:y2},{x1:x2})
  xlat=x&lat
  ;y=sstClmb(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  y=oneVal(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, exmth
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  sstAnalysisBlue2(m) = aveval / (exmth + 1) / 1.0
  mySSTCorArray(m,:,:) = dim_avg_n_Wrap(sst(mi-exmth:mi,:,:),0)

  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)
  if (variable.lt.6) then
    x=icec(mi-exmth:mi,{60:90},{0:360})
    y=iceClm(usermonth+12-1-exmth:usermonth+12-1,{60:90},{0:360})
  end if
  if (variable.eq.6) then
    x=icec(mi-exmth:mi,{y1:y2},{x1:x2})
    ;y=iceClm(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
    y=oneVal(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
  end if
  xlat=x&lat
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, exmth
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  iceAnalysisBlue2(m) = aveval / (exmth + 1) / 1.0
  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)


  abc = mi+fmnths
  abcd = mi+fmnths+fmnths2-1
  abcd2 = fmnths+fmnths2-1-1
  abcde = dimsizes(slp&time) - 1



  x=slp_std(mi+fmnths:mi+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  ;y=slpClmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=oneVal(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, fmnths2-1
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  slpAnalysisRed2(m) = aveval / (fmnths2) / 1.0

  x=h500_std(mi+fmnths:mi+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
;  y=h500Clmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=oneVal(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, fmnths2-1
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  h500AnalysisRed2(m) = aveval / (fmnths2) / 1.0

  x=t2m_std(mi+fmnths:mi+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  ;y=t2mClmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=oneVal(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, fmnths2-1
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  t2mAnalysisRed2(m) = aveval / (fmnths2) / 1.0

  x=t925_std(mi+fmnths:mi+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  ;y=t925Clmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=oneVal(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, fmnths2-1
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  t925AnalysisRed2(m) = aveval / (fmnths2) / 1.0

  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)
  x=sst_std(mi+fmnths:mi+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  ;y=sstClmb(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  y=oneVal(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, fmnths2-1
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  sstAnalysisRed2(m) = aveval / (fmnths2) / 1.0

  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)
  if (variable.lt.6) then
    x=icec(mi+fmnths:mi+fmnths+fmnths2-1,{60:90},{0:360})
    y=iceClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{60:90},{0:360})
  end if
  if (variable.eq.6) then
    x=icec(mi+fmnths:mi+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
    ;y=iceClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
    y=oneVal(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
  end if
  xlat=x&lat
  clat=cos((4.*atan(1.)/180.)*xlat)
  aveval = 0.
  do ml = 0, fmnths2-1
    aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
  end do
  iceAnalysisRed2(m) = aveval / (fmnths2) / 1.0
  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)

end do




if (variable.eq.1) then
  dependentVar1 = slpAnalysisRed1
  dependentVar2 = slpAnalysisRed2
end if
if (variable.eq.2) then
  dependentVar1 = h500AnalysisRed1
  dependentVar2 = h500AnalysisRed2
end if
if (variable.eq.3) then
  dependentVar1 = t2mAnalysisRed1
  dependentVar2 = t2mAnalysisRed2
end if
if (variable.eq.4) then
  dependentVar1 = t925AnalysisRed1
  dependentVar2 = t925AnalysisRed2
end if
if (variable.eq.5) then
  dependentVar1 = sstAnalysisRed1
  dependentVar2 = sstAnalysisRed2
end if
if (variable.eq.6) then
  dependentVar1 = iceAnalysisRed1
  dependentVar2 = iceAnalysisRed2
end if


  xx1 = new(NumAnalysisYears,float)
  xx2 = new(NumAnalysisYears,float)
  xx3 = new(NumAnalysisYears,float)
  xx4 = new(NumAnalysisYears,float)
  xx5 = new(NumAnalysisYears,float)
  xx6 = new(NumAnalysisYears,float)


  useStandardized = 1            ; 1=standardized anomalies   2=raw anomalies


  if (useStandardized.eq.0) then
  ; Blue2 and dependentVar2 use RMSE values from climatology of standardardized anomalies
    xx1 = slpAnalysisBlue2
    xx2 = h500AnalysisBlue2
    xx3 = t2mAnalysisBlue2
    xx4 = t925AnalysisBlue2
    xx5 = sstAnalysisBlue2
    xx6 = iceAnalysisBlue2
    ydep = dependentVar2
  end if

  if (useStandardized.eq.1) then
  ; Blue1 and dependentVar1 use average values from climatology of standardardized anomalies
    xx1 = slpAnalysisBlue1
    xx2 = h500AnalysisBlue1
    xx3 = t2mAnalysisBlue1
    xx4 = t925AnalysisBlue1
    xx5 = sstAnalysisBlue1
    xx6 = iceAnalysisBlue1
    ydep = dependentVar1
  end if


N = dimsizes(ydep)

  M=5  ; this used to be 8 but was dropped to 5 to remove indicies from regression
  X = new ((/M+1,N/),"float")
  X(0,:) = 1.0
  X(1,:) = xx1
  X(2,:) = xx2
  X(3,:) = xx3
  X(4,:) = xx4
  X(5,:) = xx5
  ;X(6,:) = xx6

  beta = reg_multlin(ydep,X,False)

  opt=True

  nrow = dimsizes(ydep)
  np   = 5
  if (xx5(50).eq.tofloat(0.0)) then
    np   = 4
  end if
  xp   = new( (/nrow,np/), typeof(xx1))  ; create an array to hold predictor variables
  xp(:,0) = X(1,:)
  xp(:,1) = X(2,:)
  xp(:,2) = X(3,:)
  xp(:,3) = X(4,:)
  if (np.eq.5) then
    xp(:,4) = X(5,:)
  end if



  opt=True

  if (txtareayesno.eq.2) then
    beta2 = reg_multlin_stats(ydep,xp,opt)
  end if
  if (txtareayesno.lt.2) then
    ydep = specialAnalysis1
    beta2 = reg_multlin_with_missing(ydep,xp,opt)
  end if

delete(xp)
betaMultRcor = beta2@r
betaMultR2cor = beta2@r2

intercept  = beta(0)

if (autoWgt.eq.1) then
  if(beta(1).gt.0)then
    slpwgt  = beta(1)
  end if
  if(beta(2).gt.0)then
    h500wgt  = beta(2)
  end if
  if(beta(3).gt.0)then
    t2mwgt  = beta(3)
  end if
  if(beta(4).gt.0)then
    t925wgt  = beta(4)
  end if
  if (np.eq.5) then
    if(beta(5).gt.0)then
      sstwgt  = beta(5)
    end if
  end if

  if(beta(1).le.0)then
    slpwgt  = 0.0
  end if
  if(beta(2).le.0)then
    h500wgt  = 0.0
  end if
  if(beta(3).le.0)then
    t2mwgt  = 0.0
  end if
  if(beta(4).le.0)then
    t925wgt  = 0.0
  end if
  if (np.eq.5) then
    if(beta(5).le.0)then
      sstwgt  = 0.0
    end if
  end if

  slpwgt  = beta(1)
  h500wgt = beta(2)
  t2mwgt  = beta(3)
  t925wgt = beta(4)
  if (np.eq.5) then
    sstwgt  = beta(5)
  end if
  if (np.ne.5) then
    sstwgt = 0.0
  end if
end if



if(.not.ismissing(sstAnalysisBlue2(17))) then
  do u = 0, NumAnalysisYears-1
    ui = (u*12) + usermonth - 1 + 12
    weightedAnalysisBlue2(u) = (slpAnalysisBlue2(u) * tofloat(slpwgt)) + (h500AnalysisBlue2(u) * tofloat(h500wgt)) + (t2mAnalysisBlue2(u) * tofloat(t2mwgt)) + (t925AnalysisBlue2(u) * tofloat(t925wgt))  + (sstAnalysisBlue2(u) * tofloat(sstwgt))
    weightedAnalysisRed2(u) = (slpAnalysisRed2(u) * tofloat(slpwgt)) + (h500AnalysisRed2(u) * tofloat(h500wgt)) + (t2mAnalysisRed2(u) * tofloat(t2mwgt)) + (t925AnalysisRed2(u) * tofloat(t925wgt))  + (sstAnalysisRed2(u) * tofloat(sstwgt))
    corArray1(u) = (slpAnalysisRed1(u) * tofloat(slpwgt)) + (h500AnalysisRed1(u) * tofloat(h500wgt)) + (t2mAnalysisRed1(u) * tofloat(t2mwgt)) + (t925AnalysisRed1(u) * tofloat(t925wgt))  + (sstAnalysisRed1(u) * tofloat(sstwgt))
    weightedAnalysisBlue2(u) = (slpAnalysisBlue2(u) * tofloat(slpwgt)) + (h500AnalysisBlue2(u) * tofloat(h500wgt)) + (t2mAnalysisBlue2(u) * tofloat(t2mwgt)) + (t925AnalysisBlue2(u) * tofloat(t925wgt))  + (sstAnalysisBlue2(u) * tofloat(sstwgt))
    weightedAnalysisRed2(u) = (slpAnalysisRed2(u) * tofloat(slpwgt)) + (h500AnalysisRed2(u) * tofloat(h500wgt)) + (t2mAnalysisRed2(u) * tofloat(t2mwgt)) + (t925AnalysisRed2(u) * tofloat(t925wgt))  + (sstAnalysisRed2(u) * tofloat(sstwgt))
    corArray1(u) = (slpAnalysisRed1(u) * tofloat(slpwgt)) + (h500AnalysisRed1(u) * tofloat(h500wgt)) + (t2mAnalysisRed1(u) * tofloat(t2mwgt)) + (t925AnalysisRed1(u) * tofloat(t925wgt))  + (sstAnalysisRed1(u) * tofloat(sstwgt))
  end do
end if

if(ismissing(sstAnalysisBlue2(17))) then
  do u = 0, NumAnalysisYears-1
    ui = (u*12) + usermonth - 1 + 12
    weightedAnalysisBlue2(u) = (slpAnalysisBlue2(u) * tofloat(slpwgt)) + (h500AnalysisBlue2(u) * tofloat(h500wgt)) + (t2mAnalysisBlue2(u) * tofloat(t2mwgt)) + (t925AnalysisBlue2(u) * tofloat(t925wgt))
    weightedAnalysisRed2(u) = (slpAnalysisRed2(u) * tofloat(slpwgt)) + (h500AnalysisRed2(u) * tofloat(h500wgt)) + (t2mAnalysisRed2(u) * tofloat(t2mwgt)) + (t925AnalysisRed2(u) * tofloat(t925wgt))
    corArray1(u) = (slpAnalysisRed1(u) * tofloat(slpwgt)) + (h500AnalysisRed1(u) * tofloat(h500wgt)) + (t2mAnalysisRed1(u) * tofloat(t2mwgt)) + (t925AnalysisRed1(u) * tofloat(t925wgt))
  end do
end if

templevelORrh = " T"+getlev(templev)

weightString = "Analog Years Based on Weighting-->~C~"+"SLP:"+sprintf("%6.2f",slpwgt)+" Z"+getlev(heightlev)+":"+sprintf("%6.2f",h500wgt)+" T2M:"+sprintf("%6.2f",t2mwgt)+templevelORrh+":"+sprintf("%6.2f",t925wgt)+" ~C~SST:"+sprintf("%6.2f",sstwgt)+", "+" "
weightString2 = "SLP:"+sprintf("%6.2f",slpwgt)+" Z"+getlev(heightlev)+":"+sprintf("%6.2f",h500wgt)+" T2M:"+sprintf("%6.2f",t2mwgt)+templevelORrh+":"+sprintf("%6.2f",t925wgt)+" ~C~SST:"+sprintf("%6.2f",sstwgt)+" "


  if (variable .eq. 1) then
    varName = "SLP"
  end if
  if (variable .eq. 2) then
    varName = "H500"
    varName = "Z"+getlev(heightlev)
  end if
  if (variable .eq. 3) then
    varName = "T2M"
  end if
  if (variable .eq. 4) then
    varName = "T925"
    varName = "T"+getlev(templev)
  end if
  if (variable .eq. 5) then
    varName = "SST"
  end if
  if (variable .eq. 6) then
    varName = "Precip"
  end if






  asciiwrite (filedir+"var.txt" , varName)
  zz = systemfunc("mv -f "+filedir+"var.txt "+output_dir+"/var.txt")
  asciiwrite (filedir+"useryear1.txt" , useryearString1)
  zz = systemfunc("mv -f "+filedir+"useryear1.txt "+output_dir+"/useryear1.txt")
  asciiwrite (filedir+"useryear2.txt" , useryearString2)
  zz = systemfunc("mv -f "+filedir+"useryear2.txt "+output_dir+"/useryear2.txt")
  asciiwrite (filedir+"mtext1.txt" , monthRangeString1)
  zz = systemfunc("mv -f "+filedir+"mtext1.txt "+output_dir+"/mtext1.txt")
  asciiwrite (filedir+"mtext2.txt" , monthRangeString2)
  zz = systemfunc("mv -f "+filedir+"mtext2.txt "+output_dir+"/mtext2.txt")
  monyear1 = monthRangeString1 + " " + useryearString1
  asciiwrite (filedir+"my1.txt" , monyear1)
  zz = systemfunc("mv -f "+filedir+"my1.txt "+output_dir+"/my1.txt")
  monyear2 = monthRangeString2 + " " + useryearString2
  asciiwrite (filedir+"my2.txt" , monyear2)
  zz = systemfunc("mv -f "+filedir+"my2.txt "+output_dir+"/my2.txt")
  text1 = varName+" Forecast for Lat: "+AK1+" to "+AK2+" & Lon: "+AK3+" to "+AK4
  asciiwrite (filedir+"text1.txt" , text1)
  zz = systemfunc("mv -f "+filedir+"text1.txt "+output_dir+"/text1.txt")
  text1a = "Using Analysis Area Lat: "+y1+" to "+y2+" & Lon: "+x1+" to "+x2
  asciiwrite (filedir+"text1a.txt" , text1a)
  zz = systemfunc("mv -f "+filedir+"text1a.txt "+output_dir+"/text1a.txt")
  asciiwrite (filedir+"compstr.txt" , " ")
  zz = systemfunc("mv -f "+filedir+"compstr.txt "+output_dir+"/compstr.txt")
  cortext1 = "Correlations During "+monthRangeString1+" With "+monthRangeString2+" Values"
  asciiwrite (filedir+"cortext1.txt" , cortext1)
  zz = systemfunc("mv -f "+filedir+"cortext1.txt "+output_dir+"/cortext1.txt")
  cortext2 = "of "+varName+" Within Box Bounded by"
  asciiwrite (filedir+"cortext2.txt" , cortext2)
  zz = systemfunc("mv -f "+filedir+"cortext2.txt "+output_dir+"/cortext2.txt")
  cortext3 = "Lat: "+AK1+" to "+AK2+" & Lon: "+AK3+" to "+AK4
  asciiwrite (filedir+"cortext3.txt" , cortext3)
  zz = systemfunc("mv -f "+filedir+"cortext3.txt "+output_dir+"/cortext3.txt")
  tlevel = "T"+getlev(templev)
  asciiwrite (filedir+"tlevel.txt" , tlevel)
  zz = systemfunc("mv -f "+filedir+"tlevel.txt "+output_dir+"/tlevel.txt")
  zlevel = "Z"+getlev(heightlev)
  asciiwrite (filedir+"zlevel.txt" , zlevel)
  zz = systemfunc("mv -f "+filedir+"zlevel.txt "+output_dir+"/zlevel.txt")
  redbox = "Lat: "+AK1+" to "+AK2+" & Lon: "+AK3+" to "+AK4
  asciiwrite (filedir+"redbox.txt" , redbox)
  zz = systemfunc("mv -f "+filedir+"redbox.txt "+output_dir+"/redbox.txt")

  if (txtareayesno.lt.2) then    ; special values
    cortext1 = "Correlations During "+monthRangeString1+" With"
    asciiwrite (filedir+"cortext1.txt" , cortext1)
    zz = systemfunc("mv -f "+filedir+"cortext1.txt "+output_dir+"/cortext1.txt")
    cortext2 = "a User-Defined Time Series"
    asciiwrite (filedir+"cortext2.txt" , cortext2)
    zz = systemfunc("mv -f "+filedir+"cortext2.txt "+output_dir+"/cortext2.txt")
    cortext3 = "(Obtain Time Series From User)"
    asciiwrite (filedir+"cortext3.txt" , cortext3)
    zz = systemfunc("mv -f "+filedir+"cortext3.txt "+output_dir+"/cortext3.txt")
  end if








;;&&&&&&&&&&&&&&&&&

doMultR = True
if (justcorrelations.eq.3) then

  opt = True
  multRcor = slp(0:12,:,:)
  latlonsizes = dimsizes(slp(0:(NumAnalysisYears*12)-1,:,:))

  theaveslp = new(NumAnalysisYears,float)
  theavet2m = new(NumAnalysisYears,float)
  theaveh500 = new(NumAnalysisYears,float)
  theavet925 = new(NumAnalysisYears,float)
  theavesst = new(NumAnalysisYears,float)
  theaveslpstd = new(NumAnalysisYears,float)
  theavet2mstd = new(NumAnalysisYears,float)
  theaveh500std = new(NumAnalysisYears,float)
  theavet925std = new(NumAnalysisYears,float)
  theavesststd = new(NumAnalysisYears,float)
  theaveslp@_FillValue = -9999
  theaveh500@_FillValue = -9999
  theavet2m@_FillValue = -9999
  theavet925@_FillValue = -9999
  theavesst@_FillValue = -9999
  theaveslpstd@_FillValue = -9999
  theaveh500std@_FillValue = -9999
  theavet2mstd@_FillValue = -9999
  theavet925std@_FillValue = -9999
  theavesststd@_FillValue = -9999
  theaveslparray = slp(0,:,:)
  theaveh500array = h500(0,:,:)
  theavet2marray = t2m(0,:,:)
  theaveslparray = t925(0,:,:)
  theaveslparray = sst(0,:,:)

  do r = 0, latlonsizes(1) - 1
    do s = 0, latlonsizes(2) - 1
      numregressvars = 4
      avevalsum = 0.0
      theavesst = new(NumAnalysisYears,float)
      do m = 0, NumAnalysisYears-1
        mi = (m*12) + usermonth - 1 + 12
        if (useStandardized.eq.0) then
          theaveslp(m) = (dim_avg(slp(mi-exmth:mi,r,s)))
          theavet2m(m) = (dim_avg(t2m(mi-exmth:mi,r,s)))
          theaveh500(m) = (dim_avg(h500(mi-exmth:mi,r,s)))
          theavet925(m) = (dim_avg(t925(mi-exmth:mi,r,s)))
        end if
        if (useStandardized.eq.1) then
          theaveslp(m) = (dim_avg(slp_std(mi-exmth:mi,r,s)))
          theavet2m(m) = (dim_avg(t2m_std(mi-exmth:mi,r,s)))
          theaveh500(m) = (dim_avg(h500_std(mi-exmth:mi,r,s)))
          theavet925(m) = (dim_avg(t925_std(mi-exmth:mi,r,s)))
        end if
        if(.not.ismissing(sst(m,r,s))) then
          numregressvars = 5
          avevalsum = avevalsum + dim_avg(sst(mi-exmth:mi,r,s))
          if (useStandardized.eq.0) then
            theavesst(m) = (dim_avg(sst(mi-exmth:mi,r,s)))
          end if
          if (useStandardized.eq.1) then
            theavesst(m) = (dim_avg(sst_std(mi-exmth:mi,r,s)))
          end if
        end if
      end do
      if (avevalsum.le.0) then
        numregressvars = 4
      end if
      xpp   = new( (/NumAnalysisYears,numregressvars/), float)
      xpp(:,0) = theaveslp
      xpp(:,1) = theavet2m
      xpp(:,2) = theaveh500
      xpp(:,3) = theavet925
      if (numregressvars.eq.5) then
        xpp(:,4) = theavesst
      end if
      if (txtareayesno.eq.2) then    ; regular values
        betap = reg_multlin_stats(ydep,xpp,opt)   ; var2 is the average of raw values (e.g., ave SLP). var is the average of std devs.
      end if
      if (txtareayesno.lt.2) then    ; special values
        ydep = specialAnalysis1
        betap = reg_multlin_with_missing(ydep,xpp,True)
      end if


      multRcor(0,r,s) = tofloat(betap@r)
      multRcor(1,r,s) = tofloat(betap@r2)
      multRcor(2,r,s) = tofloat(1-betap@F_pval)
      a17 = regline_stats(ydep,theaveslp)
      b17 = regline_stats(ydep,theaveh500)
      c17 = regline_stats(ydep,theavet2m)
      d17 = regline_stats(ydep,theavet925)

      multRcor(3,r,s) = QuickProb2(ydep,theaveslp)
      multRcor(4,r,s) = QuickProb2(ydep,theaveh500)
      multRcor(5,r,s) = QuickProb2(ydep,theavet2m)
      multRcor(6,r,s) = QuickProb2(ydep,theavet925)
      if(a17.lt.0) then
        a17@r = 0.0-a17@r
      end if
      if(b17.lt.0) then
        b17@r = 0.0-b17@r
      end if
      if(c17.lt.0) then
        c17@r = 0.0-c17@r
      end if
      if(d17.lt.0) then
        d17@r = 0.0-d17@r
      end if
      multRcor(8,r,s) = a17@r
      multRcor(9,r,s) = b17@r
      multRcor(10,r,s) = c17@r
      multRcor(11,r,s) = d17@r
      if (numregressvars.eq.5) then
        e17 = regline_stats(ydep,theavesst)
        multRcor(7,r,s) = QuickProb2(ydep,theavesst)
        multRcor(12,r,s) = e17@r
        if(e17.lt.0) then
          multRcor(12,r,s) = 0.0-e17@r
        end if
      end if
      if (numregressvars.eq.4) then
        multRcor(7,r,s) = theavesst@_FillValue
        multRcor(12,r,s) = theavesst@_FillValue
      end if

      delete(numregressvars)
      delete(xpp)
      delete(theavesst)
      delete(avevalsum)
      delete(betap)

    end do
  end do

  multRcor@actual_range = (/ -1, 1 /)
  multRcor@valid_range = (/ -1, 1 /)



  polarOrclyndrical = 1    ; 1=polar, 2=cyclyndrical



  AKboxres = True
  AKboxres = SetBoxRes("cyan2")
  multRcorStyleMR = True
  multRcorStyleMR = SetRes6(0.2,polarOrclyndrical)
  multRcorStyleMR@tiMainFontHeightF  = 0.01
  multRcorStyleMR@lbTitleFontHeightF= 0.01
  multRcorStyleMR@lbLabelFontHeightF= 0.01
  multRcorStyleMR@tiXAxisFontHeightF = 0.02

  multRcorStyle = True
  multRcorStyle = SetRes2(polarOrclyndrical)   ; significance
  multRcorStyle@tiMainFontHeightF  = 0.01
  multRcorStyle@lbTitleFontHeightF= 0.01
  multRcorStyle@lbLabelFontHeightF= 0.01
  multRcorStyle@tiXAxisFontHeightF = 0.02

  multRcorStyle2 = True
  multRcorStyle2 = SetRes3(0.2,polarOrclyndrical, "cor")
  multRcorStyle2@tiMainFontHeightF  = 0.01
  multRcorStyle2@lbTitleFontHeightF= 0.01
  multRcorStyle2@lbLabelFontHeightF= 0.01
  multRcorStyle2@tiXAxisFontHeightF = 0.02

  if (polarOrclyndrical.eq.1) then
    multRcorStyleMR@mpMinLatF  = 20
    multRcorStyle@mpMinLatF  = 20
    multRcorStyle2@mpMinLatF  = 20
    multRcorStyleMR@mpCenterLonF  = 210
    multRcorStyle@mpCenterLonF  = 210
    multRcorStyle2@mpCenterLonF  = 210
  end if


  multRcor@short_name = ""
  multRcor@units = ""
  multRcor(0,{-80},{90})=0
  multRcor(0,{-80},{270})=1.0
  multRcor(1,{-80},{90})=0
  multRcor(1,{-80},{270})=0.5
  multRcor(2,{-80},{90})=0
  multRcor(2,{-80},{270})=1.0
  multRcor(3,{-80},{90})=-1
  multRcor(3,{-80},{270})=1.0
  multRcor(4,{-80},{90})=-1
  multRcor(4,{-80},{270})=1.0
  multRcor(5,{-80},{90})=-1
  multRcor(5,{-80},{270})=1.0
  multRcor(6,{-80},{90})=-1
  multRcor(6,{-80},{270})=1.0
  multRcor(7,{-80},{90})=-1
  multRcor(7,{-80},{270})=1.0
  multRcor(8,{-80},{90})=-0.5
  multRcor(8,{-80},{270})=0.5
  multRcor(9,{-80},{90})=-0.5
  multRcor(9,{-80},{270})=0.5
  multRcor(10,{-80},{90})=-0.5
  multRcor(10,{-80},{270})=0.5
  multRcor(11,{-80},{90})=-0.5
  multRcor(11,{-80},{270})=0.5
  multRcor(12,{-80},{90})=-0.5
  multRcor(12,{-80},{270})=0.5

  Shaperes = True
  Shaperes = SetBoxRes("cyan")



  wtypebig9           = "png"
  wtypebig9@wkWidth  = 1400
  wtypebig9@wkHeight = 1400

  multRcor@long_name = "Linear Regression R Correlation  Plot"
  if (detrend.eq.1) then
    multRcor@long_name = "Linear Regression R Correlation Plot (Detrended)"
  end if
  if (useStandardized.eq.1) then
    multRcor@long_name = multRcor@long_name+"  [Using Standard Anomalies]"
  end if
  if (useStandardized.eq.0) then
    multRcor@long_name = multRcor@long_name+"  [Using Raw Anomalies]"
  end if


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRSLPcor")
  multRcorStyle2@tiXAxisString = "SLP R Correlation for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP R Correlation for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(8,:,:),multRcorStyle2)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(8,:,:),multRcorStyle2)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90/])
  zz = systemfunc("mv -f "+filedir+"SingleRSLPcor.png "+output_dir+"/SingleRSLPcor_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRSLPcor_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRSLPcor.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRSLPcor_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRSLPcor.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRSLPcor_a.png")


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRH500cor")
  multRcorStyle2@tiXAxisString = "Z"+getlev(heightlev) + " R Correlation for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP R Correlation for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(9,:,:),multRcorStyle2)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(9,:,:),multRcorStyle2)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"SingleRH500cor.png "+output_dir+"/SingleRH500cor_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRH500cor_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRH500cor.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRH500cor_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRH500cor.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRH500cor_a.png")


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRT2Mcor")
  multRcorStyle2@tiXAxisString = "T2M R Correlation for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP R Correlation for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(10,:,:),multRcorStyle2)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(10,:,:),multRcorStyle2)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"SingleRT2Mcor.png "+output_dir+"/SingleRT2Mcor_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRT2Mcor_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRT2Mcor.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRT2Mcor_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRT2Mcor.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRT2Mcor_a.png")


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRT925cor")
  multRcorStyle2@tiXAxisString = "T"+getlev(templev) + " R Correlation for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP R Correlation for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(11,:,:),multRcorStyle2)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(11,:,:),multRcorStyle2)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"SingleRT925cor.png "+output_dir+"/SingleRT925cor_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRT925cor_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRT925cor.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRT925cor_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRT925cor.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRT925cor_a.png")


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRSSTcor")
  multRcorStyle2@tiXAxisString = "SST R Correlation for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP R Correlation for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(12,:,:),multRcorStyle2)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(12,:,:),multRcorStyle2)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"SingleRSSTcor.png "+output_dir+"/SingleRSSTcor_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRSSTcor_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRSSTcor.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRSSTcor_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRSSTcor.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRSSTcor_a.png")










  multRcor@long_name = "Linear Regression R Significance Plot"
  if (detrend.eq.1) then
    multRcor@long_name = "Linear Regression R Significance Plot (Detrended)"
  end if
  if (useStandardized.eq.1) then
    multRcor@long_name = multRcor@long_name+"  [Using Standard Anomalies]"
  end if
  if (useStandardized.eq.0) then
    multRcor@long_name = multRcor@long_name+"  [Using Raw Anomalies]"
  end if

  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRSLPsig")
  multRcorStyle@tiXAxisString = "SLP Significance for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP Significance for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(3,:,:),multRcorStyle)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(3,:,:),multRcorStyle)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"SingleRSLPsig.png "+output_dir+"/SingleRSLPsig_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRSLPsig_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRSLPsig.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRSLPsig_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRSLPsig.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRSLPsig_a.png")


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRH500sig")
  multRcorStyle@tiXAxisString = "Z"+getlev(heightlev) + " Significance for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP Significance for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(4,:,:),multRcorStyle)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(4,:,:),multRcorStyle)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90/])
  zz = systemfunc("mv -f "+filedir+"SingleRH500sig.png "+output_dir+"/SingleRH500sig_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRH500sig_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRH500sig.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRH500sig_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRH500sig.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRH500sig_a.png")


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRT2Msig")
  multRcorStyle@tiXAxisString = "T2M Significance for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP Significance for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(5,:,:),multRcorStyle)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(5,:,:),multRcorStyle)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"SingleRT2Msig.png "+output_dir+"/SingleRT2Msig_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRT2Msig_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRT2Msig.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRT2Msig_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRT2Msig.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRT2Msig_a.png")


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRT925sig")
  multRcorStyle@tiXAxisString = "T"+getlev(templev) + " Significance for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP Significance for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(6,:,:),multRcorStyle)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(6,:,:),multRcorStyle)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"SingleRT925sig.png "+output_dir+"/SingleRT925sig_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRT925sig_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRT925sig.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRT925sig_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRT925sig.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRT925sig_a.png")


  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"SingleRSSTsig")
  multRcorStyle@tiXAxisString = "SST Significance for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "SLP Significance for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(7,:,:),multRcorStyle)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(7,:,:),multRcorStyle)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"SingleRSSTsig.png "+output_dir+"/SingleRSSTsig_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/SingleRSSTsig_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/SingleRSSTsig.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/SingleRSSTsig_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/SingleRSSTsig.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/SingleRSSTsig_a.png")


  multRcor@long_name = "Multiple Linear Regression Significance Plot"
  if (useStandardized.eq.1) then
    multRcor@long_name = multRcor@long_name+"  [Using Standard Anomalies]"
  end if
  if (useStandardized.eq.0) then
    multRcor@long_name = multRcor@long_name+"  [Using Raw Anomalies]"
  end if
  if (detrend.eq.1) then
    multRcor@long_name = "Multiple Linear Regression Significance Plot (Detrended)"
  end if
  wks_cor9 = gsn_open_wks(wtypebig9,filedir+"MultipleR")
  multRcorStyleMR@tiXAxisString = "Composite Multiple-R for " + monthRangeString1 + " time period~C~to generate a "+monthRangeString2 + " "+ varName+" forecast in cyan box.~C~Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4
  if (txtareayesno.lt.2) then
    multRcorStyle2@tiXAxisString = "Composite Multiple-R for " + monthRangeString1 + " time period~C~with a user-defined time series"
  end if
  if (polarOrclyndrical.eq.1) then
    plot90 = gsn_csm_contour_map_polar(wks_cor9,multRcor(2,:,:),multRcorStyleMR)
  end if
  if (polarOrclyndrical.eq.2) then
    plot90 = gsn_csm_contour_map(wks_cor9,multRcor(2,:,:),multRcorStyleMR)
  end if
  if (txtareayesno.eq.2) then
    poly90a = gsn_add_polyline(wks_cor9,plot90,AKlon_box,AKlat_box,AKboxres)
  end if
  draw(plot90)
  frame(wks_cor9)
  delete([/wks_cor9,plot90 /])
  zz = systemfunc("mv -f "+filedir+"MultipleR.png "+output_dir+"/MultipleR_a.png")
  if (polarOrclyndrical.eq.1) then
    zz = systemfunc("convert "+output_dir+"/MultipleR_a.png -crop 1130x1400+150+0 -quality 80 "+output_dir+"/MultipleR.jpg")
  end if
  if (polarOrclyndrical.eq.2) then
    zz = systemfunc("convert "+output_dir+"/MultipleR_a.png -crop 1400x1130+0+140 -quality 80 "+output_dir+"/MultipleR.jpg")
  end if
  zz = systemfunc("rm -f "+output_dir+"/MultipleR_a.png")


  print(multRcor(:,{45},{210})+"")

  exit
end if


;;; Compute a value for user seleced month(s) for every year (not future months)
  maxIndex = 0
  do p = 1, 77   ; change to 68 when Jan. 2016 data comes in. (72 in 2020)
      ti = (p*12) + usermonth - 1
      theyear = yrStrt + p
      jk = ti + fmnths + fmnths2 - 1
      if (jk.lt.totalDims) then
        ;; Compute average values for each of the four variables for each year
        ;; and subtract it from the target user month/year value. This is "1" array.
        ;; The "2" array holds the actual average (box) value.
        maxIndex = p   ; maxIndex is the index of the last year included
        sz = 0.
        hz = 0.
        tz = 0.
        vz = 0.
        ez = 0.
        jz = 0.
        kz = 0.
        lz = 0.
        iz = 0.


        x=slp(ti-exmth:ti,{y1:y2},{x1:x2})
        y=slp(thetime-exmth:thetime,{y1:y2},{x1:x2})

        xlat=x&lat
        clat=cos((4.*atan(1.)/180.)*xlat)
        aveval1 = 0.
        aveval2 = 0.
        do ml = 0, exmth
          aveval1 = aveval1 + abs(wgt_areaave(x(ml,:,:),clat,1.0,0) - wgt_areaave(y(ml,:,:),clat,1.0,0))
          aveval2 = aveval2 + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        slpArray1(p) = aveval1 / (exmth + 1) / 1.0
        slpArray2(p) = aveval2 / (exmth + 1) / 1.0


        x=h500(ti-exmth:ti,{y1:y2},{x1:x2})
        y=h500(thetime-exmth:thetime,{y1:y2},{x1:x2})
        aveval1 = 0.
        aveval2 = 0.
        do ml = 0, exmth
          aveval1 = aveval1 + abs(wgt_areaave(x(ml,:,:),clat,1.0,0) - wgt_areaave(y(ml,:,:),clat,1.0,0))
          aveval2 = aveval2 + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        h500Array1(p) = aveval1 / (exmth + 1) / 1.0
        h500Array2(p) = aveval2 / (exmth + 1) / 1.0



        x=t2m(ti-exmth:ti,{y1:y2},{x1:x2})
        y=t2m(thetime-exmth:thetime,{y1:y2},{x1:x2})
        aveval1 = 0.
        aveval2 = 0.
        do ml = 0, exmth
          aveval1 = aveval1 + abs(wgt_areaave(x(ml,:,:),clat,1.0,0) - wgt_areaave(y(ml,:,:),clat,1.0,0))
          aveval2 = aveval2 + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        t2mArray1(p) = aveval1 / (exmth + 1) / 1.0
        t2mArray2(p) = aveval2 / (exmth + 1) / 1.0

        x=t925(ti-exmth:ti,{y1:y2},{x1:x2})
        y=t925(thetime-exmth:thetime,{y1:y2},{x1:x2})
        aveval1 = 0.
        aveval2 = 0.
        do ml = 0, exmth
          aveval1 = aveval1 + abs(wgt_areaave(x(ml,:,:),clat,1.0,0) - wgt_areaave(y(ml,:,:),clat,1.0,0))
          aveval2 = aveval2 + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        t925Array1(p) = aveval1 / (exmth + 1) / 1.0
        t925Array2(p) = aveval2 / (exmth + 1) / 1.0

        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)
        x=sst(ti-exmth:ti,{y1:y2},{x1:x2})
        y=sst(thetime-exmth:thetime,{y1:y2},{x1:x2})
        xlat=x&lat
        clat=cos((4.*atan(1.)/180.)*xlat)
        aveval1 = 0.
        aveval2 = 0.
        do ml = 0, exmth
          aveval1 = aveval1 + abs(wgt_areaave(x(ml,:,:),clat,1.0,0) - wgt_areaave(y(ml,:,:),clat,1.0,0))
          aveval2 = aveval2 + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        sstArray1(p) = aveval1 / (exmth + 1) / 1.0
        sstArray2(p) = aveval2 / (exmth + 1) / 1.0

        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)
        if (variable.lt.6) then
          x=icec(ti-exmth:ti,{60:90},{0:360})
          y=icec(thetime-exmth:thetime,{60:90},{0:360})
        end if
        if (variable.eq.6) then
          x=icec(ti-exmth:ti,{y1:y2},{x1:x2})
          y=icec(thetime-exmth:thetime,{y1:y2},{x1:x2})
        end if
        xlat=x&lat
        clat=cos((4.*atan(1.)/180.)*xlat)
        aveval1 = 0.
        aveval2 = 0.
        do ml = 0, exmth
          aveval1 = aveval1 + abs(wgt_areaave(x(ml,:,:),clat,1.0,0) - wgt_areaave(y(ml,:,:),clat,1.0,0))
          aveval2 = aveval2 + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        iceArray1(p) = aveval1 / (exmth + 1) / 1.0
        iceArray2(p) = aveval2 / (exmth + 1) / 1.0
        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)



        YearArray(p) = theyear
        tempval = ti - exmth
    end if   ;; don't want to accidentally look for months after current month/year
  end do   ;; end do loop that assigns an anomaly and a raw value for each year to 2 diff. arrays.



; 20 seconds


  ; this routine does a calculation of RMS from normal for every monthly observation
  ; The point-by-point comparison uses the blue box ave std. dev. calculated immediately above
  ; The monthly std. dev. from  norm is written to a new array (not spatial).


  do p = 1, 72   ; change to 70 when Feb. 2018 data comes in
      ti = (p*12) + usermonth - 1
      theyear = yrStrt + p
      if (.not.ismissing(YearArray(p)) .and. ti.lt.totalDims) then
        tempval = ti - exmth
        m1 = ti-exmth
        m2 = ti
        i1 = thetime-exmth

        x=slp(ti-exmth:ti,{y1:y2},{x1:x2})
        y=slp(thetime-exmth:thetime,{y1:y2},{x1:x2})
        xNew3b = slp_std(ti-exmth:ti,{y1:y2},{x1:x2})
        yNew3b = slp_std(thetime-exmth:thetime,{y1:y2},{x1:x2})
        xlat=xNew3b&lat
        clat=cos((4.*atan(1.)/180.)*xlat)   ; used for sext 4 blocks
        aveval = 0.
        aveval3b = 0.
        aveval3c = 0.
        do ml = 0, exmth
          aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval3b = aveval3b + wgt_arearmse(xNew3b(ml,:,:),yNew3b(ml,:,:),clat,1.0,0)
          aveval3c = aveval3c + wgt_areaave(xNew3b(ml,:,:),clat,1.0,0)
        end do
        slpArray3(p) = aveval / (exmth + 1) / 1.0
        slpArray3b(p) = aveval3b / (exmth + 1) / 1.0
        slpArray3c(p) = aveval3c / (exmth + 1) / 1.0
        delete(xNew3b)
        delete(yNew3b)

        x=h500(ti-exmth:ti,{y1:y2},{x1:x2})
        y=h500(thetime-exmth:thetime,{y1:y2},{x1:x2})
        xNew3b = h500_std(ti-exmth:ti,{y1:y2},{x1:x2})
        yNew3b = h500_std(thetime-exmth:thetime,{y1:y2},{x1:x2})
        aveval = 0.
        aveval3b = 0.
        aveval3c = 0.
        do ml = 0, exmth
          aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval3b = aveval3b + wgt_arearmse(xNew3b(ml,:,:),yNew3b(ml,:,:),clat,1.0,0)
          aveval3c = aveval3c + wgt_areaave(xNew3b(ml,:,:),clat,1.0,0)
        end do
        h500Array3(p) = aveval / (exmth + 1) / 1.0
        h500Array3b(p) = aveval3b / (exmth + 1) / 1.0
        h500Array3c(p) = aveval3c / (exmth + 1) / 1.0
        delete(xNew3b)
        delete(yNew3b)

        x=t2m(ti-exmth:ti,{y1:y2},{x1:x2})
        y=t2m(thetime-exmth:thetime,{y1:y2},{x1:x2})
        xNew3b = t2m_std(ti-exmth:ti,{y1:y2},{x1:x2})
        yNew3b = t2m_std(thetime-exmth:thetime,{y1:y2},{x1:x2})
        aveval = 0.
        aveval3b = 0.
        aveval3c = 0.
        do ml = 0, exmth
          aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval3b = aveval3b + wgt_arearmse(xNew3b(ml,:,:),yNew3b(ml,:,:),clat,1.0,0)
          aveval3c = aveval3c + wgt_areaave(xNew3b(ml,:,:),clat,1.0,0)
        end do
        t2mArray3(p) = aveval / (exmth + 1) / 1.0
        t2mArray3b(p) = aveval3b / (exmth + 1) / 1.0
        t2mArray3c(p) = aveval3c / (exmth + 1) / 1.0
        delete(xNew3b)
        delete(yNew3b)

        x=t925(ti-exmth:ti,{y1:y2},{x1:x2})
        y=t925(thetime-exmth:thetime,{y1:y2},{x1:x2})
        xNew3b = t925_std(ti-exmth:ti,{y1:y2},{x1:x2})
        yNew3b = t925_std(thetime-exmth:thetime,{y1:y2},{x1:x2})
        aveval = 0.
        aveval3b = 0.
        aveval3c = 0.
        do ml = 0, exmth
          aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval3b = aveval3b + wgt_arearmse(xNew3b(ml,:,:),yNew3b(ml,:,:),clat,1.0,0)
          aveval3c = aveval3c + wgt_areaave(xNew3b(ml,:,:),clat,1.0,0)
        end do
        t925Array3(p) = aveval / (exmth + 1) / 1.0
        t925Array3b(p) = aveval3b / (exmth + 1) / 1.0
        t925Array3c(p) = aveval3c / (exmth + 1) / 1.0
        delete(xNew3b)
        delete(yNew3b)

        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)
        x=sst(ti-exmth:ti,{y1:y2},{x1:x2})
        y=sst(thetime-exmth:thetime,{y1:y2},{x1:x2})
        xNew3b = sst_std(ti-exmth:ti,{y1:y2},{x1:x2})
        yNew3b = sst_std(thetime-exmth:thetime,{y1:y2},{x1:x2})
        xlat=xNew3b&lat
        clat=cos((4.*atan(1.)/180.)*xlat)
        aveval = 0.
        aveval3b = 0.
        aveval3c = 0.
        do ml = 0, exmth
          aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval3b = aveval3b + wgt_arearmse(xNew3b(ml,:,:),yNew3b(ml,:,:),clat,1.0,0)
          aveval3c = aveval3c + wgt_areaave(xNew3b(ml,:,:),clat,1.0,0)
        end do
        sstArray3(p) = aveval / (exmth + 1) / 1.0
        sstArray3b(p) = aveval3b / (exmth + 1) / 1.0
        sstArray3c(p) = aveval3c / (exmth + 1) / 1.0
        delete(xNew3b)
        delete(yNew3b)


        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)
        if (variable.lt.6) then
          x=icec(ti-exmth:ti,{60:90},{0:360})
          y=icec(thetime-exmth:thetime,{60:90},{0:360})
          xNew3b = icec(ti-exmth:ti,{60:90},{0:360})
          yNew3b = icec(thetime-exmth:thetime,{60:90},{0:360})
        end if
        if (variable.eq.6) then
          x=icec(ti-exmth:ti,{y1:y2},{x1:x2})
          y=icec(thetime-exmth:thetime,{y1:y2},{x1:x2})
          xNew3b = icec(ti-exmth:ti,{y1:y2},{x1:x2})
          yNew3b = icec(thetime-exmth:thetime,{y1:y2},{x1:x2})
        end if
        xlat=xNew3b&lat
        clat=cos((4.*atan(1.)/180.)*xlat)
        aveval = 0.
        aveval3b = 0.
        do ml = 0, exmth
          aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval3b = aveval3b + wgt_arearmse(xNew3b(ml,:,:),yNew3b(ml,:,:),clat,1.0,0)
        end do
        iceArray3(p) = aveval / (exmth + 1) / 1.0
        iceArray3b(p) = aveval3b / (exmth + 1) / 1.0
        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)
        delete(xNew3b)
        delete(yNew3b)



        x=slp(ti-exmth:ti,{y1:y2},{x1:x2})
        xlat=x&lat
        y=slpClm(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
        clat=cos((4.*atan(1.)/180.)*xlat)
        aveval = 0.
        do ml = 0, exmth
          ;aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        slpArray4(p) = aveval / (exmth + 1) / 1.0

        x=h500(ti-exmth:ti,{y1:y2},{x1:x2})
        y=h500Clm(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
        aveval = 0.
        do ml = 0, exmth
          ;aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        h500Array4(p) = aveval / (exmth + 1) / 1.0

        x=t2m(ti-exmth:ti,{y1:y2},{x1:x2})
        y=t2mClm(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
        aveval = 0.
        do ml = 0, exmth
          ;aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        t2mArray4(p) = aveval / (exmth + 1) / 1.0

        x=t925(ti-exmth:ti,{y1:y2},{x1:x2})
        y=t925Clm(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
        aveval = 0.
        do ml = 0, exmth
          ;aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        t925Array4(p) = aveval / (exmth + 1) / 1.0

        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)
        x=sst(ti-exmth:ti,{y1:y2},{x1:x2})
        y=sstClm(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
        xlat=x&lat
        clat=cos((4.*atan(1.)/180.)*xlat)
        aveval = 0.
        do ml = 0, exmth
          ;aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
          aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
        end do
        sstArray4(p) = aveval / (exmth + 1) / 1.0


        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)
        if (variable.lt.6) then
          x=icec(ti-exmth:ti,{60:90},{0:360})
          y=iceClm(usermonth+12-1-exmth:usermonth+12-1,{60:90},{0:360})
        end if
        if (variable.eq.6) then
          x=icec(ti-exmth:ti,{y1:y2},{x1:x2})
          y=iceClm(usermonth+12-1-exmth:usermonth+12-1,{y1:y2},{x1:x2})
        end if
        xlat=x&lat
        clat=cos((4.*atan(1.)/180.)*xlat)
        aveval = 0.
        do ml = 0, exmth
          aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
        end do
        iceArray4(p) = aveval / (exmth + 1) / 1.0
        delete(x)
        delete(y)
        delete(xlat)
        delete(clat)



        ;;; Create Weighted Index
        ;;; index values divided by 3 to have them at
        ;;; approximate same scale as R-values from slp, etc.
        if (.not.ismissing(sstArray3b(p))) then
          weightedArray1(p) = (slpArray3b(p) * tofloat(slpwgt)) + (h500Array3b(p) * tofloat(h500wgt)) + (t2mArray3b(p) * tofloat(t2mwgt)) + (t925Array3b(p) * tofloat(t925wgt))  + (sstArray3b(p) *  tofloat(sstwgt))
          weightedArraySpecial(p) = (slpArray3c(p) * tofloat(slpwgt)) + (h500Array3c(p) * tofloat(h500wgt)) + (t2mArray3c(p) * tofloat(t2mwgt)) + (t925Array3c(p) * tofloat(t925wgt))  + (sstArray3c(p) * tofloat(sstwgt))
        end if
        if (ismissing(sstArray3b(p))) then
          weightedArray1(p) = (slpArray3b(p) * tofloat(slpwgt)) + (h500Array3b(p) * tofloat(h500wgt)) + (t2mArray3b(p) * tofloat(t2mwgt)) + (t925Array3b(p) * tofloat(t925wgt))
          weightedArraySpecial(p) = (slpArray3c(p) * tofloat(slpwgt)) + (h500Array3c(p) * tofloat(h500wgt)) + (t2mArray3c(p) * tofloat(t2mwgt)) + (t925Array3c(p) * tofloat(t925wgt))
        end if

        if (theyear.eq.useryear) then
          weightedArray1(p) = 9999
          weightedArraySpecial(p) = 9999
          specialArray1(p) = 9999
        end if
      end if
  end do

  slpArray3(0) = 9999.0
  h500Array3(0) = 9999.0
  t2mArray3(0) = 9999.0
  t925Array3(0) = 9999.0
  sstArray3(0) = 9999.0
  iceArray3(0) = 9999.0

  slpArray5(0) = -9999.0
  h500Array5(0) = -9999.0
  t2mArray5(0) = -9999.0
  t925Array5(0) = -9999.0
  sstArray5(0) = -9999.0
  iceArray5(0) = -9999.0

  slpArray4(0) =  0.0
  h500Array4(0) = 0.0
  t2mArray4(0) =  0.0
  t925Array4(0) = 0.0
  sstArray4(0) =  0.0
  iceArray4(0) =  0.0

;; Create new arrays that contain month/year averages of the
;; 4 variables. A value of 0 is in the first index entry, but
;; everything else has a value. This is for the R-value calculation.

doLast = True   ; This determines whether to do a verification plot (can't do one for the future!)

dcomp = usermonth+fmnths+fmnths2-1



currentMonthP12 = currentMonth +12
currentYearM1 = currentYear-1
currentYearM2 = currentYear-2

if (useryear.eq.currentYear) then  ; change to .gt.10 with October 2016 data
  doLast = False
end if
if (useryear.eq.currentYearM1 .and. dcomp.gt.currentMonth) then  ; change to .gt.9 with September 2016 data
  doLast = False
end if
if (useryear.eq.currentYearM2 .and. dcomp.gt.currentMonthP12) then   ; change to .gt.21 with September 2016 data
  doLast = False
end if


;doLast = False
;compare = 803+usermonth + fmnths + fmnths2 - 1    ; change 803 to 815 in 2016
;if (useryear.eq.2016) then
;  compare = compare + 12
;end if
;if (compare.lt.817) then                          ; change 816 to 817 with Jan 2016 data
;    doLast = True
;end if
;if (useryear.lt.2015) then                        ; change to 2016 with Jan 2016 data
;    doLast = True
;end if


RMS_Array_Size = maxIndex
if (ismissing(YearArray(72)).eq.False .and. doLast.eq.False) then  ; Change to 68 with Jan 2016 data
  RMS_Array_Size = maxIndex - 1
end if


  slpArrayforRMS = new(RMS_Array_Size,float)
  h500ArrayforRMS = new(RMS_Array_Size,float)
  t2mArrayforRMS = new(RMS_Array_Size,float)
  t925ArrayforRMS = new(RMS_Array_Size,float)
  iceArrayforRMS = new(RMS_Array_Size,float)
  sstArrayforRMS = new(RMS_Array_Size,float)
  YearArrayforRMS = new(RMS_Array_Size,float)
  iceYearArrayforRMS = new(RMS_Array_Size,float)
  do i = 0, RMS_Array_Size - 1
    slpArrayforRMS(i) = slpArray2(i+1)
    h500ArrayforRMS(i) = h500Array2(i+1)
    t2mArrayforRMS(i) = t2mArray2(i+1)
    t925ArrayforRMS(i) = t925Array2(i+1)
    sstArrayforRMS(i) = sstArray2(i+1)
    iceArrayforRMS(i) = iceArray2(i+1)
    YearArrayforRMS(i) = yrStrt + i + 1
  end do


  AKslpArray = new(RMS_Array_Size,float)
  AKh500Array = new(RMS_Array_Size,float)
  AKt2mArray = new(RMS_Array_Size,float)
  AKt925Array = new(RMS_Array_Size,float)
  AKsstArray = new(RMS_Array_Size,float)
  AKiceArray = new(RMS_Array_Size,float)
  AKboxslpArray3 = new(RMS_Array_Size,float)
  AKboxh500Array3 = new(RMS_Array_Size,float)
  AKboxt2mArray3 = new(RMS_Array_Size,float)
  AKboxt925Array3 = new(RMS_Array_Size,float)
  AKboxsstArray3 = new(RMS_Array_Size,float)
  AKboxiceArray3 = new(RMS_Array_Size,float)
  AKboxslpArray4 = new(RMS_Array_Size,float)
  AKboxh500Array4 = new(RMS_Array_Size,float)
  AKboxt2mArray4 = new(RMS_Array_Size,float)
  AKboxt925Array4 = new(RMS_Array_Size,float)
  AKboxsstArray4 = new(RMS_Array_Size,float)
  AKboxiceArray4 = new(RMS_Array_Size,float)

  do pt = 0, RMS_Array_Size - 1
    indexA = tointeger((pt*12)+usermonth-1+fmnths)+12
    indexB = tointeger((pt*12)+usermonth-1+fmnths+fmnths2-1)+12
    indexC = tointeger(thetime+fmnths)
    indexD = tointeger(thetime+fmnths+fmnths2-1)


    x=slp(indexA:indexB,{AK1:AK2},{AK3:AK4})
    xlat=x&lat
    clat=cos((4.*atan(1.)/180.)*xlat)
    aveval = 0.
    do ml = 0, fmnths2-1
      aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
    end do
    AKslpArray(pt) = aveval / (fmnths2-1 + 1) / 1.0

    x=h500(indexA:indexB,{AK1:AK2},{AK3:AK4})
    aveval = 0.
    do ml = 0, fmnths2-1
      aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
    end do
    AKh500Array(pt) = aveval / (fmnths2-1 + 1) / 1.0

    x=t2m(indexA:indexB,{AK1:AK2},{AK3:AK4})
    aveval = 0.
    do ml = 0, fmnths2-1
      aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
    end do
    AKt2mArray(pt) = aveval / (fmnths2-1 + 1) / 1.0

    x=t925(indexA:indexB,{AK1:AK2},{AK3:AK4})
    aveval = 0.
    do ml = 0, fmnths2-1
      aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
    end do
    AKt925Array(pt) = aveval / (fmnths2-1 + 1) / 1.0

    delete(x)
    delete(xlat)
    delete(clat)
    x=sst(indexA:indexB,{AK1:AK2},{AK3:AK4})
    xlat=x&lat
    clat=cos((4.*atan(1.)/180.)*xlat)
    aveval = 0.
    do ml = 0, fmnths2-1
      aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
    end do
    AKsstArray(pt) = aveval / (fmnths2-1 + 1) / 1.0


    delete(x)
    delete(xlat)
    delete(clat)
    if (variable.lt.6) then
      x=icec(indexA:indexB,{60:90},{60:90})
    end if
    if (variable.eq.6) then
      x=icec(indexA:indexB,{AK1:AK2},{AK3:AK4})
    end if
    xlat=x&lat
    clat=cos((4.*atan(1.)/180.)*xlat)
    aveval = 0.
    do ml = 0, fmnths2-1
      aveval = aveval + wgt_areaave(x(ml,:,:),clat,1.0,0)
    end do
    AKiceArray(pt) = aveval / (fmnths2-1 + 1) / 1.0
    delete(x)
    delete(xlat)
    delete(clat)


    if (indexC.lt.totalDims .and. indexD.lt.totalDims) then

      x=slp(indexA:indexB,{AK1:AK2},{AK3:AK4})
      xlat=x&lat
      y=slp(indexC:indexD,{AK1:AK2},{AK3:AK4})
      clat=cos((4.*atan(1.)/180.)*xlat)
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxslpArray3(pt) = aveval / (fmnths2-1 + 1) / 1.0

      x=h500(indexA:indexB,{AK1:AK2},{AK3:AK4})
      y=h500(indexC:indexD,{AK1:AK2},{AK3:AK4})
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxh500Array3(pt) = aveval / (fmnths2-1 + 1) / 1.0

      x=t2m(indexA:indexB,{AK1:AK2},{AK3:AK4})
      y=t2m(indexC:indexD,{AK1:AK2},{AK3:AK4})
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxt2mArray3(pt) = aveval / (fmnths2-1 + 1) / 1.0

      x=t925(indexA:indexB,{AK1:AK2},{AK3:AK4})
      y=t925(indexC:indexD,{AK1:AK2},{AK3:AK4})
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxt925Array3(pt) = aveval / (fmnths2-1 + 1) / 1.0

      delete(x)
      delete(y)
      delete(xlat)
      delete(clat)
      x=sst(indexA:indexB,{AK1:AK2},{AK3:AK4})
      y=sst(indexC:indexD,{AK1:AK2},{AK3:AK4})
      xlat=x&lat
      clat=cos((4.*atan(1.)/180.)*xlat)
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxsstArray3(pt) = aveval / (fmnths2-1 + 1) / 1.0

      delete(x)
      delete(y)
      delete(xlat)
      delete(clat)
      if (variable.lt.6) then
        x=icec(indexA:indexB,{60:90},{0:360})
        y=icec(indexC:indexD,{60:90},{0:360})
      end if
      if (variable.eq.6) then
        x=icec(indexA:indexB,{AK1:AK2},{AK3:AK4})
        y=icec(indexC:indexD,{AK1:AK2},{AK3:AK4})
      end if
      xlat=x&lat
      clat=cos((4.*atan(1.)/180.)*xlat)
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxiceArray3(pt) = aveval / (fmnths2-1 + 1) / 1.0
      delete(x)
      delete(y)
      delete(xlat)
      delete(clat)



      x=slp(indexA:indexB,{AK1:AK2},{AK3:AK4})
      xlat=x&lat
      y=slpClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
      clat=cos((4.*atan(1.)/180.)*xlat)
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxslpArray4(pt) = aveval / (fmnths2-1 + 1) / 1.0

      x=h500(indexA:indexB,{AK1:AK2},{AK3:AK4})
      y=h500Clm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxh500Array4(pt) = aveval / (fmnths2-1 + 1) / 1.0

      x=t2m(indexA:indexB,{AK1:AK2},{AK3:AK4})
      y=t2mClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxt2mArray4(pt) = aveval / (fmnths2-1 + 1) / 1.0

      x=t925(indexA:indexB,{AK1:AK2},{AK3:AK4})
      y=t925Clm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxt925Array4(pt) = aveval / (fmnths2-1 + 1) / 1.0

      delete(x)
      delete(y)
      delete(xlat)
      delete(clat)
      x=sst(indexA:indexB,{AK1:AK2},{AK3:AK4})
      y=sstClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
      xlat=x&lat
      clat=cos((4.*atan(1.)/180.)*xlat)
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxsstArray4(pt) = aveval / (fmnths2-1 + 1) / 1.0

      delete(x)
      delete(y)
      delete(xlat)
      delete(clat)
      if (variable.lt.6) then
        x=icec(indexA:indexB,{60:90},{0:360})
        y=iceClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{60:90},{0:360})
      end if
      if (variable.eq.6) then
        x=icec(indexA:indexB,{AK1:AK2},{AK3:AK4})
        y=iceClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4})
      end if
      xlat=x&lat
      clat=cos((4.*atan(1.)/180.)*xlat)
      aveval = 0.
      do ml = 0, fmnths2-1
        aveval = aveval + wgt_arearmse(x(ml,:,:),y(ml,:,:),clat,1.0,0)
      end do
      AKboxiceArray4(pt) = aveval / (fmnths2-1 + 1) / 1.0
      delete(x)
      delete(y)
      delete(xlat)
      delete(clat)
    end if
  end do





;; create user friendly arrays
slpBlueBoxMatchYears  = new(RMS_Array_Size,float)
h500BlueBoxMatchYears = new(RMS_Array_Size,float)
t2mBlueBoxMatchYears  = new(RMS_Array_Size,float)
t925BlueBoxMatchYears = new(RMS_Array_Size,float)
sstBlueBoxMatchYears = new(RMS_Array_Size,float)
iceBlueBoxMatchYears = new(RMS_Array_Size,float)
slpBlueBoxMatchYears  = slpArrayforRMS
h500BlueBoxMatchYears = h500ArrayforRMS
t2mBlueBoxMatchYears  = t2mArrayforRMS
t925BlueBoxMatchYears = t925ArrayforRMS
sstBlueBoxMatchYears = sstArrayforRMS
iceBlueBoxMatchYears = iceArrayforRMS

slpRedBoxMatchYears  = new(RMS_Array_Size,float)
h500RedBoxMatchYears = new(RMS_Array_Size,float)
t2mRedBoxMatchYears  = new(RMS_Array_Size,float)
t925RedBoxMatchYears = new(RMS_Array_Size,float)
sstRedBoxMatchYears = new(RMS_Array_Size,float)
iceRedBoxMatchYears = new(RMS_Array_Size,float)
slpRedBoxMatchYears  = AKslpArray
h500RedBoxMatchYears = AKh500Array
t2mRedBoxMatchYears  = AKt2mArray
t925RedBoxMatchYears = AKt925Array
sstRedBoxMatchYears = AKsstArray
iceRedBoxMatchYears = AKiceArray


YearArrayMatchYears = new(RMS_Array_Size,float)
YearArrayMatchYears = YearArrayforRMS
iceYearArrayMatchYears = new(RMS_Array_Size,float)
iceYearArrayMatchYears = YearArrayforRMS


; Change these to 68 when Jan 2016 data comes in
countMiss = 0
siz = dimsizes(t925Array2)
do vf = 0, siz - 1
  if(ismissing(t925Array2(vf))) then
    countMiss = countMiss + 1
  end if
end do





slpBlueBoxAllYears = new(72,float)
slpBlueBoxAllYears = slpArray2(1:72)
h500BlueBoxAllYears = new(72,float)
h500BlueBoxAllYears = h500Array2(1:72)
t2mBlueBoxAllYears = new(72,float)
t2mBlueBoxAllYears = t2mArray2(1:72)
t925BlueBoxAllYears = new(72,float)
t925BlueBoxAllYears = t925Array2(1:72)
sstBlueBoxAllYears = new(72,float)
sstBlueBoxAllYears = sstArray2(1:72)
iceBlueBoxAllYears = new(72,float)
iceBlueBoxAllYears = iceArray2(1:72)


r_square_slp = R_value(slpBlueBoxMatchYears,slpRedBoxMatchYears)
r_square_h500 = R_value(h500BlueBoxMatchYears,h500RedBoxMatchYears)
r_square_t2m = R_value(t2mBlueBoxMatchYears,t2mRedBoxMatchYears)
r_square_t925 = R_value(t925BlueBoxMatchYears,t925RedBoxMatchYears)
r_square_sst = R_value(sstBlueBoxMatchYears,sstRedBoxMatchYears)
r_square_ice = R_value(iceBlueBoxMatchYears,iceRedBoxMatchYears)




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end the section that calculates values and
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; anoms in user month (+ exmnths) for each year.




;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Do a sort of the annual slp, h500, t2m, and t925 arrays from
;;; previous section to choose the top 5 matches. (Section 9)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  ii = 1
  dcomp = usermonth+fmnths+fmnths2-1

  if (useryear.eq.2020 .and. dcomp.gt.currentMonth) then  ; this means the forecast month is in the future
    ii = ii - 1
  end if
  currentMonth12=currentMonth+12
  if (useryear.eq.2020 .and. dcomp.gt.currentMonth12) then     ; this means the forecast month is in the future
    ii = ii - 1
  end if


  aaa = slpArray3b     ; array contains the slp anomaly for each mo/yr (-) selected mo/yr
  bbb = h500Array3b    ; array contains the h500 anomaly for each mo/yr (-) selected mo/yr
  ccc = t2mArray3b     ; array contains the t2m anomaly for each mo/yr (-) selected mo/yr
  ddd = t925Array3b    ; array contains the t925 anomaly for each mo/yr (-) selected mo/yr
  eee = sstArray3b    ; array contains the sst anomaly for each mo/yr (-) selected mo/yr
  fff = iceArray3b    ; array contains the icec anomaly for each mo/yr (-) selected mo/yr
  sss = specialArray1    ; array contains the special
  www = weightedArray1    ; array contains the weighted standard anomaly for each mo/yr (-) selected mo/yr


  aaaa = dim_pqsort_n(aaa,2,0)   ; sorted anomalies. Index 0 will be
  bbbb = dim_pqsort_n(bbb,2,0)   ; a missing value for 2016 and index
  cccc = dim_pqsort_n(ccc,2,0)   ; 1 will be a value of zero since mo/yr
  dddd = dim_pqsort_n(ddd,2,0)   ; of target is one of array entries.
  eeee = dim_pqsort_n(eee,2,0)   ;
  ffff = dim_pqsort_n(fff,2,0)   ;
  wwww = dim_pqsort_n(www,2,0)   ; the is the weighted array

  xxyy = wwww



ii=0
if(YearArray(xxyy(ii)).eq.useryear) then   ; for weighted
  ii = 1
end if
weightedMatchString = "1) "+YearArray(xxyy(ii)) + "2) "+YearArray(xxyy(ii+1)) + "3) "+YearArray(xxyy(ii+2)) + "4) "+YearArray(xxyy(ii+3)) + "5) "+YearArray(xxyy(ii+4))

cat=0
if(YearArray(aaaa(cat)).eq.useryear) then   ; for slp
  cat = 1
end if
weightedSLPString = "1) "+YearArray(aaaa(cat)) + " 2) "+YearArray(aaaa(cat+1)) + " 3) "+YearArray(aaaa(cat+2)) + " 4) "+YearArray(aaaa(cat+3)) + " 5) "+YearArray(aaaa(cat+4))

cat=0
if(YearArray(bbbb(cat)).eq.useryear) then   ; for h500
  cat = 1
end if
weightedH500String = "1) "+YearArray(bbbb(cat)) + " 2) "+YearArray(bbbb(cat+1)) + " 3) "+YearArray(bbbb(cat+2)) + " 4) "+YearArray(bbbb(cat+3)) + " 5) "+YearArray(bbbb(cat+4))

cat=0
if(YearArray(cccc(cat)).eq.useryear) then   ; for t2m
  cat = 1
end if
weightedT2MString = "1) "+YearArray(cccc(cat)) + " 2) "+YearArray(cccc(cat+1)) + " 3) "+YearArray(cccc(cat+2)) + " 4) "+YearArray(cccc(cat+3)) + " 5) "+YearArray(cccc(cat+4))

cat=0
if(YearArray(dddd(cat)).eq.useryear) then   ; for t925
  cat = 1
end if
weightedT925String = "1) "+YearArray(dddd(cat)) + " 2) "+YearArray(dddd(cat+1)) + " 3) "+YearArray(dddd(cat+2)) + " 4) "+YearArray(dddd(cat+3)) + " 5) "+YearArray(dddd(cat+4))

cat=0
if(YearArray(eeee(cat)).eq.useryear) then   ; for sst
  cat = 1
end if
weightedSSTString = "1) "+YearArray(eeee(cat)) + " 2) "+YearArray(eeee(cat+1)) + " 3) "+YearArray(eeee(cat+2)) + " 4) "+YearArray(eeee(cat+3)) + " 5) "+YearArray(eeee(cat+4))

cat=0
if(YearArray(ffff(cat)).eq.useryear) then   ; for icec
  cat = 1
end if
weightedICEString = "1) "+YearArray(ffff(cat)) + " 2) "+YearArray(ffff(cat+1)) + " 3) "+YearArray(ffff(cat+2)) + " 4) "+YearArray(ffff(cat+3)) + " 5) "+YearArray(ffff(cat+4))

sp1 = specialArray1(toint(YearArray(xxyy(ii)))-1948)
sp2 = specialArray1(toint(YearArray(xxyy(ii+1)))-1948)
sp3 = specialArray1(toint(YearArray(xxyy(ii+2)))-1948)
sp4 = specialArray1(toint(YearArray(xxyy(ii+3)))-1948)
sp5 = specialArray1(toint(YearArray(xxyy(ii+4)))-1948)

specialResult = (sp1+sp2+sp3+sp4+sp5)/5.0
asciiwrite (filedir+"specialresult.txt" , sprintf("%6.2f",specialResult))
zz = systemfunc("mv -f "+filedir+"specialresult.txt "+output_dir+"/specialresult.txt")

;*****
print("Sept sea ice forecast for "+usermonth+"/"+useryear+" using "+exmthlabel+" months of data: "+YearArray(xxyy(ii))+","+YearArray(xxyy(ii+1))+","+YearArray(xxyy(ii+2))+","+YearArray(xxyy(ii+3))+","+YearArray(xxyy(ii+4))+","+specialResult)



  ;; These next 4 lines calc the ave value for top 5 analogs of each variable
  AveslpDiff  = (slpArray1(aaaa(ii))  + slpArray1(aaaa(ii+1))  + slpArray1(aaaa(ii+2))  + slpArray1(aaaa(ii+3))  + slpArray1(aaaa(ii+4)))  /5.0
  Aveh500Diff = (h500Array1(bbbb(ii)) + h500Array1(bbbb(ii+1)) + h500Array1(bbbb(ii+2)) + h500Array1(bbbb(ii+3)) + h500Array1(bbbb(ii+4))) /5.0
  Avet2mDiff  = (t2mArray1(cccc(ii))  + t2mArray1(cccc (ii+1)) + t2mArray1(cccc(ii+2))  + t2mArray1(cccc(ii+3))  + t2mArray1(cccc(ii+4)))  /5.0
  Avet925Diff = (t925Array1(dddd(ii)) + t925Array1(dddd(ii+1)) + t925Array1(dddd(ii+2)) + t925Array1(dddd(ii+3)) + t925Array1(dddd(ii+4))) /5.0
  AvesstDiff = (sstArray1(eeee(ii)) + sstArray1(eeee(ii+1)) + sstArray1(eeee(ii+2)) + sstArray1(eeee(ii+3)) + sstArray1(eeee(ii+4))) /5.0
  AveiceDiff = (iceArray1(ffff(ii)) + iceArray1(ffff(ii+1)) + iceArray1(ffff(ii+2)) + iceArray1(ffff(ii+3)) + iceArray1(ffff(ii+4))) /5.0
  WeightedDiff = (weightedArray1(wwww(ii)) + weightedArray1(wwww(ii+1)) + weightedArray1(wwww(ii+2)) + weightedArray1(wwww(ii+3)) + weightedArray1(wwww(ii+4))) /5.0

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; end the sorting of anomaly arrays
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Create a spatial array with whichever analog years you wish for the top 5
;;; analog years. This is forward looking. You can mix and match variables and
;;; analog years. (Section 10)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  j = ii   ; index to be passed to function

  slpInd = new(10,integer)
  h500Ind = new(10,integer)
  t2mInd = new(10,integer)
  t925Ind = new(10,integer)
  sstInd = new(10,integer)
  iceInd = new(10,integer)
  weightedInd = new(10,integer)
  ClmInd = new(10,integer)

if (domanual.eq.True) then
  if(manualyesno.eq.1) then
    wwww(j) = manyear1 - 1948
    wwww(j+1) = manyear2 - 1948
    wwww(j+2) = manyear3 - 1948
    wwww(j+3) = manyear4 - 1948
    wwww(j+4) = manyear5 - 1948
  end if
end if


  ; calc beg/end index numbers for analog years ( 0 to 4 for start and 5 to 9 for end)
  do qq=1,5  ; loop through and populate top 5 SLP and H500 analog month groups into template arrays
    slpInd(qq-1)   = tointeger(((YearArray(aaaa(j))-1948)*12)+usermonth-1+fmnths)              ; slp forward looking begin index
    slpInd(qq-1+5) = tointeger(((YearArray(aaaa(j))-1948)*12)+usermonth-1+fmnths+fmnths2-1)    ; slp forward looking end index
    h500Ind(qq-1)   = tointeger(((YearArray(bbbb(j))-1948)*12)+usermonth-1+fmnths)
    h500Ind(qq-1+5) = tointeger(((YearArray(bbbb(j))-1948)*12)+usermonth-1+fmnths+fmnths2-1)
    t2mInd(qq-1)   = tointeger(((YearArray(cccc(j))-1948)*12)+usermonth-1+fmnths)
    t2mInd(qq-1+5) = tointeger(((YearArray(cccc(j))-1948)*12)+usermonth-1+fmnths+fmnths2-1)
    t925Ind(qq-1)   = tointeger(((YearArray(dddd(j))-1948)*12)+usermonth-1+fmnths)
    t925Ind(qq-1+5) = tointeger(((YearArray(dddd(j))-1948)*12)+usermonth-1+fmnths+fmnths2-1)
    sstInd(qq-1)   = tointeger(((YearArray(eeee(j))-1948)*12)+usermonth-1+fmnths)
    sstInd(qq-1+5) = tointeger(((YearArray(eeee(j))-1948)*12)+usermonth-1+fmnths+fmnths2-1)
    iceInd(qq-1)   = tointeger(((YearArray(ffff(j))-1948)*12)+usermonth-1+fmnths)
    iceInd(qq-1+5) = tointeger(((YearArray(ffff(j))-1948)*12)+usermonth-1+fmnths+fmnths2-1)
    weightedInd(qq-1)   = tointeger(((YearArray(wwww(j))-1948)*12)+usermonth-1+fmnths)
    weightedInd(qq-1+5) = tointeger(((YearArray(wwww(j))-1948)*12)+usermonth-1+fmnths+fmnths2-1)
    ClmInd(qq-1)   = tointeger(usermonth+12-1+fmnths)
    ClmInd(qq-1+5) = tointeger(usermonth+12-1+fmnths+fmnths2-1)
    j = j+1
  end do

targetslp        = slp(0,:,:) ; stupid initialization
targetslp        = dim_avg_n_Wrap(slp(thetime-exmth:thetime,:,:),0)
targetslpanom    = slp(0,:,:) ; stupid initialization
targetslpanom    = dim_avg_n_Wrap(slp(thetime-exmth:thetime,:,:),0) - dim_avg_n_Wrap(slpClm(usermonth+12-1-exmth:usermonth+12-1,:,:),0)
top5slp          = Spatial5Array(slp,weightedInd)                      ; spatial array of top 5 best analogs
top5slpAnom      = Spatial5ArrayAnom(slp,weightedInd,slpClm,ClmInd)    ; calc top5 anomaly

targeth500        = h500(0,:,:) ; stupid initialization
targeth500        = dim_avg_n_Wrap(h500(thetime-exmth:thetime,:,:),0)
targeth500anom    = h500(0,:,:) ; stupid initialization
targeth500anom    = dim_avg_n_Wrap(h500(thetime-exmth:thetime,:,:),0) - dim_avg_n_Wrap(h500Clm(usermonth+12-1-exmth:usermonth+12-1,:,:),0)
top5h500          = Spatial5Array(h500,weightedInd)                      ; spatial array of top 5 best analogs
top5h500Anom      = Spatial5ArrayAnom(h500,weightedInd,h500Clm,ClmInd)    ; calc top5 anomaly

targett2m        = t2m(0,:,:) ; stupid initialization
targett2m        = dim_avg_n_Wrap(t2m(thetime-exmth:thetime,:,:),0)
targett2manom    = t2m(0,:,:) ; stupid initialization
targett2manom    = dim_avg_n_Wrap(t2m(thetime-exmth:thetime,:,:),0) - dim_avg_n_Wrap(t2mClm(usermonth+12-1-exmth:usermonth+12-1,:,:),0)
top5t2m          = Spatial5Array(t2m,weightedInd)                      ; spatial array of top 5 best analogs
top5t2mAnom      = Spatial5ArrayAnom(t2m,weightedInd,t2mClm,ClmInd)    ; calc top5 anomaly

targett925        = t925(0,:,:) ; stupid initialization
targett925        = dim_avg_n_Wrap(t925(thetime-exmth:thetime,:,:),0)
targett925anom    = t925(0,:,:) ; stupid initialization
targett925anom    = dim_avg_n_Wrap(t925(thetime-exmth:thetime,:,:),0) - dim_avg_n_Wrap(t925Clm(usermonth+12-1-exmth:usermonth+12-1,:,:),0)
top5t925          = Spatial5Array(t925,weightedInd)                      ; spatial array of top 5 best analogs
top5t925Anom      = Spatial5ArrayAnom(t925,weightedInd,t925Clm,ClmInd)    ; calc top5 anomaly

targetsst         = sst(0,:,:) ; stupid initialization
targetsst         = dim_avg_n_Wrap(sst(thetime-exmth:thetime,:,:),0)
targetsstanom     = sst(0,:,:) ; stupid initialization
targetsstanom     = dim_avg_n_Wrap(sst(thetime-exmth:thetime,:,:),0) - dim_avg_n_Wrap(sstClm(usermonth+12-1-exmth:usermonth+12-1,:,:),0)
top5sst           = Spatial5Array(sst,weightedInd)                      ; spatial array of top 5 best analogs
top5sstAnom       = Spatial5ArrayAnom(sst,weightedInd,sstClm,ClmInd)    ; calc top5 anomaly

targetice        = icec(0,:,:) ; stupid initialization
targetice        = dim_avg_n_Wrap(icec(thetime-exmth:thetime,:,:),0)
targeticeanom    = icec(0,:,:) ; stupid initialization
targeticeanom    = dim_avg_n_Wrap(icec(thetime-exmth:thetime,:,:),0) - dim_avg_n_Wrap(iceClm(usermonth+12-1-exmth:usermonth+12-1,:,:),0)
top5ice          = Spatial5Array(icec,weightedInd)                      ; spatial array of top 5 best analogs
top5iceAnom      = Spatial5ArrayAnom(icec,weightedInd,iceClm,ClmInd)    ; calc top5 anomaly

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ends section that populates the annual
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; (top 5) arrays





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Plot the usermonth(s)/year and each
;;; of the 5 analogs
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
maxVerifyIndex = thetime+fmnths+fmnths2-1
dimsz = dimsizes(sst)

if (variable .eq. 1) then
  varName = "SLP"
  varUnits = "mb"
  cdfAll = slp
  cdfClm = slpClm
  top5 = top5slp
  top5anom = top5slpAnom
  targetanom = targetslpanom
  sortInx = wwww
  r_val = r_square_slp
  if(maxVerifyIndex.lt.theMaxDimsizes) then
    verify = dim_avg_n_Wrap(slp(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    verifyanom =  dim_avg_n_Wrap(slp(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(slpClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  sel_ave_sd = slp_red_ave_sd
  sctArr = slpArray2
  AksctArr = AKslpArray
  AKverifyRMS = AKboxslpArray3
  AKforCor= AKboxslpArray4
  theVariableCorArray = mySLPCorArray
  lowRange = -8.0
  highRange = 8.0
  interval = 1.0
end if

if (variable .eq. 2) then
  varName = "H500"
  varName = "Z"+getlev(heightlev)
  varUnits = "m"
  cdfAll = h500
  cdfClm = h500Clm
  top5 = top5h500
  top5anom = top5h500Anom
  targetanom = targeth500anom
  sortInx = wwww
  r_val = r_square_h500
  if(maxVerifyIndex.lt.theMaxDimsizes) then
    verify = dim_avg_n_Wrap(h500(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    verifyanom =  dim_avg_n_Wrap(h500(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(h500Clm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  sel_ave_sd = h500_red_ave_sd
  sctArr = h500Array2
  AksctArr = AKh500Array
  AKverifyRMS = AKboxh500Array3
  AKforCor= AKboxh500Array4
  theVariableCorArray = myH500CorArray
  lowRange = -90.0
  highRange = 90.0
  interval = 15.0
end if


if (variable .eq. 3) then
  varName = "T2M"
  varUnits = "C"
  cdfAll = t2m
  cdfClm = t2mClm
  top5 = top5t2m
  top5anom = top5t2mAnom
  targetanom = targett2manom
  sortInx = wwww
  r_val = r_square_t2m
  if(maxVerifyIndex.lt.theMaxDimsizes) then
    verify = dim_avg_n_Wrap(t2m(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    verifyanom =  dim_avg_n_Wrap(t2m(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(t2mClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  sel_ave_sd = t2m_red_ave_sd
  sctArr = t2mArray2
  AksctArr = AKt2mArray
  AKverifyRMS = AKboxt2mArray3
  AKforCor= AKboxt2mArray4
  theVariableCorArray = myT2MCorArray
  lowRange = -8.0
  highRange = 8.0
  interval = 0.5
end if

if (variable .eq. 4) then
  varName = "T925"
  varName = "T"+getlev(templev)
  varUnits = "C"
  cdfAll = t925
  cdfClm = t925Clm
  top5 = top5t925
  top5anom = top5t925Anom
  targetanom = targett925anom
  sortInx = wwww
  r_val = r_square_t925
  if(maxVerifyIndex.lt.theMaxDimsizes) then
    verify = dim_avg_n_Wrap(t925(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    verifyanom =  dim_avg_n_Wrap(t925(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(t925Clm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  sel_ave_sd = t925_red_ave_sd
  sctArr = t925Array2
  AksctArr = AKt925Array
  AKverifyRMS = AKboxt925Array3
  AKforCor= AKboxt925Array4
  theVariableCorArray = myT925CorArray
  lowRange = -8.0
  highRange = 8.0
  interval = 0.5
end if


if (variable .eq. 5) then
  varName = "SST"
  varUnits = "C"
  cdfAll = sst
  cdfClm = sstClm
  top5 = top5sst
  top5anom = top5sstAnom
  targetanom = targetsstanom
  sortInx = wwww
  r_val = r_square_sst
  if(maxVerifyIndex.lt.theMaxDimsizes) then
    verify = dim_avg_n_Wrap(sst(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    verifyanom =  dim_avg_n_Wrap(sst(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(sstClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  sel_ave_sd = sst_red_ave_sd
  sctArr = sstArray2
  AksctArr = AKsstArray
  AKverifyRMS = AKboxsstArray3
  AKforCor= AKboxsstArray4
  theVariableCorArray = mySSTCorArray
  lowRange = -3.0
  highRange = 3.0
  interval = 0.3
end if


if (variable .eq. 6) then
  varName = "Precip"
  varUnits = "kg/sq m/day"
  cdfAll = icec
  cdfClm = iceClm
  top5 = top5ice
  top5anom = top5iceAnom
  targetanom = targeticeanom
  sortInx = wwww
  r_val = r_square_ice
  if(maxVerifyIndex.lt.theMaxDimsizes) then
    verify = dim_avg_n_Wrap(icec(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    verifyanom =  dim_avg_n_Wrap(icec(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(iceClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  sel_ave_sd = ice_red_ave_sd
  sctArr = iceArray2
  AksctArr = AKiceArray
  AKverifyRMS = AKboxiceArray3
  AKforCor= AKboxiceArray4
  theVariableCorArray = myICECorArray
  lowRange =  -0.5
  highRange = 0.5
  interval =  0.1
end if



boxres = True
boxres = SetBoxRes("NavyBlue")
AKboxres = True
;AKboxres = SetBoxRes("Red")
AKboxres = SetBoxRes("darkgreen")
AKboxgreen = True
AKboxgreen = SetBoxRes("darkgreen")
plot6PanelA = new(6,graphic)
plot6PanelB = new(6,graphic)
rr = "Output_"+ID + "_"+autoWgt+"_"+month_Name(usermonth)+"_"+tostring(x1)+ "_"+tostring(x2) + "_"+tostring(y1) + "_"+tostring(y2)+"_"+varName+"_Current"
rr2 = "Output_"+ID + "_"+autoWgt+"_"+month_Name(usermonth)+"_"+tostring(x1)+ "_"+tostring(x2) + "_"+tostring(y1) + "_"+tostring(y2)+"_"+varName+"_Forward"
rr3 = "Output_"+ID + "_"+autoWgt+"_"+month_Name(usermonth)+"_"+tostring(x1)+ "_"+tostring(x2) + "_"+tostring(y1) + "_"+tostring(y2)+"_"+varName+"_Verify"
rr4 = "Output_"+ID + "_"+autoWgt+"_"+month_Name(usermonth)+"_"+tostring(x1)+ "_"+tostring(x2) + "_"+tostring(y1) + "_"+tostring(y2)+"_"+varName+"_A_Scatter1"
rr5 = "Output_"+ID + "_"+autoWgt+"_"+month_Name(usermonth)+"_"+tostring(x1)+ "_"+tostring(x2) + "_"+tostring(y1) + "_"+tostring(y2)+"_"+varName+"_G_Scatter2"
rr6 = "Output_"+ID + "_"+autoWgt+"_"+month_Name(usermonth)+"_"+tostring(x1)+ "_"+tostring(x2) + "_"+tostring(y1) + "_"+tostring(y2)+"_"+varName+"_XSea_Ice_Chart"




wtype           = "png"
wtype@wkWidth  = 1000
wtype@wkHeight = 1000



res = True




wks_pan = gsn_open_wks(wtype,filedir+"pan_a")
res = SetRes1(lowRange, highRange, interval,25,210)
AKdiff = W_ave(cdfAll,thetime-exmth,thetime,y1,y2,x1,x2)
AKdiff2 = W_ave(cdfAll,thetime-exmth,thetime,y1,y2,x1,x2) - W_ave(cdfClm,usermonth+12-1-exmth,usermonth+12-1,y1,y2,x1,x2)
res@tiXAxisString = varName+" Anomaly for " + monthRangeString1 + " " + useryearString1 + "~C~Ave For Analysis Area is "+sprintf("%6.3f",AKdiff)+" "+varUnits+ "~C~Ave Anom For Forecast Area is "+sprintf("%6.3f",AKdiff2)+" "+varUnits+".~C~(c) University of Alaska Fairbanks"
plot0 = gsn_csm_contour_map_polar(wks_pan,targetanom,res)
poly0a = gsn_add_polyline(wks_pan,plot0,lon_box,lat_box,boxres)
poly0b = gsn_add_polyline(wks_pan,plot0,AKlon_box,AKlat_box,AKboxres)
draw(plot0)
frame(wks_pan)
delete(wks_pan)

wks_pan = gsn_open_wks(wtype,filedir+"pan_b")
res = SetRes1(lowRange/4.0, highRange/4.0, interval/2.0,25,210)
tempvar2 = cdfAll(0,:,:)
tempvar2 = dim_avg_n_Wrap(top5(0:numAnalogsToUse-1,:,:),0) - dim_avg_n_Wrap(cdfClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
;tempvar2 = (dim_avg_n_Wrap(top5(0:numAnalogsToUse-1,:,:),0) - dim_avg_n_Wrap(cdfClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0) ) * 5.0
AKdiff = W_ave(top5anom,0,numAnalogsToUse-1,AK1,AK2,AK3,AK4)
res@tiXAxisString = varName+" Anomaly forecast during " + monthRangeString2 +" time period.~C~Using top 5 analogs for " + monthRangeString1 + " " + useryear + ".~C~Years are : "+YearArray(sortInx(ii))+", "+YearArray(sortInx(ii+1))+", "+YearArray(sortInx(ii+2))+", "+YearArray(sortInx(ii+3))+", and "+YearArray(sortInx(ii+4))+"."+"~C~(c) University of Alaska Fairbanks"
if(numAnalogsToUse.eq.4) then
  res@tiXAxisString = varName+" Anomaly forecast during " + monthRangeString2 +" time period.~C~Using top 4 analogs for " + monthRangeString1 + " " + useryear + ".~C~Years are : "+YearArray(sortInx(ii))+", "+YearArray(sortInx(ii+1))+", "+YearArray(sortInx(ii+2))+", and "+YearArray(sortInx(ii+3))+"."+"~C~(c) University of Alaska Fairbanks"
end if
if(numAnalogsToUse.eq.3) then
  res@tiXAxisString = varName+" Anomaly forecast during " + monthRangeString2 +" time period.~C~Using top 3 analogs for " + monthRangeString1 + " " + useryear + ".~C~Years are : "+YearArray(sortInx(ii))+", "+YearArray(sortInx(ii+1))+", and "+YearArray(sortInx(ii+2))+"."+"~C~(c) University of Alaska Fairbanks"
end if
if(numAnalogsToUse.eq.2) then
  res@tiXAxisString = varName+" Anomaly forecast during " + monthRangeString2 +" time period.~C~Using top 2 analogs for " + monthRangeString1 + " " + useryear + ".~C~Years are : "+YearArray(sortInx(ii))+" and "+YearArray(sortInx(ii+1))+"."+"~C~(c) University of Alaska Fairbanks"
end if
if(numAnalogsToUse.eq.1) then
  res@tiXAxisString = varName+" Anomaly forecast during " + monthRangeString2 +" time period.~C~Using top analogs for " + monthRangeString1 + " " + useryear + ".~C~Years are : "+YearArray(sortInx(ii))+"."+"~C~ "+"   "
end if
plotX0 = gsn_csm_contour_map_polar(wks_pan,tempvar2,res)
polyX0a = gsn_add_polyline(wks_pan,plotX0,lon_box,lat_box,boxres)
polyX0b = gsn_add_polyline(wks_pan,plotX0,AKlon_box,AKlat_box,AKboxres)
plot6PanelB(0) = plotX0
draw(plotX0)
frame(wks_pan)
delete(wks_pan)
res = SetRes1(lowRange, highRange, interval,25,210)




wks_pan = gsn_open_wks(wtype,filedir+"pan_a1")
index1= tointeger(((YearArray(sortInx(ii))-1948)*12)+ usermonth - 1 - exmth)
index2= tointeger(((YearArray(sortInx(ii))-1948)*12)+ usermonth - 1)
tempvar2 = cdfAll(0,:,:)
tempvar2 = dim_avg_n_Wrap(cdfAll(index1:index2,:,:),0) - dim_avg_n_Wrap(cdfClm(usermonth-1+12-exmth:usermonth-1+12,:,:),0)
tempDiff = W_ave(cdfAll,index1,index2,y1,y2,x1,x2) - W_ave(cdfAll,thetime-exmth,thetime,y1,y2,x1,x2)
res@tiXAxisString = "Analog #1: " + varName+" Anomaly for "+ monthRangeString1 + " " + YearArray(sortInx(ii))+ ". ~C~" + monthRangeString1 + " " + YearArray(sortInx(ii)) + " (-) " + monthRangeString1 + " " + useryearString1+ " = " +  sprintf("%6.3f",tempDiff)+" "+varUnits+"."+"~C~RMS Match Score =" + sprintf("%6.3f",weightedArray1(wwww(ii)))+"~C~(c) University of Alaska Fairbanks"
plot1 = gsn_csm_contour_map_polar(wks_pan,tempvar2,res)
poly1a = gsn_add_polyline(wks_pan,plot1,lon_box,lat_box,boxres)
poly1b = gsn_add_polyline(wks_pan,plot1,AKlon_box,AKlat_box,AKboxres)
plot6PanelA(1) = plot1
draw(plot1)
frame(wks_pan)
delete(wks_pan)
wks_pan = gsn_open_wks(wtype,filedir+"pan_b1")
AKdiff = W_ave(top5anom,0,0,AK1,AK2,AK3,AK4)
res@tiXAxisString = monthRangeString2 + " " + varName + " Anomaly for Analog #1~C~  Following " + monthRangeString1 + " " + YearArray(sortInx(ii)) +"~C~Forecast Area Anom is " + sprintf("%6.3f",AKdiff)+" " + varUnits + "."+"~C~(c) University of Alaska Fairbanks"
plotX1 = gsn_csm_contour_map_polar(wks_pan,top5anom(0,:,:),res)
polyX1a = gsn_add_polyline(wks_pan,plotX1,lon_box,lat_box,boxres)
polyX1b = gsn_add_polyline(wks_pan,plotX1,AKlon_box,AKlat_box,AKboxres)
plot6PanelB(1) = plotX1
draw(plotX1)
frame(wks_pan)
delete(wks_pan)



wks_pan = gsn_open_wks(wtype,filedir+"pan_a2")
index1= tointeger(((YearArray(sortInx(ii+1))-1948)*12)+ usermonth - 1 - exmth)
index2= tointeger(((YearArray(sortInx(ii+1))-1948)*12)+ usermonth - 1)
tempvar2 = cdfAll(0,:,:)
tempvar2 = dim_avg_n_Wrap(cdfAll(index1:index2,:,:),0) - dim_avg_n_Wrap(cdfClm(usermonth-1+12-exmth:usermonth-1+12,:,:),0)
tempDiff = W_ave(cdfAll,index1,index2,y1,y2,x1,x2) - W_ave(cdfAll,thetime-exmth,thetime,y1,y2,x1,x2)
res@tiXAxisString = "Analog #2: " + varName+" Anomaly for "+ monthRangeString1 + " " + YearArray(sortInx(ii+1))+ ". ~C~" + monthRangeString1 + " " + YearArray(sortInx(ii+1)) + " (-) " + monthRangeString1 + " " + useryearString1+ " = " +  sprintf("%6.3f",tempDiff)+" "+varUnits+"."+"~C~RMS Match Score =" + sprintf("%6.3f",weightedArray1(wwww(ii+1)))+"~C~(c) University of Alaska Fairbanks"
plot2 = gsn_csm_contour_map_polar(wks_pan,tempvar2,res)
poly2a = gsn_add_polyline(wks_pan,plot2,lon_box,lat_box,boxres)
poly2b = gsn_add_polyline(wks_pan,plot2,AKlon_box,AKlat_box,AKboxres)
plot6PanelA(2) = plot2
draw(plot2)
frame(wks_pan)
delete(wks_pan)
wks_pan = gsn_open_wks(wtype,filedir+"pan_b2")
AKdiff = W_ave(top5anom,1,1,AK1,AK2,AK3,AK4)
res@tiXAxisString = monthRangeString2 + " " + varName + " Anomaly for Analog #2~C~  Following " + monthRangeString1 + " " + YearArray(sortInx(ii+1)) +"~C~Red Box Anomaly is " + sprintf("%6.3f",AKdiff)+" " + varUnits + "." +"~C~(c) University of Alaska Fairbanks"
plotX2 = gsn_csm_contour_map_polar(wks_pan,top5anom(1,:,:),res)
polyX2a = gsn_add_polyline(wks_pan,plotX2,lon_box,lat_box,boxres)
polyX2b = gsn_add_polyline(wks_pan,plotX2,AKlon_box,AKlat_box,AKboxres)
plot6PanelB(2) = plotX2
draw(plotX2)
frame(wks_pan)
delete(wks_pan)






wks_pan = gsn_open_wks(wtype,filedir+"pan_a3")
index1= tointeger(((YearArray(sortInx(ii+2))-1948)*12)+ usermonth - 1 - exmth)
index2= tointeger(((YearArray(sortInx(ii+2))-1948)*12)+ usermonth - 1)
tempvar2 = cdfAll(0,:,:)
tempvar2 = dim_avg_n_Wrap(cdfAll(index1:index2,:,:),0) - dim_avg_n_Wrap(cdfClm(usermonth-1+12-exmth:usermonth-1+12,:,:),0)
tempDiff = W_ave(cdfAll,index1,index2,y1,y2,x1,x2) - W_ave(cdfAll,thetime-exmth,thetime,y1,y2,x1,x2)
res@tiXAxisString = "Analog #3: " + varName+" Anomaly for "+ monthRangeString1 + " " + YearArray(sortInx(ii+2))+ ". ~C~" + monthRangeString1 + " " + YearArray(sortInx(ii+2)) + " (-) " + monthRangeString1 + " " + useryearString1+ " = " +  sprintf("%6.3f",tempDiff)+" "+varUnits+"."+"~C~RMS Match Score =" + sprintf("%6.3f",weightedArray1(wwww(ii+2)))+"~C~(c) University of Alaska Fairbanks"
plot3 = gsn_csm_contour_map_polar(wks_pan,tempvar2,res)
poly3a = gsn_add_polyline(wks_pan,plot3,lon_box,lat_box,boxres)
poly3b = gsn_add_polyline(wks_pan,plot3,AKlon_box,AKlat_box,AKboxres)
plot6PanelA(3) = plot3
draw(plot3)
frame(wks_pan)
delete(wks_pan)
wks_pan = gsn_open_wks(wtype,filedir+"pan_b3")
AKdiff = W_ave(top5anom,2,2,AK1,AK2,AK3,AK4)
res@tiXAxisString = monthRangeString2 + " " + varName + " Anomaly for Analog #3~C~  Following " + monthRangeString1 + " " + YearArray(sortInx(ii+2)) +"~C~Red Box Anomaly is " + sprintf("%6.3f",AKdiff)+" " + varUnits + "."+"~C~(c) University of Alaska Fairbanks"
plotX3 = gsn_csm_contour_map_polar(wks_pan,top5anom(2,:,:),res)
polyX3a = gsn_add_polyline(wks_pan,plotX3,lon_box,lat_box,boxres)
polyX3b = gsn_add_polyline(wks_pan,plotX3,AKlon_box,AKlat_box,AKboxres)
plot6PanelB(3) = plotX3
draw(plotX3)
frame(wks_pan)
delete(wks_pan)


wks_pan = gsn_open_wks(wtype,filedir+"pan_a4")
index1= tointeger(((YearArray(sortInx(ii+3))-1948)*12)+ usermonth - 1 - exmth)
index2= tointeger(((YearArray(sortInx(ii+3))-1948)*12)+ usermonth - 1)
tempvar2 = cdfAll(0,:,:)
tempvar2 = dim_avg_n_Wrap(cdfAll(index1:index2,:,:),0) - dim_avg_n_Wrap(cdfClm(usermonth-1+12-exmth:usermonth-1+12,:,:),0)
tempDiff = W_ave(cdfAll,index1,index2,y1,y2,x1,x2) - W_ave(cdfAll,thetime-exmth,thetime,y1,y2,x1,x2)
res@tiXAxisString = "Analog #4: " + varName+" Anomaly for "+ monthRangeString1 + " " + YearArray(sortInx(ii+3))+ ". ~C~" + monthRangeString1 + " " + YearArray(sortInx(ii+3)) + " (-) " + monthRangeString1 + " " + useryearString1+ " = " +  sprintf("%6.3f",tempDiff)+" "+varUnits+"."+"~C~RMS Match Score =" + sprintf("%6.3f",weightedArray1(wwww(ii+3)))+"~C~(c) University of Alaska Fairbanks"
plot4 = gsn_csm_contour_map_polar(wks_pan,tempvar2,res)
poly4a = gsn_add_polyline(wks_pan,plot4,lon_box,lat_box,boxres)
poly4b = gsn_add_polyline(wks_pan,plot4,AKlon_box,AKlat_box,AKboxres)
plot6PanelA(4) = plot4
draw(plot4)
frame(wks_pan)
delete(wks_pan)
wks_pan = gsn_open_wks(wtype,filedir+"pan_b4")
AKdiff = W_ave(top5anom,3,3,AK1,AK2,AK3,AK4)
res@tiXAxisString = monthRangeString2 + " " + varName + " Anomaly for Analog #3~C~  Following " + monthRangeString1 + " " + YearArray(sortInx(ii+3)) +"~C~Red Box Anomaly is " + sprintf("%6.3f",AKdiff)+" " + varUnits + "."+"~C~(c) University of Alaska Fairbanks"
plotX4 = gsn_csm_contour_map_polar(wks_pan,top5anom(3,:,:),res)
polyX4a = gsn_add_polyline(wks_pan,plotX4,lon_box,lat_box,boxres)
polyX4b = gsn_add_polyline(wks_pan,plotX4,AKlon_box,AKlat_box,AKboxres)
plot6PanelB(4) = plotX4
draw(plotX4)
frame(wks_pan)
delete(wks_pan)


wks_pan = gsn_open_wks(wtype,filedir+"pan_a5")
index1= tointeger(((YearArray(sortInx(ii+4))-1948)*12)+ usermonth - 1 - exmth)
index2= tointeger(((YearArray(sortInx(ii+4))-1948)*12)+ usermonth - 1)
tempvar2 = cdfAll(0,:,:)
tempvar2 = dim_avg_n_Wrap(cdfAll(index1:index2,:,:),0) - dim_avg_n_Wrap(cdfClm(usermonth-1+12-exmth:usermonth-1+12,:,:),0)
tempDiff = W_ave(cdfAll,index1,index2,y1,y2,x1,x2) - W_ave(cdfAll,thetime-exmth,thetime,y1,y2,x1,x2)
res@tiXAxisString = "Analog #5: " + varName+" Anomaly for "+ monthRangeString1 + " " + YearArray(sortInx(ii+4))+ ". ~C~" + monthRangeString1 + " " + YearArray(sortInx(ii+4)) + " (-) " + monthRangeString1 + " " + useryearString1+ " = " +  sprintf("%6.3f",tempDiff)+" "+varUnits+"."+"~C~RMS Match Score =" + sprintf("%6.3f",weightedArray1(wwww(ii+4)))+"~C~(c) University of Alaska Fairbanks"
plot5 = gsn_csm_contour_map_polar(wks_pan,tempvar2,res)
poly5a = gsn_add_polyline(wks_pan,plot5,lon_box,lat_box,boxres)
poly5b = gsn_add_polyline(wks_pan,plot5,AKlon_box,AKlat_box,AKboxres)
plot6PanelA(5) = plot5
draw(plot5)
frame(wks_pan)
delete(wks_pan)
wks_pan = gsn_open_wks(wtype,filedir+"pan_b5")
AKdiff = W_ave(top5anom,4,4,AK1,AK2,AK3,AK4)
res@tiXAxisString = monthRangeString2 + " " + varName + " Anomaly for Analog #5~C~  Following " + monthRangeString1 + " " + YearArray(sortInx(ii+4)) +"~C~Red Box Anomaly is " + sprintf("%6.3f",AKdiff)+" " + varUnits + "."+"~C~(c) University of Alaska Fairbanks"
plotX5 = gsn_csm_contour_map_polar(wks_pan,top5anom(4,:,:),res)
polyX5a = gsn_add_polyline(wks_pan,plotX5,lon_box,lat_box,boxres)
polyX5b = gsn_add_polyline(wks_pan,plotX5,AKlon_box,AKlat_box,AKboxres)
plot6PanelB(5) = plotX5
draw(plotX5)
frame(wks_pan)
delete(wks_pan)

;; delete existing image files
  zz = systemfunc("rm -f "+output_dir+"/a.png")
  zz = systemfunc("rm -f "+output_dir+"/a1.png")
  zz = systemfunc("rm -f "+output_dir+"/a2.png")
  zz = systemfunc("rm -f "+output_dir+"/a3.png")
  zz = systemfunc("rm -f "+output_dir+"/a4.png")
  zz = systemfunc("rm -f "+output_dir+"/a5.png")
  zz = systemfunc("rm -f "+output_dir+"/b.png")
  zz = systemfunc("rm -f "+output_dir+"/b1.png")
  zz = systemfunc("rm -f "+output_dir+"/b2.png")
  zz = systemfunc("rm -f "+output_dir+"/b3.png")
  zz = systemfunc("rm -f "+output_dir+"/b4.png")
  zz = systemfunc("rm -f "+output_dir+"/b5.png")
  zz = systemfunc("rm -f "+output_dir+"/ice1.png")
  zz = systemfunc("rm -f "+output_dir+"/s1.png")
  zz = systemfunc("rm -f "+output_dir+"/s2.png")
  zz = systemfunc("rm -f "+output_dir+"/v1.png")
  zz = systemfunc("rm -f "+output_dir+"/v.png")

  zz = systemfunc("mv -f "+filedir+"pan_a.png "+output_dir+"/pan_a.png")
  zz = systemfunc("convert "+output_dir+"/pan_a.png -crop 800x1000+50+0 "+output_dir+"/a.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_a.png")
  zz = systemfunc("mv -f "+filedir+"pan_b.png "+output_dir+"/pan_b.png")
  zz = systemfunc("convert "+output_dir+"/pan_b.png -crop 800x1000+50+0 "+output_dir+"/b.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_b.png")

  zz = systemfunc("mv -f "+filedir+"pan_a1.png "+output_dir+"/pan_a1.png")
  zz = systemfunc("convert "+output_dir+"/pan_a1.png -crop 800x1000+50+0 "+output_dir+"/a1.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_a1.png")
  zz = systemfunc("mv -f "+filedir+"pan_b1.png "+output_dir+"/pan_b1.png")
  zz = systemfunc("convert "+output_dir+"/pan_b1.png -crop 800x1000+50+0 "+output_dir+"/b1.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_b1.png")

  zz = systemfunc("mv -f "+filedir+"pan_a2.png "+output_dir+"/pan_a2.png")
  zz = systemfunc("convert "+output_dir+"/pan_a2.png -crop 800x1000+50+0 "+output_dir+"/a2.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_a2.png")
  zz = systemfunc("mv -f "+filedir+"pan_b2.png "+output_dir+"/pan_b2.png")
  zz = systemfunc("convert "+output_dir+"/pan_b2.png -crop 800x1000+50+0 "+output_dir+"/b2.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_b2.png")

  zz = systemfunc("mv -f "+filedir+"pan_a3.png "+output_dir+"/pan_a3.png")
  zz = systemfunc("convert "+output_dir+"/pan_a3.png -crop 800x1000+50+0 "+output_dir+"/a3.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_a3.png")
  zz = systemfunc("mv -f "+filedir+"pan_b3.png "+output_dir+"/pan_b3.png")
  zz = systemfunc("convert "+output_dir+"/pan_b3.png -crop 800x1000+50+0 "+output_dir+"/b3.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_b3.png")

  zz = systemfunc("mv -f "+filedir+"pan_a4.png "+output_dir+"/pan_a4.png")
  zz = systemfunc("convert "+output_dir+"/pan_a4.png -crop 800x1000+50+0 "+output_dir+"/a4.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_a4.png")
  zz = systemfunc("mv -f "+filedir+"pan_b4.png "+output_dir+"/pan_b4.png")
  zz = systemfunc("convert "+output_dir+"/pan_b4.png -crop 800x1000+50+0 "+output_dir+"/b4.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_b4.png")

  zz = systemfunc("mv -f "+filedir+"pan_a5.png "+output_dir+"/pan_a5.png")
  zz = systemfunc("convert "+output_dir+"/pan_a5.png -crop 800x1000+50+0 "+output_dir+"/a5.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_a5.png")
  zz = systemfunc("mv -f "+filedir+"pan_b5.png "+output_dir+"/pan_b5.png")
  zz = systemfunc("convert "+output_dir+"/pan_b5.png -crop 800x1000+50+0 "+output_dir+"/b5.png")
  zz = systemfunc("rm -f "+output_dir+"/pan_b5.png")


; TODO remove this, not needed
if (numAnalogsToUse.lt.5) then
  zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/a5.png")
  zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/b5.png")
end if
if (numAnalogsToUse.lt.4) then
  zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/a4.png")
  zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/b4.png")
end if
if (numAnalogsToUse.lt.3) then
  zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/a3.png")
  zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/b3.png")
end if
if (numAnalogsToUse.lt.2) then
  zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/a2.png")
  zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/b2.png")
end if




; TODO remove after ensuring not needed
  ; text2 = "Top 5 Atmospheric Match Years Are: "+YearArray(wwww(ii))+", "+YearArray(wwww(ii+1))+", "+YearArray(wwww(ii+2))+", "+YearArray(wwww(ii+3))+", and "+YearArray(wwww(ii+4))+"."
  ; if (numAnalogsToUse.eq.4) then
  ;   text2 = "Top 4 Atmospheric Match Years Are: "+YearArray(wwww(ii))+", "+YearArray(wwww(ii+1))+", "+YearArray(wwww(ii+2))+", and "+YearArray(wwww(ii+3))+"."
  ; end if
  ; if (numAnalogsToUse.eq.3) then
  ;   text2 = "Top 3 Atmospheric Match Years Are: "+YearArray(wwww(ii))+", "+YearArray(wwww(ii+1))+", and "+YearArray(wwww(ii+2))+"."
  ; end if
  ; if (numAnalogsToUse.eq.2) then
  ;   text2 = "Top 2 Atmospheric Match Years Are: "+YearArray(wwww(ii))+" and "+YearArray(wwww(ii+1))+"."
  ; end if
  ; if (numAnalogsToUse.eq.1) then
  ;   text2 = "Top Atmospheric Match Year Is: "+YearArray(wwww(ii))+"."
  ; end if
  ; asciiwrite (output_dir+"text2.txt" , text2)
  ; zz = systemfunc("mv -f "+filedir+"text2.txt "+output_dir+"/text2.txt")

  ; text3 = "SLP:"+sprintf("%6.2f",slpwgt)+", Z"+getlev(heightlev)+":"+sprintf("%6.2f",h500wgt)+", T2M:"+sprintf("%6.2f",t2mwgt)+", T"+getlev(templev)+":"+sprintf("%6.2f",t925wgt)+", SST:"+sprintf("%6.2f",sstwgt)+"."

  ; if(domanual.eq.True) then
  ;   if(manualyesno.eq.1) then
  ;     text3 = "No weighting performed due to manual year selection."
  ;   end if
  ; end if





asciiwrite (filedir+"rms1.txt" , sprintf("%6.3f",weightedArray1(wwww(ii))))
asciiwrite (filedir+"rms2.txt" , sprintf("%6.3f",weightedArray1(wwww(ii+1))))
asciiwrite (filedir+"rms3.txt" , sprintf("%6.3f",weightedArray1(wwww(ii+2))))
asciiwrite (filedir+"rms4.txt" , sprintf("%6.3f",weightedArray1(wwww(ii+3))))
asciiwrite (filedir+"rms5.txt" , sprintf("%6.3f",weightedArray1(wwww(ii+4))))
asciiwrite (filedir+"slpyears.txt" , weightedSLPString)
asciiwrite (filedir+"h500years.txt" , weightedH500String)
asciiwrite (filedir+"t2myears.txt" , weightedT2MString)
asciiwrite (filedir+"t925years.txt" , weightedT925String)
asciiwrite (filedir+"sstyears.txt" , weightedSSTString)
asciiwrite (filedir+"iceyears.txt" , weightedICEString)
asciiwrite (filedir+"heightlevel.txt" , getlev(heightlev))
asciiwrite (filedir+"templevel.txt" , getlev(templev))

text2 = "Top 5 Atmospheric Match Years Are: "+YearArray(wwww(ii))+", "+YearArray(wwww(ii+1))+", "+YearArray(wwww(ii+2))+", "+YearArray(wwww(ii+3))+", and "+YearArray(wwww(ii+4))+"."
if (numAnalogsToUse.eq.4) then
    text2 = "Top 4 Atmospheric Match Years Are: "+YearArray(wwww(ii))+", "+YearArray(wwww(ii+1))+", "+YearArray(wwww(ii+2))+", and "+YearArray(wwww(ii+3))+"."
end if
if (numAnalogsToUse.eq.3) then
    text2 = "Top 3 Atmospheric Match Years Are: "+YearArray(wwww(ii))+", "+YearArray(wwww(ii+1))+", and "+YearArray(wwww(ii+2))+"."
end if
if (numAnalogsToUse.eq.2) then
    text2 = "Top 2 Atmospheric Match Years Are: "+YearArray(wwww(ii))+" and "+YearArray(wwww(ii+1))+"."
end if
if (numAnalogsToUse.eq.1) then
    text2 = "Top  Atmospheric Match Year Is: "+YearArray(wwww(ii))+"."
end if
asciiwrite (filedir+"text2.txt" , text2)
text3 = "SLP:"+sprintf("%6.2f",slpwgt)+", Z"+getlev(heightlev)+":"+sprintf("%6.2f",h500wgt)+", T2M:"+sprintf("%6.2f",t2mwgt)+", T"+getlev(templev)+":"+sprintf("%6.2f",t925wgt)+", SST:"+sprintf("%6.2f",sstwgt)+"."
if(domanual.eq.True) then
    if(manualyesno.eq.1) then
        text3 = "No weighting performed due to manual year selection."
    end if
end if
asciiwrite (filedir+"text3.txt" , text3)
asciiwrite (filedir+"year1.txt" , YearArray(wwww(ii)))
asciiwrite (filedir+"year2.txt" , YearArray(wwww(ii+1)))
asciiwrite (filedir+"year3.txt" , YearArray(wwww(ii+2)))
asciiwrite (filedir+"year4.txt" , YearArray(wwww(ii+3)))
asciiwrite (filedir+"year5.txt" , YearArray(wwww(ii+4)))
asciiwrite (filedir+"verstr.txt" , "Since the forecast month is in the future, there are no verification statistics to report")

; TODO remove
; zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/v.png")
; zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/v3.png")


resP                  = True                    ; modify the panel plot
resP@gsnFrame         = True                    ; don't advance panel plot
resP@gsnPanelLabelBar = False                   ; add common colorbar



;; Verification plot (only if possible)
b=thetime+fmnths+fmnths2-1


if (b.lt.totalDims) then

  if (variable .eq. 1) then
    sel_verify =  dim_avg_n_Wrap(slp(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    sel_verifyanom =  dim_avg_n_Wrap(slp(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(slpClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  if (variable .eq. 2) then
    sel_verify = dim_avg_n_Wrap(h500(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    sel_verifyanom =  dim_avg_n_Wrap(h500(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(h500Clm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  if (variable .eq. 3) then
    sel_verify = dim_avg_n_Wrap(t2m(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    sel_verifyanom =  dim_avg_n_Wrap(t2m(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(t2mClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  if (variable .eq. 4) then
    sel_verify = dim_avg_n_Wrap(t925(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    sel_verifyanom =  dim_avg_n_Wrap(t925(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(t925Clm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  if (variable .eq. 5) then
    sel_verify = dim_avg_n_Wrap(sst(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    sel_verifyanom =  dim_avg_n_Wrap(sst(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(sstClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if
  if (variable .eq. 6) then
    sel_verify = dim_avg_n_Wrap(icec(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0)
    sel_verifyanom =  dim_avg_n_Wrap(icec(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:),0) - dim_avg_n_Wrap(iceClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  end if


  ; check to see how well it went (Find Ranking)

  top6 = cdfAll(0:9,:,:)
  top6(0,:,:)=top5(0,:,:)
  top6(1,:,:)=top5(1,:,:)
  top6(2,:,:)=top5(2,:,:)
  top6(3,:,:)=top5(3,:,:)
  top6(4,:,:)=top5(4,:,:)
  top6(5,:,:)=sel_verify(:,:)
  top6(6,:,:)=sel_verify(:,:)
  top6(7,:,:)=sel_verify(:,:)
  top6(8,:,:)=sel_verify(:,:)
  top6(9,:,:)=sel_verify(:,:)

  loopsize = weightedInd(5)-weightedInd(0)

  x=top6(0:0,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  y=top6(5:5,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  a5 = abs(wgt_arearmse(x,y,clat,1.0,0))

  x=top6(1:1,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  y=top6(5:5,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  b5 = abs(wgt_arearmse(x,y,clat,1.0,0))

  x=top6(2:2,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  y=top6(5:5,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  c5 = abs(wgt_arearmse(x,y,clat,1.0,0))

  x=top6(3:3,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  y=top6(5:5,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  d5 = abs(wgt_arearmse(x,y,clat,1.0,0))

  x=top6(4:4,{AK1:AK2},{AK3:AK4})
  xlat=x&lat
  y=top6(5:5,{AK1:AK2},{AK3:AK4})
  clat=cos((4.*atan(1.)/180.)*xlat)
  e5 = abs(wgt_arearmse(x,y,clat,1.0,0))
  delete(x)
  delete(y)
  delete(xlat)
  delete(clat)

  a5=0
  b5=0
  c5=0
  d5=0
  e5=0
  do yy=0,loopsize
    aw = cdfAll(weightedInd(0)+yy,{AK1:AK2},{AK3:AK4})
    awlat = aw&lat
    itme = cdfAll(thetime+fmnths+yy,{AK1:AK2},{AK3:AK4})
    wclat = cos((4.*atan(1.)/180.)*awlat)
    a5 = a5 + abs(wgt_arearmse(aw,itme,wclat,1.0,0))
    bw = cdfAll(weightedInd(1)+yy,{AK1:AK2},{AK3:AK4})
    b5 = b5 + abs(wgt_arearmse(bw,itme,wclat,1.0,0))
    cw = cdfAll(weightedInd(2)+yy,{AK1:AK2},{AK3:AK4})
    c5 = c5 + abs(wgt_arearmse(cw,itme,wclat,1.0,0))
    dw = cdfAll(weightedInd(3)+yy,{AK1:AK2},{AK3:AK4})
    d5 = d5 + abs(wgt_arearmse(dw,itme,wclat,1.0,0))
    ew = cdfAll(weightedInd(4)+yy,{AK1:AK2},{AK3:AK4})
    e5 = e5 + abs(wgt_arearmse(ew,itme,wclat,1.0,0))
  end do
  a5 = a5/(loopsize+1)
  b5 = b5/(loopsize+1)
  c5 = c5/(loopsize+1)
  d5 = d5/(loopsize+1)
  e5 = e5/(loopsize+1)




  top5RMS = (a5 + b5 + c5 + d5 + e5) / 5.0


  if(numAnalogsToUse.eq.1) then
    top5RMS = a5 / 1.0
  end if
  if(numAnalogsToUse.eq.2) then
    top5RMS = (a5+b5) / 2.0
  end if
  if(numAnalogsToUse.eq.3) then
    top5RMS = (a5+b5+c5) / 3.0
  end if
  if(numAnalogsToUse.eq.4) then
    top5RMS = (a5+b5+c5+d5) / 4.0
  end if


  theRank = myRank(AKverifyRMS,top5RMS)

  theMonteCarloRank = MonteCarloRank2(AKverifyRMS,top5RMS,numAnalogsToUse)
  rankString="Red box forecast better than "+sprintf("%7.1f",theRank)+"% similar months~C~and better than "+sprintf("%7.1f",theMonteCarloRank)+"% of simulations."
  rankString2="Forecast better than "+sprintf("%7.1f",theMonteCarloRank)+"% of simulations. A no-skill forecast is 50th percentile."

  sad = new(5,integer)
  sad = VerificationRanks(AKverifyRMS,YearArray(wwww(ii)),YearArray(wwww(ii+1)),YearArray(wwww(ii+2)),YearArray(wwww(ii+3)),YearArray(wwww(ii+4)))
  sadString = "Here are the verification (hindcast) ranks, 1 to 72, for each of the 5 analog years for the forecast area: "+YearArray(wwww(ii))+" (#"+sad(0)+"), "+YearArray(wwww(ii+1))+" (#"+sad(1)+"), "+YearArray(wwww(ii+2))+" (#"+sad(2)+"), "+YearArray(wwww(ii+3))+" (#"+sad(3)+"), and "+YearArray(wwww(ii+4))+" (#"+sad(4)+")"
  if (numAnalogsToUse.eq.4) then
    sadString = "Here are the verification (hindcast) ranks, 1 to 72, for each of the 4 analog years for the forecast area: "+YearArray(wwww(ii))+" (#"+sad(0)+"), "+YearArray(wwww(ii+1))+" (#"+sad(1)+"), "+YearArray(wwww(ii+2))+" (#"+sad(2)+"), and "+YearArray(wwww(ii+3))+" (#"+sad(3)+")"
  end if
  if (numAnalogsToUse.eq.3) then
    sadString = "Here are the verification (hindcast) ranks, 1 to 72, for each of the 3 analog years for the forecast area: "+YearArray(wwww(ii))+" (#"+sad(0)+"), "+YearArray(wwww(ii+1))+" (#"+sad(1)+"), and "+YearArray(wwww(ii+2))+" (#"+sad(2)+")"
  end if
  if (numAnalogsToUse.eq.2) then
    sadString = "Here are the verification (hindcast) ranks, 1 to 72, for each of the 2 analog years for the forecast area: "+YearArray(wwww(ii))+" (#"+sad(0)+") and "+YearArray(wwww(ii+1))+" (#"+sad(1)+")"
  end if
  if (numAnalogsToUse.eq.1) then
    sadString = "Here is the verification (hindcast) ranks, 1 to 72, for the analog year for the forecast area: "+YearArray(wwww(ii))+" (#"+sad(0)+")"
  end if



  delete(sad)
  asciiwrite (filedir+"verstr.txt" , sadString)
    zz = systemfunc("mv -f "+filedir+"verstr.txt "+output_dir+"/verstr.txt")

  asciiwrite (filedir+"compstr.txt" , rankString2)
    zz = systemfunc("mv -f "+filedir+"compstr.txt "+output_dir+"/compstr.txt")

;  slpcor = R_value2(slpArray4,AKforCor)
;  h500cor = R_value2(h500Array4,AKforCor)
;  t2mcor = R_value2(t2mArray4,AKforCor)
;  t925cor = R_value2(t925Array4,AKforCor)
;  sstcor = R_value2(sstArray4,AKforCor)
;  weightedcor = R_value2(weightedArray1,AKforCor)
  ; end calculating Rank


  ;theMonteCarloRank = MonteCarloRank2(AKverifyRMS,top5RMS,numAnalogsToUse)
  ;rankString="Red box forecast better than "+sprintf("%7.1f",theRank)+"% similar months~C~and better than "+sprintf("%7.1f",theMonteCarloRank)+"% of simulations."
  ;rankString2="Forecast better than "+sprintf("%7.1f",theMonteCarloRank)+"% of simulations. A no-skill forecast is 50th percentile."


  wks_pan = gsn_open_wks(wtype,filedir+"pan_v1")
  plotV = new(2,graphic)
  tempvar2 = cdfAll(0,:,:)
  tempvar2 = dim_avg_n_Wrap(top5(0:4,:,:),0) - dim_avg_n_Wrap(cdfClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  AKdiff = W_ave(top5anom,0,4,AK1,AK2,AK3,AK4)
  AKdiff2 = W_ave(top5anom,0,4,y1,y2,x1,x2)
  ;res@tiXAxisString = varName + " Anomaly forecast during " + monthRangeString2 +" time period.~C~Using top 5 analogs for " + monthRangeString1 + " " + useryear + ".~C~Years are : "+YearArray(sortInx(ii))+", "+YearArray(sortInx(ii+1))+", "+YearArray(sortInx(ii+2))+", "+YearArray(sortInx(ii+3))+", and "+YearArray(sortInx(ii+4))+"~C~Red Box Average Anomaly is "+ sprintf("%6.3f",AKdiff)+" "+varUnits+".~C~Blue Box Average Anomaly is "+ sprintf("%6.3f",AKdiff2)+" "+varUnits+".~C~"+rankString
  res@tiXAxisString = varName + " Anomaly forecast during " + monthRangeString2 +" time period.~C~Using top 5 analogs for " + monthRangeString1 + " " + useryear + ".~C~Years are : "+YearArray(sortInx(ii))+", "+YearArray(sortInx(ii+1))+", "+YearArray(sortInx(ii+2))+", "+YearArray(sortInx(ii+3))+", and "+YearArray(sortInx(ii+4))+"~C~"+weightString2+"~C~"+rankString
  plotV1 = gsn_csm_contour_map_polar(wks_pan,tempvar2,res)
  polyV1a = gsn_add_polyline(wks_pan,plotV1,lon_box,lat_box,boxres)
  polyV1b = gsn_add_polyline(wks_pan,plotV1,AKlon_box,AKlat_box,AKboxres)
  draw(plotV1)
  frame(wks_pan)
  delete(wks_pan)


  wks_pan = gsn_open_wks(wtype,filedir+"pan_v2")
  AKdiff = W_ave(cdfAll,thetime+fmnths,thetime+fmnths+fmnths2-1,AK1,AK2,AK3,AK4) - W_ave(cdfClm,usermonth-1+12+fmnths,usermonth-1+12+fmnths+fmnths2-1,AK1,AK2,AK3,AK4)
  AKdiff2 = W_ave(cdfAll,thetime+fmnths,thetime+fmnths+fmnths2-1,y1,y2,x1,x2) - W_ave(cdfClm,usermonth-1+12+fmnths,usermonth-1+12+fmnths+fmnths2-1,y1,y2,x1,x2)
  res@tiXAxisString = "Actual "+varName+ " Anomaly for "+ monthRangeString2 +" "+useryearString2 + "~C~Red Box Anomaly is "+ sprintf("%6.3f",AKdiff)+" "+varUnits+"." + "~C~Blue Box Anomaly is "+ sprintf("%6.3f",AKdiff2)+" "+varUnits+"."+"~C~(c) University of Alaska Fairbanks"
  tempvar2 = cdfAll(0,:,:)
  tempvar2 = verify - dim_avg_n_Wrap(cdfClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
  plotV2 = gsn_csm_contour_map_polar(wks_pan,tempvar2,res)
  polyV2a = gsn_add_polyline(wks_pan,plotV2,lon_box,lat_box,boxres)
  polyV2b = gsn_add_polyline(wks_pan,plotV2,AKlon_box,AKlat_box,AKboxres)
  plotV(0) = plotV1
  plotV(1) = plotV2
  draw(plotV2)
  frame(wks_pan)
  delete(wks_pan)


    zz = systemfunc("mv -f "+filedir+"pan_v1.png "+output_dir+"/pan_v1.png")
    zz = systemfunc("convert "+output_dir+"/pan_v1.png -crop 800x1000+50+0 "+output_dir+"/v1.png")
    zz = systemfunc("rm -f "+output_dir+"/pan_v1.png")
    zz = systemfunc("mv -f "+filedir+"pan_v2.png "+output_dir+"/pan_v2.png")
    zz = systemfunc("convert "+output_dir+"/pan_v2.png -crop 800x1000+50+0 "+output_dir+"/v.png")
    zz = systemfunc("rm -f "+output_dir+"/pan_v2.png")



    if (doNMME.eq.True) then
    if (variable.eq.3.and.useryear.ge.2012) then
      tempadd = fmnths+fmnths2
      if (tempadd.le.7) then
        t2mactualAK =  dim_avg_n_Wrap(cdfAll(thetime+fmnths:thetime+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4}) ,0)
        t2mactualGlobal =  dim_avg_n_Wrap(cdfAll(thetime+fmnths:thetime+fmnths+fmnths2-1,:,:) ,0)
        t2mclimoAK =  dim_avg_n_Wrap(cdfAll(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,{AK1:AK2},{AK3:AK4}) ,0)
        t2mclimoGlobal =  dim_avg_n_Wrap(cdfAll(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:) ,0)
        t2anomAK = t2mactualAK - t2mclimoAK
        t2anomGlobal = t2mactualGlobal - t2mclimoGlobal
        analogforecast = dim_avg_n_Wrap(top5anom(0:4,{AK1:AK2},{AK3:AK4}),0)
        nmmeforecast = dim_avg_n_Wrap(nmme(lead:lead+fmnths2-1,{AK1:AK2},{AK3:AK4}),0)
        cfsv2forecast = dim_avg_n_Wrap(cfsv2(lead:lead+fmnths2-1,{AK1:AK2},{AK3:AK4}),0)
        copy_VarCoords(t2mactualAK,analogforecast)
        copy_VarCoords(t2mactualAK,nmmeforecast)
        copy_VarCoords(t2mactualAK,cfsv2forecast)
        analog_actual_RMS = wgt_arearmse(analogforecast(:,:),t2anomAK(:,:),nmmelatitude,1.0,0)
        NMME_actual_RMS = wgt_arearmse(nmmeforecast(:,:),t2anomAK(:,:),nmmelatitude,1.0,0)
        CFSv2_actual_RMS = wgt_arearmse(cfsv2forecast(:,:),t2anomAK(:,:),nmmelatitude,1.0,0)


        winner="NMME"
        if(NMME_actual_RMS.gt.analog_actual_RMS) then
          winner = "ANALOGS"
        end if
        winner2="CFSv2"
        if(CFSv2_actual_RMS.gt.analog_actual_RMS) then
          winner2 = "ANALOGS"
        end if

        wks_pan = gsn_open_wks(wtype,filedir+"pan_v3")
        AKdiff = W_ave(cdfAll,thetime+fmnths,thetime+fmnths+fmnths2-1,AK1,AK2,AK3,AK4) - W_ave(cdfClm,usermonth-1+12+fmnths,usermonth-1+12+fmnths+fmnths2-1,AK1,AK2,AK3,AK4)
        AKdiff2 = W_ave(cdfAll,thetime+fmnths,thetime+fmnths+fmnths2-1,y1,y2,x1,x2) - W_ave(cdfClm,usermonth-1+12+fmnths,usermonth-1+12+fmnths+fmnths2-1,y1,y2,x1,x2)
        res@tiXAxisString = "NMME "+varName+ " Forecast Anomaly for "+ monthRangeString2 +" "+useryearString2+" ~C~(c) University of Alaska Fairbanks~C~ ~C~ "
        tempvar2 = cdfAll(0,:,:)
        tempvar2 = verify - dim_avg_n_Wrap(cdfClm(usermonth+12-1+fmnths:usermonth+12-1+fmnths+fmnths2-1,:,:),0)
        nmmeave = dim_avg_n_Wrap(nmme(lead:lead+fmnths2,:,:),0)
        plotV2 = gsn_csm_contour_map_polar(wks_pan,nmmeave(:,:),res)
        polyV2a = gsn_add_polyline(wks_pan,plotV2,lon_box,lat_box,boxres)
        polyV2b = gsn_add_polyline(wks_pan,plotV2,AKlon_box,AKlat_box,AKboxres)
        plotV(0) = plotV1
        plotV(1) = plotV2
        draw(plotV2)
        frame(wks_pan)
        delete(wks_pan)
        delete(nmmeave)
        zz = systemfunc("mv -f "+filedir+"pan_v3.png "+output_dir+"/pan_v3.png")
        zz = systemfunc("convert "+output_dir+"/pan_v3.png -crop 800x1000+50+0 "+output_dir+"/v3.png")
        zz = systemfunc("rm -f "+output_dir+"/pan_v3.png")
        delete([/t2mactualAK,t2mactualGlobal,t2mclimoAK,t2mclimoGlobal,t2anomAK,t2anomGlobal, analogforecast,nmmeforecast/])
      end if
    end if
  end if


end if ; end verification plot section





;; XY Scatter plot showing all years of the selection month(s)

f = new((/9,dimsizes(sctArr)/),float)

do qq=0,dimsizes(sctArr) - 1  ; loop through and populate top 5 analog month groups into template arrays
  f(0,qq) = sctArr(qq)
  f(1,qq) = qq+1948
end do


do ww=0,numAnalogsToUse - 1   ; might crash here!
  f(2,ww) = sctArr(sortInx(ii+ww))
  f(3,ww) = YearArray(sortInx(ii+ww))
end do
f(4,0) = W_ave(cdfAll,thetime-exmth,thetime,y1,y2,x1,x2)
f(5,0) = useryear

wks_pan = gsn_open_wks(wtype,filedir+"pan_s1")
res44                   = True                     ; plot mods desired
res44 = SetScatterRes("Nothing")
res44@tiXAxisString ="Analogs = " + YearArray(sortInx(ii)) +", " + YearArray(sortInx(ii+1)) +", " + YearArray(sortInx(ii+2)) +", " + YearArray(sortInx(ii+3)) +", " + YearArray(sortInx(ii+4))
res44@tiYAxisString ="Ave. "+varName+" from lat: "+y1+"-"+y2+" lon:"+x1+"-"+x2
res44@tiMainString = monthRangeString1+" "+useryear+" "+varName+ "~C~"+weightString
res44@xyMarkerColors = "forestgreen"
res44@xyMarkerSizeF     = 0.01                     ; Marker size (default 0.01)
plotr  = gsn_csm_xy (wks_pan,f(1,:),f(0,:),res44)                  ; create plot
res44@xyMarkerColors = "firebrick"
res44@xyMarkerSizeF     = 0.02                     ; Marker size (default 0.01)
plotr2  = gsn_csm_xy (wks_pan,f(3,:),f(2,:),res44)                  ; create plot
res44@xyMarkerColors = "orange"
res44@xyMarkerSizeF     = 0.03                     ; Marker size (default 0.01)
plotr3  = gsn_csm_xy (wks_pan,f(5,:),f(4,:),res44)                  ; create plot

overlay(plotr,plotr2)
overlay(plotr,plotr3)
draw(plotr)
frame(wks_pan)

;; XY Scatter plot showing how the best 5 analog years fared (plus verification year)
g = new((/9,RMS_Array_Size/),float)
do qq=0,RMS_Array_Size - 1  ; loop through and populate top 5 analog month groups into template arrays
  g(0,qq) = AksctArr(qq)
  g(1,qq) = qq+1948
end do

do ww=0,numAnalogsToUse - 1   ; might crash here!
  g(2,ww) = AksctArr(sortInx(ii+ww)-1)
  g(3,ww) = YearArray(sortInx(ii+ww))
end do
if (doLast .eq. True) then
  g(4,0) = W_ave(cdfAll,thetime+fmnths,thetime+fmnths+fmnths2-1,AK1,AK2,AK3,AK4)
  g(5,0) = useryear
end if

;exit

wks_pan = gsn_open_wks(wtype,filedir+"pan_s2")
res55                   = True                     ; plot mods desired
res55 = SetScatterRes("Nothing")
res55@tiXAxisString ="Analogs = " + YearArray(sortInx(ii)) +", " + YearArray(sortInx(ii+1)) +", " + YearArray(sortInx(ii+2)) +", " + YearArray(sortInx(ii+3)) +", " + YearArray(sortInx(ii+4))
res55@tiYAxisString ="Ave. "+varName+ " from lat: "+AK1+"-"+AK2+" lon:"+AK3+"-"+AK4
res55@tiMainString = monthRangeString2+" "+useryearString2+" "+varName+ "~C~"+weightString
res55@xyMarkerColors = "forestgreen"
res55@xyMarkerSizeF     = 0.01                     ; Marker size (default 0.01)
plotr  = gsn_csm_xy (wks_pan,g(1,:),g(0,:),res55)                  ; create plot
res55@xyMarkerColors = "firebrick"
res55@xyMarkerSizeF     = 0.02                     ; Marker size (default 0.01)
plotr2  = gsn_csm_xy (wks_pan,g(3,:),g(2,:),res55)                  ; create plot
overlay(plotr,plotr2)

if (doLast .eq. True) then
  res55@xyMarkerColors = "blue"
  res55@xyMarkerSizeF     = 0.03                     ; Marker size (default 0.01)
  plotr3  = gsn_csm_xy (wks_pan,g(5,:),g(4,:),res55)                  ; create plot
  overlay(plotr,plotr3)
end if

draw(plotr)
frame(wks_pan)


  zz = systemfunc("mv -f "+filedir+"pan_s2.png "+output_dir+"/s2.png")


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ends second scatter plot section
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;




slpcor = R_value3(slpAnalysisBlue2,ydep)
h500cor = R_value3(h500AnalysisBlue2,ydep)
t2mcor = R_value3(t2mAnalysisBlue2,ydep)
t925cor = R_value3(t925AnalysisBlue2,ydep)
sstcor = R_value3(sstAnalysisBlue2,ydep)
icecor = R_value3(iceAnalysisBlue2,ydep)
weightedcor = R_value3(weightedAnalysisBlue2,ydep)

cr = tochar(10)

if (doLast.eq.True) then
  allYears = "Weighted Analogs for "+useryear+","+ID+","+YearArray(sortInx(ii))+","+YearArray(sortInx(ii+1))+","+YearArray(sortInx(ii+2))+","+YearArray(sortInx(ii+3))+","+YearArray(sortInx(ii+4))+","  + sprintf("%6.3f",intercept)  +","+sprintf("%6.3f",slpwgt)+"," +sprintf("%6.3f",h500wgt)+","+sprintf("%6.3f",t2mwgt)+","+sprintf("%6.3f",t925wgt)+","+sprintf("%6.3f",sstwgt)+","+ sprintf("%6.3f",weightedcor)+","+ sprintf("%7.1f",theMonteCarloRank)
end if
if (doLast.eq.False) then
  allYears = "Weighted Analogs for "+useryear+","+ID+","+YearArray(sortInx(ii))+","+YearArray(sortInx(ii+1))+","+YearArray(sortInx(ii+2))+","+YearArray(sortInx(ii+3))+","+YearArray(sortInx(ii+4))  + sprintf("%6.3f",intercept)  +","+sprintf("%6.3f",slpwgt)+","+sprintf("%6.3f",h500wgt)+","+sprintf("%6.3f",t2mwgt)+","+sprintf("%6.3f",t925wgt)+","+sprintf("%6.3f",sstwgt)+","+ sprintf("%6.3f",weightedcor)+","+ "-9999.0"
end if

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Sea ice estimate section
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

top30Years = new(30,integer)
maxseaiceyear=toint(-9999)
numAnalogsToUseM1 = numAnalogsToUse - 1
iCntr = 0
do si = 0, 29
  if (YearArray(sortInx(ii+si)) .ge. 1979 .and. YearArray(sortInx(ii+si)) .le. 2019) then
    top30Years(iCntr) = toint(YearArray(sortInx(ii+si)))
    maxseaiceyear = toint(YearArray(sortInx(ii+si)))   ; this captures whether there is at least 1 valid sea ice year
    iCntr = iCntr + 1
  end if
  if(domanual.eq.True) then     ; This checks to see if the years were entered manually.
    if(manualyesno.eq.1) then
      if(si.eq.4) then
        si=30
      end if
    end if
  end if
end do


the5AnalogYears = new(5,integer)
the5AnalogYears(0) = toint(YearArray(sortInx(ii)))
the5AnalogYears(1) = toint(YearArray(sortInx(ii+1)))
the5AnalogYears(2) = toint(YearArray(sortInx(ii+2)))
the5AnalogYears(3) = toint(YearArray(sortInx(ii+3)))
the5AnalogYears(4) = toint(YearArray(sortInx(ii+4)))



; this next block assigns the top 5 analog years
; beginning with 1979 exclusively
;the5AnalogYears(0) = toint(top30Years(0))
;the5AnalogYears(1) = toint(top30Years(1))
;the5AnalogYears(2) = toint(top30Years(2))
;the5AnalogYears(3) = toint(top30Years(3))
;the5AnalogYears(4) = toint(top30Years(4))



fg = usermonth+fmnths
fg2 = fg

if (fg.gt.12) then
  fg2 = fg - 12
end if

orderedNum = new(80,float)
seaIceMonth = new(80,float)
seaIceMonthM1 = new(80,float)
seaIceMonthM2 = new(80,float)
theEstimates = new(5,float)
theActuals = new(5,float)


targetmonth=usermonth+fmnths

orderedNum = new(80,float)
seaIceMonth = new(80,float)
theIceYears = new(5,float)
theEstimates = new(5,float)
theActuals = new(5,float)
theEstimatesM1 = new(5,float)
theEstimatesM2 = new(5,float)
theActualsM1 = new(5,float)
theActualsM2 = new(5,float)

do p = 0, 72   ; change to 69 when Jan. 2017 data comes in.
  theSIyear = p+1948
  theIndex = (p*12)+fg2-1
  if(theIndex.le.numrows-1 .and. theIndex.ge.3) then
    orderedNum(p) = p+1948
    seaIceMonth(p) = seaice_csv(theIndex)
    seaIceMonthM1(p) = seaice_csv(theIndex-1)
    seaIceMonthM2(p) = seaice_csv(theIndex-2)
  end if
end do

; in "BB_Utils", the size of the arrays is hard-coded. Change in 2017 (not any more - Jan 2020)
theSeaIceMonthCalcsM0 = SeaIceCalcs(orderedNum,seaIceMonth,yrStrtIceClm,yrLastIceClm)
theSeaIceMonthCalcsM1 = SeaIceCalcs(orderedNum,seaIceMonthM1,yrStrtIceClm,yrLastIceClm)
theSeaIceMonthCalcsM2 = SeaIceCalcs(orderedNum,seaIceMonthM2,yrStrtIceClm,yrLastIceClm)


  validCount = 0
  ;do lk = 0, numAnalogsToUse - 1
  do lk = 0, 4
    myInd = (the5AnalogYears(lk)-1948)*12+usermonth-1+fmnths
    if (myInd.le.totalDimsM1) then     ; change to 818 in Mar 2016 (makes sure that you dont have a sea ice in the usermonth but not in the last forecast month; e.g., data for Dec 2015 but forecast for Sept 2016).
      validCount = validCount +1
      theEstimates(lk) = theSeaIceMonthCalcsM0(4,the5AnalogYears(lk)-1948)
      theEstimatesM1(lk) = theSeaIceMonthCalcsM1(4,the5AnalogYears(lk)-1948)
      theEstimatesM2(lk) = theSeaIceMonthCalcsM2(4,the5AnalogYears(lk)-1948)
      theActuals(lk) = theSeaIceMonthCalcsM0(1,the5AnalogYears(lk)-1948)
      theActualsM1(lk) = theSeaIceMonthCalcsM1(1,the5AnalogYears(lk)-1948)
      theActualsM2(lk) = theSeaIceMonthCalcsM2(1,the5AnalogYears(lk)-1948)
      if (fg.gt.12) then
        theEstimates(lk) = theSeaIceMonthCalcsM0(4,the5AnalogYears(lk)-1948+1)
        theEstimatesM1(lk) = theSeaIceMonthCalcsM1(4,the5AnalogYears(lk)-1948+1)
        theEstimatesM2(lk) = theSeaIceMonthCalcsM2(4,the5AnalogYears(lk)-1948+1)
      end if
    end if
  end do


  if (validCount .eq. 0) then
    zz = systemfunc("cp -f "+output_dir+"/NA.png "+output_dir+"/ice1.png")
    print("")
    print("Since there are no years >=1979, there is no sea ice analog forecast to make.")
  end if



  validEstimates = new(5,float)
  validEstimatesM1 = new(5,float)
  validEstimatesM2 = new(5,float)
  validActuals = new(5,float)
  validActualsM1 = new(5,float)
  validActualsM2 = new(5,float)
  validIceYears = new(5,float)
  tempcount = 0
  aveDeviation = tofloat(0.0)
  aveDeviationM1 = tofloat(0.0)
  aveDeviationM2 = tofloat(0.0)
  aveIce = tofloat(0.0)
  aveIceM1 = tofloat(0.0)
  aveIceM2 = tofloat(0.0)
  aveEst = tofloat(0.0)
  aveEstM1 = tofloat(0.0)
  aveEstM2 = tofloat(0.0)
  targetSeaIce = tofloat(0.0)
  targetSeaIceM1 = tofloat(0.0)
  targetSeaIceM2 = tofloat(0.0)
  iceYearsString = ""

  validCount = numAnalogsToUse

  do rt = 0, numAnalogsToUse - 1
    if(.not.ismissing(theEstimates(rt))) then
      validEstimates(tempcount) = theEstimates(rt)
      validEstimatesM1(tempcount) = theEstimatesM1(rt)
      validEstimatesM2(tempcount) = theEstimatesM2(rt)
      validActuals(tempcount) = theActuals(rt)
      validActualsM1(tempcount) = theActualsM1(rt)
      validActualsM2(tempcount) = theActualsM2(rt)
      validIceYears(tempcount) = the5AnalogYears(rt)
      iceYearsString = iceYearsString+" "+ the5AnalogYears(rt)
      aveIce = tofloat(aveIce) + (theActuals(rt) / tofloat(numAnalogsToUse))
      aveIceM1 = tofloat(aveIceM1) + (theActualsM1(rt) / tofloat(numAnalogsToUse))
      aveIceM2 = tofloat(aveIceM2) + (theActualsM2(rt) / tofloat(numAnalogsToUse))
      aveEst = tofloat(aveEst) + (theEstimates(rt) / tofloat(numAnalogsToUse))
      aveEstM1 = tofloat(aveEstM1) + (theEstimatesM1(rt) / tofloat(numAnalogsToUse))
      aveEstM2 = tofloat(aveEstM2) + (theEstimatesM2(rt) / tofloat(numAnalogsToUse))
      aveDeviation = tofloat(aveDeviation) + ((theActuals(rt) - theEstimates(rt)) / tofloat(numAnalogsToUse))
      aveDeviationM1 = tofloat(aveDeviationM1) + ((theActualsM1(rt) - theEstimatesM1(rt)) / tofloat(numAnalogsToUse))
      aveDeviationM2 = tofloat(aveDeviationM2) + ((theActualsM2(rt) - theEstimatesM2(rt)) / tofloat(numAnalogsToUse))
      tempcount = tempcount + 1
    end if
  end do




  curIndex = ((useryear - 1948) *12) +usermonth - 1 + fmnths
  if (fg.le.12) then
    targetSeaIce = theSeaIceMonthCalcsM0(1,useryear-1948)
    targetSeaIceM1 = theSeaIceMonthCalcsM1(1,useryear-1948)
    targetSeaIceM2 = theSeaIceMonthCalcsM2(1,useryear-1948)
    if (numAnalogsToUse.eq.5) then
      aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(4)-1948) ) / numAnalogsToUse
      aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(4)-1948) ) / numAnalogsToUse
      aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(4)-1948) ) / numAnalogsToUse
      aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(4)-1948) ) / numAnalogsToUse
      aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(4)-1948) ) / numAnalogsToUse
      aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(4)-1948) ) / numAnalogsToUse
      aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(4)-1948) ) / numAnalogsToUse
      aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(4)-1948) ) / numAnalogsToUse
      aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(3)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(4)-1948) ) / numAnalogsToUse
    end if
    if (numAnalogsToUse.eq.4) then
      aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(3)-1948) ) / numAnalogsToUse
      aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(3)-1948) ) / numAnalogsToUse
      aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(3)-1948) ) / numAnalogsToUse
      aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(3)-1948) ) / numAnalogsToUse
      aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(3)-1948) ) / numAnalogsToUse
      aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(3)-1948) ) / numAnalogsToUse
      aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(3)-1948) ) / numAnalogsToUse
      aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(3)-1948) ) / numAnalogsToUse
      aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(2)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(3)-1948) ) / numAnalogsToUse
    end if
    if (numAnalogsToUse.eq.3) then
      aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(2)-1948) ) / numAnalogsToUse
      aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(2)-1948) ) / numAnalogsToUse
      aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(2)-1948) ) / numAnalogsToUse
      aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(2)-1948) ) / numAnalogsToUse
      aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(2)-1948) ) / numAnalogsToUse
      aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(2)-1948) ) / numAnalogsToUse
      aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(2)-1948) ) / numAnalogsToUse
      aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(2)-1948) ) / numAnalogsToUse
      aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(1)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(2)-1948) ) / numAnalogsToUse
    end if
    if (numAnalogsToUse.eq.2) then
      aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(5,the5AnalogYears(1)-1948) ) / numAnalogsToUse
      aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(5,the5AnalogYears(1)-1948) ) / numAnalogsToUse
      aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(5,the5AnalogYears(1)-1948) ) / numAnalogsToUse
      aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(4,the5AnalogYears(1)-1948) ) / numAnalogsToUse
      aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(4,the5AnalogYears(1)-1948) ) / numAnalogsToUse
      aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(4,the5AnalogYears(1)-1948) ) / numAnalogsToUse
      aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM0(1,the5AnalogYears(1)-1948) ) / numAnalogsToUse
      aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM1(1,the5AnalogYears(1)-1948) ) / numAnalogsToUse
      aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948)+theSeaIceMonthCalcsM2(1,the5AnalogYears(1)-1948) ) / numAnalogsToUse
    end if
    if (numAnalogsToUse.eq.1) then
      aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948) ) / numAnalogsToUse
      aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948) ) / numAnalogsToUse
      aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948) ) / numAnalogsToUse
      aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948) ) / numAnalogsToUse
      aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948) ) / numAnalogsToUse
      aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948) ) / numAnalogsToUse
      aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948) ) / numAnalogsToUse
      aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948) ) / numAnalogsToUse
      aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948) ) / numAnalogsToUse
    end if
  end if


  if (fg.gt.12) then
    if (useryear.lt.2019) then                                          ; change me in 2017
      targetSeaIce = theSeaIceMonthCalcsM0(1,useryear-1948+1)
      targetSeaIceM1 = theSeaIceMonthCalcsM1(1,useryear-1948+1)
      targetSeaIceM2 = theSeaIceMonthCalcsM2(1,useryear-1948+1)
      if (numAnalogsToUse.eq.5) then
          aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
          aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
          aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
          aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
          aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
          aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
          aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
          aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
          aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(3)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(4)-1948+1) ) / numAnalogsToUse
      end if
      if (numAnalogsToUse.eq.4) then
          aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
          aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
          aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
          aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
          aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
          aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
          aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
          aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
          aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(2)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(3)-1948+1) ) / numAnalogsToUse
      end if
      if (numAnalogsToUse.eq.3) then
          aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
          aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
          aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
          aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
          aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
          aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
          aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
          aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
          aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(1)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(2)-1948+1) ) / numAnalogsToUse
      end if
      if (numAnalogsToUse.eq.2) then
          aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(5,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
          aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(5,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
          aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(5,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
          aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(4,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
          aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(4,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
          aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(4,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
          aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM0(1,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
          aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM1(1,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
          aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948+1)+theSeaIceMonthCalcsM2(1,the5AnalogYears(1)-1948+1) ) / numAnalogsToUse
      end if
      if (numAnalogsToUse.eq.1) then
          aveDeviation = (theSeaIceMonthCalcsM0(5,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
          aveDeviationM1 = (theSeaIceMonthCalcsM1(5,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
          aveDeviationM2 = (theSeaIceMonthCalcsM2(5,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
          aveEst = (theSeaIceMonthCalcsM0(4,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
          aveEstM1 = (theSeaIceMonthCalcsM1(4,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
          aveEstM2 = (theSeaIceMonthCalcsM2(4,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
          aveIce = (theSeaIceMonthCalcsM0(1,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
          aveIceM1 = (theSeaIceMonthCalcsM1(1,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
          aveIceM2 = (theSeaIceMonthCalcsM2(1,the5AnalogYears(0)-1948+1) ) / numAnalogsToUse
      end if
    end if
  end if




  if (fg.le.12) then
    targetSeaIceTrend = theSeaIceMonthCalcsM0(4,useryear-1948)
    targetSeaIceTrendM1 = theSeaIceMonthCalcsM1(4,useryear-1948)
    targetSeaIceTrendM2 = theSeaIceMonthCalcsM2(4,useryear-1948)
    if(.not.ismissing(the5AnalogYears(0))) then
      best1 = validActuals(0) - validEstimates(0) + theSeaIceMonthCalcsM0(4,useryear-1948)
    end if
    if(.not.ismissing(the5AnalogYears(1))) then
      best2 = validActuals(1) - validEstimates(1) + theSeaIceMonthCalcsM0(4,useryear-1948)
    end if
    if(.not.ismissing(the5AnalogYears(2))) then
      best2 = validActuals(2) - validEstimates(2) + theSeaIceMonthCalcsM0(4,useryear-1948)
    end if
    if(.not.ismissing(the5AnalogYears(3))) then
      best2 = validActuals(3) - validEstimates(3) + theSeaIceMonthCalcsM0(4,useryear-1948)
    end if
    if(.not.ismissing(the5AnalogYears(4))) then
      best2 = validActuals(4) - validEstimates(4) + theSeaIceMonthCalcsM0(4,useryear-1948)
    end if
  end if
  if (fg.gt.12) then
      targetSeaIceTrend = theSeaIceMonthCalcsM0(4,useryear-1948+1)
      targetSeaIceTrendM1 = theSeaIceMonthCalcsM1(4,useryear-1948+1)
      targetSeaIceTrendM2 = theSeaIceMonthCalcsM2(4,useryear-1948+1)
      if(.not.ismissing(the5AnalogYears(0))) then
        best1 = validActuals(0) - validEstimates(0) + theSeaIceMonthCalcsM0(4,useryear-1948+1)
      end if
      if(.not.ismissing(the5AnalogYears(1))) then
        best1 = validActuals(1) - validEstimates(1) + theSeaIceMonthCalcsM0(4,useryear-1948+1)
      end if
      if(.not.ismissing(the5AnalogYears(2))) then
        best1 = validActuals(2) - validEstimates(2) + theSeaIceMonthCalcsM0(4,useryear-1948+1)
      end if
      if(.not.ismissing(the5AnalogYears(3))) then
        best1 = validActuals(3) - validEstimates(3) + theSeaIceMonthCalcsM0(4,useryear-1948+1)
      end if
      if(.not.ismissing(the5AnalogYears(4))) then
        best1 = validActuals(4) - validEstimates(4) + theSeaIceMonthCalcsM0(4,useryear-1948+1)
      end if
  end if



SeaIceForecast = targetSeaIceTrend + aveDeviation
SeaIceForecastM1 = targetSeaIceTrendM1 + aveDeviationM1
SeaIceForecastM2 = targetSeaIceTrendM2 + aveDeviationM2


;***************************
;***************************
;***  SPECIAL Calcs and Plot
;***************************
s1 = new(dimsizes(weightedArray1),float)
s1b = new(dimsizes(weightedArray1),float)
s2 = new(dimsizes(specialArray1),float)
r1 = new(dimsizes(weightedArray1),float)
r1b = new(dimsizes(weightedArray1),float)

matchesString = ""
specialString = ""

matchesString = "Atmospheric Match Scores Based on the Following User Input Weighting Are:"+cr+"Weights: "+"SLP:"+sprintf("%6.2f",slpwgt)+", Z"+getlev(heightlev)+":"+sprintf("%6.2f",h500wgt)+", T2M:"+sprintf("%6.2f",t2mwgt)+", T"+getlev(templev)+":"+sprintf("%6.2f",t925wgt)+", and SST:"+sprintf("%6.2f",sstwgt)+"."+cr+cr
specialString = "Atmospheric Match Scores Based on the Following User Input Weighting Are:"+cr+"Weights: "+"SLP:"+sprintf("%6.2f",slpwgt)+", Z"+getlev(heightlev)+":"+sprintf("%6.2f",h500wgt)+", T2M:"+sprintf("%6.2f",t2mwgt)+", T"+getlev(templev)+":"+sprintf("%6.2f",t925wgt)+", and SST:"+sprintf("%6.2f",sstwgt)+"."+cr+"[#Rank,RMSE,"+specialText+"]"+cr+cr


do ear = 0, NumAnalysisYears-1
  earplus1 = ear + 1
  intIndex = YearArray(xxyy(ii+ear)) - 1948
  matchesString = matchesString + "#"+earplus1+","+YearArray(xxyy(ii+ear)) + ","+weightedArray1(xxyy(ii+ear))+cr

  s1(ear)=weightedArraySpecial(xxyy(ii+ear))
  s1b(ear)=weightedArray1(xxyy(ii+ear))

  if (.not.ismissing(intIndex)) then
    specialString = specialString + "#"+earplus1+","+YearArray(xxyy(ii+ear)) + ","+weightedArray1(xxyy(ii+ear)) + ","+specialArray1(toint(YearArray(xxyy(ii+ear)))-1948)+cr
    s2(ear)=specialArray1(toint(YearArray(xxyy(ii+ear)))-1948)
  end if
  if (ismissing(intIndex)) then
    specialString = specialString + "#"+earplus1+","+YearArray(xxyy(ii+ear)) + ","+weightedArraySpecial(xxyy(ii+ear))+",9999"+cr
  end if
end do

  specialslope = regline(s1,s2)
  specialintercept = specialslope@yintercept
  specialslopeb = regline(s1b,s2)
  specialinterceptb = specialslopeb@yintercept
  specialCor = escorc(s1,s2)
  specialCorb = escorc(s1b,s2)


  asciiwrite (filedir+"matches1.txt" , matchesString)
  zz = systemfunc("mv -f "+filedir+"matches1.txt "+output_dir+"/matches1.txt")
  asciiwrite (filedir+"specialmatches1.txt" , specialString)
  zz = systemfunc("mv -f "+filedir+"specialmatches1.txt "+output_dir+"/specialmatches1.txt")


matchesString2 = "Since the forecast time period is in the future, a post-analysis evauation to determine how the selection years performed is not possible."
if (b.lt.totalDims) then    ; only do this part if you can do the verification plot
  matchesString2 = ""
  matchesString2 = "Hindcast Ranking of Best Analog Years (e.g., which years were the best matches?):"+cr+"Weights: "+"SLP:"+sprintf("%6.2f",slpwgt)+", Z"+getlev(heightlev)+":"+sprintf("%6.2f",h500wgt)+", T2M:"+sprintf("%6.2f",t2mwgt)+", T"+getlev(templev)+":"+sprintf("%6.2f",t925wgt)+", and SST:"+sprintf("%6.2f",sstwgt)+"."+cr+cr

  do ear2 = 0, dimsizes(AKverifyRMS)-2  ; it's -2 because the 1948 year has a placeholder value
    ear2plus1 = ear2 + 1
    matchesString2 = matchesString2 + "Selection Match #"+ear2plus1+" ("+YearArray(xxyy(ii+ear2))+ ") was the #"+VerificationRanks2(AKverifyRMS,YearArray(xxyy(ii+ear2)))+" best hindcast match."+cr
  end do
end if
delete(xxyy)


do sr = 0, dimsizes(weightedArray1) - 1
  r1(sr)=(s1(sr)*specialslope)+specialintercept
  r1b(sr)=(s1b(sr)*specialslopeb)+specialinterceptb
end do


asciiwrite (filedir+"matches2.txt" , matchesString2)
zz = systemfunc("mv -f "+filedir+"matches2.txt "+output_dir+"/matches2.txt")






  plotYear1 = new(3,float)
  plotYear2 = new(3,float)
  plotYear3 = new(3,float)
  plotYear4 = new(3,float)
  plotYear5 = new(3,float)
  plotForecast = new(3,float)
  plotAverage = new(3,float)
  plotActual = new(3,float)

  do av = 0, validCount - 1
    if (av .eq. 0) then
      plotYear1(0) = validActualsM2(av) - validEstimatesM2(av)
      plotYear1(1) = validActualsM1(av) - validEstimatesM1(av)
      plotYear1(2) = validActuals(av) - validEstimates(av)
    end if
    if (av .eq. 1) then
      plotYear2(0) = validActualsM2(av) - validEstimatesM2(av)
      plotYear2(1) = validActualsM1(av) - validEstimatesM1(av)
      plotYear2(2) = validActuals(av) - validEstimates(av)
    end if
    if (av .eq. 2) then
      plotYear3(0) = validActualsM2(av) - validEstimatesM2(av)
      plotYear3(1) = validActualsM1(av) - validEstimatesM1(av)
      plotYear3(2) = validActuals(av) - validEstimates(av)
    end if
    if (av .eq. 3) then
      plotYear4(0) = validActualsM2(av) - validEstimatesM2(av)
      plotYear4(1) = validActualsM1(av) - validEstimatesM1(av)
      plotYear4(2) = validActuals(av) - validEstimates(av)
    end if
    if (av .eq. 4) then
      plotYear5(0) = validActualsM2(av) - validEstimatesM2(av)
      plotYear5(1) = validActualsM1(av) - validEstimatesM1(av)
      plotYear5(2) = validActuals(av) - validEstimates(av)
    end if
  end do
  plotForecast(0) = SeaIceForecastM2 - targetSeaIceTrendM2
  plotForecast(1) = SeaIceForecastM1 - targetSeaIceTrendM1
  plotForecast(2) = SeaIceForecast - targetSeaIceTrend


if (useryear.lt.2020) then
    plotActual(0) = targetSeaIceM2 - targetSeaIceTrendM2
    plotActual(1) = targetSeaIceM1 - targetSeaIceTrendM1
    plotActual(2) = targetSeaIce - targetSeaIceTrend
end if
if (useryear.eq.2020.and.fg.le.currentMonth) then
    plotActual(0) = targetSeaIceM2 - targetSeaIceTrendM2
    plotActual(1) = targetSeaIceM1 - targetSeaIceTrendM1
    plotActual(2) = targetSeaIce - targetSeaIceTrend
end if

  lineData = new((/validCount+2,3/),float)
  lineData(0,:) = plotForecast
  if (.not.ismissing(plotYear1(2))) then
    lineData(1,:) = plotActual
  end if
  templevA = 2
  if (.not.ismissing(plotYear1(2))) then
    lineData(templevA,:) = plotYear1
    templevA = templevA + 1
  end if
  if (.not.ismissing(plotYear2(2))) then
    lineData(templevA,:) = plotYear2
    templevA = templevA + 1
  end if
  if (.not.ismissing(plotYear3(2))) then
    lineData(templevA,:) = plotYear3
    templevA = templevA + 1
  end if
  if (.not.ismissing(plotYear4(2))) then
    lineData(templevA,:) = plotYear4
    templevA = templevA + 1
  end if
  if (.not.ismissing(plotYear5(0))) then
    lineData(templevA,:) = plotYear5
    templevA = templevA + 1
  end if

SeaIceDeparts = new(NumAnalysisYears,float)
do qq=0,NumAnalysisYears-1
  SeaIceDeparts(qq) = theSeaIceMonthCalcsM0(1,qq+1)
end do
betaSeaIcecor2 = regline_stats(SeaIceDeparts,ydep)
betaSeaIceR2 = betaSeaIcecor2@r


do qq=0,NumAnalysisYears-1
  SeaIceDeparts(qq) = theSeaIceMonthCalcsM0(5,qq+1)
end do



betaSeaIcecor = regline_stats(SeaIceDeparts,ydep)
betaSLPcor = regline_stats(slpAnalysisBlue2,ydep)
betaH500cor = regline_stats(h500AnalysisBlue2,ydep)
betaT2Mcor = regline_stats(t2mAnalysisBlue2,ydep)
betaT925cor = regline_stats(t925AnalysisBlue2,ydep)
betaSSTcor = regline_stats(sstAnalysisBlue2,ydep)
betaICEcor = regline_stats(iceAnalysisBlue2,ydep)

j7 = regline(SeaIceDeparts,ydep)
k7 = regline(slpAnalysisBlue2,ydep)
l7 = regline(h500AnalysisBlue2,ydep)
m7 = regline(t2mAnalysisBlue2,ydep)
n7 = regline(t925AnalysisBlue2,ydep)
o7 = regline(sstAnalysisBlue2,ydep)
p7 = regline(iceAnalysisBlue2,ydep)

betaSeaIceR = betaSeaIcecor@r
betaSLPR = betaSLPcor@r
betaH500R = betaH500cor@r
betaT2MR = betaT2Mcor@r
betaT925R = betaT925cor@r
betaSSTR = betaSSTcor@r
betaICER = betaICEcor@r

if(j7.lt.0)then
  betaSeaIceR = 0-betaSeaIceR
end if
if(k7.lt.0)then
  betaSLPR = 0-betaSLPR
end if
if(l7.lt.0)then
  betaH500R = 0-betaH500R
end if
if(m7.lt.0)then
  betaT2MR = 0-betaT2MR
end if
if(n7.lt.0)then
  betaT925R = 0-betaT925R
end if
if(o7.lt.0)then
  betaSSTR = 0-betaSSTR
end if
if(p7.lt.0)then
  betaICER = 0-betaICER
end if

monback=exmth+1

CorString=""
CorString="Multiple R (no sign)="+sprintf("%5.2f",betaMultRcor)+", R-square="+sprintf("%5.2f",betaMultR2cor)+", SLP R="+sprintf("%5.2f",betaSLPR)+", Z Height R="+sprintf("%5.2f",betaH500R)+", 2-Meter Temp R="+sprintf("%5.2f",betaT2MR)+", T Height R="+sprintf("%5.2f",betaT925R)+", SST R="+sprintf("%5.2f",betaSSTR)+", Sea Ice Extent R="+sprintf("%5.2f",betaSeaIceR)


asciiwrite (filedir+"correlations.txt" , CorString)
zz = systemfunc("mv -f "+filedir+"correlations.txt "+output_dir+"/correlations.txt")


  wks_pan = gsn_open_wks(wtype,filedir+"pan_ice1")
  myRes = True
  x = new(3,float)
  x = (/1,2,3/)
  xlabels = (/"-2 Months","-1 Month","Forecast Month"/)
  myRes@tmXBMode = "Explicit"
  ;myRes@tmXBValues = tofloat(lineData)
  myRes@tmXBLabels = xlabels
  myRes@tmLabelAutoStride = True

  myRes@xyDashPattern  = 0                         ; Make curves all solid
  myRes@xyMarkLineMode = "MarkLines"               ; Markers *and* lines
  myRes@xyMonoLineThickness = False
  myRes@xyLineThicknessF = (/3.0/)
  myRes@xyLineThicknesses = (/10.0,5.0,1.0,1.0,1.0,1.0,1.0,1.0,1.0/)
  myRes@xyLineColors := (/"blue","red","black","black","black","black","black","black","black"/) ; 3 different colors
  myRes@xyMarker = 12
  myRes@xyMarkerSizeF = 20
  myRes@xyMarkerColors := (/"blue","red","black","black","black","black","black","black","black"/) ; 3 different colors
  myRes@tiMainString = "Analog Sea Ice Extents for "+monthRangeString1+":"+iceYearsString+"~C~for "+monthRangeString2+" following years listed above."
  myRes@tiXAxisString = " ~C~Sea Ice Anomaly forecast during " + monthRangeString2+" "+useryearString2 +" time~C~period using valid analogs for " + monthRangeString1 + " " + useryear+".~C~Forecast is "+SeaIceForecast+" million sq. km. (rightmost point of blue line)~C~Blue Line = Analog Forecast~C~Red Line = Actual Sea Ice~C~Gray Lines = Analog years"
  myRes@tiYAxisString = "Million Sq. KM from "+yrStrtIceClm+"-"+yrLastIceClm+ " Trend"
  myRes@tmXBOn = False
  myRes@tmXBLabelsOn = False

  myRes@gsnMaximize = True

  myPlot = gsn_csm_xy(wks_pan,x,lineData,myRes)



    zz = systemfunc("mv -f "+filedir+"pan_ice1.png "+output_dir+"/ice1.png")




  delete(validIceYears)
  delete(maxseaiceyear)
  delete(the5AnalogYears)
  ;delete(theRegression)
  ;delete(theRegressionM1)
  ;delete(theRegressionM2)
  ;delete(theSlope)
  ;delete(theSlopeM1)
  ;delete(theSlopeM2)
  ;delete(theYintercept)
  ;delete(theYinterceptM1)
  ;delete(theYinterceptM2)
  delete(theEstimates)
  delete(theEstimatesM1)
  delete(theEstimatesM2)
  delete(theActuals)
  delete(theActualsM1)
  delete(theActualsM2)
  delete(seaIceMonth)
  delete(seaIceMonthM1)
  delete(seaIceMonthM2)
  delete(validEstimates)
  delete(validEstimatesM1)
  delete(validEstimatesM2)
  delete(validActuals)
  delete(validActualsM1)
  delete(validActualsM2)
  delete(aveDeviation)
  delete(aveDeviationM1)
  delete(aveDeviationM2)
  delete(aveIce)
  delete(aveIceM1)
  delete(aveIceM2)
  delete(aveEst)
  delete(aveEstM1)
  delete(aveEstM2)
  delete(targetSeaIce)
  delete(targetSeaIceM1)
  delete(targetSeaIceM2)
  delete(targetSeaIceTrend)
  delete(targetSeaIceTrendM1)
  delete(targetSeaIceTrendM2)
  delete(SeaIceForecast)
  delete(SeaIceForecastM1)
  delete(SeaIceForecastM2)
  delete(plotYear1)
  delete(plotYear2)
  delete(plotYear3)
  delete(plotYear4)
  delete(plotYear5)
  delete(plotForecast)
  delete(plotAverage)
  delete(plotActual)
  delete(lineData)
  delete(top30Years)
  delete(SeaIceDeparts)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; This ends the (lengthy) section where
; sea ice extent is estimated for the
; forecast year (only single month) based
; on the average deviation from the trend
; line of the analog years (since 1979)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


delete(res)
startTrendYear = 1949
endTrendYear = 2019
if (useryear.eq.2020) then
 endTrendYear = 2019
end if


if (doSpecial.eq.True) then

  if(variable.eq.1.and.specialnum.eq.99) then
    specialAnalysis1 = slpAnalysisRed1
    specialText = monthRangeString2+" SLP"+" (Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4+")"
  end if
  if(variable.eq.4.and.specialnum.eq.99) then
    specialAnalysis1 = h500AnalysisRed1
    specialText = monthRangeString2+" Z"+getlev(heightlev)+" (Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4+")"
  end if
  if(variable.eq.3.and.specialnum.eq.99) then
    specialAnalysis1 = t2mAnalysisRed1
    specialText = monthRangeString2+" T2M"+" (Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4+")"
  end if
  if(variable.eq.4.and.specialnum.eq.99) then
    specialAnalysis1 = t925AnalysisRed1
    specialText = monthRangeString2+templevelORrh+" (Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4+")"
  end if
  if(variable.eq.5.and.specialnum.eq.99) then
    specialAnalysis1 = sstAnalysisRed1
    specialText = monthRangeString2+" SST"+" (Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4+")"
  end if
  if(variable.eq.6.and.specialnum.eq.99) then
    specialAnalysis1 = iceAnalysisRed1
    specialText = monthRangeString2+" Precip"+" (Lat: "+AK1 +"-"+AK2+" Lon: "+AK3+"-"+AK4+")"
  end if



  wtypez           = "png"
  wtypez@wkWidth  = 1000
  wtypez@wkHeight = 1000

  ;rrrnewlat  = latGlobeF(89, "lat", "latitude", "degrees_north")
  ;rrrnewlat2  = latGlobeF(91, "lat", "latitude", "degrees_north")
  ;rrrnewlat  = rrrnewlat2(1:89)
  ;rrrnewlon  = lonGlobeF(180, "lon", "longitude", "degrees_east")

  rrr1 = escorc(specialAnalysis1,mySLPCorArray(lat|:,lon|:,time|:))
  rrr2 = escorc(specialAnalysis1,myH500CorArray(lat|:,lon|:,time|:))
  rrr3 = escorc(specialAnalysis1,myT2MCorArray(lat|:,lon|:,time|:))
  rrr4 = escorc(specialAnalysis1,myT925CorArray(lat|:,lon|:,time|:))
  rrr5 = escorc(specialAnalysis1,mySSTCorArray(lat|:,lon|:,time|:))
  rrr6 = escorc(specialAnalysis1,myICECorArray(lat|:,lon|:,time|:))

  rrrnewlat = slp&lat
  rrrnewlon = slp&lon

  rrr1!0="lat"
  rrr1!1="lon"
  rrr1&lat=rrrnewlat
  rrr1&lon=rrrnewlon
  rrr1&lat@units=slp&lat@units
  rrr1&lon@units=slp&lon@units
  rrr2!0="lat"
  rrr2!1="lon"
  rrr2&lat=rrrnewlat
  rrr2&lon=rrrnewlon
  rrr2&lat@units=slp&lat@units
  rrr2&lon@units=slp&lon@units
  rrr3!0="lat"
  rrr3!1="lon"
  rrr3&lat=rrrnewlat
  rrr3&lon=rrrnewlon
  rrr3&lat@units=slp&lat@units
  rrr3&lon@units=slp&lon@units
  rrr4!0="lat"
  rrr4!1="lon"
  rrr4&lat=rrrnewlat
  rrr4&lon=rrrnewlon
  rrr4&lat@units=slp&lat@units
  rrr4&lon@units=slp&lon@units
  rrr5!0="lat"
  rrr5!1="lon"
  rrr5&lat=rrrnewlat
  rrr5&lon=rrrnewlon
  rrr5&lat@units=slp&lat@units
  rrr5&lon@units=slp&lon@units
  rrr6!0="lat"
  rrr6!1="lon"
  rrr6&lat=rrrnewlat
  rrr6&lon=rrrnewlon
  rrr6&lat@units=slp&lat@units
  rrr6&lon@units=slp&lon@units



  wks_pan = gsn_open_wks(wtypez,filedir+"cor_slp_11_a")
  res = SetRes1(-1, 1, 0.1,25,210)
  rcor  = Significance(specialAnalysis1,mySLPCorArray)
  copy_VarCoords(slp(0,:,:), rcor)
  copy_VarMeta(slp(0,:,:), rcor)
  res@tiXAxisString = "Correlation Significance for "+monthRangeString1+" SLP~C~And "+specialText+" ~C~This is a monthly average "
  if (detrend.eq.0) then
    res@tiXAxisString = "Correlation Significance for "+monthRangeString1+" SLP~C~And "+specialText+" ~C~This is a monthly average "
  end if
  plot90 = gsn_csm_contour_map_polar(wks_pan,rrr1,res)
  poly90a = gsn_add_polyline(wks_pan,plot90,lon_box,lat_box,AKboxgreen)
  draw(plot90)
  frame(wks_pan)
  delete([/wks_pan,rcor,res/])
  zz = systemfunc("mv -f "+filedir+"cor_slp_11_a.png "+output_dir+"/cor_slp_11_a.png")
  zz = systemfunc("convert "+output_dir+"/cor_slp_11_a.png -crop 800x1000+100+0 -quality 80 "+output_dir+"/cor_slp_11.jpg")
  zz = systemfunc("rm -f "+output_dir+"/cor_slp_11_a.png")


  wks_pan = gsn_open_wks(wtypez,filedir+"cor_h500_11_a")
  res = SetRes1(-1, 1, 0.1,25,210)
  rcor  = Significance(specialAnalysis1,myH500CorArray)
  copy_VarCoords(h500(0,:,:), rcor)
  copy_VarMeta(h500(0,:,:), rcor)
  res@tiXAxisString = "Correlation Significance for "+monthRangeString1+" Z"+getlev(heightlev)+" ~C~And "+specialText+" ~C~This is a monthly average "
  if (detrend.eq.0) then
    res@tiXAxisString = "Correlation Significance for "+monthRangeString1+" Z"+getlev(heightlev)+" ~C~And "+specialText+" ~C~This is a monthly average "
  end if
  plot90 = gsn_csm_contour_map_polar(wks_pan,rrr2,res)
  poly90a = gsn_add_polyline(wks_pan,plot90,lon_box,lat_box,AKboxgreen)
  draw(plot90)
  frame(wks_pan)
  delete([/wks_pan,rcor,res/])
  zz = systemfunc("mv -f "+filedir+"cor_h500_11_a.png "+output_dir+"/cor_h500_11_a.png")
  zz = systemfunc("convert "+output_dir+"/cor_h500_11_a.png -crop 800x1000+100+0 -quality 80 "+output_dir+"/cor_h500_11.jpg")
  zz = systemfunc("rm -f "+output_dir+"/cor_h500_11_a.png")

  wks_pan = gsn_open_wks(wtypez,filedir+"cor_t2m_11_a")
  res = SetRes1(-1, 1, 0.1,25,210)
  rcor  = Significance(specialAnalysis1,myT2MCorArray)
  copy_VarCoords(t2m(0,:,:), rcor)
  copy_VarMeta(t2m(0,:,:), rcor)
  res@tiXAxisString = "Correlation Significance for "+monthRangeString1+" T2M ~C~And "+specialText+" ~C~This is a monthly average "
  if (detrend.eq.0) then
    res@tiXAxisString = "Correlation Significance for "+monthRangeString1+" T2M ~C~And "+specialText+" ~C~This is a monthly average "
  end if
  plot90 = gsn_csm_contour_map_polar(wks_pan,rrr3,res)
  poly90a = gsn_add_polyline(wks_pan,plot90,lon_box,lat_box,AKboxgreen)
  draw(plot90)
  frame(wks_pan)
  delete([/wks_pan,rcor,res/])
  zz = systemfunc("mv -f "+filedir+"cor_t2m_11_a.png "+output_dir+"/cor_t2m_11_a.png")
  zz = systemfunc("convert "+output_dir+"/cor_t2m_11_a.png -crop 800x1000+100+0 -quality 80 "+output_dir+"/cor_t2m_11.jpg")
  zz = systemfunc("rm -f "+output_dir+"/cor_t2m_11_a.png")

  wks_pan = gsn_open_wks(wtypez,filedir+"cor_t925_11_a")
  res = SetRes1(-1, 1, 0.1,25,210)
  rcor  = Significance(specialAnalysis1,myT925CorArray)
  copy_VarCoords(t925(0,:,:), rcor)
  copy_VarMeta(t925(0,:,:), rcor)
  res@tiXAxisString = "Correlation Significance for "+monthRangeString1+templevelORrh+" ~C~And "+specialText+" ~C~This is a monthly average "
  if (detrend.eq.0) then
    res@tiXAxisString = "Correlation Significance for "+monthRangeString1+templevelORrh+" ~C~And "+specialText+" ~C~This is a monthly average "
  end if
  plot90 = gsn_csm_contour_map_polar(wks_pan,rrr4,res)
  poly90a = gsn_add_polyline(wks_pan,plot90,lon_box,lat_box,AKboxgreen)
  draw(plot90)
  frame(wks_pan)
  delete([/wks_pan,rcor,res/])
  zz = systemfunc("mv -f "+filedir+"cor_t925_11_a.png "+output_dir+"/cor_t925_11_a.png")
  zz = systemfunc("convert "+output_dir+"/cor_t925_11_a.png -crop 800x1000+100+0 -quality 80 "+output_dir+"/cor_t925_11.jpg")
  zz = systemfunc("rm -f "+output_dir+"/cor_t925_11_a.png")




  wks_pan = gsn_open_wks(wtypez,filedir+"cor_sst_11_a")
  res = SetRes1(-1, 1, 0.1,25,210)
  rcor  = Significance(specialAnalysis1,mySSTCorArray)
  res@tiXAxisString = "Correlation Significance for "+monthRangeString1+" SST ~C~And "+specialText+" ~C~This is a monthly average "
  if (detrend.eq.0) then
    res@tiXAxisString = "Correlation Significance for "+monthRangeString1+" SST ~C~And "+specialText+" ~C~This is a monthly average "
  end if
  plot90 = gsn_csm_contour_map_polar(wks_pan,rrr5,res)
  poly90a = gsn_add_polyline(wks_pan,plot90,lon_box,lat_box,AKboxgreen)
  draw(plot90)
  frame(wks_pan)
  delete([/wks_pan,rcor,res/])
  zz = systemfunc("mv -f "+filedir+"cor_sst_11_a.png "+output_dir+"/cor_sst_11_a.png")
  zz = systemfunc("convert "+output_dir+"/cor_sst_11_a.png -crop 800x1000+100+0 -quality 80 "+output_dir+"/cor_sst_11.jpg")
  zz = systemfunc("rm -f "+output_dir+"/cor_sst_11_a.png")



  abssum = rrr1    ; initialize
  abssum@_FillValue = 99999.0
  abssum = abssum@_FillValue
  absdims = dimsizes(rrr1)

  abslats = absdims(0)
  abslons = absdims(1)
    do r=0, abslats -1
      do s=0, abslons -1
        if(.not.ismissing(rrr5(r,s))) then
          abssum(r,s) = abs(rrr1(r,s))+abs(rrr2(r,s))+abs(rrr3(r,s))+abs(rrr4(r,s))+abs(rrr5(r,s))
        end if
        if(ismissing(rrr5(r,s))) then
          abssum(r,s) = (abs(rrr1(r,s))+abs(rrr2(r,s))+abs(rrr3(r,s))+abs(rrr4(r,s))) * 1.25
        end if
      end do
    end do

;exit;;;

  wks_pan = gsn_open_wks(wtypez,filedir+"cor_sum_11_a")
  res = SetRes1(0, 2, 0.2,25,210)
  res@tiXAxisString = "Summed Correlation Significance for "+monthRangeString1+" ~C~And "+specialText+" ~C~This is a monthly average "
  if (detrend.eq.0) then
    res@tiXAxisString = "Summed Correlation Significance for "+monthRangeString1+" ~C~And "+specialText+" ~C~This is a monthly average "
  end if
  plot90 = gsn_csm_contour_map_polar(wks_pan,abssum,res)
  draw(plot90)
  frame(wks_pan)
  delete([/wks_pan,res/])
  zzz = systemfunc("mv -f "+filedir+"cor_sum_11_a.png "+output_dir+"/cor_sum_11_a.png")
  zzzz = systemfunc("chmod 777 "+output_dir+"/cor_sum_11_a.png")
  zzzzz = systemfunc("convert "+output_dir+"/cor_sum_11_a.png -crop 800x1000+100+0 -quality 80 "+output_dir+"/cor_sum_11z.jpg")
  zzzzzb = systemfunc("mv -f "+output_dir+"/cor_sum_11z.jpg "+output_dir+"/cor_sum_11.jpg")
  zzzzzz = systemfunc("rm -f "+output_dir+"/cor_sum_11_a.png")
;  zz = systemfunc("mv -f "+filedir+"cor_sum_11_a.png "+output_dir+"/cor_sum_11_a.png")
;  zz = systemfunc("convert "+output_dir+"/cor_sum_11_a.png -crop 800x1000+50+0 -quality 80 "+output_dir+"/cor_sum_11.jpg")
;  zz = systemfunc("rm -f "+output_dir+"/cor_sum_11_a.png")

  absmax = rrr1    ; initialize
  absmax@_FillValue = 99999.0
  absmax = absmax@_FillValue

  xymax = tofloat(0.0)
  do r=0, abslats -1
    do s=0, abslons -1
      xymax = abs(rrr1(r,s))
      if(.not.ismissing(rrr2(r,s))) then
      if(abs(rrr2(r,s)).gt.xymax) then
        xymax = abs(rrr2(r,s))
      end if
      end if
      if(.not.ismissing(rrr3(r,s))) then
      if(abs(rrr3(r,s)).gt.xymax) then
        xymax = abs(rrr3(r,s))
      end if
      end if
      if(.not.ismissing(rrr4(r,s))) then
      if(abs(rrr4(r,s)).gt.xymax) then
        xymax = abs(rrr4(r,s))
      end if
      end if
      if(.not.ismissing(rrr5(r,s))) then
      if(.not.ismissing(rrr5(r,s))) then
        if(abs(rrr5(r,s)).gt.xymax) then
          xymax = abs(rrr5(r,s))
        end if
      end if
      end if
      absmax(r,s) = tofloat(xymax)
      xymax = tofloat(0.0)
    end do
  end do

  wks_pan = gsn_open_wks(wtypez,filedir+"cor_max_11_a")
  res = SetRes1(0, 1, 0.1,25,210)
  res@tiXAxisString = "Max Correlation Significance for "+monthRangeString1+" ~C~And "+specialText+" ~C~This is a monthly average "
  if (detrend.eq.0) then
    res@tiXAxisString = "Max Correlation Significance for "+monthRangeString1+" ~C~And "+specialText+" ~C~This is a monthly average "
  end if
  plot90 = gsn_csm_contour_map_polar(wks_pan,absmax,res)
  draw(plot90)
  frame(wks_pan)
  delete([/wks_pan,res/])
  zzz = systemfunc("mv -f "+filedir+"cor_max_11_a.png "+output_dir+"/cor_max_11_a.png")
  zzzz = systemfunc("chmod 777 "+output_dir+"/cor_max_11_a.png")
  zzzzz = systemfunc("convert "+output_dir+"/cor_max_11_a.png -crop 800x1000+100+0 -quality 80 "+output_dir+"/cor_max_11z.jpg")
  zzzzzb = systemfunc("mv -f "+output_dir+"/cor_max_11z.jpg "+output_dir+"/cor_max_11.jpg")
  zzzzzz = systemfunc("rm -f "+output_dir+"/cor_max_11_a.png")
;  zz = systemfunc("mv -f "+filedir+"cor_max_11_a.png "+output_dir+"/cor_max_11_a.png")
;  zz = systemfunc("convert "+output_dir+"/cor_max_11_a.png -crop 800x1000+50+0 -quality 80 "+output_dir+"/cor_max_11.jpg")
;  zz = systemfunc("rm -f "+output_dir+"/cor_max_11_a.png")


  absmax2 = rrr1    ; initialize
  absmax2@_FillValue = 99999.0
  absmax2 = tofloat(1.0)

  gridvals = new(5,float)
  gridvals = (/0.0,0.0,0.0,0.0,0.0/)

  xymax2 = toint(1)
  do r=0, abslats -1
    do s=0, abslons -1
      gridvals = (/ abs(rrr1(r,s)), abs(rrr2(r,s)), abs(rrr3(r,s)), abs(rrr4(r,s)), abs(rrr5(r,s)) /)
      xymax2 = toint(maxind(gridvals) + 1)
      absmax2(r,s) = tofloat(xymax2)
      xymax2 = toint(1)
      gridvals = (/0.0,0.0,0.0,0.0,0.0/)
    end do
  end do


  wks_pan = gsn_open_wks(wtypez,filedir+"cor_max2_11_a")
  res = SetRes1(1, 5, 1,25,210)
  res@lbLabelAlignment = "ExternalEdges"
  res@cnLevels              =  (/1.8,2.8,3.8,4.8/)
  res@lbLabelStrings    =    (/"SLP","H500","T2M",templevelORrh,"SST"/) ;pre-Mar 2016
  res@lbLabelPosition  = "Center"             ; label position
  res@lbLabelAlignment = "BoxCenters"         ; label orientation
  res@lbTitleDirection = "Across"
  cmap2 = (/"(/0.90, 0.90, 0.90/)","(/0.99, 0.40, 0.40/)","(/0.40, 0.40, 0.99/)","(/0.40, 0.99, 0.40/)","(/0.99, 0.40, 0.99/)"/)
  res@cnFillPalette = cmap2
  res@lbAutoManage = False
  res@cnLevelSelectionMode = "ExplicitLevels"

  setvalues wks_pan
    "wkBackgroundColor":"white"
    "wkForegroundColor":"black"
  end setvalues
  res@tiXAxisString = "Max Correlation Variable for "+monthRangeString1+" ~C~And "+specialText+" ~C~This is a monthly average "
  if (detrend.eq.0) then
    res@tiXAxisString = "Max Correlation Variable for "+monthRangeString1+" ~C~And "+specialText+" ~C~This is a monthly average "
  end if
  plot90 = gsn_csm_contour_map_polar(wks_pan,absmax2,res)
  draw(plot90)
  frame(wks_pan)
  delete([/wks_pan,res/])
  zzz = systemfunc("mv -f "+filedir+"cor_max2_11_a.png "+output_dir+"/cor_max2_11_a.png")
  zzzz = systemfunc("chmod 777 "+output_dir+"/cor_max2_11_a.png")
  zzzzz = systemfunc("convert "+output_dir+"/cor_max2_11_a.png -crop 800x1000+100+0 -quality 80 "+output_dir+"/cor_max2_11z.jpg")
  zzzzzb = systemfunc("mv -f "+output_dir+"/cor_max2_11z.jpg "+output_dir+"/cor_max2_11.jpg")
  zzzzzz = systemfunc("rm -f "+output_dir+"/cor_max2_11_a.png")
;  zz = systemfunc("mv -f "+filedir+"cor_max2_11_a.png "+output_dir+"/cor_max2_11_a.png")
;  zz = systemfunc("convert "+output_dir+"/cor_max2_11_a.png -crop 800x1000+50+0 -quality 80 "+output_dir+"/cor_max2_11.jpg")
;  zz = systemfunc("rm -f "+output_dir+"/cor_max2_11_a.png")









wks_pan = gsn_open_wks(wtype,filedir+"special_plot")

res55                   = True                     ; plot mods desired
res55 = SetScatterRes("Nothing")
res55@tiYAxisString =specialText
res55@tiXAxisString ="RMSE from Climo: lat "+y1+"-"+y2+" lon"+x1+"-"+x2+"~C~            Pearson's R = "+sprintf("%5.3f", specialCor)
res55@tiMainString = monthRangeString1+" vs "+specialText+ "~C~"+weightString
res55@xyMarkerColors = "forestgreen"
res55@xyMarkerSizeF     = 0.01                     ; Marker size (default 0.01)
res55@xyMarkLineModes     = (/"Markers","Lines"/)  ; choose which have markers
res55@xyLineThicknesses   = (/1,2/)                ; set second line to 2
res55@xyMarkers           = 16                     ; choose type of marker
res55@xyMarkerColor       = "red"                  ; Marker color
res55@xyMarkerSizeF       = 0.005                  ; Marker size (default 0.01)
res55@xyDashPatterns      = 1                      ; solid line

data7      = new ( (/2,dimsizes(s1)/), float)
data7(0,:) = s2
data7(1,:) = (specialslope*s1)+specialintercept

plotr  = gsn_csm_xy (wks_pan,s1,data7,res55)        ; create plot

draw(plotr)
frame(wks_pan)
zz = systemfunc("mv -f "+filedir+"special_plot.png "+output_dir+"/special_plot.png")
delete(plotr)
delete(wks_pan)


wks_pan = gsn_open_wks(wtype,filedir+"special_plot2")

res55                   = True                     ; plot mods desired
res55 = SetScatterRes("Nothing")
res55@tiYAxisString =specialText
res55@tiXAxisString ="RMSE from Selected Year: lat "+y1+"-"+y2+" lon"+x1+"-"+x2
res55@tiMainString = monthRangeString1+" "+useryearString1+" vs "+specialText+ "~C~"+weightString
res55@xyMarkerColors = "forestgreen"
res55@xyMarkerSizeF     = 0.01                     ; Marker size (default 0.01)
res55@xyMarkLineModes     = (/"Markers","Lines"/)  ; choose which have markers
res55@xyLineThicknesses   = (/1,2/)                ; set second line to 2
res55@xyMarkers           = 16                     ; choose type of marker
res55@xyMarkerColor       = "red"                  ; Marker color
res55@xyMarkerSizeF       = 0.005                  ; Marker size (default 0.01)
res55@xyDashPatterns      = 1                      ; solid line

data7b      = new ( (/2,dimsizes(s1b)/), float)
data7b(0,:) = s2
data7b(1,:) = (specialslopeb*s1b)+specialinterceptb

plotr  = gsn_csm_xy (wks_pan,s1b,data7b,res55)        ; create plot

draw(plotr)
frame(wks_pan)
zz = systemfunc("mv -f "+filedir+"special_plot2.png "+output_dir+"/special_plot2.png")
delete(plotr)
delete(res55)
delete(wks_pan)
delete(s1)
delete(s1b)
delete(s2)
delete(r1)
delete(r1b)


end if





;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Now find the analogs. Uses the 'exmth' variable defined earlier
;;; to see how many months to look at. The average of the absolute
;;; values of the differences are computed for each month/year and the user
;;; selected month/year; e.g., if usermonth is July (7), useryear=1975, and
;;; exmonth is 1, find values for 6&7/48, 6&7/49, 6&7/50, through 6&7/2014. (Section 8)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

if (variable.eq.1) then
 myrcor1 = escorc(slpAnalysisRed1,mySLPCorArray(lat|:,lon|:,time|:))
 myrcor2 = escorc(h500AnalysisRed1,mySLPCorArray(lat|:,lon|:,time|:))
 myrcor3 = escorc(t2mAnalysisRed1,mySLPCorArray(lat|:,lon|:,time|:))
 myrcor4 = escorc(t925AnalysisRed1,mySLPCorArray(lat|:,lon|:,time|:))
 myrcor5 = escorc(pdoAnalysis1,mySLPCorArray(lat|:,lon|:,time|:))
 myrcor6 = escorc(npmAnalysis1,mySLPCorArray(lat|:,lon|:,time|:))
 myrcor7 = escorc(soiAnalysis1,mySLPCorArray(lat|:,lon|:,time|:))
 myrcor8 = escorc(sstAnalysisRed1,mySLPCorArray(lat|:,lon|:,time|:))
 myrcor9 = escorc(iceAnalysisRed1,mySLPCorArray(lat|:,lon|:,time|:))
end if
if (variable.eq.2) then
 myrcor1 = escorc(slpAnalysisRed1,myH500CorArray(lat|:,lon|:,time|:))
 myrcor2 = escorc(h500AnalysisRed1,myH500CorArray(lat|:,lon|:,time|:))
 myrcor3 = escorc(t2mAnalysisRed1,myH500CorArray(lat|:,lon|:,time|:))
 myrcor4 = escorc(t925AnalysisRed1,myH500CorArray(lat|:,lon|:,time|:))
 myrcor5 = escorc(pdoAnalysis1,myH500CorArray(lat|:,lon|:,time|:))
 myrcor6 = escorc(npmAnalysis1,myH500CorArray(lat|:,lon|:,time|:))
 myrcor7 = escorc(soiAnalysis1,myH500CorArray(lat|:,lon|:,time|:))
 myrcor8 = escorc(sstAnalysisRed1,myH500CorArray(lat|:,lon|:,time|:))
 myrcor9 = escorc(iceAnalysisRed1,myH500CorArray(lat|:,lon|:,time|:))
end if
if (variable.eq.3) then
 myrcor1 = escorc(slpAnalysisRed1,myT2MCorArray(lat|:,lon|:,time|:))
 myrcor2 = escorc(h500AnalysisRed1,myT2MCorArray(lat|:,lon|:,time|:))
 myrcor3 = escorc(t2mAnalysisRed1,myT2MCorArray(lat|:,lon|:,time|:))
 myrcor4 = escorc(t925AnalysisRed1,myT2MCorArray(lat|:,lon|:,time|:))
 myrcor5 = escorc(pdoAnalysis1,myT2MCorArray(lat|:,lon|:,time|:))
 myrcor6 = escorc(npmAnalysis1,myT2MCorArray(lat|:,lon|:,time|:))
 myrcor7 = escorc(soiAnalysis1,myT2MCorArray(lat|:,lon|:,time|:))
 myrcor8 = escorc(sstAnalysisRed1,myT2MCorArray(lat|:,lon|:,time|:))
 myrcor9 = escorc(iceAnalysisRed1,myT2MCorArray(lat|:,lon|:,time|:))
end if
if (variable.eq.4) then
 myrcor1 = escorc(slpAnalysisRed1,myT925CorArray(lat|:,lon|:,time|:))
 myrcor2 = escorc(h500AnalysisRed1,myT925CorArray(lat|:,lon|:,time|:))
 myrcor3 = escorc(t2mAnalysisRed1,myT925CorArray(lat|:,lon|:,time|:))
 myrcor4 = escorc(t925AnalysisRed1,myT925CorArray(lat|:,lon|:,time|:))
 myrcor5 = escorc(pdoAnalysis1,myT925CorArray(lat|:,lon|:,time|:))
 myrcor6 = escorc(npmAnalysis1,myT925CorArray(lat|:,lon|:,time|:))
 myrcor7 = escorc(soiAnalysis1,myT925CorArray(lat|:,lon|:,time|:))
 myrcor8 = escorc(sstAnalysisRed1,myT925CorArray(lat|:,lon|:,time|:))
 myrcor9 = escorc(iceAnalysisRed1,myT925CorArray(lat|:,lon|:,time|:))
end if
if (variable.eq.5) then
 myrcor1 = escorc(slpAnalysisRed1,mySSTCorArray(lat|:,lon|:,time|:))
 myrcor2 = escorc(h500AnalysisRed1,mySSTCorArray(lat|:,lon|:,time|:))
 myrcor3 = escorc(t2mAnalysisRed1,mySSTCorArray(lat|:,lon|:,time|:))
 myrcor4 = escorc(t925AnalysisRed1,mySSTCorArray(lat|:,lon|:,time|:))
 myrcor5 = escorc(pdoAnalysis1,mySSTCorArray(lat|:,lon|:,time|:))
 myrcor6 = escorc(npmAnalysis1,mySSTCorArray(lat|:,lon|:,time|:))
 myrcor7 = escorc(soiAnalysis1,mySSTCorArray(lat|:,lon|:,time|:))
 myrcor8 = escorc(sstAnalysisRed1,mySSTCorArray(lat|:,lon|:,time|:))
 myrcor9 = escorc(iceAnalysisRed1,mySSTCorArray(lat|:,lon|:,time|:))
end if
if (variable.eq.6) then
 myrcor1 = escorc(slpAnalysisRed1,myICECorArray(lat|:,lon|:,time|:))
 myrcor2 = escorc(h500AnalysisRed1,myICECorArray(lat|:,lon|:,time|:))
 myrcor3 = escorc(t2mAnalysisRed1,myICECorArray(lat|:,lon|:,time|:))
 myrcor4 = escorc(t925AnalysisRed1,myICECorArray(lat|:,lon|:,time|:))
 myrcor5 = escorc(pdoAnalysis1,myICECorArray(lat|:,lon|:,time|:))
 myrcor6 = escorc(npmAnalysis1,myICECorArray(lat|:,lon|:,time|:))
 myrcor7 = escorc(soiAnalysis1,myICECorArray(lat|:,lon|:,time|:))
 myrcor8 = escorc(sstAnalysisRed1,myICECorArray(lat|:,lon|:,time|:))
 myrcor9 = escorc(iceAnalysisRed1,myICECorArray(lat|:,lon|:,time|:))
end if


testatts = cdfAll(0,:,:)
copy_VarAtts(cdfAll(0,:,:),myrcor1)
myrcor1!0   = "lat"
myrcor1!1   = "lon"
myrcor1&lat = testatts&lat
myrcor1&lon = testatts&lon
copy_VarAtts(cdfAll(0,:,:),myrcor2)
myrcor2!0   = "lat"
myrcor2!1   = "lon"
myrcor2&lat = testatts&lat
myrcor2&lon = testatts&lon
copy_VarAtts(cdfAll(0,:,:),myrcor3)
myrcor3!0   = "lat"
myrcor3!1   = "lon"
myrcor3&lat = testatts&lat
myrcor3&lon = testatts&lon
copy_VarAtts(cdfAll(0,:,:),myrcor4)
myrcor4!0   = "lat"
myrcor4!1   = "lon"
myrcor4&lat = testatts&lat
myrcor4&lon = testatts&lon
copy_VarAtts(cdfAll(0,:,:),myrcor5)
myrcor5!0   = "lat"
myrcor5!1   = "lon"
myrcor5&lat = testatts&lat
myrcor5&lon = testatts&lon
copy_VarAtts(cdfAll(0,:,:),myrcor6)
myrcor6!0   = "lat"
myrcor6!1   = "lon"
myrcor6&lat = testatts&lat
myrcor6&lon = testatts&lon
copy_VarAtts(cdfAll(0,:,:),myrcor7)
myrcor7!0   = "lat"
myrcor7!1   = "lon"
myrcor7&lat = testatts&lat
myrcor7&lon = testatts&lon
copy_VarAtts(cdfAll(0,:,:),myrcor8)
myrcor8!0   = "lat"
myrcor8!1   = "lon"
myrcor8&lat = testatts&lat
myrcor8&lon = testatts&lon
copy_VarAtts(cdfAll(0,:,:),myrcor9)
myrcor9!0   = "lat"
myrcor9!1   = "lon"
myrcor9&lat = testatts&lat
myrcor9&lon = testatts&lon
delete(testatts)



allYears=""

if (doLast.eq.True) then
  delete(verify)
  delete(verifyanom)
  delete(tempvar2)
  delete(sel_verify)
  delete(sel_verifyanom)
  delete(top6)
  delete(a5)
  delete(b5)
  delete(c5)
  delete(d5)
  delete(e5)
end if



  delete(theVariableCorArray)
  delete(mySLPCorArray)
  delete(myH500CorArray)
  delete(myT2MCorArray)
  delete(myT925CorArray)
  delete(mySSTCorArray)
  delete(myICECorArray)
  delete(corArray1)
  delete(slpAnalysisBlue1)
  delete(h500AnalysisBlue1)
  delete(t2mAnalysisBlue1)
  delete(t925AnalysisBlue1)
  delete(sstAnalysisBlue1)
  delete(slpAnalysisRed1)
  delete(h500AnalysisRed1)
  delete(t2mAnalysisRed1)
  delete(t925AnalysisRed1)
  delete(sstAnalysisRed1)
  delete(pdoAnalysis1)
  delete(npmAnalysis1)
  delete(soiAnalysis1)
  delete(otherAnalysis1)
  delete(specialAnalysis0)
  delete(specialAnalysis1)
  delete(slpAnalysisBlue2)
  delete(h500AnalysisBlue2)
  delete(t2mAnalysisBlue2)
  delete(t925AnalysisBlue2)
  delete(sstAnalysisBlue2)
  delete(slpAnalysisRed2)
  delete(h500AnalysisRed2)
  delete(t2mAnalysisRed2)
  delete(t925AnalysisRed2)
  delete(sstAnalysisRed2)
  delete(iceAnalysisRed1)
  delete(iceAnalysisRed2)
  delete(iceAnalysisBlue1)
  delete(iceAnalysisBlue2)
  delete(weightedAnalysisBlue2)
  delete(weightedAnalysisRed2)
  delete(xx1)
  delete(xx2)
  delete(xx3)
  delete(xx4)
  delete(xx5)
  delete(xx6)
  delete(slpArrayforRMS)
  delete(h500ArrayforRMS)
  delete(t2mArrayforRMS)
  delete(t925ArrayforRMS)
  delete(sstArrayforRMS)
  delete(YearArrayforRMS)
  delete(AKslpArray)
  delete(AKh500Array)
  delete(AKt2mArray)
  delete(AKt925Array)
  delete(AKsstArray)
  delete(AKboxslpArray3)
  delete(AKboxh500Array3)
  delete(AKboxt2mArray3)
  delete(AKboxt925Array3)
  delete(AKboxsstArray3)
  delete(AKboxslpArray4)
  delete(AKboxh500Array4)
  delete(AKboxt2mArray4)
  delete(AKboxt925Array4)
  delete(AKboxsstArray4)
  delete(iceArrayforRMS)
  delete(iceYearArrayforRMS)
  delete(AKiceArray)
  delete(AKboxiceArray3)
  delete(AKboxiceArray4)

  delete ([/slpBlueBoxMatchYears, h500BlueBoxMatchYears, t2mBlueBoxMatchYears, t925BlueBoxMatchYears, sstBlueBoxMatchYears, iceBlueBoxMatchYears /])
  delete ([/slpRedBoxMatchYears, h500RedBoxMatchYears, t2mRedBoxMatchYears, t925RedBoxMatchYears, sstRedBoxMatchYears, iceRedBoxMatchYears /])
  delete ([/YearArrayMatchYears, iceYearArrayMatchYears /])

  delete(f)
  delete(g)
  delete(dependentVar1)
  delete(dependentVar2)
  delete(ydep)
  delete(X)
  delete(beta)
  delete(cdfAll)
  delete(cdfClm)
  delete(top5anom)
  delete(top5)
  delete(targetanom)
  delete(wwww)
  delete(sortInx)
  delete(sctArr)
  delete(AksctArr)
  delete(AKverifyRMS)
  delete(AKforCor)
  delete(slpClm12)
  delete(slpClma)
  delete(slpClm)
  delete(h500Clm12)
  delete(h500Clma)
  delete(h500Clm)
  delete(t2mClm12)
  delete(t2mClma)
  delete(t2mClm)
  delete(t925Clm12)
  delete(t925Clma)
  delete(t925Clm)
  delete(iceClm12)
  delete(iceClma)
  delete(iceClm)
  delete(sstClm12)
  delete(sstClma)
  delete(sstClm)
  delete(slp)
  delete(h500)
  delete(t2m)
  delete(t925)
  delete(icec)
  delete(sst)
  delete(domanual)
  delete(yearArrayRedBlue)
  delete(sst_std)
  delete(ice_std)

  if(doNMME.eq.True) then
    delete([/nmme,nmme5,yNMME,clatn,nmmelatitude /])
    delete([/cfsv2,cfsv25/])
  end if

  if(doNMME.eq.True.and.variable.eq.3) then
    if (tempadd.le.7) then
      zz2 = systemfunc("convert "+output_dir+"/b.png "+output_dir+"/v3.png  "+output_dir+"/v.png -gravity center +append "+output_dir+"/zzz.png")
      if(winner.eq."NMME") then
        zz2b = systemfunc("convert "+output_dir+"/zzz.png "+output_dir+"/Winner_NMME.png -gravity center -append "+output_dir+"/zzzz.png")
      end if
      if(winner.eq."ANALOGS") then
        zz2b = systemfunc("convert "+output_dir+"/zzz.png "+output_dir+"/Winner_Analogs.png -gravity center -append "+output_dir+"/zzzz.png")
      end if
    zz3 = systemfunc("convert "+output_dir+"/zzzz.png  -bordercolor Black -border 1x1 "+output_dir+"/VerifyPanel_"+sprinti("%0.2i", toint(ID))+".png")
    zz4 = systemfunc("rm -f "+output_dir+"/zzz.png")
    zz5 = systemfunc("rm -f "+output_dir+"/zzzz.png")
    zz6 = systemfunc("chmod 777 "+output_dir+"/VerifyPanel_"+sprinti("%0.2i", toint(ID))+".png")
    end if
  end if




end do
end

; Required for proper run via shell scripts
exit()