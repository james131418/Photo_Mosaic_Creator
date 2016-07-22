%   Photomosaic creates a photographic mosiac image
%   To choose a target image and a directory of tiling images
clear all; clc;
%   Mosaic Parameters, Number of tiles spanning width of img
tile_ratio = 100;
%   Default processed tiles backup directory (only if saving tiles)
tile_dir = strcat(pwd, filesep, 'Tiles');
%   Coefficient for scaling of output tiles
output_scale = 2;
%   Output file name
output_file_name = 'Mosaic.jpg';
%   Dithering distance
dval = 1;

%   List of file types
file_types = {['*.BMP;*.GIF;*.HDF;*.JPEG;*.JPG;*.PBM;*.PCX;*.PGM;',...
    '*.PNG;*.PNM;*.PPM;*.RAS;*.TIFF;*.TIF;*.XWD']};
comp_file_types = {'BMP' 'GIF' 'HDF' 'JPEG' 'JPG' 'PBM' 'PCX' 'PGM' ...
    'PNG' 'PNM' 'PPM' 'RAS' 'TIFF' 'TIF' 'XWD'};

%% Choose target image and directory of tiling images
img_target = uigetfile(file_types, ...
    'Please choose the target mosiac image');
img_dir = uigetdir(pwd,'Please select the archive of tiling images');

%   Get original img size
ref_img = imread(img_target);
img_size = size(ref_img);
img_size = img_size(1:2);

%%  Calc values
%   Set size for tilenail based on original size
tile_pixels = floor(img_size(1)/tile_ratio);
tile_size = [tile_pixels tile_pixels];
%Make sure h/w are proportional to tile size
new_height = floor(img_size(2)/tile_pixels);
num_tiles = [tile_ratio new_height];
new_size = [tile_ratio new_height].*tile_pixels;
ref_img = imresize(ref_img, new_size);

%% Get all directory images
dir_files = dir(img_dir);
mosaic_ind = 1;
%   For each image add it to array
for dir_ind = 1:length(dir_files)
    if ~dir_files(dir_ind).isdir
        file_name = dir_files(dir_ind).name;
        %  Check file extension
        [~, ~, ext] = fileparts(file_name);
        if max(strcmpi(ext(2:end), comp_file_types))
            mosaic_files{mosaic_ind} = file_name;
            mosaic_ind = mosaic_ind+1;
        end
    end
end

%% Resize  archive images into tiles directory
progress = waitbar(0, 'Creating Mosaic tilenails...');
num_files = length(mosaic_files);
mosaic_imgs = cell(1, num_files);
%   mkdir(tile_dir);
if ~exist(tile_dir, 'dir')
   mkdir(tile_dir);
end
%   Resize each image
for mosaic_ind = 1:num_files
    img = imread([img_dir, filesep, mosaic_files{mosaic_ind}]);
    % if read in grayscale img
    if size(img, 3) == 1
        img = ind2rgb(img, gray(256));
    end
    res_img = uint8(imresize(img, tile_size*output_scale));
    tiles{mosaic_ind} = res_img;
    imwrite(res_img, [tile_dir, filesep, strcat(num2str(mosaic_ind),'.jpg')], 'jpg');
    waitbar(mosaic_ind/num_files, progress);
end
close(progress);

%% Calculating the  averages of RGB in tile directory
progress = waitbar(0, 'Calculating tilenail Averages...');
for mosaic_ind = 1:num_files
    % calc average vals for tiles
    cur_tile = tiles{mosaic_ind};
    RGB_vals{mosaic_ind} = mean(reshape(cur_tile, [], 3), 1);
    waitbar(mosaic_ind/num_files, progress);
end
close(progress);

%% Find closest matching tile for each tile of image 
progress = waitbar(0, 'Creating Photomosaic...');
pic_map = zeros(num_tiles);
tiles_done = 0;
for row_tile = 1:num_tiles(1)
    for col_tile = 1:num_tiles(2)
        shortest_dist = 1000;
        % get mean vals for the image tiles
        cur_tile = ref_img(tile_pixels*(row_tile-1)+1:tile_pixels*(row_tile), ...
        tile_pixels*(col_tile-1)+1:tile_pixels*(col_tile),:);
        cur_RGB = mean(reshape(cur_tile, [], 3), 1);
        % find the closest tile to each tile
        for tile_tile = 1:num_files
            dist = sqrt(sum((RGB_vals{tile_tile}-cur_RGB).^2));
            % if new pt is closer
            if dist < shortest_dist
                % implement dithering to limit use of tile in an area
                if isempty(find( pic_map(max(row_tile-dval,1): ...
                                 min(row_tile+dval,num_tiles(1)),... 
                                 max(col_tile-dval,1): ...
                                 min(col_tile+dval,num_tiles(2))) ... 
                                 == tile_tile, 1))
                    shortest_dist = dist;
                    pic_map(row_tile, col_tile) = tile_tile;
                end
            end
        end
        tiles_done = tiles_done + 1;
        waitbar(tiles_done/(num_tiles(1)*num_tiles(2)), progress);
    end
end
close(progress);

%% Take mapping of tilenails and create photomosaic
progress = waitbar(0, 'Assembling Photomosaic...');
for row_tile = 1:num_tiles(1)
    cur_row = tiles{pic_map(row_tile, 1)};
    for col_tile = 2:num_tiles(2)
        cur_row = horzcat(cur_row, tiles{pic_map(row_tile, col_tile)});
        % Horizontally concatenate tiles
    end
    if row_tile == 1
        mosaic = cur_row;
    else
        mosaic = vertcat(mosaic, cur_row);
        % Vertically concatenate tiles 
        clear cur_row;
    end
    waitbar(row_tile/num_tiles(1), progress);
end
close(progress);
imwrite(mosaic, output_file_name, 'jpg');

figure; 
imagesc(mosaic); axis off;
figure;
imagesc(ref_img); axis off;