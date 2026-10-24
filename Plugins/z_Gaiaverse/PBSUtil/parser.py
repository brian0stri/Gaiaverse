import os
import csv
import json
import requests
from pathlib import Path
from models import Availability, Habitat, Rarity
from pbswriter import write_regional_dex
from regions import REGION_NAMES, normalize_region
from regions import region_name
from reporter import ValidationReport

def parse_availability(value):

    value = str(value).strip().lower()

    if value == "starter":
        return Availability.STARTER

    if value == "available":
        return Availability.AVAILABLE

    if value == "in dex":
        return Availability.IN_DEX

    if value == "evolution":
        return Availability.EVOLUTION
    
    if value == "in paradox":
        return Availability.IN_PARADOX

    if value == "unknown":
        return Availability.UNKNOWN

    return Availability.UNAVAILABLE

def contributes_to_dex(availability):
    return availability in {
        Availability.AVAILABLE,
        Availability.STARTER,
        Availability.IN_DEX
    }

def contributes_to_encounters(availability):
    return availability in {
        Availability.AVAILABLE,
        Availability.STARTER,
        Availability.IN_DEX
    }

def parse_bool(value):
    return str(value).strip().lower() in ["true","1","yes","y"]

def normalize_row(row):
    return {k.strip(): (v.strip() if v else "") for k, v in row.items()}

def get_json_from_folder():
    # 1. Get the directory where bitmapRecolor.py sits (.../imageUtil)
    base_dir = os.path.dirname(os.path.abspath(__file__))
    
    # 2. Go UP one level to the plugin root (.../LevelSync)
    plugin_root = os.path.dirname(base_dir)
    
    # 3. Go DOWN into the Graphics folder
    target_folder = os.path.join(plugin_root, "PBSUtil")
    
    print(f"Checking path: {target_folder}") # Helpful for debugging

    if not os.path.exists(target_folder):
        print("Folder not found. Check your folder structure!")
        return []

    return os.path.join(target_folder, "variant_rules.json")

URL = "https://docs.google.com/spreadsheets/d/e/2PACX-1vSE9CUnhIqpUF7UCYTX2SdsZM4NoL3jOWqrZp-QDY47meET-cr6lTAOkt7FRFMrWPqgLLLZKDHBngib/pub?output=csv"

rules = json.load(open(get_json_from_folder()))

SPECIES_ALIASES = {
    "NIDORAN M": "NIDORANmA",
    "NIDORAN♂": "NIDORANmA",
    "NIDORAN MALE": "NIDORANmA",
    "NIDORANMA" : "NIDORANmA",

    "NIDORAN F": "NIDORANfE",
    "NIDORAN♀": "NIDORANfE",
    "NIDORAN FEMALE": "NIDORANfE",
    "NIDORANFE" : "NIDORANfE",

    "FARFETCH\'D" : "FARFETCHD",
    "SIRFETCH\'D" : "SIRFETCHD",

    "MR.MIME" : "MRMIME",
    "MR. MIME" : "MRMIME",
    "MR MIME" : "MRMIME",

    "TYPE:NULL" : "TYPENULL",
    "TYPE NULL" : "TYPENULL",
    "JANGMO-O" : "JANGMOO",
    "JANGMOo" : "JANGMOO",
    "HAKAMO-O" : "HAKAMOO",
    "HAKAMOo" : "HAKAMOO",
    "KOMMO-O" : "KOMMOO",
    "KOMMOo" : "KOMMOO",
    "MIME JR." : "MIMEJR",
    "MIME JR" : "MIMEJR",
    "TAPU KOKO" : "TAPUKOKO",
    "TAPU LELE" : "TAPULELE",
    "TAPU BULU" : "TAPUBULU",
    "TAPU FINI" : "TAPUFINI",
    "MR RIME" : "MRRIME",
    "MR. RIME" : "MRRIME",
    "FLABÉBÉ" : "FLABEBE",
    "FLABÃ©BÃ©" : "FLABEBE",
    "PORYGON-Z" : "PORYGONZ",

}

data = requests.get(URL).text.splitlines()
reader = csv.DictReader(data)
headers = reader.fieldnames

region_columns = {}

region_columns = {}

