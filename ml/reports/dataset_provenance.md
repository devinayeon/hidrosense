# HidroSense Lettuce Pests Dataset Provenance

- **Generated (UTC)**: `2026-11-21T14:57:01Z`
- **Zero Synthetic Confirmed**: `True` (`synthetic_images_count = 0`)
- **Canonical Classes**: `0: thrips`, `1: whitefly`, `2: aphids`
- **Split Config**: `train=0.8`, `val=0.1`, `test=0.1`, `seed=42`, `phash_hamming_threshold=2`

## Roboflow Sources Probed & Downloaded

| Workspace / Project | Version | Required | Status | HTTP / Error | Raw Split Images | Raw Classes |
|---|---:|---|---|---|---|---|
| `puzzle-piece-detection/lettuce-pests` | 6 | True | `cached` | 200 | train:1584, valid:155, test:77 | 0:aphid, 1:whitefly |
| `puzzle-piece-detection/lettuce-pest-detection` | 1 | True | `cached` | 200 | train:1396, valid:397, test:200 | 0:thrips |
| `agrivision-2025/lettuce-pests-wieje` | 1 | False | `cached` | 200 | train:1584, valid:155, test:77 | 0:aphid, 1:whitefly |

## Class Mapping & Deduplication Summary

- **Total images scanned**: 5625
- **Exact SHA-256 duplicates removed**: 518
- **Perceptual hash (Hamming <= 2) duplicates removed**: 284
- **Total duplicates removed**: 802
- **Empty or unmapped images skipped**: 2716
- **Boxes kept**: 52056
- **Boxes dropped (total / unmapped / invalid)**: 1 / 0 / 1

| Source Dir | Scanned | Kept | SHA-256 Dup | pHash Dup | Empty/Unmapped | Boxes Kept | Boxes Dropped (Unmapped / Invalid) |
|---|---:|---:|---:|---:|---:|---:|---|
| `puzzle-piece-detection_lettuce-pests_v6` | 1816 | 1169 | 0 | 161 | 486 | 31439 | 0 (0 / 0) |
| `puzzle-piece-detection_lettuce-pest-detection_v1` | 1993 | 229 | 0 | 20 | 1744 | 1007 | 0 (0 / 0) |
| `agrivision-2025_lettuce-pests-wieje_v1` | 1816 | 709 | 518 | 103 | 486 | 19610 | 1 (0 / 1) |

## Final Split Counts & Class Distribution

| Split | Images | Instances | thrips | whitefly | aphids | Small Obj Ratio | Manifest SHA-256 (prefix) |
|---|---:|---:|---:|---:|---:|---:|---|
| `train` | 1687 | 42273 | 775 | 21097 | 20401 | 0.0788 | `588698047fb5` |
| `val` | 210 | 4748 | 70 | 2416 | 2262 | 0.0539 | `cf51422a780a` |
| `test` | 210 | 5035 | 162 | 2397 | 2476 | 0.1124 | `a22331d111f9` |
| **Total** | **2107** | **52056** | **1007** | **25910** | **25139** | - | - |

## Split Integrity & Leakage Verification

- **Status**: `passed`
- **`data.yaml` portable relative paths (`path` omitted)**: `True`
- **Cross-split SHA-256 overlaps**: `0`
- **Cross-split pHash (<= 2) overlaps**: `0`
- **Intra-split SHA-256 / pHash duplicates**: `0` / `0`
- **Unpaired files / invalid labels**: `0` / `0`
- **All canonical classes present in every split**: `True`
