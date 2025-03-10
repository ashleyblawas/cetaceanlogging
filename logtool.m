% A tool to extract & save logging periods

%% Setting up global parameters
clear; close all; clc

% Set a threshold at which point we know the tag is certainly on the animal
% (or on its way off)
tagon_thres = 5;

% Set a minimum duration to count as a SURFACING (in seconds)!
min_surf = 1;

% Set a minimum LOGGING duration (in seconds)!
min_log = 10;

%% Step 1A: Choose a prh file to process
[file, path] = uigetfile('*.mat', 'Select a .mat file', 'MultiSelect', 'on');

%% 
for i = 1:length(file)
    
close all; 
clearvars -except i file path min_log min_surf tagon_thres
% Check if the user selected a file
if isequal(file{i},0)
    disp('User canceled the file selection');
else
    % Create the full path to the file
    fullFileName = fullfile(path, file{i});
    
    % Load the .mat file
    data = load(fullFileName);
    
    % Display the contents of the .mat file
    disp('Contents of the .mat file:');
    disp(data);
    
    % Prompt the user to choose the type of file
    %choice = questdlg('Select the tag type that recorded this data:', 'File Type Selection', ...
        %'CATS', 'DTAG', 'Cancel', 'CATS');
    
    % Handle the user's choice
%     switch choice
%         case 'CATS'
%             disp('You selected a CATS tag file.');
%             % You can add further code here to handle Cats tag files
%             % For example, loading or processing a Cats tag file
%             % file = uigetfile('*.cats', 'Select Cats tag file'); % Uncomment to allow file selection
%             
%         case 'DTAG'
%             disp('You selected a DTAG file.');
%             % You can add further code here to handle Dtag files
%             % For example, loading or processing a Dtag file
%             % file = uigetfile('*.dtag', 'Select Dtag file'); % Uncomment to allow file selection
%             
%         case 'Cancel'
%             disp('User canceled the selection.');
%             % Add code to handle cancellation if needed
%     end
    
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

%% Step 2: Chop to only tag on times

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

%% Step 3: Identify surface periods
tt_sec = 0:1/fs:length(p_tagon)/fs-(1/fs);
tt_min = tt_sec/60;
tt_hour = tt_sec/60/60;

% Smooth depth signal
% p_smooth_tag = smoothdata(p_tagon, 'movmean', fs);
% p_shallow = p_smooth_tag;

% Remove any pressure data that is greater than 1 m and get indexes
% of shallow periods
p_shallow(p_tagon>1) = NaN;
p_shallow_idx = find(~isnan(p_shallow));

% Plot smoothed depth for only time when tag is on
%figure('units','normalized','outerposition',[0 0.15 0.6 0.75]);

paperSize = [11.5, 7];  % A4 size: [width, height] in inches
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

% Plot logging surfacings in pink
if length(logging_surf_rows)>0
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

legend([p1 p2 p3 p4],{'Dive depth' , 'Logging', 'Start of surfacing', 'End of surfacing'}, 'Location', 'best')

%% Print out summary data

med_log_int = median(logging_ints.("Logging Duration (Seconds)"));
log_tot_min = sum(logging_ints.("Logging Duration (Seconds)"))/60;
log_percent = 100*sum(logging_ints.("Logging Duration (Seconds)"))/tt_sec(end);

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
