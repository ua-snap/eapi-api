const express = require("express");
const bodyParser = require("body-parser");
const { validate, ValidationError, Joi } = require("express-validation");

const app = express();
const port = 3000;

app.use(bodyParser.json());

// Define the validation for parameters
// Only doing the most basic validation at this point
// to reduce security problems.
const loginValidation = {
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
	}),
};

app.get(
	"/",
	validate(loginValidation, { keyByField: true }, {}),
	(req, res) => {
		// Here's where we'll dispatch out to the shell and trigger the command.
		res.status(200).json(req.query);
	}
);

app.use(function (err, req, res, next) {
	if (err instanceof ValidationError) {
		return res.status(err.statusCode).json(err);
	}

	return res.status(400).json(err);
});

app.listen(port, () =>
	console.log(`Example app listening at http://localhost:${port}`)
);
