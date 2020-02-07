%% TMS-EEG Pipeline 

% The following pipeline is intended to demonstrate the steps utilized for efficient cleaning of TMS-EEG data.
% It can feasibly be turned into a loop and automated, however, caution is recommended due to the likelihood of 
% skipping out sensory evoked potentials.

% This pipeline makes use of original functions as well as TESA and ARTIST
% functions. 

% Version 1.1 Nicholas Murphy, Baylor College of Medicine, 2019

%% Setup workspace and load data

%% FIRST 2 PULSES NEED TO BE REMOVED 
% setup_analysispath option 5 adds all of the functions and files needed
% for this specific analysis
% addpath('/home/nmurphy/'); % this is the path to setup_analysispath.m
addpath('file path containing folders needed');
% load appropriate file
eeglab
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%aw%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
EEG = pop_fileio('file path containing tms eeg data'); %%%%% MODIFY PER PARTICIPANT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 0,'setname','tmstest','gui','off');
EEG = eeg_checkset( EEG );
EEG=pop_select(EEG,'nochannel',65);
% load tms sequence and channel locations
load('pulse sequence)
load('channel locations');
EEG.chanlocs = chanlocs;

[epochstest]=events2epoch([],EEG);
%% Organise Pulses

%%% Becasuse human error can creep in and mess up the pulse order this
%%% section determines an empirical pulse order based on the content of
%%% each epoch
[ empirical_pulse_order, non_pulse_events ] = get_pulse_type_and_order( EEG, 3, 0, 'R128',0 ,1);
EEG = pop_editeventvals( EEG,'delete',non_pulse_events);

% pulses_to_remove=[1,2,3,4,5,6,7,8]; 
% EEG = pop_editeventvals( EEG,'delete',pulses_to_remove);
% EEG.chanlocs = chanlocs;
% %add pulses here manually 
% empirical_pulse_order=empirical_pulse_order(:,9:end);%change the value here manually 
%%always check this to see if it matches the pulse order
po = empirical_pulse_order(2,:);
isempty(find(po~=pulse)) % should be 1

for iter = 1:numel(EEG.event)
    EEG.event(iter).type = '1';
end
% create trials conditions variable to use with ARTIST functions.
conditions = po;
for iter = 1:length(conditions)
    if conditions(iter) == 1
        conditions(iter) = 0;
    elseif conditions(iter) == 2
        conditions(iter) = 25;
    end
end

%% Setup ARTIST Configuration

cfg.EventCode = '1';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cfg.TMSEEGrootFolder = 'filepath name goes here';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
cfg.TrialStart  = -1500; % milliseconds
cfg.TrialEnd = 1500;
cfg.PulseLen = 20; % this covers the pre and post periods
cfg.PulseShift = -10;
cfg.BaseLine = [-300,-100]; % milliseconds
cfg.plottimes = [15,25,40,60,75,100,150,200,300];
cfg.NameProject = '';
cfg.NameCond = ''; 
cfg.NameSub = ''; 
cfg.srate_orig = 5000;
cfg.decaythr = 5;

EventCode = cfg.EventCode;
TrialStart = cfg.TrialStart;
TrialEnd = cfg.TrialEnd;
PulseLen = cfg.PulseLen;
cfg.TMSlength = cfg.PulseLen;
PulseShift = cfg.PulseShift;
BaseLine = cfg.BaseLine;
cfg.plottimes = [15,25,40,60,75,100,150,200,300];
T = TrialEnd - TrialStart;
disp(['Using ' num2str(cfg.TrialStart) 'ms before TMS pulse'])
disp(['Using ' num2str(cfg.TrialEnd) 'ms after TMS pulse'])
disp(['Using ' num2str(cfg.BaseLine(1)) 'ms to ' num2str(cfg.BaseLine(2)) 'ms for baseline'])
disp(['Will interpolate ' num2str(cfg.PulseLen) 'ms around the TMS pulse'])
disp('If any of these settings are wrong, stop now and rerun');pause(2)

%% Setup plotting folders
if ~isfield(cfg, 'NameProject'); cfg.NameProject = ''; end
if ~isfield(cfg, 'NameCond'); cfg.NameCond = ''; end
if ~isfield(cfg, 'NameSub'); cfg.NameSub = ''; end
if ~isdir([cfg.TMSEEGrootFolder filesep cfg.NameProject]);mkdir([cfg.NameProject]);end;cd([cfg.TMSEEGrootFolder filesep cfg.NameProject])
if ~isdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub]);mkdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub]);end;cd([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub])
if ~isdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond]);mkdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond]);end;cd([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond])
cfg.folderPath = ([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond]);
cfg.fullCondName = [cfg.NameProject '_' cfg.NameSub '_' cfg.NameCond];
if ~isdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond filesep 'ICA1']);mkdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond filesep 'ICA1']);end;
if ~isdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond filesep 'ICA2']);mkdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond filesep 'ICA2']);end;
if ~isdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond filesep 'ICA3']);mkdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond filesep 'ICA3']);end;
if ~isdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond filesep 'QC']);mkdir([cfg.TMSEEGrootFolder filesep cfg.NameProject filesep cfg.NameSub filesep cfg.NameCond filesep 'QC']);end;

