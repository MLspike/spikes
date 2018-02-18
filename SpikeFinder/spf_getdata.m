function [dtcalcium calcium spikecount spiketimes] = spf_getdata(dataflag,type,correction)
% function [dtcalcium calcium spikecount spiketimes] = spf_getdata(dataflag,'train|test','correct')
%---
% Input
% - dataflag    0:      small test data (beginning of dataset 1) 
%               1-10:   processed data
%               11-20:  processed data, cut to only 120s
%               21-25:  raw data (only for datasets 1-5)
%               92:     improved dataset 2 (processed + horrible jumps filtered out) 
% - 'train' or 'test'
% - 'correct'   using this flag will cause dataflag 2 to be replaced by 92

% Train or Test?
if nargin<2, type = 'train'; end
dotrain = strcmp(type,'train');
if ~dotrain && ~ismember(dataflag,[1:5 21:25 92])
    error 'dataflag for test data is either between 1 and 5, or 92 for corrected dataset 2'
end

% Correction for dataset 2 can be specified either with dataflag=2 and
% 'correct' flag, or with dataflag = 92
if nargin>=3
    if ~strcmp(correction,'correct'), else error argument, end
    if dataflag~=2, error 'correction is only for dataset 2', end
    dataflag = 92;
end

% Unprocessed data?
doraw = (dataflag>=21 & dataflag<=25);

% Load data
disp 'loading data'
datanum = fn_mod(max(1,dataflag),10);
d = spf_folders(type);
calciumproc = csvread(fullfile(d,[num2str(datanum) '.' type '.calcium.csv']),1,0);
ntproc = size(calciumproc,1);
if doraw
    tmp = csvread(spf_folders('data','datasets 1-5 nopreprocessing',[num2str(datanum) '.' type '.calcium.nopreprocessing.csv']),1,0);
    dtcalcium = 1./tmp(1,:);
    calcium = tmp(2:end,:);
    if ismember(datanum,[3 5])
        % DF/F - already performed for datasets 1 2 and 4
        calcium = fn_div(calcium,prctile(calcium,30)) - 1;
    end
    calcium(isnan(calcium)) = 0; % same convention as in the preprocessed data for non-existing data points
    clear tmp
else
    calcium = calciumproc;
    dtcalcium = .01*ones(1,size(calcium,2));
end
[nt ncell] = size(calcium);
if dotrain
    spikecount = csvread(fullfile(d,[num2str(datanum) '.train.spikes.csv']),1,0);
    for i=1:ncell
        ntc = find(calciumproc(:,i)~=0,1,'last');
        spikecount(ntc+1:ntproc,i) = NaN;
    end
else
    spikecount = [];
end

% Precise spike times as well
if dotrain
    if datanum<=5
        % can be read from raw data file
        spiketimes = csvread(spf_folders('data','datasets 1-5 nopreprocessing',[num2str(datanum) '.train.spike.nopreprocessing.csv']),2,0)/1e3;
        spiketimes = fn_map(num2cell(spiketimes,1),@(x)x(~isnan(x)));
    else
        % need to be estimated
        dtspikes = .01;
        spiketimes = fn_timevector(spikecount,dtspikes);
    end
else
    spiketimes = []; % no spikes for test dataset!
end

% Corrections / crop
if dataflag==0
    % test: use only first 10s of dataset 1
    calcium = calcium(1:1000,1:3);
    if dotrain, spikecount = spikecount(1:1000,1:3); end
    spiketimes = fn_map(spiketimes,@(x)x(x<=10));
elseif (dataflag>=1 && dataflag<=10) || (dataflag>=21 && dataflag<=25)
    % take the data as is
elseif dataflag>=11 && dataflag<=20
    % use only a sub-part of the data
    calciumcut = calcium(1:min(end,12000),:);
    spikecountcut = spikecount(1:min(end,12000),:);
    if datanum==2
        calciumcut(:,1:20) = calcium(8001:20000,1:20);
        spikecountcut(:,1:20) = spikecount(8001:20000,1:20);
    end
    calcium = calciumcut; clear calciumcut
    spikecount = spikecountcut; clear calciumcut
    if datanum==2
        spiketimes(1:20) = fn_map(spiketimes(1:20),@(x)x(x>=80 & x<=200));
        spiketimes(21:end) = fn_map(spiketimes(21:end),@(x)x(x<=120));
    else
        spiketimes = fn_map(spiketimes,@(x)x(x<=120));
    end
elseif dataflag==92
    %%
    % corrections for dataset 2
    cc = calcium;
    cc(1,:) = cc(2,:);
    if dotrain
        cc(1:848,8) = cc(1:848,8)+6;
        cc(1:2000,8) = cc(1:2000,8) - column(linspace(5,0,2000));
        cc(849:985,8) = 0.45;
        idx=4901:6465; cc(idx,13) = cc(idx,13) - column(linspace(5,0,length(idx)));
        cc(idx(1):5023,13) = .45;
        idx = 1:1051; cc(idx,14) = cc(idx,14) - column(linspace(4,0,length(idx)));
        idx=440:580; cc(1:idx(1),14) = cc(1:idx(1),14)+5; cc(idx,14) = .8;
    else
        idx = 1:1757; cc(idx,6) = cc(idx,6) - column(linspace(4,0,length(idx)));
        idx=710:820; cc(1:idx(1),6) = cc(1:idx(1),6)+3.8; cc(idx,6) = .45;
        
        idx = 21000:31000; idx1 = 24395:26205;
        nharm = 5;
        n = length(idx);
        X = zeros(n,2+2*nharm);
        X(:,1) = 1;
        X(:,2) = linspace(0,1,n);
        theta = 2*pi*(0:n-1)/n;
        for i=1:nharm
            X(:,2*i+1) = cos(i*theta);
            X(:,2*i+2) = sin(i*theta);
        end
        y = cc(idx,6);
        mask = true(1,n); mask(idx1-(idx(1)-1)) = false;
        beta = X(mask,:)\y(mask);
        drift = X([1 end],1:2)\(X([1 end],:)*beta);
        cc(idx,6) = cc(idx,6)-X*beta+X(:,1:2)*drift;
        cc(idx1,6) = X(~mask,1:2)*drift;
        
        idx = 5620:7100;
        cc(idx,7) = cc(idx,7) - column(linspace(3,0,length(idx)));
        cc(idx(1):5750,7) = 0;
    end
    %figure(1), plot([calcium(:,6) cc(:,6)]), axis([0 4e4 -1 10])
    calcium = cc;
else
    error 'unknown data flag'
end
