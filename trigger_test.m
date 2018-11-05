s1 = serial('COM4')
fopen(s1)

fwrite(s1,0)
fwrite(s1,254)
%fwrite(s1,bin2dec('100')) 