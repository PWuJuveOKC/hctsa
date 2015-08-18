function TS_classify(whatData,whatLearners,doPCs)
% TS_classify   Classify groups in the data using all features
%

% ------------------------------------------------------------------------------
% Copyright (C) 2015, Ben D. Fulcher <ben.d.fulcher@gmail.com>,
% <http://www.benfulcher.com>
%
% If you use this code for your research, please cite:
% B. D. Fulcher, M. A. Little, N. S. Jones, "Highly comparative time-series
% analysis: the empirical structure of time series and their methods",
% J. Roy. Soc. Interface 10(83) 20130048 (2010). DOI: 10.1098/rsif.2013.0048
%
% This work is licensed under the Creative Commons
% Attribution-NonCommercial-ShareAlike 4.0 International License. To view a copy of
% this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/ or send
% a letter to Creative Commons, 444 Castro Street, Suite 900, Mountain View,
% California, 94041, USA.
% ------------------------------------------------------------------------------

%-------------------------------------------------------------------------------
% Check Inputs:
%-------------------------------------------------------------------------------
if nargin < 1
    whatData = 'norm';
end
if nargin < 2
    whatLearners = 'svm';
    % 'svm', 'discriminant', 'knn'
end
if nargin < 3
    doPCs = 1;
end

%-------------------------------------------------------------------------------
% Load in data:
%-------------------------------------------------------------------------------
[TS_DataMat,TimeSeries,Operations] = TS_LoadData(whatData);

% Check that group labels have been assigned
if ~isfield(TimeSeries,'Group')
    error('Group labels not assigned to time series. Use TS_LabelGroups.');
end
timeSeriesGroup = [TimeSeries.Group]; % Use group form
numClasses = length(unique(timeSeriesGroup));
numFeatures = length(Operations);

%-------------------------------------------------------------------------------
% Set up the classification model
%-------------------------------------------------------------------------------
switch whatLearners
case 'svm'
    % Linear SVM:
    cfnModel = templateSVM('Standardize',1,'KernelFunction','linear');
case 'knn'
    % k-NN (k=3) classification:
    cfnModel = templateKNN('NumNeighbors',3,'Distance','euclidean');
case {'discriminant','linear'}
    % Linear discriminant analysis:
    cfnModel = templateDiscriminant('DiscrimType','linear');
    % could also be 'naivebayes', 'tree', ensemble methods
otherwise
    error('Unknown classification model, ''%s''',whatLearners);
end

%-------------------------------------------------------------------------------
% Fit the model using k-fold cross validation:
%-------------------------------------------------------------------------------
numFolds = 10;
CVcfnModel = fitcecoc(TS_DataMat,timeSeriesGroup,'Learners',cfnModel,'KFold',numFolds);

% Get misclassification rates from each fold:
foldLosses = 100*(1 - kfoldLoss(CVcfnModel,'Mode','individual'));

fprintf(1,['Classification rate (%u-class) using %u-fold %s classification with %u' ...
                 ' features:\n%.3f +/- %.3f%%\n'],...
                            numClasses,...
                            numFolds,...
                            whatLearners,...
                            numFeatures,...
                            mean(foldLosses),...
                            std(foldLosses))


% f = figure('color','w');
% histogram(foldLosses*100)
% xlim([0,100]);

%-------------------------------------------------------------------------------
% Compare performance of PCs:
if doPCs
    numPCs = 10;

    % Compute top 10 PCs of the data matrix:
    fprintf('Computing top %u PCs...',numPCs)
    [pcCoeff, pcScore, latent, ~, percVar] = pca(zscore(TS_DataMat),'NumComponents',numPCs);
    fprintf(' Done.\n')
    numPCs = min(10,size(pcScore,2)); % sometimes lower than attempted 10

    % Compute cumulative performance of PCs:
    PC_cfn = cell(numPCs,1);
    cfnRate = zeros(numPCs,2);
    fprintf('Computing classification rates keeping top 1--%u PCs...',numPCs)
    for i = 1:numPCs
        PC_cfn{i} = fitcecoc(pcScore(:,1:i),timeSeriesGroup,'Learners',cfnModel,'KFold',numFolds);
        losses = 1-kfoldLoss(CVcfnModel,'Mode','individual');
        cfnRate(i,1) = mean(losses)*100;
        cfnRate(i,2) = std(losses)*100;
    end
    fprintf(' Done.\n')

    plotColors = BF_getcmap('spectral',3,1);

    f = figure('color','w'); hold on
    plot([1,numPCs],ones(2,1)*mean(foldLosses),'--','color',plotColors{3})
    plot(1:numPCs,cfnRate(:,1),'o-k')
    legend(sprintf('All %u features (%.1f%%)',numFeatures,mean(foldLosses)),...
                sprintf('PCs (%.1f--%.1f%%)',min(cfnRate(:,1)),max(cfnRate(:,1))))
    plot(1:numPCs,cfnRate(:,1)+cfnRate(:,2),':k')
    plot(1:numPCs,cfnRate(:,1)-cfnRate(:,2),':k')

    xlabel('Number of PCs');
    ylabel('Classification accuracy (%)')

    titleText = sprintf('Classification rate (%u-class) using %u-fold %s classification',...
                                numClasses,...
                                numFolds,...
                                whatLearners);
    title(titleText)

end

end
