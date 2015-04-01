function flow2d = run_pwrs_red(imgNr, storeFolder, subImg, ...
 dt, ds, ts, dj, tj, ps, oob, infoFileName, testing, segWeight, pseg, pjit, pego, as, tp, ots )

%example: pic 138
%run_pwrs_red( [138], './2Frames/', 10, 0.4, 0.045, 1.0, 20, 20, 25 );
% example: set: p.saveProposals =true; p.use3Frames = true;p.usePrevProps = true;
%run_pwrs_red( [151,27], './3Frames/', [8,9,10], 0.4, 0.045, 1.0, 20, 20, 25 );

global doKittiErrors;doKittiErrors =1; % turn on/off permanent error evaluation
doKitti = 1;

% folder with image data to read from -- ausmes certain structure
dataFolder =  '../../../Desktop/work/data/';
%dataFolder = '../../../data/data_stereo_flow/';
dataFolder =  '../kittidata/'; % local folder -- just a few images added

p.testing = 0; % whether to load kitti images from the training or test set
p.subImg  = 10; % the frame number to proces, eg 10 -> pics 9 (if 3-frame version)
% 10 and 11 are loaded. To suppress the camera motion, eg. from a stereo
% rig mounted on top of the car however a solution of the previous frame
% must be available: .usePrevProps = true and p.use3Frames   = true
% 
%
% save proposals for future frames in p.tempFolder
p.saveProposals = true;
% 'temporal' folder for multi frame version -- save&read proposals of previous frames
p.tempFolder   = '/cluster/scratch_xp/public/vogechri/Journal/Thesis/3f_4w/';
p.tempFolder   = './scratch/pastproposals';
% stores results in this folder
p.storeFolder  = './scratch/test';
p.sFolder      = p.storeFolder;
pFolder = './props/'; % store generated proposals here and reuse 
% formerly used to save paramters and misc. info about run
p.infoFileName = 'test.inf';
p.use3Frames   = true; % well use 3 not 2 frames -- assume pics loaded in ref/cam structure
p.usePrevProps = true; % use proposals from the previous time step -> loaded from tempFolder
% the procedure falls back to the standard 2 frame procedure in case there
% is no video data available
%
p.computeRflow = true;          % use flow from right camera 
p.generateMoreProposals = true; % demonstrates how to append additional proposals
%
p.fitSegs      = 1000;  % reduce # of fitted proposals to this value, default 1000 
p.ps  = 25; % patchsize of per pixel optimization: 25: 50x50 pixel, default 25
p.oob = 0.8;% penalty for border oracle (oracle is derived from the initial solutions)
p.tj  = 20; % truncation value of motion smoothness, default 20
p.dj  = 20; % truncation of disparity smoothness, default 20
p.ts  = 1;  % smoothness of the motion field (p.ds*p.ts), default 0.1
p.ds  = 0.045;% smoothness of disparity field default 0.045 or 0.05
p.dt  = 0.4; % data penalty, default 0.4
p.segWeight    = 0.1; % default 0.1: segmentation weight (mu in journal)

%%%% view-consistency parameters %%%%
p.autoScale  = 0.75; % occlusion/out-of-bounds penalty (+0.1) default 0.7 or 0.75 -- so 0.7+0.1 == 0.8 == maxdata*0.5
p.vcPottsSeg = 0.15; % theta_mvp on segment level, default 0.15 or 0.1
p.vcPottsPix = 0.25; % theta_mvp on pixel level, default 0.25 
p.vcEpsSeg   = 0.15;   % epsilon in vc data term on segment level, default 0.15 or 0.1
p.vcEpsPix   = 0.015;  % epsilon in vc data term on pixel level, default 0.15 or 0.1

p.doSeg=0; % do pwrsf (iccv13, basic) for preprocessing leads to a reduction of proposals
p.doJit=0; % do 'local replacement' (iccv13 or journal for reference) for preprocessing
           % very effective strategy - can be implemented for VC-SF as well
           % but was NOT for time reasons. So to use this we must first run
           % our basic model
p.doEgo=0; % do egomotion, same as above would be easy to integrate to VC but not done yet 