for header in headers:

    if header.startswith("Region "):

        region_name = header.replace("Region ", "").strip()

        print(f"Found region column: {region_name} in header '{header}'")

        region_columns[region_name] = {
            "availability": header
        }

print("Detected regions:", region_columns)
print(reader.fieldnames)

def parse_array(value):
    if not value:
        return []
    
    value.strip()
    
    value = value.replace("[","").replace("]","")

    parts = value.split(",")

    result = []

    for p in parts:
        p = p.strip()

        if not p:
            continue

        result.append(float(p))

    return result

def parse_time_mult_array(value):

    arr = parse_array(value)

    if not arr:
        return [1,1,1,1]

    return arr

def parse_region_mult_array(value):
    
    arr = parse_array(value)
    if not arr:
        return [1,1,1,1]

    return arr

def parse_rod_mult_array(value):

    arr = parse_array(value)
    if not arr:
        return [1,1,1]

    return arr

def load_pbs_folder():
    project_root = Path(__file__).parents[3]

    target_folder = os.path.join(project_root, "PBS")

    print (f"Checking path: {target_folder}")

    if not project_root.exists():
        print("Folder not found")
        return []

    return os.path.join(target_folder, "pokemon.txt")

def parse_dex_number(value):
    if value == "":
        return None

    value = value.strip()

    if not value.isdigit():
        raise Exception(f"Invalid dex number: '{value}'")

    return int(value)

def load_species_index(path):
    species = {}

    current = None

    with open(path, encoding="utf8") as f:
        for line in f:
            line = line.strip()

            if line.startswith("[") and line.endswith("]"):
                current = line[1:-1]
                species[current] = {}

            elif "=" in line and current:
                key,val = [x.strip() for x in line.split("=",1)]
                species[current][key] = val

    return species

def write_encounter_json(data):

    project_root = Path(__file__).parents[3]
    output_path = project_root / "PBS" / "encounter_data.json"

    with open(output_path, "w", encoding="utf8") as f:
        json.dump(data, f, indent=2)

    print(f"Encounter data written to {output_path}")

def validate_species(species, form, region, pbs, rules, availability, report):

    if species not in pbs:
        report.warnings.append(f"{species} not found in pokemon.txt")

    # Evolution entries bypass region legality
    if availability in {
        Availability.IN_DEX,
        Availability.EVOLUTION,
        Availability.IN_PARADOX,
        Availability.UNKNOWN
    }:
        return

    if species in rules:
        allowed = rules[species].get(str(form), [])

        if region not in allowed:
            report.warnings.append(
                f"{species} form {form} illegal in {region}"
            )
        
def validate_duplicate_dex(entries, pbs, report):

    seen_dex = {}

    for entry in entries:

        availability = entry["availability"]
        dex = entry["dex"]
        region = entry["region"]
        species = entry["species"]

        # UNKNOWN entries don't participate in dex numbering
        if availability == Availability.UNKNOWN:
            continue

        # EVOLUTION entries may lack dex numbers
        if dex is None and availability == Availability.EVOLUTION:
            continue

        if dex is None:
            report.missing_dex.append(
                f"{species} missing dex number in region {REGION_NAMES.get(region, region)}"
            )
            continue

        dex_key = (region, dex)

        if dex_key not in seen_dex:
            seen_dex[dex_key] = species
            continue

        if seen_dex[dex_key] != species:
            report.duplicate_dex.append(
                f"Duplicate dex number {dex} in region {REGION_NAMES.get(region, region)}: "
                f"{seen_dex[dex_key]} and {species}"
        )

