const express = require("express");
const bodyParser = require("body-parser");
const { validate, ValidationError, Joi } = require("express-validation");
const { exec } = require("child_process");
const fs = require("fs");
const https = require("https");
var moment = require("moment");
var hash = require("object-hash");
const winston = require("winston");
const debug = process.env.NODE_ENV === "debug";
const EAPI_ANALYTICS_TOKEN = process.env.EAPI_ANALYTICS_TOKEN;

// Bail if no analytics token is set.
if (!EAPI_ANALYTICS_TOKEN) {
    console.log("No EAPI_ANALYTICS_TOKEN analytics token is set, exiting...");
    process.exit(1);
}

const logger = winston.createLogger({
    level: "debug",
    format: winston.format.combine(
        winston.format.timestamp({
            format: "YYYY-MM-DD HH:mm:ss",
        }),
        winston.format.json()
    ),
    transports: [
        //
        // - Write all logs with level `error` and below to `error.log`
        // - Write all logs with level `info` and below to `combined.log`
        //
        new winston.transports.File({
            filename: "./logs/error.log",
            level: "error",
        }),
        new winston.transports.File({ filename: "./logs/combined.log" }),
    ],
});

//
// If we're not in production then log to the `console` with the format:
// `${info.level}: ${info.message} JSON.stringify({ ...rest }) `
//
if (debug) {
    logger.add(new winston.transports.Console());
}

const port = process.env.NODE_PORT || 3000;
const nclScript = process.env.NCL_SCRIPT || "./forecast.ncl";
const ifUseCache = process.env.EAPI_USE_CACHE || true;
logger.info({ NODE_PORT: port, NODE_ENV: debug ? "debug" : "production" });
logger.info({ NCL_SCRIPT: nclScript });
logger.info({ EAPI_USE_CACHE: ifUseCache });

/* Express setup & configuration */
const app = express();
app.set("views", "./views");
app.set("view engine", "pug");
app.use(express.static("public"));

// Define the validation for parameters
// Only doing the most basic validation at this point
// to reduce security problems.
const paramValidation = {
    query: Joi.object({
        analog_bbox_n: Joi.number(),
        analog_bbox_w: Joi.number(),
        analog_bbox_e: Joi.number(),
        analog_bbox_s: Joi.number(),
        forecast_bbox_n: Joi.number(),
        forecast_bbox_w: Joi.number(),
        forecast_bbox_e: Joi.number(),
        forecast_bbox_s: Joi.number(),
        analog_daterange_start: Joi.date(),
        analog_daterange_end: Joi.date(),
        forecast_daterange_start: Joi.date(),
        forecast_daterange_end: Joi.date(),
        num_analogs: Joi.number(),
        forecast_theme: Joi.number(),
        auto_weight: Joi.number(),
        manual_weight_1: Joi.number(),
        manual_weight_2: Joi.number(),
        manual_weight_3: Joi.number(),
        manual_weight_4: Joi.number(),
        manual_weight_5: Joi.number(),
        correlation: Joi.number(),
        manual_match: Joi.number(),
        override_year_1: Joi.number(),
        override_year_2: Joi.number(),
        override_year_3: Joi.number(),
        override_year_4: Joi.number(),
        override_year_5: Joi.number(),
        detrend_data: Joi.number(),
        pressure_height: Joi.number(),
        pressure_temp: Joi.number(),
    }),
};

/*
Returns a JSON object with the parameters
that the NCL script needs:

a2_usermonth = end month of analog search range
a2_exmth = # of months of analog search range (max 12)
a2_useryear = end year of analog search range
a2_fmnths = # of months after end month of analog search range (max 12)
a2_fmnths2 = # of months in forecast range

Inputs:
a_start, a_end = analog search window start/end.
f_start, f_end = forecast interval start/end.
*/
function getDateParameters(a_start, a_end, f_start, f_end) {
    var analog_start = moment(a_start);
    var analog_end = moment(a_end);
    var forecast_start = moment(f_start);
    var forecast_end = moment(f_end);

    // usermonth = end month of analog search range
    // MomentJS is zero-indexed for month number.
    var usermonth = analog_end.month() + 1;

    // useryear = end year of analog search range
    var useryear = analog_end.year();

    // exmth = # of months of analog search range
    // TODO throw error if this is >12
    // Seems to need to be 1 for correlation plot too
    var as_duration = moment.duration(analog_start.diff(analog_end));
    var exmth = Math.abs(Math.round(as_duration.asMonths())) + 1;

    // fmnths = # of months after end month of forecast range
    // TODO throw error if this is >12
    var fs_duration = moment.duration(analog_end.diff(forecast_start));
    var fmnths = Math.abs(Math.round(fs_duration.asMonths()));

    // fmnths2 = # of months in forecast range
    var ff_duration = moment.duration(forecast_start.diff(forecast_end));
    var fmnths2 = Math.abs(Math.round(ff_duration.asMonths())) + 1;

    dateParams = {
        usermonth: usermonth,
        useryear: useryear,
        exmth: exmth,
        fmnths: fmnths,
        fmnths2: fmnths2,
    };
    return dateParams;
}

