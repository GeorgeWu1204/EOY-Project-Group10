import React, { Component } from 'react';
import './Navigation.css';
import Top from './top'
import { Row, Col, Switch, Input, Button, InputNumber } from 'antd';
import { Player } from 'video-react';
import {Battery} from 'react-little-icon'
import background from "../assets/imgs/background.jpg";
import {PathLine} from 'react-svg-pathline';
import PixelGrid from "react-pixel-grid";

import {
  XAxis,
  YAxis,
  ScatterChart,
  Scatter
} from "recharts";

const r = "#f00";
const g = "#0f0";
const b = "#00f";
const x = "#000";
const w = "#1110";


// for rover coordinate, input is x+,y+: y coordinate is converted to negative when stored in the state list
// for alien coordinate, input is x+,y+: y coordinate is stored as positive in state list dictionary, and then converted to negative when html render
// for path coordinate, inpu is x+,y+: y coordinate is converted to (342.32-y) when stored into the state list
var reqProcessID;
var statusProcessID;

class Navigation extends Component {
    constructor(props) {
        super(props)
        this.state = {
            // Aliens: [{id:1,x:0,y:0,c:'b',e:1}, {id:2,x:547.29* 5.847,y:-342.32 * 5.842,c:'b',e:1}], //{id:1,x:0,y:0,c:'b',e:1}, {id:2,x:547.29* 5.847,y:-342.32 * 5.842,c:'b',e:1}, {id:2,x:-40* 5.847,y:232 * 5.842,c:'b',e:1}
            Aliens:[],
            left:'0px',
            top:'0px',
            angle:0,
            // tower:[ {id: 1, x:608 * 5.847, y:0 * 5.842,e:2}, {id: 1, x:400 * 5.847, y:0 * 5.842,e:2}], // {id: 1, x:608 * 5.847, y:0 * 5.842,e:2}
            tower: [], //{id: 1, x:400 * 5.847, y:0 * 5.842, w:10,e:2}
            xDestCoordinate:'',
            yDestCoordinate:'',
            submitedXDestCoordinate:'',
            submitedYDestCoordinate:'',
            destBallColor:'',
            submitedDestBallColor:'',
            radar: [],   //{id:1,x:0*5.847,y:0*5.842,i:0.5},{id:2,x:500*5.847,y:-200*5.842,i:0.45},[{id:1,x:45,y:-750,i:1},{id:2,x:0,y:-150,i:2}]
            //radar:[],
            battery:'',
            path:[{'x':0,'y':342.32}],
            pathplan:[{'x':0,'y':0}], // {'x':547.29,'y':342.32}
            status:0,
            delay:0,
            startCorner:0
        }
        this.getCoordinate = this.getCoordinate.bind(this);
        this.getStatus = this.getStatus.bind(this);
    }

