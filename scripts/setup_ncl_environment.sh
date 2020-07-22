#!/bin/bash
# setup the installation directories for running the analogs.
# Some libraries are copied over existing built-ins in the
# NCL `csm` folder.
set -x

TEMP_DIR=$NCARG_ROOT/lib/ncarg/nclscripts
if [[ ! -f $TEMP_DIR/csm/BB_utils.ncl ]]
then
    cp -r csm $TEMP_DIR
fi

# no need to make data make data folder, should be present
# copy-paste if no csv folder here
TEMP_DIR=$NCARG_ROOT/lib/ncarg/data
if [[ ! -d $TEMP_DIR/csv ]]
then
    cp -r csv $TEMP_DIR
fi

# make folder for downloaded data if not present
TEMP_DIR=$NCARG_ROOT/lib/ncarg/data/downloads
if [[ ! -d $TEMP_DIR ]]
then
    mkdir $TEMP_DIR
fi
