% Noise Analysis for CRLB Calculations, estimating M0s,T1,T2,kappa
% Input data: Sqrt-Sum-of-Squares Gel Phantom Data
% Written by: Gopal Nataraj and Jeffrey A. Fessler; Copyright 2014

%% Raw data extraction 
% Header files and IRT Setup
if (~exist('irtdir', 'var'))
    cd ../../IRT; setup(); cd ../Scripts/CRLB_Analysis;
end
addpath('../../Scripts/');
addpath('../Calculations/DESS/');
addpath('../Gel_Phantom_06,20,14/');
addpath('../JFNielsen/common');
addpath('../JFNielsen/img');

% Imaging Parameters
nx = 240; ny = 240; nz = 10; nc = 8;
% opflip = [3 5 8 11 15 20 29 37:10:77]'; % degrees
opflip = [11 37 77]';                   % radians
flip = opflip * pi/180;                 % radians
nf = length(flip); 
TR = 15.1;                              % ms
TE = 5.04;                              % ms
wf = 0;                                 % Zero off-resonance

% Load DESS Data from p-file
if (~exist('yp_im', 'var'))
    yp_im = NaN(nx, ny, nz, nf);
    ym_im = NaN(nx, ny, nz, nf);
    yp_all = NaN(nx, ny, nz, nc, nf);
    ym_all = NaN(nx, ny, nz, nc, nf);
    
    for l = 1:nf
        pfile = sprintf('P_dess_8coil_20Jun14_opflip%d.7', opflip(l));
        [yp_all(:,:,:,:,l), yp_im(:,:,:,l)] = recon(pfile, 1);
        [ym_all(:,:,:,:,l), ym_im(:,:,:,l)] = recon(pfile, 2);
    end
    
    % Choose just one medioaxial slice
    % (For now!) rotate the sqrt-sum-of-squares images to align with complex
    % signal model --> eventually, will need to use a magnitude signal model
    yp_im = squeeze(yp_im(:,:,5,:)) * +1i;
    ym_im = squeeze(ym_im(:,:,5,:)) * -1i;
    yp_all = squeeze(yp_all(:,:,5,:,:));
    ym_all = squeeze(ym_all(:,:,5,:,:));
end

%% PART ONE: Empirical vs. Theoretical comparisons
% Square-root Sum-of-Squares (ssos) function
ssos = @(data, dim) sqrt(sum(abs(data).^2, dim));

% Choose a noise-only region
sl = floor(nf/2)+1; 
slice_msk_sos = squeeze(abs(yp_im(:,:,sl)) > 0.05*max(col(abs(yp_im(:,:,sl)))));
noise_msk_all = repmat(~imdilate(slice_msk_sos, strel('disk', 40)), [1 1 2*nf nc]);

% Extract and vectorize (correlated) noise
Y_all = permute(cat(4, yp_all, ym_all), [1 2 4 3]);
noise_all = reshape(Y_all(noise_msk_all), [length(Y_all(noise_msk_all))/nc nc]);

% Covariance matrix estimate 
% Unfortunately, statistical test in corrcoef() invalid for complex data
Cov_all = cov(noise_all); figure, im(Cov_all, 'cbar');
% print -depsc 'coil_cov_mtx.eps';

% Decorrelate the data to obtain uncorrelated noise variance across receive coils
% Whiten the data using an eigendecomposition
[V, D] = eig(Cov_all);
Y_whiten_all = reshape(Y_all, [2*nx*ny*nf nc]) * V * diag(1./sqrt(diag(D))); 
Cov_whiten_all = cov(reshape(Y_whiten_all(noise_msk_all), size(noise_all)));
figure, im(Cov_whiten_all);             % Sanity check: should be identity

