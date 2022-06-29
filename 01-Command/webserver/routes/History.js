// import client from index.js
var client = require('./Connection').client

var express = require("express");
var router = express.Router();



router.get("/", function(req, res, next) {
    console.log("lolo");
    client.write("hist");
    //[{id:1,time:'2022-06-02'},{id:2,time:'2022-06-03'},{id:3,time:'2022-06-04'},{id:4,time:'2022-06-04'}]
    console.log("hihi");
    client.on('data',function(data){
        console.log("hihi this is the data i got line 15");
        console.log(data.toString());
        console.log("end of data line 17");
        res.write(data.toString());
        res.end();
    });
});

// router.post("/List", function(req, res) {
//     client.write("hist");
//     console.log("sent index");
//     //[{id:1,time:'2022-06-02'},{id:2,time:'2022-06-03'},{id:3,time:'2022-06-04'},{id:4,time:'2022-06-04'}]
//     client.on('data',function(data){
//         res.write(data.toString());
//         res.end();
//     });
// });
    
router.post("/", function(req, res) {
    //"hinx2"
    let reqIndex = "hinx"+req.body.Index;
    client.write(reqIndex);
    console.log("sent index");
    //{'Parts':100,'Aliens':[{id:1,x:45,y:56,c:'b',e:1},{id:2,x:0,y:50,c:'g',e:2}]}
    client.on('data',function(data){
        res.write(data.toString());
        res.end();
    });
});

router.post("/Path", function(req, res) {
    //"i2,p0$"
    console.log("enter");
    let reqIndex = "i"+req.body.Index+",p"+req.body.Part;
    client.write(reqIndex);
    console.log(reqIndex);
    //{'Path':[{'x':0,'y':0},{'x':0,'y':10}]}
    client.on('data',function(data){
        console.log(data);
        res.write(data.toString());
        res.end();
    });
});
module.exports = router;
