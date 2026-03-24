% Ziyu Wang, 2026-03-18
% Move session contents to D:\Data-processed\<animal>\<session>\.
% <session>.mat and all .png files are copied to the new folder and kept
% in the original session folder; everything else is moved (removed from
% the original folder).
% If a non-keep item already exists at destination, source is deleted.
% Keep items are: <session>.mat and any .png file in the session folder.
%
% Sessions without a file named <session>.mat in the session folder are skipped.
%
% Usage: run script, select an animal folder (parent of session subfolders).

processed_root = 'D:\Data-processed';

animal_folder_path = uigetdir(pwd, 'Select animal folder');
if isequal(animal_folder_path, 0)
    disp('Cancelled.');
    return;
end

[~, animal_name, ~] = fileparts(animal_folder_path);

if ~exist(processed_root, 'dir')
    mkdir(processed_root);
end

dest_animal_path = fullfile(processed_root, animal_name);
if ~exist(dest_animal_path, 'dir')
    mkdir(dest_animal_path);
end

animal_folder = dir(animal_folder_path);
session_entries = animal_folder(~ismember({animal_folder.name}, {'.', '..'}));
% Only session *folders* (skip stray files at animal level)
session_entries = session_entries([session_entries.isdir]);

for i = 1:numel(session_entries)
    session_name = session_entries(i).name;
    session_folder_path = fullfile(animal_folder_path, session_name);

    session_mat_path = fullfile(session_folder_path, [session_name, '.mat']);
    if ~exist(session_mat_path, 'file')
        warning('Skipping session (no matching .mat): expected %s in %s', [session_name, '.mat'], session_name)
        continue;
    end

    dest_session_path = fullfile(dest_animal_path, session_name);
    if ~exist(dest_session_path, 'dir')
        mkdir(dest_session_path);
    end

    disp(['===== Session: ', session_name, ' =====']);

    items = dir(session_folder_path);
    items = items(~ismember({items.name}, {'.', '..'}));

    keep_name = [session_name, '.mat'];

    for k = 1:numel(items)
        item_name = items(k).name;
        src = fullfile(session_folder_path, item_name);
        dst = fullfile(dest_session_path, item_name);
        [~, ~, ext] = fileparts(item_name);

        try
            if items(k).isdir
                if exist(dst, 'dir')
                    rmdir(src, 's');
                    disp(['  deleted source (dest exists): ', item_name, '/']);
                else
                    movefile(src, dst);
                    disp(['  moved: ', item_name, '/']);
                end
            elseif strcmp(item_name, keep_name)
                % Session .mat: present in both locations
                if exist(dst, 'file')
                    disp(['  skip (dest exists): ', item_name]);
                else
                    copyfile(src, dst);
                    disp(['  copied (both): ', item_name]);
                end
            elseif strcmpi(ext, '.png')
                % Any .png in session folder: present in both locations
                if exist(dst, 'file')
                    disp(['  skip (dest exists): ', item_name]);
                else
                    copyfile(src, dst);
                    disp(['  copied (both): ', item_name]);
                end
            else
                if exist(dst, 'file') || exist(dst, 'dir')
                    delete(src);
                    disp(['  deleted source (dest exists): ', item_name]);
                else
                    movefile(src, dst);
                    disp(['  moved: ', item_name]);
                end
            end
        catch ME
            warning('Failed for %s -> %s: %s', src, dst, ME.message);
        end
    end
end

disp('Done. Processed data under: ');
disp(fullfile(processed_root, animal_name));
