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

router.post("/destCoord", function(req, res) {
    //"!x23,y45$"
    let destCoord = "!x"+req.body.xDest+",y"+req.body.yDest+"$";
    res.send('ok');
    client.write(destCoord);
    console.log("sent");
});

router.post("/destBall", function(req, res) {
    //"!x23,y45$" req.body.destBall
    let destBall = "!b" + req.body.ballColor + "$";
    res.send('ok');
    client.write(destBall);
    console.log("sent");
});

module.exports = router;
