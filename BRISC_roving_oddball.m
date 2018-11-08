function BRISC_roving_oddball (Participant_ID, sex, block_number)
%
% Inputs:
%   Participant_ID: number of participant, eg 1,2,3..n
%   sex: sex/gender of participant; 'string' in format 'm' for boys (male) or 'f' for girls (female)
%   block_number: the consecutive block/run for this participant, 1,2,3...
%


%% Housekeeping
clc;
clear;
close all;

% Assign default variables, if not entered:
if nargin < 3 || isempty (block_number), block_number = 1; end

if nargin < 2 || isempty (sex), sex = 'm'; end

if nargin < 1 || isempty (Participant_ID), Participant_ID = 1; end



%% Set Up Structures Used in Experiment
Par = struct(); % For experimental parameters
Res = struct(); % For results
Port = struct();% Pertaining to the serial port, for sending triggers.
Switch = struct(); % For experimental control



%% Experiment Parameters

% Trial Parameters
Par.nTonesPerBlock = 528; % Number of tones presented in a block
Par.Timing.SOA_Duration_Sec = 0.5; % SOA between consecutive tones in seconds

% Duration required for sending event codes
Par.Timing.EventCodeDuration = 0.004;

% --- Auditory Tone Parameters ---

% We'll use matlab's sound player function for an auditory cue of 50 ms
Par.Disp.ToneDuration = 0.2;                                      % Duration of the tones (including ramp up/down periods)
Par.Disp.AudioSampleRateHz = 48000;                               % This is the default for this machine
Par.Disp.AudioBitDepth = 24;                                      % Bits per sample: defauly bit depth for this machine
Par.Disp.AudioToneFreqHz = [100:100:1000,1200:200:5000];          % Frequency of the sine wave we want to play

% Durations of each phase of the tone
rampUpDuration = 0.01; % Duration of ramp-up period in seconds
rampDownDuration = 0.01; % Duration of ramp-down period in seconds
fullVolDuration = 0.18; % Duration of full-volume period of the tone



% SERIAL PORT
Port.InUse = true;         % set to true if sending triggers over serial port
Port.COMport = 'COM4';     % the COM port for the trigger box: should not change on this PC
Port.EventTriggerDuration = 0.004; % Duration, in sec, of trigger; delay before the port is flushed and set back to zero


% Just check the sex of participant has been entered using format
% 'm' for males or 'f' for females
if strcmp(sex, 'm') || strcmp(sex, 'f')
    %that's correct, so do nothing
elseif strcmp(sex, 'M')
    sex = 'm';
elseif strcmp(sex, 'F')
    sex = 'f';
else
    %any other combination will be wrong!
    error ('Please enter sex of participant as ''m'' for boys (male) or ''f'' for girls (female)')
end

% Set aside unique details of this participant/block
Res.ParticipantInfo.ID = Participant_ID;
Res.ParticipantInfo.GenderSex = sex;
Res.BlockNumber = block_number;

% Work out a unique file name for this run.
% Get a date/time string for this file:
dateString = datestr(now);
dateString(dateString == ' ') =  '_';
dateString(dateString == '-') =  '_';
dateString(dateString == ':') =  '_';
%Set aside information
Res.ExperimentName = 'BRISC_oddball';

% Unique file name for the data to be saved as, and full path for results storage:
Res.FileName = fullfile('C:\Users\BRISC\Documents\dlab-BRISC_EEG', ...
    'data', ['P', num2str(Participant_ID), '_', ...  %P for participant
    sex, '_', Res.ExperimentName, ...
    ['_' , dateString, '_'] ...
    num2str( block_number ), ...                     % Final value is block number
    '.mat']);

% Just abort if the file already exists
% (this should never be needed, but just in case):
if exist(Res.FileName,'file')
    userResponse = input('WARNING: Run file exists. Overwrite? Enter y or n: ','s');
    if ~strcmp( userResponse, 'y' )
        error('Aborting function! File exists!');
    end
