function BRISC_sound
%
% Inputs (requested):
%   Participant_ID: the unique ID code for this participant, as a 'string'
%       in the format '1M0001'
%       First digit will be 1-3,
%       2nd character is M for boys (male, M) or F for girls (female, F)
%       then 4-digit unique number
%   subgroupCode: 'M' for Midline, 'E' for endline (or 'B' for baseline), as a 'string'
%   block_number: the consecutive block/run for this experiment and this participant, 1,2,3...
%
% Auditory oddball task
%% Housekeeping
clc;
clear;
close all;

% Request input of variables:
Participant_ID = input('\n Please enter the unique 6-character participant ID/code, eg. ''1F0001'': ');
stageCode = input('\n Please enter the trial stage code, eg. ''M'' or ''E'': ');
block_number = input('\n Please enter experiment run/block number: ');

% If the Participant ID seems wrong, request again:
if length(Participant_ID) ~= 6
    fprintf('\n Participant ID/code incorrect format.')
    Participant_ID = input('\n Please enter the unique 6-character participant ID/code, eg. ''1F0001'': ');
    stageCode = input('\n Please enter the trial stage code, eg. ''M'' or ''E'': ');
    block_number = input('\n Please enter experiment run/block number: ');
end


%% Set Up Structures Used in Experiment
Par = struct(); % For experimental parameters
Res = struct(); % For results
Port = struct();% Pertaining to the serial port, for sending triggers.
%Switch = struct(); % For experimental control

%% Experiment Parameters

% Set aside unique details of this participant/block
Res.ParticipantInfo.ID = Participant_ID;
Res.ParticipantInfo.GenderSex = Participant_ID(2);
Res.ParticipantInfo.TrailStageCode = stageCode;
Res.BlockNumber = block_number;

% Work out a unique file name for this run.
% Get a date/time string for this file:
dateString = datestr(now);
dateString(dateString == ' ') =  '_';
dateString(dateString == '-') =  '_';
dateString(dateString == ':') =  '_';
%Set aside information
Res.ExperimentName = 'BRISC_sound';

% Print information:
fprintf('\nRunning %s experiment. Press ''Esc'' to exit. \n', Res.ExperimentName)

% Unique file name for the data to be saved as, and full path for results storage:
Res.FileName = fullfile('C:\Users\BRISC\Documents\dlab-BRISC_EEG', ... % Full path for data file
    'data', [Participant_ID, '_', ...  % Unique participant code
    stageCode, '_', ...                % The stage of the trial (M for midline or E for endline).
    Res.ExperimentName, ...
    '_',  num2str( block_number ), ... % Current block
    '_' , dateString ...
    '.mat']);

% Just abort if the file already exists
% (this should never be needed, but just in case):
if exist(Res.FileName,'file')
    userResponse = input('\n WARNING: Run file exists. Overwrite? Enter y or n: ','s');
    if ~strcmp( userResponse, 'y' )
        error('Aborting function! File exists!');
    end
end

% SERIAL PORT
Port.InUse = false;         % set to true if sending triggers over serial port
Port.COMport = 'COM4';     % the COM port for the trigger box: should not change on this PC
Port.EventTriggerDuration = 0.004; % Duration, in sec, of trigger; delay before the port is flushed and set back to zero

% Just do quick warning if triggers are switched OFF:
if ~Port.InUse
    userResponse = input('\n WARNING: Serial port is OFF. No triggers will be sent. Continue? Enter y or n: ','s');
    if strcmp( userResponse, 'n' )
        error('Aborting function!');
    end
end
%% - Stimulus parameters

% Trial Parameters
Par.nTonesPerBlock = 588; % Total Number of tones presented in a block
Par.Timing.SOA_Duration_Sec = 0.5; % SOA between consecutive tones in seconds

% Duration required for sending event codes
Par.Timing.EventCodeDuration = 0.004;

% --- Auditory Tone Parameters ---

% We'll use matlab's sound player function for an auditory cue of 50 ms
Par.Disp.ToneDuration = 0.2;                                      % Duration of the tones (including ramp up/down periods)
Par.Disp.AudioSampleRateHz = 48000;                               % This is the default for this machine
Par.Disp.AudioBitDepth = 24;                                      % Bits per sample: defauly bit depth for this machine
Par.Disp.AudioToneFreqHz = [100:100:1000,1200:200:5000];          % Frequency of the sine wave we want to play
Par.Disp.NumUniqueToneFreq = length(Par.Disp.AudioToneFreqHz);

