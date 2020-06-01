const express = require("express");
const bodyParser = require("body-parser");
const { validate, ValidationError, Joi } = require("express-validation");
const { exec } = require("child_process");
var hash = require('object-hash');

const app = express();
const port = 3000;

app.set('views', './views')
app.set('view engine', 'pug')
app.use(express.static('public'))
app.use(bodyParser.json()); // TODO may not need this after dev?

// Wire in the validation code
app.use(function(err, req, res, next) {
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
    (req, res) => {

        nonce = hash(req.query, { algorithm: "md5"} )

        cli_string = `
mkdir -p /tmp/${nonce} && \
export NCL_OUTPUT_DIR=/tmp/${nonce}/ && \
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
useryear=2017 \
fmnths=1 \
fmnths2=2 \
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
usermonth=1 \
exmth=3 \
justcorrelations=${req.query.correlation} \
ID=12345 \
specialnum=99 \
/Users/becrevensten/repos/snap/eapi-analogs/SeaIceSelectPercents4bRMS.ncl
`
        cli_string = "./run_ncl.sh";
        console.log(cli_string);
        exec(cli_string, { shell: "/bin/bash" }, (error, stdout, stderr) => {
            if (error) {
                console.error(`exec error: ${error}`);
                return;
            }
            console.log(`stdout: ${stdout}`);
            console.error(`stderr: ${stderr}`);
        });

        // Here's where we'll dispatch out to the shell and trigger the command.
        res.send(cli_string);
    }
);

app.get("/template", (req, res) => {
    res.render('index', {
        title: 'EAPI Analog Forecast Results',
        message: 'Analog forecast results',
        year_1: 2012,
        year_2: 2016,
        year_3: 2017,
        year_4: 2007,
        year_5: 2011,
    })
})


app.listen(port, () =>
    console.log(`Example app listening at http://localhost:${port}`)
);