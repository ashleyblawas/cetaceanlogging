% A tool to extract & save logging periods
function [] = logtool()

%% Setting up global parameters
clear; close all; clc

% Set a threshold at which point we know the tag is certainly on the animal
% (or on its way off)
tagon_thres = 5;

% Set a minimum duration to count as a SURFACING (in seconds)!
min_surf = 1;

% Set a minimum LOGGING duration (in seconds)!
min_log = 10;

% Define a theoretical threshold for logging that you are intersted in
% (e.g., 45 seconds)
threshold = 45;  

% Set a threshold in m/s for how much depth accumulatoin you will allow
% during a logging period. This is to help prevent detection of periods
% when the animal is really not loggin but doing little blips at the
% surface...
surf_da_thres = 10;
    
LogData = table();

%% Step 1: Choose prh file(s) to process
[file, path] = uigetfile('*.mat', 'Select a .mat file', 'MultiSelect', 'on');

% uigetfile returns a char array if you select just 1 file but the rest of the
% code expects a celery of char arrays, so convert if that is the case. there
% might be a more elegant way to do this...
if(class(file) == 'char')
    file = {file};
end

creator = input('Enter your name (as the creator of these outputs): \n', 's');  % 's' for string input

loc = input('Enter the general location these tags were deployed in (i.e., Cape Hatteras): \n', 's');  % 's' for string input

% Prompt the user to choose the type of file
% Create a figure window
fig = uifigure('Position', [100, 100, 250, 400]);

% Add a label
uilabel(fig, 'Position', [10, 360, 250, 30], 'Text', 'Select your tag type from the dropdown:');

% Create a dropdown
dropdown = uidropdown(fig, ...
    'Items', {'CATS', 'D2', 'D3', 'D4', 'TDR', 'Acousonde'}, ...
    'Position', [10, 325, 120, 30], ...
    'Editable','on');

% Variable to store selected value (use assignin later if needed)
tagtype = '';

% Add button with callback that passes dropdown and fig
uibutton(fig, 'Position', [20 280 65 30], 'Text', 'OK', ...
    'ButtonPushedFcn', @(btn, event) closebuttonfunction(dropdown, fig));

% Wait for the user
uiwait(fig);

% Callback function (gets dropdown and fig as inputs)
function closebuttonfunction(dropdown, fig)
    % Get selected value from dropdown
    tagtype = dropdown.Value;
    
    % Assign to base workspace if needed
    assignin('base', 'tagtype', tagtype);  % Optional: makes tagtype available after UI closes

    % Close the UI
    close(fig);
end

%% Step 2: Run workhorse loop
for i = 1:length(file)
    
close all; 
clearvars -except i file path min_log min_surf tagon_thres threshold surf_da_thres LogData_temp creator loc tagtype LogData

%% Step 2A: Import record
% Check if the user selected a file
if isequal(file{i},0)
    disp('User canceled the file selection');
else
    % Create the full path to the file
    fullFileName = fullfile(path, file{i});
    
    % Load the .mat file
    data = load(fullFileName);
    
    % Save variables from structure
    A = data.A;
    Aw = data.Aw;
    M = data.M;
    Mw = data.Mw;
    fs = data.fs;
    head = data.head;
    p = data.p;
    pitch = data.pitch;
    roll = data.roll;

clear data
end

%% Step 2B: Chop to only tag on times

% Set start to be as soon as tag crosses 1m
if p(1)<tagon_thres
    start_idx = find(p>=tagon_thres, 1, 'first');
else
    start_idx = 1;
end

% Set end to be last time tag crosses 1m
if p(end)<tagon_thres
    end_idx = find(p()>=tagon_thres, 1, 'last');
else
    end_idx = length(p);
end

% Subset p to only when tag is on
p_tagon = p(start_idx:end_idx);

%% Step 2C: Identify surface periods
tt_sec = 0:1/fs:length(p_tagon)/fs-(1/fs);
tt_min = tt_sec/60;
tt_hour = tt_sec/60/60;

% Remove any pressure data that is greater than 1 m and get indexes
% of shallow periods
p_shallow(p_tagon>1) = NaN;
p_shallow_idx = find(~isnan(p_shallow));

paperSize = [11.5, 7];  
figure('Units', 'inches', 'PaperSize', [paperSize(1), paperSize(2)],'Position', [0, 0, paperSize(1), paperSize(2)]);

