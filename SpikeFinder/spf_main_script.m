
%% Define global variable for the main data folder 

% This is the folder that contains the spikefinder.test and
% spikefinder.test sub-folders. Additional folders will be created in it by
% the function spf_folders.

global SpikeFinderDataDir
SpikeFinderDataDir = 'E:\Users\Thomas\Thomas\PROJECTS\1611_SpikeFinder\data';

%% Choose a dataset

dataset = 1;

%% Train on the specified dataset
% Note that the current procedure for training MLspike takes hours if not
% days...

% When loading dataset 2, a few manual corrections are applied to the data
% to remove big jumps. The program is notified to apply these corrections
% by passing dataflag 92 instead of 2
if dataset==2
    dataflag = 92;
else
    dataflag = dataset;
end

% While some parameters are trained, some others are fixed manually.
% Different manual parameter sets are defined in function spf_parameters in
% the form of a 3-digits code called 'methodflag'. 
% Briefly:
% - The 1st digits indicates whether to use MAP, proba or samples output
% (at the end, proba output where systematically preferred), define the
% type of nonlinearity (sub-linear for OGB, supra-linear for GCamp) and
% whether to use heuristics for estimating noise level (but the best
% MLspike submission to SpikeFinder did not use them).
% - The 2nd digit sets some internal parameters of the algorithm.
% - The 3rd digit defines temporal binning and some additional optional
% parameters.
% Below are indicated the best methodflags found for each dataset (and for
% the best MLspike submission), but others can be tested as well.
best_method_flags = [223 223 523 223 523 525 523 523 525 523];
methodflag = best_method_flags(dataset);

% Go!
% Results are stored regularly to the 'precomp' folder, so that
% computations can be resumed after an interruption, just by calling the
% same command (but 'fromscratch' option forces a restart from zero).
% Range for the parameters being estimated are defined in function
% spf_getrange.
spf_train(dataflag, methodflag)

% It is possible to execute the training in a separate Matlab process with
% the 'batch' flag, and to recruit N workers for parallel computing with
% 'batchN' flag.
% spf_train(dataflag, methodflag, 'batch6')

%% During the training

% The state of the current training can be displayed with functions
% spf_summary, spf_displayEvalPoints and spf_monitor (see their help for
% options)
spf_summary

