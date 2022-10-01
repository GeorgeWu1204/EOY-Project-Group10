// import client from index.js
var client = require('./Connection').client

var express = require("express");
var router = express.Router();

router.post("/", function(req, res) {
    //"!end$"
    client.write(req.body.end);
    res.write('sure');
    res.end();
});
module.exports = router;

