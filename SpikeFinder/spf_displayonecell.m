function spf_displayonecell(x)

% time spec
dtspikes = .01;
if isfield(x,'dtcalcium'), dtcalcium = x.dtcalcium; else dtcalcium = .01; end
if isfield(x,'spikecount')
    spikemode = 'count'; 
    spikes = x.spikecount;
    dorealspikes = ~isempty(spikes);
elseif isfield(x,'spiketimes')
    spikemode = 'times';
    spikes = x.spiketimes;
    dorealspikes = ~isempty(spikes);
else
    dorealspikes = false;
end
doest = isfield(x,'fit');
if doest && ~strcmp(spikemode,'count'), error 'estimation results can be provided only as spike counts (not times)', end
doMAP = doest && isfield(x,'method') && strcmp(x.method,'MAP');
    
% display (split into sub-parts)
if strcmp(spikemode,'count') && dorealspikes
    ntspikes = length(x.spikecount);
    T = ntspikes*dtspikes;
    ntcalcium = floor(T/dtcalcium); % might be smaller than length(x.calcium)
else
    ntspikes = 0;
    ntcalcium = length(x.calcium);
end
if ntcalcium==0, clf, return, end
nsplit = 4;
[spikesplit spikestsplit calciumsplit fitsplit driftsplit] = deal(cell(1,nsplit));
for i=1:nsplit
    calciumsplit{i} = x.calcium(1+round((i-1)*ntcalcium/nsplit):round(i*ntcalcium/nsplit));
    if dorealspikes
        if strcmp(spikemode,'count')
            spikesplit{i} = spikes(1+round((i-1)*ntspikes/nsplit):round(i*ntspikes/nsplit));
            spikesplit{i} = fn_timevector(spikesplit{i},dtspikes);
        else
            Tfrac = ntcalcium*dtcalcium/nsplit;
            spikesplit{i} = spikes(spikes>=(i-1)*Tfrac & spikes<=i*Tfrac) - (i-1)*Tfrac;
        end
    end
    if doest
        spikecountest = x.spikecountest;
        if doMAP
            if length(spikecountest)==ntspikes 
                spikestsplit{i} = spikecountest(1+round((i-1)*ntspikes/nsplit):round(i*ntspikes/nsplit));
                spikestsplit{i} = fn_timevector(spikestsplit{i},dtspikes); 
            elseif length(spikecountest)==length(x.calcium)
                spikestsplit{i} = spikecountest(1+round((i-1)*ntcalcium/nsplit):round(i*ntcalcium/nsplit));
                spikestsplit{i} = fn_timevector(spikestsplit{i},dtcalcium);
            else
                error 'length mismatch'
            end
        else
            if length(spikecountest)==ntspikes
                spikecountest = interp1((0:ntspikes-1)*dtspikes,spikecountest,(0:ntcalcium-1)*dtcalcium,'linear',0);
            elseif length(spikecountest)~=length(x.calcium)
                error 'length mismatch'
            end
            spikestsplit{i} = spikecountest(1+round((i-1)*ntcalcium/nsplit):round(i*ntcalcium/nsplit));
        end
        fitsplit{i} = x.fit(1+round((i-1)*ntcalcium/nsplit):round(i*ntcalcium/nsplit));
        driftsplit{i} = x.drift(1+round((i-1)*ntcalcium/nsplit):round(i*ntcalcium/nsplit));
    end
end
rateflag = fn_switch(~doest || doMAP,{},{'rate'});
if doest
    spk_display(dtcalcium,{spikesplit spikestsplit},{calciumsplit fitsplit driftsplit},'ncol',1,rateflag{:})
else
    spk_display(dtcalcium,spikesplit,calciumsplit,'ncol',1,rateflag{:})
end    
ha = findobj(gcf,'type','axes'); ha = ha(end);
ax = axis(ha);
if all(isfield(x,{'setflag' 'dataflag' 'cellnum'}))
    str = sprintf('%s dataset %i, cell %i',upper(x.setflag),x.dataflag,x.cellnum);
    if dorealspikes && doest && isfield(x,'score'), str = [str sprintf(': score = %f',x.score)]; end
    text(ax(1),ax(4),str,'parent',ha,'verticalalignment','top');
end



