var createError = require('http-errors');
var express = require('express');
var path = require('path');
var cookieParser = require('cookie-parser');
var logger = require('morgan');
var cors = require("cors");

var ConnectionRouter = require('./routes/Connection');
var NavigationRouter = require('./routes/Navigation');
var StartNavigationRouter = require('./routes/StartNavigation');
var StopExplorationRouter = require('./routes/StopExploration');
var EndNavigationRouter = require('./routes/EndNavigation');
var HistoryRouter = require('./routes/History');
var StatusRouter = require('./routes/Status');
var StartControlRouter = require('./routes/StartControl');
var ControlRouter = require('./routes/Control');
var RadarRouter = require('./routes/Radar');

var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');

app.use(cors());
app.use(logger('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(express.static(path.join(__dirname, 'public')));

app.use('/', ConnectionRouter);
app.use('/Navigation',NavigationRouter);
app.use('/StartNavigation',StartNavigationRouter);
app.use('/StopExploration',StopExplorationRouter);
app.use('/EndNavigation',EndNavigationRouter);
app.use('/History',HistoryRouter);
app.use('/Status',StatusRouter);
app.use('/StartControl',StartControlRouter);
app.use('/Control',ControlRouter);
app.use('/Radar',RadarRouter);

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  next(createError(404));
});

// error handler
app.use(function(err, req, res, next) {
  // set locals, only providing error in development
  res.locals.message = err.message;
  res.locals.error = req.app.get('env') === 'development' ? err : {};

  // render the error page
  res.status(err.status || 500);
  res.render('error');
});

module.exports = app;
