"""
Speech bubble text cleaning using OpenCV.
Removes original text from detected bubbles using contour-aware inpainting.
"""

import cv2
import numpy as np
from contour import find_bubble_contour, get_contour_mask


def clean_bubble(image: np.ndarray, contour: np.ndarray) -> np.ndarray:
    """
    Clean text inside a speech bubble using its actual contour shape.

    Args:
        image: OpenCV image (BGR)
        contour: actual bubble contour points

    Returns:
        Image with text removed from inside the bubble
    """
    result = image.copy()

    # Create mask of bubble interior
    bubble_mask = get_contour_mask(contour, image.shape)

    # Erode bubble mask to avoid touching the border
    kernel = np.ones((7, 7), np.uint8)
    inner_mask = cv2.erode(bubble_mask, kernel, iterations=2)

    # Find dark pixels (text) within the inner bubble area
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Adaptive threshold for text detection within the bubble
    # Get the bubble's average brightness for adaptive threshold
    bubble_pixels = gray[inner_mask > 0]
    if len(bubble_pixels) == 0:
        return result

    bg_value = int(np.median(bubble_pixels[bubble_pixels > 150])) if np.any(bubble_pixels > 150) else 230
    threshold = min(bg_value - 40, 185)

    _, text_binary = cv2.threshold(gray, threshold, 255, cv2.THRESH_BINARY_INV)

    # Text mask = dark pixels inside the eroded bubble
    text_mask = cv2.bitwise_and(text_binary, inner_mask)

    # Dilate text mask to catch edges and anti-aliased pixels
    kernel_d = np.ones((4, 4), np.uint8)
    text_mask = cv2.dilate(text_mask, kernel_d, iterations=1)

    # Inpaint only where text was detected
    if np.any(text_mask > 0):
        inpainted = cv2.inpaint(result, text_mask, 7, cv2.INPAINT_TELEA)
        # Apply inpainting only within the bubble
        result[inner_mask > 0] = inpainted[inner_mask > 0]

    return result


def clean_bubble_fallback(image: np.ndarray, bbox: list[int],
                          padding: int = 6) -> np.ndarray:
    """
    Fallback rectangular cleaning when contour detection fails.
    """
    result = image.copy()
    x1, y1, x2, y2 = bbox
    h, w = image.shape[:2]

    x1 = max(0, x1 + padding)
    y1 = max(0, y1 + padding)
    x2 = min(w, x2 - padding)
    y2 = min(h, y2 - padding)

    if x2 <= x1 or y2 <= y1:
        return result

    region = result[y1:y2, x1:x2]
    if region.size == 0:
        return result

    gray = cv2.cvtColor(region, cv2.COLOR_BGR2GRAY)
    _, text_mask = cv2.threshold(gray, 180, 255, cv2.THRESH_BINARY_INV)

    kernel = np.ones((3, 3), np.uint8)
    text_mask = cv2.dilate(text_mask, kernel, iterations=1)

    inpainted = cv2.inpaint(region, text_mask, 5, cv2.INPAINT_TELEA)
    result[y1:y2, x1:x2] = inpainted
    return result


def clean_all_bubbles(image_path: str, bubbles: list[dict]) -> np.ndarray:
    """
    Clean all detected bubbles in a comic page.
    Detects actual contours and stores them in each bubble dict.
    """
    image = cv2.imread(image_path)
    if image is None:
        raise ValueError(f"Could not load image: {image_path}")

    for bubble in bubbles:
        contour = find_bubble_contour(image, bubble['bbox'])
        if contour is not None:
            bubble['_contour'] = contour
            image = clean_bubble(image, contour)
        else:
            bubble['_contour'] = None
            image = clean_bubble_fallback(image, bubble['bbox'])

    return image
