laser = rossubscriber('/base_scan');
robotPos = rossubscriber('/odom');

%Fahrbefehle in Form von Geschwindigkeiten
robotCmd = rospublisher('/cmd_vel', 'geometry_msgs/Twist');
velMsg = rosmessage(robotCmd);


scandata = receive(laser,10);
angles = linspace(scandata.AngleMin, scandata.AngleMax, numel(scandata.Ranges));
xy = readCartesian(scandata);
ranges = scandata.Ranges;
ranges(720);

values = 1:720;
%histogram(720,ranges);

%bar(values,ranges);

scandata = receive(laser,10);
% xy = readCartesian(scandata(1))
% plot(xy(:,1),xy(:,2));


%angles = linspace(scandata.AngleMin, scandata.AngleMax, numel(scandata.Ranges));


while true
    scandata = receive(laser,10);
    ranges = scandata.Ranges;
    vel_msg = rosmessage(robotCmd);
    vel_msg.Linear.X = 0.5;
    send(robotCmd,vel_msg);
    xy = readCartesian(scandata);
    x = xy(:,1);
    y = xy(:,2);
    plot(xy(:,1),xy(:,2));
    
    
    if ranges(1) < 1
       
        vel_msg.Linear.X = 0;
        send(robotCmd,vel_msg);
        
        angle_min = scandata.AngleMin
        angle_max = scandata.AngleMax
        angle_inc = scandata.AngleIncrement
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        ranges1_left = ranges(351:720);
        ranges1_right = ranges(1:350);
        
        [left1_min_range, left1_min_ind] = min(ranges1_left);
        [right1_min_range, right1_min_ind] = min(ranges1_right);
        
        left1_min_ind = left1_min_ind + 350;
        
        x1_right = x(right1_min_ind);
        y1_right = y(right1_min_ind);
        
        x1_left = x(left1_min_ind);
        y1_left = y(left1_min_ind);
        
        angles1_left = (left1_min_ind) * angle_inc;
        angles1_right = (right1_min_ind) * angle_inc;
        
        angles1_left_deg = angles1_left * (180/pi);
        angles1_right_deg = angles1_right * (180/pi);
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        ranges_left = ranges(350:650);
        ranges_right = ranges(50:350);
        
        [left2_min_range, left2_min_ind] = min(ranges_left);
        [right2_min_range, right2_min_ind] = min(ranges_right);
        
        left2_min_ind = left2_min_ind + 350;
        right2_min_ind = right2_min_ind + 50;
        
        
        
        x2_right = x(right2_min_ind);
        y2_right = y(right2_min_ind);
        
        x2_left = x(left2_min_ind);
        y2_left = y(left2_min_ind);
        
        angles2_left = (left2_min_ind) * angle_inc;
        angles2_right = (right2_min_ind) * angle_inc;
        
        angles2_left_deg = angles2_left * (180/pi);
        angles2_right_deg = angles2_right * (180/pi);
        
        
        
        aplha = atan((y1_left-y2_left)/(x1_left-x2_left))
        
        aplha_deg = aplha * (180/pi)
        
        
        break;
        
    end
    
    
end