subplot(3, 1, [1 2]);
p1 = plot(tt_min, p_tagon, 'k', 'LineWidth', 1); hold on
set(gca, 'YDir', 'reverse');
xlabel('Time (Minutes)'); ylabel('Depth (m)');
title(file{i}(1:9), 'Interpreter', 'none');

% Find start and end of surface periods
p_shallow_breaks_end = find(diff(p_shallow_idx)>1);
p_shallow_breaks_start = find(diff(p_shallow_idx)>1)+1;

% Define variable to store surfacings
p_shallow_ints = table([1, p_shallow_breaks_start]',...
    [p_shallow_breaks_end, length(p_shallow_idx)]',...
          'VariableNames',{'Surf Start Index','Surf End Index'});

% Make third column which is duration of surfacing in indices
p_shallow_ints.("Surf Duration (Samples)") = p_shallow_ints.("Surf End Index") - p_shallow_ints.("Surf Start Index");
p_shallow_ints.("Surf Duration (Seconds)") = p_shallow_ints.("Surf Duration (Samples)")/fs;

% If surfacing is less than minimum surface duration then remove it - likely not a surfacing anyway but a period
% where depth briefly crosses above depth threshold
delete_rows = find(p_shallow_ints.("Surf Duration (Seconds)") < min_surf);
p_shallow_ints(delete_rows, :) = [];

% % If minima of a surfacing is not at least within a reasonable range of the
% % neighborhood (surrounding 4) of surfacings then remove it
% for r = length(p_shallow_ints):-1:1 % Go backwards so can delete as you go
%     if r == length(p_shallow_ints)
%         min1 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r-1, 1):p_shallow_ints(r-1, 2))),0));
%         min2 = min1;
%         min3 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r-2, 1):p_shallow_ints(r-2, 2))),0));
%         min4 = min3;
%     elseif r == length(p_shallow_ints)-1
%         min1 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r-1, 1):p_shallow_ints(r-1, 2))),0));
%         min2 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r+1, 1):p_shallow_ints(r+1, 2))),0));
%         min3 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r-2, 1):p_shallow_ints(r-2, 2))),0));
%         min4 = min3;
%     elseif r == 2
%         min1 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r-1, 1):p_shallow_ints(r-1, 2))),0));
%         min2 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r+1, 1):p_shallow_ints(r+1, 2))),0));
%         min4 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r+2, 1):p_shallow_ints(r+2, 2))),0));
%         min3 = min4;
%     elseif r == 1
%         min2 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r+1, 1):p_shallow_ints(r+1, 2))),0));
%         min1 = min2;
%         min4 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r+2, 1):p_shallow_ints(r+2, 2))),0));
%         min3 = min4;
%     else
%         min1 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r-1, 1):p_shallow_ints(r-1, 2))),0));
%         min2 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r+1, 1):p_shallow_ints(r+1, 2))),0));
%         min3 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r-2, 1):p_shallow_ints(r-2, 2))),0));
%         min4 = min(max(p_shallow(p_shallow_idx(p_shallow_ints(r+2, 1):p_shallow_ints(r+2, 2))),0));
%     end
%     temp_sort = sort([min1, min2, min3, min4]);
%     if min(p_shallow(p_shallow_idx(p_shallow_ints(r, 1):p_shallow_ints(r, 2))))>mean(temp_sort(1:2))+0.5
%         p_shallow_ints(r, :) = [];
%     end
% end

% If these periods are less than 10 seconds then we say they are a "single
% breath surfacing" otherwise they are a "logging surfacings"
single_breath_surf_rows = find(p_shallow_ints.("Surf Duration (Seconds)") <= min_log);
logging_surf_rows = find(p_shallow_ints.("Surf Duration (Seconds)") > min_log);

% Define logging starts and ends
logging_start_idxs = p_shallow_idx(p_shallow_ints{logging_surf_rows, 'Surf Start Index'});
logging_end_idxs = p_shallow_idx(p_shallow_ints{logging_surf_rows, 'Surf End Index'});

logging_ints = table(logging_start_idxs',logging_end_idxs',...
          'VariableNames',{'Logging Start Index','Logging End Index'});

logging_ints.("Logging Start (Seconds)") = tt_sec(logging_start_idxs)';
logging_ints.("Logging End (Seconds)") = tt_sec(logging_end_idxs)';
logging_ints.("Logging Duration (Seconds)") = logging_ints.("Logging End (Seconds)") - logging_ints.("Logging Start (Seconds)");


