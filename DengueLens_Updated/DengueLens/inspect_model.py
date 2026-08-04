import json
try:
    import tensorflow as tf
    model_path = "e:/UI/DengueLens_Updated/DengueLens/Model/best_int8.tflite"
    interpreter = tf.lite.Interpreter(model_path=model_path)
    
    inputs = interpreter.get_input_details()
    outputs = interpreter.get_output_details()
    
    print("Inputs:")
    for i in inputs:
        print(f"- {i['name']}: shape={i['shape']}, type={i['dtype']}")
        
    print("Outputs:")
    for o in outputs:
        print(f"- {o['name']}: shape={o['shape']}, type={o['dtype']}")
        
    float_model_path = "e:/UI/DengueLens_Updated/DengueLens/Model/best_float32.tflite"
    interpreter_f = tf.lite.Interpreter(model_path=float_model_path)
    
    print("\nFloat32 Model:")
    print("Inputs:")
    for i in interpreter_f.get_input_details():
        print(f"- {i['name']}: shape={i['shape']}, type={i['dtype']}")
        
    print("Outputs:")
    for o in interpreter_f.get_output_details():
        print(f"- {o['name']}: shape={o['shape']}, type={o['dtype']}")

except ImportError:
    print("Tensorflow not installed")
except Exception as e:
    print(f"Error: {e}")
