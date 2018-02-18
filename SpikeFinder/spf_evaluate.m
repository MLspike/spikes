function [score smooth delay spikecountadj scoreall] = spf_evaluate(spikecountest,spikecount)
% function [score smooth delay spikecountadj scoreall] = spf_evaluate(spikecountest,spikecount)

[smooth out] = fminbnd(@(x)smoothcorr(spikecountest,spikecount,x),0,1);
score = 1-out;
if nargout>=2
    [~, spikecountadj delay outall] = smoothcorr(spikecountest,spikecount,smooth);
    scoreall = 1-outall;
end

%---
function [out spikecountadj delay outall] = smoothcorr(spikecountest,spikecount,smooth)

dtspikes = .01;
spikecountadj = fn_filt(spikecountest,smooth/dtspikes,'lk');
ncell = size(spikecount,2);
minlag = -5; % corresponds to -50ms
maxlag = 20; % corresponds to 200ms
outall = zeros(1-minlag+maxlag,ncell);
for i=1:ncell
    ntc = find(~isnan(spikecount(:,i)),1,'last');
    spkcib = fn_bin(spikecount(1:ntc,i),4);
    xi = spikecountadj(:,i);
    if ~any(xi)
        % no spike estimated -> consider correlation is zero (out is one)
        outall(:,i) = 1;
    else
        for k=minlag:maxlag
            if k<0
                xij = [zeros(-k,1); xi(1:end+k)];
            elseif k==0
                xij = xi;
            elseif k>0
                xij = [xi(1+k:end); zeros(k,1)];
            end
            xijb = fn_bin(xij(1:ntc),4);
            c = corrcoef(xijb,spkcib);
            c(isnan(c)) = 0;
            outall(1-minlag+k,i) = 1-c(1,2);
        end
    end
end
out = mean(outall,2);
[out lag] = min(out);
outall = outall(lag,:);
k = minlag-1+lag;
delay = k*dtspikes;
if k<0
    spikecountadj = [zeros(-k,ncell); spikecountadj(1:end+k,:)];
elseif k>0
    spikecountadj = [spikecountadj(1+k:end,:); zeros(k,ncell)];
end