def validate_dex_gaps(entries, pbs, report):

    region_dex = {}
    species_by_region_dex = {}
    

    for entry in entries:

        if entry["dex"] is None:
            continue

        region = entry["region"]
        species = entry["species"]

        region_dex.setdefault(region, []).append(entry["dex"])
        species_by_region_dex.setdefault((region, entry["dex"]), set()).add(species)

    for region, numbers in region_dex.items():

        numbers = sorted(numbers)

        for i in range(len(numbers) - 1):

            if numbers[i+1] != numbers[i] + 1 and (species_by_region_dex[(region, numbers[i+1])]) != (species_by_region_dex[(region, numbers[i])]):

                report.warnings.append(
                    f"Warning: Region {REGION_NAMES.get(region, region)} skipped dex number "
                    f"{numbers[i]+1} between {numbers[i]} and {numbers[i+1]}"
                )
                if region not in report.dex_gaps:
                    report.dex_gaps[region] = []
                    for gap in range(numbers[i]+1, numbers[i+1]):
                        if gap not in report.dex_gap_nos:
                            report.dex_gap_nos.add(gap)
                            report.dex_gaps[region].append(f"{gap} between {numbers[i]} and {numbers[i+1]}")
                            report.warnings.append(f"Added dex gap: {gap} in region {REGION_NAMES.get(region, region)}")
                report.dex_gaps[region].append(f"{numbers[i]+1} between {numbers[i]} and {numbers[i+1]}")
                report.warnings.append(f"Added dex gap: {gap} in region {REGION_NAMES.get(region, region)}")

def build_evolution_map(pbs):

    evo_map = {}

    for species, data in pbs.items():

        evo_line = data.get("Evolutions")

        if not evo_line:
            continue

        target = evo_line.split(",")[0]

        evo_map.setdefault(species,set()).add(target)
        evo_map.setdefault(target,set()).add(species)

    return evo_map

def validate_evolution_families(entries, pbs, report):

    evo_map = build_evolution_map(pbs)

    species_regions = {}

    for entry in entries:
        species_regions.setdefault(entry["species"], set()).add(entry["region"])

    for species in species_regions:

        if species not in evo_map:
            continue

        for evo in evo_map[species]:

            if evo not in species_regions:
                continue

            if species_regions[species] != species_regions[evo]:

                report.warnings.append(
                    f"Warning: Evolution family split across regions: "
                    f"{species} {species_regions[species]} → "
                    f"{evo} {species_regions[evo]}"
                )

def validate_evolution_order(entries, pbs, report):

    evo_map = build_evolution_map(pbs)

    region_species_order = {}

    for i, entry in enumerate(entries):

        if entry["dex"] is None:
            continue

        region = entry["region"]
        species = entry["species"]

        region_species_order.setdefault(region, {})
        region_species_order[region][species] = i

    for region, species_positions in region_species_order.items():

        for species in species_positions.items():

            if species not in evo_map:
                report.warnings.append(
                    f"Warning: Species {species} in region {REGION_NAMES.get(region, region)} has no evolution data in pokemon.txt"
                )
                continue

            for evo in evo_map[species]:

                if evo not in species_positions:
                    continue

def parse_habitats(value):

    if not value:
        return []

    habitats = []

    for h in value.split(","):

        h = h.strip().lower()

        try:
            habitats.append(Habitat(h))
        except ValueError:
            report.warnings.append(f"Unknown habitat '{h}' in value '{value}'") 
            continue

    return habitats

def get_power_tier(bst):

    if bst < 350:
        return "EARLY"

    if bst < 450:
        return "MID"

    if bst < 550:
        return "LATE"

    return "STRONG"

def bst_lookup_from_pbs(pbs):

    bst_lookup = {}

    for species, data in pbs.items():

        stats = data.get("BaseStats")

        if not stats:
            continue

        bst = sum(int(x) for x in stats.split(",") if x.isdigit())
        bst_lookup[species] = bst
        print(f"Computed bst: {bst} for species {species}")

    return bst_lookup

def resolve_habitats(habitats):

    resolved = []

    for h in habitats:

        if h == Habitat.ALLLAND:
            resolved.extend(Habitat.ALLLANDCONTAINER)
        if h == Habitat.UNKNOWN:
            continue
        else:
            resolved.append(h)

    return resolved

def build_ticket_table(pools):

    tables = {}

    for region, habitats in pools.items():

        tables.setdefault(region, {})
        print(f"Building ticket table for region {REGION_NAMES.get(region, region)} with habitats: {list(habitats.keys())}")

        for habitat, entries in habitats.items():

            if habitat == Habitat.UNKNOWN.value:
                continue
    
            species = []
            weights = []

            total = 0

            for e in entries:
                print("Entry Debug:", e, type(e))
                tickets = int(e["tickets"])
                print(f"adding {tickets} data type {type(tickets)}")
                total += tickets
                species.append((e["species"], e["form"]))
                weights.append(total)

            tables[region][habitat] = {
                "species": species,
                "weights": weights,
                "total": total
            }

    return tables

