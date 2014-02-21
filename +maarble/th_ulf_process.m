function th_ulf_process(TT,thId,freqRange)
%TH_ULF_PROCESS  process THEMIS ULF data
%
%  th_ulf_process(TT,thId,freqRange)

% ----------------------------------------------------------------------------
% "THE BEER-WARE LICENSE" (Revision 42):
% <yuri@irfu.se> wrote this file.  As long as you retain this notice you
% can do whatever you want with this stuff. If we meet some day, and you think
% this stuff is worth it, you can buy me a beer in return.   Yuri Khotyaintsev
% ----------------------------------------------------------------------------

% This software was developed as part of the MAARBLE (Monitoring,
% Analyzing and Assessing Radiation Belt Energization and Loss)
% collaborative research project which has received funding from the
% European Community's Seventh Framework Programme (FP7-SPACE-2011-1)
% under grant agreement n. 284520.



%% defaults
if nargin < 1
  %TT = [iso2epoch('2008-04-20T17:40:00Z') iso2epoch('2008-04-20T23:30:00Z')]; thId = 'e'; freqRange = 'pc35';
  TT = [iso2epoch('2008-04-20T22:20:00Z') iso2epoch('2008-04-20T23:30:00Z')]; thId = 'e'; freqRange = 'pc12';
elseif nargin < 3
  freqRange = 'all';
end

%% setup
dataDir = '/data/themis';
plotFlag = 1;
exportFlag = 1;

wantPC12 = 0;
wantPC35 = 0; wantSCM = 0;
if ischar(freqRange)
  switch lower(freqRange)
    case 'all'
      wantPC12 = 1;
      wantPC35 = 1;
    case 'pc12'
      wantPC12 = 1;
    case 'pc35'
      wantPC35 = 1;
    otherwise
      error('Invalid value for freqRange')
  end
else
  if freqRange(1) > 1, wantSCM = 1; end
end

tmpR = load(sprintf('%s%smRth.mat',dataDir,filesep), '-mat', ['Rth' thId]);
gseR = tmpR.(['Rth' thId]);
gseV=gseR(1:end-1,:); dtR = diff(gseR(:,1));
for iComp=2:4, gseV(:,iComp)=diff(gseR(:,iComp))./dtR; end
clear tmpR dtR

if ~isa(TT,'irf.TimeTable'), TT=irf.TimeTable(TT); end

for ievent=1:numel(TT),
tint=TT.TimeInterval(ievent,:);
sprintf('processing %s\n',irf_disp_iso_range(tint,1))


%% Load data
% Round time interval to minutes
tint = [floor(tint(1)/60) ceil(tint(2)/60)]*60;
% Extend time interval by these ranges to avoid edge effects 
DT_PC5 = 80*60; DT_PC2 = 120;

bs = th_read_l2(['th' thId '_fgs_dsl'],tint+DT_PC5*[-1 1]);
  [bs,~,ttGap] = th_clean_eb(bs);
if isempty(bs), 
    irf.log('warning','skipping, no BS data'),continue, 
end
if wantPC35
  es = th_read_l2(['th' thId '_efs_dot0_dsl'],tint+DT_PC5*[-1 1]);
  es=th_clean_eb(es,'NaN');
end
if wantPC12
  bl = th_read_l2(['th' thId '_fgl_dsl'],tint+DT_PC2*[-1 1]);
  ef = th_read_l2(['th' thId '_eff_dot0_dsl'],tint+DT_PC2*[-1 1]);
  if isempty(ef)
    irf.log('warning','no EF data')
  else
    % Remove backward time jumps in EF
    % Example THE 2007-08-11T09:40:02.489975Z (3 points)
    while true
      idxJump = find(diff(ef(:,1))<=0);
      if isempty(idxJump), break, end
      idxJump = idxJump(1);
      irf.log('warning',['EF time jumps back at ' epoch2iso(ef(idxJump,1))])
      ii = find(ef(:,1)<=ef(idxJump,1)); ii(ii<=idxJump) = [];
      irf.log('warning',sprintf('Disregarging %d points',length(ii)))
      ef(ii,:) = [];
    end
  end
