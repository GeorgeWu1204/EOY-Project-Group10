// import client from index.js
var client = require('./Connection').client

var express = require("express");
var router = express.Router();

router.post("/", function(req, res) {
    //"!start0$"
    const startMsg = "!start" + req.body.corner+"$";
    client.write(startMsg);
});

router.post("/Dest", function(req, res) {
    //"!x34,y45$"
    console.log("hihidest");
    var xDestCoord = req.body.xDest;
    var yDestCoord = req.body.yDest;
    const startMsg = "!x" + xDestCoord + ",y" + yDestCoord + "$";
    console.log(startMsg);
    client.write(startMsg);
    res.write('sure');
    res.end();
});

router.post("/Ball", function(req, res) {
    //"!br$"
    console.log("hihiball");
    // var xDestCoord = req.body.xDest;
    const startMsg = "!b" + req.body.ballColor + "$";
    client.write(startMsg);
    res.write('sure');
    res.end();
});

module.exports = router;
