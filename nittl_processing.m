function trialInfo = nittl_processing(nittl, time, sessionInfo, trialInfo)
    ttl = struct();
    led_threshold = sessionInfo.nittl_threshold.led;
    sound_threshold = sessionInfo.nittl_threshold.sound;
    motor_threshold = sessionInfo.nittl_threshold.motor;
    reinforcer_threshold = sessionInfo.nittl_threshold.reinforcer;
    water_threshold = sessionInfo.nittl_threshold.water;
    airpuff_threshold = sessionInfo.nittl_threshold.airpuff;

    ttl.nittl_led = get_rising_time(nittl.LED, time, led_threshold, 1, 3);
    disp(['nittl led: ', num2str(length(ttl.nittl_led))])

    ttl.nittl_led_ardudaq = get_rising_time(nittl.LED_arduDaq, time, led_threshold, 1, 3);
    disp(['nittl led_ardudaq: ', num2str(length(ttl.nittl_led_ardudaq))])

    ttl.nittl_sound = get_rising_time(nittl.Sound, time, sound_threshold, 1, 0);
    disp(['nittl sound: ', num2str(length(ttl.nittl_sound))])

    ttl.nittl_motor = get_rising_time(nittl.Motor, time, motor_threshold, 0.5, 3);
    disp(['nittl motor: ', num2str(length(ttl.nittl_motor))])
    if ~isnan(nittl.Motor)
        ttl.nittl_motor_fwd = ttl.nittl_motor(1:2:end);
        ttl.nittl_motor_bwd = ttl.nittl_motor(2:2:end);
    else
        ttl.nittl_motor_fwd = NaN;
        ttl.nittl_motor_bwd = NaN;
    end
    disp(['nittl motor_fwd: ', num2str(length(ttl.nittl_motor_fwd))])
    disp(['nittl motor_bwd: ', num2str(length(ttl.nittl_motor_bwd))])
    ttl = rmfield(ttl, 'nittl_motor');

    % ttl.reinforcer contains both reinforcer and led-daq timepoints; extracting only reinforcer timepoints
    if any(strcmp(nittl.Properties.VariableNames, "Reinforcer"))
        ttl.nittl_reinforcer = get_rising_time(nittl.Reinforcer, time, reinforcer_threshold, 1, 2);
        disp(['nittl reinforcer before alignment: ', num2str(length(ttl.nittl_reinforcer))])
        ttl.nittl_reinforcer = align_reinforcer(ttl.nittl_reinforcer, trialInfo);
        disp(['nittl reinforcer after alignment: ', num2str(length(ttl.nittl_reinforcer))])
    elseif any(strcmp(nittl.Properties.VariableNames, "Water")) && any(strcmp(nittl.Properties.VariableNames, "Airpuff"))
        ttl.nittl_water = get_rising_time(nittl.Water, time, water_threshold, 1, 2);
        disp(['nittl water: ', num2str(length(ttl.nittl_water))])
        ttl.nittl_water = align_reinforcer(ttl.nittl_water, trialInfo, "Hit");
        disp([' nittl water after alignment: ', num2str(length(ttl.nittl_water))])
        ttl.nittl_airpuff = get_rising_time(nittl.Airpuff, time, airpuff_threshold, 1, 2);
        disp(['nittl airpuff: ', num2str(length(ttl.nittl_airpuff))])
        ttl.nittl_airpuff = align_reinforcer(ttl.nittl_airpuff, trialInfo, "FA");
        disp([' nittl airpuff after alignment: ', num2str(length(ttl.nittl_airpuff))])
    else
        warning('Neither reinforcer nor water and airpuff found in nittl; setting reinforcer_timepoints to NaN.');
        ttl.nittl_reinforcer = NaN(0, 1);
        ttl.nittl_water = NaN(0, 1);
        ttl.nittl_airpuff = NaN(0, 1);
    end


    % trialInfo.nittl = check_timepoints(trialInfo.nittl);
    ttl = align_to_leddaq(ttl);

    ttl_fields = fieldnames(ttl);
    for k = 1:numel(ttl_fields)
        field_name = ttl_fields{k};
        trialInfo.(field_name) = ttl.(field_name);
    end
end

% Find the difference betwee two consecutive timepoints in seq greater than threshold_diff
% and remove the timepoints that are less than threshold_time
function [timepoints] = get_rising_time(daq_seq, time_seq, threshold_diff, threshold_time, lower_bound)
    daq_seq(daq_seq < lower_bound) = 0;
    timepoints = time_seq([0; diff(daq_seq)] > threshold_diff);
    timepoints(find(diff(timepoints) < threshold_time) + 1) = [];
    % Output double (ms): time_seq in seconds; ensure numeric ms
    timepoints = 1000 * double(timepoints);
end

% Reinforcer contains both reinforcer and led-daq timepoints; extracting only reinforcer timepoints
function [reinforcer_timepoints] = align_reinforcer(ttl_reinforcer, trialInfo, target_label)
    % CC sessions: align reinforcer to R trials using trialInfo.trialType.
    % GNG sessions: align reinforcer to FA trials using trialInfo.behavior.
    if isfield(trialInfo, 'trialType')
        labels = trialInfo.trialType;
        labels = string(labels(:));
        target_mask = labels == "R";
        fprintf(' Detected R trials (CC): %d\n', sum(target_mask));
    elseif isfield(trialInfo, 'behavior')
        if nargin < 3
            target_label = "FA";
        elseif isempty(target_label)
            target_label = "FA";
        else
            target_label = string(target_label);
        end
        labels = trialInfo.behavior;
        labels = string(labels(:));
        target_mask = labels == target_label;
        fprintf(' Detected %s trials (GNG): %d\n', char(target_label), sum(target_mask));
    else
        warning(' Neither trialType nor behavior found in trialInfo; setting reinforcer_timepoints to NaN.');
        reinforcer_timepoints = NaN(0, 1);
        return;
    end

    % if the number of reinforcer TTL is aligned, then the rest of reinforcer TTL are set to NaN. If not, keep the original reinforcer TTL.
    if sum(target_mask) == numel(ttl_reinforcer)
        reinforcer_timepoints = NaN(numel(target_mask), 1);
        reinforcer_timepoints(target_mask) = ttl_reinforcer;
        disp(' Reinforcer timepoints aligned.')
    else
        disp(' Reinforcer timepoints length mismatched with trial Type info.');
        reinforcer_timepoints = ttl_reinforcer;
    end
end

% Align the timepoints to the led-daq timepoints, setting the led-daq timepoints to 0
function [ttl] = align_to_leddaq(ttl)
    fields = fieldnames(ttl);
    ref = ttl.nittl_led_ardudaq;

    for k = 1:numel(fields)
        field_name = fields{k};
        if ~strcmp(field_name, 'nittl_led_ardudaq')
            current = ttl.(field_name);

            % Some sessions can have empty fields; keep them empty.
            if isempty(current)
                continue;
            end

            % If reference is empty, preserve size and mark as missing.
            if isempty(ref)
                ttl.(field_name) = NaN(size(current));
                continue;
            end

            if numel(current) == numel(ref)
                ttl.(field_name) = current - ref;
            else
                % Keep shape stable when lengths are mismatched.
                n = min(numel(current), numel(ref));
                aligned = NaN(size(current));
                aligned(1:n) = current(1:n) - ref(1:n);
                ttl.(field_name) = aligned;
            end
        end
    end
    ttl.nittl_led_ardudaq = zeros(numel(ref), 1);
end