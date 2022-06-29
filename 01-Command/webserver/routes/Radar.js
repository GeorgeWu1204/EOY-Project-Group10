// import client from index.js
var client = require('./Connection').client

var express = require("express");
var router = express.Router();

router.post("/Start", function(req, res) {
    client.write(req.body.start);
    res.write('sure');
    res.end();
});

router.post("/End", function(req, res) {
    client.write(req.body.end);
    res.write('sure');
    res.end();
});

module.exports = router;