function [EEG,COND,artchan,arttrial,preEEG] = cleanup(EEG,cfg,TrialStart,TrialEnd,EventCode,conditions)

disp('REMOVE BAD TRIALS AND CHANNELS');pause(1)
EEG = pop_epoch(EEG, {EventCode}, [TrialStart/1000 TrialEnd/1000]);
if length(EEG.times) > size(EEG.data,2)
    timer = linspace(TrialStart,TrialEnd,size(EEG.data,2));
    EEG.times = timer;
end
preEEG=EEG;
% IDENTIFY AND REMOVE BAD TRIALS
[arttrial] = identifyarttrial(EEG, cfg);
disp(['BAD TRIALS: ' num2str(arttrial')]); pause(1)
EEG = pop_select(EEG, 'notrial', arttrial);
% IDENTIFY AND REMOVE BAD CHANNELS
artchan = identifyartchan(EEG,cfg);
disp(['BAD CHANNELS: ' num2str(artchan)]); pause(1)
EEG = eeg_interp(EEG, artchan);
COND=conditions; COND(arttrial)=[];


end