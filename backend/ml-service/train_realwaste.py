"""Train and export the nine-class RealWaste classifier."""

import argparse
import json
import os
from pathlib import Path

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers


CLASS_NAMES = [
    "Cardboard",
    "Food Organics",
    "Glass",
    "Metal",
    "Miscellaneous Trash",
    "Paper",
    "Plastic",
    "Textile Trash",
    "Vegetation",
]
IMAGE_SIZE = (224, 224)
MEAN = tf.constant([0.485, 0.456, 0.406], dtype=tf.float32)
STD = tf.constant([0.229, 0.224, 0.225], dtype=tf.float32)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--data-dir",
        type=Path,
        default=Path(__file__).parent / "realwaste" / "RealWaste",
    )
    parser.add_argument(
        "--model-dir",
        type=Path,
        default=Path(__file__).parent / "model",
    )
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--head-epochs", type=int, default=8)
    parser.add_argument("--fine-tune-epochs", type=int, default=12)
    return parser.parse_args()


def normalize(images: tf.Tensor, labels: tf.Tensor) -> tuple[tf.Tensor, tf.Tensor]:
    images = tf.cast(images, tf.float32) / 255.0
    return (images - MEAN) / STD, labels


def make_model() -> keras.Model:
    inputs = keras.Input(shape=(*IMAGE_SIZE, 3), name="image")
    augmented = keras.Sequential(
        [
            layers.RandomFlip("horizontal"),
            layers.RandomRotation(0.08),
            layers.RandomZoom(0.15),
            layers.RandomContrast(0.1),
        ],
        name="augmentation",
    )(inputs)
    raw_pixels = (augmented * STD + MEAN) * 255.0
    backbone = keras.applications.EfficientNetB0(
        include_top=False,
        weights="imagenet",
        input_shape=(*IMAGE_SIZE, 3),
        pooling="avg",
    )
    backbone.trainable = False
    features = backbone(raw_pixels, training=False)
    outputs = layers.Dense(len(CLASS_NAMES), name="classifier")(features)
    return keras.Model(inputs, outputs, name="realwaste_efficientnet_b0")


def prepare_dataset(
    data_dir: Path, validation: bool, seed: int, batch_size: int
) -> tf.data.Dataset:
    dataset = keras.utils.image_dataset_from_directory(
        data_dir,
        labels="inferred",
        label_mode="int",
        class_names=CLASS_NAMES,
        image_size=IMAGE_SIZE,
        batch_size=batch_size,
        validation_split=0.2,
        subset="validation" if validation else "training",
        seed=seed,
        shuffle=not validation,
    )
    return dataset.map(normalize, num_parallel_calls=tf.data.AUTOTUNE).prefetch(
        tf.data.AUTOTUNE
    )


def class_weights(train_dataset: tf.data.Dataset) -> dict[int, float]:
    counts = tf.zeros(len(CLASS_NAMES), dtype=tf.int64)
    for _, labels in train_dataset:
        counts += tf.cast(tf.math.bincount(labels, minlength=len(CLASS_NAMES)), tf.int64)
    total = int(tf.reduce_sum(counts).numpy())
    return {
        index: total / (len(CLASS_NAMES) * max(int(count), 1))
        for index, count in enumerate(counts.numpy())
    }


def export_tflite(model: keras.Model, destination: Path) -> None:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    model_bytes = converter.convert()
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary_destination = destination.with_suffix(".tmp.tflite")
    temporary_destination.write_bytes(model_bytes)
    os.replace(temporary_destination, destination)


def main() -> None:
    args = parse_args()
    if not args.data_dir.is_dir():
        raise FileNotFoundError(f"Dataset directory not found: {args.data_dir}")
    tf.keras.utils.set_random_seed(args.seed)
    os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "1")

    train_dataset = prepare_dataset(args.data_dir, False, args.seed, args.batch_size)
    validation_dataset = prepare_dataset(args.data_dir, True, args.seed, args.batch_size)
    model = make_model()
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-3),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    model.fit(
        train_dataset,
        validation_data=validation_dataset,
        epochs=args.head_epochs,
        class_weight=class_weights(train_dataset),
        callbacks=[
            keras.callbacks.EarlyStopping(
                monitor="val_accuracy", patience=3, restore_best_weights=True
            )
        ],
    )

    backbone = model.get_layer("efficientnetb0")
    backbone.trainable = True
    for layer in backbone.layers[:-30]:
        layer.trainable = False
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-5),
        loss=keras.losses.SparseCategoricalCrossentropy(from_logits=True),
        metrics=["accuracy"],
    )
    model.fit(
        train_dataset,
        validation_data=validation_dataset,
        epochs=args.fine_tune_epochs,
        class_weight=class_weights(train_dataset),
        callbacks=[
            keras.callbacks.EarlyStopping(
                monitor="val_accuracy", patience=4, restore_best_weights=True
            )
        ],
    )

    loss, accuracy = model.evaluate(validation_dataset, verbose=0)
    print(f"validation_loss={loss:.4f} validation_accuracy={accuracy:.4f}")
    model_dir = args.model_dir
    model_dir.mkdir(parents=True, exist_ok=True)
    export_tflite(model, model_dir / "waste_classifier.tflite")
    (model_dir / "class_names.json").write_text(
        json.dumps(CLASS_NAMES), encoding="utf-8"
    )
    print(f"wrote {model_dir / 'waste_classifier.tflite'}")


if __name__ == "__main__":
    main()
