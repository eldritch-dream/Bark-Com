from PIL import Image
import os

source = "assets/images/quartermaster_v3.png"
target = "assets/images/QuarterMaster_v3.jpg"

try:
    if os.path.exists(source):
        img = Image.open(source)
        img = img.convert('RGB')
        img.save(target, "JPEG")
        print(f"Converted {source} to {target}")
    else:
        print(f"Source {source} not found")
except Exception as e:
    print(f"Error: {e}")
