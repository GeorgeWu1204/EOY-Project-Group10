import React, { Component } from 'react';

class ListAdd extends Component {
    constructor(props){
        super(props)
        this.state={
            
        }
    }
    add(){
        if(this.refs.txt.value===''){
         
        }else{
            let obj={}
            obj.id=this.props.list[this.props.list.length-1].id+1
            obj.item=this.refs.txt.value.trim()
            obj.check=false
            this.props.list.push(obj)
            this.props.change(this.props.list)
            this.refs.txt.value=''
        }
        
    }
    componentDidMount(){
        const that=this
        this.refs.txt.onkeydown=function(ev){
            if(ev.keyCode===13){
                that.add()
            }
        }
    }
    


    render() {

        return (
            <div className="add-box">
                <input type="text" className='add-txt'ref='txt' placeholder='请输入内容，可敲击enter键完成输入'/>
                <div className='add-btn' onClick={this.add.bind(this)}>添加</div>
            </div>
        );
    }
}

export default ListAdd;
