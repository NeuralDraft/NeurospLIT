#!/usr/bin/env python3
"""
Generate app icon placeholders for NeurospLIT
Replace these with your actual app icon design
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_placeholder_icon(size, output_path):
    """Create a placeholder icon with the NeurospLIT text"""
    # Create a new image with purple gradient background
    img = Image.new('RGBA', (size, size), (139, 92, 246, 255))  # Purple color
    draw = ImageDraw.Draw(img)
    
    # Draw a simple design
    # Draw circle
    margin = size // 8
    draw.ellipse(
        [margin, margin, size - margin, size - margin],
        outline=(255, 255, 255, 255),
        width=max(1, size // 40)
    )
    
    # Add text ($ symbol for tip/money app)
    text = "$"
    font_size = size // 2
    # Try to use a system font, fallback to default if not available
    try:
        font = ImageFont.truetype("arial.ttf", font_size)
    except:
        font = ImageFont.load_default()
    
    # Get text size for centering
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]
    
    x = (size - text_width) // 2
    y = (size - text_height) // 2 - size // 10
    
    draw.text((x, y), text, fill=(255, 255, 255, 255), font=font)
    
    # Save the image
    img.save(output_path, 'PNG')
    print(f"Created: {output_path}")

def main():
    """Generate all required icon sizes"""
    icon_dir = "Resources/Assets/Assets.xcassets/AppIcon.appiconset"
    
    # Ensure directory exists
    os.makedirs(icon_dir, exist_ok=True)
    
    # Define all required sizes
    sizes = [
        (20, "Icon-20.png"),
        (29, "Icon-29.png"),
        (40, "Icon-40.png"),
        (58, "Icon-58.png"),
        (60, "Icon-60.png"),
        (76, "Icon-76.png"),
        (80, "Icon-80.png"),
        (87, "Icon-87.png"),
        (120, "Icon-120.png"),
        (152, "Icon-152.png"),
        (167, "Icon-167.png"),
        (180, "Icon-180.png"),
        (1024, "Icon-1024.png"),
    ]
    
    for size, filename in sizes:
        output_path = os.path.join(icon_dir, filename)
        create_placeholder_icon(size, output_path)
    
    print(f"\n✅ Generated {len(sizes)} placeholder icons in {icon_dir}")
    print("⚠️  Remember to replace these with your actual app icon design!")

if __name__ == "__main__":
    try:
        from PIL import Image, ImageDraw, ImageFont
        main()
    except ImportError:
        print("❌ Pillow library not installed.")
        print("To generate placeholder icons, install it with:")
        print("  pip install Pillow")
        print("\nAlternatively, manually add your icon files to:")
        print("  Resources/Assets/Assets.xcassets/AppIcon.appiconset/")
        print("\nRequired sizes: 20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024 pixels")
