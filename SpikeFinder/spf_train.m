function [score parest] = spf_train(dataflag,methodflag,varargin)
% function [score parest] = spf_train(dataflag,methodflag ...
%                   [,'batch|batchN'][,'fromscratch'][,{fmincon options...}])
 
% Flag
[doparallel dobatch fromscratch] = deal(false);
fminopt = {};
for i=1:length(varargin)
    flag = varargin{i};
    if iscell(flag)
        fminopt = flag;
    else
        switch flag
            case 'batch'
                dobatch = true;
                poolopt = {};
            case 'fromscratch'
                fromscratch = true;
            otherwise
                N = sscanf(flag,'batch%i');
                dobatch = true;
                doparallel = true;
                poolopt = {'Pool',N};
        end
    end
end
        
% Batch execution
if dobatch
    if length(dataflag)~=length(methodflag), error 'length of dataflag and methodflag mismatch', end
    for i = 1:length(dataflag)
        % reconstruct the command!
        command = sprintf('spf_train(%i,%i',dataflag(i),methodflag(i));
        if doparallel, command = [command ',''pool''','']; end %#ok<AGROW>
        if fromscratch, command = [command ',''fromscratch''']; end %#ok<AGROW>
        if ~isempty(fminopt)
            for k=1:length(fminopt)
                a = fminopt{k};
                if ischar(a)
                    fminopt{k} = ['''' a '''']; %#ok<AGROW>
                else
                    fminopt{k} = num2str(a); %#ok<AGROW>
                end
            end
            command = [command ',{' fn_strcat(fminopt,',') '}']; %#ok<AGROW>
        end
        command(end+1) = ')'; %#ok<AGROW>
        % launch batch job
        batch(command,'AutoAttachFiles',false, ...
            'AdditionalPaths',fileparts(which('spf_train')),poolopt{:});
        fn_singular('Batch started for dataset ',dataflag(i))
    end
    return
end

% File where computations are stored
dsave = spf_folders('precomp');
if ~exist(dsave,'dir'), mkdir(dsave), end
methodflagstr = num2str(methodflag);
[method defpar parsetnames] = spf_parameters(methodflag);    
nonlinearity = fn_switch(parsetnames{3},'saturation','saturation','p2','pnonlin');
doautosigma = isstruct(defpar.finetune.autosigmasettings);
fsave = fullfile(dsave,sprintf('%s%s-dataset%i.mat',method,methodflagstr,dataflag));
fprintf('Method %s%s - Dataset %i\n',method,methodflagstr,dataflag)

% Parameter range
[~, ~, parsetnames] = spf_parameters(methodflag);
[LB UB] = spf_getrange(dataflag,methodflag);
ninput = length(parsetnames);

% Starting parameters: first look for existing stimulation, otherwise start
% by calibration
pstart = [];
% (existing results for this method?)
if exist(fsave,'file') && ~fromscratch
    % Select samples within range
    res = fn_loadvar(fsave,'res');
    testedpar = cat(1,res.parset); if isempty(testedpar), testedpar = zeros(0,ninput); end
    ok = all(bsxfun(@ge,testedpar+1e-10,LB) ...
        & bsxfun(@le,testedpar-1e-10,UB),2);
    res = res(ok);
    
    % Best one
    if ~isempty(res)
        % minimal output
        [~, kmin] = min([res.out]);
        % if last execution was interrupted while computing a derivative,
        % it would save time to restart exactly from the same point for
        % which the derivative was being computed: look for it
        if kmin==1
            kstart = kmin;
        else
            p = res(kmin).parset;
            for k = kmin-1:-1:1
                switch sum([res(k).parset]~=p)
                    case 1
                        % we probably found the point
                        kstart = k;
                        break
                    case 2
                        % the point is probably further before
                    otherwise
                        % kmin is probably the point
                        kstart = kmin;
                        break
                end
            end
        end
        disp 'found starting point from previous estimation'
        pstart = res(kstart).parset;
    end
end
% (same method, but previous version of the program with some bugs in it)
fbug = fullfile(dsave,'score mean instead of median',sprintf('%s%s-dataset%i.mat',method,methodflagstr,dataflag));
if isempty(pstart) && exist(fbug,'file') && ~fromscratch
    try
        best = fn_loadvar(fbug,'best');
        pstart = best.parset;
        disp 'found starting point from previous estimation with ''mean rather than median'' bug'
    catch
    end
end
% (other method, provided it estimated the same parameters)
if isempty(pstart) && ~fromscratch
    res = spf_summary(dataflag);
    if isempty(res)
        ord = [];
    else
        methodstested = char(fn_map({res.method},@(x)x(end-2:end)));
        samealgo = (methodstested(:,1)==methodflag(1));
        [~, ord] = sortrows([column(samealgo) cat(1,res.score)]); % take preferentially with the same algo, then maximal score
    end
    for idx=row(ord(end:-1:1))
        [~, ~, parsetnames2] = spf_parameters(methodstested(idx,:));
        if isequal(parsetnames2,parsetnames)
            disp(['found starting point from previous estimation with method ' methodstested(idx,:)])
            pstart = res(idx).parset;
            break
        end
    end
end
% (no previous result exists -> calibration)
if fromscratch || isempty(pstart)
    % Load data for calibration
    [dtcalcium calcium ~, spiketimes] = spf_getdata(dataflag);
    [~, ncell] = size(calcium);
    calcium = num2cell(calcium,1);
    calcium = fn_map(calcium,@(x)1+x(1:find(x~=0,1,'last')));
    % run a calibration !
    pcal = spk_calibration('par','dt',dtcalcium,'tdrift',15, ...
        'dosaturation',strcmp(nonlinearity,'saturation'), ...
        'dodelay',true);
    [pest fit drift] = spk_calibration(spiketimes,calcium,pcal);
    if doautosigma
        noisepar = .8;
    else
        sigma = zeros(1,ncell);
        for i=1:ncell, sigma(i) = rms(calcium{i}-fit{i}); end
        noisepar = mean(sigma);
    end
    drift = .01;
    switch nonlinearity
        case 'saturation'
            pstart = [log10(pest.a) log10(pest.tau) pest.saturation log10(noisepar) log10(drift)];
        case 'pnonlin'
            pstart = [log10(pest.a) log10(pest.tau) 0 0 log10(noisepar) log10(drift)];
        otherwise
            error 'not implemented yet'
    end
end

% Start optimization!
pstart = min(UB,max(LB,pstart));
if any(pstart==LB | pstart==UB)
    disp 'moving starting point away from bound'
    idx = (pstart==LB); pstart(idx) = pstart(idx)+1e-4;
    idx = (pstart==UB); pstart(idx) = pstart(idx)-1e-4;
end
disp 'Starting Optimization'
fact = 1e4;
fun = @(x)spf_scoreMLspike([x*fact dataflag methodflag],doparallel);
opt = optimset('display','iter','TolFun',1e-8,fminopt{:});
parest = fmincon(fun,pstart/fact,[],[],[],[],LB/fact,UB/fact,[],opt)*fact;
score = 1-fun(parest/fact);

