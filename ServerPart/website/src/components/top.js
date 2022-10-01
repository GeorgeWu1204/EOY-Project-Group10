import React, { Component } from 'react';
import './top.module.css';
import {Link} from 'react-router'
import {Battery} from 'react-little-icon'
import {  Row, InputNumber  } from 'antd';
class Top extends Component {
    constructor(props){
        console.log(111)
        console.log(props)
        super(props)
        this.state={
            menudata:[
                {name:'Home',path:'/',icon:'iconfont icon-home'},
                {name:'Navigation',path:'/Navigation',icon:'iconfont icon-location'},
                {name:'Control',path:'/Control',icon:'iconfont icon-control'},
                {name:'Radar',path:'/Radar',icon:'iconfont icon-location'},
                {name:'History',path:'/History',icon:'iconfont icon-history'},
            ],
            e:props.e,
            dl:80
        }
    }
    chs(e){
        this.setState({
            dl:e
        })
    }
    // btnClick(val,e){
    //     this.setState({
    //         e
    //     })
    //     this.props.router.push(val.path)
    // }
    render() {
        

        return (
            <div class='tops'>
                <div class='left'>
                    <div class='menus'>
                      {
                    this.state.menudata.map((item, index) => {
                        return <div 
                        class={['list',index==this.state.e?'active':null].join(' ')}
                        key={index}>
                            <Link to={item.path}>
                                <span class={item.icon}>  {item.name}</span>
                            </Link></div>
                    })
                }
                    </div>
                </div>
            </div>
        );
    }
}

export default Top;
