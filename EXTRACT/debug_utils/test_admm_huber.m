%% Prepare inputs
std_noise = 0.02;
[M,F_ground,T_ground] = generate_movie(100,100,1000,0.01,std_noise,50);

[h,w,t] = size(M);
M = reshape(M,h*w,t);
M = gpuArray(M);

%% Prepare inputs with biafra's code
std_noise=0.02;
nCellsDesired = 50;
imgSize = [40 40];
minDist = 3;
eventRate = 10/1000;  % in events/frame
framesDesired = 1000;
[M,T_ground,cellParams,~,~]=simulateData_makeTestData_v2(nCellsDesired,imgSize, minDist, eventRate, framesDesired); 
[h,w,t] = size(M);
%%
[h,w,t] = size(M);
M = reshape(M,h*w,t);
M = gpuArray(M);
% M = fix_baseline2(M);
F_ground=calcCellImgs(cellParams, imgSize);
F_ground = reshape(F_ground,prod(imgSize),size(T_ground,1));

X_norm = zscore(F_ground,1,1)/sqrt(size(F_ground,1));
C = X_norm'*X_norm;
C(C<0.5)=0;
sum(C(:)>0.85)/2-size(F_ground,2)/2
%% Run admm_huber
radius = 3;
spacing =5;
num_in_x = floor((w-0*2*radius-1)/spacing);
num_in_y = floor((h-0*2*radius-1)/spacing);

f = single(fspecial('disk',radius)>0);
% f = fspecial('gaussian',2*[radius,radius]+1,radius/2);
f = f/sum(f(:));

% Init method 1:
% acc = 0;
% F_init = zeros(h,w,(num_in_x+1)*(num_in_y+1));
% for x_center = radius+1:spacing:radius+1+num_in_x*spacing
%     for y_center = 0*radius+1:spacing:radius+1+num_in_y*spacing
%         acc = acc+1;
%         F_init(y_center-radius:y_center+radius,x_center-radius:x_center+radius,acc) = f;
%     end
% end
% k = size(F_init,3);
% 
% F_init = gpuArray(single(reshape(F_init,h*w,k)));

% Init method 2:
[cents_1,cents_2] = meshgrid(1:spacing:h,1:spacing:w);
cents = [cents_1(:),cents_2(:)]';
F_init = generate_images_from_centroids(h,w,f,cents,radius);
F_init = bsxfun(@rdivide,F_init,sum(F_init,1));
% F_init = F_init(:,idx_kept);
% % Init method 3:
% k = ceil(h/spacing)*ceil(w/spacing);
% acc = 0;
% filters = zeros(h,w,k);
% for i = 1:ceil(h/spacing)
%     for j = 1:ceil(w/spacing)
%         acc  =acc+1;
%         y_idx = 1+(i-1)*spacing:min(i*spacing,h);
%         x_idx = 1+(j-1)*spacing:min(j*spacing,w);
%         filters(y_idx,x_idx,acc) = 1/length(y_idx)/length(x_idx);
%     end
% end
% F_init = single(reshape(filters,h*w,k));
M2=gpuArray(reshape(M_small,h*w,t));