% Durations of each phase of the tone
rampUpDuration = 0.01; % Duration of ramp-up period in seconds
rampDownDuration = 0.01; % Duration of ramp-down period in seconds
fullVolDuration = 0.18; % Duration of full-volume period of the tone

%% - Hardware
% Query the machine we're running:
[~, Par.ComputerName] = system('hostname');
Par.ComputerType = computer;
% Store the version of Windows:
[~, Par.WindowsVersion] = system('ver');
% Store the version of Matlab we're running:
Par.MatlabVersion = version;

% Unify the keyboard names in case we run this on a mac:
KbName('UnifyKeyNames')
% Define escape key:
RespQuit = KbName('escape'); % Hit 'Esc' to quit/abort program.


%% Open the serial device for triggers (if using)
if Port.InUse
    Port.sObj = serial(Port.COMport);
    fopen(Port.sObj);
    
    % Send a dummy pulse to initialise the device:
    send_event_trigger(Port.sObj, Port.EventTriggerDuration, 255)
else
    Port.sObj = []; % Just use an empty object if we're not using the port
end

%% Define the event code triggers
if Port.InUse
    
    % Trigger numbers 111-140 denotes the 30 different tone frequencies
    Port.EventCodes.toneFreqs = 111:140;
    
    % Trigger numbers 201-210 denote the number of repetitions of the tone
    Port.EventCodes.repetitionNumbers = 201:210;
    
end % of if Port.InUse



%% Set up the auditory tones:

for toneNo = 1:length(Par.Disp.AudioToneFreqHz)
    
    Par.Disp.AudioCueWave(toneNo, :) = sin(2 * pi * Par.Disp.AudioToneFreqHz(toneNo) * ...
        (1 / Par.Disp.AudioSampleRateHz: 1 / Par.Disp.AudioSampleRateHz : Par.Disp.ToneDuration));
    
end % of for toneNo

% Make the volume ramp for the sound, 100 ms over start/finish, so there are no harsh auditory onsets:
Par.Disp.AudioCueVolRamp = [linspace(0,1, Par.Disp.AudioSampleRateHz * rampUpDuration), ...
    ones(1, Par.Disp.AudioSampleRateHz * fullVolDuration), linspace(1, 0, Par.Disp.AudioSampleRateHz * rampDownDuration)];

% Play the sound once to preload the function
sound( Par.Disp.AudioCueVolRamp .* Par.Disp.AudioCueWave(4, :), Par.Disp.AudioSampleRateHz, Par.Disp.AudioBitDepth);



%% Generate the sequence of tones within the block
% A tone is randomly-selected, and then this repeats 4,5,6,7,8,9 or 10 times.

toneOrder = []; % 30 separate tones

% Numbers of tone repetitions in a single train
nToneReps = 4:10; % Following Garrido et al 2008
nToneRepSets = Par.nTonesPerBlock / sum(nToneReps) ; % Should be 12

%Randomly order the set of unique tones, such that each is repeated in the set before
% moving on to the next set
for ii = 1: nToneRepSets
    
    toneOrder = [toneOrder, randperm(Par.Disp.NumUniqueToneFreq)];
end

%toneOrder = randperm(toneOrder(end)); % Randomly order
% Append some extra tones onto the end to fill out the block
%toneOrder2 = randperm(toneOrder(end)); % Randomly order
%toneOrder_fullBlock = [toneOrder, toneOrder2];

% Copy to Par structure
%Par.toneOrder = toneOrder_fullBlock(1:36);
Par.toneOrder = toneOrder;


% Generate a vector of numbers of times each tone repeats
Par.toneRepetitions = repmat(nToneReps, 1, nToneRepSets, 1);
Par.toneRepetitions = Par.toneRepetitions(randperm(length(Par.toneRepetitions)));

% 588 stimuli in a block
% One set of sum(4:10) repetitions = 49 tones -> * 12 = 588 tones per
% block

Par.toneForEachTrial = repmat(Par.toneOrder(1), 1, Par.toneRepetitions(1));

for toneSet = 2:length(Par.toneRepetitions)
    
    Par.toneForEachTrial(end + 1 : end + Par.toneRepetitions(toneSet)) = repmat(Par.toneOrder(toneSet), 1, Par.toneRepetitions(toneSet));
    
end % of for toneSet


%% Save all parameters and details so far:
save(Res.FileName, 'Par', 'Res', 'Port')


