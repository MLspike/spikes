function out = spf_scoreMLspike(in,doparallel)
% function out = spf_scoreMLspike([log10(a) log10(tau) sat|[p2 p3] log10(sig) log10(drift) ...
%       dataflag methodflag], doparallel)
%---
% Train for SpikeFinder challenge using simultaneous calcium and spikes
% recording.
% 
% Input:
% - dataflag    Dataset number, ranging from 1 to 10
% - methodflag  Flag for default parameters set
% - a,tau,saturation,p2,p3,sigma,drift    Model parameters

if nargin<2 || isstruct(doparallel) % strange that when called by SUMO, 2nd argument is an empty structure...
    doparallel = true;
end

% Parameters
dataflag = in(end-1);
methodflag = in(end);
parset = in(1:end-2);
[method defpar parsetnames par tbin baselinerange] = spf_parameters(methodflag,parset);
if dataflag>=21 && dataflag<=25
    if ~strcmp(par.drift.effect,'multiplicative')
        error 'drift effect must be multiplicative for raw data'
    end
else
    if ~strcmp(par.drift.effect,'additive')
        error 'drift effect must be additive for processed data'
    end
end

% Display parameters
fprintf(['testing [' num2str(parset,' %.3f') '] ('])
for i=1:length(parset)
    name = parsetnames{i};
    val = parset(i);
    if strfind(name,'log10(')
        name = name(7:end-1);
        val = 10^val;
    end
    if i>1, fprintf(', '), end
    fprintf('%s=%.2f',name,val)
end
fprintf(')\n')

% File where computations are stored
dsave = spf_folders('precomp');
if ~exist(dsave,'dir'), mkdir(dsave), end
fsave = fullfile(dsave,sprintf('%s%i-dataset%i.mat',method,methodflag,dataflag));
resmodel = struct('parset',cell(1,0), ... % structure for saving scores
    'smooth',[],'delay',[], ...
    'date',[],'datestr',[],'origin',[], ...
    'score',[],'out',[]);
if ~exist(fsave,'file')
    res = resmodel;
    fn_savevar(fsave,defpar,parsetnames,res)
else
    res = fn_loadvar(fsave,'res');
    if ~isfield(res,'smooth'), res = fn_structmerge(resmodel,res,'strict'); end
end

% Was this computation already performed and saved?
kres = fn_find(parset,{res.parset});
if isempty(kres)
    resk = fn_structinit(resmodel);
    clear res % res must be re-loaded before saving
else
    out = res(kres).out;
    fprintf('computation was already performed -> score=%.10f\n',1-out)
    return
end

% Load data
[dtcalcium calcium spikecount] = spf_getdata(dataflag);
[ntcalcium ncell] = size(calcium);
ntspikes = size(spikecount,1);

% Estimation (= computational bottleneck): loop on trials
par.display = 'count';
par.dographsummary = false;
spikecountest = zeros(ntspikes,ncell);
[fit drift] = deal(zeros(ntcalcium,ncell));
if doparallel
    % estimate using multiple workers
    disp 'tps_mlspike'
    parfor i=1:ncell
        fprintf('\b %i\n',i)
        pari = par; pari.dt = dtcalcium(i);
        [spikecountest(:,i) fit(:,i) drift(:,i)] = spf_estimate(calcium(:,i),spikecount(:,i),pari,tbin,baselinerange);
    end
else
    fn_progress('tps_mlspike',ncell)
    for i=1:ncell
        fn_progress(i)
        par.dt = dtcalcium(i);
        [spikecountest(:,i) fit(:,i) drift(:,i)] = spf_estimate(calcium(:,i),spikecount(:,i),par,tbin,baselinerange);
    end
end

% Score by optimizing over delay and smoothing
[score smooth delay spikecountadj] = spf_evaluate(spikecountest,spikecount);

% Store and save
resk.parset = parset;
resk.smooth = smooth;
resk.delay = delay;
resk.date = now;                                    % store also the date
resk.datestr = datestr(resk.date);
d = dbstack;
if isscalar(d)
    resk.origin = 'manual';
else
    resk.origin = [d(2).name '-' d(3).name];
end
resk.score = score;
resk.out = 1-score;
res = fn_loadvar(fsave,'res');
if ~isfield(res,'smooth'), res = fn_structmerge(resmodel,res); end
res(end+1) = resk;
fprintf('\b -> score=%.10f\n',score)
DOSAVE = eval('true');
if DOSAVE
    fn_savevar(fsave,res,'-APPEND')                 % save!
    fprintf('(saved at position %i)\n',length(res))
    
    % % Additional save to be sure we are not loosing samples
    % dsave = strrep(fsave,'.mat','-all');
    % if ~exist(dsave,'dir'), mkdir(dsave), end
    % fn_savevar(fullfile(dsave,fn_hash(parset)),resk)
    
    % Save also current estimate if it is the best
    if isscalar(res) || resk.out<min([res(1:end-1).out])
        disp 'New minimum encountered: save estimation result'
        best = struct('parset',parset,'smooth',smooth,'delay',delay, ...
            'spikecountest',spikecountest,'spikecountadj',spikecountadj,'fit',fit,'drift',drift,'score',score,'out',1-score);
        fn_savevar(fsave,best,'-APPEND')
    end
else
    disp 'NOT SAVING!'
end

% Output
out = 1-score;

