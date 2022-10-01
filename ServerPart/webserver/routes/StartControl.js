// import client from index.js
var client = require('./Connection').client

var express = require("express");
var router = express.Router();

router.post("/", function(req, res) {
    //"!control0,x10,y6$"
    const startMsg =  "!control" + req.body.corner+",x"+req.body.startXCoord+",y"+req.body.startYCoord+"$";
    client.write(startMsg);
    res.write('sure');
    res.end();
});

router.post("/Node", function(req, res) {
    //"!node$""
    client.write(req.body.start);
    res.write('sure');
    res.end();
});

module.exports = router;