% Need to add a check for if the animal accumulates a lot of depth change
% in the period then this is actually a bunch of single breath surfacings
for r = height(logging_ints):-1:1
    % Smooth depth to 1 Hz
    p_tagon_smoothed = movmean(p_tagon(logging_ints{r, "Logging Start Index"}:logging_ints{r, "Logging End Index"}), 5*fs);  % smooth over 5 seconds

    accum_depth = sum(abs(diff(p_tagon_smoothed)));
    accum_depth_rate = accum_depth/(logging_ints{r, "Logging Duration (Seconds)"}/60);

    if accum_depth_rate > surf_da_thres
        % Drop non-logging periods
        %logging_ints(r, :) = [];
        
        fprintf('Dropping out logging interval %d because depth accumulation was %.2f m/s\n', ...
            r, accum_depth_rate);
    end
end

% Plot logging surfacings in pink
if height(logging_ints)>0
    for r = 1:length(logging_surf_rows)
        p2 = plot(tt_min(logging_ints{r, "Logging Start Index"}-1:logging_ints{r, "Logging End Index"}-1), p_tagon(logging_ints{r, "Logging Start Index"}:logging_ints{r, "Logging End Index"}), 'm-', 'LineWidth', 2);
    end
    % Need this condition in case there is no logging
else
    p2 = plot(NaN, NaN, 'm-', 'LineWidth', 2);
end

% Plot start and end of surfacings with asteriks
p3 = plot(tt_min(logging_ints.("Logging Start Index")-1), p_tagon(logging_ints.("Logging Start Index")), 'g*');
p4 = plot(tt_min(logging_ints.("Logging End Index")-1), p_tagon(logging_ints.("Logging End Index")), 'r*');

warning('off', 'MATLAB:legend:IgnoringExtraEntries');
legend([p1 p2 p3 p4],{'Dive depth' , 'Logging', 'Start of surfacing', 'End of surfacing'}, 'Location', 'best')
warning('on', 'MATLAB:legend:IgnoringExtraEntries');

%% Step 2D: Print out summary data

med_log_int = median(logging_ints.("Logging Duration (Seconds)"));
log_tot_min = sum(logging_ints.("Logging Duration (Seconds)"))/60;
log_percent = 100*sum(logging_ints.("Logging Duration (Seconds)"))/tt_sec(end);

if height(logging_ints)>0
    
    annotation('textbox', [0.1, 0.07, 0.5, 0.15], 'String', sprintf('Median Logging Interval (Seconds): %.2f', med_log_int), ...
        'FontSize', 12, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'EdgeColor', 'none');
    
    annotation('textbox', [0.1, 0.04, 0.5, 0.15], 'String', sprintf('%% Time Spent Logging: %.2f%%', log_percent), ...
        'FontSize', 12, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'EdgeColor', 'none');
    
    annotation('textbox', [0.1, 0.01, 0.5, 0.1], 'String', sprintf('Total Time Spent Logging: %.2f minutes', log_tot_min), ...
        'FontSize', 12, 'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom', 'EdgeColor', 'none');
    
    subplot(313)
    boxplot(logging_ints.("Logging Duration (Seconds)"), 'orientation', 'horizontal', 'Widths', 1); hold on;
    xlabel('Logging Interval Durations (Seconds)');  % X-axis label
    
    x = ones(size(logging_ints.("Logging Duration (Seconds)")));  % Create x-values for the data points (all the same for one group)
    jitterAmount = 0.25;    % Amount of jitter to apply
    jitteredX = x + jitterAmount * (rand(size(x)) - 0.5);  % Random jitter in the x-direction
    
    % Scatter the jittered points
    scatter(logging_ints.("Logging Duration (Seconds)"),jitteredX,  'filled', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'k')
    alpha(.5); set(gca,'YTickLabel',{' '})
    
    print(gcf, strcat(file{i}(1:9), "log_ints"), '-dpdf');
end

%% Step 3: Export data to big table

