from PIL import Image
import os

try:
    path = "assets/images/QuarterMaster_v3.jpg"
    if os.path.exists(path):
        img = Image.open(path)
        img = img.convert('RGB')
        img.save(path, "JPEG")
        print("Converted v3 to JPG")
    else:
        print("v3 not found")
except Exception as e:
    print(f"Error: {e}")
