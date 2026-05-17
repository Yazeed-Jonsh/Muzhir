from __future__ import annotations

import json
from dataclasses import dataclass, asdict
from pathlib import Path

from ultralytics import YOLO


ROOT = Path(r"D:\2026 F2\CPCS499\Muzhir")
DATASET_IMAGES = Path(r"D:\2026 F2\CPCS499\Dataset\dataset\test\images")
DATASET_LABELS = Path(r"D:\2026 F2\CPCS499\Dataset\dataset\test\labels")

MODELS = {
    "fp16_tflite": ROOT / "mobile_app/assets/models/muzhir_fp16.tflite",
    "onnx_backend": ROOT / "backend/assets/best.onnx",
}

IMGSZ = 640
PREDICT_CONF = 0.001
APP_CONF = 0.25
REPEATS = 2


def gt_classes(image: Path) -> set[int]:
    label_file = DATASET_LABELS / f"{image.stem}.txt"
    if not label_file.exists():
        return set()
    classes: set[int] = set()
    for line in label_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        classes.add(int(float(line.split()[0])))
    return classes


def top_pred(result) -> tuple[int | None, float]:
    if result.boxes is None or len(result.boxes) == 0:
        return None, 0.0
    box = result.boxes[0]
    return int(box.cls.item()), float(box.conf.item())


@dataclass
class Summary:
    total_images: int = 0
    labeled_images: int = 0
    unlabeled_images: int = 0
    top1_hit_raw: int = 0
    top1_hit_app_thr: int = 0
    predicted_raw: int = 0
    predicted_app_thr: int = 0
    unstable_repeat_count: int = 0


def rate(a: int, b: int) -> float:
    return round(a / b, 4) if b else 0.0


def evaluate_model(model_name: str, model_path: Path, images: list[Path]) -> dict:
    model = YOLO(str(model_path), task="detect")
    summary = Summary(total_images=len(images))
    per_image = []

    for image in images:
        gt = gt_classes(image)
        if gt:
            summary.labeled_images += 1
        else:
            summary.unlabeled_images += 1

        preds = []
        for _ in range(REPEATS):
            result = model.predict(
                source=str(image),
                imgsz=IMGSZ,
                conf=PREDICT_CONF,
                verbose=False,
            )[0]
            preds.append(top_pred(result))

        if preds[0][0] != preds[1][0]:
            summary.unstable_repeat_count += 1

        pred_cls, pred_conf = preds[0]
        if gt:
            if pred_cls is not None:
                summary.predicted_raw += 1
                if pred_cls in gt:
                    summary.top1_hit_raw += 1
            if pred_cls is not None and pred_conf >= APP_CONF:
                summary.predicted_app_thr += 1
                if pred_cls in gt:
                    summary.top1_hit_app_thr += 1

        per_image.append(
            {
                "image": image.name,
                "gt": sorted(gt),
                "pred_top_class": pred_cls,
                "pred_top_conf": round(pred_conf, 6),
                "pred_repeat2_class": preds[1][0],
                "unstable_between_repeats": preds[0][0] != preds[1][0],
            }
        )

    return {
        "model": model_name,
        "model_path": str(model_path),
        "summary": asdict(summary),
        "metrics": {
            "top1_hit_rate_raw_on_labeled": rate(summary.top1_hit_raw, summary.labeled_images),
            "top1_hit_rate_app_thr_on_labeled": rate(
                summary.top1_hit_app_thr, summary.labeled_images
            ),
            "precision_raw_on_predicted": rate(summary.top1_hit_raw, summary.predicted_raw),
            "precision_app_thr_on_predicted": rate(
                summary.top1_hit_app_thr, summary.predicted_app_thr
            ),
            "repeat_instability_rate": rate(
                summary.unstable_repeat_count, summary.total_images
            ),
        },
        "sample_unstable_images": [
            row["image"] for row in per_image if row["unstable_between_repeats"]
        ][:20],
    }


def main() -> None:
    images = sorted(DATASET_IMAGES.glob("*"))
    if not images:
        raise RuntimeError(f"No test images found at {DATASET_IMAGES}")

    output = {
        "images_count": len(images),
        "predict_conf": PREDICT_CONF,
        "app_conf_threshold": APP_CONF,
        "repeats_per_image": REPEATS,
        "results": {},
    }
    for name, path in MODELS.items():
        output["results"][name] = evaluate_model(name, path, images)

    out = ROOT / "offline_phase0_baseline.json"
    out.write_text(json.dumps(output, indent=2), encoding="utf-8")
    print(out)
    print(json.dumps({k: v["metrics"] for k, v in output["results"].items()}, indent=2))


if __name__ == "__main__":
    main()
