function lprobeListOutput = default_lprobe( lprobeNames )
%LP.DEFAULT_LPROBE select default Langmuir probes
% 
% Langmuir probes are defined by class LP.LPROBE
%
%  LP.DEFAULT_LPROBE print the list of available probes
%
%  OUT = LP.DEAFAULT_LPROBE return all Langmuir probes
%
%  OUT = LP.DEAFAULT_LPROBE({name1,name2,..}) return selectec Langmuir probes
%

lprobeList = {'sphere',       @lp_sphere;...
	            'wire',         @lp_wire;...
	            'sphere+wire',  @lp_sphere_wire;...
	            'Cluster',      @lp_Cluster;...
	            'MMS_SDP',      @lp_MMS_SDP;...
	            'MMS_ADP',      @lp_MMS_ADP;...
	            'Solar_Orbiter',@lp_Solar_Orbiter...
	            };
lprobeNamesList = lprobeList(:,1);
lprobeLpFunc    = lprobeList(:,2);

if nargin == 0 && nargout == 0
	for iLprobe = 1:numel(lprobeNamesList),
		disp([num2str(iLprobe) '. ' lprobeNamesList{iLprobe}]);
	end
	return;
elseif nargin == 0
	lprobeNames = lprobeNamesList; 
end
if ischar(lprobeNames), lprobeNames = {lprobeNames};   end

iFoundLprobe = [];
for iLprobe = 1:numel(lprobeNames),
	iFoundLprobe = [iFoundLprobe find(strcmp(lprobeNames(iLprobe),lprobeNamesList))]; %#ok<AGROW>
end

if iFoundLprobe
	lprobeListOutput = lprobeLpFunc{iFoundLprobe(1)}();
	for j=2:numel(iFoundLprobe)
		lprobeListOutput(j) = lprobeLpFunc{iFoundLprobe(j)}();
	end
end

% 		name
% 		surface
% 		radiusSphere
% 		radiusWire
% 		lengthWire

	function Lprobe = lp_sphere
		Lprobe = lp.lprobe;
		Lprobe.name = 'sphere';
		Lprobe.surface = 'themis';
		Lprobe.radiusSphere = 0.04; % 4cm
	end
	function Lprobe = lp_wire
		Lprobe = lp.lprobe;
		Lprobe.name = 'cylinder/wire';
		Lprobe.surface = 'themis';
		Lprobe.radiusWire = 1e-3;
		Lprobe.lengthWire = 1;
	end
	function Lprobe = lp_sphere_wire
		Lprobe = lp.lprobe;
		Lprobe.name = 'sphere+wire';
		Lprobe.surface = 'themis';
		Lprobe.radiusSphere = 0.04; % 4cm
		Lprobe.radiusWire = 1e-3;
		Lprobe.lengthWire = 1;
	end
	function Lprobe = lp_Cluster
		Lprobe = lp.lprobe;
		Lprobe.name = 'Cluster';
		Lprobe.surface = 'cluster';
		Lprobe.radiusSphere = 0.04; % 4cm
		Lprobe.radiusWire = 1e-3;
		Lprobe.lengthWire = 1;
	end
	function Lprobe = lp_MMS_SDP
		Lprobe = lp.lprobe;
		Lprobe.name = 'MMS SDP';
		Lprobe.surface = 'TiN';
		Lprobe.radiusSphere = 0.04; % 4cm
		Lprobe.radiusWire = 0.12e-3;
		Lprobe.lengthWire = 1.75;
	end
	function Lprobe = lp_MMS_ADP
		Lprobe = lp.lprobe;
		Lprobe.name = 'MMS ADP';
		Lprobe.surface = 'cluster';
		Lprobe.radiusWire = 0.5e-2;
		Lprobe.lengthWire = 1;
	end
	function Lprobe = lp_Solar_Orbiter
		Lprobe = lp.lprobe;
		Lprobe.name = 'Solar Orbiter';
		Lprobe.surface = 'elgiloy';
		Lprobe.radiusWire = (0.01887+0.0314)/2/2;
		Lprobe.lengthWire = 6.1604;
	end

end