if height(logging_ints)>0
    
    tagID = file{i}(1:9);
    spec = file{i}(1:2);
    PHz = fs;
    
    TT_sec = 0:1/fs:length(p)/fs-(1/fs);
    
    record_dur = max(TT_sec);
    
    LogData_temp = table(repmat({tagID}, height(logging_ints), 1),...
        repmat({spec}, height(logging_ints), 1),...
        repmat({loc}, height(logging_ints), 1),...
        repmat({tagtype}, height(logging_ints), 1),...
        repmat({PHz}, height(logging_ints), 1),...
        repmat({record_dur}, height(logging_ints), 1), 'VariableNames', {'ID', 'Species', 'Location', 'Tag Type', 'PHz', 'Record Duration (Seconds)'});
    
    LogData_temp.StartI = logging_ints.("Logging Start Index")+start_idx-1;
    LogData_temp.EndI = logging_ints.("Logging End Index")+start_idx-1;
    
    LogData_temp.("Logging Start (Seconds)") = TT_sec(logging_start_idxs)';
    LogData_temp.("Logging End (Seconds)") = TT_sec(logging_end_idxs)';
    LogData_temp.("Logging Duration (Seconds)") = logging_ints.("Logging End (Seconds)") - logging_ints.("Logging Start (Seconds)");
    
    LogData_temp.("Date Analyzed") = repmat({datetime('now')}, height(logging_ints), 1);
    LogData_temp.("Creator") = repmat({creator}, height(logging_ints), 1);
    
    LogData = [LogData; LogData_temp];
    
else % If no logging
    
    tagID = file{i}(1:9);
    spec = file{i}(1:2);
    PHz = fs;
    
    TT_sec = 0:1/fs:length(p)/fs-(1/fs);
    
    record_dur = max(TT_sec);
    
    LogData_temp = table(repmat({tagID}, 1, 1),...
        repmat({spec}, 1, 1),...
        repmat({loc}, 1, 1),...
        repmat({tagtype}, 1, 1),...
        repmat({PHz}, 1, 1),...
        repmat({record_dur}, 1, 1), 'VariableNames', {'ID', 'Species', 'Location', 'Tag Type', 'PHz', 'Record Duration (Seconds)'});
    
    LogData_temp.StartI = NaN;
    LogData_temp.EndI = NaN;
    
    LogData_temp.("Logging Start (Seconds)") =  NaN;
    LogData_temp.("Logging End (Seconds)") =  NaN;
    LogData_temp.("Logging Duration (Seconds)") =  NaN;
    
    LogData_temp.("Date Analyzed") = repmat({datetime('now')},1, 1);
    LogData_temp.("Creator") = repmat({creator}, 1, 1);
    
    LogData = [LogData; LogData_temp];
    
    fprintf('%s has no logging in it. No figure is being saved but a row was added to LogData with NaNs.\n', tagID);
    
end

end

if isfile('LogData.mat')
    save('LogData.mat', 'LogData', '-append');
else
    save('LogData.mat', 'LogData');
end

clearvars -except LogData threshold

%% Step 4: Plot histogram of ALL logging intervals from table

if all(isnan(LogData.StartI))~= 1
    
    % Drop major outliers using Z-score
    % 1. Calculate the mean and standard deviation of the data
    meanData = mean(LogData.("Logging Duration (Seconds)"));
    stdData = std(LogData.("Logging Duration (Seconds)"));
    
    % 2. Define the threshold for outliers (e.g., 3 standard deviations from the mean)
    sd_threshold = 3;
    
    % 3. Calculate the Z-scores
    zScores = (LogData.("Logging Duration (Seconds)") - meanData) / stdData;
    
    % 4. Identify rows with Z-scores greater than the threshold (outliers)
    outlierRows = abs(zScores) > sd_threshold;
    
    % 5. Remove the rows that are outliers
    LogData_noOutliers = LogData(~outlierRows, :);
    
    % Plot
    nbins = sqrt(height(LogData_noOutliers));
    
    % if no logging was found nbins will be 0 and histogram will fail so only plot
    % if there is some data. otherwise throw a warning to alert the user.
    if(nbins > 0)
        figure;  % Create a new figure window
        histogram(LogData_noOutliers.("Logging Duration (Seconds)"), floor(nbins));  % Plot histogram
        
        % Add labels and title to the plot
        xlabel('Logging Duration (Seconds)');
        ylabel('Frequency');
        %set(gca, 'XScale', 'log')
        
        % Display grid for better readability
        grid on;
        
        % A. Find how many values are greater than the threshold
        aboveThreshold = LogData_noOutliers.("Logging Duration (Seconds)") > threshold;
        
        % B. Calculate the percentage of values above the threshold
        percentageAboveThreshold = sum(aboveThreshold) / height(LogData_noOutliers) * 100;
        
        % Display the result
        text(0.5, max(ylim) * 0.95, sprintf('%% of logging intervals > %.0f s: %.2f%%', threshold, percentageAboveThreshold), ...
            'FontSize', 12, 'Color', 'black');
    else
        warning('probably no logging was detected, nothing to plot');
    end
    
end

%% end the function
end