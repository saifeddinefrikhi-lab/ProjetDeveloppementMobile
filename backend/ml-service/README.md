# Waste classification model service

This service loads `model/waste_classifier.tflite` and exposes the endpoint used
by the Node API:

```text
POST /predict
multipart field: file
```

The model is converted from the EfficientNet-B0 ONNX model in
`huggingface-space/model`. It expects `224x224` RGB images normalized with the
ImageNet mean and standard deviation. The service uses LiteRT/TensorFlow Lite
for CPU inference and returns the nine source-model classes.

## Retraining

The nine-class RealWaste dataset is included under `realwaste/RealWaste`.
Install the training dependency set and run:

```powershell
python -m pip install -r requirements-training.txt
python train_realwaste.py
```

The script uses ImageNet-pretrained EfficientNet-B0, balances the class
frequencies, evaluates a held-out 20% split, and writes the compatible
`model/waste_classifier.tflite` and `model/class_names.json` artifacts.

## Setup

Python 3.14 is supported with the LiteRT runtime.

```powershell
cd backend\ml-service
py -3.14 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn app:app --host 127.0.0.1 --port 8000
```
