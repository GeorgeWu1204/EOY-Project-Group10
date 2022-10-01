import React, { Component } from 'react';
import './Control.css';
import Top from './top'
import { Row, Col, Switch, Input, Button, InputNumber } from 'antd';
import { Player } from 'video-react';
import {Battery} from 'react-little-icon'
import background from "../assets/imgs/background.jpg";
import {PathLine} from 'react-svg-pathline';
import {
    XAxis,
    YAxis,
    ScatterChart,
    Scatter
  } from "recharts";
var reqControlProcessID;
var statusProcessID;
class Control extends Component {
    constructor(props) {
        super(props)
        this.state = {
            left:window.xStartCoord + 'px',
            top:-1*window.yStartCoord + 'px',
         
            angle:0,
            direction:1,  // 0123 up right down left
            path:[{'x':window.xStartCoord, 'y':342.32 - window.yStartCoord}],
          
            // pathplan:[{'x': window.xStartCoord, 'y':window.yStartCoord}],
            pathplan:[],
            currentPlanX:0,
            currentPlanY:0,
            status:0,
            startCorner:window.startCorner,
            controlMode:1,
            Aliens:window.alien,
            tower:window.tower,
        }
        this.getStatus = this.getStatus.bind(this);
        this.getControlCoordinate = this.getControlCoordinate.bind(this);
    }
    getStatus (){
        console.log("getstatus");
        fetch(window.ip + "Status")
            .then(res => res.json())
            // negative sign for y of rover is set right here   &    path is converted to 342.32-y set here
            .then(res => this.setState({ status: res.status}))
    }
    
    refreshConnectStatus () {
        statusProcessID = setInterval(this.getStatus, 2000);
    }

    endRefreshConnectStatus () {
        window.clearInterval(statusProcessID);
    }
    componentDidMount() {
        this.refreshConnectStatus();
    }

    componentWillUnmount(){
        this.endRefreshConnectStatus();
        console.log("unmounted status"); 
    }

    // selectCorner(checked){
    //     if (checked) {
    //         // start from top
    //         this.setState({startCorner:1, left:'0px', top:'-342.32px', pathplan:[{'x': 0, 'y':342.32}]}) 
    //     }
    //     else{
    //         // start from bottom
    //         this.setState({startCorner:0, left:'0px', top:'0px', pathplan:[{'x': 0, 'y':0}]})
    //     }
    // }

    selectMode(checked){
        if (checked) {
            // node
            this.setState({controlMode:0, Aliens:[], tower:[], left:'0px', top:'0px', startCorner:0, pathplan:[{'x': 0, 'y':0}], path:[{'x':0, 'y':342.32}]})
            console.log("mode 0");
        }
        else{
            // continuous
            this.setState({controlMode:1})
            console.log("mode 1");
        }
    }
    getControlCoordinate() {
        // console.log("im here");
        if (this.state.startCorner == 0){
            console.log("fetching coord");
            fetch(window.ip + "Control")
                .then(res => res.json())
                // negative sign for y of rover is set right here   &    path is converted to 342.32-y set here
                .then(res => this.setState({ status: res.status, tower: res.Tower, battery: res.battery,  left:(res.xCoord/5.847)+'px', top:(-res.yCoord/5.842)+'px', angle:-res.angle+90, path:this.state.path.concat({'x':res.xCoord/5.847,'y':342.32-(res.yCoord/5.842)}), Aliens:res.Aliens}))
                .then(console.log("coord fetched"))
            }
        
        else if (this.state.startCorner == 1){
            fetch(window.ip + "Control")
                .then(res => res.json())
                // negative sign for y of rover is set right here   &    path is converted to 342.32-y set here
                .then(res => this.setState({ status: res.status, tower: res.Tower, battery: res.battery, left:(res.xCoord/5.847)+'px', top:(-res.yCoord/5.842-342.32)+'px', angle:-res.angle+90, path:this.state.path.concat({'x':res.xCoord/5.847,'y':-(res.yCoord/5.842)}), Aliens:res.Aliens}))
            }
    }

    refreshControlRoverCoord () {
        reqControlProcessID = setInterval(this.getControlCoordinate, 500);
    }
    endRefreshControlRoverCoord () {
        window.clearInterval(reqControlProcessID);
    }

