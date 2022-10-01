import React, { Component } from 'react';
import './App.css';
import Top from './components/top'
import backgroundfront from "./assets/imgs/frontpage.png";

window.ip = "http://localhost:9000/"
window.xStartCoord = 0
window.yStartCoord = 0
window.startCorner = 0
window.alien = []
window.tower = []

class App extends Component {
    constructor(props){
        super(props)
        this.state={
        }
    }
    
    connectTCP(){
        fetch(window.ip)
    }
    componentWillMount() {
        this.connectTCP();
        console.log("Connected to webserver")
    }
  
    render() {
            return (
                <div class='bg' style={{ backgroundImage: `url(${backgroundfront})`  }} >
                    <div className="App">
                        <Top e='0' />
                    </div>
                </div>
            );
        }
    }

export default App;


