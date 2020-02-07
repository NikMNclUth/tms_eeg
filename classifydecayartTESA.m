function [artcomp,tcomps] = classifydecayartTESA(EEG,cfg,savepath)
% Reject Big decay artifact
artcomp = [];
W = EEG.icaweights*EEG.icasphere;
Wm = pinv(W);
source = reshape(W*EEG.data(:,:),[size(W,1), size(EEG.data,2), size(EEG.data,3)]);
plotTimeX = [-200,500];
[~,mt1] = min(abs(EEG.times-11));
[~,mt2] = min(abs(EEG.times-30));
tcomps = zeros(size(source,1),1);

[~,tp1] = min(abs(EEG.times-plotTimeX(1,1)));
[~,tp2] = min(abs(EEG.times-plotTimeX(1,2)));



for iter = 1:size(source,1)
    temp = squeeze(source(iter,:,:));
    tempCompZ = zscore(EEG.icawinv(:,iter));
    muscleScore = abs(mean(temp,2));
    winScore = mean(muscleScore(mt1:mt2,:),1);
    tmsMuscleRatio = winScore./mean(muscleScore);
    if tmsMuscleRatio >= 5
        tcomps(iter) = 1;
    end
    figure;
    subplot(2,3,[1,2]);
    plot(EEG.times,mean(temp,2),'k'); grid on; hold on;
    plot([0 0], get(gca,'ylim'),'r--');xlabel('Time (ms)');ylabel('Amplitude (a.u.)');
    subplot(2,3,[4,5]);
    topoplot(EEG.icawinv(:,iter),EEG.chanlocs,'electrodes','off');
    colorbar;
    temp1 = temp(tp1:tp2,:);
    subplot(2,3,[3,6]);
    imagesc(temp1','XData', plotTimeX);
    caxis([-max(abs(temp1(:))), max(abs(temp1(:)))]);
    xlabel('Time (ms)');
    ylabel('Trials');
    % save image
    fname = [savepath,'ica1_component',num2str(iter)];
    savefig(fname,16,16,150,'',4,[10 8]);
    close
end

for ii = 1:size(Wm, 2)
    sourcesig = squeeze(mean(abs(source(ii,(EEG.times<60)&(EEG.times>=cfg.PulseLen),:)), 3));
    if isfield(cfg, 'decaythr')
        I = find(sourcesig>cfg.decaythr); % find components with amplitude greater than a threshold
    else
        I = find(sourcesig>30);
    end
    if ~isempty(I)
        artcomp = [artcomp ii];
    end
end



end