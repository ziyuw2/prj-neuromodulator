function trialInfo = nittl_processing_v3(nittl, time, sessionInfo, trialInfo)
    led_threshold = sessionInfo.nittl_threshold.led;
    sound_threshold = sessionInfo.nittl_threshold.sound;
    motor_threshold = sessionInfo.nittl_threshold.motor;
    reinforcer_threshold = sessionInfo.nittl_threshold.reinforcer;

    trialInfo.nittl_led = get_rising_time(nittl.LED, time, led_threshold, 1);
    disp(['nittl led: ', num2str(length(trialInfo.nittl_led))])

    trialInfo.nittl_led_ardudaq = get_rising_time(nittl.LED_arduDaq, time, led_threshold, 1);
    disp(['nittl led_ardudaq: ', num2str(length(trialInfo.nittl_led_ardudaq))])

    trialInfo.nittl_sound = get_rising_time(nittl.Sound, time, sound_threshold, 1);
    disp(['nittl sound: ', num2str(length(trialInfo.nittl_sound))])

    trialInfo.nittl_motor = get_rising_time(nittl.Motor, time, motor_threshold, 1);
    disp(['nittl motor: ', num2str(length(trialInfo.nittl_motor))])

    if ~isnan(nittl.Motor)
        trialInfo.nittl_motor_fwd = trialInfo.nittl_motor(1:2:end);
        trialInfo.nittl_motor_bwd = trialInfo.nittl_motor(2:2:end);
    else
        trialInfo.nittl_motor_fwd = NaN;
        trialInfo.nittl_motor_bwd = NaN;
    end
    disp(['nittl motor_fwd: ', num2str(length(trialInfo.nittl_motor_fwd))])
    disp(['nittl motor_bwd: ', num2str(length(trialInfo.nittl_motor_bwd))])

    % ttl.reinforcer contains both reinforcer and led-daq timepoints; extracting only reinforcer timepoints
    trialInfo.nittl_reinforcer = get_rising_time(nittl.Reinforcer, time, reinforcer_threshold, 1);
    disp(class(trialInfo.nittl_reinforcer))
    trialInfo.nittl_reinforcer = get_rising_time_reinforcer(trialInfo.nittl_reinforcer, trialInfo.trialType);
    disp(['nittl reinforcer: ', num2str(length(trialInfo.nittl_reinforcer))])

    trialInfo.nittl = check_timepoints(trialInfo.nittl);
    trialInfo.nittl = align_to_leddaq(trialInfo.nittl);
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