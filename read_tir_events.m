function [eventT] = read_tir_events(tir_path, threshold, min_gap_frames)
% READ_TIR_EVENTS_V4 Read TIR tiff file and extract event times
%
% Inputs:
%   tir_path   - path to the folder containing TIR file
%   threshold  - (optional) threshold for event detection, default 500
%   min_gap_frames - (optional) minimum gap between events (frames), default 50
%
% Outputs:
%   eventT     - event time indices (frame numbers)
%   pix_trace  - pixel intensity trace (mean of each frame)

if nargin < 2 || isempty(threshold)
    threshold = 500;
end
if nargin < 3 || isempty(min_gap_frames)
    min_gap_frames = 50;
end


% Auto-detect TIR file
tir_files = dir(fullfile(tir_path, '*TIR*.tiff'));
if isempty(tir_files)
    tir_files = dir(fullfile(tir_path, '*TIR*.tif'));
end
if isempty(tir_files)
    tir_files = dir(fullfile(tir_path, '*TIR*.ome.tiff'));
end
if isempty(tir_files)
    error('No TIR file found in %s', tir_path);
end
fname = tir_files(1).name;
disp(['... Processing TIR file: ', fname])


% Full path to TIR file
full_path = fullfile(tir_path, fname);

% Read TIR file info
info = imfinfo(full_path);
nFrames = numel(info);

% Read pixel trace
t = Tiff(full_path, 'r');
pix_trace = zeros(nFrames, 1);

for k = 1:nFrames
    t.setDirectory(k);
    frame = t.read();
    pix_trace(k) = mean(mean(frame));
end

t.close();

% Detect events
eventT = find(diff(pix_trace) > threshold) + 1;
if ~isempty(eventT)
    eventT(end) = [];
end

% Remove events that are too close together
if numel(eventT) > 1 && sum(diff(eventT)) > 0
    eventT(find(diff(eventT) < min_gap_frames) + 1) = [];
end

end
