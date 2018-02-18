function [method defpar parsetnames par tbin baselinerange] = spf_parameters(methodflag,parset)
% function [method defpar parsetnames] = spf_parameters(methodflag,parset)
% function [method defpar parsetnames par tbin baselinerange] = spf_parameters(methodflag,parset)

dopar = (nargin>=2);

% Default parameters
defpar = tps_mlspikes('par');
methodflagstr = num2str(methodflag);
method = fn_switch(methodflagstr(1),{'1' '7'},'MAP',{'2' '4' '5' '6'},'proba','3','samples');
nonlinearity = fn_switch(methodflagstr(1),{'1' '2' '3' '4' '7'},'saturation',{'5' '6'},'pnonlin');
doautosigma = fn_switch(methodflagstr(1),{'1' '2' '3' '5'},false,{'4' '6' '7'},true);
if doautosigma
    defpar.finetune.autosigmasettings = spk_autosigma('par');
end
defpar.algo.estimate = method;
nsamp = 500;
switch methodflagstr(2)
    case '0'
        % keep default 'algo' pars
    case '1'
        defpar.algo.nc = 60;
        defpar.algo.nb = 60;
    case '2'
        defpar.algo.cmax = 20;
        defpar.algo.nc = 120;
        defpar.algo.nb = 60;
    case '3'
        % a lighter one, for testing
        defpar.algo.cmax = 15;
        defpar.algo.nc = 60;
        defpar.algo.nb = 40;
        nsamp = 300;
    case '4'
        defpar.algo.nspikemax = 10;
        defpar.algo.cmax = 20;
        defpar.algo.nc = 120;
        defpar.algo.nb = 60;
    case '5'
        defpar.algo.nspikemax = 20;
        defpar.algo.cmax = 40;
        defpar.algo.nc = 120;
        defpar.algo.nb = 60;
    otherwise
        error 'wrong method flag'
end
if strcmp(method,'samples')
    defpar.algo.nsample = nsamp; 
    rng(0,'twister') % seed the random number generator for reproducibility of results
end
baselinerange = 0;
tbin = 1;
switch methodflagstr(3)
    case '0'
        % keep other default values -> multiplicative drift
    case {'1' '2'}
        defpar.drift.effect = 'additive';
    case '3'
        defpar.drift.effect = 'additive';
        tbin = 2;
    case '4'
        defpar.drift.effect = 'additive';
        tbin = 2;
        defpar.special.burstcostsone = true;
    case '5'
        defpar.drift.effect = 'additive';
        tbin = 4;
    case '6'
        defpar.drift.effect = 'additive';
        tbin = 4;
        defpar.special.burstcostsone = true;
    case '7'
        defpar.special.burstcostsone = true;
    case '8'
        baselinerange = 75;
    case '9'
        defpar.special.burstcostsone = true;
        baselinerange = 75;
    otherwise
        error 'wrong method flag'
end

% Parameters
if doautosigma
    noiseparname = 'log10(sigmafact)';
else
    noiseparname = 'log10(sigma)';
end
switch nonlinearity
    case 'saturation'
        parsetnames = {'log10(a)' 'log10(tau)' 'saturation' noiseparname 'log10(drift)'};
    case 'pnonlin'
        parsetnames = {'log10(a)' 'log10(tau)' 'p2' 'p3' noiseparname 'log10(drift)'};
end
if dopar
    switch nonlinearity
        case 'saturation'
            [a tau noisepar drift] = dealc(10.^parset([1 2 4 5]));
            saturation = parset(3);
            pnonlin = [];
        case 'pnonlin'
            [a tau noisepar drift] = dealc(10.^parset([1 2 5 6]));
            saturation = 0;
            pnonlin = parset([3 4]);
    end
    par = defpar;
    par.a = a;
    par.tau = tau;
    par.saturation = saturation;
    par.pnonlin = pnonlin;
    if doautosigma
        par.finetune.autosigmasettings.bias = noisepar;
    else
        par.finetune.sigma = noisepar;
    end
    par.drift.parameter = drift;
else
    par = [];
end
