function [spk fit drift parest] = spk_est(calcium,par)
% function [spk fit drift parest] = spk_est(calcium,par)
% function par = spk_est('par')
%---
% Estimate spike times (or spike probabilities, or sample spike trains)
% accounting for calcium signal.
%
% Input:
% - calcium     vector or cell array thereof - calcium signals (can be the
%               raw signal or after division by average value, i.e. with
%               mean value around 1; but mean value should not be
%               subtracted, i.e. algorithm will fail if mean or baseline
%               value is around zero)
% - par         parameter set (par = spk_est('par') gives default
%               parameters, only parameter par.dt, the sampling time, is
%               mandatory)
%
% Output:
% - spk         vector or cell array thereof - Estimated spike times
% - fit         vector or cell array thereof - Fit to the original signal
% - drift       vector or cell array thereof - Estimated baseline drift
% - parest      original parameter structure with, if noise parameter
%               par.finetune.sigma was not given yet, its estimated value
%               present


if ischar(calcium) && strcmp(calcium,'par')
    par = tps_mlspikes('par');
    spk = par;
else
    defaultpar = tps_mlspikes('par');
    if isnumeric(par)
        dt = par;
        par = defaultpar;
        par.dt = par;
    else
        par = fn_structmerge(defaultpar,par);
    end
    [n, fit, parest, ~, ~, drift] = tps_mlspikes(calcium,par); %#ok<*ASGLU>
    switch lower(par.algo.estimate)
        case 'map'
            spk = fn_timevector(n,par.dt);
        case 'proba'
            spk = n;
        case {'sample' 'samples'}
            spk = fn_timevector(n,par.dt);
    end
end