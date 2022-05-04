function [x] = classification_hyperparameters( ...
        x, S, S_smooth, T, M, pre_S_corr, pre_T_corr_in, pre_T_corr_out, fov_size, avg_radius, use_gpu)
    num_cells_this_iter = size(T, 1);
    [fmap, ~] = get_quality_metric_map;

    % Populate metrics
    metrics = zeros(length(fmap), num_cells_this_iter);
    % T metrics:
    metrics(fmap('T_maxval'), :) = extract.internal. get_trace_snr(T);
    metrics(fmap('T_corruption'), :) = extract.internal.temporal_corruption(T);
    T_smooth = medfilt1(T, 3, [], 2);
    T_norm = zscore(T_smooth, 1, 2) / sqrt(size(T_smooth, 2));
    metrics(fmap('T_max_corr'), :) = max(T_norm * T_norm', [], 1);
    % S metrics:
    metrics(fmap('S_area_1'), :) = extract.internal.get_cell_areas(S, 0.2);
    metrics(fmap('S_smooth_area_1'), :) = extract.internal.get_cell_areas(S_smooth, 0.2);
    metrics(fmap('S_area_2'), :) = extract.internal.get_cell_areas(S);
    metrics(fmap('S_smooth_area_2'), :) = extract.internal.get_cell_areas(S_smooth);
    S_norm = zscore(S_smooth, 1, 1) / sqrt(size(S_smooth, 1));
    metrics(fmap('S_max_corr'), :) = max(S_norm' * S_norm, [], 1);
    metrics(fmap('S_corruption'), :) = extract.internal.spat_corruption(S, fov_size);
    [circularities, eccentricities] = extract.internal.get_circularity_metrics(S, fov_size);
    metrics(fmap('S_circularity'), :) = circularities;
    metrics(fmap('S_eccent'), :) = eccentricities;
    % Spatio-temporal metrics:
    idx_ST_123 = [fmap('ST1_index_1'), fmap('ST1_index_2'), ...
            fmap('ST1_index_3'), fmap('ST1_index_4'), fmap('ST1_index_5'), ...
                fmap('ST2_index_1'), fmap('ST2_index_2'), fmap('ST2_index_3'), ...
                fmap('ST2_index_4'), fmap('ST2_index_5'), fmap('ST3_index_1'), ...
                fmap('ST3_index_2'), fmap('ST3_index_3'), fmap('ST3_index_4'), ...
                fmap('ST3_index_5')];
    [~, metrics(idx_ST_123(1:5), :), ...
            metrics(idx_ST_123(6:10), :), ...
            metrics(idx_ST_123(11:15), :), ] = ...
        extract.internal.find_spurious_cells(S, T, M, pre_S_corr, pre_T_corr_in, ...
        pre_T_corr_out, fov_size, avg_radius, use_gpu);
    metrics([fmap('ST_corr_1'), fmap('ST_corr_2'), fmap('ST_corr_3')], :) = ...
        extract.internal.get_st_corr_metrics(M, S, T, fov_size, avg_radius);
    % Set NaN metrics to zero
    metrics(isnan(metrics(:))) = 0;

    % Make classification struct for this iter
    x(end + 1).metrics = metrics;

end