%%%% size of expansion area in segments - should/could be wrt size of images
p.gx=8; % 8 kitti - can be adjusted to image size / relative size
p.gy=5; % 5 kitti
p.gridSize= 16; % kitti default 16 but depends on image size trades accuracy with speed

if exist('pseg','var')
  p.doSeg = pseg;
end
if exist('pjit','var')
  p.doJit = pjit;
end
if exist('pego','var')
  p.doEgo = pego;
end
if exist('ots','var')
  p.vcEpsSeg = ots; % per segment tolerance epsilon
end
if exist('tp','var')
  p.vcPottsSeg = tp;
end
if exist('as','var')
  p.autoScale = as;
end
if exist('segWeight','var')
  p.segWeight = segWeight;
end
if exist('testing','var')
  p.testing = testing;
end
if exist('subImg','var')
  p.subImg = subImg;
end
if exist('storeFolder', 'var')
  p.storeFolder = storeFolder;
  p.sFolder = p.storeFolder;
end
if exist('infoFileName', 'var')
  p.infoFileName = infoFileName;
end
if exist('ps', 'var')
  p.ps= ps;
end
if exist('oob', 'var')
  p.oob=oob;
end
if exist('tj', 'var')
  p.tj=tj;
end
if exist('dj', 'var')
  p.dj = dj;
end
if exist('ts', 'var')
  p.ts =ts;
end
if exist('ds', 'var')
  p.ds = ds;
end
if exist('dt', 'var')
  p.dt = dt;
end
p.frames = 0;

global flow2DGt;
global flow2DGt_noc;
global Linux_;
Linux_ = 1;% different folders to load data from ?!

if ~isdeployed
  path(path,'./io/');  
  path(path,'./io/other/');
  path(path,'./mex/');
  path(path, './egomotion/');
  path(path,'./visualization/');
  path(path, './Segmentation');
  path(path, './weighting');
  path(path, './proposals');
  path(path,'./stuff/');
  path(path,'./pwrsf/');
  path(path,'../export_fig');%plotting - read the Readme
  path(path, '../sc/');%plotting - read the Readme
  path(path,'./stereo/');
  path(path,'../createFlow/');
  path(path,'../KittiIO/');
  path(path,'./ViewMappings');
end

testImages = imgNr;
subImages  = subImg;

permStr = '';
permStr = sprintf('%sdt:%1.2f ds:%.3f ts:%.3f dj:%.0f tj:%.0f oob:%.2f ps:%d \n\n', ...
  permStr, p.dt, p.ds, p.ts, p.dj, p.tj, p.oob, p.ps );
fprintf(2,permStr);

if ~exist(p.sFolder,'dir')
  mkdir(p.sFolder);
end

for testImg_ = 1:numel(testImages)  
  p.imgNr = testImages(testImg_);
  
  for subImg_ = 1:numel(subImages)
    p.subImg = subImages(subImg_ );
    
    if exist( sprintf('%s/RESULTS_K%03d_%02d_%s.txt', p.sFolder, p.imgNr, p.subImg, date), 'file' )
      continue;
    end
    
    if doKitti
      [cam, ref, imageName, flow2DGt, flow2DGt_noc] = loadKittiFlow(dataFolder , p.imgNr, p);
    else
      % NZ problem no cam pair can stereo reconstruct the pedestrians except
      % center right
      % left as left -> left right or left center
      % % [cam, ref, imageName, flow2DGt, flow2DGt_noc] = loadZealandFlow('c:/data/' , p.imgNr, p, 'people');%'bridge');
      
      % center as left -> center right as default -- later use 3 cams from center
      %  [cam, ref, imageName, flow2DGt, flow2DGt_noc] = loadZealandFlowCentered('c:/data/' , p.imgNr, p, 'people'); % , 'bridge');
      
      [cam, ref, imageName, flow2DGt, flow2DGt_noc] = loadTestFlow( p.imgNr, p);
    end
    p.imageName = imageName;
    
    % construct the initial segmentation: cubes almost as good as super-pixel
    %Seg = SegmentImage( ref.I(1).I );%, 13); % 2nd parameter defines desired patchsize: the higher the larger the initial patches
    Seg = SegmentImageCube( ref.I(1).I, p.gridSize, p );%, 13); % 2nd parameter defines desired patchsize: the higher the larger the initial patches
    Seg = correctSegCenters(Seg);
    Seg = setWeights_patchSmooth( Seg, cam(1).Kl );

    tic
    N_prop=0; RT_prop=0; oracle=0;
    % function provides proposals by variational flow/stereo, SGM, other methods can be used (also additionally)
    if doKitti
      % generating initial proposals from precomputed initial solutions
