function annotate_neuropixels_v2(~,~,histology_scroll_gui)
% Part of AP_histology toolbox
%
% Annotate Neuropixels tracts on slices and get CCF positions/regions


%%%%% WORKING
% really strip this down, just figure with buttons like add segment and
% save. 
%
% problem: can't draw on change because this gui not listening to other
% might just have to save each segmentation each time, but then still won't
% update after draw


% Get histology toolbar data
histology_scroll_guidata = guidata(histology_scroll_gui);

figure('color','w','toolBar','none','menubar','none','Name','Neuropixels annotator', ...
    'units','normalized','position', ...
    histology_scroll_gui.Position./[1,1,2,3])

uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0,0,0.5,1],'String','Add probe segment', ...
    'Callback',{@add_probe_segment,histology_toolbar_gui});

uicontrol('style','pushbutton','units','normalized', ...
    'Position',[0.5,0,0.5,1],'String','Save probe', ...
    'Callback',{@save_probe,histology_toolbar_gui});


end


%%% just copied, doesn't work now
function add_segment

        curr_line = imline;
        % If the line is just a click, don't include
        curr_line_length = sqrt(sum(abs(diff(curr_line.getPosition,[],1)).^2));
        if curr_line_length == 0
            return
        end
        gui_data.probe_points_histology{gui_data.curr_slice,curr_probe} = ...
            curr_line.getPosition;
        set(gui_data.histology_ax_title,'String', ...
            {'Arrows: change slice','Number (shift, +10): draw probe X '});

        % Delete movable line, draw line object
        curr_line.delete;
        gui_data.probe_lines(curr_probe) = ...
            line(gui_data.probe_points_histology{gui_data.curr_slice,curr_probe}(:,1), ...
            gui_data.probe_points_histology{gui_data.curr_slice,curr_probe}(:,2), ...
            'linewidth',3,'color',gui_data.probe_color(curr_probe,:));

end




