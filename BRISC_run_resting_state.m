% BRISC_bubbles
% (BRISC_run_resting_state)
% Display resting state 'bubbles' stimulus, and send triggers.
% Should be run for approximately 2 minutes.
% GarboriumDemo_RM.m is run; a colour modification of the popular PTB function GarboriumDemo.



clc
clear;
close all;

%% Set Up Structures Used in Experiment
Port = struct();% Pertaining to the serial port, for sending triggers.

% SERIAL PORT
Port.InUse = true;         % set to true if sending triggers over serial port
Port.COMport = 'COM4';     % the COM port for the trigger box: should not change on this PC
Port.EventTriggerDuration = 0.004; % Duration, in sec, of trigger; delay before the port is flushed and set back to zero

% Just do quick warning if triggers are switched OFF:
if ~Port.InUse
    userResponse = input('WARNING: Serial port is OFF. No triggers will be sent. Continue? Enter y or n: ','s');
    if strcmp( userResponse, 'n' )
        error('Aborting function!');
    end
end

%% Open the serial device for triggers (if using)
if Port.InUse
    Port.sObj = serial(Port.COMport);
    fopen(Port.sObj);
    
    % Send a dummy pulse to initialise the device:
    send_event_trigger(Port.sObj, Port.EventTriggerDuration, 255)
else
    Port.sObj = []; % Just use an empty object if we're not using the port
end

send_event_trigger(Port.sObj, Port.EventTriggerDuration, 100)

GarboriumDemo_RM (350) ; % Display colour modified version of GarboriumDemo

% Close the serial port:
fclose(Port.sObj);
% Get rid of whole struct:
clear('Port')

%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function send_event_trigger(serial_object, trigger_duration, event_code)
% Send a trigger over the serial port, as defined in 'event_code'
% There is an imposed delay (duration) of 'trigger_duration' seconds
% and then the port is flushed again with zero, ready for next use.

fwrite(serial_object, event_code);
WaitSecs(trigger_duration);
fwrite(serial_object, 0);

end
