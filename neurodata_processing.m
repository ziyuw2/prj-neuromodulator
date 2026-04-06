% Ziyu Wang, 2026-04-06
% 4. Align and process neurodata

animal_folder_path = uigetdir(pwd, 'Select animal folder');

animal_folder = dir(animal_folder_path);
session_folders = animal_folder(~ismember({animal_folder.name}, {'.','..'}));
% Only process subfolders (skip stray files at animal level)
session_folders = session_folders([session_folders.isdir]);

for i = 1%:numel(session_folders)
    session_folder_path = fullfile(animal_folder_path, session_folders(i).name);
    mat_path = fullfile(session_folder_path, [session_folders(i).name, '.mat']);
    if ~exist(mat_path, 'file')
        warning('.mat file not found (expected %s) in %s', [session_folders(i).name, '.mat'], session_folders(i).name)
        continue;
    end
    load(mat_path);
    Fall = sessionInfo.Fall;
    F = Fall.F;
    Fneu = Fall.Fneu;
    iscell = Fall.iscell;

    

end