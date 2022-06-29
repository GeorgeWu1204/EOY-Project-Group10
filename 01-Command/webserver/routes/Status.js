var client = require('./Connection').client

var express = require("express");
var router = express.Router();


router.get("/", function(req, res, next) {
    client.write("status");
    client.on('data',function(data){
        res.write(data.toString());
        res.end();
    });
    
});

module.exports = router;