%% CHOP CONTINUOUS DATA TO SEGMENT MORE CLOSELY TO THE STIMULATION BLOCKS
% Use this section to cut down unnecessary segments of the continuous data
% to improve ICA performance
[EEG,pulse] = chopdata(EEG,cfg);

%% REMOVE THE PULSE ARTIFACT AND DOWNSAMPLE TO 1KHZ
% Use this section to remove the pulse period and replace with a linear
% interpolation
[EEG,cfg,cond_offset] = pulsehandler(EEG,cfg,EventCode,TrialStart,TrialEnd,PulseLen,PulseShift,conditions,pulse);

%% DETREND THE CONTINUOUS DATA
% remove linear trends from the data
[EEG,TREND] = detrend_tms(EEG,cfg,TrialStart,TrialEnd,EventCode,T);
%% EPOCHED DATA
EEGepoch = pop_epoch(EEG, {EventCode}, [TrialStart/1000 TrialEnd/1000]);
%% 1ST STAGE: USE ICA ON THE CONTINUOUS DATA TO REMOVE BIG-AMPLITUDE DECAY ARTIFACT
% ICA #1 is performed on the whole scalp data (future version will seek to
% identify bad channels and trials here --- although the cleanup function
% might work)
% Here we find decay artifacts and remove them from the data using data
% driven approaches


disp('ICA ROUND 1 - REMOVE LARGE AMPLITUDE DECAY ARTIFACT');pause(1)
[~, indelec,measure] = pop_rejchan(EEGepoch,'threshold',3,'measure','kurt','norm','on');
ic_chans = 1:size(EEG.data,1);ic_chans(indelec) = [];
EEGepoch = pop_reref(EEGepoch,[],'keepref','on','exclude',indelec);
EEG = pop_reref(EEG,[],'keepref','on','exclude',indelec);
% INFOMAX ICA
EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 0, 'pca', EEG.nbchan - 1, 'interupt', 'off');

% COPY THE ICA PARAMETERS TO THE EPOCHED DATA
EEGepoch.icaweights = EEG.icaweights;
EEGepoch.icasphere = EEG.icasphere;
EEGepoch.icawinv = EEG.icawinv;
% use TESA and ARTIST methods to find the components with varying levels of
% decay\
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
savepath = 'filepath to save to'; % update
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
[artcomp,tcomps] = classifydecayartTESA(EEGepoch,cfg,savepath);

% PLOT ICA MAPS
%%%% Although the TESA and ARTIST functions accurately find decay 
%%%% here you should manually inspect the components and determine which to
%%%% leave in and take out based on the suggestions above

ARTIST_plotICA(EEGepoch, cfg, artcomp, 1)
f = find(tcomps == 1);
manadd = [2]; % components to add manually
manrem = []; % components to remove from suggestions
out = unique([artcomp';f;manadd']);
if ~isempty(manrem);ff = find(out == manrem);end
if ~isempty(manrem);out(ff) = []; end% remove suggested components from final selection
clear f manadd manrem ff
EEG = pop_subcomp(EEG, out);

%% ADD THE TRENDS BACK IN FOR FILTERING ON CONTINUOUS DATA
EEG.data=EEG.data+TREND.data;

%% BANDPASS FILTER CONTINUOUS DATA BETWEEN 1 AND 100 Hz
disp('BANDPASS FILTER 1:100Hz');pause(1)
lcut = 1;hcut = 100;
EEG = pop_eegfiltnew(EEG, lcut, 0);
EEG = pop_eegfiltnew(EEG, 0, hcut);

%% NOTCH FILTERING TO REMOVE LINE NOISE
disp('NOTCH FILTER (LINE NOISE REMOVAL) at 60 Hz');pause(1)
EEG = pop_eegfiltnew(EEG, 58, 62, 2000*EEG.srate/1000, 1);