end

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
RespQuit = KbName('escape'); % Hit 'Esq' to quit/abort program.



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
    
    
    % Trigger numbers 101-130 denotes the different tone frequencies
    Port.EventCodes.toneFreqs = 111:140;

    % Trigger numbers 201-236 denote the number of repetitions of the tone
    Port.EventCodes.repetitionNumbers = 201:236;
    
    
    
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
% A tone is randomly-selected, and then this repeats 2, 6 or 36 times.

toneOrder = 1:30; % 30 separate tones

toneOrder = Shuffle(toneOrder); % Randomly order

% Append some extra tones onto the end to fill out the block
toneOrder2 = Shuffle(toneOrder); % Randomly order

toneOrder_fullBlock = [toneOrder, toneOrder2];

% Copy to Par structure
Par.toneOrder = toneOrder_fullBlock(1:36);

% Numbers of tone repetitions in a single train
nToneReps = [2, 6, 36];
nToneRepSets = 12;

% Generate a vector of numbers of times each tone repeats
Par.toneRepetitions = repmat(nToneReps, 1, nToneRepSets, 1);
Par.toneRepetitions = Shuffle(Par.toneRepetitions);

% 528 stimuli in a block 
% One set of 2 + 6 + 36 repetitions = 44 tones -> * 12 = 528 tones per
% block

Par.toneForEachTrial = repmat(Par.toneOrder(1), 1, Par.toneRepetitions(1));

for toneSet = 2:length(Par.toneRepetitions)
    
    Par.toneForEachTrial(end + 1 : end + Par.toneRepetitions(toneSet)) = repmat(Par.toneOrder(toneSet), 1, Par.toneRepetitions(toneSet));
    
end % of for toneSet




%% Save all parameters and details so far:
% save(Res.FileName, 'Par', 'Res', 'Switch', 'Port')


%% Wait Before Block

WaitSecs(3);


%% Present Auditory Stimuli in the Block

% Reset counter variable denoting number of tone repetitions
nReps = 1;

Res.Timing.toneOnset(1) = GetSecs;

for trial = 1:Par.nTonesPerBlock
    
    %% - Get relevant trial information (tone frequency, trigger number etc)
    
    toneThisTrial = Par.toneForEachTrial(trial);
    
    % Check for tone repetitions
    if trial > 1 && toneThisTrial == Par.toneForEachTrial(trial - 1) % If repeated tone
    
        nReps = nReps + 1;
        
    elseif trial > 1 && toneThisTrial ~= Par.toneForEachTrial(trial - 1) % If changed tone
    
        nReps = 1;
        
    end % of if toneThisTrial

    
    
    %% - Send triggers
    
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
                    
%     % Waits for SOA duration to elapse before playing tone
%     while GetSecs < Res.Timing.toneOnset(trial) + Par.Timing.SOA_Duration_Sec - Par.Timing.EventCodeDuration
%     
%     end % of while GetSecs
    
    % Trigger denoting the tone presented in the current trial
    send_event_trigger(Port.sObj, Port.EventTriggerDuration, ...
                        Port.EventCodes.toneFreqs(toneThisTrial)); 
                    
    
    %% - Play tone    
    
    % Mark the time before tone onset
    Res.Timing.toneOnset(trial) = GetSecs;
    
    % Play the tone
    sound( Par.Disp.AudioCueVolRamp .* Par.Disp.AudioCueWave(toneThisTrial, :), ...
        Par.Disp.AudioSampleRateHz, ...
        Par.Disp.AudioBitDepth);
    
    
    
    %% - Wait during the ISI
    % Waits for SOA duration minus event trigger duration (to account for time it takes to send a trigger)
    while GetSecs < Res.Timing.toneOnset(trial) + Par.Timing.SOA_Duration_Sec - 0.1;
    
    
    end % of while GetSecs
    
end % of for trial








%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function send_event_trigger(serial_object, trigger_duration, event_code)
% Send a trigger over the serial port, as defined in 'event_code'
% There is an imposed delay (duration) of 'trigger_duration' seconds
% and then the port is flushed again with zero, ready for next use.

fwrite(serial_object, event_code);
WaitSecs(trigger_duration);
fwrite(serial_object, 0);

end


end % of function

