import json
import logging
import os
import threading
from io import BytesIO
from pathlib import Path

import numpy as np
from ai_edge_litert.interpreter import Interpreter
from fastapi import FastAPI, File, HTTPException, Response, UploadFile
from pydantic import BaseModel
from PIL import Image, UnidentifiedImageError

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = Path(
    os.getenv("WASTE_TFLITE_MODEL_PATH", BASE_DIR / "model" / "waste_classifier.tflite")
)
CLASS_NAMES_PATH = Path(
    os.getenv("WASTE_CLASS_NAMES_PATH", BASE_DIR / "model" / "class_names.json")
)
IMAGE_SIZE = (224, 224)
IMAGENET_MEAN = np.asarray([0.485, 0.456, 0.406], dtype=np.float32)
IMAGENET_STD = np.asarray([0.229, 0.224, 0.225], dtype=np.float32)
MAX_IMAGE_BYTES = 10 * 1024 * 1024

app = FastAPI(title="Waste Classification Model", version="2.0.0")
logger = logging.getLogger("uvicorn.error")
interpreter = None
input_index = None
output_index = None
class_names = []
inference_lock = threading.Lock()


class ClassificationLog(BaseModel):
    method: str
    path: str
    status: int
    duration_ms: float
    response_bytes: int


def load_model() -> None:
    global interpreter, input_index, output_index, class_names
    if interpreter is not None:
        return
    if not MODEL_PATH.is_file():
        raise RuntimeError(f"TFLite model file not found: {MODEL_PATH}")
    if not CLASS_NAMES_PATH.is_file():
        raise RuntimeError(f"Class names file not found: {CLASS_NAMES_PATH}")

    loaded_classes = json.loads(CLASS_NAMES_PATH.read_text(encoding="utf-8"))
    if not isinstance(loaded_classes, list) or not all(
        isinstance(label, str) for label in loaded_classes
    ):
        raise RuntimeError("Class names must be a list of strings")

    loaded_interpreter = Interpreter(model_path=str(MODEL_PATH))
    loaded_interpreter.allocate_tensors()
    inputs = loaded_interpreter.get_input_details()
    outputs = loaded_interpreter.get_output_details()
    if len(inputs) != 1 or len(outputs) != 1:
        raise RuntimeError("The TFLite model must have one input and one output")
    if tuple(inputs[0]["shape"]) != (1, 224, 224, 3):
        raise RuntimeError(f"Unexpected TFLite input shape: {inputs[0]['shape']}")
    if outputs[0]["shape"][-1] != len(loaded_classes):
        raise RuntimeError("Class names do not match the TFLite output size")

    interpreter = loaded_interpreter
    input_index = inputs[0]["index"]
    output_index = outputs[0]["index"]
    class_names = loaded_classes


def preprocess_image(contents: bytes) -> np.ndarray:
    try:
        image = Image.open(BytesIO(contents)).convert("RGB").resize(IMAGE_SIZE)
    except (UnidentifiedImageError, OSError, ValueError) as error:
        raise ValueError("Invalid image file") from error
    pixels = np.asarray(image, dtype=np.float32) / 255.0
    return ((pixels - IMAGENET_MEAN) / IMAGENET_STD)[None, ...]


def predict(contents: bytes) -> tuple[str, float, dict[str, float]]:
    load_model()
    tensor = preprocess_image(contents)
    with inference_lock:
        interpreter.set_tensor(input_index, tensor)
        interpreter.invoke()
        logits = np.asarray(interpreter.get_tensor(output_index)[0], dtype=np.float64)

    shifted = logits - np.max(logits)
    probabilities = np.exp(shifted)
    probabilities /= probabilities.sum()
    predicted_index = int(np.argmax(probabilities))
    return (
        class_names[predicted_index],
        float(probabilities[predicted_index]),
        {
            label: float(probabilities[index])
            for index, label in enumerate(class_names)
        },
    )


@app.on_event("startup")
def startup() -> None:
    load_model()


@app.get("/health")
def health() -> dict[str, object]:
    load_model()
    return {
        "status": "ok",
        "service": "waste-classification-model",
        "model": "EfficientNet-B0 TensorFlow Lite",
        "num_classes": len(class_names),
    }


@app.post("/classification-log", status_code=204)
def classification_log(entry: ClassificationLog) -> Response:
    logger.info(
        "%s %s %d %.3f ms - %d",
        entry.method,
        entry.path,
        entry.status,
        entry.duration_ms,
        entry.response_bytes,
    )
    return Response(status_code=204)


@app.post("/predict")
async def predict_endpoint(file: UploadFile = File(...)) -> dict:
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=415, detail="An image file is required")
    contents = await file.read(MAX_IMAGE_BYTES + 1)
    if not contents:
        raise HTTPException(status_code=400, detail="The uploaded image is empty")
    if len(contents) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="The image exceeds the 10 MB limit")
    try:
        predicted_class, confidence, all_probabilities = predict(contents)
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
    return {
        "predicted_class": predicted_class,
        "confidence": confidence,
        "all_probabilities": all_probabilities,
    }