    startControl(checked) {
        if (checked){
            this.endRefreshConnectStatus();
            
            if (this.state.controlMode == 1){
                var xNodeCoord = Math.round (window.xStartCoord/34.2)
                var yNodeCoord = Math.round ((window.startCorner ? -1 * window.yStartCoord + 342.32 : window.yStartCoord )/34.32)
                fetch(window.ip + "StartControl", {
                    method: 'POST',
                    body: JSON.stringify({
                        start: '!control$',
                        corner:this.state.startCorner,
                        startXCoord:xNodeCoord,
                        startYCoord:yNodeCoord // convert to node
                    }),
                    headers: {
                        'Content-type': 'application/json; charset=UTF-8' 
                    }
                })
                .then(async response => {
                    if (response.ok){
                        console.log(response);
                    }
                })
            }
            else{
                fetch(window.ip + "StartControl/Node", {
                    method: 'POST',
                    body: JSON.stringify({
                        start: '!node$',
                    }),
                    headers: {
                        'Content-type': 'application/json; charset=UTF-8' 
                    }
                })
                .then(async response => {
                    if (response.ok){
                        console.log(response);
                    }
                })
            }
            this.refreshControlRoverCoord();
        }
        else {
            this.endRefreshControlRoverCoord();
            fetch(window.ip + "EndNavigation", {
                method: 'POST',
                body: JSON.stringify({
                    end: '!end$', 
                }),
                headers: {
                    'Content-type': 'application/json; charset=UTF-8' 
                }
            })
            .then(async response => {
                if (response.ok){
                    console.log(response);
                }
            })
            this.refreshConnectStatus();
        }
    }

    detectAlien(){
        fetch(window.ip + "Control/Detect", {
            method: 'POST',
            body: JSON.stringify({
                detect: '!detect$'
            }),
            headers: {
                'Content-type': 'application/json; charset=UTF-8' 
            }
        })
        .then(async response => {
            if (response.ok){
                console.log(response);
            }
        })
    }
    move(str){
        fetch(window.ip + "Control", { 
            method: 'POST',
            body: JSON.stringify({
                instruction: str,
            }),
            headers: {
                'Content-type': 'application/json; charset=UTF-8' 
	        }
        })
        .then(async response => {
            if (response.ok){
                console.log(response);
            }
        })
        if((str=='w' && this.state.direction == 0) || (str=='s' && this.state.direction == 2)){
            this.setState({currentPlanY: this.state.currentPlanY + 34.23});
            this.setState({pathplan:this.state.pathplan.concat({'x':this.state.currentPlanX,'y':this.state.currentPlanY+34.23})});
        }
        // else if  (str=='s' && this.state.direction == 2){

        // }
        else if((str=='s' && this.state.direction == 0) || (str=='w' && this.state.direction == 2)){
            this.setState({currentPlanY: this.state.currentPlanY - 34.23});
            this.setState({pathplan:this.state.pathplan.concat({'x':this.state.currentPlanX,'y':this.state.currentPlanY-34.23})});
        }
        else if((str=='w' && this.state.direction == 1) || (str=='s' && this.state.direction == 3)){
            this.setState({currentPlanX: this.state.currentPlanX + 34.2});
            this.setState({pathplan:this.state.pathplan.concat({'x':this.state.currentPlanX+34.2,'y':this.state.currentPlanY})});
        }
        else if((str=='s' && this.state.direction == 1) || (str=='w' && this.state.direction == 3)){
            this.setState({currentPlanX: this.state.currentPlanX - 34.2});
            this.setState({pathplan:this.state.pathplan.concat({'x':this.state.currentPlanX-34.2,'y':this.state.currentPlanY})});
        }
        
        else if (str=='d'){
            this.setState({direction:((this.state.direction+1)%4+4)%4});
        }
        else if (str=='a'){
            this.setState({direction:((this.state.direction-1)%4+4)%4});
        }
        console.log("after");
        console.log(this.state.currentPlanX);
        console.log(this.state.currentPlanY);
        console.log(this.state.direction);
    }

    press(str){
        console.log("before");
        console.log(str);
        fetch(window.ip + "Control", { 
            method: 'POST',
            body: JSON.stringify({
                instruction: 'c'+str,
            }),
            headers: {
                'Content-type': 'application/json; charset=UTF-8' 
	        }
        })
    }

    release(){
        console.log("release");
        fetch(window.ip + "Control", { 
            method: 'POST',
            body: JSON.stringify({
                instruction: 'cr' // release message
            }),
            headers: {
                'Content-type': 'application/json; charset=UTF-8' 
	        }
        })
    }
    