/*
Build the command line that runs the NCL code.

nonce = fragment used to build output directory (md5 of query params works)
correlation = if true, then it forces two special params to be set.
params = validated (i.e. expect/handle no garbage or injections) query params
*/
function getNclCliCommand(nonce, correlation, params) {
    dateParams = getDateParameters(
        params.analog_daterange_start,
        params.analog_daterange_end,
        params.forecast_daterange_start,
        params.forecast_daterange_end
    );

    // TODO: Correlations currently aren't supported in this
    // user interface.  Leaving this code fragment here because
    // it has a piece of knowledge relating the working state
    // of the correlation code (must be 3 with month 1)
    if (correlation === true) {
        // 3 forces RMS correlation, and
        // duration (exmth) seems to need to be 1 for this.
        params.correlation = 3;
        dateParams.exmth = 1;
    } else {
        // Fix the value to reduce surprises.
        params.correlation = 0;
    }

    cliString = `
export NCL_OUTPUT_DIR=./public/outputs/${nonce}/ && \
mkdir -p $NCL_OUTPUT_DIR && \
ncl -n -Q \
fromweb=1 \
txtareayesno=2 \
heightlev=${params.pressure_height} \
templev=${params.pressure_temp} \
detrend=${params.detrend_data} \
howmanyyears=${params.num_analogs} \
seaiceyesno=0 \
manualyesno=${params.manual_match} \
manyear1=${params.override_year_1} \
manyear2=${params.override_year_2} \
manyear3=${params.override_year_3} \
manyear4=${params.override_year_4} \
manyear5=${params.override_year_5} \
variable=${params.forecast_theme} \
useryear=${dateParams.useryear} \
fmnths=${dateParams.fmnths} \
fmnths2=${dateParams.fmnths2} \
usermonth=${dateParams.usermonth} \
exmth=${dateParams.exmth} \
slpwgt1=${params.manual_weight_1} \
h500wgt1=${params.manual_weight_2} \
t2mwgt1=${params.manual_weight_3} \
t925wgt1=${params.manual_weight_4} \
sstwgt1=${params.manual_weight_5} \
icewgt1=100 \
autoWgt=${params.auto_weight} \
y1=${params.analog_bbox_s} \
y2=${params.analog_bbox_n} \
x1=${params.analog_bbox_w} \
x2=${params.analog_bbox_e} \
AK1=${params.forecast_bbox_s} \
AK2=${params.forecast_bbox_n} \
AK3=${params.forecast_bbox_w} \
AK4=${params.forecast_bbox_e} \
justcorrelations=${params.correlation} \
ID=12345 \
specialnum=99 \
${nclScript}
    `;
    return cliString;
}