%% 2ND STAGE: IDENTIFY AND REMOVE BAD TRIALS AND CHANNELS
% Finds clusters of bad channels and trials, removes and replaces with
% interpolated data, bad data are output as artchan and arttrial. trial
% order is updated

[EEG,COND,artchan,arttrial,preEEG] = cleanup(EEG,cfg,TrialStart,TrialEnd,EventCode,conditions);

%% 3RD STAGE: REMOVE THE REMAINING ARTIFACTS
% Uses ARTIST routines to find biological and environment noise components

disp('ICA ROUND 2 - REMOVE REMAINING ARTIFACTS');pause(1)
% COMMON AVERAGE REFERENCE
EEG = pop_reref(EEG, []);
preEEG=pop_reref(preEEG, []);
% DETERMINE OPTIMAL COMPONENT NUMBER NUMBER USING PCA
CovM = EEG.data(:, :)*EEG.data(:, :)'/size(EEG.data(:, :), 2);
[~, D] = eig(CovM);
d = sort(diag(D), 'descend');
dd = zeros(1, length(d));
for l = 1:length(d)
    dd(l) = sum(d(1:l));
end
cntNumCompForICA = sum(dd/dd(end) < .999);
% INFOMAX ICA
EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 0, 'pca', cntNumCompForICA, 'interupt', 'off');
% LOAD TRAINED CLASSIFIER
load classifierweight.mat;
cfg.w = classifier.w;
cfg.b = classifier.b;
artcomp = classifyartcomp(cfg, EEG);

% PLOT ICA MAPS
ARTIST_plotICA(EEG, cfg, artcomp, 2)
preEEG_wclean = EEG;
% EEG = pop_subcomp(EEG);

% Manual Suggestions
compsadd = []; % manually selected components to add
compsrem = ismember(artcomp,[]);artcomp(compsrem)=[]; % components to remove from suggestions

% Final Components
finalcomps = [artcomp,compsadd];
EEG = pop_subcomp(EEG, finalcomps);

%% COMMON AVERAGE REFERENCE
disp('COMMON AVERAGE REFERENCING'); pause(1)
EEG = pop_reref(EEG, []);

%% BASELINE CORRECTION w.r.t -300 ~ -100 ms
disp('BASELINE CORRECTION'); pause(1)
EEG = pop_rmbase(EEG, [BaseLine(1), BaseLine(2)]);

%% PLOT TEP AND TOPOGRAPHY
close all;colormap(jet);
c=unique(COND);figure;
for cnt=1:size(c,2)
    xlimm = [-200 500]+c(cnt);
    fnameTitle = [cfg.fullCondName '_' int2str(c(cnt)) ' ms'];
    fnameTitletmp = strfind(fnameTitle,'_');for bb = 1:length(fnameTitletmp);fnameTitle(fnameTitletmp(bb)) = ' ';end
    tit = sprintf([fnameTitle ' \n Total trials: ' num2str(sum(COND==c(cnt))) ', Srate: ' num2str(round(cfg.srate_orig)) 'Hz, \n ' num2str(length(artchan)) ' Bad Channels, ' num2str(length(arttrial)) ' Bad Trials ']);title(tit,'FontSize',10);
    dat = squeeze(mean(EEG.data(:,EEG.times>xlimm(1) & EEG.times<xlimm(2),COND==c(cnt)),3));
    timtopo(dat,EEG.chanlocs,[-200,500,-1.5*max(max(dat)),1.5*max(max(dat))],cfg.plottimes,'',0,0,'shrink','on');box off
    cd(cfg.folderPath);cd('QC');savefig([cfg.fullCondName '_' int2str(c(cnt)) 'ms_TEP'],16,16,150,'',4,[10 8]);
    disp('SAVING FILE...')
    clf
    
end
%% Cut and Save
% Cut down the data to remove presence of edge artifacts in single trial
% data

EEG = pop_epoch(EEG, {EventCode}, [-1000/1000 1000/1000]);
preEEG = pop_epoch(preEEG, {EventCode}, [-1000/1000 1000/1000]);
preEEG_wclean = pop_epoch(preEEG_wclean, {EventCode}, [-1000/1000 1000/1000]);
cd(cfg.folderPath);save(cfg.fullCondName,'EEG','TREND','COND','arttrial','artchan','artcomp','cfg','conditions','preEEG','preEEG_wclean');
