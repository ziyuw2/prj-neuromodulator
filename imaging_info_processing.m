% Ziyu Wang, 2026-03-18
% 3. Extract imaging information from Fall.mat file after suite2p processing and manual curation
%
% Requires readNPY on the MATLAB path (e.g. npy-matlab) for F, Fneu, spks, iscell.
% stat.npy and ops.npy are loaded via load_suite2p_stat_ops_npy (MATLAB Python + NumPy,
% allow_pickle): Fall.stat is 1xn cell of ROI structs; Fall.ops is a struct.

animal_folder_path = uigetdir(pwd, 'Select animal folder');

animal_folder = dir(animal_folder_path);
session_folders = animal_folder(~ismember({animal_folder.name}, {'.','..'}));
% Only process subfolders (skip stray files at animal level)
session_folders = session_folders([session_folders.isdir]);

npy_names = {'stat.npy', 'ops.npy', 'F.npy', 'Fneu.npy', 'spks.npy', 'iscell.npy'};

for i = 9%:numel(session_folders)
    session_folder_path = fullfile(animal_folder_path, session_folders(i).name);
    disp(['============ Processing session: ', session_folders(i).name, ' ============='])
    cd(session_folder_path);

    mat_path = fullfile(session_folder_path, [session_folders(i).name, '.mat']);
    if ~exist(mat_path, 'file')
        warning('.mat file not found (expected %s) in %s', [session_folders(i).name, '.mat'], session_folders(i).name)
        continue;
    end

    suite2p_plane = fullfile(session_folder_path, 'green', 'cyto', 'suite2p', 'plane0');
    fall_mat_path = fullfile(suite2p_plane, 'Fall.mat');

    if exist(fall_mat_path, 'file')
        Fall = load(fall_mat_path);
        save(mat_path, 'Fall', '-append');
        disp(['Appended Fall (from Fall.mat) to: ', session_folders(i).name, '.mat'])
    else
        missing_npy = {};
        for j = 1:numel(npy_names)
            p = fullfile(suite2p_plane, npy_names{j});
            if ~exist(p, 'file')
                missing_npy{end+1} = npy_names{j}; %#ok<AGROW>
            end
        end

        if isempty(missing_npy)
            % Load numeric arrays first (readNPY-compatible). stat/ops often break readNPY.
            try
                Fall = struct( ...
                    'F', readNPY(fullfile(suite2p_plane, 'F.npy')), ...
                    'Fneu', readNPY(fullfile(suite2p_plane, 'Fneu.npy')), ...
                    'spks', readNPY(fullfile(suite2p_plane, 'spks.npy')), ...
                    'iscell', readNPY(fullfile(suite2p_plane, 'iscell.npy')));
            catch ME
                warning('Could not read core suite2p .npy (F/Fneu/spks/iscell) in %s: %s — skipping Fall append.', ...
                    suite2p_plane, ME.message);
                Fall = [];
            end

            if ~isempty(Fall)
                stat_npy = fullfile(suite2p_plane, 'stat.npy');
                ops_npy = fullfile(suite2p_plane, 'ops.npy');
                [Fall.stat, Fall.ops] = load_suite2p_stat_ops_npy(stat_npy, ops_npy);

                save(mat_path, 'Fall', '-append');
                disp(['Appended Fall (from .npy) to: ', session_folders(i).name, '.mat'])
            end
        else
            warning(['Fall.mat not found and missing .npy in ', suite2p_plane, ': ', strjoin(missing_npy, ', '), ...
                ' — skipping Fall append.'])
        end
    end

end
