function [EEG,cfg,cond_offset] = pulsehandler(EEG,cfg,EventCode,TrialStart,TrialEnd,PulseLen,PulseShift,conditions,pulse,srchoice)
disp('REMOVING THE PULSE ARTIFACT')
EEGbeforeRemoval = EEG; % SAVE FOR PLOTTING PURPOSES
cnt = 1;clear PulseStart PulseEnd
if ~exist('conditions','var') || isempty(conditions)
    disp('NO PAIRED PULSE EVENTS FOUND. MOVING ON, ASSUMING ALL DATA IS SINGLE PULSE.')
    cflag=false;
else
    %     cond=1;
    disp([ int2str(sum(conditions>0)) ' PAIRED PULSE EVENTS FOUND. ADJUSTING INTERPOLATION ACCORDING TO TRIAL ORDER.'])
    cond_offset=conditions./(1000/EEG.srate);
    cflag=true;
end
for kk = 1:length(EEG.event)
    if strcmp(num2str(EEG.event(kk).type), num2str(EventCode))
        TStart = ceil(EEG.event(kk).latency + TrialStart/1000*EEG.srate);
        if TStart <= 0
            error('Insufficient preTMS data for the first trial! Remove the first event');
        end
        TEnd = ceil(EEG.event(kk).latency + TrialEnd/1000*EEG.srate - 1);
        if TEnd > EEG.pnts
            error('Insufficient postTMS data for the last trial! Remove the last event');
        end
        PulseStart(cnt) = ceil(EEG.event(kk).latency + (PulseShift/1000*EEG.srate));
        if cflag && conditions(cnt)<PulseLen
            PulseEnd(cnt) = ceil(PulseStart(cnt) + floor(PulseLen/1000*EEG.srate) + cond_offset (cnt));
        else
            PulseEnd(cnt) = ceil(PulseStart(cnt) + floor(PulseLen/1000*EEG.srate));
        end
        x = ceil([TStart : PulseStart(cnt)-1,PulseEnd(cnt) + 1 : TEnd]);
        y = EEG.data(:, x);
        xi = floor(PulseStart(cnt) : PulseEnd(cnt));
        EEG.data(:,xi) = interp1(x, y', xi)';
        if cflag && conditions(cnt)>15
            x = x + cond_offset(cnt); %shift time indices to account for longer IPIs
            y = EEG.data(:, x);
            xi = xi + cond_offset(cnt);
            EEG.data(:,xi) = interp1(x, y', xi)';
        end
        if cnt == 1
            firstPulseMS = EEG.event(kk).latency/(EEG.srate/1000);
        end
        cnt = cnt + 1;
    end
end

disp(['FOUND:' num2str(cnt-1) ' EVENTS TO REMOVE PULSE']) %corrected for overcounting in above loop by 1, CPW--5-22-18

if ~exist('conditions','var') || isempty(conditions)
    disp('NO PAIRED PULSE EVENTS FOUND. MOVING ON, ASSUMING ALL DATA IS SINGLE PULSE')
    cond_offset = [];
else
    cond=1;
    cond_offset=conditions./(1000/EEG.srate);
    for i=find(pulse)
        EEG.event(i).latency=EEG.event(i).latency + cond_offset(cond);
        cond=cond+1;
    end
end

cfg.srate_orig = EEG.srate;
if ~isempty(srchoice)
    if EEG.srate >= 1000
        disp('Downsampling to 1KHz')
        EEG = pop_resample(EEG , 1000);
    else
        error('Sampling rate should be greater than 1000 Hz!');
    end
    disp('DOWNSAMPLING TO 1KHz')
else
    EEG = pop_resample(EEG , srchoice);
end

%% PLOT THE PULSE ARTIFACT BEFORE AND AFTER PULSE REMOVAL REJECTION
close all;  colordef white %added colordef clarification just in case CPW--5/22/18
plot(EEGbeforeRemoval.times-firstPulseMS,squeeze(EEGbeforeRemoval.data(10,:,:)),'b','LineWidth',1); hold all; box off;
plot(EEG.times-firstPulseMS,squeeze(EEG.data(10,:,:)),'r','LineWidth',1); hold all; box off;
line([PulseShift/(EEG.srate/1000) PulseShift/(EEG.srate/1000)+PulseLen],[500 500],'Color','k','LineStyle','--','LineWidth',2); hold all;
line([PulseShift/(EEG.srate/1000) PulseShift/(EEG.srate/1000)],[-500 500],'Color','k','LineStyle','--','LineWidth',2); hold all;
text(PulseShift/(EEG.srate/1000), 1500, [num2str(PulseShift/(EEG.srate/1000)) 'ms Pulse Shift, ' num2str(PulseLen) 'ms Pulse Duration']);
xlim([-20 50]); box off; xlabel('Time (ms)'); ylabel('uV');
% REMOVE UNDERLINES SO TITLE DOESN'T HAVE UNDERSCORES
tt = cfg.fullCondName;tm = strfind(tt,'_');for ji = 1:length(tm);tt(tm(ji)) = ' ';end;title(tt);
h = legend({'Before Pulse Removal';'After Pulse Removal'},'Location','SouthEast');legend boxoff
cd(cfg.folderPath);cd('QC');savefig([cfg.fullCondName '_QC_PulseRemoval'],16,16,150,'',4,[10 8]);























end