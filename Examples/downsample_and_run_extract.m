%% Start the main pipeline

movie_info = h5info('example.h5', '/Data');
movie_size = num2cell(movie_info.Dataspace.Size);
[nx, ny, totalnum] = deal(movie_size{:});

%% Downsample the movie
extract.internal.downsampletime_pipeline('example.h5:/Data', 40, 4, 40000)
% Downsamples the first 40000 frames of the movie by 4 using 40 blocks. You can downsample the movie down to 2Hz, maybe even more...

%% run EXTRACT on the downsampled movie

M = h5read('example_downsampled.h5', '/Data');
config = []
config = extract.get_defaults(config);

config.avg_cell_radius = 6;
config.num_partitions_x = 1;
config.num_partitions_y = 1;

% change these as needed
config.cellfind_min_snr = 1;
config.thresholds.T_min_snr = 10;

output = extract.solvers.extractor(M, config);
save('extract_downsampled_unsorted.mat', 'output', '-v7.3');

% While it is optional, it is beneficial to sort the cells at this stage before moving forward.

%% run EXTRACT on the full movie
load('unsorted_extract.mat');
M = 'example.h5:/Data';
config = output.config;

config.avg_cell_radius = 6;

% Add more partitions as needed for the RAM memory. As a rule of thumb, you want to partition the movie such that partitioned movie memory is 1/4th of RAM memory.
config.num_partitions_x = 2;
config.num_partitions_y = 2;

config.max_iter = 0;

% If you sorted, make sure that S_in is the sorted cell filters!
S_in = output.spatial_weights;
config.S_init = full(reshape(S_in, size(S_in, 1) * size(S_in, 2), size(S_in, 3)));

output = extract.solvers.extractor(M, config);
save('extrat_full_sorted.mat', 'output', '-v7.3');