% Extract the whitened data back
% (For now!) rotate the sqrt-sum-of-squares images to align with complex
% signal model --> eventually, will need to use a magnitude signal model
Y_whiten_sos = reshape(ssos(Y_whiten_all, 2), [nx ny 2*nf]);
yp_whiten_sos = Y_whiten_sos(:,:,1:nf) * +1i;
ym_whiten_sos = Y_whiten_sos(:,:,nf+1:end) * -1i;

% % In the high-SNR regime, var(Sqrt-SoS) \approx 0.5*var(single coil)
% The whitened data has unit variance, so var(Sqrt-SoS) = 1/2
var_hat_sos = 0.5;

% % Square-root Sum-of-Squares (ssos) function
% ssos = @(data, dim) sqrt(sum(abs(data).^2, dim));
%
% % 1a. Noise regions
% % Choose a noise-only region 
% sl = floor(nf/2)+1; 
% slice_msk_sos = squeeze(abs(yp_im(:,:,sl)) > 0.05*max(col(abs(yp_im(:,:,sl)))));
% noise_msk_sos = repmat(~imdilate(slice_msk_sos, strel('disk', 40)), [1 1 nf]);
% 
% % Extract and vectorize noise
% noise_p_sos = reshape(yp_im(noise_msk_sos), [length(yp_im(noise_msk_sos))/nf nf]);
% noise_m_sos = reshape(ym_im(noise_msk_sos), [length(ym_im(noise_msk_sos))/nf nf]);
% 
% % Covariance matrix estimate, of size (M x M); hopefully off-diagonals are small
% Sigma_hat_sos = cov([noise_p_sos noise_m_sos]);
% 
% % Compute the closest scaled-identity matrix to Sig_hat
% % This is simply given by scaling identity by the mean of the eigenvalues
% mean_var_hat_sos = mean(eig(Sigma_hat_sos));
% Sig_hat_diag = diag(repmat(mean_var_hat_sos, [2*nf 1]));
% 
% % 1b. Signal regions
% % Extract and vectorize complex coil noise data
% noise_msk_all = repmat(~imdilate(slice_msk_sos, strel('disk', 40)), [1 1 nc nf]);
% noise_p_all = reshape(yp_all(noise_msk_all), [length(yp_all(noise_msk_all))/nf nf]);
% noise_m_all = reshape(ym_all(noise_msk_all), [length(ym_all(noise_msk_all))/nf nf]);
% 
% % Covariance matrix estimate, of size (M x M)
% Sig_hat_all = cov([noise_p_all noise_m_all]);           
% Sigr_hat_all = cov([real(noise_p_all) real(noise_m_all)]);
% Sigi_hat_all = cov([imag(noise_p_all) imag(noise_m_all)]); 
% 
% mean_var_hat_all = mean(eig(Sig_hat_all));
% meanr_var_hat_all = mean(eig(Sigr_hat_all));
% meani_var_hat_all = mean(eig(Sigi_hat_all));
% 
% % In the high-SNR regime, var(Sqrt-SoS) \approx 0.5*var(single coil)
% var_hat_sos = 0.5*mean_var_hat_all;

%% PART TWO: Four-Parameter VarPro for computing empirical (M0s/T1/T2/kappa) est. variance
% High-resolution dictionary creation
T1 = logspace(2, 3, 100);                   % logspace(2, 3.5, 200);
T2 = logspace(log10(30), log10(50), 100);   % logspace(1, 2.5, 200);
kappa = 2 .^ linspace(0, 2, 100);           % 2 .^ linspace(-1, 3, 51);
D = NaN(2*length(flip), length(T1), length(T2), length(kappa));
for t1 = 1:length(T1)
    for t2 = 1:length(T2)
        for s = 1:length(kappa)
            for a = 1:nf
                [D(a, t1, t2, s), D(nf+a, t1, t2, s)] = ...
                    dess_fun(TR, TE, 1, T1(t1), T2(t2), flip(a)*kappa(s), wf);
            end
        end
    end
end
D = reshape(D, [2*length(flip) length(T1)*length(T2)*length(kappa)]);
% D = abs(D);                                 % Use magnitude dictionary for SoS

