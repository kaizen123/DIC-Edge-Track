function find_bright_edge(folder,varargin)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%Setup variables and parse command line
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
i_p = inputParser;
i_p.FunctionName = 'find_bright_edge';

i_p.addRequired('folder',@(x)isdir(x));

i_p.addParameter('COV_thresh',0.018,@(x)isnumeric(x));
i_p.addParameter('debug',0,@(x)x == 1);

i_p.parse(folder,varargin{:});

addpath(genpath('image_processing_misc'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%Main Program
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

files = dir(fullfile(folder,'*.tif'));

vis_folder = fullfile(folder,'..','edge_vis');
mkdir_no_err(vis_folder);

cell_mask_folder = fullfile(folder,'..','cell_mask');
mkdir_no_err(cell_mask_folder);

for i = 1:length(files);
    base = imread(fullfile(folder,files(i).name));
    base_norm = normalize_image(base);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Calculate filtered images to conduct segmentation
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    std_filt = stdfilt(base,getnhood(strel('disk',15)));
    
    I_filt = fspecial('disk',15);
    mean_filt = imfilter(base,I_filt,'replicate');
    
    cov_image = double(std_filt) ./ double(mean_filt);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Segment and clean the image
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    cell_mask = cov_image > i_p.Results.COV_thresh;
    
    %Pick out the largest object, we will assume it is the cell region.
    %Then fill in any holes missed by the COV filter.
    cell_mask = filter_to_largest_object(cell_mask);
    cell_mask = imfill(cell_mask,'holes');
    
    %The fairly large search region used for in stdfilt has a tendency to
    %expand the boundary around the cells. This will remove that 15 pixel
    %boundary and then re-filter to pick out the largest object
    cell_mask = imerode(cell_mask,strel('disk',15));
    cell_mask = filter_to_largest_object(cell_mask);

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %Visualization and Output
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    png_output_file = regexprep(files(i).name,'.tif','.png');
    imwrite(cell_mask,...
        fullfile(cell_mask_folder,png_output_file));
    
    visualization = create_highlighted_image(base_norm,...
        thicken_perimeter(bwperim(cell_mask),3),...
        'mix_percent',0.5);
    visualization = imresize(visualization,0.5);
    
    imwrite(visualization,...
        fullfile(vis_folder,png_output_file));
end
