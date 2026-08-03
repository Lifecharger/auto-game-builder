"""Re-generate wardrobe garments that came out WITH a baked human body/mannequin.

Same slugs/categories as batch_garments.py — files are overwritten in place.
Prompt is hardened to garment-shell-only (Meshy has no negative prompt field;
exclusions are baked into the positive prompt).
"""

import batch_garments as bg

SHELL2 = (
    "single hollow garment shell floating in empty space, ghost mannequin "
    "product style, worn shape with empty interior visible through the neck "
    "and hem openings, ABSOLUTELY NO human body, no skin, no breasts, no "
    "torso, no legs, no head, no neck, no mannequin, no stand, fabric only, "
    "thin single layer cloth, game asset"
)

ITEMS = [
    ("tops", "crop_halter", "halter neck crop top"),
    ("tops", "crop_offshoulder", "off-shoulder crop top"),
    ("tops", "crop_tank", "cropped tank top with thin straps"),
    ("tops", "crop_tube", "strapless tube crop top"),
    ("tops", "shirt_fitted_button", "fitted button-up shirt with open collar"),
    ("tops", "shirt_offshoulder", "off-shoulder loose blouse"),
    ("tops", "shirt_sleeveless", "sleeveless collared shirt"),
    ("tops", "shirt_vneck_blouse", "silk blouse with deep v neckline"),
    ("tops", "tshirt_scoop", "scoop neck fitted t-shirt"),
    ("bottoms", "skirt_pencil_mini", "tight pencil mini skirt"),
    ("bottoms", "skirt_pleated_mini", "short pleated mini skirt"),
    ("bottoms", "skirt_ruffle_layers", "layered ruffled mini skirt with three tiers"),
    ("underwear", "bralette", "delicate bralette with scalloped edges"),
    ("underwear", "briefs_highwaist", "high waist briefs"),
]

if __name__ == "__main__":
    bg.SHELL = SHELL2
    bg.ITEMS = ITEMS
    bg.main()
