function [LB UB] = spf_getrange(dataflag,methodflag)
% function [LB UB] = spf_getrange(dataflag,methodflag)

datanum = fn_mod(max(1,dataflag),10);
[~, defpar parsetnames] = spf_parameters(methodflag);    
nonlinearity = fn_switch(parsetnames{3},'saturation','saturation','p2','pnonlin');
dopnonlin = strcmp(nonlinearity,'pnonlin');
doautosigma = isstruct(defpar.finetune.autosigmasettings);
doadditivedrift = strcmp(defpar.drift.effect,'additive');

% OGB/GCamp defaults
if doadditivedrift  % normalized data are zero-mean...
    switch nonlinearity
        case 'saturation'
            % for OGB: saturation
            %       'log10(a)' 'log10(tau)' 'saturation' 'log10(sigma)' 'log10(drift)'
            LB = [   -1.5           -1           0            -1            -4     ];
            UB = [      0           .5          .2             0            -1     ];
        case 'pnonlin'
            % for GCaMP: supranonlinearity; change also other parameters
            %        'log10(a)' 'log10(tau)' 'p2' 'p3' 'log10(sigma)' 'log10(drift)'
            LB = [   -1.5           -1       -1  -.5         -2            -4     ];
            UB = [      1            1        2   .5          0            -1     ];
    end
else                % raw data
    switch nonlinearity
        case 'saturation'
            % for OGB: saturation
            %       'log10(a)' 'log10(tau)' 'saturation' 'log10(sigma)' 'log10(drift)'
            LB = [     -5           -1           0            -5            -5     ];
            UB = [     -1           .5          .2             0            -1     ];
        case 'pnonlin'
            % for GCaMP: supranonlinearity; change also other parameters
            %        'log10(a)' 'log10(tau)' 'p2' 'p3' 'log10(sigma)' 'log10(drift)'
            LB = [     -5           -1       -1  -.5         -5            -8     ];
            UB = [      0            1        2   .5          0            -1     ];
    end
end
range = [LB; UB];

% auto sigma?
if doautosigma
    range(:,4+dopnonlin) = [-.5; .5];
end

% adjust the range depending on dataset
if doadditivedrift
    switch datanum
        case 3 % pnonlin
            if ~doautosigma, range(:,6) = [-5; -2]; end
        case 4 % saturation
            range(:,3) = [0; .3];
            if doautosigma
                range(:,4) = [-.5; 1]; 
            else
                range(:,4) = [-.5; .5]; 
            end
            range(:,5) = [-5; -2];
        case 5 % pnonlin
            range(:,1) = [-3; -1];
            range(:,3) = [-1; 3];
            range(:,4) = [-.5; 1];
            range(:,6) = [-5; -2];
        case 8 % pnonlin
            range(:,6) = [-2; 0];
    end
else
    switch datanum
        case 4
            if ~dopnonlin, range(:,3) = [0; .4]; end
            range(:,5) = [-8; -4];
    end
end

% output
LB = range(1,:);
UB = range(2,:);
