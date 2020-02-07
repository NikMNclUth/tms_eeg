function [prEEG,events2remove,pr_trlorder] = test_pulses2(EEG,eventcode,stimchan,pulseorder)
% test_pulses2 - update to the much loved but relatively inefficient get_pulse_type_and_order
% Use to find irrelevant triggers, and track non-pulse events.
% Will generate an empirical pulse order and test this aginst the original
% pulse order. Sections can be commented out as required.
%
% 1) The first section identifies all trials with comment markers and
% treats them as indicators of incorrect data or unrelated sections of the
% report.
%
% 2) After finding where the TMS data begins non-pulse events are
% identified by finding anything not contaiing the eventcode. Trial indices
% are taken from the EVENT.urevent field.
%
% 3) Generate a list of single and paired pulses by detecting the highest
% peaks in a z-transformed window of the period -10ms to 35ms from the
% first pulse (assuming paired pulse ISI of 25ms ---- alter as needed).
%
% 4) Identify misfires by estimating triggers with a latency difference
% (from index +1) of less than 2 seconds. The find trials that don't
% contain clear peaks and treat as noise to be removed.
%
% 5) Finalise the trials based on the UREVENT index and apply to a copy of
% the original data structure.
% Will indicate if data match the original, intended pulse sequence or not.
% IF DATA DO NOT MATCH YOU WILL NEED TO MANUALLY INSPECT AND CORRECT THE
% PROBLEM.
%
% Inputs
% - EEG = EEGlab event structure
% - eventcode = code for stimulation events (e.g. 'R128')
% - stimchan = index of channel to use for test purposes
% - pulseorder = pulse sequence given to TMS device
%
% Outputs
% - prEEG = pruned EEG - all non-event trials removed
% - events2remove = indices of events to remove from raw data structure
% - pr_trlorder = pruned trial order - compare with original order
% Nicholas Murphy (2019) - Baylor College of Medicine



%% 1) Identify Comment Markers and Set Updated Start Point if Needed
comments = 1:size(EEG.event,2);
for iter = 1:size(EEG.event,2)
    e = EEG.event(1,iter).value;
    if ~strcmp('Comment',e);comments(iter)=0;end
end
comments(comments==0)=[];
remove = 1:max(comments);
TEMP = EEG;
TEMP = pop_editeventvals( TEMP,'delete',remove);
clear e

%% 2) Identify remaining non-pulse events
npevents = 1:size(TEMP.event,2);
npu = []; count = 0;
for iter = 1:size(TEMP.event,2)
    e = TEMP.event(1,iter).type;
    if strcmp(eventcode,e);npevents(iter)=0; end
    if ~strcmp(eventcode,e);count = count+1; npu(count) = TEMP.event(1,iter).urevent;end
end
npevents(npevents==0)=[];
TEMP = pop_editeventvals( TEMP,'delete',npevents);
clear count

if size(TEMP.event,2) == max(size(pulseorder))
    events2remove = [remove,npu];
    prEEG = pop_editeventvals(EEG,'delete',events2remove);
    pr_trlorder = [];
else
    
    %% 3) Find Single and Paired Pulses
    TEMP = pop_resample(TEMP , 1000);
    TEMP = eeg_checkset(TEMP);
    TEMP = pop_epoch(TEMP, {  }, [-1.5  1.5], 'newname', 'tmstest epochs', 'epochinfo', 'yes');
    TEMP = eeg_checkset(TEMP);
    TEMP = pop_rmbase( TEMP, [-200    -10]);
    time = TEMP.times;
    % ISI = 25;
    % stimchan = 3;
    test = zscore(abs(squeeze(TEMP.data(stimchan,find(time==-10):find(time>34.9&time<35.1),:))'),[],2);
    for iter = 1:size(test,1)
        test(iter,:)  =  gaussmooth_signal( test(iter,:),10 );
        % smooth to aid peak detection
    end
    trls = zeros(size(TEMP.event,2),1);
    for iter = 1:numel(trls)
        [PKS,~]=findpeaks(test(iter,:),'NPeaks',2,'MinPeakHeight',1);
        if numel(PKS) == 1
            trls(iter) = 1;
        elseif numel(PKS) == 2
            trls(iter) = 2;
        else
            trls(iter) = 999;
        end
        clear PKS
    end
    % sum(trls(3:end,:) == pulse');
    
    
    %% 4) Identify potential misfires
    % latency approach
    [epochstest,~]=events2epoch(eventcode,TEMP);
    lats = (diff(epochstest(:,2)))/TEMP.srate; % convert to ms
    misfires1 = find(lats<2)+1;
    % check1 = numel(epochstest(:,2))==numel(pulse);
    
    % content approach
    pks = zeros(size(TEMP.event,2),1);
    for iter = 1:numel(trls)
        [PKS,~]=findpeaks(test(iter,:),'MinPeakHeight',0.5);
        % we expect the amplitude to be well below this in trials where the
        % coil was correctly in place. The more peaks there are that approach
        % the same height the more we can be certain that this is not a proper
        % trial
        pks(iter) = numel(PKS);
        clear PKS
    end
    maxpks = 2;
    misfires2 = find(pks>maxpks);
    
    misfires = [misfires1;misfires2]';
    msfu = []; count = 0;
    for iter = misfires
        count = count+1;
        msfu(count) = TEMP.event(1,iter).urevent;
    end
    pr_trlorder = pks; pr_trlorder(misfires)=[];
    
    %% 5) Finalise trials to remove
    
    
    events2remove = [remove,npu,msfu];
    prEEG = pop_editeventvals(EEG,'delete',events2remove);
    
    % does the output match the input trial order?
    
    if size(prEEG.event,2) == max(size(pulseorder))
        disp('number of retained pulses equal to apriori pulse order')
    else
        disp('number of retained pulses does not match apriori pulse order')
    end
    if size(prEEG.event,2) == max(size(pulseorder)) & sum(pr_trlorder) == sum(pulseorder)
        disp('trials match')
    else
        disp('trials do not match. please inspect')
    end
    
end




end