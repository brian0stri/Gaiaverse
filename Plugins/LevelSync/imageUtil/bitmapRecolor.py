"""enter pip install Pillow in your Terminal if your PIL import is missing, 
enter pip install FreeSimpleGUI in your Terminal if your FreeSimpleGUI import is missing,
then refresh your IDE to update the import. 
This module provides functions to recolor bitmap images based on user-defined color mappings. 
It allows users to specify new RGB values for unique colors detected in the image, and then applies those changes to create a 
recolored version of the original image. See juliorain's documentation for more details and instructions on how to use this module effectively."""

import os
from os import path

import PIL.Image as Image

from tkinter import colorchooser
from tkinter import messagebox
import tkinter as tk
import FreeSimpleGUI as sg

# Global debug log
debug_log = []
active_window = None
active_log_element = None

def log_message(message):
    """Add message to debug log, print to console, and update GUI if active"""
    debug_log.append(message)
    print(message)
    
    # Update GUI text field if available
    if active_window and active_log_element:
        try:
            active_window[active_log_element].update(value='\n'.join(debug_log) + '\n')
        except:
            pass  # Window might be closed

def show_debug_log():
    """Display debug log in a new window"""
    if not debug_log:
        return
    
    layout = [
        [sg.Multiline('\n'.join(debug_log), size=(80, 30), disabled=True, autoscroll=True, key='-LOG-')],
        [sg.Button("Close"), sg.Button("Copy to Clipboard")]
    ]
    
    window = sg.Window("Debug Log", layout, resizable=True)
    
    while True:
        event, values = window.read()
        if event in (sg.WIN_CLOSED, "Close"):
            break
        elif event == "Copy to Clipboard":
            sg.clipboard_set('\n'.join(debug_log))
            sg.popup_quick_message("Copied to clipboard!", auto_close_duration=1)
    
    window.close()


def get_images_from_folder():
    # 1. Get the directory where bitmapRecolor.py sits (.../imageUtil)
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 2. Go UP one level to the plugin root (.../LevelSync)
    plugin_root = os.path.dirname(base_dir)
    
    # 3. Go DOWN into the Graphics folder
    target_folder = os.path.join(plugin_root, "Graphics", "UI", "Battle")
    
    log_message(f"Checking path: {target_folder}") # Helpful for debugging

    if not os.path.exists(target_folder):
        log_message("Folder not found. Check your folder structure!")
        return []

    return [os.path.join(target_folder, f) for f in os.listdir(target_folder) if f.endswith('.png') and "_backup" not in f] 

def prompt_user_for_colors(unique_colors, original_colors):
    root = tk.Tk()
    root.withdraw() 
    
    color_map = {}
    for color in unique_colors:
        log_message(f"Pick a replacement for original color: {color}")
        
        # Opens the standard Windows color picker dialog
        # Returns ((r, g, b), "#hexcode")
        result = colorchooser.askcolor(title=f"New color for {color}", initialcolor=color)
        
        # Explicitly check if the RGB part (index 0) exists
        if result[0] is not None:
            # result[0] is (r, g, b)
            new_color = tuple(map(int, result[0]))
            if new_color in original_colors:
                log_message("New color cannot be the same as the original color. Please choose a different color.")
                continue
            color_map[color] = new_color
            log_message(f"Mapped {color} -> {new_color}")
        else:
            # User hit 'Cancel' or closed the window
            log_message(f"User cancelled for {color}. Keeping original.")
            color_map[color] = color

    root.destroy()  # Clean up the Tkinter root window
    return color_map

def record_colors(image_path, original_colors):
    transparent_color = original_colors[0]  # Assuming the first color in original_colors is the transparent color
    img = Image.open(image_path)
    found_in_image = set()
    
    if img.mode == 'P':
        palette = img.getpalette()
        # RPGXP palettes are always 256 colors (768 values)
        for i in range(0, len(palette), 3):
            rgb = (palette[i], palette[i+1], palette[i+2])
            
            # Skip the specific transparent color and pure black (usually empty)
            if rgb != transparent_color[:3] and rgb != (0, 0, 0):
                found_in_image.add(rgb)
                
    return found_in_image

def recolor_bitmap(image_path, color_map):
    img = Image.open(image_path).convert('RGBA')
    data = img.getdata()  # Changed from get_flattened_data() to getdata()
    
    new_data = []
    transparent_pixels_found = {}  # Track transparent pixels with non-white RGB
    
    for item in data:
        original_rgb = item[:3]
        alpha = item[3]
        
        # Skip fully transparent pixels (alpha = 0) - don't recolor them
        if alpha == 0:
            # Log any transparent pixels with non-white RGB values for debugging
            if original_rgb != (255, 255, 255) and original_rgb not in transparent_pixels_found:
                transparent_pixels_found[original_rgb] = True
                log_message(f"Skipping transparent pixel with RGB: {original_rgb} (alpha=0)")
            new_data.append(item)
        elif original_rgb in color_map:
            # Replace RGB but preserve original Alpha
            new_color = color_map[original_rgb] + (alpha,)
            new_data.append(new_color)
        else:
            new_data.append(item)
    
    img.putdata(new_data) # Note: putdata is NOT deprecated
    img.save(image_path)
    return img

