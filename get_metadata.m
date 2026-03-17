% Ziyu Wang, 2026-03-17
% Extract metadata from .txt file

function imagingInfo = get_metadata(metadata_path)
%GET_METADATA Locate and parse a metadata .txt file and extract fields
%
%   imagingInfo = GET_METADATA(metadata_path, imagingInfo)
%
%   Expects:
%     metadata_path : full path to metadata .txt file
%
%   Adds:
%     imagingInfo : struct with extracted fields

    imagingInfo = parse_metadata_txt(metadata_path);
    imagingInfo = extract_important_fields(imagingInfo);
end


function meta = parse_metadata_txt(filepath)
%PARSE_METADATA_TXT Parse metadata .txt into a containers.Map

    meta = containers.Map('KeyType', 'char', 'ValueType', 'char');

    txt = fileread(filepath);
    lines = regexp(txt, '\r\n|\n|\r', 'split');
    lines = strtrim(lines);
    lines = lines(~cellfun(@isempty, lines));

    i = 1;
    n = numel(lines);

    while i <= n
        line = lines{i};

        if ~isempty(line) && ismember(line(1), ['%', '>', '<', '=', '['])
            i = i + 1;
            continue;
        end

        idx = strfind(line, ':');
        if ~isempty(idx)
            key = strtrim(line(1:idx(1)-1));
            value = strtrim(line(idx(1)+1:end));
            meta(key) = value;
            i = i + 1;
        else
            if i + 1 <= n
                nextLine = lines{i+1};
                if isempty(nextLine) || ismember(nextLine(1), ['%', '>', '<', '=', '['])
                    i = i + 1;
                else
                    meta(line) = nextLine;
                    i = i + 2;
                end
            else
                i = i + 1;
            end
        end
    end
end


function info = extract_important_fields(meta)
%EXTRACT_IMPORTANT_FIELDS Extract numeric information from metadata map

    info = struct();

    info.FileName = getOr(meta, "FileName", "");
    info.Comment = getOr(meta, "Comment", "");
    info.MeasurementDate = getOr(meta, "MeasurementDate", "");
    info.wavelength_LP1 = str2double(getOr(meta, "wavelength_LP1", "NaN"));
    info.GDD1 = str2double(getOr(meta, "GDD1", "NaN"));
    info.Dia1 = str2double(getOr(meta, "Dia1", "NaN"));

    frameRateStr = getOr(meta, "Frame rate", "NaN");
    parts = strsplit(strtrim(frameRateStr));
    info.frame_rate_Hz = str2double(parts{1});

    info.AO = str2double(getOr(meta, "AO", "NaN"));
    info.UG = str2double(getOr(meta, "UG", "NaN"));

    pixelStr = getOr(meta, "Pixel size", "");
    nums = regexp(pixelStr, '[\d\.]+', 'match');
    info.pixel_size_um = cellfun(@str2double, nums);

    scanStr = getOr(meta, "Scanning area", "");
    nums = regexp(scanStr, '[\d\.]+', 'match');
    info.scanning_area_um = cellfun(@str2double, nums);

    durStr = getOr(meta, "Duration", "");
    nums = regexp(durStr, '[\d\.]+', 'match');
    vals = cellfun(@str2double, nums);
    vals = fliplr(vals);
    duration_s = 0;
    for i = 1:numel(vals)
        duration_s = duration_s + vals(i) * 60^(i-1);
    end
    info.duration_s = duration_s;

    dimStr = getOr(meta, "Dimensions", "");
    nums = regexp(dimStr, '\d+', 'match');
    info.dimensions = cellfun(@str2double, nums);
end


function val = getOr(meta, key, defaultVal)
%GETOR Get key from containers.Map or return default
    if isKey(meta, key)
        val = meta(key);
    else
        val = defaultVal;
    end
end
