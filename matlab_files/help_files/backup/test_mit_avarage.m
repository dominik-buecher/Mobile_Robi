clc;
clear;

laser = rossubscriber('/base_scan');
robotPos = rossubscriber('/odom');

%Fahrbefehle in Form von Geschwindigkeiten
cmd_vel = rospublisher('/cmd_vel', 'geometry_msgs/Twist');
velMsg = rosmessage(cmd_vel);

%Abstand zur Reihenmitte
pub_offset = rospublisher('/offset', 'std_msgs/Float64');
offsetMsg = rosmessage(pub_offset);

%Orientierung zur Reihenmitte
pub_alpha = rospublisher('/alpha', 'std_msgs/Float64');
alphaMsg = rosmessage(pub_alpha);

%true, wenn innerhalb der Reihe
inside_row = rospublisher('/inside_row', 'std_msgs/Bool');
insideRowMsg = rosmessage(inside_row);


% Definiere die Breite, die links und rechts hinzugefügt werden soll
intervall_Breite = 0.05; 
roi_view_x = 2.5;
roi_view_y = 0.8;
turn_counter = 1;
robot_speed = 0.5;
robot_width = 0.3;
values = 1:720;
k = 20;
kp = 0.7;
old_alpha = 0;
lenk_toleranz = 0.065
x_distance = 0.5; 

xy_plot = [];
alpha_array = [];



