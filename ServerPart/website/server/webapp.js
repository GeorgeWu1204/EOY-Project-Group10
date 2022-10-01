let processID;

function start() {
    processID = setInterval("presentData()", 500);
}

function presentData() {

    let xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        console.log("get data");
        if (xhttp.readyState==4 && xhttp.status==200){
            document.getElementById("demo").innerHTML = this.responseText;
        }
    };
   
    xhttp.open("GET", "/showdata",true);
    xhttp.send();
}

function closeConnection(processID) {
	window.clearInterval(processID);
}

////////////////////////////

function start2() {
    processID2 = setInterval("presentData2()", 2000);
}

function presentData2() {

    let xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        console.log("get data2");
        if (xhttp.readyState==4 && xhttp.status==200){
            document.getElementById("demo2").innerHTML = this.responseText;
        }
    };
   
    xhttp.open("GET", "/showdata2",true);
    xhttp.send();
}

function closeConnection2(processID2) {
	window.clearInterval(processID2);
}


    // function sleep(sleepDuration){
    //     var now = new Date().getTime();
    //     while(new Date().getTime() < now + sleepDuration){ /* Do nothing */ }
    // }