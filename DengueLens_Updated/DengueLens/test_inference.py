from ai_edge_litert.interpreter import Interpreter
import numpy as np

interp = Interpreter(model_path=r"E:\UI\DengueLens_Updated\DengueLens\Model\best_int8.tflite")
interp.allocate_tensors()

inp = interp.get_input_details()[0]
out = interp.get_output_details()[0]
print("input:", inp['shape'], inp['dtype'])
print("output:", out['shape'], out['dtype'])

if inp['dtype'] == np.int8:
    dummy = np.random.randint(-128, 127, size=inp['shape'], dtype=np.int8)
else:
    dummy = np.random.uniform(0, 1, size=inp['shape']).astype(np.float32)

interp.set_tensor(inp['index'], dummy)
interp.invoke()
print("✅ invoke succeeded")
print(interp.get_tensor(out['index']).shape)