F_init = gpuArray(F_init);
T_init = max(F_init'*M2,0);

% F_init = gpuArray(F_ground);
% T_init = gpuArray(T_ground);

% filt = ones(1,3)/3;
% idx_trash = find(max(conv2(1,filt,T_init,'same'),[],2)<norm(f)*std_noise*(sqrt(2*log(t))-0.7) );
% F_init(:,idx_trash) = [];
% T_init(idx_trash,:) = [];
F_init = bsxfun(@rdivide,F_init,max(F_init,[],1));%max(f(:));


config = [];
config = update_config(config);
config.siz = [h,w];
config.T_elim_thresh = config.T_elimthresh_std_ratio*std_noise;
config.mu = config.mu_mad_ratio*std_noise*sqrt(2/pi)*1;
config.plot_loss=1;
config.mask_extension_radius=5;
config.subtract_surround=0;
config.smooth_T = 1;
config.diffuse_T = 1;
config.T_dup_corr_thresh = 0.95;
config.F_dup_corr_thresh = 0.95;
% config.spat_corrupt_thresh = 1;
config.TOL_sub = 1e-7;
% config.smooth_F = 1;
config.max_iter = 30;
config.max_iter_T = 50;
config.max_iter_F = 50;
config.diffuse_F = 1;
config.keep_tol_default=5;
config.keep_tol= 5;
config.T_corr_thresh = 0.5;
config.F_corr_thresh = 0.7;
config.smooth_F = 0;
% config.size_lower_limit = 5;
% profile off
% profile on
tic
[F1,T1,idx_kept,history] = alt_opt(M2,gpuArray(F_init),gpuArray(T_init),config);
endt=toc;
fprintf('This took %d minutes and %d seconds.\n',floor(endt/60),round(mod(endt,60)));
% profile viewer
% profile off

%% Align cell images and traces
t = size(T1,2);
idx_match = match_sets(F_ground,F1);
if isempty(idx_match)
    T_diff = [];
%     F_angle = [];
    num_comp = 0;
    return;
end

T_diff = T_ground(idx_match(1,:),:) -  T1(idx_match(2,:),:);
T_diff = sqrt(sum(T_diff.^2,2)/t);
max_trace = max([T_ground(idx_match(1,:),:),T1(idx_match(2,:),:)],[],2);
T_diff = T_diff./max_trace;
% F_angle = acos(m')/pi*180;

% Plot outputs

k_matched = size(idx_match,2);
im_ground_m = reshape(F_ground(:,idx_match(1,:)),h,w,k_matched);
im_m = reshape(F1(:,idx_match(2,:)),h,w,k_matched);

% get only image regions
mask = im_ground_m>0;
proj_mask_x = sum(mask,1)>0;
proj_mask_y = sum(mask,2)>0;
ims_ground = {};
ims = {};
for i = 1:k_matched

    y_range = find(squeeze(proj_mask_y(:,:,i)));
    x_range = find(squeeze(proj_mask_x(:,:,i)));

    % expand ranges
    max_len_x = 21;
    max_len_y = 21;
    ex_factor_y = inf;
    while ex_factor_y>0
        r=0;
        if ex_factor_y==1, r = round(rand);end
        ex_factor_y = max_len_y-length(y_range);
        if ex_factor_y<=0, break;end
        y_range = max(y_range(1)-ceil(ex_factor_y/2)+r,1):min(y_range(end)+floor(ex_factor_y/2)+r,h);
    end
    ex_factor_x = inf;
    while ex_factor_x>0
        r=0;
        if ex_factor_x==1, r = round(rand);end
        ex_factor_x = max_len_x-length(x_range);
        if ex_factor_x<=0, break;end        
        x_range = max(x_range(1)-ceil(ex_factor_x/2)+r,1):min(x_range(end)+floor(ex_factor_x/2)+r,w);
    end
    ims_ground{i} = im_ground_m(y_range,x_range,i);
    ims{i} = im_m(y_range,x_range,i);
end


big_im = [];
for i = 1:k_matched
    big_im = [[ims_ground{i},ims{i}];big_im];
end
subplot(1,5,1)
imagesc(big_im)
colormap(jet)
axis image
set(gca,'YTick',[])
set(gca,'XTick',[])

subplot(1,5,2:5)
max_max_trace = 1.1*max(max_trace);
offsets = 0:max_max_trace:(k_matched-1)*max_max_trace;
plot(bsxfun(@plus,T_ground(idx_match(1,:),:),offsets')','-.k','LineWidth',1.5)
hold on
% plot(bsxfun(@plus,T2(idx_match(1,:),:),offsets')','LineWidth',0.5)
plot(bsxfun(@plus,T1(idx_match(2,:),:),offsets')','LineWidth',0.5)
hold off
set(gca,'YTick',[])

%% Check outputs
i_ground_matched = idx_match(1,:);
i_ground_unmatched = 1:size(F_ground,2);
i_ground_unmatched = setdiff(i_ground_unmatched,i_ground_matched);
M_res = M-F1*T1;
F_scaled =  bsxfun(@rdivide,F1,sum(F1.^2,1));
T_ls = F_scaled'*M_res + bsxfun(@times,T1,sum(F1.*F_scaled,1)');
score = 1-sum((T_ls-T1).^2,2)./sum((T_ls).^2,2);
T_big = F1'*M;
T_big = inv(F1'*F1)*T_big;%bsxfun(@rdivide,T_big,sum(F1.^2,1)');

% Find overlapping cells for each cell
F_norm = zscore(F1,1,1)/sqrt(size(F1,1));
C = F_norm'*F_norm;
C=(C>0.2);
% Find residual movie
M_res = M-F1*T1;
T_ms = bsxfun(@minus,T1,mean(T1,2))';
F_big = M_res*T_ms;
h_spat = (fspecial('gaussian',[3,3],1));

for i = 1:size(F1,2)
    i_init = idx_kept(i);
    j_matched = find(idx_match(2,:)==i);

    if j_matched~=0
        i_ground = idx_match(1,j_matched);
    end
    
    subplot(2,3,1)
%     imagesc(reshape(F_init(:,i_init),h,w));axis image;
    f_affected = F_big(:,i)+F1(:,C(:,i))* (T1(C(:,i),:)*T_ms(:,i));
    im_affected = reshape(f_affected,h,w);
    im_affected = imfilter(im_affected,h_spat);
    im_affected(im_affected<0.1*max(im_affected(:)))=0;
    imagesc(im_affected);axis image;
    title('Init')
    hold on;
    scatter(cellParams(i_ground_unmatched,1),cellParams(i_ground_unmatched,2),'x','MarkerEdgeColor','white','LineWidth',1.5);
    scatter(cellParams(i_ground_matched,1),cellParams(i_ground_matched,2),'o','MarkerEdgeColor','white','LineWidth',1.5);
    for j = 1:size(cellParams,1)
        text(cellParams(j,1)+1,cellParams(j,2),num2str(j),'Color','w','FontSize',7);
    end
    hold off
    
    subplot(2,3,2)
    imagesc(reshape(F1(:,i),h,w));axis image;
    hold on;
    scatter(cellParams(i_ground_unmatched,1),cellParams(i_ground_unmatched,2),'x','MarkerEdgeColor','white','LineWidth',1.5);
    scatter(cellParams(i_ground_matched,1),cellParams(i_ground_matched,2),'o','MarkerEdgeColor','white','LineWidth',1.5);
    if j_matched>0
        scatter(cellParams(i_ground,1),cellParams(i_ground,2),'o','filled','MarkerEdgeColor','white','MarkerFaceColor','white','LineWidth',1.5);
    end
    hold off
    title('emp')
    
    subplot(2,3,3)
    if j_matched>0
        imagesc(reshape(F_ground(:,i_ground),h,w));axis image;
    else
        imagesc(zeros(h,w));axis image;
    end
    hold on;
    scatter(cellParams(i_ground_unmatched,1),cellParams(i_ground_unmatched,2),'x','MarkerEdgeColor','white','LineWidth',1.5);
    scatter(cellParams(i_ground_matched,1),cellParams(i_ground_matched,2),'o','MarkerEdgeColor','white','LineWidth',1.5);    
    if j_matched>0
        scatter(cellParams(i_ground,1),cellParams(i_ground,2),'o','filled','MarkerEdgeColor','white','MarkerFaceColor','white','LineWidth',1.5);
    end
    hold off
    title('ground')
    subplot(2,3,4:6)
%     plot(T_init(i_init,:),'--','Color',[1,1,1]*0.7);
    plot(T_big(i,:),'--','Color',[1,1,1]*0.7);
    hold on
    plot(T1(i,:),'k');
    if j_matched>0
        plot(T_ground(i_ground,:),'--r');
    end
    hold off
    title(sprintf('Cell #%d, score: %.2f %.2f',i,score(i)));
    if i<size(F1,2)
        pause;
    end
end