def build_biome_pools(encounter_data, bst_lookup):

    pools = {}

    for e in encounter_data.values():

        species = e["species"]
        form = e["form"]
        tickets = e["tickets"]
        regions = e.get("regions",[])
        habitats = resolve_habitats(e.get("habitats", []))

        bst = bst_lookup.get(species)

        #print(species, type(species))
        #print("BST lookup result:", bst_lookup.get(species))

        if bst is None:
            continue

        if habitats == [Habitat.UNKNOWN]:
            continue

        for region in regions:
           for habitat in habitats:
                    pools\
                        .setdefault(region, {})\
                        .setdefault(habitat, [])\
                        .append({
                        "species": species,
                        "form": form,
                        "tickets": tickets
                    })

    return pools

def write_biome_json(data):

    output_path = "ProjectLSync/PBS/biome_pools.json"

    with open(output_path, "w", encoding="utf8") as f:
        json.dump(data, f, indent=2)
    
    print(f"Biome pools written to {output_path}")

def rarity_from_tickets(tickets):

    if tickets >= 50:
        return Rarity.COMMON

    if tickets >= 25:
        return Rarity.UNCOMMON

    if tickets >= 10:
        return Rarity.RARE

    return Rarity.ULTRA_RARE

def auto_assign_dex(entries):

    region_next_dex = {}
    species_dex = {}

    for entry in entries:

        if not contributes_to_dex(entry["availability"]):
            continue

        region = entry["region"]
        species = entry["species"]

        if region not in region_next_dex:
            region_next_dex[region] = 1
            species_dex[region] = {}

        # if species already got a dex number, reuse it
        if species in species_dex[region]:
            entry["dex"] = species_dex[region][species]
            continue

        dex = region_next_dex[region]
        species_dex[region][species] = dex
        entry["dex"] = dex

        region_next_dex[region] += 1

def build_evolution_families(pbs):

    print("Using UNION-FIND family builder")

    parent = {}

    # initialize each species as its own parent
    for species in pbs.keys():
        parent[species] = species

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra = find(a)
        rb = find(b)
        if ra != rb:
            parent[rb] = ra

    # connect evolutions
    for species, data in pbs.items():

        evo_line = data.get("Evolutions")

        if not evo_line:
            continue

        parts = evo_line.split(",")

        # every 3rd entry is a target species
        for i in range(0, len(parts), 3):

            target = parts[i]

            if target not in parent:
                continue

            union(species, target)

    # group by root
    families = {}

    for species in pbs.keys():

        root = find(species)

        families.setdefault(root, []).append(species)

    return list(families.values())

def build_evolution_graph(pbs):

    evo_graph = {}

    for species, data in pbs.items():

        evo_line = data.get("Evolutions")

        if not evo_line:
            continue

        target = evo_line.split(",")[0]

        evo_graph.setdefault(species, []).append(target)

    return evo_graph

def find_base_species(pbs):

    children = set()

    for data in pbs.values():

        evo_line = data.get("Evolutions")

        if evo_line:
            children.add(evo_line.split(",")[0])

    bases = []

    for species in pbs:

        if species not in children:
            bases.append(species)

    return bases

def order_family(family, pbs):

    children = set()

    for s in family:
        evo = pbs.get(s, {}).get("Evolutions")

        if not evo:
            continue

        target = evo.split(",")[0]

        children.add(target)

    # base species = not evolved from anything
    bases = [s for s in family if s not in children]

    ordered = []
    queue = bases[:]

    while queue:

        s = queue.pop(0)
        ordered.append(s)

        evo = pbs.get(s, {}).get("Evolutions")

        if not evo:
            continue

        target = evo.split(",")[0]

        if target in family:
            queue.append(target)

    return ordered


def normalize_species(name):
    name = name.strip().upper()

    if name in SPECIES_ALIASES:
        return SPECIES_ALIASES[name]

    name = name.replace(".", "")
    name = name.replace(":", "")
    name = name.replace("-", "")
    name = name.replace(" ", "")

    return name

