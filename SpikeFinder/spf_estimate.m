function [spikecountest fit drift spikecountadj] = spf_estimate(calcium,spikecount,par,tbin,baselinerange,smooth,delay)
% function [spikecountest fit drift spikecountadj] = spf_estimate(calcium,spikecount,par,tbin,baselinerange[,smooth,delay])
%---
% here, calcium and spikecount are vectors (i.e. a single recording)

% estimate
ntcalcium = length(calcium);
ntc = find(calcium~=0,1,'last');
calcium = calcium+1; % note that calcium is expressed in DF/F, while we need F or F/F0
% (cut and bin)
calciumbin = fn_bin(calcium(1:ntc),[tbin 1]);
% (estimate)
dtcalcium = par.dt;
dtspikes = .01;
if tbin>1
    par.dt = dtcalcium*tbin;
end
if baselinerange
    par.F0 = [min(calcium) prctile(calcium,baselinerange)];
end
[spikecountest, fit, ~, ~, ~, drift] = tps_mlspikes(calciumbin,par);
% (unbin and uncut)
if tbin>1
    if dtcalcium~=dtspikes, error 'not sure that tbin>1 compatible with dtcalcium~=dtspikes', end
    spikecountest = fn_enlarge(spikecountest,ntc,0);
    fit = fn_enlarge(fit,ntc);
    drift = fn_enlarge(drift,ntc);
end
if ntc<ntcalcium
    spikecountest(ntc+1:length(calcium),:) = 0;
    fit(ntc+1:length(calcium),:) = 1;
    drift(ntc+1:length(calcium),:) = 1;
end
% (resample estimated spikes at 100Hz)
spikecountest_dtcalcium = spikecountest;
if dtcalcium~=dtspikes
    switch par.algo.estimate
        case 'MAP'
            spiketimes = fn_timevector(spikecountest_dtcalcium,dtcalcium);
            spikecountest = fn_timevector(spiketimes,(0:size(spikecount,1)-1)*dtspikes);
        otherwise
            spikecountest = interp1((0:ntcalcium-1)*dtcalcium,spikecountest_dtcalcium,(0:size(spikecount,1)-1)*dtspikes);
    end
end
if strcmp(par.algo.estimate,'samples')
    spikecountest = mean(spikecountest,2);
    fit = mean(fit,2);
    drift = mean(drift,2);
end

% smooth+delay?
if nargin>=6
    spikecountadj = fn_filt(spikecountest,smooth/dtspikes,'lk');
    k = round(delay/dtspikes);
    if k<0
        spikecountadj = [zeros(-k,1); spikecountadj(1:end+k)];
    elseif k>0
        spikecountadj = [spikecountadj(1+k:end); zeros(k,1)];
    end
else
    spikecountadj = spikecountest;
end

% display (split it to multiple rows)
fn_figure('SPF TRAIN')
spf_displayonecell(struct('method',par.algo.estimate,'dtcalcium',dtcalcium,'calcium',calcium, ...
    'spikecount',spikecount,'spikecountest',spikecountest_dtcalcium,'fit',fit,'drift',drift))