end

R = gseR; % XXX FIXME: this must be a real transformation to DSL
R = irf_tlim(R,tint+DT_PC5*[-1 1]);
V = gseV;
V = irf_tlim(V,tint+DT_PC5*[-1 1]);

%% Calculate and plot
bf = irf_filt(bs,0,1/600,1/5,5);
t_1min = ((tint(1)-DT_PC5):60:(tint(end)+DT_PC5))';
B0_1MIN = irf_resamp(bf,t_1min); %clear bf
nGaps = size(ttGap.TimeInterval,1);
if nGaps>0
  for iGap=1:nGaps
    tintGap = ttGap.TimeInterval(iGap,:);
    if diff(tintGap)>300
      irf.log('warning',['Long ' ttGap.Comment{iGap} ' in BS at '...
        irf_disp_iso_range(tintGap,1) ' > 5 min'])
      B0_1MIN = irf_tlim(B0_1MIN,tintGap+[-30 30],1);
    end
  end
end
facMatrix = irf_convert_fac([],B0_1MIN,R);

if wantPC35
  t_1SEC = ((tint(1)+2-DT_PC5):1:(tint(end)+DT_PC5))';
  B_1SEC = irf_resamp(bs,t_1SEC);
  
  % Set Gaps to NaN. for safety we set both E and B
  if nGaps>0
    for iGap=1:nGaps
      tintGap = ttGap.TimeInterval(iGap,:);
      B_1SEC(B_1SEC(:,1)>=tintGap(1)-0.5 & B_1SEC(:,1)<=tintGap(2)+0.5,2:end) = NaN;
      es(es(:,1)>=tintGap(1)-0.5 & es(:,1)<=tintGap(2)+0.5,2:end) = NaN;
    end
  end
  
  E3D_1SEC = irf_resamp(es,t_1SEC);
  
  % Construct the inertial frame
  evxb = irf_tappl(irf_cross(B_1SEC,irf_resamp(V,t_1SEC)),'*1e-3*(-1)');
  iE3D_1SEC = E3D_1SEC;
  iE3D_1SEC(:,2:4) = iE3D_1SEC(:,2:4) - evxb(:,2:4);
  % Remove all E-fields > 10 mV/m in inertial frame
  for iComp=2:4, iE3D_1SEC(abs(iE3D_1SEC(:,iComp))>10, 2:4) = NaN; end
  
  ebsp = ...
    irf_ebsp(iE3D_1SEC,B_1SEC,[],B0_1MIN,R,'pc35',...
    'fac','polarization','noresamp','fullB=dB','facMatrix',facMatrix);
  tlim_ebsp();
  if plotFlag
    close all
    h = irf_pl_ebsp(ebsp);
    irf_zoom(h,'x',tint)
    title(h(1),['THEMIS ' upper(thId) ', ' irf_disp_iso_range(tint,1)])
    orient tall
    %set(gcf,'paperpositionmode','auto')
    print('-dpng',['MAARBLE_TH' upper(thId) '_ULF_PC35_' irf_fname(tint,5)])
  end
  if exportFlag
    maarble.export(ebsp,tint,['th' thId],'pc35')
  end
