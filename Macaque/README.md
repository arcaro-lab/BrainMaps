# Image Registration Script

This script performs nonlinear image registration to align a functional retinotopy map to a subject-specific T1-weighted anatomical MRI. It uses AFNI, FSL, and ANTs tools. The script downscales the anatomical images to match the functional resolution and applies a combination of FLIRT and ANTs transformations.
 
Within Retinotopy, there is an example for aligning the retinotopy maps from NMT to a target image (registerRetino.sh).


## Usage

```
./registerRetino.sh <target_image> [<moving_image>] [<functional_map>]
```

- `<target_image>`: Path to the subject’s T1-weighted anatomical image (default: MPRAGE_SS.nii.gz).
- `<moving_image>`: Path to the template image the functional map is aligned to (default: NMT_v2.0_sym_SS.nii.gz).
- `<functional_map>`: Path to the functional retinotopy map in template space (default: AvgRetino_NMT2.0sym.nii.gz).

Output Summary

The script creates the following key outputs:
- AvgRetino_syn2fixed.nii.gz: The functional map transformed into the subject’s anatomical space.
- Intermediate steps are saved in step1 through step5 subdirectories for debugging or inspection.


## Steps

1. **Downsample Images**: The script downscales both the moving and target images to match the resolution of the functional map (1x1x1 mm).

    ```
    3dresample -dxyz $functional_resolution -prefix step1/downsampled_target.nii.gz -input $TARGET_IMAGE
    3dresample -dxyz $functional_resolution -prefix step1/downsampled_moving.nii.gz -input $MOVING_IMAGE
    ```

    From here on out, fixed and moving are the downsampled versions:

    ```
    FIXED="step1/downsampled_target.nii.gz"
    MOVING="step1/downsampled_moving.nii.gz"
    ```

2. **FLIRT Registration**: The script uses `flirt` to register the moving image to the fixed (target) image.

    ```
    flirt -in $MOVING \
    -ref $FIXED \
    -out step2/moving_flirt2fixed.nii.gz \
    -omat step2/moving_flirt2fixed.mat \
    -bins 256 -cost corratio \
    -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -dof 6 \
    -interp trilinear
    ```

3. **ANTS Registration**: The script runs `antsRegistration` to register the flirted moving image to the fixed image.

    ```
    antsRegistrationSyN.sh -f $FIXED \
    -m step2/moving_flirt2fixed.nii.gz \
    -d 3 -o step3/moving_syn2fixed -n 4
    ```

4. **Resample Functional Map**: The script resamples the functional map to the moving image.

    ```
    3dresample -master $MOVING -prefix step4/resampled_functional_map.nii.gz -input $FUNCTIONAL_MAP
    ```

5. **FLIRT Transform**: The script applies the flirt transform to the resampled functional map using nearest neighbor interpolation.

    ```
    flirt -in step4/resampled_functional_map.nii.gz \
    -applyxfm \
    -init step2/moving_flirt2fixed.mat \
    -out step5/functional_map_flirt2moving.nii.gz \
    -paddingsize 0.0 -interp nearestneighbour \
    -ref $FIXED
    ```

6. **ANTS Transform**: The script applies the ANTs transform to the functional map post-flirt transform.

    ```
    antsApplyTransforms \
    -e 3 \
    --interpolation NearestNeighbor \
    -i step5/functional_map_flirt2moving.nii.gz \
    -r $FIXED \
    -t step3/moving_syn2fixed1Warp.nii.gz \
    -t step3/moving_syn2fixed0GenericAffine.mat \
    -o functional_map_syn2fixed.nii.gz
    ```

7. **Copy Attributes**: The script copies attributes from the original dataset.

    ```
    3drefit -copyaux $FUNCTIONAL_MAP functional_map_syn2fixed.nii.gz
    ```
