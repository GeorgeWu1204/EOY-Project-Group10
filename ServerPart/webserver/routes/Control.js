// import client from index.js
var client = require('./Connection').client

var express = require("express");
var router = express.Router();

router.get("/", function(req, res, next) {
    client.write("req")
    client.on('data',function(data){
        res.write(data.toString());
        res.end();
    });
});

router.post("/", function(req, res) {
    //"!w$" (wsad) for node control mode
    //"!cw$" (wsad) for continuous control mode
    let instructionMsg = "!"+req.body.instruction+"$";

    console.log("sent from control:");
    console.log(instructionMsg);

    client.write(instructionMsg);
    res.write('sure');
    res.end();


    // console.log("post finished");
});

router.post("/Detect", function(req, res) {
    // "!detect$"
    client.write(req.body.detect);
    res.write('sure');
    res.end();
});

module.exports = router;
