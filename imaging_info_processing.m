% Ziyu Wang, 2026-03-18
% 3. Extract imaging information from Fall.mat file after suite2p processing and manuel curation

animal_folder_path = uigetdir(pwd, 'Select animal folder');

animal_folder = dir(animal_folder_path);
session_folders = animal_folder(~ismember({animal_folder.name}, {'.','..'}));

for i=3 %:numel(session_folders)
    sessionInfo = struct();
    trialInfo = struct(); 
    imagingInfo = struct();

    session_folder_path = fullfile(animal_folder_path, session_folders(i).name);
    disp(['===== Processing session: ', session_folders(i).name, ' ====='])
    cd(session_folder_path);

    mat_file = dir('*0*.mat');

    if isempty(mat_file)
        warning('.mat file not found in the %s', session_folders(i).name)
        continue;
    end

    mat_path = fullfile(mat_file.name);
    tmp = load(mat_path);
    imagingInfo = tmp.imagingInfo;

    %% load Fall.mat from green\cyto\suite2p\plane0
    fall_path = fullfile(session_folder_path, 'green', 'cyto', 'suite2p', 'plane0', 'Fall.mat');
    if exist(fall_path, 'file')
        Fall = load(fall_path);
        disp('Processing Fall.mat file...')
    else
        warning('Fall.mat not found at %s', fall_path);
        Fall = struct();
    end

end