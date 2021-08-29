
function [behavior] = getSessionTracking(varargin)
%
% Gets position trackign for each sub-session and concatenate all of them so they are 
% aligned with LFP and spikes. Default is recording with Basler, and requiere avi videos 
% and at least one tracking LED. There is an alternative in case OptiTrack was used. 
% Needs to be run in main session folder. 
%
% USAGE
%
%   [tracking] = getSessionTracking(varargin)
%
% INPUTS
%   basePath       -(default: pwd) basePath for the recording file, in buzcode format:
%   roiTracking    - 2 x R, where 1C is x and 2C is y. By default it
%                   considers the whole video. With the option 'manual' allows to draw
%                   a ROI.
%   roiLED         - 2 x R. 'manual' for drawing the ROI.
%   roisPath       - provide a path with ROI mat files ('roiTRacking.mat'
%                   and 'roiLED.mat'). By default try to find it in
%                   basePath or upper folder.
%   convFact       - Spatial conversion factor (cm/px). If not provide,
%                   normalize maze size.
%   saveMat        - default true
%   forceReload    - default false
%   optitrack      - if optitrack instead of basler was used. Default false
%
% OUTPUT
%       - tracking.behaviour output structure, with the fields:
%   position.x               - x position in cm/ normalize
%   position.y               - y position in cm/ normalize
%   timestamps      - in seconds, if Basler ttl detected, sync by them
%   folder          - 
%   sync.sync       - Rx1 LED luminance.
%   sync.timestamps - 2xC with start stops of sync LED.
%       only for OptiTrack
%   position.z 
%   orientation.x
%   orientation.y
%   orientation.z

%   HISTORY:
%     - Manuel Valero 2019
%     - Added OptiTrack support: 5/20, AntonioFR (new updates from KM)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Defaults and Params
p = inputParser;
addParameter(p,'basepath',pwd,@isstr);
addParameter(p,'convFact',[],@isnumeric); % 0.1149
addParameter(p,'roiTracking',[],@ismatrix);
addParameter(p,'roiLED',[],@ismatrix);
addParameter(p,'roisPath',[],@isfolder);
addParameter(p,'saveMat',true,@islogical)
addParameter(p,'forceReload',false,@islogical)
addParameter(p,'optitrack',false,@islogical)

parse(p,varargin{:});
basepath = p.Results.basepath;
convFact = p.Results.convFact;
roiTracking = p.Results.roiTracking;
roiLED = p.Results.roiLED;
roisPath = p.Results.roisPath;
saveMat = p.Results.saveMat;
forceReload = p.Results.forceReload;
optitrack = p.Results.optitrack;

%% In case tracking already exists 
if ~isempty(dir([basepath filesep '*Tracking.Behavior.mat'])) || forceReload
    disp('Trajectory already detected! Loading file.');
    file = dir([basepath filesep '*Tracking.Behavior.mat']);
    load(file.name);
    return
end

