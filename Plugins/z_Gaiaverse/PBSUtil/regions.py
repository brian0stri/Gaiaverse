REGION_NAMES = {
    0: "Alpha",
    1: "Beta",
    2: "Gamma",
    3: "Delta"
}

REGION_NAMES = {v:k for k,v in REGION_NAMES.items()}

def normalize_region(region):

    if isinstance(region, int):
        return region

    if region in REGION_NAMES:
        return REGION_NAMES[region]

    raise Exception(f"Unknown region: {region}")

def region_name(region):
    region = normalize_region(region)

    return REGION_NAMES[region]