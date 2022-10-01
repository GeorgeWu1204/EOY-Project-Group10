function requestBattery() {
    processID = setInterval("presentBatteryData()", 500);
}

function presentBatteryData() {

    let xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function() {
        console.log("get data");
        if (xhttp.readyState==4 && xhttp.status==200){
            //document.getElementById("demo").innerHTML = this.responseText;

        }

    };
   
    xhttp.open("GET", "/batteryData",true);
    xhttp.send();
}
