
% BRISC_run_attention_experiment
% To do;
% - decide on method of flicker position counterbalancng (blocks or individual babies)?
% - what subject info needs to be entered/stored (code,number?)
% - arrange randomisation control for different trial types
% - serial port calls, including closing it down when exiting/quitting.
% - do we use desired or corrected trial duration in control of trial stim? (cf Daniel)

%% Housekeeping
clc;
clear all;
close all;

%% Set Up Structures Used in Experiment
Par = struct(); % For experimental parameters
Res = struct(); % For results
Port = struct();% Pertaining to the serial port, for sending triggers.
Switch = struct(); % For experimental control

Switch.DrawMovies = false; % set to true or false to determine movie playback:

% Query the machine we're running:
[~, Par.ComputerName] = system('hostname');
Par.ComputerType = computer;
% Store the version of Windows:
[~, Par.WindowsVersion] = system('ver');
% Store the version of Matlab we're running:
Par.MatlabVersion = version;

% Define escape key:
% Unify the keyboard names in case we run this on a mac:
KbName('UnifyKeyNames')
RespQuit = KbName('escape'); % Hit 'Esq' to quit/abort program.

%%
if Switch.DrawMovies
    % Generate a cell array of strings providing the full paths of each of the 9 movie files.
    % All of the Wiggles movies listed here have the same resolution: 720 (h) * 1280 (w)
    Par.Disp.video_dir = 'C:\Users\BRISC\Videos';                    % The movie file directory
    Par.Disp.MoviePaths = {'The Wiggles - Romp Bomp A Stomp.mp4', ...    % Each of the movie file names
        'The Wiggles- Do The Pretzel (Official Video).mp4', ...
        'The Wiggles- Do The Propeller! (Official Video).mp4', ...
        'The Wiggles- Do the Skeleton Scat (Official Video).mp4', ...
        'The Wiggles- I''ve Got My Glasses On (Official Video).mp4', ...
        'The Wiggles- Ooey, Ooey, Ooey Allergies.mp4', ...
        'The Wiggles- Say the Dance, Do the Dance (Official Video).mp4', ...
        'The Wiggles- There Are So Many Animals (Official Video).mp4', ...
        'The Wiggles- Who''s In The Wiggle House- (Official Video).mp4'};
    % Insert the full directory into each file path
    Par.Disp.MoviePaths = cellfun(@(x) fullfile(Par.Disp.video_dir, x), Par.Disp.MoviePaths, 'UniformOutput', false);
    
    % Extract and set aside details of each of the movies:
    for v=1:length(Par.Disp.MoviePaths)
        Par.Disp.MovieDetails{v} = VideoReader(Par.Disp.MoviePaths{v});
    end
    
    Par.Disp.NumMovieFiles = length(Par.Disp.MovieDetails); % Store the number of available movie files.
    ReduceMovieResBy = 1/3; % How much do we want to reduce the size of the movies by when drawn?
end

