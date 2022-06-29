import socket
from threading import Thread
from _thread import *
# import json
import simplejson as json
import re
import Database.AlienTable as AlienDatabase
import Database.TimeTable as TimeDatabase
import Database.PositionTable as PositionDatabase
import Database.TowerTable as TowerDatabase
# import Database.RadarTable as RadarDatabase
from datetime import datetime
from decimal import Decimal
import select
import asyncio
import websockets
import functools
import math



#-----------------------------------------------FUNCTIONS------------------------------------------------------#
async def check_connection(websocket, connection_status, lastActiveTime):
    # check connection when nothing is received from client in the past 5 seconds
    if (datetime.now() - lastActiveTime).total_seconds() > 5: 
        print("timeout le, trying to check if client is alive")
        try:
            # await websocket.send("omg")
            pong_waiter = await websocket.ping()
            await asyncio.wait_for(pong_waiter, timeout=4.0)
        except (asyncio.exceptions.TimeoutError, websockets.exceptions.ConnectionClosedError) as e:
            connection_status = 0
            print("In except")
        else:
            lastActiveTime = datetime.now()

    return connection_status, lastActiveTime

async def receive_from_esp(websocket, connection_status, lastActiveTime):
    cmsg = ""
    try:
        cmsg = await asyncio.wait_for(websocket.recv(), timeout=1.0)
        
    except (ValueError, asyncio.TimeoutError, websockets.ConnectionClosedOK, websockets.ConnectionClosedError):
        pass

    else:
        print("received from esp:", cmsg)
        lastActiveTime = datetime.now()
    
    return cmsg, connection_status, lastActiveTime

async def send_to_esp(websocket, message, connection_status):
    try:
        await websocket.send(message.encode())
        print("to esp:", message)
    except (websockets.ConnectionClosedOK, websockets.ConnectionClosedError):
        connection_status = 0
    return connection_status

def get_path_part(path, part_size):
    path_parts = []
    total_full_parts_num = len(path) // part_size
    for i in range(total_full_parts_num):
        path_parts.append(path[i*part_size : (i+1)*part_size])

    path_parts.append(path[ total_full_parts_num * part_size :])
    return path_parts

def alien_out_of_range_correction(XCoordinate, YCoordinate, corner):
#     corner 0:
# 	    X: -116.94 ~ (3555 - 177.5*2 + 116.94)=3316.94 
# 	    Y: -105.16 ~ (2337 - 168.5*2 + 105.16)=2105.16 
#     corner 1:
# 	    X: same
#       Y: 105.16 ~ - (2337 - 168.5*2 + 105.16)=-2105.16 

    if XCoordinate < -11.694:
        XCoordinate = -11.694
    elif XCoordinate > 331.694:
        XCoordinate = 331.694

    if corner == 0: # negative y, positive x
        if YCoordinate < -10.516:
            YCoordinate = -10.516
        elif YCoordinate > 210.516:
            YCoordinate = 210.516
            
    elif corner == 1: # positive y, positive x
        if YCoordinate < -210.516:
            YCoordinate = -210.516
        elif YCoordinate > 10.516:
            YCoordinate = 10.516
        
    return XCoordinate, YCoordinate

def get_obstacle_coord(distance, angle, currentX, currentY, currentAngle): # lingdao coordinate system in cm, angle anticlockwise is positive
    # anticlockwise is positive angle
    obstacle_x = currentX/10 + distance * math.cos((angle+currentAngle)/180*math.pi)
    obstacle_y = -currentY/10 - distance * math.sin((angle+currentAngle)/180*math.pi)
    print("line 101: ")
    print(distance, " ", angle, " ", currentX, " ", currentY, " ", currentAngle, " ", obstacle_x, " ", obstacle_y)
    return obstacle_x, obstacle_y

