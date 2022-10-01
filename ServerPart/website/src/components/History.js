import React, { Component } from 'react';
import './History.css';
import './Navigation.css';
import Top from './top';
import {Input} from 'antd';
import background from "../assets/imgs/background.jpg";
import {PathLine} from 'react-svg-pathline';


const { TextArea } = Input;

// let processID = setInterval("presentBatteryData()", 500);

class History extends Component {
    constructor(props){
        super(props)
        this.state={
            Index:[], //[{id:1,time:'2022-06-02'},{id:2,time:'2022-06-03'},{id:3,time:'2022-06-04'},{id:4,time:'2022-06-04'}],
            Path:[],
            Pathplan: "",
            Aliens:[], //[{id:1,Index:1,x:45,y:56,c:'b'},{id:2,Index:2, x:0,y:50,c:'g'}]
            Tower:[], // {id:1,Index:1,x:608*5.847,y:342.32*5,w:15,e:2}
            Radar: [],
            Number: 0,
            Histindex:0,
            Starttime:'',
            Endtime:'',
            Corner:0,
        }
        this.reqHistory = this.reqHistory.bind(this);
    }

    convertString(pathList){
        let pathString = "";
        for (let index = 0; index < pathList.length; index++) {
            const element = pathList[index];
            pathString += (" "+element['x']+","+element['y']);
        }
        return pathString;
    }
    reqHistory(){
        // fetch(window.ip+"History/List", { 
        //     method: 'POST',
        //     body: JSON.stringify({
        //         history: 'request',
        //     }),
        //     headers: {
        //         'Content-type': 'application/json; charset=UTF-8' 
	    //     }
        // })
        // .then(async res=>res.json())
        // .then(res => this.setState({Index:res.Index}))

        fetch(window.ip + "History")
        .then(res => res.json())
        // negative sign for y of rover is set right here   &   path is converted to 342.32-y set here
        .then(res => this.setState({Index:res.Index}))
        // console.log(this.state.Index);
    }
    async reqAlien(id){
        return fetch (window.ip + "History", {
            method: 'POST',
            body: JSON.stringify({
                Index: id, 
            }),
            headers: {
                'Content-type': 'application/json; charset=UTF-8' 
            }})
        .then(res=>res.json())
        .then(res=>this.setState({Number:res.Parts, Starttime:res.start,Endtime:res.end, Aliens:res.Aliens, Tower: res.Tower, Radar: res.Radar, Corner:res.Corner}));
    }
    async reqPath(Collected,id){
        return fetch (window.ip + "History/Path", {
            method: 'POST',
            body: JSON.stringify({
                Index: id, 
                Part: Collected
            }),
            headers: {
                'Content-type': 'application/json; charset=UTF-8' 
            }})
        .then(res=>res.json())
        .then(res=>this.setState({Path:this.state.Path.concat(res.Pathreal), Pathplan:this.state.Pathplan + this.convertString(res.Pathplanned)}))
        .then(console.log(this.state.Pathplan))
       
    }
    
