%% Clear prior saves for new cumulative metrics
% load('Z:\home\Lindsay\Barrage\combinedPaths.mat');
% paths_save = [];
% save('Z:\home\Lindsay\Barrage\combinedPaths.mat', 'paths_save');
% load('Z:\home\Lindsay\Barrage\ratPaths.mat');
% paths_save = [];
% save('Z:\home\Lindsay\Barrage\ratPaths.mat', 'paths_save');
% load('Z:\home\Lindsay\Barrage\mousePaths.mat');
% paths_save = [];
% save('Z:\home\Lindsay\Barrage\mousePaths.mat', 'paths_save');

%% Set paths to be run
main = "Z:\Data\AYAold\";
% main = "Y:\SMproject\";
% paths = ["AYA10\day31"];
paths = ["AB4\day03"; "AB4\day07"; "AB4\day08"; "AB4\day09"; "AB4\day11";...
    "AYA6\day17"; "AYA6\day19"; "AYA6\day20"; ...
%     "AYA7\day19" ; "AYA7\day20"; "AYA7\day22"; "AYA7\day24"; ...
%     "AYA7\day25"; "AYA7\day27"; "AYA7\day30"; ...
    "AYA7\day24"; "AYA7\day25";...
    "AYA9\day15"; "AYA9\day16"; "AYA9\day17"; "AYA9\day20"; ...
    "AYA10\day25"; "AYA10\day27"; "AYA10\day31"; "AYA10\day32"; "AYA10\day34"];

bigSave = 'Z:\home\Lindsay\Barrage\ratPaths.mat'; %change to mouse, potentially - change below as well
comSave = 'Z:\home\Lindsay\Barrage\combinedPaths.mat';

%% Set main parameters
ifHSE = 0; %Run detection
    ifUseMet = 1; %Load in previous metrics
    ifDetUn = 1; %Choose only high firing rate units
    ifPickUn = 0; %Choose only units that fire many spikes during events
    ifPare = 1; %Keep only the events with so many spikes
ifPSTH = 1; %Get analytical plots for each run
ifAnalysis = 0; %Run analytical plots
ifBigPSTH = 0;
ifCum = 0; %Run cumulative metrics analysis
bigCCG = 0; %Get population CCG
bigDur = 0; %Get population event duration distribution (box plot)

if ~ifUseMet
    useMet.nSigma = 3;
    useMet.tSmooth = 0.02;
    useMet.binSz = 0.005;
    useMet.tSepMax = 0.01; %was playing with 0.005, 0.1
    useMet.mindur = 0.05;
    useMet.maxdur = 10;
    useMet.lastmin = 0.05;
    useMet.sstd = -1*(useMet.nSigma-0.1); %sets start to nSig+sstd %-1*(useMet.nSigma-2);
    useMet.estd = (useMet.nSigma-0.1); %sets end to nSig-sstd %(useMet.nSigma-2);
    useMet.EMGThresh = 0.8;
    
    useMet.Hz = 50; useMet.ft = 0.1; useMet.numEvt = 2;
    useMet.bound = 3; useMet.useSpkThresh = 0.3;
    
    useMet.unMin = 2; useMet.spkNum = 4; useMet.spkHz = 60; useMet.unMax = 0; 
end