%      [N_prop, RT_prop, oracle] = generateProposals_load(p, cam, ref, Seg );

    if ~exist( sprintf( '%s/PropSolution%03d_%02d.mat', pFolder, p.imgNr, p.subImg), 'file');
      [N_prop, RT_prop, oracle]  = generateProposals(p, cam, ref, Seg );
      if ~exist(pFolder,'dir')
        mkdir(pFolder);
      end
      save( sprintf( '%s/PropSolution%03d_%02d.mat', pFolder, p.imgNr, p.subImg), 'Seg', 'N_prop', 'RT_prop', 'oracle');
    else
      load( sprintf( '%s/PropSolution%03d_%02d.mat', pFolder, p.imgNr, p.subImg));
    end      

    else
      [N_prop, RT_prop, oracle ] = generateProposals(p, cam, ref, Seg );
    end

    if size(N_prop,1) < 4
      N_prop = cat(1, N_prop, ones(1,size(N_prop, 2)));
    end    
    toc
    
    % new simplified version - does it work ?
    [flow2d, Energy] = pwrsfMulti_simpler_v3 ( ref, cam, p, Seg, N_prop, RT_prop, oracle );
    
    [occErr, noccErr, epes] = getKittiErrSF ( flow2d(:,:,1), flow2d(:,:,2), flow2d(:,:,3) ); %, p, 1 );
    
    kittiStr = sprintf('DispPix-occ 2/3/4/5 %.3f & %.3f & %.3f & %.3f\nFlowPix-occ 2/3/4/5 %.3f & %.3f & %.3f & %.3f\n', occErr.err2, occErr.err3, occErr.err4, occErr.err5, occErr.err2f, occErr.err3f, occErr.err4f, occErr.err5f);
    kittiStr = sprintf('%s\nDispPix-noc 2/3/4/5 %.3f & %.3f & %.3f & %.3f\nFlowPix-noc 2/3/4/5 %.3f & %.3f & %.3f & %.3f\n', kittiStr, noccErr.err2, noccErr.err3, noccErr.err4, noccErr.err5, noccErr.err2f, noccErr.err3f, noccErr.err4f, noccErr.err5f);
    kittiStr = sprintf('%s\nDispEPE %.3f & %.3f\nFlowEPE %.3f & %.3f\n', kittiStr, epes.epe_nocD, epes.epeD, epes.epe_noc, epes.epe);
    
    fid = fopen(sprintf('%s/RESULTS_K%03d_%02d_%s.txt', p.sFolder, p.imgNr, p.subImg, date), 'w', 'n');
    if fid~=-1
      fwrite(fid, kittiStr, 'char');
      fclose(fid);
    end
    
    if ~exist(sprintf('%s/disp/', p.sFolder), 'dir')
      mkdir(sprintf('%s/disp/', p.sFolder));
    end
    if ~exist(sprintf('%s/flow/', p.sFolder), 'dir')
      mkdir(sprintf('%s/flow/', p.sFolder));
    end

    % store results:
%    flow_write( cat(3, squeeze(flow2d(:,:,2)), squeeze(flow2d(:,:,3)), ones(size(squeeze(flow2d(:,:,3))))), sprintf('%s/flow/%06d_%02d.png', p.sFolder, p.imgNr, p.subImg ));
%    disp_write( squeeze(-flow2d(:,:,1)), sprintf('%s/disp/%06d_%02d.png', p.sFolder, p.imgNr, p.subImg ));
    
  end
end
end
