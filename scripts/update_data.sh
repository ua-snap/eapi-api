#!/bin/bash
# download data, overwriting current files
# sst.mnmean.v5.nc
set -x

TEMP_FP=$NCARG_ROOT/lib/ncarg/data/downloads/sst.mnmean.v5.nc
wget -O $TEMP_FP ftp://ftp.cdc.noaa.gov/Datasets/noaa.ersst.v5/sst.mnmean.nc
# air.mon.mean.nc
TEMP_FP=$NCARG_ROOT/lib/ncarg/data/downloads/air.mon.mean.nc
wget -O $TEMP_FP ftp://ftp.cdc.noaa.gov/Datasets/ncep.reanalysis.derived/surface/air.mon.mean.nc
# hgt.mon.mean.nc
TEMP_FP=$NCARG_ROOT/lib/ncarg/data/downloads/hgt.mon.mean.nc
wget -O $TEMP_FP ftp://ftp.cdc.noaa.gov/Datasets/ncep.reanalysis.derived/pressure/hgt.mon.mean.nc
# air.mon.mean.pres.nc (renamed from default)
TEMP_FP=$NCARG_ROOT/lib/ncarg/data/downloads/air.mon.mean.pres.nc
wget -O $TEMP_FP ftp://ftp.cdc.noaa.gov/Datasets/ncep.reanalysis.derived/pressure/air.mon.mean.nc
# icec.sfc.mon.mean.nc
TEMP_FP=$NCARG_ROOT/lib/ncarg/data/downloads/icec.sfc.mon.mean.nc
wget -O $TEMP_FP ftp://ftp.cdc.noaa.gov/Datasets/ncep.reanalysis.derived/surface_gauss/icec.sfc.mon.mean.nc
# slp.mon.mean.nc
TEMP_FP=$NCARG_ROOT/lib/ncarg/data/downloads/slp.mon.mean.nc
wget -O $TEMP_FP ftp://ftp.cdc.noaa.gov/Datasets/ncep.reanalysis.derived/surface/slp.mon.mean.nc
# precip.mon.anom.nc
TEMP_FP=$NCARG_ROOT/lib/ncarg/data/downloads/precip.mon.anom.nc
wget -O $TEMP_FP ftp://ftp.cdc.noaa.gov/Datasets/prec/precip.mon.anom.nc