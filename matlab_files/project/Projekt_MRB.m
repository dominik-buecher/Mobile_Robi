% Implementierung der ROS Subscriber und Puplisher
% Laser-Abonnement erstellen, um Daten von '/base_scan' zu empfangen
laser = rossubscriber('/base_scan');
robotPos = rossubscriber('/odom');

% Ein Publisher für das ROS-Thema '/cmd_vel' wird erstellt, um Geschwindigkeitsbefehle zu senden
cmd_vel = rospublisher('/cmd_vel', 'geometry_msgs/Twist');
vel_msg = rosmessage(cmd_vel);

% Ein Publisher für das ROS-Thema '/offset' wird erstellt, um den Abstand zur Reihenmitte zu veröffentlichen
pub_offset = rospublisher('/offset', 'std_msgs/Float64');
offsetMsg = rosmessage(pub_offset);

% Ein Publisher für das ROS-Thema '/alpha' wird erstellt, um die Orientierung zur Reihenmitte zu veröffentlichen
pub_alpha = rospublisher('/alpha', 'std_msgs/Float64');
alphaMsg = rosmessage(pub_alpha);

% Ein Publisher für das ROS-Thema '/inside_row' wird erstellt, um den Status "innerhalb der Reihe" zu veröffentlichen
inside_row = rospublisher('/inside_row', 'std_msgs/Bool');
insideRowMsg = rosmessage(inside_row);


% Deklaration der verwendeten Parameter
intervall_Breite = 0.065; % Breite des Intervalls
roi_view_x = 2.5; % X-Ansicht des ROI (Region of Interest)
roi_view_y = 0.8; % Y-Ansicht des ROI (Region of Interest)
turn_counter = 1; % Zählvariable für Drehungen
robot_speed = 0.5; % Roboter-Geschwindigkeit
values = 1:720; % Array mit Werten von 1 bis 720
k = 20; % Konstante 'k'
kp = 0.8; % Proportionaler Verstärkungsfaktor 'kp'
old_alpha = 0; % Vorherige Ausrichtung zur Mittellinie
lenk_toleranz = 0.055; % Toleranz für die Lenkung

mittel_linie = []; % Array für die Mittellinie
alpha_array = []; % Array für die Ausrichtungen zur Mittellinie



