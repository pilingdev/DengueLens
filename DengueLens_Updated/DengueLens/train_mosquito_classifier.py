"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  DengueLens — MobileNetV3-Small Mosquito Species Classifier Training       ║
║  Run this notebook/script on Kaggle with GPU enabled.                      ║
╚══════════════════════════════════════════════════════════════════════════════╝

Classes:  Aegypti | Albopictus | Anopheles | Culex | Non-Mosquito
Input:    224 × 224 × 3  (raw uint8 pixels, [0, 255])
Model:    MobileNetV3Small with built-in Rescaling layer
Output:   mobilenetv3_mosquito_classifier.keras + .tflite + labels_classifier.txt

IMPORTANT — Preprocessing Contract:
  The Flutter app (DengueLens) feeds RAW [0, 255] pixel values to the TFLite
  model. The model's first layer is a Rescaling(1/127.5, offset=-1) layer that
  internally maps [0, 255] → [-1, 1]. This script MUST match that contract.
  We use rescale=None in ImageDataGenerator and add Rescaling inside the model.
"""

# ──────────────────────────────────────────────────────────────────────────────
# 0. CONFIGURATION — Edit these to match your Kaggle setup
# ──────────────────────────────────────────────────────────────────────────────

import os

# ╔══════════════════════════════════════════════════════════════╗
# ║  🔧 EDIT THIS: Point to your Kaggle dataset root.          ║
# ║  The folder should contain one subfolder per class:         ║
# ║    dataset_root/                                            ║
# ║      ├── Aegypti/                                           ║
# ║      ├── Albopictus/                                        ║
# ║      ├── Anopheles/                                         ║
# ║      ├── Culex/                                             ║
# ║      └── Non-Mosquito/                                      ║
# ╚══════════════════════════════════════════════════════════════╝

DATASET_ROOT = "/kaggle/input/New_Dataset/nDataset"

# Training hyperparameters
IMG_SIZE        = 224
BATCH_SIZE      = 32
EPOCHS_WARMUP   = 5        # Head-only warmup epochs (frozen backbone)
EPOCHS_FINETUNE = 25       # Full fine-tuning epochs (unfrozen backbone)
LEARNING_RATE   = 1e-3     # Warmup LR
FINETUNE_LR     = 1e-4     # Fine-tuning LR (lower for stable convergence)
DROPOUT_RATE    = 0.3      # Classifier head dropout
LABEL_SMOOTHING = 0.1      # Helps prevent overconfident predictions

# Class names — auto-detected from dataset folders at runtime.
# After training, the labels file will use whatever folder names your dataset has.
# If you need to rename them for DengueLens, edit the LABEL_MAP below.
# Example: LABEL_MAP = {"non_mosquito": "Non-Mosquito", "aedes_aegypti": "Aegypti"}
LABEL_MAP = {}   # <-- Optional: {"dataset_folder_name": "DengueLens_label_name"}

# Output directory
OUTPUT_DIR = "/kaggle/working"

# ──────────────────────────────────────────────────────────────────────────────
# 1. IMPORTS
# ──────────────────────────────────────────────────────────────────────────────

import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path
import json
import warnings
warnings.filterwarnings("ignore")

# Fix for truncated/corrupted images in the dataset
from PIL import ImageFile
ImageFile.LOAD_TRUNCATED_IMAGES = True

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, callbacks, optimizers
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from sklearn.metrics import classification_report, confusion_matrix

print(f"TensorFlow version : {tf.__version__}")
print(f"GPU available      : {tf.config.list_physical_devices('GPU')}")
print(f"Dataset root       : {DATASET_ROOT}")
print(f"Image size         : {IMG_SIZE}×{IMG_SIZE}")
print(f"Batch size         : {BATCH_SIZE}")
print(f"Classes            : {CLASS_NAMES}")

# ──────────────────────────────────────────────────────────────────────────────
# 2. DATASET LOADING & AUGMENTATION
# ──────────────────────────────────────────────────────────────────────────────

# Your dataset is already split: nDataset/train/, nDataset/valid/, nDataset/test/
# Each split folder contains class subfolders (Aegypti, Albopictus, etc.)

TRAIN_DIR = os.path.join(DATASET_ROOT, "train")
VALID_DIR = os.path.join(DATASET_ROOT, "valid")
TEST_DIR  = os.path.join(DATASET_ROOT, "test")

# Auto-detect class names from the train subfolder
detected_classes = sorted([
    d for d in os.listdir(TRAIN_DIR)
    if os.path.isdir(os.path.join(TRAIN_DIR, d)) and not d.startswith(".")
])
print(f"\n🔍 Detected classes from dataset: {detected_classes}")

CLASS_NAMES = detected_classes
NUM_CLASSES = len(CLASS_NAMES)

if NUM_CLASSES < 2:
    raise ValueError(f"Expected at least 2 class folders in {TRAIN_DIR}, found: {detected_classes}")

# ⚠️ NO rescale=1./255 here! The model's built-in Rescaling layer handles it.
# We pass raw [0, 255] float32 pixels to match the TFLite inference pipeline.

train_datagen = ImageDataGenerator(
    # Raw pixel values — no rescaling!
    rotation_range=30,
    width_shift_range=0.2,
    height_shift_range=0.2,
    shear_range=0.15,
    zoom_range=0.2,
    horizontal_flip=True,
    vertical_flip=True,       # Mosquito crops can appear at any orientation
    brightness_range=[0.7, 1.3],
    fill_mode="reflect",
)

val_datagen = ImageDataGenerator(
    # No augmentation for validation — just raw pixels
)

print(f"\n📂 Loading training data from {TRAIN_DIR}...")
train_generator = train_datagen.flow_from_directory(
    TRAIN_DIR,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode="categorical",
    classes=CLASS_NAMES,
    shuffle=True,
    seed=42,
    interpolation="bilinear",
)

print(f"\n📂 Loading validation data from {VALID_DIR}...")
val_generator = val_datagen.flow_from_directory(
    VALID_DIR,
    target_size=(IMG_SIZE, IMG_SIZE),
    batch_size=BATCH_SIZE,
    class_mode="categorical",
    classes=CLASS_NAMES,
    shuffle=False,
    seed=42,
    interpolation="bilinear",
)

# Print class distribution
print("\n📊 Class distribution (training):")
class_counts = {}
for cls_name, cls_idx in train_generator.class_indices.items():
    count = np.sum(train_generator.classes == cls_idx)
    class_counts[cls_name] = count
    print(f"   {cls_name:15s} : {count:5d} images")
print(f"   {'TOTAL':15s} : {len(train_generator.classes):5d} images")

print(f"\n📊 Validation set : {len(val_generator.classes)} images")

# ──────────────────────────────────────────────────────────────────────────────
# 3. COMPUTE CLASS WEIGHTS (handles imbalanced datasets)
# ──────────────────────────────────────────────────────────────────────────────

from sklearn.utils.class_weight import compute_class_weight

# Use only the classes that actually appear in the training data
unique_classes = np.unique(train_generator.classes)
class_weights_array = compute_class_weight(
    class_weight="balanced",
    classes=unique_classes,
    y=train_generator.classes,
)
class_weights = dict(zip(unique_classes, class_weights_array))

print("\n⚖️  Computed class weights:")
for idx in unique_classes:
    name = CLASS_NAMES[idx]
    print(f"   {name:15s} : {class_weights[idx]:.4f}")

# ──────────────────────────────────────────────────────────────────────────────
# 4. BUILD MODEL
# ──────────────────────────────────────────────────────────────────────────────

def build_model(num_classes, img_size=224, dropout_rate=0.3):
    """
    Build MobileNetV3-Small with a built-in Rescaling layer.
    
    Architecture:
        Input [0, 255] → Rescaling [-1, 1] → MobileNetV3Small → GAP → Dropout → Dense(softmax)
    
    The Rescaling layer is INSIDE the model so the TFLite export includes it.
    This means inference code can feed raw uint8 pixels directly.
    """
    # Input layer
    inputs = layers.Input(shape=(img_size, img_size, 3), name="input_image")
    
    # Built-in rescaling: [0, 255] → [-1, 1]
    # This matches tf.keras.applications.mobilenet_v3 expected preprocessing
    x = layers.Rescaling(scale=1.0/127.5, offset=-1.0, name="rescaling")(inputs)
    
    # MobileNetV3-Small backbone (pretrained on ImageNet)
    backbone = keras.applications.MobileNetV3Small(
        input_shape=(img_size, img_size, 3),
        include_top=False,
        weights="imagenet",
        include_preprocessing=False,  # We handle it with our Rescaling layer
    )
    backbone._name = "mobilenetv3small_backbone"
    
    x = backbone(x, training=True)
    
    # Classification head
    x = layers.GlobalAveragePooling2D(name="global_avg_pool")(x)
    x = layers.BatchNormalization(name="head_bn")(x)
    x = layers.Dropout(dropout_rate, name="head_dropout")(x)
    x = layers.Dense(128, activation="relu", name="head_dense")(x)
    x = layers.Dropout(dropout_rate / 2, name="head_dropout_2")(x)
    outputs = layers.Dense(num_classes, activation="softmax", name="predictions")(x)
    
    model = keras.Model(inputs=inputs, outputs=outputs, name="mosquito_classifier")
    return model, backbone


model, backbone = build_model(NUM_CLASSES, IMG_SIZE, DROPOUT_RATE)
model.summary()

# ──────────────────────────────────────────────────────────────────────────────
# 5. PHASE 1 — WARMUP (Train head only, backbone frozen)
# ──────────────────────────────────────────────────────────────────────────────

print("\n" + "="*70)
print("🧊 PHASE 1: WARMUP — Training classification head only")
print("="*70)

# Freeze backbone
backbone.trainable = False

model.compile(
    optimizer=optimizers.Adam(learning_rate=LEARNING_RATE),
    loss=keras.losses.CategoricalCrossentropy(label_smoothing=LABEL_SMOOTHING),
    metrics=["accuracy"],
)

warmup_callbacks = [
    callbacks.EarlyStopping(
        monitor="val_accuracy",
        patience=3,
        restore_best_weights=True,
        verbose=1,
    ),
]

history_warmup = model.fit(
    train_generator,
    epochs=EPOCHS_WARMUP,
    validation_data=val_generator,
    class_weight=class_weights,
    callbacks=warmup_callbacks,
    verbose=1,
)

# ──────────────────────────────────────────────────────────────────────────────
# 6. PHASE 2 — FINE-TUNING (Unfreeze backbone, train end-to-end)
# ──────────────────────────────────────────────────────────────────────────────

print("\n" + "="*70)
print("🔓 PHASE 2: FINE-TUNING — Training entire model end-to-end")
print("="*70)

# Unfreeze the backbone
backbone.trainable = True

# Use a lower learning rate for fine-tuning to avoid catastrophic forgetting
model.compile(
    optimizer=optimizers.Adam(learning_rate=FINETUNE_LR),
    loss=keras.losses.CategoricalCrossentropy(label_smoothing=LABEL_SMOOTHING),
    metrics=["accuracy"],
)

finetune_callbacks = [
    callbacks.EarlyStopping(
        monitor="val_accuracy",
        patience=7,
        restore_best_weights=True,
        verbose=1,
    ),
    callbacks.ReduceLROnPlateau(
        monitor="val_loss",
        factor=0.5,
        patience=3,
        min_lr=1e-7,
        verbose=1,
    ),
    callbacks.ModelCheckpoint(
        filepath=os.path.join(OUTPUT_DIR, "best_model.keras"),
        monitor="val_accuracy",
        save_best_only=True,
        verbose=1,
    ),
]

history_finetune = model.fit(
    train_generator,
    epochs=EPOCHS_FINETUNE,
    validation_data=val_generator,
    class_weight=class_weights,
    callbacks=finetune_callbacks,
    verbose=1,
)

# ──────────────────────────────────────────────────────────────────────────────
# 7. EVALUATION
# ──────────────────────────────────────────────────────────────────────────────

print("\n" + "="*70)
print("📊 EVALUATION")
print("="*70)

# Load the best checkpoint
model = keras.models.load_model(os.path.join(OUTPUT_DIR, "best_model.keras"))

# Evaluate on validation set
val_generator.reset()
val_loss, val_acc = model.evaluate(val_generator, verbose=1)
print(f"\n✅ Best Validation Accuracy : {val_acc*100:.2f}%")
print(f"✅ Best Validation Loss     : {val_loss:.4f}")

# Generate predictions for classification report
val_generator.reset()
y_pred_probs = model.predict(val_generator, verbose=1)
y_pred = np.argmax(y_pred_probs, axis=1)
y_true = val_generator.classes[:len(y_pred)]

print("\n📋 Classification Report:")
print(classification_report(y_true, y_pred, target_names=CLASS_NAMES, digits=4))

# ──────────────────────────────────────────────────────────────────────────────
# 8. PLOTS — Training History & Confusion Matrix
# ──────────────────────────────────────────────────────────────────────────────

def merge_histories(h1, h2):
    """Merge two Keras history objects."""
    merged = {}
    for key in h1.history:
        merged[key] = h1.history[key] + h2.history.get(key, [])
    return merged

history = merge_histories(history_warmup, history_finetune)

fig, axes = plt.subplots(1, 3, figsize=(20, 5))

# Accuracy plot
axes[0].plot(history["accuracy"], label="Train", linewidth=2)
axes[0].plot(history["val_accuracy"], label="Validation", linewidth=2)
axes[0].axvline(x=len(history_warmup.history["accuracy"])-0.5, color="gray",
                linestyle="--", alpha=0.5, label="Fine-tune start")
axes[0].set_title("Accuracy", fontsize=14, fontweight="bold")
axes[0].set_xlabel("Epoch")
axes[0].set_ylabel("Accuracy")
axes[0].legend()
axes[0].grid(True, alpha=0.3)

# Loss plot
axes[1].plot(history["loss"], label="Train", linewidth=2)
axes[1].plot(history["val_loss"], label="Validation", linewidth=2)
axes[1].axvline(x=len(history_warmup.history["loss"])-0.5, color="gray",
                linestyle="--", alpha=0.5, label="Fine-tune start")
axes[1].set_title("Loss", fontsize=14, fontweight="bold")
axes[1].set_xlabel("Epoch")
axes[1].set_ylabel("Loss")
axes[1].legend()
axes[1].grid(True, alpha=0.3)

# Confusion matrix
cm = confusion_matrix(y_true, y_pred)
cm_normalized = cm.astype("float") / cm.sum(axis=1)[:, np.newaxis]
sns.heatmap(cm_normalized, annot=True, fmt=".2f", cmap="Blues",
            xticklabels=CLASS_NAMES, yticklabels=CLASS_NAMES, ax=axes[2])
axes[2].set_title("Confusion Matrix (Normalized)", fontsize=14, fontweight="bold")
axes[2].set_xlabel("Predicted")
axes[2].set_ylabel("True")

plt.tight_layout()
plt.savefig(os.path.join(OUTPUT_DIR, "training_results.png"), dpi=150, bbox_inches="tight")
plt.show()
print(f"\n📈 Training plots saved to {OUTPUT_DIR}/training_results.png")

# ──────────────────────────────────────────────────────────────────────────────
# 9. EXPORT — Save .keras, .tflite, and labels file
# ──────────────────────────────────────────────────────────────────────────────

print("\n" + "="*70)
print("💾 EXPORTING MODEL")
print("="*70)

# 9a. Save Keras model
keras_path = os.path.join(OUTPUT_DIR, "mobilenetv3_mosquito_classifier.keras")
model.save(keras_path)
print(f"✅ Saved Keras model        : {keras_path}")

# 9b. Convert to TFLite (float32 — full precision)
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.target_spec.supported_ops = [
    tf.lite.OpsSet.TFLITE_BUILTINS,
    tf.lite.OpsSet.SELECT_TF_OPS,        # Fallback for any unsupported ops
]
converter._experimental_lower_tensor_list_ops = False

tflite_model = converter.convert()

tflite_path = os.path.join(OUTPUT_DIR, "mobilenetv3_mosquito_classifier.tflite")
with open(tflite_path, "wb") as f:
    f.write(tflite_model)
print(f"✅ Saved TFLite model       : {tflite_path}")
print(f"   TFLite model size        : {len(tflite_model) / (1024*1024):.2f} MB")

# 9c. Save labels file
labels_path = os.path.join(OUTPUT_DIR, "labels_classifier.txt")
with open(labels_path, "w") as f:
    for name in CLASS_NAMES:
        f.write(name + "\n")
print(f"✅ Saved labels file        : {labels_path}")

# ──────────────────────────────────────────────────────────────────────────────
# 10. VERIFICATION — Quick sanity check on TFLite model
# ──────────────────────────────────────────────────────────────────────────────

print("\n" + "="*70)
print("🔍 TFLITE VERIFICATION")
print("="*70)

# Load TFLite model and verify input/output shapes
interpreter = tf.lite.Interpreter(model_path=tflite_path)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"   Input shape  : {input_details[0]['shape']}")
print(f"   Input dtype  : {input_details[0]['dtype']}")
print(f"   Output shape : {output_details[0]['shape']}")
print(f"   Output dtype : {output_details[0]['dtype']}")

# Run a test inference with random data in [0, 255] range
test_input = np.random.uniform(0, 255, size=(1, IMG_SIZE, IMG_SIZE, 3)).astype(np.float32)
interpreter.set_tensor(input_details[0]["index"], test_input)
interpreter.invoke()
test_output = interpreter.get_tensor(output_details[0]["index"])

print(f"   Test output  : {test_output}")
print(f"   Sum of probs : {test_output.sum():.4f}  (should be ≈ 1.0)")
print(f"   Predicted    : {CLASS_NAMES[np.argmax(test_output)]}")

# ──────────────────────────────────────────────────────────────────────────────
# 11. SUMMARY
# ──────────────────────────────────────────────────────────────────────────────

print("\n" + "="*70)
print("🎉 TRAINING COMPLETE!")
print("="*70)
print(f"""
📦 Output files in {OUTPUT_DIR}:
   ├── mobilenetv3_mosquito_classifier.keras   (Keras model)
   ├── mobilenetv3_mosquito_classifier.tflite  (TFLite model)
   ├── labels_classifier.txt                   (Class labels)
   ├── best_model.keras                        (Best checkpoint)
   └── training_results.png                    (Plots)

🚀 To use in DengueLens:
   1. Download the .tflite and labels_classifier.txt files
   2. Replace the files in your DengueLens/Model/ folder:
      • Model/mobilenetv3_mosquito_classifier.tflite
      • Model/labels_classifier.txt
   3. Run the app — no code changes needed!

⚠️  Preprocessing reminder:
   • The model expects RAW [0, 255] float32 pixel values as input
   • The Rescaling layer inside the model handles normalization
   • This matches the DengueLens Flutter app's preprocessing pipeline
""")
