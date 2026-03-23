function trialInfo = nittl_processing_v3(nittl, time, sessionInfo, trialInfo)
    ttl = struct();
    led_threshold = sessionInfo.nittl_threshold.led;
    sound_threshold = sessionInfo.nittl_threshold.sound;
    motor_threshold = sessionInfo.nittl_threshold.motor;
    reinforcer_threshold = sessionInfo.nittl_threshold.reinforcer;

    ttl.nittl_led = get_rising_time(nittl.LED, time, led_threshold, 1);
    disp(['nittl led: ', num2str(length(ttl.nittl_led))])

    ttl.nittl_led_ardudaq = get_rising_time(nittl.LED_arduDaq, time, led_threshold, 1);
    disp(['nittl led_ardudaq: ', num2str(length(ttl.nittl_led_ardudaq))])

    ttl.nittl_sound = get_rising_time(nittl.Sound, time, sound_threshold, 1);
    disp(['nittl sound: ', num2str(length(ttl.nittl_sound))])

    ttl.nittl_motor = get_rising_time(nittl.Motor, time, motor_threshold, 1);
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
    ttl.nittl_reinforcer = get_rising_time(nittl.Reinforcer, time, reinforcer_threshold, 1);
    ttl.nittl_reinforcer = get_rising_time_reinforcer(ttl.nittl_reinforcer, trialInfo.trialType);
    disp(['nittl reinforcer: ', num2str(length(ttl.nittl_reinforcer))])

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
function [timepoints] = get_rising_time(daq_seq, time_seq, threshold_diff, threshold_time)
    timepoints = time_seq([0; diff(daq_seq)] > threshold_diff);
    timepoints(find(diff(timepoints) < threshold_time) + 1) = [];
    % Output double (ms): time_seq in seconds; ensure numeric ms
    timepoints = 1000 * double(timepoints);
end

% Reinforcer contains both reinforcer and led-daq timepoints; extracting only reinforcer timepoints
function [reinforcer_timepoints] = get_rising_time_reinforcer(ttl_reinforcer, trialType)
    % Output: one value per trial; R trials get the corresponding ttl_reinforcer value, rest are NaN
    reinforcer_timepoints = NaN(numel(trialType), 1);
    isR = strcmp(trialType, 'R');
    % nR = sum(isR);
    assert(numel(ttl_reinforcer) == sum(isR), 'Reinforcer timepoints length must match the number of R trials');
    reinforcer_timepoints(isR) = ttl_reinforcer(1:numel(ttl_reinforcer));
end

% function [ttl] = check_timepoints(ttl)
%     fields = fieldnames(ttl);
%     length_list = zeros(1, numel(fields));
%     for k = 1:numel(fields) 
%         length_list(k) = length(ttl.(fields{k}));
%     end
%     valid_length = length_list(length_list > 1);
%     tot_trial = mode(valid_length);
%     aligned = length_list == tot_trial;
%     for k = 1:numel(fields)
%         if ~aligned(k)
%             disp(['Timepoints are not aligned for ', fields{k}])
%             ttl.(fields{k}) = NaN(tot_trial, 1);
%         end
%     end
% end

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
            % jitter_idx = 0 < ttl.(fields{k}) & ttl.(fields{k}) < 700;
            % disp(['There are ', num2str(sum(jitter_idx)), ' jitter timepoints for ', fields{k}])
            % ttl.(fields{k})(jitter_idx) = NaN;
        end
    end
    ttl.nittl_led_ardudaq = zeros(numel(ref), 1);
end