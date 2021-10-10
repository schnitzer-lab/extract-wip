%% Welcome to the EXTRACT tutorial! Written by Fatih Dinc, 03/02/2021
%perform cell extraction
clear;
M = single(hdf5read('Fig4_example.h5','/data'));
%%
config=[];
config = get_defaults(config); %calls the defaults

% Essentials, without these EXTRACT will give an error:
config.avg_cell_radius=6; 

% The movie is large, change the partitions if needed.
config.num_partitions_x=1;
config.num_partitions_y=1; 

% All the rest is to be optimized, which is the purpose of this tutorial!

output=extractor(M,config);
