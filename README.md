# Analog forecast tool processing & display

API (nodeJS) that listens for requests, does some basic validation and executes the [NCL](https://github.com/ua-snap/eapi-analogs) code which performs processing.  The API then displays results.

## Installation

 1. Have `nodejs`, `nvm` installed.
 1. `nvm install v12.16.3`
 1. `nvm use v12.16.3`
 1. `npm install -g nodemon`
 1. `cd path/to/this/repo`
 1. (Future) Copy `forecast.ncl` to this location or something.  TODO fix.
 1. `npm install`
 1. `nodemon`