end
if wantPC12
  if isempty(bl), 
    irf.log('warning','skipping PC12, no BL data'),continue, 
  end
    
  baseFreq = 16;
  fSampB = 1/median(diff(bl(:,1))); 
  if isempty(ef)
    fSampE = NaN; 
    t_BASE = (fix(bl(1,1)):1/baseFreq:ceil(bl(end,1)))';
    iE3D_BASE = [];
  else
    fSampE = 1/median(diff(ef(:,1)));
    t_BASE = (fix(min(bl(1,1),ef(1,1))):1/baseFreq:ceil(max(bl(end,1),ef(end,1))))';
  end
  
  B_BASE = irf_resamp(bl,t_BASE);
  ii = find(diff(bl(:,1))>2/fSampB);
  if ~isempty(ii)
    for iGap=ii
      irf.log('warning',['Long gap in BL ' irf_disp_iso_range(bl(iGap+[0 1],1)')])
      B_BASE(t_BASE(:,1)>bl(iGap,1) & t_BASE(:,1)<bl(iGap+1,1),2:4) = NaN;
    end
  end
    
  E3D_BASE = irf_resamp(ef,t_BASE);
  ii = find(diff(ef(:,1))>2/fSampE);
  if ~isempty(ii)
    for iGap=ii
      irf.log('warning',['Long gap in EF ' irf_disp_iso_range(ef(iGap+[0 1],1)')])
      E3D_BASE(t_BASE(:,1)>ef(iGap,1) & t_BASE(:,1)<ef(iGap+1,1),2:4) = NaN;
    end
  end
  
  % Construct the inertial frame
  evxb = irf_tappl(irf_cross(B_BASE,irf_resamp(V,t_BASE)),'*1e-3*(-1)');
  iE3D_BASE = E3D_BASE;
  iE3D_BASE(:,2:4) = iE3D_BASE(:,2:4) - evxb(:,2:4);
  
  tic
  ebsp = irf_ebsp(iE3D_BASE,B_BASE,[],B0_1MIN,R,'pc12',...
    'fac','polarization','noresamp','fullB=dB','dedotb=0','nav',12,...
    'facMatrix',facMatrix);
  toc
  tlim_ebsp();
  if isempty(ebsp.t)
    irf.log('warning','No result for PC12'),continue 
  end
  irf_wave_detection_algorithm(ebsp, thId);
  flim_ebsp(fSampB,fSampE);
  if plotFlag
    close all
    h = irf_pl_ebsp(ebsp);
    irf_zoom(h,'x',tint)
    title(h(1),['THEMIS ' upper(thId) ', ' irf_disp_iso_range(tint,1)])
    orient tall
    %set(gcf,'paperpositionmode','auto')
    print('-dpng',['MAARBLE_TH' upper(thId) '_ULF_PC12_' irf_fname(tint,5)])
  end
  if exportFlag
    maarble.export(ebsp,tint,['th' thId],'pc12')
  end
end

% Export FAC matrix
[facMatrix.t,idxTlim]=irf_tlim(facMatrix.t,tint);
facMatrix.rotMatrix = facMatrix.rotMatrix(idxTlim,:,:);
if exportFlag
  maarble.export(facMatrix,tint,['th' thId])
end

end

  function tlim_ebsp % Trim ebsp to tlim
    IGNORE_FIELDS = {'f','flagFac','fullB','B0','r'};
    fieldsEBSP = fields(ebsp);
    tFields = setxor(fieldsEBSP,IGNORE_FIELDS);
    %nData = length(ebsp.t);
    [~,idx] = irf_tlim(ebsp.t,tint);
    for fName = tFields'
      if isempty(ebsp.(fName{:})), continue, end
      s = size(ebsp.(fName{:}));
      switch numel(s)
        case 2
          ebsp.(fName{:}) = ebsp.(fName{:})(idx,:);
        case 3
          ebsp.(fName{:}) = ebsp.(fName{:})(idx,:,:);
        otherwise
          error('wrong size!')
      end
    end
  end % tlim_ebsp()

  function flim_ebsp(fSampB,fSampE) % Thim the unmeasured frequencies
    IGNORE_FIELDS = {'t','f','flagFac','fullB','B0','r'};
    fieldsEBSP = fields(ebsp);
    tFields = setxor(fieldsEBSP,IGNORE_FIELDS);
    idxB = find(ebsp.f>fSampB/2); idxE = find(ebsp.f>fSampE/2);
    for fName = tFields'
      if isempty(ebsp.(fName{:})), continue, end
      if strcmpi(fName{:}(1:2),'ee'), idx = idxE;
      elseif strcmpi(fName{:}(1:2),'pf') %Poynting flux
        if fSampB>fSampE, idx = idxE; else idx = idxB; end
      else idx = idxB;
      end
      s = size(ebsp.(fName{:}));
      switch numel(s)
        case 2
          ebsp.(fName{:})(:,idx) = NaN;
        case 3
          ebsp.(fName{:})(:,idx,:) = NaN;
        otherwise
          error('wrong size!')
      end
    end
  end % flim_ebsp()
end