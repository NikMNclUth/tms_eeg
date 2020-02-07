function [EEG,pulse] = chopdata(EEG,cfg)
nevent = length(EEG.event);
pulse=logical([]);
latencies=[];
for i=1:nevent
    if strcmpi(EEG.event(i).type,cfg.EventCode)
        pulse(i)=1;
        latencies=[latencies EEG.event(i).latency];
    else
        pulse(i)=0;
    end
end


%define the first and last pulse events (i.e., minimal clipping of data)
firsti=find(pulse,1,'first');
lasti=find(pulse,1,'last');
buffer=10*cfg.srate_orig; %10 seconds * sampling rate
breakpoints=EEG.event(firsti).latency-buffer;
if breakpoints<1; breakpoints=1; end %in case a 10 sec buffer doesn't precede the first pulse, just take the first sample.
gap_idx=find(diff(latencies)>buffer); %find the gaps in pulse events that are longer than the buffer
for i=1:numel(gap_idx) %define breakpoints by these gaps
    breakpoints=[breakpoints latencies(gap_idx(i))+buffer latencies(gap_idx(i)+1)-buffer];
end


%in case the 10 sec buffer goes longer than the data, clip it to the size
%of the continuous data
breakpoints=[breakpoints EEG.event(lasti).latency+buffer];
if breakpoints(end) > size(EEG.data,2)
    breakpoints(end)=size(EEG.data,2);
end
%check that all breakpoints are non-overlapping (i.e. if buffer is 10s, and
%the gap is <2*buffer (e.g., 15s), then might as well keep all that together)
if any(diff(breakpoints)<0)
    clip=find(diff(breakpoints<0));
    clip=sort([clip clip+1]);
    breakpoints(clip)=[];
end
breakpoints=reshape(breakpoints, [2 length(breakpoints)/2])';
plot(EEG.data(10,:),'r'); hold on; %plot segmented sections, make sure it looks how you want it.
for i=1:size(breakpoints,1)
    plot(breakpoints(i,1):breakpoints(i,2),EEG.data(10,breakpoints(i,1):breakpoints(i,2)),'b');
end
EEG=pop_select(EEG,'point',breakpoints);













end