%% Basler tracking 
if ~(optitrack)
    cd(basepath); cd ..; upBasepath = pwd; cd(basepath);
    if isempty(roisPath)
        if exist([basepath filesep 'roiTracking.mat'],'file') || ...
            exist([basepath filesep 'roiLED.mat'],'file')
                roisPath = basepath;
                try load([roisPath filesep 'roiLED.mat'],'roiLED'); end
                load([roisPath filesep 'roiTracking.mat'],'roiTracking');
        elseif exist([upBasepath filesep 'roiTracking.mat'],'file') || ...
            exist([upBasepath filesep 'roiLED.mat'],'file')
                roisPath = upBasepath;
                try load([roisPath filesep 'roiLED.mat'],'roiLED'); end
                load([roisPath filesep 'roiTracking.mat'],'roiTracking');
        end   
    end

    %% Find subfolder recordings
    cd(basepath);
    [sessionInfo] = getSessionInfo(basepath, 'noPrompts', true);
    %C = strsplit(sessionInfo.session.name,'_');
    %sess = dir(strcat(C{1},'_',C{2},'*')); % get session files
    if exist([basepath filesep strcat(sessionInfo.session.name,'.MergePoints.events.mat')],'file')
        load(strcat(sessionInfo.session.name,'.MergePoints.events.mat'));
        count = 1;
        for ii = 1:size(MergePoints.foldernames,2)
            %if sess(ii).isdir && ~isempty(dir([basepath filesep sess(ii).name filesep '*Basler*avi']))
             if ~isempty(dir([basepath filesep MergePoints.foldernames{ii} filesep '*Basler*avi']))   
                cd([basepath filesep MergePoints.foldernames{ii}]); %cd([basepath filesep sess(ii).name]);
                fprintf('Computing tracking in %s folder \n',MergePoints.foldernames{ii});
                 tempTracking{count}= LED2Tracking([],'convFact',convFact,'roiTracking',...
                     roiTracking,'roiLED',roiLED,'forceReload',forceReload); % computing trajectory
                 trackFolder(count) = ii; 
                count = count + 1;
            end
        end
        cd(basepath);
    else
        error('missing MergePoints, quiting...');
    end
    
    %% Concatenate and sync timestamps
    ts = []; subSessions = []; maskSessions = [];
    if exist([basepath filesep strcat(sessionInfo.session.name,'.MergePoints.events.mat')],'file')
        load(strcat(sessionInfo.session.name,'.MergePoints.events.mat'));
        for ii = 1:length(trackFolder)
            if strcmpi(MergePoints.foldernames{trackFolder(ii)},tempTracking{ii}.folder)
                sumTs = tempTracking{ii}.timestamps + MergePoints.timestamps(trackFolder(ii),1);
                subSessions = [subSessions; MergePoints.timestamps(trackFolder(ii),1:2)];
                maskSessions = [maskSessions; ones(size(sumTs))*ii];
                ts = [ts; sumTs];
            else
                error('Folders name does not match!!');
            end
        end
    else
        warning('No MergePoints file found. Concatenating timestamps...');
        for ii = 1:length(trackFolder)
            sumTs = max(ts)+ tempTracking{ii}.timestamps;
            subSessions = [subSessions; [sumTs(1) sumTs(end)]];
            ts = [ts; sumTs];
        end
    end

    % Concatenating tracking fields...
    x = []; y = []; folder = []; samplingRate = []; description = [];
    for ii = 1:size(tempTracking,2) 
        x = [x; tempTracking{ii}.position.x]; 
        y = [y; tempTracking{ii}.position.y]; 
        folder{ii} = tempTracking{ii}.folder; 
        samplingRate = [samplingRate; tempTracking{ii}.samplingRate];  
        description{ii} = tempTracking{ii}.description;
    end

    tracking.position.x = x;
    tracking.position.y = y;
    tracking.folders = folder;
    tracking.samplingRate = samplingRate;
    tracking.timestamps = ts;
    tracking.events.subSessions =  subSessions;
    tracking.events.subSessionsMask = maskSessions;

end
%% OptiTrack 
if optitrack
    
    % Get csv file locations
    trackingFiles = checkFile('basepath',basepath,'fileType','.csv');
    nFiles = length(trackingFiles);
    
    % Load merge point info to correct times
    mergeFile = checkFile('basepath',basepath,'fileType','.MergePoints.events.mat');
    load([mergeFile.folder,filesep,mergeFile.name]);
    
    % Load data from each file with proper time 
    clear trackData;
    for fileIdx = 1:nFiles
        tempFile = trackingFiles(fileIdx);
        trackData.file(fileIdx) = readOptitrackCSV(tempFile.name,'basepath',tempFile.folder,...
            'syncCh',2,'syncNbCh',4,'syncSampFq',5000); % these values chosen for this session, need to fix
        tempFolder = tempFile(fileIdx).folder;
        subDirIdx = strcmp(tempFolder,MergePoints.foldernames);
        t0 = MergePoints.timestamps(subDirIdx,1);
        trackData.file(fileIdx).timestamps = trackData.file(fileIdx).timestamps + t0;
    end
    
    % Stick data together in order
    data = vertcat(trackData.file(:).data);
    timestamps = vertcat(trackData.file(:).timestamps);
    
    behavior = struct();
    behavior.timestamps = timestamps;
    behavior.frameCount = data(:,1);
    
    behavior.orientation.rx = data(:,3);
    behavior.orientation.ry = data(:,4);
    behavior.orientation.rz = data(:,5);
    behavior.orientation.rw = data(:,6);
    
    behavior.position.x = data(:,7);
    behavior.position.y = data(:,8);
    behavior.position.z = data(:,9);
    
    if size(data,2)==10
        behavior.errorPerMarker = data(:,10);
    end
    
end

%% save tracking 
session = getSession('basepath',basepath);
if saveMat
    save([basepath filesep session.general.name '.behavior.mat'],'behavior');
end

end

