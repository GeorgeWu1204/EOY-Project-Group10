let express = require('express');
let server = express();
//let dirName = "C:/Users/mengy/Documents/Year2/EOY Project/Actual/website"

let simulated_data = 1;

// server.get('/', function(req, res) {
//     let options = {
//         root: path.join(__dirname)
//     };
//     res.sendFile('/server/index.html',options);
// });

server.post("/", (req, res) => {
    console.log("Connected to React");
    // res.redirect("/");
  });


// server.get('/webapp.js', function(req, res) {
//  res.sendFile(dirName + '/webapp.js');
// });

// server.get('/showdata', function(req, res) {
//     //console.log("hihihi");
//     // res.sendFile(dirName + '/ajax_info.txt');

//     res.type('text/plain');
//     res.write(simulated_data.toString())
//     res.end();

//     simulated_data = Math.floor(Math.random() * 11);
 
// });

// server.get('/batteryData', function(req, res) {

//     res.type('text/plain');
//     res.write(simulated_data.toString())
//     res.end();
//     simulated_data = Math.floor(Math.random() * 11);
 
// });

// server.get('/showdata2', function(req, res) {
//     //console.log("hihihi");
//     // res.sendFile(dirName + '/ajax_info.txt');

//     res.type('text/plain');
//     res.write(simulated_data.toString())
//     res.end();

//     simulated_data = Math.floor(Math.random() * 11);
 
// });

// function primeOrNot(num){ 
//     if(num<2){ 
//         return " not a prime"; 
//     }else if(num==2){ 
//         return " a prime"; 
//     }else{ 
//         const rootnum = Math.sqrt(num); 
//         for(let d=2; d<rootnum; d++){ 
//             if(num%d==0){ 
//                 return " not a prime";; 
//             } 
//         } 
//     return " a prime"; 
//     } 
// }

// server.post('/primality-test', function(req, res) { 
//     //formData is a JavaScript object 
//     const formData = req.body; 
//     const responseContent = "<p>The number is"+ primeOrNot(formData.num1)+"</p>"; 
//     let htmlTree = htmlParser.parse(htmlContent); 
//     htmlTree.getElementById("form1").insertAdjacentHTML("afterend",responseContent); 
//     res.writeHead(200, {'Content-Type':'text/html'}); 
//     res.end(htmlTree.toString()); 
// });

console.log('Server is running on port 4000');
server.listen(4000);