% Ziyu Wang, 2026-03-12
% 1. Extract session and trial information from GO.mat file (via nittl_processing)
% 2. Extract metadata from .txt file (via get_metadata)
% 3. Extract timepoints from TIR tiff file (via read_tir_events)

animal_folder_path = uigetdir(pwd, 'Select animal folder');

animal_folder = dir(animal_folder_path);
session_folders = animal_folder(~ismember({animal_folder.name}, {'.','..'}));
% Only process subfolders (skip stray files at animal level)
session_folders = session_folders([session_folders.isdir]);

for i = 9%:numel(session_folders)
    sessionInfo = struct();
    trialInfo = struct(); 
    imagingInfo = struct();

    session_folder_path = fullfile(animal_folder_path, session_folders(i).name);
    output_mat_path = fullfile(session_folder_path, [session_folders(i).name, '.mat']);
    mat_exists = exist(output_mat_path, 'file');
    disp(['———————————————————————————— Processing session: ', session_folders(i).name, ' ——————————————————————————————'])
    if mat_exists
        disp('Existing .mat found: updating sessionInfo / trialInfo / imagingInfo only (e.g. Fall unchanged).')
    end

    cd(session_folder_path);
    behavior_file = dir('*GO*.mat');
    nittl_file = dir('*NITTL*.mat');
    metadata_file = dir('*metadata*.txt');
    if isempty(behavior_file)
        warning('GO.mat file not found in the %s', session_folders(i).name)
        continue;
    end
    if isempty(nittl_file)
        warning('NITTL.mat file not found in the %s', session_folders(i).name)
        continue;
    end


    %% Load behavior file (GO.mat)
    disp(['... Processing behavior file:', behavior_file.name])
    behmat_path = fullfile(behavior_file.name);
    tmp = load(behavior_file.name);
    behavior = tmp.session;
    % extract session information from behavior.Info.session
    session = behavior.Info.session;
    session_keys = fieldnames(behavior.Info.session);
    session_target_fields = {'computerName', 'date', 'animalID', 'rig', 'experimenter', ...
                     'expType', 'animalType', 'rule', 'motorConnection', 'daqrec', ...
                     'name', 'taskName', 'startTime', 'endTime', 'totalTime'};
    
    for j = 1:numel(session_keys)
        if ismember(session_keys{j}, session_target_fields)
            sessionInfo.(session_keys{j}) = string(session.(session_keys{j}));
        end
    end

    behavior.Info = rmfield(behavior.Info, 'session');
    % extract the rest fields of behavior.Info to sessionInfo
    info_keys = fieldnames(behavior.Info);
    for j = 1:numel(info_keys)
        sessionInfo.(info_keys{j}) = behavior.Info.(info_keys{j});
    end
    behavior = rmfield(behavior, 'Info');

    % extract trial information from behavior.event
    event_keys = fieldnames(behavior.event);
    for j = 1:numel(event_keys)
        trialInfo.(event_keys{j}) = behavior.event.(event_keys{j})';
    end
    behavior = rmfield(behavior, 'event');

    % extract session and trial information from behavior
    behavior_keys = fieldnames(behavior);
    sessionInfo_target_fields = {'Init', 'expType'};
    trialInfo_target_fields_cc  = {'iti','rule', 'CStypeDir', 'tone', 'trialType'};
    trialInfo_target_fields_gng = {'iti','rule', 'trialTypeDir', 'tone', 'behavior'};

    use_gng = contains(session_folders(i).name, 'GNG');
    if use_gng
        trialInfo_target_fields = trialInfo_target_fields_gng;
    else
        trialInfo_target_fields = trialInfo_target_fields_cc;
    end

    for j=1:numel(behavior_keys)
        if ismember(behavior_keys{j}, sessionInfo_target_fields)
            sessionInfo.(behavior_keys{j}) = behavior.(behavior_keys{j});
        elseif ismember(behavior_keys{j}, trialInfo_target_fields)
            trialInfo.(behavior_keys{j}) = behavior.(behavior_keys{j})';
        end
    end
    
    
    %% load nittl file (NITTL.mat)
    sessionInfo.nittl_threshold.led= 2;
    sessionInfo.nittl_threshold.sound= 3;
    sessionInfo.nittl_threshold.motor= 2;
    sessionInfo.nittl_threshold.reinforcer= 2;
    sessionInfo.nittl_threshold.water= 2;
    sessionInfo.nittl_threshold.airpuff= 2;
    disp(['... Processing nittl file:', nittl_file.name])
    nittlmat_path = fullfile(nittl_file.name);
    tmp = load(nittl_file.name);
    nittl = tmp.session.NIDAQ.raw;
    time = seconds(nittl.Time);

    trialInfo = nittl_processing(nittl, time, sessionInfo, trialInfo);

    %% Process metadata file (optional)
    has_metadata = false;
    if isempty(metadata_file)
        warning('metadata.txt file not found in %s; saving without imagingInfo metadata.', session_folders(i).name)
    else
        disp('... Processing metadata file')
        metadata_path = fullfile(metadata_file.name);
        imagingInfo = get_metadata(metadata_path);
        has_metadata = true;
    end


    %% Extract timepoints from TIR tiff file (via read_tir_events)
    diff_threshold = 100;
    timegap_threshold_s = 5; % minimum gap in seconds between detected rises
    sessionInfo.tir_threshold.tir_diff = diff_threshold;
    sessionInfo.tir_threshold.tir_timegap_s = timegap_threshold_s;
    trialInfo.tir_frames = [];
    trialInfo.tir_mean_trace = [];

    tir_folder_path = fullfile(session_folder_path, 'tir');
    if exist(tir_folder_path, 'dir')
        if has_metadata && isfield(imagingInfo, 'frame_rate_Hz') && imagingInfo.frame_rate_Hz > 0
            frame_rate_Hz = imagingInfo.frame_rate_Hz;
            disp(['Frame rate: ', num2str(frame_rate_Hz)])
        else
            disp('Frame rate not found in metadata; double check.')
        end

        min_gap_frames = timegap_threshold_s * frame_rate_Hz;
        try
            [tir_frames, pix_trace] = read_tir_events(tir_folder_path, diff_threshold, min_gap_frames);
            trialInfo.tir_frames = tir_frames;
            trialInfo.tir_mean_trace = pix_trace;
            disp(['Extracted TIR rises: ', num2str(numel(tir_frames))])
        catch ME
            warning('Failed to extract TIR events in %s: %s', tir_folder_path, ME.message)
        end
    else
        warning('TIR folder not found in %s', session_folders(i).name)
    end


    %% Save outputs (append if file exists so Fall and other vars are preserved)
    if mat_exists
        save(output_mat_path, 'sessionInfo', 'trialInfo', '-append');
        if has_metadata
            save(output_mat_path, 'imagingInfo', '-append');
        end
    elseif has_metadata
        save(output_mat_path, 'sessionInfo', 'trialInfo', 'imagingInfo');
    else
        save(output_mat_path, 'sessionInfo', 'trialInfo');
    end

    disp(['======================= .mat file saved to ', session_folders(i).name, '.mat ======================='])

end