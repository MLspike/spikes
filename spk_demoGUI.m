classdef spk_demoGUI < hgsetget
   
    properties
        data     % simulation result
        res     % estimation result
    end
    properties (Dependent)
        pgen    % spikes simulation parameters
        pcal    % calcium simulation parameters
        pest    % estimation parameters
    end
    properties (Access='private')
        grob    % graphic objects
        Xdat    % control for data parameters
        Xest    % control for estimation parameters
        owndatamsgshown = false;
        tonwarningshown = false;
    end
    
    % Init
    methods
        function G = spk_demoGUI
            % graphic objects
            % (controls)
            hf = fn_figure('MLspike demo - Controls');
            fn_setfigsize(hf,600,700)
            set(hf,'numbertitle','off')
            G.grob.hf = hf;
            G.grob.pdat = uipanel('parent',hf,'pos',[.01  .01 .485 .98]);     % controls for spikes parameters
            G.grob.pest = uipanel('parent',hf,'pos',[.505 .09 .485 .90]);     % controls for estimation parameters
            G.grob.uerase = uicontrol('parent',hf,'units','normalized','pos',[.505 .01 .485 .07], ...
                'string','Erase estimation result','callback',@(u,e)eraseresult(G));
            initcontrols(G)
            % (display)
            G.grob.display = fn_figure('MLspike demo - Result');
            set(G.grob.display,'numbertitle','off')
            % run
            getdata(G)
        end
        function initcontrols(G)
            
            % DATA
            pdat = struct( ...
                'use__my__own__data',false, ...
                ... SPIKE SIM
                'noiseseed1',[], ...
                'rate',1,'T',30,'mode','bursty', ...
                ... CALCIUM SIM
                'noiseseed2',[], ...
                'dtsim',.02, ...
                'a',.1,'tau',1,'ton',0, ...
                'nonlinearity','saturation (OGB)', ...
                'saturation',.1,'hill',1.7, ...
                'p2',0.5,'p3',0.01, ...
                'sigma',.03, ...
                'drift__amp',.05,'drift__n',5, ...
                ... MY OWN DATA
                'calcium','', ...
                'dtown','', ...
                'real__spike__times','');
            spec = struct( ...
                'DATA',        'label', ...
                'use__my__own__data','logical', ...
                ... SPIKE SIM
                'spikes__simulation',        'label', ...
                'noiseseed1','xstepper 1 0 1000', ...
                'rate',     'double', ...
                'T',        'double', ...
                'mode',     {{'periodic' 'fix-rate' 'vary-rate' 'bursty'}}, ...
                ... CALCIUM SIM
                'calcium__simulation','label', ...
                'noiseseed2','xstepper 1 0 1000', ...
                'dtsim','double', ...
                'a','double','tau','double','ton','double', ...
                'nonlinearity',{{'none' 'saturation (OGB)' 'cubic polynom (GCaMP)' 'Hill+sat. (GCaMP)'}}, ...
                'saturation','double','hill','double','p2','double','p3','double', ...
                'sigma','double', ...
                'drift__amp', 'double', 'drift__n',  'double', ...
                ... MY OWN DATA
                'owndata','label', ...
                'calcium','char', ...
                'dtown','double', ...
                'real__spike__times','char');
            [spec(2).noiseseed1 spec(2).noiseseed2] = deal('noise seed');
            [spec(2).dtsim spec(2).dtown] = deal('dt');
            spec(2).owndata = 'data from Matlab variable(s)';
            G.Xdat = fn_control(pdat,spec,@(s)getdata(G),G.grob.pdat);
            checkavailablepar(G,'dat');
            
            % ESTIMATION
            p = struct('output','MAP spike train', ...
                'a',pdat.a,'tau',pdat.tau,'ton',pdat.ton, ...
                'nonlinearity',pdat.nonlinearity, ...
                'saturation',pdat.saturation,'hill',pdat.hill, ...
                'p2',pdat.p2,'p3',pdat.p3, ...
                'sigma',.025,'drift',.015, ...
                'bmin',.7,'bmax',1.3, ...
                'cmax',10,'nc',50,'np',50,'nb',50);
            spec = struct( ...
                'ESTIMATION',   'label', ...
                'output',{{'MAP spike train' 'spike probabilities' 'spike samples'}}, ...
                'model__parameters',   'label', ...
                'a','double','tau','double','ton','double', ...
                'nonlinearity',{{'none' 'saturation (OGB)' 'cubic polynom (GCaMP)' 'Hill+sat. (GCaMP)'}}, ...
                'saturation','double','hill','double','p2','double','p3','double', ...
                'sigma','double','drift','double', ...
                'range__for__baseline','label', ...
                'bmin','double','bmax','double', ...
                'discretization__parameters','label', ...
                'cmax','double','nc','double','np','double',...
                'nb','double');
            G.Xest = fn_control(p,spec,@(s)doest(G),G.grob.pest);
            checkavailablepar(G,'est');
            
            % no action if Matlab is busy
            set(findobj(G.grob.hf,'type','uicontrol','style','pushbutton'),'BusyAction','cancel')
            % normalized positions
            set(findobj(G.grob.hf,'type','uicontrol'),'units','normalized')
        end
    end
    
    % Get parameters
    methods
        function pgen = get.pgen(G)
            p = G.Xdat.s;
            pgen = struct('rate',p.rate,'T',p.T,'mode',p.mode);
        end
        function pcal = get.pcal(G)
            p = G.Xdat.s;
            pcal = spk_calcium('par');
            pcal.dt = p.dtsim;
            pcal.T = p.T;
            pcal.a = p.a;
            pcal.tau = p.tau;
            pcal.ton = p.ton;
            pcal.saturation = p.saturation;
            pcal.hill = p.hill;
            pcal.pnonlin = [p.p2 p.p3];
            switch p.nonlinearity
                case 'none'
                    [pcal.saturation pcal.hill pcal.pnonlin] = deal(0,1,[]);
                case 'saturation (OGB)'
                    [pcal.hill pcal.pnonlin] = deal(1,[]);
                case 'cubic polynom (GCaMP)'
                    [pcal.saturation pcal.hill] = deal(0,1);
                case 'Hill+sat. (GCaMP)'
                    pcal.pnonlin = [];
            end
            pcal.sigma = p.sigma;
            pcal.drift.parameter = [p.drift__n p.drift__amp];
        end
        function pest = get.pest(G)
            p = G.Xest.s;
            % default values
            pest = tps_mlspikes('par');
            % regular parameters
            pest.algo.estimate = fn_switch(p.output, ...
                'MAP spike train','MAP','spike probabilities','proba','spike samples','samples');
            if strcmp(pest.algo.estimate,'samples')
                pest.algo.nsample = 4;
            end
            pest.dt = G.data.dt;
            pest.a = p.a;
            pest.tau = p.tau;
            pest.ton = p.ton;
            pest.saturation = p.saturation;
            pest.hill = p.hill;
            pest.pnonlin = [p.p2 p.p3];
            switch p.nonlinearity
                case 'none'
                    [pest.saturation pest.hill pest.pnonlin] = deal(0,1,[]);
                case 'saturation (OGB)'
                    [pest.hill pest.pnonlin] = deal(1,[]);
                case 'cubic polynom (GCaMP)'
                    [pest.saturation pest.hill] = deal(0,1);
                case 'Hill+sat. (GCaMP)'
                    pest.pnonlin = [];
            end
            pest.finetune.sigma = p.sigma;
            pest.drift.parameter = p.drift;
            % discretization parameters
            pest.algo.cmax = p.cmax;
            pest.algo.nc = p.nc;
            pest.algo.np = p.np;
            pest.F0 = [p.bmin p.bmax];
            pest.algo.nb = p.nb;
        end
        function checkavailablepar(G,flag)
            switch flag
                case 'dat'
                    X = G.Xdat;
                case 'est'
                    X = G.Xest;
            end
            xx = X.controls;
            names = {xx.name};
            % use my own data?
            if strcmp(flag,'dat')
                F0 = {'DATA' 'use__my__own__data'};
                F = {'owndata' 'calcium' 'dtown' 'real__spike__times'};
                doown = X.use__my__own__data;
                for i=1:length(xx)
                    use = onoff(ismember(names{i},F0) || (ismember(names{i},F)==doown));
                    set(xx(i).hname,'enable',use)
                    if ~isempty(xx(i).hval), set(xx(i).hval,'enable',use), end
                end
                if doown, return, end
            end
            % nonlinearity parameters
            switch X.nonlinearity
                case 'none'
                    en = [0 0 0 0];
                case 'saturation (OGB)'
                    en = [1 0 0 0];
                case 'cubic polynom (GCaMP)'
                    en = [0 0 1 1];
                case 'Hill+sat. (GCaMP)'
                    en = [1 1 0 0];
            end
            F = {'saturation' 'hill' 'p2' 'p3'};
            for i=1:length(F)
                xi = xx(strcmp(names,F{i}));
                set([xi.hname xi.hval],'enable',onoff(en(i)))
            end
            % number of drifts only if drift amplitude
            if strcmp(flag,'cal')
                xi = xx(strcmp(names,'drift__n'));
                set([xi.hname xi.hval],'enable',onoff(X.drift__amp>0))
            end
            % discretization parameters that are really needed
            if strcmp(flag,'est')
                xi = xx(strcmp(names,'nb'));
                set([xi.hname xi.hval],'enable',onoff(X.drift>0))
                xi = xx(strcmp(names,'np'));
                set([xi.hname xi.hval],'enable',onoff(X.ton>0))
            end
        end
    end
    
    % Action
    methods
        function getdata(G)
            % update which controls are enabled
            checkavailablepar(G,'dat');
            if G.Xdat.use__my__own__data>0 && ~G.owndatamsgshown % give some instructions for own data
                waitfor(msgbox({'To run estimation on your own data, specify the name of the Matlab variable where the calcium signal is stored (it should be a vector).' ...
                    'Please also specify the sampling time (in seconds).' ...
                    'If real spikes were also recorded, you can also specify the variable where spike times (in seconds) are stored, so estimation error can be evaluated.'}, ...
                    'Using own data'))
                G.owndatamsgshown = true;
            end
            
            % get spikes and calcium data
            if G.Xdat.use__my__own__data
                ok = getowndata(G);
                G.data.dt = G.Xdat.dtown;
            else
                simulspikes(G)
                simulcalcium(G)
                ok = true;
                G.data.dt = G.Xdat.dtsim;
            end
            
            % display
            clf(G.grob.display)
            if ~ok, return, end
            spk_display(G.data.dt,G.data.spikes,G.data.calcium,'in',G.grob.display)
            
            % also estimate?
            if G.Xest.immediateupdate, doest(G), end
        end
        function ok = getowndata(G)
            try
                calcium = evalin('base',G.Xdat.calcium);
                ok = isnumeric(calcium) && ismatrix(calcium) && isscalar(G.Xdat.dtown);
                if ok && ~isempty(G.Xdat.real__spike__times)
                    [nt, nx] = size(cacium); 
                    if nt==1, calcium=calcium'; end
                    spikes = evalin('base',G.Xdat.real__spike__times);
                    if iscell(spikes)
                        ok = (length(spikes)==nx);
                    elseif ~isnumeric(spikes)
                        ok = false;
                    elseif isempty(spikes)
                        ok = true;
                    elseif ismatrix(spikes)
                        ok = all(size(spikes)==[nt nx]);
                        if ~ok && all(size(spikes)==[nx nt])
                            spikes = spikes';
                            [nt, nx] = deal(nx,nt);
                            ok = true;
                        end
                    else
                        ok = false;
                    end
                    if ok
                        if ~iscell(spikes), G.data.spikes = {spikes}; end
                    end
                else
                    G.data.spikes = {};
                end
                if ok
                    G.data.calcium = calcium; 
                else
                    [G.data.calcium, G.data.spikes] = deal([],{});
                end
            catch
                ok = false;
            end
        end
        function simulspikes(G)
            p = G.pgen;
            if ~isempty(G.Xdat.noiseseed1), rng(G.Xdat.noiseseed1,'twister'), end
            G.data.spikesadd = spk_gentrain(p.rate,10+p.T,p.mode); % generate spikes before time 0 to get non-baseline calcium at time 0
            G.data.spikes = {G.data.spikesadd(G.data.spikesadd>10)-10};
            % clear previous calcium
            G.data.calcium = [];
        end
        function simulcalcium(G)
            p = G.pcal;
            if ~isempty(G.Xdat.noiseseed2), rng(G.Xdat.noiseseed2,'twister'), end
            p.T = 10+p.T;
            calciumadd = spk_calcium(G.data.spikesadd,p); % generate calcium starting 10s before time 0
            G.data.calcium = calciumadd(round(10/p.dt)+1:end); % keep only the part of the signal after time 0
        end
        function doest(G)
            % parameters
            checkavailablepar(G,'est');
            if G.Xest.ton>0 && ~G.tonwarningshown % issue a warning first time a rise time is used
                waitfor(warndlg({'You introduced a rising time in the estimation, this will raise the dimension of the state space from 2 to 3 and might slow down estimations.' ...
                    'Estimation speed can be improved by adjusting the "discretization parameters" so as to make a coarser discretization grid.' ...
                    'However, this needs to be done carefully in order not to degrade estimation accuracy. To do so, monitor the displays in the "tps_mlspike GRAPH SUMMARY" figure.' ...
                    'As a suggestion, some discretization parameters will now be automatically changed.'}, ...
                    'Estimation with a rise time'))
                G.Xest.cmax = 5;
                G.Xest.nc = 45;
                G.Xest.bmin = 0.8;
                G.Xest.bmax = 1.2;
                G.Xest.nb = 35;
                G.tonwarningshown = true;
            end
            p = G.pest;
            
            % estimate
            c = fn_watch(G.grob.hf,'startnow');
            [G.res.spikest, G.res.fit, G.res.drift] = spk_est(G.data.calcium,p);
            
            % display
            if ~ishandle(G.grob.display) % result figure was closed
                G.grob.display = fn_figure('MLspike demo - Result');
                set(G.grob.display,'numbertitle','off')
            end
            hf = G.grob.display; clf(hf)
            switch p.algo.estimate
                case 'MAP'
                    spk_display(p.dt,[G.data.spikes {G.res.spikest}], ...
                        {G.data.calcium G.res.fit G.res.drift},'in',hf)
                case 'proba'
                    spk_display(p.dt,[G.data.spikes {G.res.spikest}], ...
                        {G.data.calcium G.res.fit G.res.drift},'in',hf,'rate')
                case 'samples'
                    for i=1:4
                        ha = subplot(2,2,i,'parent',hf);
                        ksamp = round(1+(i-1)/(4-1)*(p.algo.nsample-1));
                        spk_display(p.dt,[G.data.spikes G.res.spikest(ksamp)], ...
                            {G.data.calcium G.res.fit(:,ksamp) G.res.drift(:,ksamp)},'in',ha)
                        ylabel(ha,sprintf('sample %i/%i',ksamp,p.algo.nsample))
                    end
            end
        end
        function eraseresult(G)
            clf(G.grob.display)
            spk_display(G.data.dt,G.data.spikes,G.data.calcium,'in',G.grob.display)
        end
    end
    
end
