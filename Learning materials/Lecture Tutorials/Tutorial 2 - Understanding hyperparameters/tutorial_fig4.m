%% Welcome to the EXTRACT tutorial! Written by Fatih Dinc, 03/02/2021
%perform cell extraction
clear;
M = single(hdf5read('/Volumes/DJ_Drew_SSD/EXTRACT/Fig4_example.h5', '/data'));
%%
config=[];
config = extract.get_defaults(config); %calls the defaults
config.use_gpu=false;

% Essentials, without these EXTRACT will give an error:
config.avg_cell_radius=6; 

% The movie is small, one partition should be enough!
config.num_partitions_x=1;
config.num_partitions_y=1; 

% All the rest is to be optimized, which is the purpose of this tutorial!

output=extract.solvers.extractor(M,config);


%% Check quality
figure, imshow(max(M,[],3),[0 50]);
extract.debug.plot_cells_overlay(output.spatial_weights,[1,0,0],[])
%% Check movie
extract.debug.view_movie(M, 'ims',output.spatial_weights,'im_colors',[1, 0.5, 0])