    //////////////////////////////////////////////////CONNECTION STATUS//////////////////////////////////////////////
    getStatus (){
        console.log("getstatus");
        fetch(window.ip+"Status")
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

    //////////////////////////////////////////////////AFTER START//////////////////////////////////////////////
    getCoordinate() {
        console.log("fetching coord");
        if (this.state.startCorner == 0){
            fetch(window.ip + "Navigation")
                .then(res => res.json())
                // negative sign for y of rover is set right here   &    path is converted to 342.32-y set here
                .then(res => this.setState({ status: res.status, battery: res.battery, tower: res.Tower, left:(res.xCoord/5.847)+'px', top:(-res.yCoord/5.842)+'px', angle:-res.angle+90, path:this.state.path.concat({'x':res.xCoord/5.847,'y':342.32-(res.yCoord/5.842)}),  pathplan:this.state.pathplan.concat({'x':res.xCoordPlan,'y':res.yCoordPlan}),Aliens:res.Aliens}))      
                .then(console.log(this.state.tower))
        }
        
        else if (this.state.startCorner == 1){
            fetch(window.ip+"Navigation")
                .then(res => res.json())
                // negative sign for y of rover is set right here   &    path is converted to 342.32-y set here
                .then(res => this.setState({ status: res.status, battery: res.battery, tower: res.Tower, left:(res.xCoord/5.847)+'px', top:(-res.yCoord/5.842-342.32)+'px', angle:-res.angle+90, path:this.state.path.concat({'x':res.xCoord/5.847,'y':-(res.yCoord/5.842)}), pathplan:this.state.pathplan.concat({'x':res.xCoordPlan,'y':342.32-res.yCoordPlan}),Aliens:res.Aliens}))
            }
    }
    refreshRoverCoord () {
        reqProcessID = setInterval(this.getCoordinate, 150);
    }
    endRefreshRoverCoord () {
        window.clearInterval(reqProcessID);
    }

    //////////////////////////////////////////////////SET START//////////////////////////////////////////////
    submitDestCoord(xDestCoord, yDestCoord) {
        this.endRefreshConnectStatus();
        this.setState({submitedXDestCoordinate:xDestCoord, submitedYDestCoordinate:yDestCoord, path:[], pathplan:[]});
        fetch(window.ip+"StartNavigation/Dest", {
            method: 'POST',
            body: JSON.stringify({
                xDest: xDestCoord,
                yDest: yDestCoord
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

    submitDestBallColor(color) {
        this.endRefreshConnectStatus();
        this.setState({submitedDestBallColor:color, path:[], pathplan:[]});
        fetch(window.ip+"StartNavigation/Ball", { 
            method: 'POST',
            body: JSON.stringify({
                ballColor: color,
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

    selectCorner(checked){
        if (checked) {
            // start from top
            this.setState({startCorner:1, left:'0px', top:'-342.32px', pathplan:[{'x': 0, 'y':342.32}]}) 
            window.startCorner = 1;
        }
        else{
            // start from bottom
            this.setState({startCorner:0, left:'0px', top:'0px', pathplan:[{'x': 0, 'y':0}]})
            window.startCorner = 0;
        }
    }

    startNavigation(checked) {
        if (checked){
            this.endRefreshConnectStatus();
            if (this.state.startCorner == 0) {
                this.setState({left:'0px',top:'0px',path:[{'x':0,'y':342.32}],pathplan:[{'x': 0, 'y':0}], Aliens:[], tower:[]});
            }
            else if (this.state.startCorner == 1) {
                // CHECK!!! left and top px is probabily wrong
                this.setState({left:'0px',top:'-342.32px',path:[{'x':0,'y':0}],pathplan:[{'x': 0, 'y':342.32}], Aliens:[], tower:[]});
            }
            fetch(window.ip + "StartNavigation", {
                method: 'POST',
                body: JSON.stringify({
                    start: '!start$',
                    corner: this.state.startCorner,
                    
                }),
                headers: {
                    'Content-type': 'application/json; charset=UTF-8' 
                }
            })

            this.refreshRoverCoord();
        }
        else {
            fetch(window.ip + "StopExploration", {
                method: 'POST',
                body: JSON.stringify({
                    end: '!stopexp$', 
                }),
                headers: {
                    'Content-type': 'application/json; charset=UTF-8' 
                }
            })
        }
    }
    endOfNavigation(){
        this.endRefreshRoverCoord();
        fetch(window.ip + "EndNavigation", {
            method: 'POST',
            body: JSON.stringify({
                end: '!end$', 
            }),
            headers: {
                'Content-type': 'application/json; charset=UTF-8' 
            }
        })
        window.xStartCoord = this.state.pathplan[this.state.pathplan.length - 1].x
        window.yStartCoord = this.state.pathplan[this.state.pathplan.length - 1].y
        window.alien = this.state.Aliens
        window.tower = this.state.tower
        console.log(window.xStartCoord)
        this.refreshConnectStatus();
    }
    render() {
        return (
            <div class='bg' style={{ backgroundImage: `url(${background})`  }} >
                <div>
                    <Top e='1' />
                        <div class='section' >
                            <div class='sectionleft_nav'>

                                <span class='heading'>
                                    <b>Navigation</b>
                                </span>
                                
                                <span class='subheading'>
                                    Map Selection
                                </span>

                                <span><b>
                                    bottom <Switch onChange={(checked) => this.selectCorner(checked)}/> top
                                </b></span>

                                <span class='subheading'>
                                    Rover Explore
                                </span>
                                <span><b>
                                    off <Switch onChange={(checked) => this.startNavigation(checked)}/> on
                                </b></span>
                                {/* <br/> */}

                                <span class='subheading'>
                                    Reach Coordinate
                                </span>

                                <Row gutter={16}>
                                    <Col span={12}>
                                        <Input 
                                            onChange={e => this.setState({ xDestCoordinate: e.target.value })}
                                            placeholder="Coord X" />
                                    </Col>
                                    <Col span={12}>
                                        <Input
                                            onChange={e => this.setState({ yDestCoordinate: e.target.value })}
                                            placeholder="Coord Y" />
                                    </Col>
                                </Row>
                                <Button type="primary" onClick={() => this.submitDestCoord(this.state.xDestCoordinate,this.state.yDestCoordinate)}>SUBMIT</Button>
                                
                                {this.state.submitedXDestCoordinate != '' &&
                                    <span class = 'submitedinfo'> Reaching Coordinate: ({this.state.submitedXDestCoordinate} , {this.state.submitedYDestCoordinate})</span>
                                }
                                
                                
                                <span class='subheading'>
                                    Reach Ball </span>
                                <Row gutter={16}>
                                    <Col span={12}>
                                        <Input 
                                            onChange={e => this.setState({ destBallColor: e.target.value })}
                                            placeholder="Ball Color" />
                                    </Col>
                                    <Col span={12}>
                                        <Button type="primary" onClick={() => this.submitDestBallColor(this.state.destBallColor)}>SUBMIT</Button>
                                    </Col> 
                                </Row>  

                                <span class='subheading'>
                                    End Navigation </span>
                                <Row gutter={16}>
                                    <Col span={12} offset={6}>
                                        <Button type="danger" onClick={() => this.endOfNavigation()}> END </Button>
                                    </Col> 
                                </Row>    
                                {this.state.submitedDestBallColor == 'c' && <span class = 'submitedinfo'> Reaching cyan ball </span>}
                                {this.state.submitedDestBallColor == 'b' && <span class = 'submitedinfo'> Reaching blue ball </span>}
                                {this.state.submitedDestBallColor == 'p' && <span class = 'submitedinfo'> Reaching pink ball </span>}
                                {this.state.submitedDestBallColor == 'r' && <span class = 'submitedinfo'> Reaching red ball </span>}
                                {this.state.submitedDestBallColor == 'y' && <span class = 'submitedinfo'> Reaching yellow ball </span>}
                                {this.state.submitedDestBallColor == 'g' && <span class = 'submitedinfo'> Reaching green ball </span>}  
                            </div>

                            <div class='sectioncenter'>
                                <img class='rover' style={{
                                    marginLeft:this.state.left,
                                    marginTop:this.state.top,
                                    transform: `rotate(${this.state.angle}deg)`}}

                                    src={require('../assets/imgs/whiterobot.png')}>
                                    
                                </img>

                                {(this.state.path && (this.state.path.length > 0)) ?
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

                                {(this.state.pathplan && (this.state.pathplan.length > 0)) ?
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
                                    {(this.state.Aliens && (this.state.Aliens.length > 0)) ?
                                        
                                        this.state.Aliens.map(item => (
                                            <li key={item.id}> 
                                                {/* {item.x}, {item.y}, {item.c}  */}
                                                
                                                {(item.e < 0 || item.e == 0) &&
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
                                    {(this.state.tower && this.state.tower.length > 0) ?
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

                                {/*Destination*/}
                                <div class = "towermap">
                                    {this.state.submitedXDestCoordinate != ''  &&
                                            <img class='tower' style={{
                                                marginLeft: parseInt(this.state.submitedXDestCoordinate)*34.2,
                                                marginTop: this.state.startCorner == 0 ? -parseInt(this.state.submitedYDestCoordinate)*34.23 : -342.32 + parseInt(this.state.submitedYDestCoordinate)*34.23
                                            }}
                                                src={require('../assets/imgs/flag.png')}>
                                            </img>
                                    }
                                </div>

                                
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
                                                    <span class='tower_info'> <b> {item.id}: ({item.x.toFixed(2)} , &nbsp;
                                                                            {this.state.startCorner == 0 && -item.y.toFixed(2)}
                                                                            {this.state.startCorner == 1 && item.y.toFixed(2)} 
                                                                            ) {(item.w/10).toFixed(2)} cm</b> </span>
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
                                                    {item.id}: ({item.x} , &nbsp;
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
export default Navigation;
