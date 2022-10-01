// import client from index.js
var client = require('./Connection').client

var express = require("express");
var router = express.Router();

router.post("/", function(req, res) {
    //"!stopexp$"
    client.write(req.body.end);
});
module.exports = router;
