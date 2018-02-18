function spf_displayEvalPoints(dataflag,methodflag,varargin)
% function spf_displayEvalPoints(dataflag,methodflag[,'line'][,'sumo'][,'fmincon'])

% Input
dsave = spf_folders('precomp');
if nargin==0
    fn_getfile('REP',dsave);
    fsave = fn_getfile('*.mat','Select result file to display');
    if isequal(fsave,0), return, end
    [methodflagstr dataflagstr] = fn_regexptokens(fn_fileparts(fsave,'base'),'^.*(\d{3})-dataset(\d)*$');
    dataflag = str2double(dataflagstr); methodflag = str2double(methodflagstr);
else
    methodflagstr = num2str(methodflag);
    method = spf_parameters(methodflag);
    fsave = fullfile(dsave,sprintf('%s%s-dataset%i.mat',method,methodflagstr,dataflag));
end

[sumoonly fmincononly doline] = deal(false);
for i=1:length(varargin)
    switch varargin{i}
        case 'sumo'
            sumoonly = true;
        case 'fmincon'
            fmincononly = true;
        case 'line'
            doline = true;
    end
end

% Load results
fprintf('\nDataset %i - Method %i\n',dataflag,methodflag)
disp 'loading results'
s = load(fsave);
res = s.res;
if isempty(res)
    disp 'No result available yet'
    return
end

%%
parnames = s.parsetnames;
npar = length(parnames);
% res([res.score]<res(1).score) = [];
testedpar = cat(1,res.parset);
score = cat(1,res.score);
neval = length(score);
m = max(score(find(~isnan(score),1,'first')),(min(score)+max(score))/2);
col = fn_clip(score,[m max(score)],mapgeog(256));

%%
[LB UB] = spf_getrange(dataflag,methodflag);
range = [LB; UB];

%%
origins = {res.origin};
idxsumo = ~fn_isemptyc(strfind(origins,'fetchEvaluatedPoints'));

%% Parameter space
bgcol = [1 1 1]*.6;
fn_figure('Show Points','color',bgcol,'tag','Show Points')

ok = true(1,neval);
if sumoonly
    ok(~idxsumo) = false;
elseif fmincononly
    % keep only last evaluation of each step
    idxfmincon = find(~idxsumo);
    orig = origins(idxfmincon);
    isderiv = ~fn_isemptyc(strfind(orig,'finDiffEvalAndChkErr'));
    ok1 = (~isderiv & isderiv([2:end end]));
    ok(:) = false; ok(idxfmincon(ok1)) = true;
end
nok = sum(ok);
for i=1:npar
    for j=1:i-1
        subplot(npar-1,npar-1,(j-1)*(npar-1)+(i-1))
        if doline
            plot(testedpar(ok,i),testedpar(ok,j),'color',[1 1 1]*.3,'hittest','off')
            hold on
        end
        scatter(testedpar(ok,i),testedpar(ok,j),[10 6*ones(1,nok-1)],col(ok,:),'hittest','off')
        hold off
        set(gca,'color',bgcol,'buttondownfcn',@(ha,~)zoomfun(ha,i,j,npar,range))
        set(gca,'xlim',range(:,i),'ylim',range(:,j))
        box on
        if j==1, title(parnames{i},'fontweight','normal'), end
        if j==i-1, ylabel(parnames{j}), end
    end
end

% Display also best parameter set
best = s.best;
disp(['Best parameter set: ' num2str(best.parset,' %.4f')])
fprintf('(')
for i=1:length(best.parset)
    name = s.parsetnames{i};
    val = best.parset(i);
    if strfind(name,'log10(')
        name = name(7:end-1);
        val = 10^val;
    end
    if i>1, fprintf(', '), end
    fprintf('%s=%.3f',name,val)
end
fprintf(')\n-> score=%f\n\n',best.score)

%% Scores


fn_figure('Scores')
plot([res(idxsumo).score],'color',fn_colorset('newmatlab',1)/2+1/2)
hold on
plot([res(~idxsumo).score],'color',fn_colorset('newmatlab',2)/2+1/2)
h1=plot(cummax([res(idxsumo).score]),'color',fn_colorset('newmatlab',1),'linewidth',1);
h2=plot(cummax([res(~idxsumo).score]),'color',fn_colorset('newmatlab',2),'linewidth',1);
hold off
xlabel '# eval', ylabel 'score'
if any(idxsumo), legend([h1 h2],'SUMO','fmincon','location','SouthEast'), else legend(h2,'fmincon','location','SouthEast'), end

%---
function zoomfun(ha,i0,j0,npar,range0)

hf = get(ha,'parent');
switch get(hf,'SelectionType')
    case 'normal'
        rect = fn_mouse('rectax-');
    case 'alt'
        axis tight
        rect = row(range0(:,[i0 j0]));
    otherwise
        return
end
if diff(rect(1:2))
    i = i0;
    for j=1:i-1
        set(subplot(npar-1,npar-1,(j-1)*(npar-1)+(i-1)),'xlim',rect(1:2))
    end
    for j=i+1:npar
        set(subplot(npar-1,npar-1,(i-1)*(npar-1)+(j-1)),'ylim',rect(1:2))
    end
end
if diff(rect(3:4))
    j = j0;
    for i=j+1:npar
        set(subplot(npar-1,npar-1,(j-1)*(npar-1)+(i-1)),'ylim',rect(3:4))
    end
    for i=1:j-1
        set(subplot(npar-1,npar-1,(i-1)*(npar-1)+(j-1)),'xlim',rect(3:4))
    end
end



        
        