function renderAnalogForecast(pathBase, query, res, cliString) {
    // Build some values used in the template.
    publicPathBase = "./public/" + pathBase;

    var forecast_themes = {
        1: "Sea Level Pressure",
        2: "Pressure level height",
        3: "2-meter Temperature",
        4: "Pressure Level Temperature",
        5: "Sea Surface Temperature",
        6: "Precipitation",
    };

    var pressure_levels = {
        1: "925mb",
        5: "500mb",
        9: "200mb",
    };

    var analog_start = moment(query.analog_daterange_start);
    var analog_end = moment(query.analog_daterange_end);

    // Generate analog month and year ranges for PUG rendering
    var analog_month_range, analog_year_range;
    if (analog_start.format("MMMM YYYY") == analog_end.format("MMMM YYYY")) {
        analog_year_range = analog_start.format("MMMM YYYY");
        analog_month_range = analog_start.format("MMMM");
    } else {
        analog_year_range =
            analog_start.format("MMMM YYYY") +
            "&ndash;" +
            analog_end.format("MMMM YYYY");
        analog_month_range =
            analog_start.format("MMMM") + "&ndash;" + analog_end.format("MMMM");
    }

    var forecast_start = moment(query.forecast_daterange_start);
    var forecast_end = moment(query.forecast_daterange_end);

    // Generate forecast month and year ranges for PUG rendering
    var forecast_month_range, forecast_year_range;
    if (
        forecast_start.format("MMMM YYYY") == forecast_end.format("MMMM YYYY")
    ) {
        forecast_year_range = forecast_start.format("MMMM YYYY");
        forecast_month_range = forecast_start.format("MMMM");
    } else {
        forecast_year_range =
            forecast_start.format("MMMM YYYY") +
            "&ndash;" +
            forecast_end.format("MMMM YYYY");
        forecast_month_range =
            forecast_start.format("MMMM") +
            "&ndash;" +
            forecast_end.format("MMMM");
    }

    forecast_bbox =
        query.forecast_bbox_n +
        "N, " +
        query.forecast_bbox_w +
        "E, " +
        query.forecast_bbox_s +
        "N, " +
        query.forecast_bbox_e +
        "E";
    analog_match_bbox =
        query.analog_bbox_n +
        "N, " +
        query.analog_bbox_w +
        "E, " +
        query.analog_bbox_s +
        "N, " +
        query.analog_bbox_e +
        "E";

    // Read output text file(s) to grab more info
    // If processing failed, catch the error and report to user.
    try {
        // Get the match years!
        yearsText = fs.readFileSync(publicPathBase + "text2.txt", "utf-8");
        let [year1, year2, year3, year4, year5] = yearsText.matchAll(/\d{4}/g);

        // Get the auto-weights!
        weightsText = fs.readFileSync(publicPathBase + "text3.txt", "utf-8");
        // Split the line by commas to get each result,
        // Split each value by colon to get the value.
        let [slpWgt, z925Wgt, t2mWgt, t925Wgt, sstWgt] = weightsText
            .split(",")
            .map((wgt) => wgt.split(":")[1]);
        // Remove training . and whitespace from sstWgt
        sstWgt = sstWgt.replace(/\.\s*$/, "");

        // Get the table of match values by year!
        yearRms = fs.readFileSync(publicPathBase + "matches1.txt", "utf-8");
        // Split by # to get the csv-like values,
        // Remove the first value because it's unwanted text,
        // then unwrap each row to just grab the RMS match numbers.
        yearRms = yearRms.split("#");
        yearRms.shift();
        let [
            year1_rms,
            year2_rms,
            year3_rms,
            year4_rms,
            year5_rms,
        ] = yearRms.map((rms) => rms.split(",")[2]);

        res.render("results", {
            analytics: EAPI_ANALYTICS_TOKEN,
            path: pathBase,
            theme: forecast_themes[query.forecast_theme],
            pressure_height: pressure_levels[query.pressure_height],
            pressure_temp: pressure_levels[query.pressure_temp],
            forecast_year_range: forecast_year_range,
            forecast_month_range: forecast_month_range,
            analog_year_range: analog_year_range,
            analog_month_range: analog_month_range,
            forecast_bbox: forecast_bbox,
            analog_match_bbox: analog_match_bbox,
            year_1: year1,
            year_2: year2,
            year_3: year3,
            year_4: year4,
            year_5: year5,
            year1_rms: year1_rms,
            year2_rms: year2_rms,
            year3_rms: year3_rms,
            year4_rms: year4_rms,
            year5_rms: year5_rms,
            slpWgt: slpWgt,
            z925Wgt: z925Wgt,
            t2mWgt: t2mWgt,
            t925Wgt: t925Wgt,
            sstWgt: sstWgt,
            current_year: moment().format("YYYY"),
        });
    } catch (e) {
        res.render("error", { cliString: cliString, error: e.toString() });
    }
}

// Route for forecast
app.post(
    "/forecast",
    validate(paramValidation, { keyByField: true }, {}),
    (req, res, next) => {
        nonce = hash(req.query, { algorithm: "md5" });
        pathBase = "outputs/" + nonce + "/";
        // If in debug mode, send pre-baked results
        if (debug) {
            logger.info("Displaying static test results.");
            pathBase = "test/";
            renderAnalogForecast(
                pathBase,
                req.query,
                res,
                getNclCliCommand(nonce, false, req.query)
            );
            next();
        } else if (ifUseCache && fs.existsSync("./public/" + pathBase)) {
            // Render results from cache if possible...
            logger.info("Using existing cached result for: %s", pathBase);
            renderAnalogForecast(
                pathBase,
                req.query,
                res,
                getNclCliCommand(nonce, false, req.query)
            );
        } else {
            // Run the processing.
            cliString = getNclCliCommand(nonce, false, req.query);
            logger.debug({ command: cliString, nonce: nonce });
            exec(
                cliString,
                { shell: "/bin/bash", timeout: 120000 },
                (error, stdout, stderr) => {
                    if (error) {
                        logger.error(`exec error: ${error}`);
                        logger.error(stderr);
                        return;
                    }
                    logger.info(stdout);
                    renderAnalogForecast(pathBase, req.query, res, cliString);
                }
            );
        }
    }
);

// This route must come last so it catches validation errors.
app.use(function (err, req, res, next) {
    res.render("invalid", {
        query: JSON.stringify(req.query),
        error: JSON.stringify(err),
    });
});

const httpsServer = https.createServer({
   key: fs.readFileSync('/etc/letsencrypt/live/phoebe.snap.uaf.edu/privkey.pem'),
   cert: fs.readFileSync('/etc/letsencrypt/live/phoebe.snap.uaf.edu/fullchain.pem'),
   }, app);

httpsServer.listen(port, () =>
    console.log(`EAPI-API listening at http://localhost:${port}`)
);