def validate_paradox_habitats(entries, pbs, report):

    for entry in entries:

        habitats = entry.get("habitats", [])
        availability = entry.get("availability")

        paradox_habitats = [h for h in habitats if "paradox" in h]

        if paradox_habitats and availability != Availability.INPARADOX:

            report.warnings.append(
                f"{entry['species']} has paradox habitat {paradox_habitats} but is not INPARADOX"
            )

pbs = load_species_index(load_pbs_folder())

report = ValidationReport()

entries = []

row_count = 0

VALIDATORS = [
    validate_duplicate_dex,
    validate_dex_gaps,
    validate_evolution_families,
    validate_evolution_order,
    validate_paradox_habitats,
]

encounter_data = {}

for row in reader:
    row_count += 1
    row = {k.strip(): (v.strip() if v else "") for k, v in row.items()}

    species = normalize_species(row["Name"])
    form_value = row.get("Form Number","").strip()
    form = int(form_value) if form_value else 0

    habitats = parse_habitats(row.get("Habitats", ""))
    region_mult_array = parse_region_mult_array(row.get("RegionMults", ""))
    rod_mult_array = parse_rod_mult_array(row.get("RodMults", ""))
    time_mult_array = parse_time_mult_array(row.get("TimeMults", ""))
    is_event_only = "unknown" in habitats
    print(species, habitats, region_mult_array, rod_mult_array, time_mult_array)
    

    tickets = int(row.get("Tickets") or 0)
    available_count = 0

    species_key = f"{species}_{form}" if form else species

    enc_entry = None
    
    if not is_event_only:

        enc_entry = encounter_data.setdefault(species_key, {
            "species": species,
            "form": form,
            "habitats": [h.value for h in habitats],
            "availability": [],
            "regions" : [],
            "tickets": tickets,
            "region_mult": region_mult_array,
            "rod_mult": rod_mult_array,
            "time_mult": time_mult_array,
        })

    for region_name, columns in region_columns.items():
        region_id = normalize_region(region_name)

        #print(region_name, repr(row.get(columns["availability"])))
        availability = parse_availability(
            row.get(columns["availability"], "")
        )

        if enc_entry and contributes_to_encounters(availability):
            enc_entry["regions"].append(region_id)
            enc_entry["availability"].append(availability.value)

        dex_value = None

        if not contributes_to_encounters(availability):
            continue

        validate_species(species, form, region_name, pbs, rules, availability, report)

        available_count += 1

        entries.append({
            "region": region_id,
            "dex": dex_value,
            "species": species,
            "form": form,
            "availability": availability,
            "available_count" : available_count,
            "biomes": []
        })

auto_assign_dex(entries)

for e in entries: 
    if e["dex"] is None and contributes_to_dex(e["availability"]):
        report.warnings.append(("Missing dex:", e))
        print("Critical error: Missing dex number for available species. Build cannot continue.")
        break

for entry in entries:

    region = entry["region"]
    species = entry["species"]
    form = entry["form"]
    region_name_str = region
    habitats = entry.get("habitats", [])
    stats = entry.get("stats", "")


bst_lookup = bst_lookup_from_pbs(pbs)

pools = build_biome_pools(encounter_data, bst_lookup)

for e in entries:
    if e["dex"] is None and contributes_to_dex(e["availability"]):
        report.warnings.append(("Missing dex:", e))

report.rows_read = row_count

for validator in VALIDATORS:
    validator(entries, pbs, report)

report.entries_parsed = len(entries)
report.regions_detected = len(region_columns)

if report.duplicate_dex or report.missing_dex:
    
    print("\nBuild failed due to critical dex errors.")
    report.write_full_report(entries, pbs)
    exit(1)

families = build_evolution_families(pbs)

families = [order_family(f, pbs) for f in families]

written = write_regional_dex(entries, families)

report.entries_written = written

report.write_full_report(entries, pbs, path="ProjectLSync/PBS/dex_build_report.txt")

write_encounter_json(encounter_data)

def write_biome_json(data):

    output_path = "ProjectLSync/PBS/biome_pools.json"

    with open(output_path, "w", encoding="utf8") as f:
        json.dump(data, f, indent=1, separators=(",", ":"))
    
    print(f"Biome pools written to {output_path}")

spawn_tables = build_ticket_table(pools)

write_biome_json(spawn_tables)

report.write_spawn_tables(spawn_tables)