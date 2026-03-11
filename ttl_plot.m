% Convert NITTL.mat files into a csv

% Select animal folder to begin with
animal_folder_path = uigetdir(pwd, 'Select animal folder');

animal_folder = dir(animal_folder_path);
session_folders = animal_folder(~ismember({animal_folder.name}, {'.','..'}));

for i=13%:numel(session_folders)
    session_folder_path = fullfile(animal_folder_path, session_folders(i).name);
    disp(session_folder_path)
    csv_files = dir(fullfile(session_folder_path, '*.csv'));
    csv_name = {csv_files.name};
    % disp(length(csv_name))

    if length(csv_name) ~= 1
        warning('Something went wrong. Please make sure there is one csv file in %s', session_folders(i).name)
        continue;
    end
    
    csv_path = fullfile(session_folder_path, csv_name{1});
    disp(csv_path)
    T = readtable(csv_path);

    figure('Position', [100, 100, 1000, 1200]) % left bottom width height
    tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact')

    % --- LED (NI only) ---
    nexttile
    histogram(T.led, 20, 'DisplayName', 'NI')
    xline(0, '--r', 'Ideal value', 'LineWidth', 2, 'HandleVisibility', 'off')
    xlabel('Time (ms)')
    title('LED − LED DAQ')

    % --- Sound ---
    nexttile
    histogram(T.sound - T.arduino_sound, 100, 'DisplayName', 'Sound - LED DAQ')
    % hold onf
    % histogram(T.arduino_sound, 20, 'DisplayName', 'ARDU')
    % xline(0, '--r', 'Ideal value', 'LineWidth', 2, 'HandleVisibility', 'off')
    legend('Location', 'north')
    xlabel('Time (ms)')
    title('Sound − LED DAQ')
    hold off

    % --- Motor Forward ---
    nexttile
    histogram(T.motor_fwd, 20, 'DisplayName', 'NI')
    hold on
    histogram(T.arduino_motor_fwd, 20, 'DisplayName', 'ARDU')
    xline(2000, '--r', 'Ideal value', 'LineWidth', 2, 'HandleVisibility', 'off')
    legend('Location', 'north')
    xlabel('Time (ms)')
    title('Motor Fwd − LED DAQ')
    hold off

    % --- Motor Backward ---
    nexttile
    histogram(T.motor_bwd, 20, 'DisplayName', 'NI')
    hold on
    histogram(T.arduino_motor_bwd, 20, 'DisplayName', 'ARDU')
    xline(4000, '--r', 'Ideal value', 'LineWidth', 2, 'HandleVisibility', 'off')
    legend('Location', 'north')
    xlabel('Time (ms)')
    title('Motor Bwd − LED DAQ')
    hold off

    % --- Reinforcer ---
    nexttile
    histogram(T.reinforcer, 20, 'DisplayName', 'NI')
    hold on
    histogram(T.arduino_water, 20, 'DisplayName', 'ARDU')
    xline(3000, '--r', 'Ideal value', 'LineWidth', 2, 'HandleVisibility', 'off')
    legend('Location', 'north')
    xlabel('Time (ms)')
    title('Water − LED DAQ')
    hold off

    % --- Motor Duration ---
    nexttile
    histogram(T.motor_bwd - T.motor_fwd, 20, 'DisplayName', 'NI')
    hold on
    histogram(T.arduino_motor_bwd - T.arduino_motor_fwd, 20, 'DisplayName', 'ARDU')
    % xline(2000, '--r', 'Ideal value', 'LineWidth', 2, 'HandleVisibility', 'off')
    legend('Location', 'north')
    xlabel('Time (ms)')
    title('Motor Duration (Bwd − Fwd)')
    hold off

    % --- NIDAQ and Arduino Differences, motor---
    nexttile
    histogram(T.arduino_motor_fwd - T.motor_fwd, 20, 'DisplayName', 'Fwd')
    hold on
    histogram(T.arduino_motor_bwd - T.motor_bwd, 20, 'DisplayName', 'Bwd')
    xline(0, '--r', 'Ideal value', 'LineWidth', 2, 'HandleVisibility', 'off')
    legend('Location', 'north')
    xlabel('Time (ms)')
    title('NIDAQ and Arduino Motor Differences')
    hold off

    % --- NIDAQ and Arduino Differences, reinforcer ---
    nexttile
    histogram(T.arduino_water - T.reinforcer, 20, 'DisplayName', 'Water')
    xline(0, '--r', 'Ideal value', 'LineWidth', 2, 'HandleVisibility', 'off')
    legend('Location', 'north')
    xlabel('Time (ms)')
    title('NIDAQ and Arduino Reinforcer Differences')
    hold off

    sgtitle(session_folders(i).name)
    saveas(gcf, fullfile(session_folder_path, [session_folders(i).name, '-ttl_diff_check.png']))

    disp(['==== Done plotting TTL differences for ', session_folders(i).name, ' ===='])
end


