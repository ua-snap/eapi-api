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

## Running

Environment variables to set:

 * `NODE_PORT`: port for the node service (default 3000)
 * `NODE_ENV`: if set to `production`, app writes log files (`error.log`, `combined.log` for any other log notes) instead of console output.  If set to any other value, this puts the application into debug mode and writes output to console and also bypasses cache, only serving static processing results from `public/test`.
 * `NCL_SCRIPT`: path to NCL script to execute, default `./forecast.ncl`.
 * `EAPI_USE_CACHE`: set to `false` to bypass the cache and run the processing script every time.

### Production

```
npm start
```

### Development

```
npm run dev
```

### Development mode

```
export NODE_ENV=debug
npm run dev
```

### Production mode

```
export NODE_ENV=production
npm start
```

## Deploying app

```
npm shrinkwrap
git commit -am "update shrinkwrap"
git push origin master
```