while true
    
    % Empfangen der Laserscan-Daten mit einer Wartezeit von 10 Sekunden
    scandata = receive(laser,10);
    % Extrahieren der Entfernungsdaten aus den Scandaten
    ranges = scandata.Ranges;
    
    % Setzen der linearen Geschwindigkeit auf robot_speed
    vel_msg.Linear.X = robot_speed;
    % Setzen der Winkelgeschwindigkeit auf 0
    vel_msg.Angular.Z = 0;
    
    % Senden der Geschwindigkeitsnachricht über den cmd_vel-Publisher
    send(cmd_vel,vel_msg); 


    % Überprüfen ob sich der Roboter außerhalb einer Pflanzenreihe befindet
    if min(ranges)>2
        
        insideRowMsg.Data = false; % Setze insideRowMsg auf 'false'
        send(inside_row, insideRowMsg); % Senden der insideRowMsg-Nachricht über den inside_row-Publisher
        
        % Überprüfung, ob turn_counter gerade ist
        if mod(turn_counter, 2) == 0 
            direction = -1; % Wenn gerade, dann setze die Richtung auf -1 (gegen den Uhrzeigersinn)
        else
            direction = 1; % Sonst setze die Richtung auf 1 (im Uhrzeigersinn)
        end 

        distance = 0.5; % Entfernung für die gerade Strecke
        velocity = 0.5; % Geschwindigkeit für die gerade Strecke
        radius = 0.4; % Radius für die Kurve
        linearSpeed = velocity; % Lineare Geschwindigkeit für die Kurve
        angularSpeed = velocity/radius; % Winkelgeschwindigkeit für die Kurve
        durationStraight = distance/ linearSpeed; % Dauer für die gerade Strecke (basierend auf Geschwindigkeit und Entfernung)

        vel_msg.Angular.Z = 0; % Setzen der Winkelgeschwindigkeit auf 0 (keine Rotation)
        sendTime = rostime('now'); % Aktuelle Zeit speichern
    
        % Schleife für die gerade Strecke, die basierend auf der Dauer ausgeführt wird
        while (rostime('now') - sendTime < durationStraight) 
            send(cmd_vel, vel_msg); % Senden der Geschwindigkeitsnachricht über den cmd_vel-Publisher
        end 

        durationCurve = pi/angularSpeed; % Dauer für die Kurve (basierend auf Winkelgeschwindigkeit)
        vel_msg.Linear.X = linearSpeed; % Setzen der linearen Geschwindigkeit auf linearSpeed
        vel_msg.Angular.Z = direction * angularSpeed; % Setzen der Winkelgeschwindigkeit auf direction * angularSpeed (im oder gegen den Uhrzeigersinn)
        sendTime = rostime('now'); % Aktuelle Zeit speichern
        
        % Schleife für die Kurve, die basierend auf der Dauer ausgeführt wird (mit einer kleinen Toleranz von 0.15s)
        while (rostime('now') - sendTime < durationCurve - 0.15) 
            send(cmd_vel, vel_msg); % Senden der Geschwindigkeitsnachricht über den cmd_vel-Publisher
        end

        turn_counter = turn_counter + 1; % Inkrementieren des turn_counter um 1 (Vorbereitung für die nächste Drehung)

    % Überprüfen ob sich der Roboter innerhalb einer Pflanzenreihe befindet    
    elseif min(ranges) < 2
        
        insideRowMsg.Data = true; % Setze insideRowMsg auf den Wert 'true'
        send(inside_row, insideRowMsg); % Senden der insideRowMsg-Nachricht über den inside_row-Publisher

        xy = readCartesian(scandata); % Umwandeln der Laserscan-Daten in kartesische Koordinaten

        roi = (xy(:,1) > 0 & xy(:,1) < roi_view_x) & (abs(xy(:,2)) < roi_view_y); % Erstellen einer Region of Interest (ROI) basierend auf den X- und Y-Grenzen
        found_points = xy(roi,:); % Extrahieren der Punkte, die innerhalb der ROI gefunden wurden
        
        % Überprüfung, ob der minimale Wert in 'ranges' kleiner als 0.2 ist
        if min(ranges) < 0.2 
            vel_msg.Linear.X = 0; % Setzen der linearen Geschwindigkeit auf 0 (Stoppen des Roboters)
            send(cmd_vel,vel_msg); % Senden der Geschwindigkeitsnachricht über den cmd_vel-Publisher
        end

        
        alpha = alphahist(found_points, old_alpha, k); % Berechnen des Alpha-Werts basierend auf den gefundenen Punkten, dem vorherigen Alpha-Wert und der Konstanten k
        old_alpha = alpha; % Aktualisieren des vorherigen Alpha-Werts mit dem aktuellen Alpha-Wert

        alphaMsg.Data = alpha; % Setze alphaMsg auf den aktuellen Alpha-Wert
        send(pub_alpha, alphaMsg); % Senden der alphaMsg-Nachricht über den pub_alpha-Publisher

        left_points_mask = found_points(:,2) > 0; % Erstellen einer Maske für die Punkte auf der linken Seite (y > 0)
        mittel_linie = [found_points(:,1), found_points(:,2) - 0.375 * left_points_mask + 0.375 * ~left_points_mask]; % Erzeugen der Mittellinie basierend auf den gefundenen Punkten und der Maske

        
        % Überprüfung, ob mittel_linie nicht leer ist
        if isempty(mittel_linie) == false 
            min_line = min(mittel_linie(:,2)); % Berechnen des minimalen Y-Werts in mittel_linie
            max_line = max(mittel_linie(:,2)); % Berechnen des maximalen Y-Werts in mittel_linie
            mitte = mittel_linie(:,2); % Extrahieren der Y-Werte aus mittel_linie
            values = min_line:.005:max_line; % Erzeugen einer Wertebereichsliste von min_line bis max_line mit Schrittweite 0.005
            
            % Überprüfung, ob die Anzahl der Werte in values mindestens 2 beträgt
            if numel(values) >= 2 
                figure(3); 
                hist = histogram(mitte, values); % Erstellen des Histogramms basierend auf den Werten in mitte und values
                hold on; 
            end
        end

        anzahl = hist.Values; % Extrahieren der Anzahl der Datenpunkte in jedem Bins des Histogramms
        mitten = hist.BinEdges(1:end-1) + diff(hist.BinEdges)/2; % Berechnen der Mittelpunkte der Bins basierend auf den Bin-Kanten
        [maxAnzahl, idx] = max(anzahl); % Finden des maximalen Werts und des entsprechenden Index in anzahl
        maxBinMittelpunkt = mitten(idx); % Extrahieren des Mittelpunkts des Bins mit der maximalen Anzahl
        intervalStart = maxBinMittelpunkt - intervall_Breite; % Berechnen des Startwerts des Intervalls basierend auf dem Mittelpunkt und der Breite
        intervalEnd = maxBinMittelpunkt + intervall_Breite; % Berechnen des Endwerts des Intervalls basierend auf dem Mittelpunkt und der Breite
        datenImIntervall = mittel_linie(mittel_linie >= intervalStart & mittel_linie <= intervalEnd); % Extrahieren der Datenpunkte in mittel_linie, die innerhalb des Intervalls liegen
        offset_mitte_laser = mean(datenImIntervall); % Berechnen des Durchschnitts der Datenpunkte im Intervall

        patch([intervalStart intervalStart intervalEnd intervalEnd], [0 maxAnzahl maxAnzahl 0], 'r', 'FaceAlpha',0.3);
        hold off; 

        offsetMsg.Data = offset_mitte_laser; % Setze offsetMsg auf den berechneten Offset
        send(pub_offset, offsetMsg); % Senden der offsetMsg-Nachricht über den pub_offset-Publisher
        
        
        % Überprüfung, ob der Offset kleiner als die negative Lenktoleranz ist
        if offset_mitte_laser < -lenk_toleranz 
            vel_msg.Linear.X = 0; % Setzen der linearen Geschwindigkeit auf 0, um anzuhalten
            vel_msg.Angular.Z = -kp; % Setzen der Winkelgeschwindigkeit auf den negativen Proportionalitätsfaktor kp, um nach links zu lenken
            send(cmd_vel,vel_msg); % Senden der vel_msg-Nachricht über den cmd_vel-Publisher

            % Überprüfung, ob der Offset größer als die Lenktoleranz ist
        elseif offset_mitte_laser > lenk_toleranz 
            vel_msg.Linear.X = 0; % Setzen der linearen Geschwindigkeit auf 0, um anzuhalten
            vel_msg.Angular.Z = kp; % Setzen der Winkelgeschwindigkeit auf den positiven Proportionalitätsfaktor kp, um nach rechts zu lenken
            send(cmd_vel,vel_msg); % Senden der vel_msg-Nachricht über den cmd_vel-Publisher
        end
        
        
        %%%
        % Visualisierung der Mittellinie zwischen den gefundenen Punkten (Dient nur zu visuellen Zwecken)
        left_points = found_points(found_points(:,2) >= 0,:); % Extrahieren der Punkte auf der linken Seite, deren y-Koordinate größer oder gleich 0 ist
        right_points = found_points(found_points(:,2) < 0,:); % Extrahieren der Punkte auf der rechten Seite, deren y-Koordinate kleiner als 0 ist
        
        % Überprüfen, ob entweder die linken oder rechten Punkte leer sind
        if isempty(left_points) || isempty(right_points)
            continue; % Fortsetzen der Schleife, um den nächsten Durchlauf zu starten
        end

        [~, left_first_idx] = min(left_points(:,1)); % Finden des Index des Punkts auf der linken Seite mit der kleinsten x-Koordinate
        [~, left_next_idx] = min(abs(left_points(:,1) - (left_points(left_first_idx,1) + 0.5))); % Finden des Index des Punkts auf der linken Seite, der 0,5 Einheiten rechts vom ersten Punkt liegt
        [~, right_first_idx] = min(right_points(:,1)); % Finden des Index des Punkts auf der rechten Seite mit der kleinsten x-Koordinate
        [~, right_next_idx] = min(abs(right_points(:,1) - (right_points(right_first_idx,1) + 0.5))); % Finden des Index des Punkts auf der rechten Seite, der 0,5 Einheiten rechts vom ersten Punkt liegt

        if left_points(left_first_idx,2) < 0 || left_points(left_next_idx,2) < 0 || right_points(right_first_idx,2) > 0 || right_points(right_next_idx,2) > 0
            continue; % Fortsetzen der Schleife, wenn die Bedingung nicht erfüllt ist
        end
        
        % Berechnen des Mittelpunkts zwischen dem ersten Punkt auf der linken Seite und dem ersten Punkt auf der rechten Seite
        mid_point1 = [(left_points(left_first_idx,1)+right_points(right_first_idx,1))/2, (left_points(left_first_idx,2)+right_points(right_first_idx,2))/2]; 
        % Berechnen des Mittelpunkts zwischen dem nächsten Punkt auf der linken Seite und dem nächsten Punkt auf der rechten Seite
        mid_point2 = [(left_points(left_next_idx,1)+right_points(right_next_idx,1))/2, (left_points(left_next_idx,2)+right_points(right_next_idx,2))/2]; 

        figure(1);
        plot(found_points(:,1), found_points(:,2), 'k.');
        hold on;
        plot(left_points(left_first_idx, 1), left_points(left_first_idx, 2), 'ro', 'LineWidth', 2, 'MarkerSize', 10);
        plot(left_points(left_next_idx, 1), left_points(left_next_idx, 2), 'mo', 'LineWidth', 2, 'MarkerSize', 10);
        plot(right_points(right_first_idx, 1), right_points(right_first_idx, 2), 'ro', 'LineWidth', 2, 'MarkerSize', 10);
        plot(right_points(right_next_idx, 1), right_points(right_next_idx, 2), 'mo', 'LineWidth', 2, 'MarkerSize', 10);
        plot([mid_point1(1), mid_point2(1)], [mid_point1(2), mid_point2(2)], 'r-');
        hold off;
        %%%      
    end
end