#-----------------------------------------------------------------------------------------------------------------------------#
#-----------------------------------------------------WEBSERVER COMMUNICATION-------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------------#
def webserver_communication(welcome_socket_web, server_port_web, current_information, msg_to_esp, start, database, control_mode): # current_info includes: coordinate, direction, charge
  welcome_socket_web.bind(('0.0.0.0',server_port_web))
  welcome_socket_web.listen(1)
  print('Web Server running on port ', server_port_web)
  connection_socket_web, caddr_add = welcome_socket_web.accept()
  print("Web Client Connected")
  message = ""
  corner = -1
  mode = 0
  while True:
    cmsg = connection_socket_web.recv(1024)
    cmsg = cmsg.decode()
    if (cmsg != "req"):
        print("received from web:", cmsg)
    
    # print("-----------website:", cmsg)
    #-------------------------------------------------------Receive-----------------------------------------------------------------#
    if cmsg != "":
        # print("received from webserver:", cmsg)

        # before start - only transmit status
        if "status" in cmsg:
            status_dict = {'status': current_information['status']}
            message = json.dumps(status_dict)
            connection_socket_web.send(message.encode())

        # start exploration mode
        elif ("!start0$" in cmsg) or ("!start1$" in cmsg): # !start0$ for bottom, !start1$ for top
            start[0] = True
            print("start! in exploration mode")
            msg_to_esp[0] = cmsg

            database[0] = int(TimeDatabase.get_max_nav_index())+1 # NavigationId 
            database[1] = 0 # Position Index
            database[7] = cmsg[6]
            current_information['xCoord'] = 0
            current_information['yCoord'] = 0
            current_information['xCoordPlan'] = 0
            current_information['yCoordPlan'] = 0
            current_information['battery'] = 0
            current_information['Aliens'] = []
            current_information['Tower'] = []

        # manually stop exploration
        elif "!stopexp$" in cmsg: 
            msg_to_esp[0] = cmsg
        
        # reaching coordinates and ball
        elif ((cmsg[:2] == "!x" or cmsg[:2] == "!b") and cmsg[-1] == "$"):
            msg_to_esp[0] = cmsg

        # start a new map! continuous control mode to look at balls 
        elif "!control" in cmsg: # "!control1,x200,y678$"
            start[0] = True
            control_mode[0] = True
            print("start! in controlling mode")
            
            database[0] = int(TimeDatabase.get_max_nav_index())+1 # NavigationId 
            database[1] = 0 # position index
            cmsgLst = cmsg.split(",")
            database[7] = cmsgLst[0][-1] # start corner

            xResetCoordinate = float(cmsgLst[1][1:]) * 200 # convert node to mm
            yResetCoordinate = -1 * float(cmsgLst[2][1:-1]) * 200
            current_information['xCoord'] = xResetCoordinate
            current_information['yCoord'] = yResetCoordinate

            msg_to_esp[0] = "!control,x" + str(int(xResetCoordinate)) + ",y" + str(int(yResetCoordinate)) + "$"

            # if 'xCoord' in current_information : 
            #     # if there is xCoord in current_information, it means the control mode is after the exploration, we set the starting plan coordinate to the end of exploration
            #     # if there is no xCoord in current_information, it means that the control mode is run first, set to 0
            #     database[2] = current_information['xCoordPlan']
            #     database[3] = current_information['yCoordPlan']
            #     current_information['Alien'] = []
            #     current_information['Tower'] = []
            # else:
            #     current_information['xCoord'] = 0
            #     current_information['yCoord'] = 0
            #     current_information['xCoordPlan'] = 0
            #     current_information['yCoordPlan'] = 0
            # print("line 137")
            # database[8] = 1 # facing direction


        # remote control continuous
        elif "!cw$" in cmsg: 
            msg_to_esp[0] = "!cw$"
        elif "!ca$" in cmsg: 
            msg_to_esp[0] = "!ca$"
        elif "!cs$" in cmsg: 
            msg_to_esp[0] = "!cs$"
        elif "!cd$" in cmsg: 
            msg_to_esp[0] = "!cd$"
        elif "!cr$" in cmsg:
            msg_to_esp[0] = "!cr$"

        elif "!detect$" in cmsg:
            msg_to_esp[0] = "!detect$"
        
        # node mode, clear all aliens and paths 
        elif "!node$" in cmsg: 
            start[0] = True
            print("start! in node mode")
            msg_to_esp[0] = cmsg

            database[0] = int(TimeDatabase.get_max_nav_index())+1 # NavigationId 
            database[1] = 0 # Position Index
            database[7] = "0"
            current_information['xCoord'] = 0
            current_information['yCoord'] = 0
            current_information['xCoordPlan'] = 0
            current_information['yCoordPlan'] = 0
            current_information['battery'] = 0
            current_information['Aliens'] = []
            current_information['Tower'] = []

        # remote control node OR adjust to correct position before remote control mode
        elif "!w$" in cmsg: 
            msg_to_esp[0] = "!w$"
        elif "!a$" in cmsg: 
            msg_to_esp[0] = "!a$"
        elif "!s$" in cmsg: 
            msg_to_esp[0] = "!s$"
        elif "!d$" in cmsg: 
            msg_to_esp[0] = "!d$"

        # end of whole exploration, store database
        elif "!end$" in cmsg:
            msg_to_esp[0] = "!end$"
            print("line 241")
            start[0] = False
            control_mode[0] = False
        
 
        # after start, req current rover data
        elif cmsg == "req":
            message = json.dumps(current_information)
            connection_socket_web.send(message.encode())
            # print("receive req")
            # print("Response to req:", message)
            # print("sent webserver msg:", message.encode())

        # require history list
        elif cmsg == "hist":
            hist_query_list = TimeDatabase.scan_time_table()
            # hist_list = {'Index':[{'id':1,'time':'2022-06-02'},{'id':2,'time':'2022-06-03'},{'id':3,'time':'2022-06-04'},{'id':4,'time':'2022-06-04'}]}
            # select the latest 5 history data
            display_hist_list = []
            if len(hist_query_list) != 0:
                for i in range(len(hist_query_list)):
                    hist_index = hist_query_list[i]['id']
                    if hist_index > len(hist_query_list)-5:
                        display_hist_list.append(hist_query_list[i])
        
            # print("selected hist_query_list:", display_hist_list)
            display_hist_list = sorted(display_hist_list,key=lambda x:x['id'],reverse=True)
            # print("selected hist_query_list after sorting:", display_hist_list)
            sent_message_json = {'Index':display_hist_list}
            message = json.dumps(sent_message_json, use_decimal=True)
            connection_socket_web.send(message.encode())
            print('sent hist message', message)
        
        # require specific history information "hinx2"
        elif cmsg[0:4] == "hinx":  #history index  hinx2
            historyIndex = cmsg[4:]
            hist_info_list = {}
            # hist_info_list['Aliens'] = [{'id':1,'x':45,'y':56,'c':'b','e':1},{'id':2,'x':0,'y':50,'c':'g','e':2}]
            aliens = AlienDatabase.query_aliens(int(historyIndex))
            timeDetails = TimeDatabase.query_time(int(historyIndex))
            towers = TowerDatabase.query_tower(int(historyIndex))
            # radars = RadarDatabase.query_radar(int(historyIndex))

            # TIME
            if len(timeDetails) == 0:
                hist_info_list['start'] = ''
                hist_info_list['end'] = ''
                hist_info_list['Corner'] = -1
                corner = -1
            else:
                hist_info_list['start'] = timeDetails[0]['start']
                hist_info_list['end'] = timeDetails[0]['end']
                hist_info_list['Corner'] = int(timeDetails[0]['Corner'])
                corner = int (timeDetails[0]['Corner'])

             # TOWER
            for tower in towers:
                tower['x'] = float(tower['x'])
                tower['y'] = float(tower['y'])
                tower['w'] = float(tower['w'])
                tower['e'] = int(tower['e'])
            hist_info_list['Tower'] = towers
    

            # ALIEN
            for alien in aliens:
                alien['x'] = float(alien['x'])
                alien['y'] = float(alien['y'])
                alien['e'] = int(alien['e'])
            hist_info_list['Aliens'] = aliens

            # # RADAR
            # for radar in radars:
            #     radar['x'] = float(radar['x'])
            #     radar['y'] = float(radar['y'])
            #     radar['i'] = float(radar['i'])
            # hist_info_list['Radar'] = radars
      
            path = PositionDatabase.query_positions(int(historyIndex))
            path_real = []
            path_position_real = {'x':0,'y':0}
            path_planned = []
            path_position_planned = {'x':0,'y':0}
            for position in path:
                path_position_real['x'] = float(position['x'])/5.842
                path_position_planned['x'] = float(position['xp'])

                if corner == 0:
                    path_position_real['y'] = 342.32 - float(position['y'])/5.847 # 342.32-positive
                    path_position_planned['y'] = 342.32 + float(position['yp']) # 342.32+negative
                elif corner == 1:
                    path_position_real['y'] = - float(position['y'])/5.847 # positive
                    path_position_planned['y'] = float(position['yp']) # positive
                path_real.append(path_position_real.copy())
                path_planned.append(path_position_planned.copy())
        
            path_real_part = get_path_part(path_real, 10)
            path_planned_part = get_path_part(path_planned, 10)

            hist_info_list['Parts'] = len(path_real_part)
            
            message = json.dumps(hist_info_list,use_decimal=True)
            connection_socket_web.send(message.encode())
            # print("Message to webserver:",message)

            for part_num in range(len(path_real_part)):
                part_req = connection_socket_web.recv(1024)
                part_req = part_req.decode()
                # print("Received part request:", part_req)
                # "i2,p0"
                if part_req == "":
                    part_num += 1
                    continue
                if part_req[0] == 'i': 
                    part_req_list = part_req.split(",")
                    
                    if (int(part_req_list[0][1:]) == int(historyIndex) and int(part_req_list[1][1:]) == part_num):
                        hist_info_list = {}
                        hist_info_list['Pathreal'] = path_real_part[part_num]    
                        hist_info_list['Pathplanned'] = path_planned_part[part_num]    

                        message = json.dumps(hist_info_list,use_decimal=True)
                        # print("Part message to webserver:", message)
                        connection_socket_web.send(message.encode())
                        print("part num", part_num, "matched      Send to webserver:", message)
                    # else:
                        # print("part num doesn't match:",int(part_req_list[0][1:]), " , ", historyIndex, " , ", int(part_req_list[1][1:]), "," , part_num)

        elif cmsg == "!startradar$":
            msg_to_esp[0] = "!startradar$"
            start[0] = True
        
        elif cmsg == "!endradar$":
            msg_to_esp[0] = "!endradar$"
            start[0] = False
            current_information["Radar"] = []

