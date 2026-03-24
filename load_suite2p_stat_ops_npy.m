function [stat_cell, ops_struct] = load_suite2p_stat_ops_npy(stat_path, ops_path)
%LOAD_SUITE2P_STAT_OPS_NPY Load suite2p stat.npy and ops.npy into MATLAB types.
%
%   [stat_cell, ops_struct] = LOAD_SUITE2P_STAT_OPS_NPY(stat_path, ops_path)
%
%   stat.npy  -> 1 x n cell array; each cell is a struct (one ROI dict).
%   ops.npy   -> struct (ops dictionary).
%
%   Requires MATLAB Python interface + NumPy (same env you use for suite2p).
%   readNPY cannot load these files (object / pickled dtypes).

    stat_cell = {};
    ops_struct = struct();

    try
        py.importlib.import_module('numpy');
    catch
        warning('load_suite2p_stat_ops_npy:PythonNumPy', ...
            'NumPy not available in MATLAB''s Python environment; stat.npy/ops.npy not loaded. Configure pyenv with Python that has numpy.');
        return;
    end

    np = py.importlib.import_module('numpy');

    if nargin >= 1 && ~isempty(stat_path) && exist(stat_path, 'file')
        try
            stat_cell = load_stat_npy_impl(np, stat_path);
        catch ME
            warning('load_suite2p_stat_ops_npy:stat', 'Failed to load stat.npy: %s', ME.message);
            stat_cell = {};
        end
    end

    if nargin >= 2 && ~isempty(ops_path) && exist(ops_path, 'file')
        try
            ops_struct = load_ops_npy_impl(np, ops_path);
        catch ME
            warning('load_suite2p_stat_ops_npy:ops', 'Failed to load ops.npy: %s', ME.message);
            ops_struct = struct();
        end
    end
end

%% -------------------------------------------------------------------------
function cellOut = load_stat_npy_impl(np, stat_path)
    a = np.load(stat_path, pyargs('allow_pickle', true));
    nd = double(a.ndim);
    item_a = py.getattr(a, 'item');
    if nd == 0
        cellOut = {py_to_matlab(item_a())};
        return;
    end
    % 1 x n cell: ravel so (n,), (n,1), (1,n) all become n ROI dicts
    flat = np.ravel(a);
    item_f = py.getattr(flat, 'item');
    n = double(py.len(flat));
    cellOut = cell(1, n);
    for k = 1:n
        cellOut{k} = py_to_matlab(item_f(int32(k - 1)));
    end
end

function s = load_ops_npy_impl(np, ops_path)
    a = np.load(ops_path, pyargs('allow_pickle', true));
    nd = double(a.ndim);
    item_fn = py.getattr(a, 'item');
    if nd == 0
        d = item_fn();
    else
        d = item_fn(int32(0));
    end
    s = py_to_matlab(d);
    if ~isstruct(s)
        s = struct('value', s);
    end
end

function x = py_to_matlab(obj)
    if isempty(obj) || (isa(obj, 'py.NoneType'))
        x = [];
        return;
    end

    if isa(obj, 'py.dict')
        keys_py = py.list(obj.keys());
        nk = double(py.len(keys_py));
        x = struct();
        for ii = 1:nk
            key = char(keys_py{ii});
            safeKey = matlab.lang.makeValidName(key, 'ReplacementStyle', 'underscore');
            if isempty(safeKey)
                safeKey = sprintf('key_%d', ii);
            end
            val = obj{key};
            x.(safeKey) = py_to_matlab(val);
        end
        return;
    end

    if isa(obj, 'py.list') || isa(obj, 'py.tuple')
        n = double(py.len(obj));
        x = cell(1, n);
        for ii = 1:n
            x{ii} = py_to_matlab(obj{ii});
        end
        return;
    end

    if isa(obj, 'py.numpy.ndarray')
        try
            x = double(obj);
        catch
            try
                x = logical(obj);
            catch
                % Object or unsupported dtype: try element-wise (small arrays only)
                sh = cell(obj.shape);
                n = prod(cellfun(@double, sh));
                if n <= 4096 && numel(sh) == 1
                    x = cell(1, n);
                    for ii = 1:n
                        x{ii} = py_to_matlab(obj.item(int32(ii - 1)));
                    end
                else
                    x = [];
                end
            end
        end
        return;
    end

    if isa(obj, 'py.str')
        x = char(obj);
        return;
    end

    if isa(obj, 'py.bytes')
        x = char(obj);
        return;
    end

    if isa(obj, 'py.bool')
        x = logical(double(obj));
        return;
    end

    if isa(obj, 'py.int') || isa(obj, 'py.float')
        x = double(obj);
        return;
    end

    if isa(obj, 'py.complex')
        x = double(obj.real) + 1i * double(obj.imag);
        return;
    end

    try
        x = char(obj);
    catch
        try
            x = double(obj);
        catch
            x = [];
        end
    end
end
