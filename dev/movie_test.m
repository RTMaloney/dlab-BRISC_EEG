
%%
% Generate a cell array of strings providing the full paths of each of the 9 movie files.
Par.Disp.video_dir = 'C:\Users\BRISC\Videos';                    % The movie file directory
Par.Disp.Movies = {'The Wiggles - Romp Bomp A Stomp.mp4', ...    % Each of the movie file names
    'The Wiggles- Do The Pretzel (Official Video).mp4', ...
    'The Wiggles- Do The Propeller! (Official Video).mp4', ...
    'The Wiggles- Do the Skeleton Scat (Official Video).mp4', ...
    'The Wiggles- I''ve'' Got My Glasses On (Official Video).mp4', ...
    'The Wiggles- Ooey, Ooey, Ooey Allergies.mp4', ...
    'The Wiggles- Say the Dance, Do the Dance (Official Video).mp4', ...
    'The Wiggles- There Are So Many Animals (Official Video).mp4', ...
    'The Wiggles- Who''s'' In The Wiggle House- (Official Video).mp4'};
% Insert the full directory into each file path
Par.Disp.Movies = cellfun(@(x) fullfile(Par.Disp.video_dir, x), Par.Disp.Movies, 'UniformOutput', false);

movieFile = Par.Disp.Movies{1};

%%
try
    screenNum = max(Screen('Screens'));
    Screen('Preference', 'SkipSyncTests', 1);
    [window, rect] = Screen('OpenWindow', screenNum, 128);
    moviePtr = Screen('OpenMovie', window, movieFile);
    Screen('PlayMovie', moviePtr, 1);
    
catch
    
    sca
end
