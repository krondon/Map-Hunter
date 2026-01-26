
import os
from PIL import Image

def smart_crop_avatars():
    # Source image from the previous turn which has the explorer and spec updates
    source_path = r"C:/Users/natac/.gemini/antigravity/brain/a1425432-a507-4216-832b-e8a573c3c0e0/uploaded_media_1769372408054.png"
    output_dir = r"c:/Users/natac/Desktop/Busqueda_del_tesoro/Juego_QR/assets/images/avatars"
    
    if not os.path.exists(source_path):
        print(f"Error: Source image not found at {source_path}")
        return

    try:
        img = Image.open(source_path)
        width, height = img.size
        print(f"Image dimensions: {width}x{height}")
        
        # We assume the image follows the previous grid layout roughly (2 rows),
        # but we need to capture the full sprite content which might overflow the standard grid cell.
        
        # Explorer M is in the bottom-left area. 
        # Typically Row 1, Col 0. 
        # But to avoid cutting the pickaxe (which extends right), we will grab a wider area.
        # We'll take the entire bottom-left quadrant (Col 0 and Col 1 width).
        
        # Row 1 starts at height // 2
        row_start = height // 2
        
        # 1. Extract Explorer M
        # Take the left half of the bottom row (covering usually Col 0 and Col 1)
        # 1024 width / 2 = 512.
        explorer_area = img.crop((0, row_start, width // 2, height))
        
        # Find the bounding box of the non-transparent content
        explorer_bbox = explorer_area.getbbox()
        if explorer_bbox:
            explorer_sprite = explorer_area.crop(explorer_bbox)
            # Add a small margin or keep it tight? The user wants the full image.
            # Usually it's better to keep it tight or center it in a standard frame.
            # For now, let's just save the full content tightly cropped to ensure nothing is cut off visually.
            # But the UI might expect a certain aspect ratio? 
            # The UI code uses `fit: BoxFit.contain`, so a tight crop is fine, the UI handles scaling.
            
            save_path = os.path.join(output_dir, "explorer_m.png")
            explorer_sprite.save(save_path)
            print(f"Saved explorer_m.png (Size: {explorer_sprite.size})")
        else:
            print("Warning: No content found for explorer_m area")

        # 2. Extract Spec M
        # Spec M is usually at the far right (Col 3).
        # We'll take the right half of the bottom row (covering Col 2 and Col 3) to be safe.
        spec_area = img.crop((width // 2, row_start, width, height))
        
        spec_bbox = spec_area.getbbox()
        if spec_bbox:
            spec_sprite = spec_area.crop(spec_bbox)
            save_path = os.path.join(output_dir, "spec_m.png")
            spec_sprite.save(save_path)
            print(f"Saved spec_m.png (Size: {spec_sprite.size})")
        else:
            print("Warning: No content found for spec_m area")
            
        print("Smart crop completed.")
        
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    smart_crop_avatars()
