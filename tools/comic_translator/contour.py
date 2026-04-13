"""
Speech bubble contour detection using OpenCV.
Finds actual bubble shapes from approximate bounding boxes provided by Gemini.
"""

import cv2
import numpy as np


def find_bubble_contour(image: np.ndarray, bbox: list[int],
                        expand: int = 50) -> np.ndarray | None:
    """
    Find the actual speech bubble contour around an approximate bounding box.

    Args:
        image: full comic page (BGR)
        bbox: [x1, y1, x2, y2] approximate text area from Gemini
        expand: pixels to expand search area beyond bbox

    Returns:
        contour as np.ndarray of points in image coordinates, or None
    """
    h, w = image.shape[:2]
    x1, y1, x2, y2 = bbox

    # Expand search region to capture full bubble
    rx1 = max(0, x1 - expand)
    ry1 = max(0, y1 - expand)
    rx2 = min(w, x2 + expand)
    ry2 = min(h, y2 + expand)

    region = image[ry1:ry2, rx1:rx2]
    if region.size == 0:
        return None

    gray = cv2.cvtColor(region, cv2.COLOR_BGR2GRAY)

    # Threshold to find white/light regions (bubble interiors)
    _, binary = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY)

    # Clean up: close small gaps in bubble borders
    kernel = np.ones((3, 3), np.uint8)
    binary = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel, iterations=2)

    # Find contours
    contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL,
                                    cv2.CHAIN_APPROX_SIMPLE)
    if not contours:
        return None

    # Bbox center relative to region
    cx = (x1 + x2) // 2 - rx1
    cy = (y1 + y2) // 2 - ry1

    # Find contour that contains the bbox center and has largest area
    best = None
    best_area = 0
    for cnt in contours:
        if cv2.pointPolygonTest(cnt, (float(cx), float(cy)), False) >= 0:
            area = cv2.contourArea(cnt)
            if area > best_area:
                best = cnt
                best_area = area

    if best is None:
        # Fallback: find contour closest to center with reasonable area
        min_area = (x2 - x1) * (y2 - y1) * 0.3  # at least 30% of bbox area
        candidates = [(cnt, cv2.contourArea(cnt)) for cnt in contours
                       if cv2.contourArea(cnt) > min_area]
        if candidates:
            # Pick closest to center
            def dist_to_center(cnt):
                M = cv2.moments(cnt)
                if M["m00"] == 0:
                    return float('inf')
                mcx = int(M["m10"] / M["m00"])
                mcy = int(M["m01"] / M["m00"])
                return (mcx - cx) ** 2 + (mcy - cy) ** 2
            best = min(candidates, key=lambda x: dist_to_center(x[0]))[0]

    if best is None:
        return None

    # Shift contour back to full image coordinates
    best = best + np.array([rx1, ry1])

    # Smooth the contour slightly to reduce jaggedness
    epsilon = 0.005 * cv2.arcLength(best, True)
    best = cv2.approxPolyDP(best, epsilon, True)

    return best


def get_contour_widths(contour: np.ndarray, image_shape: tuple,
                        margin_pct: float = 0.10) -> dict[int, tuple[int, int]]:
    """
    For each Y row within the contour, get (left_x, right_x) usable bounds.

    Args:
        contour: bubble contour points
        image_shape: (height, width, ...) of the image
        margin_pct: inset from contour edge as fraction (0.10 = 10%)

    Returns:
        dict mapping Y -> (left_x, right_x) with margin applied
    """
    mask = np.zeros(image_shape[:2], dtype=np.uint8)
    cv2.drawContours(mask, [contour], 0, 255, -1)

    bb = cv2.boundingRect(contour)
    bx, by, bw, bh = bb

    widths = {}
    for row in range(by, by + bh):
        row_data = mask[row, bx:bx + bw]
        white = np.where(row_data > 0)[0]
        if len(white) >= 2:
            left = bx + white[0]
            right = bx + white[-1]
            span = right - left
            inset = int(span * margin_pct)
            widths[row] = (left + inset, right - inset)

    return widths


def get_contour_mask(contour: np.ndarray, image_shape: tuple) -> np.ndarray:
    """Create a filled binary mask from a contour."""
    mask = np.zeros(image_shape[:2], dtype=np.uint8)
    cv2.drawContours(mask, [contour], 0, 255, -1)
    return mask


def contour_center(contour: np.ndarray) -> tuple[int, int]:
    """Get the centroid of a contour."""
    M = cv2.moments(contour)
    if M["m00"] == 0:
        bb = cv2.boundingRect(contour)
        return bb[0] + bb[2] // 2, bb[1] + bb[3] // 2
    return int(M["m10"] / M["m00"]), int(M["m01"] / M["m00"])
