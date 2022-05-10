M = single(h5read('jones.hdf5','/Data/Images'));


% Decide on the partition number, and play with internal threshold parameters

config=[];
config = extract.get_defaults(config);
%config.use_gpu=0;
config.avg_cell_radius=7;
config.num_partitions_x=1;
config.num_partitions_y=1;



config.thresholds.T_min_snr=4;
config.thresholds.spatial_corrupt_thresh=1.5;
config.cellfind_min_snr=0;


output=extract.solvers.extractor(M,config);
