function [M,m] = compute_df(M, skip,baseline)
% delta F/ F of a 3-D movie

    if nargin <2 || isempty(skip)
        skip = false;
    end
    
    % If mean activity is below ABS_THRESHOLD, it is considered 0
    ABS_THRESHOLD = 1e-2;
    
    m = quantile(M,baseline, 3);
    % If movie is centered around 0, then skip
    % Compare mean of mean image to the center pixel std
    t = M(round(end/2),round(end/2),:);
    median_val = quantile(m(:),baseline);
    is_centered = (median_val < std(t)/ 10) || (median_val < ABS_THRESHOLD);
    if is_centered || skip
        m = max(m,ones(size(m)));
        return;
    end

    % Subtract temporal mean
    M = bsxfun(@minus, M, m);
end
