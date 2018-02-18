function d = spf_folders(folderflag,varargin)
% function d = spf_folders(folderflag[,subfolder1,...])
%---
% Return the path to the specified folder. Valid folder flags are 'train'
% (training data), 'test' (testing data), 'precomp' (storage of ongoing
% training results), 'testres' (results on test data) and 'submissions'
% (final results on both train and test data). 

% Check whether global variable SpikeFinderDataDir exists
global SpikeFinderDataDir
if ~isempty(SpikeFinderDataDir)
    
    % Use variable SpikeFinderDataDir to determine folder locations
    if ~exist(SpikeFinderDataDir,'dir')
        error(['''' SpikeFinderDataDir ''' is not a valid directory'])
    end
    switch folderflag
        case {'train' 'test'}
            d = fullfile(SpikeFinderDataDir, ['spikefinder.' folderflag]);
            if ~exist(d,'dir')
                error(['Could not find folder ''spikefinder.' folderflag ''''])
            end
        case {'precomp' 'testres' 'submissions' 'SUMO'}
            d = fullfile(SpikeFinderDataDir, folderflag);
            if ~exist(d,'dir')
                mkdir(d)
            end
        case 'data'
            d = SpikeFinderDataDir;
        otherwise
            error('Unknown folder flag ''%s''', folderflag)
    end
    
else
    
    % Usage for author only (T. Deneux)
    switch folderflag
        case {'train' 'test'}
            d = fn_cd('spf','data',['spikefinder.' folderflag]);
        case {'precomp' 'testres'}
            d = fn_cd('spf','save',folderflag);
        case {'data' 'submissions' 'SUMO'}
            d = fn_cd('spf',folderflag);
        otherwise
            error('Unknown folder flag ''%s''', folderflag)
    end
    
end

% Go to sub-folder or file?
if ~isempty(varargin)
    d = fullfile(d,varargin{:});
end


