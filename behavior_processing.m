% Ziyu Wang, 2026-03-12
% Extract session and trial information from GO.mat file

animal_folder_path = uigetdir(pwd, 'Select animal folder');

animal_folder = dir(animal_folder_path);
session_folders = animal_folder(~ismember({animal_folder.name}, {'.','..'}));

for i=3 %:numel(session_folders)
    sessionInfo = struct();
    trialInfo = struct(); 

    session_folder_path = fullfile(animal_folder_path, session_folders(i).name);
    disp(session_folders(i).name)
    cd(session_folder_path);

    behavior_file = dir('*GO*.mat');

    if isempty(behavior_file)
        warning('GO.mat file not found in the %s', session_folders(i).name)
        continue;
    end

    % Load behavior file
    disp(['Loading behavior file:', behavior_file.name])
    behmat_path = fullfile(behavior_file.name);
    disp(behavior_file.name)
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
    
    info_keys = fieldnames(behavior.Info);
    for j = 1:numel(info_keys)
        sessionInfo.(info_keys{j}) = behavior.Info.(info_keys{j});
    end
    behavior = rmfield(behavior, 'Info');

    % extract trial information from behavior.event
    event_keys = fieldnames(behavior.event);
    for j = 1:numel(event_keys)
        trialInfo.(event_keys{j}) = behavior.event.(event_keys{j});
    end
    behavior = rmfield(behavior, 'event');

    % extract session and trial information from behavior
    behavior_keys = fieldnames(behavior);
    sessionInfo_target_fields = {'Init', 'expType'};
    trialInfo_target_fields = {'rule', 'CStypeDir', 'tone', 'trialType'};

    for j=1:numel(behavior_keys)
        if ismember(behavior_keys{j}, sessionInfo_target_fields)
            sessionInfo.(behavior_keys{j}) = behavior.(behavior_keys{j});
        elseif ismember(behavior_keys{j}, trialInfo_target_fields)
            trialInfo.(behavior_keys{j}) = behavior.(behavior_keys{j});
        end
    end
end