%% Wait Before Block

WaitSecs(3);


%% Present Auditory Stimuli in the Block

% Reset counter variable denoting number of tone repetitions
nReps = 1;

Res.Timing.toneOnset(1) = GetSecs; % Initialise 'GetSecs'

ForcedQuit = false;

%% Loop across all trials:
for trial = 1:Par.nTonesPerBlock
    
    % - Get relevant trial information (tone frequency, trigger number etc)
    
    toneThisTrial = Par.toneForEachTrial(trial);
    
    % Check for tone repetitions
    if trial > 1 && toneThisTrial == Par.toneForEachTrial(trial - 1) % If repeated tone
        
        nReps = nReps + 1;
        
    elseif trial > 1 && toneThisTrial ~= Par.toneForEachTrial(trial - 1) % If changed tone
        
        nReps = 1; % Reset n reps for this tone
        
    end % of if toneThisTrial
    
    
    
    %% - Send triggers
    
    if Port.InUse
        % Trigger Denoting Block Number
        send_event_trigger(Port.sObj, Port.EventTriggerDuration, ...
            block_number);
        
        
        % Wait a litle bit before sending the code
        WaitSecs(0.01);
        
        % Get hundreds and tens + ones counters for trial number
        trial_hundredsCounter = floor(trial / 100);
        trial_tensCounter = rem(trial, 100);
        
        % Trigger Denoting Trial Number (2 triggers for this)
        % Denoting hundreds first
        send_event_trigger(Port.sObj, Port.EventTriggerDuration, ...
            trial_hundredsCounter + 1);
        
        % Wait a litle bit before sending the code
        WaitSecs(0.01);
        
        % Then denoting tens + ones
        send_event_trigger(Port.sObj, Port.EventTriggerDuration, ...
            trial_tensCounter + 1);
        
        % Wait a litle bit before sending the code
        WaitSecs(0.01);
        
        % Trigger denoting the repetition number of the tone
        send_event_trigger(Port.sObj, Port.EventTriggerDuration, ...
            Port.EventCodes.repetitionNumbers(nReps));
        
        % Waits for SOA duration to elapse before playing tone
        while GetSecs < Res.Timing.toneOnset(trial) + Par.Timing.SOA_Duration_Sec - Par.Timing.EventCodeDuration

        end % of while GetSecs
        
        % Trigger denoting the tone presented in the current trial
        send_event_trigger(Port.sObj, Port.EventTriggerDuration, ...
            Port.EventCodes.toneFreqs(toneThisTrial));
        
    end
    
    %% - Play tone
    
    % Mark the time before tone onset and store in results struct
    Res.Timing.toneOnset(trial) = GetSecs;
    
    % Play the tone
    sound( Par.Disp.AudioCueVolRamp .* Par.Disp.AudioCueWave(toneThisTrial, :), ...
        Par.Disp.AudioSampleRateHz, ...
        Par.Disp.AudioBitDepth);
    
    
    
    %% - Wait during the ISI
    
    % Save data here:
    save(Res.FileName, 'Par', 'Res', 'Port')
    
    % Waits for SOA duration minus event trigger duration (to account for time it takes to send a trigger)
    while GetSecs < Res.Timing.toneOnset(trial) + Par.Timing.SOA_Duration_Sec - 0.1
        
        % Here, we can check for 'esc' button presses to abort:
        [KeyIsDown, ~, keyCode] = KbCheck();
        if KeyIsDown % a key has been pressed
            if keyCode(RespQuit)
                ForcedQuit = true
                ExitGracefully(ForcedQuit, Port.sObj)
            end
        end
        
        
    end % of while GetSecs
    
end % of for trial

% One final save of data:
save(Res.FileName, 'Par', 'Res', 'Port')

end % of function

%% Sub-functions follow..
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ExitGracefully (ForcedQuit, serial_object)
%...need to shut everything down here...

% Close down the serial port (if used)
if ~isempty(serial_object)
    fclose(serial_object);
end

% announce to cmd window if the program was aborted by the user
if ForcedQuit
    error('You quit the program!')
end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function send_event_trigger(serial_object, trigger_duration, event_code)
% Send a trigger over the serial port, as defined in 'event_code'
% There is an imposed delay (duration) of 'trigger_duration' seconds
% and then the port is flushed again with zero, ready for next use.

fwrite(serial_object, event_code);
WaitSecs(trigger_duration);
fwrite(serial_object, 0);

end
