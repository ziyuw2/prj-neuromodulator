% Ziyu Wang, 2026-03-10
% Accomodating the USB speaker
% sound is not extracted from NITTL.mat file since using USB speaker

% Convert NITTL.mat files into a csv

% Select animal folder to begin with
animal_folder_path = uigetdir(pwd, 'Select animal folder');

animal_folder = dir(animal_folder_path);
session_folders = animal_folder(~ismember({animal_folder.name}, {'.','..'}));

for i=13 %:numel(session_folders)
    session_folder_path = fullfile(animal_folder_path, session_folders(i).name);
    disp(session_folder_path)
    cd(session_folder_path);
    nittl_file = dir('*NITTL*.mat');
    behavior_file = dir('*GO*.mat');
    if isempty(nittl_file) 
        warning('NITTL.mat file not found in the %s', session_folders(i).name)
        continue;
    end

    if isempty(behavior_file)
        warning('GO.mat file not found in the %s', session_folders(i).name)
        continue;
    end
    
    % Load behavior file
    disp(['Loading behavior file...', behavior_file.name])
    behmat_path = fullfile(behavior_file.name);
    disp(behavior_file.name)
    tmp = load(behavior_file.name);
    session = tmp.session;

    % Load NITTL.mat file
    disp(['Loading NITTL.mat file...', nittl_file.name])
    tmp = load(nittl_file.name);
    nittl = tmp.session.NIDAQ.raw;
    time = seconds(nittl.Time);
    disp(class(time))
    ttl = struct();

    led_threshold = 2;
    sound_threshold = 0.01;
    motor_threshold = 2;
    reinforcer_threshold = 2;

    ttl.led = get_rising_time(nittl.LED, time, 2, 1);
    disp(['nittl led: ', num2str(length(ttl.led))])

    ttl.led_ardudaq = get_rising_time(nittl.LED_arduDaq, time, 2, 1);
    disp(['nittl led_ardudaq: ', num2str(length(ttl.led_ardudaq))])

    ttl.sound = get_rising_time(nittl.Sound, time, 0.01, 1);
    disp(['nittl sound: ', num2str(length(ttl.sound))])

    ttl.motor = get_rising_time(nittl.Motor, time, 2, 1);
    disp(['nittl motor: ', num2str(length(ttl.motor))])

    if ~isnan(nittl.Motor)
        ttl.motor_fwd = ttl.motor(1:2:end);
        ttl.motor_bwd = ttl.motor(2:2:end);
    else
        ttl.motor_fwd = NaN;
        ttl.motor_bwd = NaN;
    end
    disp(['nittl motor_fwd: ', num2str(length(ttl.motor_fwd))])
    disp(['nittl motor_bwd: ', num2str(length(ttl.motor_bwd))])

    % ttl.reinforcer contains both reinforcer and led-daq timepoints; extracting only reinforcer timepoints
    ttl.reinforcer = get_rising_time(nittl.Reinforcer, time, 1, 1);
    disp(class(ttl.reinforcer))
    ttl.reinforcer = get_rising_time_reinforcer(ttl.reinforcer, session.trialType);
    disp(['nittl reinforcer: ', num2str(length(ttl.reinforcer))])

    ttl = check_timepoints(ttl);
    ttl = align_to_leddaq(ttl);

    T = table( ...
        ttl.led, ...
        ttl.led_ardudaq, ...
        ttl.sound, ...
        ttl.motor_fwd, ...
        ttl.reinforcer, ...
        ttl.motor_bwd, ...
        session.event.led', ...
        session.event.sound', ...
        session.event.port_on', ...
        session.event.port_off', ...
        session.event.water', ...
        session.event.airpuff', ...
        session.trialType', ...
        session.iti', ...
        'VariableNames', { ...
            'led', ...
            'led_daq', ...
            'sound', ...
            'motor_fwd', ...`
            'reinforcer', ...
            'motor_bwd' ...
            'arduino_led', ...
            'arduino_sound', ...
            'arduino_motor_fwd', ...
            'arduino_motor_bwd', ...
            'arduino_water', ...
            'arduino_airpuff', ...
            'trialType', ...
            'iti', ...
        } ...
    );

    writetable(T, fullfile(session_folder_path, [session_folders(i).name, '-nittl.csv']));
    disp(['==== Saved nittl.csv to ', fullfile(session_folder_path, [session_folders(i).name, '-nittl.csv']), ' ===='])
end


function [timepoints] = get_rising_time(daq_seq, time_seq, threshold_diff, threshold_time)
    timepoints = time_seq([0; diff(daq_seq)] > threshold_diff);
    timepoints(find(diff(timepoints) < threshold_time) + 1) = [];
    % Output double (ms): time_seq in seconds; ensure numeric ms
    timepoints = 1000 * double(timepoints);
end

function [reinforcer_timepoints] = get_rising_time_reinforcer(ttl_reinforcer, trialType)
    % Output: one value per trial; R trials get the corresponding ttl_reinforcer value, rest are NaN
    reinforcer_timepoints = NaN(numel(trialType), 1);
    isR = strcmp(trialType, 'R');
    % nR = sum(isR);
    assert(numel(ttl_reinforcer) == sum(isR), 'Reinforcer timepoints length must match the number of R trials');
    reinforcer_timepoints(isR) = ttl_reinforcer(1:numel(ttl_reinforcer));
end

function [ttl] = check_timepoints(ttl)
    fields = fieldnames(ttl);
    length_list = zeros(1, numel(fields));
    for k = 1:numel(fields) 
        length_list(k) = length(ttl.(fields{k}));
    end
    valid_length = length_list(length_list > 1);
    tot_trial = mode(valid_length);
    aligned = length_list == tot_trial;
    for k = 1:numel(fields)
        if ~aligned(k)
            disp(['Timepoints are not aligned for ', fields{k}])
            ttl.(fields{k}) = NaN(tot_trial, 1);
        end
    end
end

function [ttl] = align_to_leddaq(ttl)
    fields = fieldnames(ttl);
    for k = 1:numel(fields)
        if ~strcmp(fields{k}, 'led_ardudaq')
            ttl.(fields{k}) = ttl.(fields{k}) - ttl.led_ardudaq;
            % jitter_idx = 0 < ttl.(fields{k}) & ttl.(fields{k}) < 700;
            % disp(['There are ', num2str(sum(jitter_idx)), ' jitter timepoints for ', fields{k}])
            % ttl.(fields{k})(jitter_idx) = NaN;
        end
    end
    ttl.led_ardudaq = zeros(numel(ttl.led_ardudaq), 1);
end