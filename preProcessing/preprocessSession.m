function  preprocessSession(varargin)

% [preprocessSession(varargin)]

%   [Master function to run the basic pre-processing pipeline for an
%   individual sessions. Is based on sessionsPipeline.m but in this case
%   works on an individual session basis no in a folfer with multiple ones]
%
%
% INPUTS
%   [input parser]  [inputs as opiton list of values - see below]
%   <options>       optional list of property-value pairs (see table below)
%  =========================================================================
%   Properties    Values
%  -------------------------------------------------------------------------
% [basepath]             [Basepath for experiment. It contains all session
%                         folders. If not provided takes pwd]
% [analogChannels]       [List of analog channels with pulses to be detected (it
%                         supports Intan Buzsaki Edition)]
% [digitalChannels]      [List of digital channels with pulses to be detected (it
%                         supports Intan Buzsaki Edition)]
% [forceSum]             [Force make folder summary (overwrite, if necessary). 
%                         Default false]
% [cleanArtifacts]       [Remove artifacts from dat file. By default, if there is 
%                         analogEv in folder, is true]
% [stateScore]           [Run automatic brain state detection with SleepScoreMaster. 
%                         Default true]
% [spikeSort]            [Run automatic spike sorting using Kilosort. Default true]
% [cleanRez]             [Run automatic noise detection of the Kilosort results
%                        (these will be pre-labelled as noise in phy). Default true]
% [getPos]               [get tracking positions. Default false]
% [runSummary            [run summary analysis using AnalysisBatchScript.
%                         Defualt false]
% [pullData]             [Path for raw data. Look for not analized session to
%                         copy to the main folder basepath. To do...]
% [path_to_dlc_bat_file] [path to your dlc bat file to analyze your videos
%                         (see neurocode\behavior\dlc for example files)]
% [nKilosortRuns]        [number of desired Kilosort runs (default = 1). The
%                         function will break down the shanks into "nKilosortRuns" 
%                         groups for each run]
%  OUTPUTS
%    N/A
%
%  NOTES
%   TODO:
%   - Improve auto-clustering routine
%   - Test cleaning and removing artifacts routines
%  SEE ALSO
%
% [AntonioFR] [2020 - 2022]
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 3 of the License, or
% (at your option) any later version.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Set up parameters and parse inputs

p = inputParser;
addParameter(p,'basepath',pwd,@isfolder); % by default, current folder
addParameter(p,'fillMissingDatFiles',false,@islogical);
addParameter(p,'fillTypes',[],@iscellstr);
addParameter(p,'analogInputs',false,@islogical);
addParameter(p,'analogChannels',[],@isnumeric);
addParameter(p,'digitalInputs',false,@islogical);
addParameter(p,'digitalChannels',[],@isnumeric);
addParameter(p,'getAcceleration',false,@islogical);
addParameter(p,'cleanArtifacts',false,@islogical);
addParameter(p,'stateScore',true,@islogical);
addParameter(p,'spikeSort',true,@islogical);
addParameter(p,'cleanRez',true,@islogical);
addParameter(p,'getPos',false,@islogical);
addParameter(p,'removeNoise',false,@islogical); % raly: noise removal is bad, it removes periods 20ms after (because of the filter shifting) a peak in high gamma. See ayadata1\home\raly\Documents\notes\script_NoiseRemoval_bad.m for details.
addParameter(p,'runSummary',false,@islogical);
addParameter(p,'SSD_path','D:\KiloSort',@ischar)    % Path to SSD disk. Make it empty to disable SSD
addParameter(p,'path_to_dlc_bat_file','',@isfile)
addParameter(p,'nKilosortRuns',1,@isnumeric);  %needs to be changed from shanks to probes HLR 01/05/23

% addParameter(p,'pullData',[],@isdir); To do...
parse(p,varargin{:});

basepath = p.Results.basepath;
fillMissingDatFiles = p.Results.fillMissingDatFiles;
fillTypes = p.Results.fillTypes;
analogInputs = p.Results.analogInputs;
analogChannels = p.Results.analogChannels;
digitalInputs = p.Results.digitalInputs;
digitalChannels = p.Results.digitalChannels;
getAcceleration = p.Results.getAcceleration;
cleanArtifacts = p.Results.cleanArtifacts;
stateScore = p.Results.stateScore;
spikeSort = p.Results.spikeSort;
cleanRez = p.Results.cleanRez;
getPos = p.Results.getPos;
removeNoise = p.Results.removeNoise;
runSummary = p.Results.runSummary;
SSD_path = p.Results.SSD_path;
path_to_dlc_bat_file = p.Results.path_to_dlc_bat_file;
nKilosortRuns = p.Results.nKilosortRuns;

if ~exist(basepath,'dir')
    error('path provided does not exist')
end
cd(basepath)

%% Pull meta data

% Get session names
if strcmp(basepath(end),filesep)
    basepath = basepath(1:end-1);
end
[~,basename] = fileparts(basepath);

% Get xml file in order
xmlFile = checkFile('fileType','.xml','searchSubdirs',true);
xmlFile = xmlFile(1);
if ~(strcmp(xmlFile.folder,basepath)&&strcmp(xmlFile.name(1:end-4),basename))
    copyfile([xmlFile.folder,filesep,xmlFile.name],[basepath,filesep,basename,'.xml'])
end

% Check info.rhd
% (assumes this will be the same across subsessions)
rhdFile = checkFile('fileType','.rhd','searchSubdirs',true);
rhdFile = rhdFile(1);
if ~(strcmp(rhdFile.folder,basepath)&&strcmp(rhdFile.name(1:end-4),basename))
    copyfile([rhdFile.folder,filesep,rhdFile.name],[basepath,filesep,basename,'.rhd'])
end

%% Make SessionInfo
% Manually ID bad channels at this point. automating it would be good
session = sessionTemplate(basepath,'showGUI',false);
save(fullfile(basepath,[basename, '.session.mat']),'session');

%% Fill missing dat files of zeros
if fillMissingDatFiles
    if isempty(fillTypes)
        fillTypes = {'analogin';'digitalin';'auxiliary';'time';'supply'};
    end
    for ii = 1:length(fillTypes)
        fillMissingDats('basepath',basepath,'fileType',fillTypes{ii});
    end
end
%% Concatenate sessions
disp('Concatenate session folders...');
concatenateDats(basepath,1);

%% run again to add epochs from basename.MergePoints.m
session = sessionTemplate(basepath,'showGUI',false);
save(fullfile(basepath,[basename, '.session.mat']),'session');

%% Process additional inputs - CHECK FOR OUR LAB

% Analog inputs
% check the two different fucntions for delaing with analog inputs and proably rename them
if analogInputs
    if  ~isempty(analogChannels)
        analogInp = computeAnalogInputs('analogCh',analogChannels,'saveMat',true,'fs',session.extracellular.sr);
    else
        analogInp = computeAnalogInputs('analogCh',[],'saveMat',true,'fs',session.extracellular.sr);
    end
    
    % analog pulses ...
    [pulses] = getAnalogPulses('samplingRate',session.extracellular.sr);
end

% Digital inputs
if digitalInputs
    if ~isempty(digitalChannels)
        % need to change to only include specified channels
        digitalInp = getDigitalIn('all','fs',session.extracellular.sr,'digUse',digitalChannels);
    else
        digitalInp = getDigitalIn('all','fs',session.extracellular.sr);
    end
end

% Auxilary input
if getAcceleration
    accel = computeIntanAccel('saveMat',true);
end

%% Make LFP
try
    try
        LFPfromDat(basepath,'outFs',1250,'useGPU',true);
    catch
        if (exist([basepath '\' basename '.lfp'])~=0)
            fclose([basepath '\' basename '.lfp']); %if the above run failed after starting the file
            delete([basepath '\' basename '.lfp']);
        end
        LFPfromDat(basepath,'outFs',1250,'useGPU',false);
    end
catch
    try
        warning('LFPfromDat failed, trying ResampleBinary')
        ResampleBinary([basepath '\' basename '.dat'],[basepath '\' basename '.lfp'],session.extracellular.nChannels,1,16);
    catch
        warning('LFP file could not be generated, moving on');
    end
end

% 'useGPU'=true gives an error if CellExplorer in the path. Need to test if
% it is possible to remove the copy of iosr toolbox from CellExplorer -
% seems to be fixed? as of 9/22

%% Clean data  - CHECK FOR OUR LAB
% Remove stimulation artifacts
if cleanArtifacts && analogInputs
    [pulses] = getAnalogPulses(analogInp,'analogCh',analogChannels);
    cleanPulses(pulses.ints{1}(:));
end

% remove noise from data for cleaner spike sorting
if removeNoise
    NoiseRemoval(basepath); % not very well tested yet
end

%% Get brain states
% an automatic way of flaging bad channels is needed
if stateScore
    try
        if exist('pulses','var')
            SleepScoreMaster(basepath,'noPrompts',true,'ignoretime',pulses.intsPeriods,'rejectChannels',session.channelTags.Bad.channels); % try to sleep score
        else
            SleepScoreMaster(basepath,'noPrompts',true,'rejectChannels',session.channelTags.Bad.channels); % takes lfp in base 0
        end
    catch
        warning('Problem with SleepScore scoring... unable to calculate');
    end
end

%% Kilosort concatenated sessions - Needs to be changed to probes, not shanks HLR 01/05/2023
if spikeSort
    if nKilosortRuns>1 % if more than one Kilosort cycle desired, break the shanks down into the desired number of kilosort runs
        shanks = session.extracellular.spikeGroups.channels;
        kilosortGroup = ceil(((1:length(shanks))/nKilosortRuns));
        for i=1:nKilosortRuns
            channels = cat(2,shanks{kilosortGroup==i});
            excludeChannels = find(~ismember((1:session.extracellular.nChannels),channels));
            excludeChannels = cat(2,excludeChannels,session.channelTags.Bad.channels);
            kilosortFolder = KiloSortWrapper('SSD_path',SSD_path,'rejectchannels',excludeChannels);
            if cleanRez
                load(fullfile(kilosortFolder,'rez.mat'),'rez');
                CleanRez(rez,'savepath',kilosortFolder);
            end
        end
    else
        %% single sort
        kilosortFolder = KiloSortWrapper('SSD_path',SSD_path,...
            'rejectchannels',session.channelTags.Bad.channels); % 'NT',20*1024 for long sessions when RAM is overloaded
        if cleanRez
            load(fullfile(kilosortFolder,'rez.mat'),'rez');
            CleanRez(rez,'savepath',kilosortFolder);
        end
        %     PhyAutoClustering(kilosortFolder);
    end
end

%% Get tracking positions
if getPos
    % check for pre existing deeplab cut
    if exist(path_to_dlc_bat_file,'file')
        system(path_to_dlc_bat_file,'-echo')
    end
    % put tracking into standard format
    general_behavior_file('basepath',basepath)
end

%% Summary -  NOT WELL IMPLEMENTED YET
if runSummary
    if forceSum || (~isempty(dir('*Kilosort*')) && (isempty(dir('summ*')))) % is kilosorted but no summ
        disp('running summary analysis...');
        sessionSummary;
    end
end
end