    render() {

        return (
            <div class='bg' style={{ backgroundImage: `url(${background})`  }} >
            <div>
                <Top e='2' />
                <div class='section'>
                    <div class='sectionleft'>
                        <h1><b>Remote Control</b></h1>
                        {/* <span class='subheading'>
                            Map Selection
                        </span>

                        <span><b>
                            bottom <Switch onChange={(checked) => this.selectCorner(checked)}/> top
                        </b></span> */}

                        <span class='subheading'>
                            Control Mode
                        </span>

                        <span class="detectbutton"><b>
                            Continuous <Switch onChange={(checked) => this.selectMode(checked)}/> Node  &nbsp;
                            <Button type="primary" onClick={() => this.detectAlien()}>DETECT</Button>
                        </b></span>

                        <span class='subheading'>
                            Control Rover
                        </span>
                        <span><b>
                            off <Switch onChange={(checked) => this.startControl(checked)}/> on
                        </b></span>

                        {this.state.controlMode == 0?
                            <div class='circle'>
                                <div class='w' onClick={()=>this.move('w')}>▲</div>
                                <div class='s' onClick={()=>this.move('s')}>▼</div>
                                <div class='a' onClick={()=>this.move('a')}>&#8630;</div>
                                <div class='d' onClick={()=>this.move('d')}>&#8631;</div>
                            </div> 
                            :
                            <div class='circle'>
                                <div class='w' onMouseDown={()=>this.press('w')} onMouseUp={()=>this.release()}>▲</div>
                                <div class='s' onMouseDown={()=>this.press('s')} onMouseUp={()=>this.release()}>▼</div>
                                <div class='a' onMouseDown={()=>this.press('a')} onMouseUp={()=>this.release()}>&#8630;</div>
                                <div class='d' onMouseDown={()=>this.press('d')} onMouseUp={()=>this.release()}>&#8631;</div>
                            </div> }
            
    
      {/* <div
        onMouseDown={startCounter}
        onMouseUp={stopCounter}
        onMouseLeave={stopCounter}
        style={elementStyle}
      />
    </div> */}


                    </div>

                    <div class='sectioncenter'>
                        <img class='rover' style={{
                            marginLeft:this.state.left,
                            marginTop:this.state.top,
                            transform: `rotate(${this.state.angle}deg)`}}

                            src={require('../assets/imgs/whiterobot.png')}>
                            
                        </img>
                        {this.state.path && this.state.path.length > 0 ?
                            <svg class='pathline'>
                                <PathLine 
                                    points={this.state.path}
                                    stroke="deepskyblue"
                                    stroke-opacity="50%"
                                    strokeWidth="3"
                                    fill="none"
                                    r={10}
                                    />
                            </svg>
                            :<h/>}

                        {this.state.pathplan && this.state.pathplan.length > 0 ?
                            <div class="planned_pathline">
                                <ScatterChart width={615} height={382}>
                                    <XAxis axisLine={false} type="number" dataKey="x" tick={false} stroke="red" domain={[0, 547.29]} />
                                    <YAxis axisLine={false} type="number" dataKey="y" tick={false} stroke="red" domain={[0, 342.32]}/>
                                    <Scatter data={this.state.pathplan} fill="white" isAnimationActive={false}/>
                                </ScatterChart>
                            </div>
                        :<h/>}

                        {/* Alien */}
                                
                        <ul class = "alien_map">
                            {this.state.Aliens && this.state.Aliens.length > 0 ?
                                this.state.Aliens.map(item => (
                                    <li key={item.id}> 
                                        {/* {item.x}, {item.y}, {item.c}  */}
                                        
                                        {item.e == -1 &&
                                        <img class= "alien" style={{
                                            marginLeft: item.x/5.847,
                                            marginTop: this.state.startCorner==0 ? item.y/5.842 : -342.32+item.y/5.842  // negative sign for y of alien is set here (different from rover - for convenience)
                                        }}
                                                src={require('../assets/imgs/' + item.c + 'error.png')}>
                                        </img>}

                                        {item.e == 1 &&
                                        <img class= "alien" style={{
                                            marginLeft:item.x/5.847,
                                            marginTop:this.state.startCorner==0 ? item.y/5.842 : -342.32+item.y/5.842 // negative sign for y of alien is set here (different from rover - for convenience)
                                        }}
                                            src={require('../assets/imgs/' + item.c + 'iball.png')}>
                                        </img>}

                                        {item.e >= 2 &&
                                        <img class= "alien" style={{
                                            marginLeft:item.x/5.847,
                                            marginTop:this.state.startCorner==0 ? item.y/5.842 : -342.32+item.y/5.842 // negative sign for y of alien is set here (different from rover - for convenience)
                                        }}
                                            src={require('../assets/imgs/' + item.c + 'ball.png')}>
                                        </img>}
                                    </li> ))
                                : <h/>}
                        </ul>

                        {/* Tower */}
                        <ul class = "towermap">
                            {this.state.tower && this.state.tower.length > 0 ?
                                this.state.tower.map(item => (
                                    <li key={item.id}> 
                                    {item.e == 1 &&
                                        <img class='tower' style={{
                                            marginLeft: item.x/5.847,
                                            marginTop: this.state.startCorner == 0 ? item.y/5.842 : -342.32 + item.y/5.842,
                                            width: 10+item.w/10 }}
                                            src={require('../assets/imgs/itower.png')}>
                                        </img>}
                                    {item.e >= 2 && 
                                        <img class='tower' style={{
                                            marginLeft: item.x/5.847,
                                            marginTop: this.state.startCorner == 0 ? item.y/5.842 : -342.32 + item.y/5.842,
                                            width: 10+item.w/10 }}
                                            
                                            src={require('../assets/imgs/tower.png')}>
                                        </img>}
                                    </li> ))
                            : <h/>}
                        </ul>
                        <img class="map" src={require('../assets/imgs/marsmapgrid.png')}></img>

                    </div>
                    <div class='sectionright'>
                        <span class = 'batterytitle'> Battery </span>
                    
                        <Row gutter={1}>
                            <span class = 'battery'>
                                <Battery size={60} percent={this.state.battery} color={'rgb(0,102,0)'} type='nogrid'/>
                            </span>
                        </Row>
                        
                        <Row>
                            <h2 class = 'battery_num'> <b> {this.state.battery}% </b> </h2>    
                        </Row>

                        <div class="rectangle">
                        
                            <div class="status_section">
                                <span class = 'status_navigation'> Status </span>
                                {this.state.status == 0 ? 
                                    <h2 class='status_info'> <b> Disconnected </b> </h2> :
                                    <h2 class='status_info'> <b> Connected </b> </h2>
                                }
                            </div>

                            <div class="tower_section">
                                <span class = 'tower'> Tower </span>
                                {this.state.tower && this.state.tower.length > 0 ?
                                    this.state.tower.map(item => (
                                        <li key = {item.id} class="nav_alien_info">
                                            <span class='tower_info'> <b> ({item.x.toFixed(2)} , &nbsp;
                                                                    {this.state.startCorner == 0 && -item.y.toFixed(2)}
                                                                    {this.state.startCorner == 1 && item.y.toFixed(2)} 
                                                                    )</b> </span>
                                        </li>))
                                :<h/>}
                            </div>
                            <br/> 
                            <br/> 
                            <br/> 
                            <br/> 
                            <span class = 'nav_alien_title'> Aliens </span>
                            <ul class="nav_alien_details">
                                {this.state.Aliens && this.state.Aliens.length > 0 ?
                                    this.state.Aliens.map(item => (
                                        <li key={item.id} class="nav_alien_info"> 
                                            {/* {item.x}, {item.y}, {item.c}  */}
                                            {/* <img class= "alien" style={{
                                                marginLeft:item.x,
                                                marginTop:-item.y // negative sign for y of alien is set here (different from rover - for convenience)
                                            }}
                                                src={require('../assets/imgs/' + item.c + 'ball.png')}>
                                            </img> */}
                                            Alien {item.id}: ( {item.x} , &nbsp;
                                                {this.state.startCorner == 0 && -item.y}
                                                {this.state.startCorner == 1 && item.y}
                                            )                                              
                                            {item.c == 'g' && <span> Darkgreen </span>}
                                            {item.c == 'c' && <span> Cyan </span>}
                                            {item.c == 'b' && <span> Blue </span>}
                                            {item.c == 'p' && <span> Pink </span>}
                                            {item.c == 'r' && <span> Red </span>}
                                            {item.c == 'y' && <span> Yellow </span>}
                                        </li> ))
                                :<h/>}
                            </ul>
                        </div>
                    </div>
                </div>
            </div>
            </div>
        );
    }
}

export default Control;