%% Screen Initialisation
try % Enclose in a try/catch statement, in case something goes awry with the PTB functions
    
    %%
    %Shut down any lingering screens, in case they are open:
    Screen('CloseAll');
    
    AssertOpenGL;
    % Determine the max screen number, to display stimuli on.
    % We will only be using 1 screen, so this should = 0.
    Par.Disp.screenid = max(Screen('Screens'));
    % Define background (mean luminance grey):
    Par.Disp.backgroundColour_RGB = 128;
    
    % Open onscreen window: We request a 32 bit per colour component
    % floating point framebuffer if it supports alpha-blendig. Otherwise
    % the system shall fall back to a 16 bit per colour component framebuffer:
    PsychImaging('PrepareConfiguration');
    PsychImaging('AddTask', 'General', 'FloatingPoint32BitIfPossible');
    Screen('Preference', 'SkipSyncTests', 1) % Uncomment this to override sync tests
    [Par.scrID, scrDim] = PsychImaging('OpenWindow', Par.Disp.screenid, Par.Disp.backgroundColour_RGB);
    
    Par.Disp.ScreenDimensions = scrDim; % Store screen dimensions (pixels)
    winWidth = scrDim(3);
    winHeight = scrDim(4);
    centreX = scrDim(3)/2;
    centreY = scrDim(4)/2;
    
    %raise priority level
    priorityLevel=MaxPriority(Par.scrID); Priority(priorityLevel);
    
    % We use a normalized color range from now on. All color values are
    % specified as numbers between 0.0 and 1.0, instead of the usual 0 to
    % 255 range. This is more intuitive:
    Screen('ColorRange', Par.scrID, 1, 0);
    
    % Set the alpha-blending:
    Screen('BlendFunction', Par.scrID, GL_SRC_ALPHA, GL_ONE);
    Screen('BlendFunction', Par.scrID, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    %% Define stimuli
    % Set up the 6 * 6 checkerboards stimulus.
    
    % The first entry specifies how many pixels in each square.
    Par.Disp.NumCheckSquares = 6;                                         % number of squares in row of the checkerboard.
    Par.Disp.NumPixCheckSq = floor(scrDim(4)/4/Par.Disp.NumCheckSquares); % make it a proportion of the screen height.
    Par.Disp.Checkerboard = double(checkerboard(Par.Disp.NumPixCheckSq, ...
        Par.Disp.NumCheckSquares/2) > 0.5);                               % Make the checkerboard of just 1s and 0s (white/black)
    
    % Make checkerboard texture.
    % NOTE: we only need 1 texture; for flickering we use the rotation option in 'Drawtexture'
    CheckTex = Screen('MakeTexture',Par.scrID,Par.Disp.Checkerboard,[],[],2);
    
    % Define left and right coordinates of the checkerboards:
    centeredCheckRect(1,:) = CenterRectOnPointd(Screen('Rect', CheckTex), scrDim(3)/4, centreY); % Left side
    centeredCheckRect(2,:) = CenterRectOnPointd(Screen('Rect', CheckTex), scrDim(3)/2 + scrDim(3)/4, centreY); % Right side
    
    % Determine the size of the cue/reward stimulus.
    % We'll make this a border around the checks of width TWO checkerboard squares.
    Par.Disp.CueRect = [0 0 size(Par.Disp.Checkerboard)+Par.Disp.NumPixCheckSq*2];
    % Define the coordinates of the cue:
    centeredCueRect(1,:) = CenterRectOnPointd(Par.Disp.CueRect, scrDim(3)/4, centreY); % Left side
    centeredCueRect(2,:) = CenterRectOnPointd(Par.Disp.CueRect, scrDim(3)/2 + scrDim(3)/4, centreY); % Right side
    
    % Colour of the cue:
    Par.Disp.CueRGB = [1 0 0];
    
    %% Work out timing of task/stimuli
    
    % Define desired timing of trial events in sec
    % Note that the checkers and the movie are on screen for the entire duration of the trial
    % Initial period of fixation, flickering checkers and movie:
    Par.Timing.FixnChecksDurationPt1.uncorrected = 1.25;
    % Presentation of the cue
    Par.Timing.CueDuration.uncorrected = 0.1;
    % Break before reward period
    Par.Timing.FixnChecksDurationPt2.uncorrected = 0.15;
    % Post-cue reward period
    Par.Timing.RewardDuration.uncorrected = 3;
    % ... and the sum of all these elements.
    Par.Timing.TotalTrialDuration.uncorrected = Par.Timing.FixnChecksDurationPt1.uncorrected + ...
        Par.Timing.CueDuration.uncorrected + ...
        Par.Timing.FixnChecksDurationPt2.uncorrected + ...
        Par.Timing.RewardDuration.uncorrected;
    
    % How long between trials? Define the inter-trial interval here (in sec)
    Par.Disp.InterTrialInterval = 2;
    
    % Adjust stimulus presentation durations to exact multiples of the screen
    % refresh duration
    Par.Timing.screenFrameRate = FrameRate(Par.scrID); % Get the frame rate
    Par.Timing.screenRefreshTime = 1 / FrameRate(Par.scrID); % Calculate the screen refresh duration in sec
    
    % Compute the number of frames for each stimulus event
    % Initial fixation period
    Par.Timing.FixnChecksDurationPt1.nFrames = ...
        round(Par.Timing.FixnChecksDurationPt1.uncorrected * Par.Timing.screenFrameRate);
    % Presentation of the cue
    Par.Timing.CueDuration.nFrames = ...
        round(Par.Timing.CueDuration.uncorrected * Par.Timing.screenFrameRate);
    % Break before reward period
    Par.Timing.FixnChecksDurationPt2.nFrames = ...
        round(Par.Timing.FixnChecksDurationPt2.uncorrected * Par.Timing.screenFrameRate);
    % Post-cue reward period
    Par.Timing.RewardDuration.nFrames = ...
        round(Par.Timing.RewardDuration.uncorrected * Par.Timing.screenFrameRate);
    % Sum of frames across the trial:
    Par.Timing.TotalTrialFrames = Par.Timing.FixnChecksDurationPt1.nFrames + Par.Timing.CueDuration.nFrames + ...
        Par.Timing.FixnChecksDurationPt2.nFrames + Par.Timing.RewardDuration.nFrames;
    % ...and the total duration of one trial in SEC
    Par.Timing.TotalTrialDuration.corrected = Par.Timing.TotalTrialFrames / Par.Timing.screenFrameRate;
    
    %% Set up timing duty cycles for the checkerboards.
    % These consist of square waves of zeros and ones that are used to
    % flip the checkerboard by 90 deg in order to cause it to reverse in contrast polarity at the appropriate frequency.
    
    Par.Disp.CheckFreqHz = [6 10]; % temporal frequencies of the two checkerboards
    angFreq = 2* pi * Par.Disp.CheckFreqHz; % Periodic frequencies of our checkerboards
    % Define time points to sample our wave at (in sec):
    t = Par.Timing.screenRefreshTime : Par.Timing.screenRefreshTime : Par.Timing.TotalTrialDuration.uncorrected;
    % Generate the square waves for both frequencies;
    % Half-wave rectify them by adding 1 and dividing by 2 (so we have 1s and 0s, not 1s and -1s).
    Par.Disp.ChecksDutyCycles = (square(cos(angFreq.*t')) + 1) / 2;
    
    %% Set up timing duty cycles for the cue / reward stimulus.
    % Cue will be bright red border around the checkerboard.
    %   There are 5 cue trial types:
    %   Valid | invalid | double cue | no cue + tone | no cue, no tone
    %   .. * 2 each with the reward stimulus presented on either left or right. So 10 trials.
    %   We control each trial type by modifying the RGB values of the cue/reward type stimulus on each frame.
    %   NOTE: when we insert the RGB values for the color change of the reward stimulus in a non-periodic
    %   way, we sometimes get additional frames added on the end; this is probably not an issue
    %   (these extra frames will simply not be indexed and used).
    
    % Set up a matrix encoding each of the visible conditions, where 1=present, 0=not present
    % Assign trials with reward appearing on the LEFT hand side
    %   Left side     |  Right side
    %   Cue | Reward  | Cue | Reward
    Par.Disp.ConditionMatrix = [
        1       1       0       0; ... % Valid cue, left reward
        1       0       0       1; ... % Invalid cue, left reward
        0       1       0       0; ... % Tone only, left reward
        1       1       1       0; ... % Double cue, left reward
        0       1       0       0; ... % No cues, left reward
        ];
    % To set up the trials with reward on the RIGHT hand side, we can simply
    % swap columns 1&2 for 3&4 from above. Do so using circshift:
    Par.Disp.ConditionMatrix = [Par.Disp.ConditionMatrix; ...
        circshift(Par.Disp.ConditionMatrix,2,2)];
    % We now have a matrix encoding the 10 trial types (according to reward location+cue validity).
    % We can use this to set up our cuing duty cycle.
    Par.Disp.NumTrialTypes = length(Par.Disp.ConditionMatrix);
    
    % Set up grey RGB values for most of the trial (ie, invisible cue):
    Par.Timing.LeftCueStimulusRGB = repmat({ones(Par.Timing.TotalTrialFrames, 3).*0.5}, ...
        Par.Disp.NumTrialTypes, 1);
    Par.Timing.RightCueStimulusRGB = repmat({ones(Par.Timing.TotalTrialFrames, 3).*0.5}, ...
        Par.Disp.NumTrialTypes, 1);
    
    % Insert cue duration frames RGB (defined above) for both left and right sides,
    % and the randomly flickering colours of the reward stimulus.
    % Define characteristics of the reward stimulus (common to all conditions):
    minChange = 2; %minimum time of reward stim change (2 frames)
    jitterRange = round(1 * Par.Timing.screenFrameRate); % Amount of jitter in change (frames)
    
    for condN = 1:Par.Disp.NumTrialTypes % Loop across all unique trial types
        
        % Insert left side cue (if any)
        if Par.Disp.ConditionMatrix(condN,1)
            Par.Timing.LeftCueStimulusRGB{condN}(Par.Timing.FixnChecksDurationPt1.nFrames+1 : ...
                Par.Timing.FixnChecksDurationPt1.nFrames + Par.Timing.CueDuration.nFrames, :) ...
                = repmat(Par.Disp.CueRGB, Par.Timing.CueDuration.nFrames, 1);
        end
        % Insert right side cue (if any)
        if Par.Disp.ConditionMatrix(condN,3)
            Par.Timing.RightCueStimulusRGB{condN}(Par.Timing.FixnChecksDurationPt1.nFrames+1 : ...
                Par.Timing.FixnChecksDurationPt1.nFrames + Par.Timing.CueDuration.nFrames, :) ...
                = repmat(Par.Disp.CueRGB, Par.Timing.CueDuration.nFrames, 1);
        end
        
        % Insert the reward stimulus
        % Insert random RGB values across random periods to induce non-periodic colour flicker
        if Par.Disp.ConditionMatrix(condN,2)
            % First, do left hand side stimulus
            frameCount = Par.Timing.TotalTrialFrames - Par.Timing.RewardDuration.nFrames; % Reset num frames prior to reward onset
            while frameCount < Par.Timing.TotalTrialFrames
                offset = round((rand*jitterRange)+minChange);
                Par.Timing.LeftCueStimulusRGB{condN}(frameCount+1 : frameCount+offset,:) = ...
                    repmat(rand(1,3), offset, 1);
                frameCount = frameCount + offset;
            end
        end
        
        % Now do right hand side stimulus:
        if Par.Disp.ConditionMatrix(condN,4)
            frameCount = Par.Timing.TotalTrialFrames - Par.Timing.RewardDuration.nFrames; % Reset num frames prior to reward onset
            while frameCount < Par.Timing.TotalTrialFrames
                offset = round((rand*jitterRange)+minChange);
                Par.Timing.RightCueStimulusRGB{condN}(frameCount+1 : frameCount+offset,:) = ...
                    repmat(rand(1,3), offset, 1);
                frameCount = frameCount + offset;
            end
        end
    end    % End of loop across conditions
    
    
    %% Determine parameters of each movie displayed on each trial
    
    if Switch.DrawMovies
        
        % We'll select a random movie and a random time period from that movie for display on each trial,
        % provided it does not exceed the end of the movie.
        
        for condN = 1:Par.Disp.NumTrialTypes
            
            %Randomly select a movie file:
            RandDraw = ceil(rand*Par.Disp.NumMovieFiles);
            
            % Set aside the name+path of the movie file to be used:
            Par.Disp.MoviesUsed.movieFileName{condN} = Par.Disp.MoviePaths{RandDraw};
            % Select a random time point from the movie, making sure it will not overlap with the end of the trial:
            Par.Disp.RandomMovieStartTime(condN) = rand*(Par.Disp.MovieDetails{RandDraw}.Duration - Par.Timing.TotalTrialDuration.uncorrected);
            
            % Determine new rect based on movie resolution, to make the movie smaller on screen.
            % All movies are displayed at the centre of the screen.
            % These will be identical for each selection, unless a new set of movies of different resolution are used.
            % But we will set aside details of each just in case...
            Par.Disp.movieRects(condN,:) = CenterRectOnPointd ([0 0 ...
                Par.Disp.MovieDetails{RandDraw}.Width * ReduceMovieResBy ...
                Par.Disp.MovieDetails{RandDraw}.Height * ReduceMovieResBy], ...
                centreX, centreY);
        end
    end
    
    %% Begin the experiment!
    ForcedQuit = false; % this is a flag for the exit function to indicate whether the program was aborted
    HideCursor;
    
    % Display welcome screen
    Screen('TextFont',Par.scrID, 'Arial');
    Screen('TextSize',Par.scrID, 44);
    DrawFormattedText(Par.scrID,['Welcome ', ...
        '\n \nPress any key to begin.'], ...
        'center', 'center', 0);
    Screen('Flip', Par.scrID); %, [], [], [], 1);
    
    % Wait for user response to continue...
    ButtonPressed = 0;
    while ~ButtonPressed
        % if 'Esq' is pressed, abort
        [KeyIsDown, ~, keyCode] = KbCheck();
        if KeyIsDown % a key has been pressed
            if keyCode(RespQuit)
                ForcedQuit = true
                ExitGracefully(ForcedQuit)
                %if any other button on the keyboard has been pressed
            else
                ButtonPressed = 1;
            end
        end
    end
    
    WaitSecs(0.2)
    KbCheck(); % take a quick KbCheck to load it now & flush any stored events
    
    % Blank the screen and wait 2 secs before beginning.
    Screen('Flip', Par.scrID);
    WaitSecs(2);
    Res.Timing.missedFrames = 0; % Set up counter for missed frames.
    trialN = 1; % Counter to increment across TRIALS
    F = 1; % Counter to increment across FRAMES
    
    % Update screen and begin
    vbl = Screen('Flip', Par.scrID);
    Res.Timing.runStartTime = vbl;
    
    %%
    % Test presentation
    while trialN <= Par.Disp.NumTrialTypes % Begin loop across trial types
        
        DrawFormattedText(Par.scrID,[num2str(trialN)], ...
            'center', 'center', 0);
        [vbl , ~ , ~, ~] = Screen('Flip', Par.scrID);
        
        if Switch.DrawMovies
            % Open movie file for current trial:
            [moviePtr, ~, ~, ~, ~] = Screen('OpenMovie', Par.scrID, Par.Disp.MoviesUsed.movieFileName{trialN}, ...
                [], ... % preloadsecs
                [], ... % asyc (?)
                2, ...  % specialFlags: set to 2 get rid of sound (may be faster) RM.
                5, ...  % pixelFormat, 5 or 6 meant to be better... RM ...6 results in b/w movies
                []);    % maxThreads;
        end
                
        if Switch.DrawMovies
            % Start movie playback engine:
            Screen('PlayMovie', moviePtr, 1); % Final argument is play rate.
        end
        
        % Insert inter-trial interval
        while GetSecs() < vbl + Par.Disp.InterTrialInterval, end 
        
        % Refresh screen ready for new trial:
        [vbl , ~ , ~, ~] = Screen('Flip', Par.scrID, vbl+(Par.Timing.screenRefreshTime*0.5)); %, [], [], 1); % update display on next refresh (& provide deadline)
        
        %Determine what the correct length of the stimulus or blank should be, if this is the first frame:
        if F == 1
            trialStartVBL = vbl; %take start point as most recent vbl
            trialEndVBL = trialStartVBL + Par.Timing.TotalTrialDuration.corrected -  Par.Timing.screenRefreshTime;
            
            % Send trigger to mark first frame of stimulus:
            
        end
        
        
        % Draw each stimulus event:
        trialEnd = false;
        while ~trialEnd %This should keep iterating across stim frames until vbl >= trialEndVBL
            
            if Switch.DrawMovies
                % If it's the first frame, set the movie to its random start point:
                if F == 1
                    Screen('SetMovieTimeIndex', moviePtr, Par.Disp.RandomMovieStartTime(trialN));
                end
            end
            
            % Draw the cue + reward stimuli:
            Screen('FillRect', Par.scrID, Par.Timing.LeftCueStimulusRGB{trialN}(F,:), centeredCueRect(1,:));
            Screen('FillRect', Par.scrID, Par.Timing.RightCueStimulusRGB{trialN}(F,:), centeredCueRect(2,:));
            
            Screen('DrawTextures', Par.scrID, CheckTex, [], centeredCheckRect', Par.Disp.ChecksDutyCycles(F,:)*90);
            
            if Switch.DrawMovies
                % Wait for next movie frame, retrieve texture handle to it
                MovieTex = Screen('GetMovieImage', Par.scrID, moviePtr);
                % Draw the new movie texture immediately to screen:
                Screen('DrawTexture', Par.scrID, MovieTex, [], Par.Disp.movieRects(trialN,:)); %
            end
            
            Screen('DrawingFinished', Par.scrID);
            
            [vbl , ~ , ~, missed] = Screen('Flip', Par.scrID, vbl+(Par.Timing.screenRefreshTime*0.5)); %, [], [], 1); % update display on next refresh (& provide deadline)
            
            if Switch.DrawMovies
                % Release movie texture:
                Screen('Close', MovieTex);
            end
            
            if missed > 0
                Res.Timing.missedFrames = Res.Timing.missedFrames + 1;
            end
            
            % Check for 'Escape' key
            [KeyIsDown, ~, keyCode] = KbCheck();
            if KeyIsDown % a key has been pressed
                if keyCode(RespQuit)
                    ForcedQuit = true
                    ExitGracefully(ForcedQuit)
                end
            end
            
            % Increment frames.
            F = F + 1; % Only F is reset with each trial
            
            % This is the important bit:
            % If we've reached the determined end time of the trial,
            % we reset F and move on to the next one.
            % This means no stimulus ever exceeds its deadline (by more than 1 frame anyway)
            % and we shouldn't miss any either.
            if vbl >= trialEndVBL
                F = 1;           % Reset F for next trial
                trialN = trialN+1; % Increment condition/ trial type
                trialEnd = true; % This should terminate the current stimulus execution and move on to next one
            end
        end % end of loop across trial frames
        
        if Switch.DrawMovies
            % Stop movie playback:
            Screen('PlayMovie', moviePtr, 0);
            % Close movie object:
            Screen('CloseMovie', moviePtr);
        end
        F =1;
        %trialN = trialN+1; % Increment condition/ trial type
        
        Screen('Flip', Par.scrID); % Blank screen between trials
        
    end % end of loop across trial types
    
    missed_deadlines = Res.Timing.missedFrames
    sca
    
catch
    
    % We throw the error again so the user sees the error description.
    psychrethrow(psychlasterror);
    sca
    
end % End of try/catch statement.
ShowCursor

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function ExitGracefully (ForcedQuit)
%...need to shut everything down here...

% turn off the prioritisation:
Priority( 0 ); % restore priority

% Close down the screen:
Screen('CloseAll')

% Bring back the mouse cursor:
ShowCursor();

% announce to cmd window if the program was aborted by the user
if ForcedQuit
    error('You quit the program!')
end

end