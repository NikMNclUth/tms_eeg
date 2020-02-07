function [EEG,TREND] = detrend_tms(EEG,cfg,TrialStart,TrialEnd,EventCode,T)

disp('DETRENDING CONTINUOUS DATA')
TREND=EEG;
stimtrial = [];
for kk = 1:length(EEG.event)
    if strcmp(num2str(EEG.event(kk).type), num2str(EventCode))
        stimtrial = [stimtrial kk];
    end
end
for kk = 1:length(stimtrial)-1
    
    time1 = round(TrialStart/1000*EEG.srate + EEG.event(stimtrial(kk)).latency);
    time2 = round(TrialStart/1000*EEG.srate + EEG.event(stimtrial(kk + 1)).latency - 1);
    EEG.data(:, time1 : time2) = detrend(EEG.data(:, time1 : time2)','linear')';
    if kk==1; TASKSTART=time1; end
end
% LAST EPOCH
time = round([TrialStart/1000*EEG.srate:T/1000*EEG.srate] + double(EEG.event(stimtrial(end)).latency));
EEG.data(:, time) = detrend(EEG.data(:, time)','linear')';
TREND.data=TREND.data-EEG.data;

end