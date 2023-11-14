%% X Energy Lab Schlieren Video Processing Code V1.0.1 (mp4 edition)
% Last Update: 11/13/23 by Spencer K
%
%Adding a github dummy line in here as well
%
% This version takes in a .mp4 video. MATLAB will read this video as a
% 3x8 bit RGB file, which means it must first be converted into grayscale,
% then it can be manipulated as an 8 bit grayscale.
% Code does three primary tasks
%
%   1) Remove the background from video
%   2) Removes background and applies a preset contrast value
%   3) Goes through interactive loop to test different contrasts to
%   identify the preferred contrast
%
% The two flags at the beginning "contrast" and "interactiveContrast" will
% signal the code when to activate the preferences.
%
% * If both are 0, then only the background remover runs.
% * If contrast =1, the set sigma value "sig" will be used to apply contrast
% to the entire video
% * If both "contrast" and "interactiveContrast" are flagged, then a loop
% will begin after selecting the video to first identify the frame to test
% contrast against, then different values of the contrast can be
% experimented with
%
% V1.0.1: Sigma can now be set as an array in case the desired different
% contrasts are known ahead of time. i got tired of clicking three times
% when I wanted to do the same set of [10 15 20] so now it can do it
%
%

clc;close all;clear;

%Make sure both flags are 1 if going interactive contrast, if it is just
%the interactive, the whole code will run with the default/initial sigma
%value set
contrast=1;%flag for setting contrast
interactiveContrast=0; %flag to use interactive contrast routine

sig=5;%initial contrast value, set when not using interactive contrast. Can be a vector


[filename,pathname]=uigetfile('*.mp4');%interact to select the video
vid = VideoReader([pathname filename]) %load in the video
tic
frames=read(vid);



% para=gcp;%parallelzation properties
% [x1,y1,z1,f1]=size(frames);
%
% %setting up false frames to be corrected later
% temp=ones(x1,y1,z1,f1+1,'uint8');
% temp(:,:,:,1:end-1)=frames(:,:,:,:);
% temp(:,:,:,end)=2^11*temp(:,:,:,end);
% frames=temp;
% clear temp
%
% [x1,y1,z1,f1]=size(frames);
% %check if the number of frames is divisble by the number of working cores
% evensplit=mod(f1,para.NumWorkers);
% if evensplit~=0
%     temp=ones(x1,y1,z1,f1+(para.NumWorkers-evensplit),'uint8');
%     temp(:,:,:,1:end-(para.NumWorkers-evensplit))=frames(:,:,:,:);
%     temp(:,:,:,end)=2^11*temp(:,:,:,end);
%     frames=temp;
%     clear temp
% end
% toc
[x1,y1,z1,f1]=size(frames);
tic

%convert all the rgb frames into grayscale
for i=1:f1
    grayVid(:,:,:,i)=rgb2gray(frames(:,:,:,i));
end
toc
clear frames %free some memory up

%go into contrast conditioning function
if interactiveContrast && contrast
    sig=SetContrast(grayVid);
end

%Prep old video for processing
processedVid=zeros(x1,y1,'int16'); %preallocate processed vid space
grayVid=squeeze(grayVid); %get rid of unnessesary dimensions
grayVid=cast(grayVid,'int16');
backRef=grayVid(:,:,1); %get background reference
tic
for j=1:length(sig)
    %Prep video writer
    if contrast
        extraName=sprintf('_contrast_%.2f-sig',sig(j));
        vidWrite=VideoWriter([pathname filename(1:end-4) extraName]); %set writer object with filename
    else
        vidWrite=VideoWriter([pathname filename(1:end-4) '_noBackground']); %set writer object with filename
    end
    vidWrite.FrameRate=vid.FrameRate;%Set output framerate to be same as input

    open(vidWrite)

    for i=1:f1 %for every file
        processedVid=grayVid(:,:,i)-backRef+128;
        if contrast
            processedVid=cast(processedVid,'uint8'); %ensures pixels are between 0 and 255
            processedVid=cast(processedVid,'single'); %puts it in a data type that exp() can read
            processedVid=255./(1+exp(-(processedVid-128)./sig(j)));
        end

        processedVid=cast(processedVid,'uint8');%tricky trick: will make all >255 equal 255, and all <0, equal zero
        %also its necessary for the video writer

        % One option to get higher color resolution: at the moment not working
        % processedVid=cast(processedVid,'single');
        % processedVid=processedVid./255;
        writeVideo(vidWrite,processedVid)

    end

    toc
    close(vidWrite)

end

function sig = SetContrast(frames)
%this function makes it easy to determine what sigma to use for contrast
%it will loop through the first 50 frames for the user to pick a frame to
%use as the starter test frame and then test a variety of sigmas and show
%the resultant contrast
figure (1)
hold on
for i=1:50 %
    imshow(frames(:,:,i))
    choice= input('Use this frame? (0) for no (1) for yes       ');
    if choice
        break
    end
end

frames=cast(frames,'int16');
backRef=frames(:,:,1);
refFrame=frames(:,:,i)-backRef+128;
refFrame=cast(refFrame,'single');

sig=input('What is the initial sigma value:     ');
while true
    testFrame=cast(255./(1+exp(-(refFrame-128)./sig)),'uint8');
    imshow(testFrame)
    disp('If this is the desired contrast, enter 0 ')
    sigGood=input('Enter a new sigma value:     ');
    if ~sigGood
        break
    else
        sig=sigGood;
    end
end
hold off

end
