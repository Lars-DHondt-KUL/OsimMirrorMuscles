function [varargout] = mirrorName(original_name, optional_inputs)
% --------------------------------------------------------------------------
% mirrorName
%   This functions creates the name of the mirrored element (joint, muscle,
%   etc.) based on the input. 
%   Examples:
%       ans1 = mirrorName('Soleus_r') 
%           ans1 = 'Soleus_l'
%
%       [ans1, ans2] = mirrorName('Right_knee')
%           ans1 = 'Left_knee'
%           ans2 = 'Right_knee' 
%
% INPUT:
%   - original_name - 
%   * name of the left or right side.(char or string)
%
%   - optional_inputs -
%   * prefix/suffix_left/right: cell array with prefixes/suffixes to
%   identify the left/right side. (cell array of char or string)
%
% OUTPUT:
%   - mirrored_name (if 1 output argument) -
%   * name of the right or left side, based on given input (char)
%
%   - [left_name, right_name] (if 2 output arguments) -
%   * name of the left and right side, based on given input (char)
%
% 
% Original author: Lars D'Hondt
% Original date: 15 February 2024
% --------------------------------------------------------------------------
arguments
    original_name char
    optional_inputs.suffix_left {mustBeNonzeroLengthText} = {'_l','_L','_left','_Left'};
    optional_inputs.suffix_right {mustBeNonzeroLengthText} = {'_r','_R','_right','_Right'};
    optional_inputs.prefix_left {mustBeNonzeroLengthText} = {'l_','L_','left_','Left_'};
    optional_inputs.prefix_right {mustBeNonzeroLengthText} = {'r_','R_','right_','Right_'};

end

% cast prefixes and suffixes to cell arrays of character vectors
for s=["suffix_left","suffix_right","prefix_left","prefix_right"]
    if ~iscell(optional_inputs.(s))
        optional_inputs.(s) = {optional_inputs.(s)};
    end
    optional_inputs.(s) = cellfun(@(s)char(s),optional_inputs.(s),'UniformOutput',false);
end

original_name = char(original_name);

suffixA = [optional_inputs.suffix_left, optional_inputs.suffix_right];
suffixB = [optional_inputs.suffix_right, optional_inputs.suffix_left];

prefixA = [optional_inputs.prefix_left, optional_inputs.prefix_right];
prefixB = [optional_inputs.prefix_right, optional_inputs.prefix_left];

%%
mirrored_name = original_name;
left_name = [];
right_name = [];


%% Find mirrored name
% suffix
for i=1:length(suffixA)
    nA = length(char(suffixA{i}));
    if length(original_name)>nA && strcmp(original_name(end-nA+1:end),suffixA{i})
        mirrored_name = [original_name(1:end-nA),suffixB{i}];

        if i<=length(optional_inputs.suffix_left)
            left_name = original_name;
            right_name = mirrored_name;
        else
            left_name = mirrored_name;
            right_name = original_name;
        end
    end
end

% prefix
for i=1:length(prefixA)
    nA = length(prefixA{i});
    if length(original_name)>nA && strcmp(original_name(1:nA),prefixA{i})
        mirrored_name = [prefixB{i}, original_name(nA+1:end)];

        if i<=length(optional_inputs.suffix_left)
            left_name = original_name;
            right_name = mirrored_name;
        else
            left_name = mirrored_name;
            right_name = original_name;
        end
    end
end


%% return output
if nargout == 1
    varargout{1} = mirrored_name;

elseif nargout == 2
    varargout{1} = left_name;
    varargout{2} = right_name;
end


end % end of function