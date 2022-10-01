import React, { Component } from 'react';
import './Radar.css';
import Top from './top'
import { Row, Col, Switch, Input, Button, InputNumber } from 'antd';
import { Player } from 'video-react';
import {Battery} from 'react-little-icon'
import background from "../assets/imgs/background.jpg";
import {PathLine} from 'react-svg-pathline';
import PixelGrid from "react-pixel-grid";

var reqProcessID;
var statusProcessID;

class Radar extends Component {
    constructor(props) {
        super(props)
        this.state = {
            top:'0px',
            left:'0px', //'950px'
            angle:0,
            status:0,
            path:[{'x':0, 'y':95}],
            // path:[{'x':0,'y':95},{'x':950,'y':95-50}],
            // radar:[{'id':0, 'x':0,'y':0/0.95,'i':1}, {'id':1, 'x':20,'y':0/0.95,'i':1}, {'id':2,'x':40,'y':0/0.95,'i':2}, {'id':3,'x':60,'y':0/0.95,'i':2}, {'id':4,'x':80,'y':0/0.95,'i':2},{'id':4,'x':100,'y':0/0.95,'i':3}],
            radar:[]
        }
        this.getCoordinate = this.getCoordinate.bind(this);
        this.getStatus = this.getStatus.bind(this);
    }

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

    endRefreshRoverCoord () {
        window.clearInterval(reqProcessID);
    }

    componentDidMount() {
        this.refreshConnectStatus();
    }
    
    componentWillUnmount(){
        this.endRefreshConnectStatus();
        console.log("unmounted status"); 
    }

    getCoordinate() {
        console.log("fetching coord");
    
        fetch(window.ip + "Navigation")
            .then(res => res.json())
            // negative sign for y of rover is set right here   &   path is converted to 342.32-y set here
            .then(res => this.setState({ radar: res.Radar, status: res.status,  left:(res.xCoord*0.95)+'px', top:(-res.yCoord*0.95)+'px', angle:-res.angle+90, path:this.state.path.concat({'x':res.xCoord*0.95,'y':95-res.yCoord*0.95})}))      
    }

    refreshRoverCoord () {
        reqProcessID = setInterval(this.getCoordinate, 150);
    }
    endRefreshRoverCoord () {
        window.clearInterval(reqProcessID);
    }

    startRadar(checked) {
        if (checked){
            this.endRefreshConnectStatus();

            this.setState({left:'0px',top:'0px',path:[{'x':0,'y':95}]});
            
            fetch(window.ip + "Radar/Start", {
                method: 'POST',
                body: JSON.stringify({
                    start: '!startradar$',
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
            this.refreshRoverCoord();
        }
        else {
            this.endRefreshRoverCoord();
            fetch(window.ip + "Radar/End", {
                method: 'POST',
                body: JSON.stringify({
                    end: '!endradar$', 
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

    render() {
        return (
            <div class='bg' style={{ backgroundImage: `url(${background})`  }} >
                <div>
                    <Top e='3' />
                        <div class='section' >
                            
                            <div class = "sectionbutton"><span><b>
                                off <Switch onChange={(checked) => this.startRadar(checked)}/> on
                            </b> </span></div>

                            <div class="radar_status_section">
                                        <span class = 'radar_status_navigation'> Status </span>
                                        {this.state.status == 0 ? 
                                            <h2 class='radar_status_info'> <b> Disconnected </b> </h2> :
                                            <h2 class='radar_status_info'> <b> Connected </b> </h2>
                                        }
                            </div>
                        
                            <div class = "sectiontrack">
                                <img class='roverradar' style={{
                                    marginLeft:this.state.left,
                                    marginTop:this.state.top,
                                    transform: `rotate(${this.state.angle}deg)`}}

                                    src={require('../assets/imgs/whiterobot.png')}>
                                    
                                </img>

                                {(this.state.path && (this.state.path.length > 0)) ?
                                    <svg class='radarpath'>
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

                                <ul class="radar_map">
                                    {this.state.radar.length > 0 ?
                                        
                                        this.state.radar.map(item => (
                                            <li key={item.id}>   
                                                {item.i == 1 &&
                                                    <div class="circle circle-yellow"  style={{
                                                        // width: `${1/item.i * 50}px`,
                                                        // height: `${1/item.i * 50}px`,
                                                        marginLeft: item.x*0.95,
                                                        marginTop: -item.y*0.95}}>
                                                    </div>}

                                                {item.i == 2 &&
                                                    <div class="circle circle-orange" style={{
                                                        // width: `${1/item.i * 30}px`,
                                                        // height: `${1/item.i * 30}px`,
                                                        marginLeft: item.x*0.95,
                                                        marginTop: -item.y*0.95}}>      
                                                    </div>}

                                                {item.i == 3 &&
                                                    <div class="circle circle-red" style={{
                                                        // width: `${1/item.i * 10}px`,
                                                        // height: `${1/item.i * 10}px`,
                                                        marginLeft: item.x*0.95,
                                                        marginTop: -item.y*0.95}}>
                                                    </div>}
                                            </li> ))
                                    : <h/>}
                                </ul>
                                <img class="track" src={require('../assets/imgs/radartrack.png')}></img>
                            </div>
                        </div>
                </div>
            </div>
        );
    }
}
export default Radar;