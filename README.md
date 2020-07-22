# Analog forecast tool processing & display

API (nodeJS) that listens for requests, does some basic validation and executes the [NCL](https://github.com/ua-snap/eapi-analogs) code which performs processing.  The API then displays results.

## Installation on CentOS7

```bash
# Preliminary installation
sudo yum install -y wget fontconfig-devel libXrender-devel libXext libgfortran git ImageMagick;
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash;
nvm install v12.16.3;
nvm alias default v12.16.3;

# Install NCL
wget https://www.earthsystemgrid.org/dataset/ncl.630.0/file/ncl_ncarg-6.3.0.Linux_CentOS7.0_x86_64_gcc482.tar.gz;
sudo mkdir /usr/local/ncl-6.3.0;
sudo chown -R centos /usr/local/ncl-6.3.0/;
tar -zxvf ncl_ncarg-6.3.0.Linux_CentOS7.0_x86_64_gcc482.tar.gz -C /usr/local/ncl-6.3.0;
export NCARG_ROOT=/usr/local/ncl-6.3.0/;
export PATH=$NCARG_ROOT/bin:$PATH;
ncl -V; # Verify this responds with sane value
./scripts/setup_ncl_environment.sh;
./scripts/update_data.sh;

# Install & run the API
npm install;
npm run prod;
```

### Data update cronjob

A cronjob should be added which executes the `./scripts/update_data.sh` script.

## Some notes on running this script

The user running the process must have the `ncl` exec in its path.

```
export NCARG_ROOT=/usr/local/ncl-6.3.0/;
export PATH=$NCARG_ROOT/bin:$PATH;
```

Other environment variables to set:

 * `NODE_PORT`: port for the node service (default 3000)
 * `NODE_ENV`: if set to `production`, app writes log files (`error.log`, `combined.log` for any other log notes) instead of console output.  If set to any other value, this puts the application into debug mode and writes output to console and also bypasses cache, only serving static processing results from `public/test`.
 * `EAPI_ANALYTICS_TOKEN`: Google Analytics token.  Must be set to run, use fake value for dev.
 * `NCL_SCRIPT`: path to NCL script to execute, default `./forecast.ncl`.
 * `EAPI_USE_CACHE`: set to `false` to bypass the cache and run the processing script every time.

### Production

```
npm run prod
npm run restart # to reload running service
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
