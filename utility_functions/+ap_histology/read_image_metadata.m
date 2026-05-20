function image_metadata = read_image_metadata(im_filename)

im_info = imfinfo(im_filename);

if isfield(im_info(1),'ImageDescription') && ...
        contains(im_info(1).ImageDescription,'SMZ')
    % Nikon SMZ - taken with NIS-Elements

    image_metadata = struct;

    plane_info = split(erase(cell2mat(extractBetween(im_info(1).ImageDescription, ...
        'Plane #','</Value>','Boundaries','inclusive')),'</Value>'), ...
        'Plane #'+digitsPattern+':'+whitespacePattern);
    plane_info = plane_info(~cellfun(@isempty,plane_info));

    image_metadata.plane_filters = string(cellfun(@(x) extractBetween(x, ...
        'FilterChanger(Turret):'+whitespacePattern+digitsPattern+whitespacePattern+'(',')'),plane_info,'uni',false));
    image_metadata.plane_brightfield = cellfun(@(x) contains(x,'LED'),plane_info);
else
    % Anything else: return empty
    image_metadata = [];
end