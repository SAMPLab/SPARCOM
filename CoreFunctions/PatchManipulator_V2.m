function [ PatchMat, RowEndIndex] = PatchManipulator_V2( ImageBlock, Dimensions, Overlap, ImageSize, Params )
%PATCHMANIPULATOR  - Extract or combine patches from/to an image.
%                    The output PatchMat is an MN X (number of patches)
%                    matrix. Each column represents a patch from the
%                    original image.
%

% Step 1: Preliminaries
% ---------------------
% Full image dimensions
I_M = ImageSize.X;
I_N = ImageSize.Y;

% Patch dimensions
M = Dimensions.X;
N = Dimensions.Y;

% % Work only with odd length patches - for convenience only.
% if (mod(M,2) == 0 | mod(N,2) == 0)
%     error('PatchManipulator: Work only with odd length patches.');
% end

% Patch centers
dM = floor(M/2);            % pixels around the center cM
cM = dM + mod(M,2);
dN = floor(N/2);            % pixels around the center cN
cN = dN + mod(M,2);

% Create center patch grids - disregrad edges
Mvec = [cM:(M - Overlap.X):I_M];
Nvec = [cN:(N - Overlap.Y):I_N];

% Add additional center in case of "overslip"
if ( I_M - Mvec(end) > M - dM - mod(M,2) )
    Mvec = [Mvec (Mvec(end) + M - Overlap.X) ];
end
if ( I_N - Nvec(end) > N - dN - mod(N,2) )
    Nvec = [Nvec (Nvec(end) + N - Overlap.Y) ];
end

% Step 2: Patch manipulations
% ---------------------------
switch lower(Params.Type)
    case 'extract' % Extract patches - relevant for the low resolution patch based analysis
        % Zero-pad the edges of the image (if necessary) - in order that the image could
        % be decomposed as "whole" patches
        TempImage = zeros((Mvec(end) + dM), (Nvec(end) + dN));
        TempImage(1:I_M,1:I_N) = ImageBlock;
        
%         % Duplicate last row and column - Neumann boundary conditions
%         [Lr, Lc] = size(TempImage);
%         TempImage(1:I_M, I_N + 1:end) = repmat(ImageBlock(:, end), 1, Lc - I_N);
%         TempImage(I_M + 1:end, :) = repmat(TempImage(I_M, :), Lr - I_M, 1);
        
        % End of every patch
        RowEndIndex = [];
        
        % Extract each patch
        kk = 1;
        for (ii = 1:length(Mvec))
            for (jj = 1:length(Nvec))
                Temp = TempImage([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]);
                PatchMat(:,kk) = reshape(Temp,M*N,1);
                
                % Increment
                kk = kk + 1;
            end
            RowEndIndex = [RowEndIndex (kk-1)];
        end
    case 'combine' % Combine patches - relevant for the high resolution restoration
        % Combine each patch - Overlaps are taken into acount by placing
        % the current patch over the previous (in the overlap area) and then
        % performing an average.
        
        % Initialization
        PatchMat = zeros(Mvec(end) + dM, Nvec(end) + dN);
        
        %% Apodization
        ApodType = 'tukey';
        ApodParam.N = 0.95; 0.5;        % 0.5 for 32 windows. 0.95 - for 16 windows
        switch lower(ApodType)
            case 'hamming'
                Apod = window(@hamming, Dimensions.X);
                Apod = repmat(Apod.', Dimensions.X, 1);
                Apod = Apod.*Apod.';
            case 'triang'
                Apod = window(@triang, Dimensions.X);
                Apod = repmat(Apod.', Dimensions.X, 1);
                Apod = Apod.*Apod.';
            case 'tukey'
                Apod = window(@tukeywin, Dimensions.X, ApodParam.N);
                Apod = repmat(Apod.', Dimensions.X, 1);
                Apod = Apod.*Apod.';
            case 'cosine'
                [x, y] = meshgrid(-Dimensions.X/2:Dimensions.X/2 - 1);
                Apod = cos(pi*x/(Dimensions.X)).*cos(pi*y/(Dimensions.X));
        end
        
%         % Create empty Weights matrix
%         WMat  = zeros(Mvec(end) + dM, Nvec(end) + dN);
        
%         % Create single Weight patch
%         WPtch = ones(M,N);
        
        kk = 1;
        for (ii = 1:length(Mvec))
            for (jj = 1:length(Nvec))
                % Apodization
                Temp = reshape(ImageBlock(:,kk),M,N).*Apod;
                
                % Add current patch in the correct place
                PatchMat([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]) =...
                    PatchMat([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]) + Temp;
                
%                 % Add Weight patch to the weights matrix, with over laps
%                 WMat([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]) =...
%                     WMat([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]) + WPtch;
                
                % Increment
                kk = kk + 1;
            end
        end
        
%         % Point-wise division - averaging
%         PatchMat = PatchMat./WMat;
        
        % Crop to size N X N = M*P X M*P
        PatchMat = PatchMat(1:I_M, 1:I_N);

        RowEndIndex = [];
    otherwise
        error('PatchManipulator: Type not supported.');
end





% % %  case 'combine' % Combine patches - relevant for the high resolution restoration
% % %         % Combine each patch - Overlaps are taken into acount by placing
% % %         % the current patch over the previous (in the overlap area) and then
% % %         % performing an average.
% % %         
% % %         % Initialization
% % %         PatchMat = zeros(Mvec(end) + dM, Nvec(end) + dN);
% % %         
% % %         % Create empty Weights matrix
% % %         WMat  = zeros(Mvec(end) + dM, Nvec(end) + dN);
% % %         
% % %         % Create single Weight patch
% % %         WPtch = ones(M,N);
% % %         
% % %         kk = 1;
% % %         for (ii = 1:length(Mvec))
% % %             for (jj = 1:length(Nvec))
% % %                 Temp = reshape(ImageBlock(:,kk),M,N);
% % %                 
% % %                 % Add current patch in the correct place
% % %                 PatchMat([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]) =...
% % %                     PatchMat([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]) + Temp;
% % %                 
% % %                 % Add Weight patch to the weights matrix, with over laps
% % %                 WMat([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]) =...
% % %                     WMat([Mvec(ii) - dM + mod(M-1,2):Mvec(ii) + dM],[Nvec(jj) - dN + mod(N-1,2):Nvec(jj) + dN]) + WPtch;
% % %                 
% % %                 % Increment
% % %                 kk = kk + 1;
% % %             end
% % %         end
% % %         
% % %         % Point-wise division - averaging
% % %         PatchMat = PatchMat./WMat;
% % %         
% % %         % Crop to size N X N = M*P X M*P
% % %         PatchMat = PatchMat(1:I_M, 1:I_N);
% % % 
% % %         RowEndIndex = [];
% % %     otherwise
% % %         error('PatchManipulator: Type not supported.');
% % % end
