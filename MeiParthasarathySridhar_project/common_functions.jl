##################################################
# Please include all the common packages here :) #
##################################################

using Images, DataFrames, FixedPointNumbers, PyPlot, Colors, ProgressMeter
using Interact, Reactive, DataStructures
using JuMP, Clp, Mosek

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

# function to scale one basis image to the desired size
function scale_image(image,desired_size)
    n_combine = div(size(image, 1), desired_size[1])
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

# downscale image by a factor
function downscale_image(image, factor)
    if factor == 1
        return image
    else
        desired_height = div(size(image,1), factor)
        desired_width = div(size(image,2), factor)
        desired_size = (desired_width, desired_height)
        
        return scale_image(image, desired_size)
    end
end

# find the dominant channel for an image
function find_channel(image)
    ch = 0    
    max = -1
    avgc = 0
    for c in 1:3
        avgc = mean(image[:,:,c])
        if (avgc > max)
        max = avgc
        ch = c
        end
    end
    return ch
end

# split the basis image array to 3 different basis sets based on the dominant channel
function split_channel(images_mat,images_r,images_g,images_b)
    cnt = zeros(Int64, 3)
    for (image_n, image) in enumerate(images_mat)
        c=find_channel(image)
        cnt[c] = cnt[c]+1
        if (c==1)
            images_r[cnt[c]]=copy(image)
        elseif (c==2)
            images_g[cnt[c]]=copy(image)
        else
            images_b[cnt[c]]=copy(image)
        end
    end
    return cnt
end

# convert rgb image to grayscaled image
function rgb2gray(images)
    images_gray_mat = cell(length(images),1)
    for (image_n, image) in enumerate(images)
        image_gray = convert(Image{Gray{Ufixed8}}, image)
        image_mat = reinterpret(UInt8, separate(image_gray).data)
        image_gray_mat=rand(UInt8, size(image_mat,1), size(image_mat,2),3)
        image_gray_mat[:,:,1]= image_mat[:,:,1]
        image_gray_mat[:,:,2]= image_mat[:,:,1]
        image_gray_mat[:,:,3]= image_mat[:,:,1]      
        images_gray_mat[image_n] = image_gray_mat
    end
    return images_gray_mat
end

# scale a grayscale image
function scale_gray_image(image,desired_size)
     n_combine = 64/desired_size[1]
    n_pixel = n_combine*n_combine
    temp=image[1:desired_size[2], 1:desired_size[1], :]
    for i in 1:desired_size[2]
        for j in 1:desired_size[1]
            sub = image[(i-1)*n_combine+(1:n_combine),(j-1)*n_combine+(1:n_combine),:]
            
            pixel=convert(UInt8,round(sum(sum(sub[:,:,1]))/n_pixel))
            temp[i,j,1]=pixel
            end
        end
    temp[:,:,2]=temp[:,:,1]
    temp[:,:,3]=temp[:,:,1]
    return temp
end

# scale an array of grayscale images
function scale_cellarray_gray_mats(images_mat, desired_size)
    for (image_n, image) in enumerate(images_mat)
        images_mat[image_n] = scale_gray_image(image,desired_size)
    end
    return images_mat
end

# convert the image type to Int64 for easy calculation of image histogram
function convert_image_mat_to_Int64(image_mat)
    image_mat1=rand(Int64,size(image_mat,1),size(image_mat,2),size(image_mat,3))
    for i in 1:size(image_mat,1)
        for j in 1:size(image_mat,2)
            for k in 1:size(image_mat,3)
                image_mat1[i,j,k]=convert(Int64, image_mat[i,j,k])
            end
        end
    end
    
    return image_mat1
end

; # suppress output