def check_if_alien_exists(current_information, color):
    exist = -1
    for i in range(len(current_information["Aliens"])):
        if color == current_information["Aliens"][i]['c']:
           exist = i
    return exist 

#-----------------------------------------------------------------------------------------------------------------------------#
#-------------------------------------------------------ESP32 COMMUNICATION---------------------------------------------------#
#-----------------------------------------------------------------------------------------------------------------------------#
async def espserver_communication(websocket, current_information, msg_to_esp, start, database, control_mode):
    print("ESP connected")
    lastActiveTime = datetime.now() # for checking if client is alive
    connection_status = 1
    current_information['status'] = connection_status
    # start_flag = False
    global alien_info
    global tower_info
    start_flag = False
 
    cmsg, connection_status, lastActiveTime = await receive_from_esp(websocket, connection_status, lastActiveTime)
    if cmsg=='restart':
        print(cmsg,'hihihihhihi')
        start_flag = True

    buffer_empty = True
    # print('msgtoesp',msg_to_esp,'startflat',start_flag,'database',database)
    while True:
        
        #### 'end' signal
        if msg_to_esp[0] == "!end$":
            print("sending to esp END signal...")
            connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
            current_information['status'] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!5")
                return
            buffer_empty = False
            msg_to_esp[0] = ""
            start_flag = False
            database[6] = datetime.now().strftime('%Y-%m-%d-%H-%M-%S') #End
            add_time = TimeDatabase.add_time(database[0],database[4],database[5],database[6], database[7])
            
            # TOWER
            for key in tower_info:
                towerselectedInfo = tower_info[key][-1] # the latest information for a tower
                towerselectedCoords = towerselectedInfo[2:].split(",")
                XselectedCoordinateTower = round(float(towerselectedCoords[0][1:])*10,2)
                YselectedCoordinateTower = round(float(towerselectedCoords[1][1:])*10,2)
                selectedWidthTower = round(float(towerselectedCoords[2][1:])*10,2)
                selectedCountTower = towerselectedCoords[3][1:]
                add_tower = TowerDatabase.add_tower(database[0], key, str(XselectedCoordinateTower), str(YselectedCoordinateTower), str(selectedWidthTower), selectedCountTower)

            # ALIEN
            for key in alien_info:
                alienselectedInfo = alien_info[key][-1] # the latest information for a alien
                alienselectedCoords = alienselectedInfo[2:].split(",") # get rid of 'ar' & split
                XselectedCoordinate = round(float(alienselectedCoords[0][1:])*10,2)
                YselectedCoordinate = round(float(alienselectedCoords[1][1:])*10,2)
                selectedCount = alienselectedCoords[2][1:]
                selectedColor = alienselectedInfo[1]
                add_alien = AlienDatabase.add_alien(database[0], key, str(XselectedCoordinate), str(YselectedCoordinate), selectedColor, selectedCount)
                
            # # RADAR
            # radar_list = current_information["Radar"]
            # for key in radar_list:
            #     add_radar = RadarDatabase.add_radar(radar_list[key]['id'], radar_list[key]['x'], radar_list[key]['y'], radar_list[key]['i'])
            # continue

        #### ----------------------------------------------之前不发数--------------------------------------------------####
        #-----------------------------------------Waiting for Start signal-----------------------------------------------#
        while start_flag == False:
            #### exploration mode:
            if msg_to_esp[0] == "!start0$" or msg_to_esp[0] == "!start1$":
                if buffer_empty == False:
                    while True:
                        # receive
                        cmsg, connection_status, lastActiveTime = await receive_from_esp(websocket, connection_status, lastActiveTime)
                        # print("received from esp:", cmsg)
                        current_information['status'] = connection_status
                        if connection_status == 0:
                            print("!!!!!!!!!!!!!!!!!!!!!1")
                            return
                        if "E" in cmsg:
                            break
                    buffer_empty = True
                print("sending start to esp in exploration mode ...")
                alien_info = {} ## {1:["info1","info2"], 2:["info1","info2"]}
                tower_info = {} ## {1:["info1","info2"], 2:["info1","info2"]}
                connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
                current_information['status'] = connection_status
                if connection_status == 0:
                    print("!!!!!!!!!!!!!!!!!!!!!2")
                    return
                msg_to_esp[0] = ""
                start_flag = True
                stopStoringToDatabase = False
                database[4] = datetime.now().strftime('%Y-%m-%d') # Time
                database[5] = datetime.now().strftime('%Y-%m-%d-%H-%M-%S') #Start
     
            #### secretly adjust position
            elif msg_to_esp[0] == "!cw$" or msg_to_esp[0] == "!cs$" or msg_to_esp[0] == "!ca$" or msg_to_esp[0] == "!cd$" or msg_to_esp[0] == "!cr$":
                connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
                current_information['status'] = connection_status
                if connection_status == 0:
                    print("!!!!!!!!!!!!!!!!!!!!!5")
                    return   
                msg_to_esp[0] = "" 
            
            #### remote control mode
            elif "!control" in msg_to_esp[0]: # "!control,x200,y678$"
                if buffer_empty == False:
                    while True:
                        # receive
                        cmsg, connection_status, lastActiveTime = await receive_from_esp(websocket, connection_status, lastActiveTime)
                        # print("received from esp:", cmsg)
                        current_information['status'] = connection_status
                        if connection_status == 0:
                            print("!!!!!!!!!!!!!!!!!!!!!1")
                            return
                        if "E" in cmsg:
                            break
                    buffer_empty = True
                print("sending start to esp in remote control mode, correct angle to 0 deg ...")
                # alien_info = {} ## {1:["info1","info2"], 2:["info1","info2"]}
                # tower_info = {} ## {1:["info1","info2"], 2:["info1","info2"]} 
                connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status) # ESP32 no need to know specific start corner, but need to correct the angle to 0deg
                current_information['status'] = connection_status
                if connection_status == 0:
                    print("!!!!!!!!!!!!!!!!!!!!!2")
                    return
                msg_to_esp[0] = ""
                start_flag = True
                stopStoringToDatabase = False
                database[4] = datetime.now().strftime('%Y-%m-%d') # Time
                database[5] = datetime.now().strftime('%Y-%m-%d-%H-%M-%S') #Start

            elif msg_to_esp[0] == "!node$":
                connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
                msg_to_esp[0] = ""
                start_flag = True
                stopStoringToDatabase = False
                database[4] = datetime.now().strftime('%Y-%m-%d') # Time
                database[5] = datetime.now().strftime('%Y-%m-%d-%H-%M-%S') #Start
                database[7] = 0 #corner

            elif msg_to_esp[0] == "!startradar$":
                connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
                if buffer_empty == False:
                    while True:
                        # receive
                        cmsg, connection_status, lastActiveTime = await receive_from_esp(websocket, connection_status, lastActiveTime)
                        # print("received from esp:", cmsg)
                        current_information['status'] = connection_status
                        if connection_status == 0:
                            print("!!!!!!!!!!!!!!!!!!!!!1")
                            return
                        if "E" in cmsg:
                            break
                    buffer_empty = True
                print("start radar")
                
                msg_to_esp[0] = ""
                start_flag = True
                stopStoringToDatabase = True

                
            # check the connection status
            connection_status, lastActiveTime = await check_connection(websocket, connection_status, lastActiveTime)
            current_information['status'] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!4")
                return
                
        ####--------------------------------------之前发数---------------------------------------------#
        #-------------Already started, send to esp other information 1)'end' signal 2)REMOTE CONTROL SIGNAL-----------------------------------------------------#
        #### 'stopexp' signal 
        if msg_to_esp[0] == "!stopexp$":
            connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
            stopStoringToDatabase = True
            current_information['status'] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!5")
                return
            msg_to_esp[0] = ""

        elif msg_to_esp[0] == "!endradar$":
            connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
            current_information["status"] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!5")
                return
            msg_to_esp[0] = ""

         #### reaching coordinate (following exploration mode, not considered as a new navigation)
        elif msg_to_esp[0][:2] == "!x" and msg_to_esp[0].split(",")[1][0] == "y":
            # print("sending to esp reaching coordinates...")
            connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
            current_information['status'] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!3")
                return
            msg_to_esp[0] = ""


        #### reaching color ball (following exploration mode, not considered as a new navigation)
        elif msg_to_esp[0][:2] == "!b" and msg_to_esp[0][3] == "$":
            # print("sending to esp ball color...")
            connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
            current_information['status'] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!3")
                return
            msg_to_esp[0] = ""

        #### check the connection status
        connection_status, lastActiveTime = await check_connection(websocket, connection_status, lastActiveTime)
        current_information['status'] = connection_status
        if connection_status == 0:
            print("!!!!!!!!!!!!!!!!!!!!!4")
            return

        #### remote control mode in node
        elif msg_to_esp[0] == "!w$" or msg_to_esp[0] == "!s$" or msg_to_esp[0] == "!a$" or msg_to_esp[0] == "!d$":
            # moving to left or right
            if (msg_to_esp[0] == "!w$" and database[8] == 1) or (msg_to_esp[0] == "!s$" and database[8] == 3): # move right, x increase
                database[2] = database[2] + 34.2
            elif (msg_to_esp[0] == "!w$" and database[8] == 3) or (msg_to_esp[0] == "!s$" and database[8] == 1): # move left, x decrease
                database[2] = database[2] - 34.2
            elif (msg_to_esp[0] == "!w$" and database[8] == 0) or (msg_to_esp[0] == "!s$" and database[8] == 2): # move up, y decrease
                database[3] = database[3] - 34.23
            elif (msg_to_esp[0] == "!s$" and database[8] == 0) or (msg_to_esp[0] == "!w$" and database[8] == 2): # move down, y increase
                database[3] = database[3] + 34.23
            elif msg_to_esp[0] == "!a$":     # rotate anticlockwise
                database[8] = (database[8]-1+4)%4 
            elif msg_to_esp[0] == "!d$":   # rotate clockwise
                database[8] = (database[8]+1+4)%4
            connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
            current_information['status'] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!5")
                return   
            msg_to_esp[0] = "" 
        
        # remote control in continuous mode
        elif msg_to_esp[0] == "!cw$" or msg_to_esp[0] == "!cs$" or msg_to_esp[0] == "!ca$" or msg_to_esp[0] == "!cd$" or msg_to_esp[0] == "!cr$":
            connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
            current_information['status'] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!5")
                return   
            msg_to_esp[0] = "" 

        # detect alien instruction
        elif msg_to_esp[0] == "!detect$":
            connection_status = await send_to_esp(websocket, msg_to_esp[0], connection_status)
            current_information['status'] = connection_status
            if connection_status == 0:
                print("!!!!!!!!!!!!!!!!!!!!!5")
                return   
            msg_to_esp[0] = "" 
            
        #---------------------------------------------------Receive rover information from ESP32-----------------------------------------------------#
        cmsg, connection_status, lastActiveTime = await receive_from_esp(websocket, connection_status, lastActiveTime)
        if connection_status == 0:
            print("!!!!!!!!!!!!!!!!!!!!!6")
            return
        # print("received from esp:", cmsg)
        if cmsg != "" and start[0] == True:
            regex = '\!(.*?)\$'
            validInfoList = re.findall(regex, cmsg)
            for i in range(len(validInfoList)):
                # stop looping through the list 
                if msg_to_esp[0] == "!end$":
                    break
                selectedInfo = validInfoList[i] 
                # "!cx23.34,y45.67,t67,b23$" Real Coordinate 
                if selectedInfo[0] == "c":
                    roverCoords = selectedInfo[1:].split(",") # get rid of 'c' & split
                    XCoordinate  = roverCoords[0][1:]
                    YCoordinate = roverCoords[1][1:]
                    thetaAngle = roverCoords[2][1:]
                    current_information['xCoord'] = float(XCoordinate)
                    current_information['yCoord'] = float(YCoordinate)
                    current_information['angle'] = float(thetaAngle)
                    database[1]+=1

                    if stopStoringToDatabase == False:
                        add_position = PositionDatabase.add_position(database[0], database[1], XCoordinate, YCoordinate,str(database[2]),str(database[3]))
                
                # "!px10,y6$" Planned Node Coordinate
                elif selectedInfo[0] == "p":
                    roverCoordsPlanned = selectedInfo[1:].split(",")
                    XCoordinatePlanned  = round(float(roverCoordsPlanned[0][1:]) * 34.2, 2)
                    YCoordinatePlanned = round(float(roverCoordsPlanned[1][1:]) * 34.23, 2)
                    current_information['xCoordPlan'] = XCoordinatePlanned  # 只有planned是存图的坐标，剩下的全是存global coord in mm
                    current_information['yCoordPlan'] = YCoordinatePlanned
                    database[2] = XCoordinatePlanned
                    database[3] = YCoordinatePlanned

                
                # "!arx23.34,y45.67,e1$" Alien
                # in control mode: !ard12.2,a5.2$
                elif selectedInfo[0] == "a":
                    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                    print("!!!!!!!!!!!!!!!!!!!!!!!!", selectedInfo, "!!!!!!!!!!!!!!!!!!!!")
                    print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!")
                    # send the alien info back to esp - act as ACK
                    # connection_socket_esp.send(("!" + selectedInfo + "$").encode()) NEED TO CHANGE BACK!!!!!!!!!!
                    
                    # alienIndex = int(selectedInfo[1])-1
                    Color = selectedInfo[1]
                    if (control_mode[0] == True):
                        alienDistanceAndAngle = selectedInfo[2:].split(",") # get rid of 'ar' & split
                        distance = float(alienDistanceAndAngle[0][1:])
                        angle = float(alienDistanceAndAngle[1][1:-1])
                        XCoordinate, YCoordinate = get_obstacle_coord(distance, angle, current_information['xCoord'], current_information['yCoord'], current_information['angle'])
                        Count = "2"
                        selectedInfo = "a"+Color+"x"+str(XCoordinate)+",y"+str(YCoordinate)+",e2"

                    else:
                        alienCoordsAndCount = selectedInfo[2:].split(",") # get rid of 'ar' & split
                        XCoordinate = float(alienCoordsAndCount[0][1:])
                        YCoordinate = float(alienCoordsAndCount[1][1:])
                        Count = int(alienCoordsAndCount[2][1:])
                    
                    # XCoordinate, YCoordinate = alien_out_of_range_correction(XCoordinate, YCoordinate, database[7])

                    alienIndex = check_if_alien_exists(current_information, Color)
                    # Create a new alien
                    if alienIndex == -1:
                        alienIndex = len(alien_info)
                        alien_dict = {}
                        alien_dict['id'] = alienIndex + 1
                        alien_dict['x'] = round(XCoordinate*10,2)
                        alien_dict['y'] = round(YCoordinate*10,2)
                        alien_dict['c'] = Color
                        alien_dict['e'] = Count
                        
                        current_information["Aliens"].append(alien_dict)
                        print("£££££££££££££££££££££££ New alien created:", current_information["Aliens"])
                        alien_info[alienIndex+1] = [selectedInfo]
                        # print(alien_info)
                    # The alien already exists, change its info
                    else:
                        alien_info[alienIndex+1].append(selectedInfo)
                        # print(alien_info)
                        current_information["Aliens"][alienIndex]['x'] = round(float(XCoordinate)*10,2)
                        current_information["Aliens"][alienIndex]['y'] = round(float(YCoordinate)*10,2)
                        current_information["Aliens"][alienIndex]['c'] = Color
                        current_information["Aliens"][alienIndex]["e"] = Count
                        print("£££££££££££££££££££££££ alien changed:", current_information["Aliens"])
                        
                    
                # # "!b34$" battery level
                # elif selectedInfo[0] == "b":
                #     current_information['battery'] = selectedInfo[1:]

                # "!t1x34,y78,w23,e1$" tower 
                elif selectedInfo[0] == "t":
                    towerCoordsFilter = selectedInfo[2:].split(",")
                    WidthTowerFilter = float(towerCoordsFilter[2][1:])

                    if WidthTowerFilter != 0:

                        towerIndex = int(selectedInfo[1])-1
                        if (control_mode[0] == True):
                            towerDistanceAngleWidth = selectedInfo[2:].split(",") # get rid of 't1'
                            distance = float(towerDistanceAngleWidth[0][1:]) 
                            angle = float(towerDistanceAngleWidth[1][1:])
                            WidthTower = float(towerDistanceAngleWidth[2][1:-1])
                            XCoordinateTower, YCoordinateTower = get_obstacle_coord(distance, angle, current_information['xCoord'], current_information['yCoord'], current_information['angle'])
                            countTower = 2
                            selectedInfo = "t"+str(towerIndex+1)+"x"+str(XCoordinateTower)+",y"+str(YCoordinateTower)+",w"+str(WidthTower)+",e2"
                        
                        else:
                            towerCoords = selectedInfo[2:].split(",")
                            XCoordinateTower  = float(towerCoords[0][1:])
                            YCoordinateTower = float(towerCoords[1][1:])
                            WidthTower = float(towerCoords[2][1:])
                            countTower = int(towerCoords[3][1:])


                        if towerIndex >= len(current_information['Tower']):
                            tower_dict = {}
                            tower_dict['id'] = towerIndex + 1
                            tower_dict['x'] = round(XCoordinateTower*10,2)
                            tower_dict['y'] = round(YCoordinateTower*10,2)
                            tower_dict['w'] = round(WidthTower*10,2)
                            tower_dict['e'] = countTower
                            current_information['Tower'].append(tower_dict) 
                            tower_info[towerIndex+1] = [selectedInfo]

                        else:
                            existedTower = False
                            for infoTower in tower_info[towerIndex+1]:
                                if infoTower == selectedInfo:
                                    existedTower = True
                                    break
                            if existedTower == False:
                                tower_info[towerIndex+1].append(selectedInfo)
                                # print(alien_info)
                                current_information["Tower"][towerIndex]['x'] = round(float(XCoordinateTower)*10,2)
                                current_information["Tower"][towerIndex]['y'] = round(float(YCoordinateTower)*10,2)
                                current_information["Tower"][towerIndex]['w'] = round(float(WidthTower)*10,2)
                                current_information["Tower"][towerIndex]["e"] = int(countTower)
                        print("################# Tower:",current_information["Tower"])

                # receive: "!rx32.4,y100.23,i2$" radar intensity
                # send to web: add index
                elif selectedInfo[0] == "r": 
                    radarIndex = len(current_information["Radar"]) # radarIndex starts from 0

                    radarCoordsAndIntensity = selectedInfo[1:].split(",") # get rid of 'r' & split
                    XCoordinate = radarCoordsAndIntensity[0][1:]
                    YCoordinate = radarCoordsAndIntensity[1][1:]
                    Intensity = radarCoordsAndIntensity[2][1:]

                    radar_dict = {}
                    radar_dict['id'] = radarIndex
                    radar_dict['x'] = round(float(XCoordinate),2)
                    radar_dict['y'] = round(float(YCoordinate),2)

                    if (0.4 < float(Intensity) and float(Intensity) <= 4): ## should be 3.3
                        if (0.4 < float(Intensity) and float(Intensity) <= 1.4):
                            radar_dict['i'] = 1
                        elif (1.4 < float(Intensity) and float(Intensity) <= 2.3):
                            radar_dict['i'] = 2
                        elif (2.3 < float(Intensity) and float(Intensity) <= 4):
                            radar_dict['i'] = 3
                        current_information["Radar"].append(radar_dict)
                        print(current_information["Radar"])

        # check everytime the connection status
        connection_status, lastActiveTime = await check_connection(websocket, connection_status, lastActiveTime)
        current_information['status'] = connection_status
        if connection_status == 0:
            print("!!!!!!!!!!!!!!!!!!!!!7")
            # asyncio.Future.set_result("done")
            return

