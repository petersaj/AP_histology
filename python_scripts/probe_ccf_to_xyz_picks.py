import json
import sys
from pathlib import Path

import numpy as np
from iblatlas.atlas import AllenAtlas

# Requires iblenv conda environment or anything with the ibllib module:
# See: https://github.com/int-brain-lab/iblenv?tab=readme-ov-file#install-from-scratch

probe_scaling_factor_to_um = (
    10  # AP histology uses 10um atlas, so we need to scale the probe coordinates by 10
)
allen_atlas_res_to_use = 25  # IBL atlas gui uses 25 um atlas, not sure it matters
atlas = AllenAtlas(allen_atlas_res_to_use)


def main(tracing_path):
    tracing_path = Path(tracing_path)
    one_shank_pts_files = sorted(list(tracing_path.glob("probe_ccf.points.npy")))
    multi_shank_pts_files = sorted(
        list(tracing_path.glob("probe_ccf.points.shank*.npy"))
    )
    if len(one_shank_pts_files) > 0 and len(multi_shank_pts_files) > 0:
        raise ValueError(
            "Found both single shank ('probe_ccf.points.npy') and\
             multi shank ('probe_ccf.points.shank*.npy') files.\
             Please only provide one type of file."
        )

    pts_files = (
        one_shank_pts_files if len(one_shank_pts_files) > 0 else multi_shank_pts_files
    )
    for iShank, pt_file in enumerate(pts_files):
        # Load in coordinates of track in CCF space (order - apdvml, origin - top, left, front voxel
        xyz_apdvml = np.load(pt_file)
        xyz_apdvml = (xyz_apdvml * probe_scaling_factor_to_um)  # convert from CCF volume coords to microns

        # Convert to IBL space (order - mlapdv, origin - bregma)
        xyz_mlapdv = (atlas.ccf2xyz(xyz_apdvml, ccf_order="apdvml") * 1e6)  # convert output in meters back to microns (lol)
        xyz_picks = {"xyz_picks": xyz_mlapdv.tolist()}

        if len(pts_files) == 1:
            # Path to save the data (same folder as where you have all the data)
            with open(Path(tracing_path.parent, "xyz_picks.json"), "w") as f:
                json.dump(xyz_picks, f, indent=2)
        else:
            shank_idx = iShank + 1  # IBL shank files are 1-indexed
            with open(Path(tracing_path.parent, f"xyz_picks_shank{shank_idx}.json"), "w") as f:
                json.dump(xyz_picks, f, indent=2)


if __name__ == "__main__":
    tracing_path = sys.argv[1]
    main(tracing_path)