    async reqPathAlien(id){
        this.setState({Number:0,Path:[],Pathplan:"",Aliens:[], Tower:[], Radar:[],Histindex:id, Corner:-1});
        console.log("heherere");
        await this.reqAlien(id); 
        console.log("state number:");
        console.log(this.state.Number);
        console.log("end");
        var Collected = 0;
        while(Collected < this.state.Number){
            await this.reqPath(Collected,id);
            Collected += 1;
            console.log(Collected);
        }
    }
    // componentDidMount() {
    //     this.reqHistory();
    //     console.log("Request for history data");
    // }
    // componentWillUnmount(){
    //     console.log("Unmounted");
    // }
    
    
    render() {
        return (
            <div class='bg' style={{ backgroundImage: `url(${background})` }} >
                <div>
                    <Top e='4' />
                    <div class='section' >
                        <div class='sectionleft'>
                            {/* <div class='histtitle'>
                                <h1><b> History </b></h1>
                            </div> */}
                            <button class='gethist' onClick={()=>this.reqHistory()}>
                                <b>Get History</b>
                            </button>

                            
                            <ul class = "histbuttons">
                                {(this.state.Index && (this.state.Index.length > 0)) ?
                                    this.state.Index.map(item => (

                                        <li key={item.id} > 
                                        
                                            <button class={item.id==this.state.Histindex?'histactive':'histbutton'} onClick={()=>this.reqPathAlien(item.id)}>
                                                Navigation {item.id}: {item.time}
                                            </button>
                        
                                        </li>))
                                        
                                    : <h/> }
                            
                            </ul>
                            
                        </div>

                        <div class='sectioncenter'>

                            {(this.state.Path && (this.state.Path.length != 0)) ? 
                                <svg class='pathline'>
                                    <PathLine 
                                        points={this.state.Path}
                                        stroke="deepskyblue"
                                        strokeWidth="3"
                                        fill="none"
                                        r={10}
                                        />
                                </svg>
                                : <h/>}

                            {(this.state.Pathplan && (this.state.Pathplan != "")) ?
                                <svg class='hist_planned_pathline'>
                                        <polyline
                                            points={this.state.Pathplan}
                                            //stroke-linejoin = 'miter'
                                            stroke-dasharray = "5,5"
                                            stroke-opacity="60%"
                                            stroke = "lawngreen"
                                            stroke-width="4"
                                            fill="none"
                                            r={10}
                                            />
                                </svg>
                                : <h/>}

                            {/* Alien */}
                            <ul class = "alien_map">
                                {(this.state.Aliens && (this.state.Aliens.length > 0)) ?
                                    this.state.Aliens.map(item => (
                                        <li key={item.Index}> 
                                            {item.e == 1 &&
                                            <img class= "alien" style={{
                                                marginLeft:item.x/5.847,
                                                marginTop:this.state.Corner==0 ? item.y/5.842 : -342.32+item.y/5.842 // negative sign for y of alien is set here (different from rover - for convenience)
                                            }}
                                                src={require('../assets/imgs/' + item.c + 'iball.png')}>
                                            </img>}
                                            {item.e == -1 &&
                                            <img class= "alien" style={{
                                                marginLeft:item.x/5.847,
                                                marginTop:this.state.Corner==0 ? item.y/5.842 : -342.32+item.y/5.842 // negative sign for y of alien is set here (different from rover - for convenience)
                                            }}
                                                src={require('../assets/imgs/' + item.c + 'error.png')}>
                                            </img>}
                                            {item.e >= 2 &&
                                            <img class= "alien" style={{
                                                marginLeft:item.x/5.847,
                                                marginTop:this.state.Corner==0 ? item.y/5.842 : -342.32+item.y/5.842 // negative sign for y of alien is set here (different from rover - for convenience)
                                            }}
                                                src={require('../assets/imgs/' + item.c + 'ball.png')}>
                                            </img>}
                                            
                                        </li> ))
                                    : <h/>}
                            </ul>

                            {/* Tower */}
                            <ul class = "towermap">
                                {(this.state.Tower.length && (this.state.Tower.length > 0)) ?
                                    this.state.Tower.map(item => (
                                        <li key={item.id}> 
                                        {item.e == 1 &&
                                            <img class='tower' style={{
                                                marginLeft: item.x/5.847,
                                                marginTop: this.state.Corner == 0 ? item.y/5.842 : -342.32+item.y/5.842,
                                                width: 10+item.w/10 }}
                                                src={require('../assets/imgs/itower.png')}>
                                            </img>}
                                        {item.e >= 2 && 
                                            <img class='tower' style={{
                                                marginLeft: item.x/5.847,
                                                marginTop: this.state.Corner == 0 ? item.y/5.842 : -342.32+item.y/5.842,
                                                width: 10+item.w/10 }}
                                                src={require('../assets/imgs/tower.png')}>
                                            </img>}
                                        </li> ))
                                : <h/>}
                            </ul>
                            <img  class="map" src={require('../assets/imgs/marsmapgrid.png')}></img>
                        </div>
                        
                        <div class='sectionright'>
                            {/* <div class='alientitle'>
                                <h1><b> Aliens </b></h1>
                            </div> */}
                            
                            <ul class="alien_details">
                            <h1><b> Aliens </b></h1>
                                {(this.state.Aliens && (this.state.Aliens.length > 0)) ?
                                    this.state.Aliens.map(item => (
                                        <li key={item.Index} class="alien_info"> 
                                            Alien {item.Index}: ( {item.x} , &nbsp;
                                                    {this.state.Corner == 0 && -item.y}
                                                    {this.state.Corner == 1 && item.y}
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
                            
                            <ul class='detailed_tower'>
                                <h1><b> Towers </b></h1>
                                    {(this.state.Tower && (this.state.Tower.length > 0)) ? 
                                        this.state.Tower.map(item => (
                                            <li key={item.Index} class="alien_info">
                                                ({item.x.toFixed(2)} , &nbsp;
                                                {this.state.Corner == 0 && -item.y.toFixed(2)}
                                                {this.state.Corner == 1 && item.y.toFixed(2)}) &nbsp;
                                                {item.w}cm
            
                                            </li> ))
                                    :<h/>
                                    }
                            </ul>

                            <div class='detailed_time'>
                                <h1><b> Time </b></h1>
                                    <p>
                                        Start: {this.state.Starttime}
                                        <br/>
                                        End: {this.state.Endtime}
                                    </p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        );
    }
}

export default History;
