# HidroSense Lettuce Pests Dataset Provenance

- **Generated (UTC)**: `2026-11-22T05:53:06Z`
- **Zero Synthetic Confirmed**: `True` (`synthetic_images_count = 0`)
- **Canonical Classes**: `0: thrips`, `1: whitefly`, `2: aphids`
- **Split Config**: `train=0.8`, `val=0.1`, `test=0.1`, `seed=42`, `phash_hamming_threshold=2`, `group_hamming_threshold=4`, `group_aware_split=True`

## Roboflow Sources Probed & Downloaded

| Workspace / Project | Version | Required | Status | HTTP / Error | Raw Split Images | Raw Classes |
|---|---:|---|---|---|---|---|
| `puzzle-piece-detection/lettuce-pests` | 6 | True | `cached` | 200 | train:1584, valid:155, test:77 | 0:aphid, 1:whitefly |
| `puzzle-piece-detection/lettuce-pest-detection` | 1 | True | `cached` | 200 | train:1396, valid:397, test:200 | 0:thrips |
| `agrivision-2025/lettuce-pests-wieje` | 1 | False | `cached` | 200 | train:1584, valid:155, test:77 | 0:aphid, 1:whitefly |

## Class Mapping & Deduplication Summary

- **Total images scanned**: 5625
- **Exact SHA-256 duplicates removed**: 560
- **8-dihedral perceptual hash (Hamming <= 2) duplicates removed**: 773
- **Total duplicates removed**: 1333
- **Dihedral orientations checked**: 8
- **Group Hamming threshold**: 4
- **Connected component groups formed**: 450
- **Roboflow base stems grouped**: 677
- **Empty or unmapped images skipped**: 2716
- **Boxes kept**: 35801
- **Boxes dropped (total / unmapped / invalid)**: 1 / 0 / 1

| Source Dir | Scanned | Kept | SHA-256 Dup | pHash Dup | Empty/Unmapped | Boxes Kept | Boxes Dropped (Unmapped / Invalid) |
|---|---:|---:|---:|---:|---:|---:|---|
| `puzzle-piece-detection_lettuce-pests_v6` | 1816 | 692 | 0 | 638 | 486 | 16937 | 0 (0 / 0) |
| `puzzle-piece-detection_lettuce-pest-detection_v1` | 1993 | 228 | 0 | 21 | 1744 | 1006 | 0 (0 / 0) |
| `agrivision-2025_lettuce-pests-wieje_v1` | 1816 | 656 | 560 | 114 | 486 | 17858 | 1 (0 / 1) |

## Final Split Counts & Class Distribution

| Split | Images | Groups | Instances | thrips | whitefly | aphids | Small Obj Ratio | Manifest SHA-256 (prefix) |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `train` | 1245 | 360 | 28562 | 793 | 13709 | 14060 | 0.0786 | `3207c9964925` |
| `val` | 178 | 45 | 4350 | 53 | 2908 | 1389 | 0.0591 | `745ee3abea2a` |
| `test` | 153 | 45 | 2889 | 160 | 1481 | 1248 | 0.0453 | `6b2db33b754a` |
| **Total** | **1576** | **450** | **35801** | **1006** | **18098** | **16697** | - | - |

## Split Integrity & Leakage Verification

- **Status**: `passed`
- **`data.yaml` portable relative paths (`path` omitted)**: `True`
- **Dihedral orientations checked**: `8`
- **Cross-split SHA-256 overlaps**: `0`
- **Cross-split 8-dihedral pHash (<= 2) overlaps**: `0`
- **Cross-split 8-dihedral group pHash (<= 4) overlaps**: `0`
- **Cross-split Roboflow base-stem overlaps**: `0`
- **Intra-split SHA-256 / 8-dihedral pHash duplicates**: `0` / `0`
- **Unpaired files / invalid labels**: `0` / `0`
- **All canonical classes present in every split**: `True`
