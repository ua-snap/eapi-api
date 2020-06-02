const express = require("express");
const bodyParser = require("body-parser");
const { validate, ValidationError, Joi } = require("express-validation");
const { exec } = require("child_process");
const fs  = require("fs");
var moment = require("moment");
var hash = require("object-hash");

const app = express();
const port = 3000;

app.set("views", "./views");
app.set("view engine", "pug");
app.use(express.static("public"));
app.use(bodyParser.json()); // TODO may not need this after dev?

// Wire in the validation code
app.use(function (err, req, res, next) {
    if (err instanceof ValidationError) {
        return res.status(err.statusCode).json(err);
    }

    return res.status(400).json(err);
});

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
    }),
};

app.get(
    "/",
    validate(paramValidation, { keyByField: true }, {}),
    (req, res, next) => {
        nonce = hash(req.query, { algorithm: "md5" });

        // Do a bit of pre-processing to get
        // the dates into a format that the NCL
        // script is expecting.
        var analog_start = moment(req.query.analog_daterange_start);
        var analog_end = moment(req.query.analog_daterange_end);
        var forecast_start = moment(req.query.forecast_daterange_start);
        var forecast_end = moment(req.query.forecast_daterange_end);

        console.log(analog_start, analog_end, forecast_start, forecast_end);

        // usermonth = end month of analog search range
        var usermonth = analog_start.month();

        // useryear = end year of analog search range
        var useryear = analog_end.year();

        // exmth = # of months of analog search range
        var as_duration = moment.duration(analog_start.diff(analog_end));
        var exmth = Math.abs(Math.round(as_duration.asMonths()));

        // fmnths = # of months after end month of forecast range
        var fs_duration = moment.duration(analog_end.diff(forecast_start));
        var fmnths = Math.abs(Math.round(fs_duration.asMonths()));

        // fmnths2 = # of months in forecast range
        var ff_duration = moment.duration(forecast_start.diff(forecast_end));
        var fmnths2 = Math.abs(Math.round(ff_duration.asMonths()));

        output_path = "./public/outputs/" + nonce;

        if (fs.existsSync(output_path)) {
            console.log("Using prerendered results...");
            res.render("results", {
                path: "outputs/" + nonce + "/",
                title: "EAPI Analog Forecast Results",
                message: "Analog forecast results",
                year_1: 2012,
                year_2: 2016,
                year_3: 2017,
                year_4: 2007,
                year_5: 2011,
            });
        } else {
            // Run the processing.

            cli_string = `
export NCL_OUTPUT_DIR=./public/outputs/${nonce}/ && \
mkdir -p $NCL_OUTPUT_DIR && \
conda run -n ncl_stable ncl -n -Q \
fromweb=1 \
txtareayesno=2 \
heightlev=1 \
templev=1 \
detrend=${req.query.detrend_data} \
howmanyyears=${req.query.num_analogs} \
seaiceyesno=0 \
manualyesno=${req.query.manual_match} \
manyear1=${req.query.override_year_1} \
manyear2=${req.query.override_year_2} \
manyear3=${req.query.override_year_3} \
manyear4=${req.query.override_year_4} \
manyear5=${req.query.override_year_5} \
variable=${req.query.forecast_theme} \
useryear=${useryear} \
fmnths=${fmnths} \
fmnths2=${fmnths2} \
usermonth=${usermonth} \
exmth=${exmth} \
slpwgt1=${req.query.manual_weight_1} \
h500wgt1=${req.query.manual_weight_2} \
t2mwgt1=${req.query.manual_weight_3} \
t925wgt1=${req.query.manual_weight_4} \
sstwgt1=${req.query.manual_weight_5} \
icewgt1=100 \
autoWgt=${req.query.auto_weight} \
y1=${req.query.analog_bbox_s} \
y2=${req.query.analog_bbox_n} \
x1=${req.query.analog_bbox_w} \
x2=${req.query.analog_bbox_e} \
AK1=${req.query.forecast_bbox_s} \
AK2=${req.query.forecast_bbox_n} \
AK3=${req.query.forecast_bbox_w} \
AK4=${req.query.forecast_bbox_e} \
justcorrelations=${req.query.correlation} \
ID=12345 \
specialnum=99 \
forecast.ncl
`;
            console.log(cli_string);
            exec(
                cli_string,
                { shell: "/bin/bash", timeout: 120000 },
                (error, stdout, stderr) => {
                    if (error) {
                        console.error(`exec error: ${error}`);
                        return;
                    }
                    console.log(`stdout: ${stdout}`);
                    // console.error(`stderr: ${stderr}`);

                    res.render("results", {
                        path: "outputs/" + nonce + "/",
                        title: "EAPI Analog Forecast Results",
                        message: "Analog forecast results",
                        year_1: 2012,
                        year_2: 2016,
                        year_3: 2017,
                        year_4: 2007,
                        year_5: 2011,
                    });
                }
            );
        }
    }
);

app.listen(port, () =>
    console.log(`Example app listening at http://localhost:${port}`)
);
