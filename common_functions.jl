##################################################
# Please include all the common packages here :) #
##################################################

using Images, DataFrames, FixedPointNumbers, PyPlot, Colors, ProgressMeter

# loads all jpg image files inside the directory
function get_image_files(image_dir)
    # get all the files in the directory
    dir_contents = readdir(image_dir)
    dir_contents = [ join([image_dir, dir_contents[i]], "/") for i in 1:length(dir_contents) ]
    
    # retain only jpg image files
    image_files = filter(x->ismatch(r"(.jpg$)|(.jpeg$)"i, x), dir_contents)
    
    # return the paths to the jpg image files
    return image_files
end

# converts image to a h x w matrix
#   h = height
#   w = width
function convert_image_to_mat(image)
    image_mat = reinterpret(UInt8, separate(image).data)
    return image_mat
end

# converts a h x w matrix to an Images module image
function convert_mat_to_image(image_mat)
    image = colorim(image_mat)
    return image
end

# load a list of image files as a cell array of image matrices
function load_images_as_cellarray_mats(image_files)
    images_mat = cell(length(image_files),1)
    for (image_n, image_file) in enumerate(image_files)
        image = load(image_file)
        image_mat = convert_image_to_mat(image)
        
        # fix for RGB4 seen on Mac because of ImageMagick behavior
        #  read only RGB (ignore the 4th value)
        image_mat = image_mat[:,:,1:3]
        
        images_mat[image_n] = image_mat
    end
    return images_mat
end

# convert a cell array of image matrices to a cell array of images
function load_cellarray_mats_as_images(images_mat)
    images = cell(length(images_mat),1)
    for (image_n, image_mat) in enumerate(images_mat)
        image = convert_mat_to_image(image_mat)
        images[image_n] = image
    end
    return images
end

# silly way to make all images the same size
function subsample_cellarray_mats(images_mat, desired_size)
    for (image_n, image) in enumerate(images_mat)
        images_mat[image_n] = image[1:desired_size[2], 1:desired_size[1], :]
    end
    return images_mat
end

# function to scale one basis image to the desired size
function scale_image(image,desired_size)
    n_combine = floor( size(image, 1)/desired_size[1] )
    n_pixel = n_combine*n_combine
    temp=image[1:desired_size[2], 1:desired_size[1], :]
    for i in 1:desired_size[2]
        for j in 1:desired_size[1]
            sub = image[(i-1)*n_combine+(1:n_combine),(j-1)*n_combine+(1:n_combine),:]
            for c in 1:3
                pixel=convert(UInt8,round(sum(sum(sub[:,:,c]))/n_pixel))
                temp[i,j,c]=pixel
            end
        end
    end
    return temp
end

# scale the whole base array
function scale_cellarray_mats(images_mat, desired_size)
    for (image_n, image) in enumerate(images_mat)
            images_mat[image_n] = scale_image(image,desired_size)
    end
    return images_mat
end

; # suppress output
