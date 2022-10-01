import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';
// import registerServiceWorker from './registerServiceWorker';
// import List from './list'
// import Batterys from './components/Battery'
import Control from './components/Control'
import Navigation from './components/Navigation'
import History from './components/History'
import Radar from './components/Radar'

import { Router, Route, hashHistory } from 'react-router';

ReactDOM.render((
<React.StrictMode>
    <Router history={hashHistory}>
        <Route path='/' component={App}></Route>
        <Route path='/Control' component={Control}></Route>
        <Route path='/Navigation' component={Navigation}></Route>
        <Route path='/Radar' component={Radar}></Route>
        <Route path='/History' component={History}></Route>

    </Router>
</React.StrictMode>
), document.getElementById('root1'));
// registerServiceWorker();