%% Iterate through our sessions
for p = 1:length(paths)
    
    % Set naming conventions for session p
    cd(strcat(main,paths(p)));
    curPath = convertStringsToChars(paths(p));
    basepath = convertStringsToChars(strcat(main,curPath));
    basename = convertStringsToChars(basenameFromBasepath(basepath));
    animName = animalFromBasepath(basepath);
    if ~exist(strcat(basepath,'\','Barrage_Files'))
        mkdir('Barrage_Files');
    end
    savePath = convertStringsToChars(strcat(basepath, '\Barrage_Files\', basename, '.'));
    
    if ifHSE
        if ifUseMet
            load([savePath 'useMetNew.mat']);
        end
        mkSpks([basepath '\Barrage_Files']); %this is still bulky, add check to see if already made
        
        % Detect high firing units
        if ifDetUn
            unitsForDetection(useMet.Hz,useMet.ft,useMet.numEvt);
            loadPath = strcat(basepath,'\Barrage_Files\',basename,'.useSpk.cellinfo.mat');
            
            %Only keep units that fire enough spikes in detected events
            if ifPickUn
                bound = useMet.bound; bound = useMet.spkThresh;
                [~,useSpkThresh,~,bound] = pickUns(bound,useSpkThresh,0.05,useMet,loadPath, useMet.Hz, useMet.ft, useMet.numEvt);
                [~,normSpkThresh,~,bound] = pickUns(bound,useSpkThresh,-0.01,useMet,loadPath, useMet.Hz, useMet.ft, useMet.numEvt);
                checking = burstCellDetection(normSpkThresh,loadPath);
                useMet.bound = bound;
                useMet.spkThresh = normSpkThresh;
                note_all = "PickUns";
            else
                note_all = "DetectUn";
            end
        else
            note_all = "No pre-vetting";
        end
        
        if exist([savePath 'HSEfutEVT.mat'])
            load([savePath 'HSEfutEVT.mat']);
            runLast = size(evtSave,1);
        else
            runLast = 0;
        end
        runNum = runLast+1;
        load([basepath '\' basename '.cell_metrics.cellinfo.mat']);    
        if ifDetUn
            load([savePath 'useSpk.UIDkeep.mat']);
            load([savePath 'useSpk.cellinfo.mat']); %load in the spikes that we've picked and run to save
        else
            load([savePath 'CA2pyr.cellinfo.mat']);
            UIDkeep = spikes.UID;
            save([savePath 'useSpk.UIDkeep.mat']);
        end
        HSE = find_HSE_b('spikes',spikes,...
                        'nSigma',useMet.nSigma,'binSz',useMet.binSz,...
                        'tSmooth',useMet.tSmooth,'tSepMax',useMet.tSepMax,...
                        'mindur',useMet.mindur,'maxdur',useMet.maxdur,...
                        'lastmin',useMet.lastmin,'EMGThresh',useMet.EMGThresh,...
                        'Notes',note_all,'sstd',useMet.sstd,'estd',useMet.estd,...
                        'recordMetrics',true,'neuro2',true,'runNum',runNum);
        if ifPare
            HSE = pareEvt(HSE, spikes, useMet.unMin, useMet.spkNum, useMet.spkHz, useMet.unMax);
        end
        % Save
        save([savePath 'useMetNew.mat'],'useMet');
        load(bigSave);
        paths_save = [paths_save; strcat(main,paths(p))];
        save(bigSave, 'paths_save');
        paths_save = [];
        load(comSave);
        paths_save = [paths_save; strcat(main,paths(p))];
        save(comSave, 'paths_save');
    end
    if ifAnalysis
        BarAnalysis(strcat(main,paths(p)));
    end
    if ifPSTH
        regionPSTH();
        close all
    end
    if bigDur
        load(strcat(basepath,'\Barrage_Files\',basename,'.HSE.mat'));
        if p==1
            useGroup = [];
            ugc = 1;
            totDurX = HSE.timestamps(:,2)-HSE.timestamps(:,1);
            useGroup{ugc} = animName;
            totDurG = ugc*ones(size(totDurX,1),1);
            totDurLab = [paths(p)];
        else
            tempName = [];
            tempName = animName;
            if find(contains(useGroup, tempName))
                ugc = find(contains(useGroup, tempName));
            else
                ugc = length(useGroup) + 1;
                useGroup{ugc} = animName;
            end
            tempDur = []; tempDur = HSE.timestamps(:,2)-HSE.timestamps(:,1);
            totDurX = [totDurX; tempDur];
            totDurG = [totDurG; ugc*ones(size(tempDur,1),1)];
            totDurLab = [totDurLab paths(p)];
        end
    end
    if bigCCG
        load([savePath 'CCG_dat.mat']);
        if p == 1
            CCGsum = zeros(length(CCG_dat.time),length(paths));
        end
        CCGsum(:,p) = zscore(CCG_dat.y);
    end
end

if ifBigPSTH
    
end

if ifCum
    NewMetComb("rat");
end
if bigDur
    figure(2);
    boxplot(totDurX,totDurG);title('Barrage Duration Across Animals');ylabel('Duration (s)');
    xticklabels(useGroup);
    saveas(gcf,'Z:\home\Lindsay\Barrage\ratEvtBox.png');
end
if bigCCG
    CCG_mean = mean(CCGsum,2);
    CCG_low = CCG_mean - (std(CCGsum,0,2)/sqrt(size(CCGsum,2)));
    CCG_high = CCG_mean + (std(CCGsum,0,2)/sqrt(size(CCGsum,2)));
    figure(3);
    hold on
    plot(CCG_dat.time, CCG_mean, 'k');
    plot(CCG_dat.time,CCG_low, 'Color', [0.25 0.25 0.25], 'LineStyle', ':');
    plot(CCG_dat.time,CCG_high, 'Color', [0.25 0.25 0.25], 'LineStyle', ':');
    saveas(gcf,'Z:\home\Lindsay\Barrage\ratCCG.png');
end