while true
    
    scandata = receive(laser,10);
    ranges = scandata.Ranges;
    ranges(720);

    
    vel_msg = rosmessage(cmd_vel);
    vel_msg.Linear.X = robot_speed;
    send(cmd_vel,vel_msg);
    
   
    % check if the robot is at the end of the maze
    % make a turn if the robot is at the end
    if min(ranges)>3
                    
        %publish that the Robot is not inside the maze 
        insideRowMsg.Data = false;
        send(inside_row, insideRowMsg);
        %pub_inside_row.publish(insideRowMsg);
        
        distance = 0.5;
        
        if mod(turn_counter, 2) == 0
            direction = -1;
        else
            direction = 1;
        end 
        
        velocity = 0.5;
        radius = 0.4;
        linearSpeed = velocity;
        angularSpeed = velocity/radius;
        durationStraight = distance/ linearSpeed;
        
        % drive a little bit out of the maze field in a straight line
        vel_msg.Angular.Z = 0;
        sendTime = rostime('now');
        while (rostime('now') - sendTime < durationStraight)
            send(robotCmd, vel_msg);
        end 
        
        % make a turn
        angle = pi;
        durationCurve = angle/angularSpeed;
        vel_msg.Linear.X = linearSpeed;
        vel_msg.Angular.Z = direction * angularSpeed;
        sendTime = rostime('now');
        while (rostime('now') - sendTime < durationCurve - 0.15) % 0.15 offset damit er die Kurve nicht noch weiter ausfährt
            send(robotCmd, vel_msg);
        end
        turn_counter = turn_counter + 1;
        
        
    elseif min(ranges) < 2
        
        %publish that the Robot is inside the maze 
        insideRowMsg.Data = true;
        send(inside_row, insideRowMsg);
        %pub_inside_row.publish(insideRowMsg);
        
        xy = readCartesian(scandata);   
        roi = (xy(:,1) > 0 & xy(:,1) < roi_view_x) & (abs(xy(:,2)) < roi_view_y);
        found_points = xy(roi,:);
        
        
        alpha = alphahist(found_points, old_alpha, k);
        old_alpha = alpha;
        alpha_array = [alpha_array; alpha];
        
        %publish the orientation alpha of the robot to the mid 
        orientationMsg.data = alpha;
        send(pub_alpha, alphaMsg);
        
        
        points_left = [];
        points_right = [];
        mittel_linie = [];
        for i = 1:length(found_points)
            if found_points(i,2) > 0
                points_left = [points_left; found_points(i,1), (found_points(i,2) - 0.375)];
                mittel_linie = [mittel_linie; found_points(i,1), (found_points(i,2) - 0.375)];
            else

                points_right = [points_right; found_points(i,1), (found_points(i,2) + 0.375)];
                mittel_linie = [mittel_linie; found_points(i,1), (found_points(i,2) + 0.375)];
            end

        end
    
        if isempty(mittel_linie) == false
            avarg = mean(mittel_linie(:,2));
            min_line = min(mittel_linie(:,2));
            max_line = max(mittel_linie(:,2));
            mitte = mittel_linie(:,2);
            values = min_line:.005:max_line;
            figure(2);
            hist = histogram(mitte, values);
            hold on;
            
        end
        
        
        
        
        
        

        % Extrahiere die Bin-Anzahlen und Mitten aus dem Histogramm-Objekt
        anzahl = hist.Values;
        mitten = hist.BinEdges(1:end-1) + diff(hist.BinEdges)/2;
        % [anzahl, mitten] = histcounts(mittel_linie(:,2), values);
        
        % Finde den Bin mit der höchsten Anzahl
        [maxAnzahl, idx] = max(anzahl);
        maxBinMittelpunkt = mitten(idx);

        % Berechne die Begrenzungen des Intervalls
        intervalStart = maxBinMittelpunkt - intervall_Breite;
        intervalEnd = maxBinMittelpunkt + intervall_Breite;

        % Schneide die Daten auf das Intervall zu
        datenImIntervall = mittel_linie(mittel_linie >= intervalStart & mittel_linie <= intervalEnd);

        % Berechne den Mittelwert der Daten im Intervall
        offset_mitte = mean(datenImIntervall)
        patch([intervalStart intervalStart intervalEnd intervalEnd], [0 maxAnzahl maxAnzahl 0], 'r', 'FaceAlpha',0.3);
        hold off;
        
        %publish the distance of the robot to the mid 
        offsetMsg.Data = offset_mitte;
        send(pub_offset, offsetMsg);
    
        if offset_mitte < -lenk_toleranz
            vel_msg = rosmessage(robotCmd);
            vel_msg.Angular.Z = -kp + (offset_mitte*2);
            send(robotCmd,vel_msg);

        elseif offset_mitte > lenk_toleranz
            vel_msg = rosmessage(robotCmd);      
            vel_msg.Angular.Z = kp + (offset_mitte*2);
            send(robotCmd,vel_msg);   
        end
        
        
        
        
        left_points = found_points(found_points(:,2) >= 0,:);
        right_points = found_points(found_points(:,2) < 0,:);
        % Überprüfen Sie, ob links und rechts Punkte vorhanden sind
        if isempty(left_points) || isempty(right_points)
            continue;
        end

        % Finde den ersten Punkt und einen Punkt, der x_distance entfernt ist, auf beiden Seiten
        [~, left_first_idx] = min(left_points(:,1));
        [~, left_next_idx] = min(abs(left_points(:,1) - (left_points(left_first_idx,1) + x_distance)));

        [~, right_first_idx] = min(right_points(:,1));
        [~, right_next_idx] = min(abs(right_points(:,1) - (right_points(right_first_idx,1) + x_distance)));

        % Überprüfen Sie, ob die oberen Punkte über dem Roboter und die unteren Punkte unter dem Roboter sind
        if left_points(left_first_idx,2) < 0 || left_points(left_next_idx,2) < 0 || right_points(right_first_idx,2) > 0 || right_points(right_next_idx,2) > 0
            continue;
        end

        % Berechnen Sie die Mittelpunkte der beiden Linien, die durch die Punkte verlaufen
        mid_point1 = [(left_points(left_first_idx,1)+right_points(right_first_idx,1))/2, (left_points(left_first_idx,2)+right_points(right_first_idx,2))/2];
        mid_point2 = [(left_points(left_next_idx,1)+right_points(right_next_idx,1))/2, (left_points(left_next_idx,2)+right_points(right_next_idx,2))/2];

        figure(6);
        plot(found_points(:,1), found_points(:,2), 'k.');
        hold on;
        plot(left_points(left_first_idx, 1), left_points(left_first_idx, 2), 'ro', 'LineWidth', 2, 'MarkerSize', 10);
        plot(left_points(left_next_idx, 1), left_points(left_next_idx, 2), 'mo', 'LineWidth', 2, 'MarkerSize', 10);
        plot(right_points(right_first_idx, 1), right_points(right_first_idx, 2), 'ro', 'LineWidth', 2, 'MarkerSize', 10);
        plot(right_points(right_next_idx, 1), right_points(right_next_idx, 2), 'mo', 'LineWidth', 2, 'MarkerSize', 10);
        plot([mid_point1(1), mid_point2(1)], [mid_point1(2), mid_point2(2)], 'r-');
        hold off;   

        drawnow;
        
        
    
    end
        

end