% Below are all methodflags tested on the training data, as well as
% corresponding scores and best parameters. Note that scores slightly
% differ from those published on the SpikeFinder contest page because for
% each dataset the mean (rather than the median) is computed over dataset's
% neurons.
% To directly run estimations using these parameters, follow the code in
% spf_publish under "Run estimation with estimated parameters on the test
% set".
% Dataset 01: 0.51315 using proba223 (parset=-0.9585 0.0648 0.0022 -0.6579 -2.2808, smooth=0.0689, delay=0.0100)
%             0.51233 using proba425 (parset=-0.7997 0.0449 0.0119 -0.0196 -1.6719, smooth=0.0389, delay=0.0200)
%             0.50831 using proba525 (parset=-0.6942 0.1499 0.1578 -0.0124 -0.5591 -2.1554, smooth=0.0418, delay=0.0200)
%             0.50109 using proba423 (parset=-0.7355 -0.0080 0.0257 -0.0969 -2.0000, smooth=0.1661, delay=0.0100)
% Dataset 92: 0.47127 using proba223 (parset=-0.5107 0.0246 0.0057 -0.3797 -2.8215, smooth=0.2289, delay=-0.0300)
%             0.47019 using proba425 (parset=-0.3887 0.0496 0.0101 0.2536 -2.0802, smooth=0.2381, delay=-0.0200)
%             0.46774 using proba423 (parset=-0.6407 -0.0801 0.0382 0.1725 -1.6586, smooth=0.2441, delay=-0.0200)
%             0.46541 using proba525 (parset=-0.4746 0.0442 0.1155 -0.0122 -0.5563 -2.4708, smooth=0.2571, delay=-0.0200)
% Dataset 03: 0.47471 using proba523 (parset=-1.2410 0.3563 0.2564 -0.0012 -0.6764 -4.2916, smooth=0.1988, delay=-0.0100)
%             0.47468 using proba525 (parset=-1.4461 0.4554 0.4948 -0.0072 -0.7659 -4.4545, smooth=0.1689, delay=0.0000)
%             0.46886 using proba625 (parset=-1.4425 0.4102 0.2635 -0.0020 0.4670 -2.6777, smooth=0.2352, delay=0.0000)
%             0.46814 using proba623 (parset=-1.5000 0.4010 0.4756 -0.0108 0.5000 -4.0000, smooth=0.2595, delay=-0.0100)
% Dataset 04: 0.49214 using proba423 (parset=-0.5425 -0.0935 0.0009 0.4996 -4.9990, smooth=0.2894, delay=-0.0500)
%             0.48317 using proba223 (parset=-0.3909 -0.1235 0.0015 -0.1122 -4.8481, smooth=0.2749, delay=-0.0500)
% Dataset 05: 0.48382 using proba623 (parset=-2.0082 0.2819 0.8712 -0.0072 -0.0127 -4.4275, smooth=0.2538, delay=0.1000)
%             0.48128 using proba523 (parset=-1.9842 0.2928 1.6696 -0.0460 -1.0679 -4.3918, smooth=0.2378, delay=0.1000)
%             0.47265 using proba525 (parset=-1.8780 0.3927 1.8691 -0.0541 -1.0540 -4.3387, smooth=0.2301, delay=0.1100)
% Dataset 06: 0.67299 using proba623 (parset=-0.7817 0.0014 0.3167 0.0149 0.2976 -2.2202, smooth=0.0894, delay=0.0200)
%             0.65920 using proba525 (parset=-0.7538 0.0815 0.3095 0.0014 -0.6647 -2.3849, smooth=0.1005, delay=0.0300)
%             0.65898 using proba523 (parset=-0.8030 -0.2065 0.6147 0.1755 -0.4428 -2.1422, smooth=0.1129, delay=0.0200)
% Dataset 07: 0.75386 using proba523 (parset=-0.3788 -0.3356 1.0952 -0.0306 -0.3730 -1.4090, smooth=0.0224, delay=0.0100)
%             0.74644 using proba623 (parset=-0.5806 -0.2646 0.3700 0.0898 0.0555 -2.4423, smooth=0.0224, delay=0.0100)
%             0.67321 using proba525 (parset=-0.8284 -0.1837 1.1222 -0.0198 -0.6303 -1.7418, smooth=0.0418, delay=0.0200)
% Dataset 08: 0.70219 using proba623 (parset=-0.6782 0.0596 0.4830 0.2052 0.0836 -0.9463, smooth=0.0562, delay=0.0200)
%             0.70070 using proba523 (parset=-0.5605 0.3809 0.2296 0.0840 -0.5553 -0.7643, smooth=0.0477, delay=0.0200)
%             0.66593 using proba525 (parset=-0.5605 0.3809 0.2296 0.0840 -0.5554 -0.7643, smooth=0.0226, delay=0.0300)
% Dataset 09: 0.51898 using proba525 (parset=-0.4624 0.3934 0.1241 -0.0177 -0.5255 -1.1719, smooth=0.0420, delay=0.0200)
%             0.51863 using proba523 (parset=-0.6632 0.3832 0.0688 -0.0062 -0.5024 -2.4724, smooth=0.0226, delay=0.0100)
%             0.51424 using proba623 (parset=-0.8238 0.1600 -0.0036 -0.0007 0.1505 -2.4851, smooth=0.0226, delay=0.0100)
% Dataset 10: 0.70469 using proba623 (parset=-0.4203 -0.2444 -0.0176 0.0015 0.1020 -2.3663, smooth=0.0343, delay=0.0100)
%             0.69739 using proba523 (parset=-0.3337 -0.1606 0.1050 -0.0057 -0.4902 -2.4600, smooth=0.0224, delay=0.0100)
%             0.68178 using proba525 (parset=-0.2330 -0.2534 0.0755 -0.0021 -0.4748 -2.4112, smooth=0.0418, delay=0.0200)


%% Run on the test data and publish everything

% The following function will first publish the training results (in the
% 'submissions' folder), and then if test data exist for this dataset, run
% MLspike on it with the current best parameters and publish the results.
% More details on the test data estimations will also be saved in the
% 'testres' folder.
spf_publish(dataset)


