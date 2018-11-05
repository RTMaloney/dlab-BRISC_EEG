
%% 
clear all
close all
clc


%%
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


%%
obj = VideoReader(fullfile('C:\Users\BRISC\Videos','The Wiggles- Say the Dance, Do the Dance (Official Video).mp4'))

NumFramesToDraw = 4.5*60;
tic
for k = 1 : NumFramesToDraw
    this_frame = readFrame(obj);
    
    MovieTex(k) = Screen('MakeTexture',Par.scrID,this_frame,[],[],[]);
    
    %thisfig = figure();
    %   thisax = axes('Parent', thisfig);
    %   image(this_frame, 'Parent', thisax);
    %   title(thisax, sprintf('Frame #%d', k));
    %   pause(0.1)
end
toc

% generate 'rect'  for the movie, making it half the size on screen:
movieRect = CenterRectOnPointd ([0 0 ...
                obj.Width / 2 ...
                obj.Height / 2], ...
                centreX, centreY);

%%
% We want to present only every 2nd frame, or the movie plays too fast
xx = [1:NumFramesToDraw; 1:NumFramesToDraw;];
xx = reshape(xx,1,NumFramesToDraw*2);
Screen('Flip', Par.scrID)
num_missed = 0;
for ii=1:length(xx)
    
    Screen('DrawTextures', Par.scrID, MovieTex(xx(ii)), [], movieRect);
    
    Screen('DrawingFinished', Par.scrID);
    
    [vbl , ~ , ~, missed] = Screen('Flip', Par.scrID); %, vbl+(Par.Timing.screenRefreshTime*0.5)); %, [], [], 1); % update display on next refresh (& provide deadline)

    if missed > 0
        num_missed = num_missed+1;
    end
    
end

num_missed
sca
