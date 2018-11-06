s1 = serial('COM4')
fopen(s1)

fwrite(s1,0)
WaitSecs(0.005)
fwrite(s1,17)
%fwrite(s1,bin2dec('100')) 

fclose(s1)

% clear('s1')