def restore_original_colors(image_path, original_colors, new_colors):
    img = Image.open(image_path).convert('RGBA')
    data = img.get_flattened_data()
    
    new_data = []
    for color in new_colors:
        log_message(f"Restoring color: {color} to original color: {original_colors[new_colors.index(color)]}")
    
    for item in data:
        rgb = item[:3]
        if rgb in new_colors:
            # Replace with original color but preserve original Alpha
            new_color = original_colors[new_colors.index(rgb)] + (item[3],)
            new_data.append(new_color)
    
    img.putdata(new_data)
    img.save(image_path)
    return img

def count_and_fix_specific_color(image_paths, target_rgb, replacement_rgb=None):
    """
    Count pixels with a specific RGB value across all images.
    Optionally fix them to a replacement color.
    
    Args:
        image_paths: List of image file paths
        target_rgb: Tuple (R, G, B) to search for
        replacement_rgb: Optional tuple (R, G, B) to replace with
    
    Returns:
        Dictionary with image paths as keys and pixel counts as values
    """
    results = {}
    total_count = 0
    
    for img_path in image_paths:
        img = Image.open(img_path).convert('RGBA')
        data = img.getdata()
        
        count = 0
        new_data = []
        
        for pixel in data:
            rgb = pixel[:3]
            alpha = pixel[3]
            
            if rgb == target_rgb:
                count += 1
                if replacement_rgb:
                    # Replace with new color, preserve alpha
                    new_data.append(replacement_rgb + (alpha,))
                else:
                    new_data.append(pixel)
            else:
                new_data.append(pixel)
        
        if count > 0:
            results[os.path.basename(img_path)] = count
            total_count += count
            log_message(f"{os.path.basename(img_path)}: {count} pixels with {target_rgb}")
            
            # Save if replacement was specified
            if replacement_rgb:
                img.putdata(new_data)
                img.save(img_path)
                log_message(f"  -> Fixed to {replacement_rgb}")
    
    log_message(f"\nTOTAL: {total_count} pixels with color {target_rgb} across all images")
    return results, total_count

# Example usage:
# color_mapping = {
#     (255, 0, 0): (0, 255, 0),  # Red to Green
#     (0, 0, 255): (255, 255, 0)  # Blue to Yellow
# }
# recolor_bitmap("path_to_image.bmp", color_mapping)

