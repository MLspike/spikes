function summary = spf_summary(varargin)
% function summary = spf_summary([dataflag][,'oldresults'][,'noautosigma'])

% Input/Output
doall = true; doold = false; doautosigma = true;
for i=1:length(varargin)
    a = varargin{i};
    if ischar(a)
        switch a
            case 'oldresults'
                doold = true;
            case 'noautosigma'
                doautosigma = false;
            otherwise
                error 'unknown flag'
        end
    else
        dataflag = a;
        doall = false;
    end
end
doout = (nargout>0);

% Scan result files
if doold
    dsave = spf_folders('precomp','score mean instead of median');
else
    dsave = spf_folders('precomp');
end
if doall
    files = dir(fullfile(dsave,'*-dataset*.mat'));
else
    n = length(dataflag);
    dataflag(dataflag==2) = 92;
    files = cell(1,n);
    for i=1:n
        files{i} = row(dir(fullfile(dsave,sprintf('*-dataset%i.mat',dataflag(i)))));
    end
    files = cell2mat(files);
    clear dataflag
end
files = {files.name};

summary = struct('dataflag',[],'res',[]);
for kf = 1:length(files)
    
    [method dataflag] = fn_regexptokens(files{kf},'(.*)-dataset(\d*).mat');
    if ~doautosigma
        methodflag = str2double(method(end-2:end));
        [~, defpar] = spf_parameters(methodflag);
        if isstruct(defpar.finetune.autosigmasettings)
            % autosigma on -> discard
            continue
        end
    end
    dataflag = str2double(dataflag);
    res = fn_loadvar(fullfile(dsave,files{kf}),'res');
    [score, idx] = max([res.score]);
    if isempty(score), continue, end
    isrunning = (now-res(end).date)<0.02;
    resk = struct('score',score,'method',method,'parset',res(idx).parset,'smooth',res(idx).smooth,'delay',res(idx).delay,'running',isrunning);
    if length(summary)<(1+dataflag) || isempty(summary(1+dataflag).dataflag)
        summary(1+dataflag).dataflag = dataflag;
        summary(1+dataflag).res = resk;
    else
        summary(1+dataflag).res(end+1) = resk;
    end
    
end
summary(fn_isemptyc({summary.dataflag})) = [];
datanum = [summary.dataflag];
datanum(datanum==92) = 2;
idx = (datanum>=21) & (datanum<=25); datanum(idx) = datanum(idx)-20;
if isempty(summary)
    if doout, disp 'no results found yet', end
    return
end
[summary.datanum] = dealc(datanum);

[datanum ord] = sort(datanum); %#ok<ASGLU>
summary = summary(ord);

% Display best scores
if ~doout, clc, end
for k = 1:length(summary)
    sk = summary(k);
    if isempty(sk.dataflag), continue, end
    resk = sk.res;
    [~, ord] = sort([resk.score],'descend');
    resk = resk(ord);
    summary(k).res = resk;
    if ~doout
        % display
        for i=1:length(resk)
            reski = resk(i);
            str = fn_switch(i==1,sprintf('Dataset %.2i: ',sk.dataflag),repmat(' ',1,12));
            runflag = fn_switch(reski.running,' [running]','');
            fprintf('%s%.5f using %s%s (parset=',str,reski.score,reski.method,runflag)
            fprintf('%.4f ',reski.parset)
            fprintf('\b, smooth=%.4f, delay=%.4f)\n',reski.smooth,reski.delay)
        end
    elseif ~doall
        % return results structure
        summary = resk;
        return
    end
    clear resk
end
if ~doout, clear summary, end