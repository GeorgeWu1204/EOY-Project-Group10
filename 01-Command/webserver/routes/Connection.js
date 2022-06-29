var express = require('express');
let net = require('net');
var router = express.Router();


/* GET home page. */
let alrTCPConnection = 0
var client = new net.Socket();

router.get('/', function(req, res, next) {
  // res.render('index', { title: 'Express' });
  if (!alrTCPConnection){
    console.log('Starting a connection...');
    client.connect(12000,'52.90.54.21', function() {
        console.log('Connected');
        alrTCPConnection = 1;
    });
  }
});

module.exports = router;
module.exports.client = client;
