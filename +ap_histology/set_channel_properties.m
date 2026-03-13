function set_channel_properties(~,~,histology_gui)
% Part of AP_histology toolbox 
%
% Set channel properties

% Get histology toolbar data
histology_guidata = guidata(histology_gui);

% Set number of channels
n_channels = size(histology_guidata.data{1},3);

% Create editable properties box
channel_properties_fig = uifigure('Name','Set channel properties');
channel_properties_grid = uigridlayout(channel_properties_fig,[2,2]);
channel_properties_grid.RowHeight = {'7x','1x'};

% Set available colors
[colors_rgb,colors_name] = set_colors;

% Get names for current colors
[~,channel_color_idx] = ismember(histology_guidata.channel_colors,colors_rgb,'rows');
channel_colors = colors_name(channel_color_idx);

channel_properties = table(categorical(channel_colors,colors_name), ...
    histology_guidata.channel_visibility,'VariableNames',{'Color','Visible'});

channel_properties_table = uitable(channel_properties_grid, ...
    'ColumnEditable',[true,true], ...
    'RowName',arrayfun(@(x) sprintf('Channel %d',x),1:n_channels,'uni',false), ...
    'Data',channel_properties);

channel_properties_table.Layout.Column = [1,size(channel_properties,2)];
channel_properties_table.DisplayDataChangedFcn = @(obj,event) set_color_row(obj,event);

% Add save/cancel buttons
uibutton(channel_properties_grid,'push', ...
    'Text','Save','ButtonPushedFcn', ...
    {@channel_properties_save,histology_gui,channel_properties_table});
uibutton(channel_properties_grid,'push', ...
    'Text','Cancel','ButtonPushedFcn',@channel_properties_cancel);

% Set initial colors
set_color_row(channel_properties_table);

end

function set_color_row(channel_properties_table,event)
% Set row of table to channel color
[colors_rgb,colors_name] = set_colors;
[~,color_idx] = ismember(channel_properties_table.Data.Color,colors_name);
channel_properties_table.BackgroundColor = colors_rgb(color_idx,:);
end

function [colors_rgb,colors_name] = set_colors
% Set all available colors with names
colors_rgb = table2array(combinations(0:1,0:1,0:1));
colors_rgb = colors_rgb(any(colors_rgb,2),:);
colors_name = {'B';'G';'C';'R';'M';'Y';'W'};
end

function channel_properties_save(obj,event,histology_gui,channel_properties_table)
% Save: update main GUI data

% Grab channel colors
[colors_rgb,colors_name] = set_colors;
[~,color_idx] = ismember(channel_properties_table.Data.Color,colors_name);
channel_colors = colors_rgb(color_idx,:);

% Set color and visibility in histology gui data 
histology_guidata = guidata(histology_gui);
histology_guidata.channel_colors = channel_colors;
histology_guidata.channel_visibility = channel_properties_table.Data.Visible;

% Update histology guidata
guidata(histology_gui,histology_guidata);

% Update histology image
histology_guidata.update([],[],histology_gui);

% Close properties box
close(obj.Parent.Parent);
end

function channel_properties_cancel(obj,event)
% Cancel: close without saving
close(obj.Parent.Parent);
end