def intermediate_func(current_information, msg_to_esp, start, database, control_mode):
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    ws_server = websockets.serve(functools.partial(espserver_communication, current_information=current_information, msg_to_esp = msg_to_esp, start = start, database = database, control_mode = control_mode), port=14000, ping_timeout=20, timeout=1, close_timeout=1)
    loop.run_until_complete(ws_server)
    loop.run_forever()

current_information = {"status":0, "xCoord": 0, "yCoord": 0, "angle": 0, "xCoordPlan": 0, "yCoordPlan": 0,"battery": 0, "Aliens": [], "Tower":[], "Radar":[]}  # "Aliens": [{id:1,x:45,y:56,c:'b'},{id:2,x:0,y:50,c:'g'}]
msg_to_esp = [""]
start = [False]
database = [0,0,0,0,'','','',0,0] 
# database[0]:Navigation Id; database[1]:rover position table index; database[2]:planned position x; database[3]: planned position y;
# database[4]:time; database[5]:start; database[6]:end; 
# database[7]: corner 
# database[8]: direction->only useful for remote control to calculate the planned path 0123 up right down left
control_mode = [False]

# xCoord: num, yCoord: num, battery: num,
# alien1: 
# xAlien: [alien1, alien2, alien3], yAlien: [alien1, alien2, alien3], Colour: [alien1, alien2, alien3]

print("We're in database server...")
# receive from ESP32 server
print("ESP listening on port 14000")
#thread = Thread (target=asyncio.run,args = (websocket_espserver_communication(current_information, msg_to_esp, start, database),))
thread = Thread (target=intermediate_func, args = (current_information, msg_to_esp, start, database, control_mode, ))
thread.start()

# send to web server
server_port_web = 12000
welcome_socket_web = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
welcome_socket_web.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
webserver_communication(welcome_socket_web,server_port_web,current_information,msg_to_esp, start,database, control_mode)