% (ML) Dictionary-based estimation via variable-projection method
% Note that we are now using the whitened ssos data
weights = ones(2*nf, 1);
W = spdiags(weights, 0, 2*nf, 2*nf);    % Weighting Matrix
y = reshape(permute(cat(3, yp_whiten_sos, ym_whiten_sos), [3 1 2]), [2*nf nx*ny]);

maxProd = zeros(1, nx*ny);
idx = zeros(1, nx*ny);
for k = 1:(length(T1)*length(T2)*length(kappa))
    % Compute kth inner product
    hess = abs(D(:,k)' * W * D(:,k));
    ytild = D(:,k)' * W * y / sqrt(hess);
    newProd = abs(ytild).^2;

    % If the kth inner product is largest, save k
    update = newProd > maxProd;
    maxProd(update) = newProd(update);
    idx(update) = k;
end

% Extract indices for maximum-likelihood (ML) maps
[t1_idx, t2_idx, s_idx] = ind2sub([length(T1) length(T2) length(kappa)], idx);
T1_ml = reshape(T1(t1_idx), [nx ny]); 
T2_ml = reshape(T2(t2_idx), [nx ny]);
kappa_ml = reshape(kappa(s_idx), [nx ny]);

% M0s initial guess
M0s_ml = NaN(nx*ny, 1);
for q = 1:length(idx)
    M0s_ml(q) = (D(:,idx(q))' * y(:,q)) ./ (D(:,idx(q))' * D(:,idx(q)));
end
M0s_ml = reshape(M0s_ml, [nx ny]);

% Empirical means and standard deviations from ROI
center = [120 120];
radius = 15; 
roi_msk = false(size(slice_msk_sos));
roi_msk(center(1)-radius:center(1)+radius, center(2)-radius:center(2)+radius) = true; 
[M0s_ml_mean, M0s_ml_sd]      = multiMeans(M0s_ml, center, radius);
[T1_ml_mean, T1_ml_sd]        = multiMeans(T1_ml, center, radius);
[T2_ml_mean, T2_ml_sd]        = multiMeans(T2_ml, center, radius);
[kappa_ml_mean, kappa_ml_sd]  = multiMeans(kappa_ml, center, radius);

%% PART THREE: CRLB computation to obtain theoretical (M0s/T1/T2/kappa) est. variance
% Note: norm_crlb_dess_4parm() yields standard deviations for
% abs(M0s)*sqrt(SoS(sensitivities)) = 1. We must scale this CRLB 
% to match the signal level of the data. 

% Four-parameter time-uncompensated CRLB
TR_dess = TR * ones(nf, 1);
Sigma_inv = (1 ./ var_hat_sos) * speye(2*nf);
time_comp = 0;
[~, M0s_theory_sd, T1_theory_norm, T2_theory_norm, kappa_theory_norm]...
    = norm_crlb_dess_4parm(T1_ml_mean, T2_ml_mean, kappa_ml_mean, wf,...
    []', flip, []', TR_dess, TE, Sigma_inv, time_comp);

% Scale the normalized CRLB to match signal level of the data
% Note M0s_theory_sd is the std. dev. of M0s*sqrt(SoS(sensitivities)).
% M0s_theory_sd / sqrt(s'*inv(Sigma)*s) would be LATENT std. dev. of M0s
% M0s_theory_norm = M0s_theory_sd / M0s_ml_mean is std. dev. of M0s = 1.
T1_theory_sd  = T1_theory_norm  / abs(M0s_ml_mean);
T2_theory_sd  = T2_theory_norm  / abs(M0s_ml_mean);
kappa_theory_sd = kappa_theory_norm / abs(M0s_ml_mean); 

% % Note: crlb_dess_kappa() incorporates the noise covariance automatically
% Sigma_inv = (1 ./ mean_var_hat) * speye(2*nf);
% TR_dess = TR * ones(nf, 1);
% scan_time = sum(TR_dess);
% 
% % Four-parameter time-compensated CRLB
% [~, M0s_theory_tcsd, T1_theory_tcsd, T2_theory_tcsd, kappa_theory_tcsd]...
%     = crlb_dess_kappa(M0s_ml_mean, T1_ml_mean, T2_ml_mean,...
%     kappa_ml_mean, wf, []', flip, []', TR_dess, TE, Sigma_inv);
% 
% % Undo time-compensation for comparison with empirical values
% M0s_theory_sd   = M0s_theory_tcsd / sqrt(scan_time);
% T1_theory_sd    = T1_theory_tcsd / sqrt(scan_time);
% T2_theory_sd    = T2_theory_tcsd / sqrt(scan_time);
% kappa_theory_sd = kappa_theory_tcsd / sqrt(scan_time);

%% PART FOUR: Graphical outputs
% Histogram of ML estimates to observe Gaussianity of estimator
Xm = linspace(min(M0s_ml(roi_msk)), max(M0s_ml(roi_msk)), 100);...
    Ym = normpdf(Xm, M0s_ml_mean, M0s_theory_sd);... 
    [Nm, Bm] = hist(M0s_ml(roi_msk), 20);... 
    figure; bar(Bm, Nm/max(Nm)*max(Ym)); hold on;...
    plot(Xm, Ym, 'r', 'LineWidth', 2); hold off;...
    title('Histogram of M0s Estimates');...
    legend('Empirical', 'Gaussian w/ CRLB std. dev.');
%     print -depsc 'M0s_hist_4parm,3flip.eps';
 
X1 = linspace(min(T1_ml(roi_msk)), max(T1_ml(roi_msk)), 100);...
    Y1 = normpdf(X1, T1_ml_mean, T1_theory_sd);...
    [N1, B1] = hist(T1_ml(roi_msk), 20); hold on;...
    figure; bar(B1, N1/max(N1)*max(Y1)); hold on;...
    plot(X1, Y1, 'r', 'LineWidth', 2); hold off;...
    title('Histogram of T1 Estimates');...
    legend('Empirical', 'Gaussian w/ CRLB std. dev.');
%     print -depsc 'T1_hist_4parm,3flip.eps';

X2 = linspace(min(T2_ml(roi_msk)), max(T2_ml(roi_msk)), 100);...
    Y2 = normpdf(X2, T2_ml_mean, T2_theory_sd);...
    [N2, B2] = hist(T2_ml(roi_msk), 20); hold on;...
    figure; bar(B2, N2/max(N2)*max(Y2)); hold on;...
    plot(X2, Y2, 'r', 'LineWidth', 2); hold off;...
    title('Histogram of T2 Estimates');...
    legend('Empirical', 'Gaussian w/ CRLB std. dev.');
%     print -depsc 'T2_hist_4parm,3flip.eps';

Xk = linspace(min(kappa_ml(roi_msk)), max(kappa_ml(roi_msk)), 100);...
    Yk = normpdf(Xk, kappa_ml_mean, kappa_theory_sd);...
    [Nk, Bk] = hist(kappa_ml(roi_msk), 20); hold on;...
    figure; bar(Bk, Nk/max(Nk)*max(Yk)); hold on;...
    plot(Xk, Yk, 'r', 'LineWidth', 2); hold off;...
    title('Histogarm of kappa Estimates');...
    legend('Empirical', 'Gaussian w/ CRLB std. dev.');
%     print -depsc 'kap_hist_4parm,3flip.eps';

% ML Estimated Images
figure; im(M0s_ml, 'cbar');   %print -depsc 'M0s_ml.eps'
figure; im(T1_ml, 'cbar');    %print -depsc 'T1_ml.eps'
figure; im(T2_ml, 'cbar');    %print -depsc 'T2_ml.eps'
figure; im(kappa_ml, 'cbar'); %print -depsc 'kap_ml.eps'