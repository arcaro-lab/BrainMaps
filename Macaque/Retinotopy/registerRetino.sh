#!/bin/bash

# Usage: registerRetino.sh <target_image> [<moving_image>] [<functional_map>]

# Assign input arguments to variables
TARGET_IMAGE=${1:-MPRAGE_SS.nii.gz}
MOVING_IMAGE=${2:-NMT_v2.0_sym_SS.nii.gz}
FUNCTIONAL_MAP=${3:-AvgRetino_NMT2.0sym.nii.gz}

# Define downsampled versions
DOWNSAMPLED_TARGET="downsampled_target.nii.gz"
DOWNSAMPLED_MOVING="downsampled_moving.nii.gz"

# Create directories for intermediate files
mkdir -p step1 step2 step3 step4 step5

# Step 1: Downsample both the moving and fixed images to match the resolution of the functional map (1 1 1 mm)
3dresample -dxyz 1 1 1 -prefix step1/$DOWNSAMPLED_TARGET -input $TARGET_IMAGE
3dresample -dxyz 1 1 1 -prefix step1/$DOWNSAMPLED_MOVING -input $MOVING_IMAGE

# From here on out, fixed and moving are the downsampled versions
FIXED="step1/$DOWNSAMPLED_TARGET"
MOVING="step1/$DOWNSAMPLED_MOVING"

# Step 2: Use flirt to register the moving image to the fixed image
flirt -in $MOVING \
-ref $FIXED \
-out step2/moving_flirt2fixed.nii.gz \
-omat step2/moving_flirt2fixed.mat \
-bins 256 -cost corratio \
-searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 6 \
-interp trilinear

# Step 3: Runs antsRegistration to register the flirted moving image to the fixed image
antsRegistrationSyN.sh -f $FIXED \
-m step2/moving_flirt2fixed.nii.gz \
-d 3 -o step3/moving_syn2fixed -n 4

# Step 4: Resample the functional map to the moving image
3dresample -master $MOVING -prefix step4/AvgRetino_resamp.nii.gz -input $FUNCTIONAL_MAP

# Step 5: Applies the flirt transform to the resampled functional map using NN interpolation
flirt -in step4/AvgRetino_resamp.nii.gz \
-applyxfm \
-init step2/moving_flirt2fixed.mat \
-out step5/AvgRetino_flirt2moving.nii.gz \
-paddingsize 0.0 -interp nearestneighbour \
-ref $FIXED

# Step 6: Applies ANTs transform to the functional map post flirt transform
antsApplyTransforms \
  -e 3 \
  --interpolation NearestNeighbor \
  -i step5/AvgRetino_flirt2moving.nii.gz \
  -r $FIXED \
  -t step3/moving_syn2fixed1Warp.nii.gz \
  -t step3/moving_syn2fixed0GenericAffine.mat \
  -o AvgRetino_syn2fixed.nii.gz

# Step 7: Copy attributes from original dataset
3drefit -copyaux $FUNCTIONAL_MAP AvgRetino_syn2fixed.nii.gz