def main():
    global debug_log, active_window, active_log_element
    debug_log = []  # Clear debug log at start
    active_window = None
    active_log_element = None
    
    transparent_color = (255, 255, 255, 0)  # default RGBA for fully transparent
    main_color = (255,150,0,255)  # default RGBA for the main color (example: orange)
    shadow_color = (0, 0, 0, 255)  # default RGBA for the shadow color (example: black)
    original_colors = [transparent_color, main_color, shadow_color]
    recolored_images = []
    new_colors = []  # Example new colors (Red, Green, Blue)
    image_paths = get_images_from_folder()  # Get all image paths from the specified folders
    layout = [[sg.Text(f"Found {len(image_paths)} images. Do you want to recolor them?")],
              [sg.Button("Yes"), sg.Button("No"), sg.Button("Restore Default Colors")],
              [sg.Button("Count/Fix Specific Color"), sg.Button("View Debug Log")]]
    window = sg.Window("Bitmap Recolor", layout)
    event, values = window.read()
    window.close()
    choice = event
    if choice == 'Yes':
        # Create progress window with debug output
        layout = [
            [sg.Text("Processing images... Messages will appear below:")],
            [sg.Multiline(size=(70, 20), disabled=False, autoscroll=True, 
                          key='-DEBUG-', reroute_stdout=False, write_only=False)],
            [sg.Text("", key='-STATUS-')],
            [sg.Button("Close")]
        ]
        progress_window = sg.Window("Recolor Progress", layout, finalize=True, keep_on_top=True)
        
        # Set up global references for live updates
        active_window = progress_window
        active_log_element = '-DEBUG-'
        
        all_unique_colors = set()
    
        # 1. Scan all images first to build a master list of colors
        log_message("Scanning all images for unique colors...")
        for img_path in image_paths:
            colors = record_colors(img_path, original_colors)
            all_unique_colors.update(colors) # .update merges sets and keeps them unique
    
        log_message(f"Total unique colors across all images: {len(all_unique_colors)}")
        log_message("\nPlease select replacement colors in the color picker dialogs...")
        progress_window['-STATUS-'].update("Waiting for color selections...")

        # 2. Ask user for replacements ONCE for the master list
        # Use the original_colors list to prevent mapping TO a protected color
        color_map = prompt_user_for_colors(list(all_unique_colors), original_colors)

        progress_window['-STATUS-'].update("Applying colors to images...")
        log_message("\nApplying color mappings to images...")
        
        # 3. Apply the map to every image
        for img_path in image_paths:
            log_message(f"Processing: {os.path.basename(img_path)}")
            recolored_img = recolor_bitmap(img_path, color_map)
            recolored_images.append(recolored_img)
        
        log_message("\n=== RECOLORING COMPLETE === Click Close to continue.")
        progress_window['-STATUS-'].update("Complete!")
        
        # Wait for user to close
        while True:
            event, values = progress_window.read()
            if event in (sg.WIN_CLOSED, "Close"):
                break
        
        progress_window.close()
        active_window = None
        active_log_element = None
    if choice == 'Restore Default Colors':
        # Create progress window with debug output
        layout = [
            [sg.Text("Restoring colors... Messages will appear below:")],
            [sg.Multiline(size=(70, 20), disabled=False, autoscroll=True, 
                          key='-DEBUG-', reroute_stdout=False, write_only=False)],
            [sg.Button("Close")]
        ]
        progress_window = sg.Window("Restore Progress", layout, finalize=True, keep_on_top=True)
        
        # Set up global references for live updates
        active_window = progress_window
        active_log_element = '-DEBUG-'
        
        for path in image_paths:
            log_message(f"Restoring: {os.path.basename(path)}")
            restore_original_colors(path, original_colors, new_colors)
        
        log_message("\n=== RESTORE COMPLETE === Click Close to continue.")
        
        # Wait for user to close
        while True:
            event, values = progress_window.read()
            if event in (sg.WIN_CLOSED, "Close"):
                break
        
        progress_window.close()
        active_window = None
        active_log_element = None
    if choice == 'Count/Fix Specific Color':
        # Prompt for target color
        layout = [
            [sg.Text("Enter RGB color to search for:")],
            [sg.Text("R:"), sg.Input(key='R', size=(5,1)), 
             sg.Text("G:"), sg.Input(key='G', size=(5,1)), 
             sg.Text("B:"), sg.Input(key='B', size=(5,1))],
            [sg.Text("Replace with (leave blank to only count):")],
            [sg.Text("R:"), sg.Input(key='NewR', size=(5,1)), 
             sg.Text("G:"), sg.Input(key='NewG', size=(5,1)), 
             sg.Text("B:"), sg.Input(key='NewB', size=(5,1))],
            [sg.Button("Run"), sg.Button("Cancel")]
        ]
        window = sg.Window("Count/Fix Color", layout)
        event, values = window.read()
        window.close()
        
        if event == 'Run':
            try:
                target_rgb = (int(values['R']), int(values['G']), int(values['B']))
                
                # Create progress window with debug output
                layout = [
                    [sg.Text("Processing images... Messages will appear below:")],
                    [sg.Multiline(size=(70, 20), disabled=False, autoscroll=True, 
                                  key='-DEBUG-', reroute_stdout=False, write_only=False)],
                    [sg.Button("Close")]
                ]
                progress_window = sg.Window("Count/Fix Progress", layout, finalize=True, keep_on_top=True)
                
                # Set up global references for live updates
                active_window = progress_window
                active_log_element = '-DEBUG-'
                
                # Check if replacement color was provided
                if values['NewR'] and values['NewG'] and values['NewB']:
                    replacement_rgb = (int(values['NewR']), int(values['NewG']), int(values['NewB']))
                    log_message(f"Searching for {target_rgb} and replacing with {replacement_rgb}")
                    count_and_fix_specific_color(image_paths, target_rgb, replacement_rgb)
                else:
                    log_message(f"Counting pixels with color {target_rgb}")
                    count_and_fix_specific_color(image_paths, target_rgb)
                
                log_message("\n=== COMPLETE === Click Close to continue.")
                
                # Wait for user to close
                while True:
                    event, values = progress_window.read()
                    if event in (sg.WIN_CLOSED, "Close"):
                        break
                
                progress_window.close()
                active_window = None
                active_log_element = None
                
            except ValueError:
                sg.popup_error("Invalid RGB values entered!")
                log_message("Invalid RGB values entered!")
    if choice == 'View Debug Log':
        show_debug_log()
    if choice == 'No':
        return
    for recolored_image in recolored_images if len(recolored_images) > 0 else []:
        recolored_image.show()  # Display the recolored image

if __name__ == "__main__":    main()