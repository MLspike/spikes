function spf_publish(datanum,doautosigma)

if nargin<2, doautosigma = true; end

if nargin==0 || isempty(datanum), datanum = 1:10; end
if ~isscalar(datanum)
    for i=datanum
        spf_publish(i,doautosigma)
    end
    return
end

% Handle correction of dataset 2
if datanum==2, dataflag = 92; else dataflag = datanum; end

% Get info about best estimation with this dataflag
res = spf_summary(dataflag);
if ~doautosigma
    % remove estimations with auto-sigma, i.e. with methodflag starting
    % with 4 or 6
    ok = fn_isemptyc(regexp({res.method},'proba(4|6)'));
    res = res(ok);
end
res = res(1); % keep only info about the best estimation

% Get training estimation result for this best parameter set
methodflagstr = res.method(end-2:end);
methodflag = str2double(methodflagstr);
fprintf('Publishing results: Dataset %i - Method %i\n',dataflag,methodflag)
dsave = spf_folders('precomp');
method = spf_parameters(methodflag);    
fsave = fullfile(dsave,sprintf('%s%i-dataset%i.mat',method,methodflag,dataflag));
best = fn_loadvar(fsave,'best');
if ~isequal(best.parset,res.parset), error 'parameter set mismatch', end
fprintf('Training data: score = %.4f\n',res.score)
trainpred = best.spikecountadj;

% Save to file
dsubmit = spf_folders('submissions','current submission');
if ~exist(dsubmit,'dir'), mkdir(dsubmit), end
fpred = fullfile(dsubmit,[num2str(datanum) '.train.spikes.csv']);
ncell = size(trainpred,2);
csvwrite(fpred, [0:ncell-1; trainpred]); % don't forget the header row

% [par tbin method defpar parsetnames] = spf_parameters(methodflag,parset);

% Run estimation with estimated parameters on the test set
if datanum>5, return, end
fprintf('Test data: ')
[dtcalcium calcium ~] = spf_getdata(dataflag,'test');
[nt ncell] = size(calcium);
parset = best.parset;
[~, ~, ~, par tbin baselinerange] = spf_parameters(methodflag,parset);
[smooth delay] = deal(best.smooth,best.delay);
par.display = 'count';
[spikecountest spikecountadj fit drift] = deal(zeros(nt,ncell));
fn_progress('tps_mlspike',ncell)
for i=1:ncell
    fn_progress(i)
    par.dt = dtcalcium(i);
    [spikecountest(:,i) fit(:,i) drift(:,i) spikecountadj(:,i)] = spf_estimate(calcium(:,i),[],par,tbin,baselinerange,smooth,delay);
end

% Save to file
fpred = fullfile(dsubmit,[num2str(datanum) '.test.spikes.csv']);
csvwrite(fpred, [0:ncell-1; spikecountadj]); % don't forget the header row

% Save also all details
dsave = spf_folders('testres');
if ~exist(dsave,'dir'), mkdir(dsave), end
fsave = fullfile(dsave,sprintf('testset%i.mat',datanum));
fn_savevar(fsave,calcium,methodflag,parset,par,tbin,smooth,delay,spikecountest,spikecountadj,fit,drift)

