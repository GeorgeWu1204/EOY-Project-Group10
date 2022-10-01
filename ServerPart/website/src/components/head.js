import React, { Component } from 'react';

class Head extends Component {
    constructor(props){
        super(props)
        this.state={
            data:props.data
        }
    }
    add(){
        let num=this.props.data
        num++
        //console.log(num)
        this.props.change(num)
    }
    componentWillMount(){
      
    }
    componentDidMount(){
        
    }
    componentWillReceiveProps(nextProps) {
       
        this.setState({
            data:nextProps.data
        })
    }
    shouldComponentUpdate() {
     
        return true;        // 记得要返回true
    }
    componentWillUpdate(){
       
    }
    componentDidUpdate(){
      
    }
    componentWillUnmount() {
       
    }

    render() {
        

        return (
            <div>
                {this.state.data}

                <button onClick={this.add.bind(this)}>+1</button>
            </div>
        );
    }
}

export default Head;
