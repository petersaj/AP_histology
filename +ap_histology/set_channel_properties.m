
function set_channel_properties

% Create editable properties box
channel_properties_fig = uifigure('Name','Set channel properties');
channel_properties_grid = uigridlayout(channel_properties_fig,[2,2]);
channel_properties_grid.RowHeight = {'7x','1x'};


[colors_rgb,colors_name] = set_colors;

n_channels = 3;


channel_colors = {'W','R','G'}';
channel_visible = true(n_channels,1);

channel_properties = table(categorical(channel_colors,colors_name), ...
    channel_visible,'VariableNames',{'Color','Visible'});

channel_properties_table = uitable(channel_properties_grid, ...
    'ColumnEditable',[true,true], ...
    'RowName',arrayfun(@(x) sprintf('Channel %d',x),1:n_channels,'uni',false), ...
    'Data',channel_properties);

channel_properties_table.Layout.Column = [1,size(channel_properties,2)];
channel_properties_table.DisplayDataChangedFcn = @(obj,event) set_color_row(obj,event);


% Add save/cancel buttons
uibutton(channel_properties_grid,'push', ...
    'Text','Save','ButtonPushedFcn',{@set_probe_recording_slot_save,probe_atlas_gui});
uibutton(channel_properties_grid,'push', ...
    'Text','Cancel','ButtonPushedFcn',@set_probe_recording_slot_cancel);

% Set initial colors
set_color_row(channel_properties_table);

end


function set_color_row(channel_properties_table,event)

[colors_rgb,colors_name] = set_colors;
[~,color_idx] = ismember(channel_properties_table.Data.Color,colors_name);
channel_properties_table.BackgroundColor = colors_rgb(color_idx,:);

end

function [colors_rgb,colors_name] = set_colors

colors_rgb = table2array(combinations(0:1,0:1,0:1));
colors_rgb = colors_rgb(any(colors_rgb,2),:);
colors_name = {'B','G','C','R','M','Y','W'};

end