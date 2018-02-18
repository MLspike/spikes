function spf_display(dataflag,methodflag)
% function spf_display(dataflag,methodflag)
% function spf_display('all')

% Load results
if nargin>=1 && strcmp(dataflag,'all')
    x = loadAllResults();
else
    if nargin==0
        dsave = spf_folders('precomp');
        fn_getfile('REP',dsave);
        fsave = fn_getfile('*.mat','Select result file to display');
        if isequal(fsave,0), return, end
        [methodflagstr dataflagstr] = fn_regexptokens(fn_fileparts(fsave,'base'),'^.*(\d{3})-dataset(\d)*$');
        dataflag = str2double(dataflagstr); methodflag = str2double(methodflagstr);
    end
    x = loadResult('train',dataflag,methodflag,true);
end

fn_review(x,@(xi)spf_displayonecell(xi))

%---
function x = loadAllResults()

% container
x = cell(2,10);

% train
train = spf_summary;
for i=1:10
    x{1,i} = loadResult('train',train(i).dataset,str2double(train(i).res(1).method(end-2:end)));
end

% test
for i=1:5
    x{2,i} = loadResult('test',i);
end

% put together
x = x([1:10 11:2:19]);
n = max(fn_itemlengths(x));
for i=1:15
    if length(x{i})<n, x{i}(n).setflag = []; end
end
x = cat(1,x{:});


%---
function x = loadResult(setflag,dataflag,methodflag,displaypar)

if nargin<4, displaypar = false; end

% Load data and results
switch setflag
    case 'train'
        dsave = spf_folders('precomp');
        methodflagstr = num2str(methodflag);
        method = spf_parameters(methodflag);
        fsave = fullfile(dsave,sprintf('%s%s-dataset%i.mat',method,methodflagstr,dataflag));
        s = load(fsave);
        if ~isfield(s,'best'), error 'no best estimate saved in file', end
        res = s.best;
        [dtcalcium calcium spikecount] = spf_getdata(dataflag,setflag);
        spikecountc = num2cell(spikecount,1);
        % evaluate per trial
        scoreall = spf_score(res.spikecountadj,spikecount);
        scoreallc = num2cell(scoreall);
    case 'test'
        dsave = spf_folders('testres');
        fsave = fullfile(dsave,['testset' num2str(dataflag) '.mat']);
        res = load(fsave);
        calcium = res.calcium;
        if isfield(res,'dtcalcium'), dtcalcium = res.dtcalcium; else dtcalcium = .01*ones(1,size(calcium,2)); end
        methodflagstr = num2str(res.methodflag);
        method = spf_parameters(methodflag);
        spikecountc = [];
        scoreallc = [];
end
calcium = calcium+1;

% Display
if displaypar
    fprintf('\n')
    disp(['Best parameter set: ' num2str(res.parset,' %.4f')])
    fprintf('(')
    for i=1:length(res.parset)
        name = s.parsetnames{i};
        val = res.parset(i);
        if strfind(name,'log10(')
            name = name(7:end-1);
            val = 10^val;
        end
        if i>1, fprintf(', '), end
        fprintf('%s=%.3f',name,val)
    end
    fprintf(')\n-> score=%f\n\n',res.score)
    fprintf('\b-> score=%f\n\n',mean(scoreall))
end

x = struct('setflag',setflag,'dataflag',dataflag,'method',method,'cellnum',num2cell(1:size(calcium,2)), ...
    'dtcalcium',num2cell(dtcalcium),'calcium',num2cell(calcium,1),'spikecount',spikecountc, ...
    'spikecountest',num2cell(res.spikecountadj,1),'fit',num2cell(res.fit,1),'drift',num2cell(res.drift,1), ...
    'score',scoreallc);

%---
function displayonecell(x)

dtcalcium = x.dtcalcium;
dtspikes = .01;
dotrain = strcmp(x.setflag,'train');

% display (split into 3 parts)
nt = length(x.calcium);
if nt==0, clf, return, end
nsplit = 4;
[spikesplit spikestsplit calciumsplit fitsplit driftsplit] = deal(cell(1,nsplit));
for i=1:nsplit
    if dotrain, spikesplit{i} = x.spikecount(1+round((i-1)*nt/nsplit):round(i*nt/nsplit)); end
    spikestsplit{i} = x.spikecountest(1+round((i-1)*nt/nsplit):round(i*nt/nsplit));
    calciumsplit{i} = x.calcium(1+round((i-1)*nt/nsplit):round(i*nt/nsplit));
    fitsplit{i} = x.fit(1+round((i-1)*nt/nsplit):round(i*nt/nsplit));
    driftsplit{i} = x.drift(1+round((i-1)*nt/nsplit):round(i*nt/nsplit));
end
if strcmp(x.method,'MAP')
    for i=1:nsplit
        if dotrain, spikesplit{i} = fn_timevector(spikesplit{i},dtspikes); end
        spikestsplit{i} = fn_timevector(spikestsplit{i},dtspikes);
    end
    rateflag = {};
else
    for i=1:nsplit
        spikesplit{i} = fn_timevector(spikesplit{i},dtspikes);
    end
    rateflag = {'rate'};
end
spk_display(dtcalcium,{spikesplit spikestsplit},{calciumsplit fitsplit driftsplit},'ncol',1,rateflag{:})

ha = findobj(gcf,'type','axes'); ha = ha(end);
ax = axis(ha);
str = sprintf('%s dataset %i, cell %i',upper(x.setflag),x.dataflag,x.cellnum);
if dotrain, str = [str sprintf(': score = %f',x.score)]; end
text(ax(1),ax(4),str,'parent',ha,'verticalalignment','top');



