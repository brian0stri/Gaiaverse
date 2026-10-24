from importlib.resources import path

from models import Availability


class ValidationReport:

    def __init__(self):
        self.dex_gaps = {}
        self.dex_gap_nos = set()
        self.evo_splits = []
        self.illegal_forms = []
        self.duplicate_dex = []
        self.duplicate_species = []
        self.missing_dex = []
        self.warnings = []
        self.REPORT_SECTIONS = [
            "_write_summary",
            "_write_region_distribution",
            "_write_region_combination_matrix",
            "_write_signature_species",
            "_write_strong_signature_species",
            "_write_type_distribution",
            "_write_bst_analysis",
            "_write_power_tiers",
            "_write_power_curve_chart",
        ]

        self.entries_parsed = 0
        self.entries_written = 0
        self.regions_detected = 0
        self.rows_read = 0
    
    def _is_special_species(self, species, pbs):

        data = pbs.get(species)

        if not data:
            return False

        flags = data.get("Flags", "")

        flag_list = [f.strip() for f in flags.split(",")]

        return any(f in ["Legendary", "Mythical", "Paradox"] for f in flag_list)

    def write_full_report(self, entries, pbs, path="ProjectLSync/PBS/dex_build_report.txt"):

        print("write_full_report() called")

        with open(path, "w", encoding="utf8") as f:

            for section in self.REPORT_SECTIONS:
                getattr(self, section)(entries, pbs, f)

        print(f"Dex analysis written to {path}")

    def _write_summary(self, entries, pbs, f):

        f.write("\nDex Build Report\n")
        f.write("----------------\n")

        f.write(f"Entries parsed:   {self.entries_parsed}\n")
        f.write(f"Entries written:  {self.entries_written}\n")
        f.write(f"Regions detected: {self.regions_detected}\n")
        f.write(f"Rows read:       {self.rows_read}\n")

        f.write("\n")

        f.write(f"Dex gaps:          {sum(len(v) for v in self.dex_gaps.values())}\n")
        f.write(f"Evolution splits:  {len(self.evo_splits)}\n")
        f.write(f"Illegal forms:     {len(self.illegal_forms)}\n")
        f.write(f"Duplicate dex:     {len(self.duplicate_dex)}\n")
        f.write(f"Duplicate species: {len(self.duplicate_species)}\n")
        f.write(f"Missing Dex:       {len(self.missing_dex)}\n")
                

        if any([self.dex_gaps, self.evo_splits,
            self.illegal_forms, self.duplicate_dex]):

            f.write("\nDetails\n")

            for region, gaps in self.dex_gaps.items():
                for gap in gaps:
                    f.write(f"Dex Gap in {region}: {gap}\n")

            for w in self.evo_splits:
                f.write(f"Evolution: {w}\n")

            for w in self.illegal_forms:
                f.write(f"Illegal Form: {w}\n")

            for w in self.duplicate_dex:
                f.write(f"Duplicate Dex: {w}\n")

            for w in self.duplicate_species:
                f.write(f"Duplicate Species: {w}\n")

            for w in self.missing_dex:
                f.write(f"Missing Dex Nos: {w}\n")

            for w in self.warnings:
                f.write(f"Warning: {w}\n")

        else:
            f.write("\nNo validation issues detected.\n")

    def _write_region_distribution(self, entries, pbs, f):

        f.write("\nRegional Distribution\n")
        f.write("---------------------\n")

        region_counts = {}

        for e in entries:
            if e["dex"] is None:
                continue

            if self._is_special_species(e["species"], pbs):
                continue

            region_counts.setdefault(e["region"], set()).add(e["species"])

        for region, species in sorted(region_counts.items()):
            f.write(f"Region {region}: {len(species)} species\n")

        f.write("\n")
    
    def _write_region_combination_matrix(self, entries, pbs, f):

        f.write("\nRegional Combination Matrix\n")
        f.write("---------------------------\n\n")

        species_regions = {}

        for e in entries:

            if e["availability"] != Availability.AVAILABLE:
                continue

            species = e["species"]
            region = e["region"]

            if self._is_special_species(species, pbs):
                continue

            species_regions.setdefault(species, set()).add(region)

        combo_counts = {}

        for regions in species_regions.values():

            mask = 0

            for r in regions:
                mask |= (1 << r)

            combo_counts[mask] = combo_counts.get(mask, 0) + 1

        f.write("Mask  R0 R1 R2 R3  Count\n")
        f.write("-------------------------\n")

        for mask in range(1, 16):

            r0 = 1 if mask & 1 else 0
            r1 = 1 if mask & 2 else 0
            r2 = 1 if mask & 4 else 0
            r3 = 1 if mask & 8 else 0

            count = combo_counts.get(mask, 0)

            f.write(f"{mask:04b}   {r0}  {r1}  {r2}  {r3}   {count}\n")
    
    def _write_signature_species(self, entries, pbs, f):

        f.write("\nRegional Signature Species\n")
        f.write("--------------------------\n\n")

        species_regions = {}

        for e in entries:

            if e["availability"] != Availability.AVAILABLE:
                continue

            if self._is_special_species(e["species"], pbs):
                continue

            species = e["species"]
            region = e["region"]

            species_regions.setdefault(species, set()).add(region)

        region_unique = {0: [], 1: [], 2: [], 3: []}

        for species, regions in species_regions.items():

            if len(regions) == 1:

                r = next(iter(regions))

                region_unique[r].append(species)

        for r in sorted(region_unique):

            mons = sorted(region_unique[r])

            f.write(f"Region {r} Unique ({len(mons)})\n")

            for m in mons[:20]:   # limit so report doesn't explode
                f.write(f"  {m}\n")

            if len(mons) > 20:
                f.write(f"  ... ({len(mons)-20} more)\n")

            f.write("\n")

    def _write_type_distribution(self, entries, pbs, f):

        f.write("Type Distribution\n")
        f.write("-----------------\n")

        region_types = {}

        for e in entries:

            if e["dex"] is None:
                continue

            region = e["region"]
            species = e["species"]

            if self._is_special_species(species, pbs):
                continue

            data = pbs.get(species, {})

            types = data.get("Types")

            if not types:
                continue

            type_list = [t.strip() for t in types.split(",")]

            for t in type_list:

                region_types.setdefault(region, {})

                region_types[region][t] = region_types[region].get(t, 0) + 1

        MAX_BAR = 20

        # find the largest count across all regions
        max_count = max(
            count
            for region in region_types
            for count in region_types[region].values()
        )

        all_types = sorted({t for r in region_types for t in region_types[r]})

        for t in all_types:

            f.write(f"{t}\n")

            for region in sorted(region_types):

                count = region_types[region].get(t, 0)

                filled = int((count / max_count) * MAX_BAR)

                bar = "█" * filled + "░" * (MAX_BAR - filled)

                percent = int((count / max_count) * 100)

                f.write(f"R{region} [{bar}] {count} ({percent}%)\n")

        f.write("\n")
            
    def _write_strong_signature_species(self, entries, pbs, f):

        f.write("\nStrong Signature Pokémon\n")
        f.write("------------------------\n\n")

        species_regions = {}

        for e in entries:

            if e["availability"] != Availability.AVAILABLE:
                continue

            species = e["species"]
            region = e["region"]

            if self._is_special_species(species, pbs):
                continue

            species_regions.setdefault(species, set()).add(region)

        region_strong = {0: [], 1: [], 2: [], 3: []}

        for species, regions in species_regions.items():

            if len(regions) != 1:
                continue

            data = pbs.get(species)
            if not data:
                continue

            stats = data.get("BaseStats")
            if not stats:
                continue

            bst = sum(int(x) for x in stats.split(","))

            r = next(iter(regions))

            region_strong[r].append((species, bst))

        for r in sorted(region_strong):

            mons = sorted(region_strong[r], key=lambda x: x[1], reverse=True)

            f.write(f"Region {r}\n")

            for species, bst in mons[:10]:
                f.write(f"{species:<15} {bst}\n")

        f.write("\n")
        

    def _write_bst_analysis(self, entries, pbs, f):

        f.write("\nBST Analysis\n")
        f.write("------------\n\n")

        region_all = {}
        region_first = {}
        region_final = {}

        evolves_to = set()
        evolves_from = set()

        # determine evolution relationships
        for species, data in pbs.items():

            evo = data.get("Evolutions")

            if not evo:
                continue

            parts = evo.split(",")

            for i in range(0, len(parts), 3):

                target = parts[i].strip()

                evolves_to.add(species)
                evolves_from.add(target)

        for entry in entries:

            region = entry["region"]
            species = entry["species"]

            data = pbs.get(species)

            if not data:
                continue

            stat_line = data.get("BaseStats")

            if not stat_line:
                continue

            if entry["availability"] != Availability.AVAILABLE:
                continue

            if self._is_special_species(species, pbs):
                continue

            stats = [int(x.strip()) for x in stat_line.split(",")]
            bst = sum(stats)

            region_all.setdefault(region, []).append((species, bst))

            # first stage = evolves but nothing evolves into it
            if species in evolves_to and species not in evolves_from:
                region_first.setdefault(region, []).append(bst)

            # final stage = something evolves into it but it evolves into nothing
            if species in evolves_from and species not in evolves_to:
                region_final.setdefault(region, []).append(bst)

        for region in sorted(region_all):

            values = region_all[region]
            bst_values = [v for _, v in values]

            avg_all = sum(bst_values) // len(bst_values)

            first_vals = region_first.get(region, [])
            final_vals = region_final.get(region, [])

            avg_first = sum(first_vals) // len(first_vals) if first_vals else 0
            avg_final = sum(final_vals) // len(final_vals) if final_vals else 0

            lowest = min(values, key=lambda x: x[1])
            highest = max(values, key=lambda x: x[1])

            f.write(f"Region {region}\n")
            f.write(f"Average BST (all):          {avg_all}\n")
            f.write(f"Average BST (first-stage):  {avg_first}\n")
            f.write(f"Average BST (final stage):  {avg_final}\n")
            f.write(f"Lowest BST: {lowest[1]} ({lowest[0]})\n")
            f.write(f"Highest BST: {highest[1]} ({highest[0]})\n\n")

    def _write_bst_histogram(self, entries, pbs, f):

        f.write("\nBST Histogram\n")
        f.write("-------------\n\n")

        bins = [
            (0, 299),
            (300, 399),
            (400, 499),
            (500, 599),
            (600, 699),
            (700, 999)
        ]

        region_bins = {}

        for entry in entries:

            if entry["availability"] != Availability.AVAILABLE:
                continue

            region = entry["region"]
            species = entry["species"]

            data = pbs.get(species)
            if not data:
                continue

            stat_line = data.get("BaseStats")
            if not stat_line:
                continue

            if self._is_special_species(species, pbs):
                continue

            # optional legendary filter
            flags = data.get("Flags", "")
            flag_list = [f.strip() for f in flags.split(",")]

            if any(f in ["Legendary", "Mythical", "Paradox"] for f in flag_list):
                continue

            stats = [int(x.strip()) for x in stat_line.split(",")]
            bst = sum(stats)

            region_bins.setdefault(region, [0] * len(bins))

            for i, (low, high) in enumerate(bins):
                if low <= bst <= high:
                    region_bins[region][i] += 1
                    break

        # print table
        header = "Range      " + "  ".join(f"R{r}" for r in sorted(region_bins))
        f.write(header + "\n")
        f.write("-" * len(header) + "\n")

        for i, (low, high) in enumerate(bins):

            label = f"{low}-{high}" if high < 900 else "700+"

            line = f"{label:<10}"

            for region in sorted(region_bins):
                line += f"{region_bins[region][i]:>4}"

            f.write(line + "\n")

    def _write_power_tiers(self, entries, pbs, f):

        f.write("\nPower Tier Histogram\n")
        f.write("--------------------\n\n")

        tiers = [
            ("Low (<350)", 0, 349),
            ("Mid (350–449)", 350, 449),
            ("Strong (450–549)", 450, 549),
            ("High (550–599)", 550, 599),
            ("Elite (600-649)", 600,649),
            ("Apex (650+)", 650, 999)
        ]

        region_counts = {}

        for entry in entries:

            if entry["availability"] != Availability.AVAILABLE:
                continue

            region = entry["region"]
            species = entry["species"]

            data = pbs.get(species)
            if not data:
                continue

        # filter special Pokémon
            if self._is_special_species(species, pbs):
                continue
        
            stat_line = data.get("BaseStats")
            if not stat_line:
                continue

            stats = [int(x.strip()) for x in stat_line.split(",")]
            bst = sum(stats)

            region_counts.setdefault(region, [0]*len(tiers))

            for i, (_, low, high) in enumerate(tiers):
                if low <= bst <= high:
                    region_counts[region][i] += 1
                    break

        header = "Tier              " + " ".join(f"R{r:>3}" for r in sorted(region_counts))
        f.write(header + "\n")
        f.write("-"*len(header) + "\n")

        for i, (name, _, _) in enumerate(tiers):

            line = f"{name:<18}"

            for region in sorted(region_counts):
                line += f"{region_counts[region][i]:>4}"

            f.write(line + "\n")

    def _write_power_curve_chart(self, entries, pbs, f):

        f.write("\nRegional BST Power Curve\n")
        f.write("------------------------\n\n")

        bins = [
            ("200–299", 200, 299),
            ("300–399", 300, 399),
            ("400–499", 400, 499),
            ("500–599", 500, 599),
            ("600–699", 600, 699),
        ]

        region_bins = {}

        for entry in entries:

            if entry["availability"] != Availability.AVAILABLE:
                continue

            region = entry["region"]
            species = entry["species"]

            data = pbs.get(species)
            if not data:
                continue

            flags = data.get("Flags", "")
            flag_list = [x.strip() for x in flags.split(",")]

            if self._is_special_species(species, pbs):
                continue

            stats = data.get("BaseStats")
            if not stats:
                continue

            bst = sum(int(x) for x in stats.split(","))

            region_bins.setdefault(region, [0]*len(bins))

            for i, (_, low, high) in enumerate(bins):
                if low <= bst <= high:
                    region_bins[region][i] += 1
                    break

        max_value = max(
            count
            for region in region_bins
            for count in region_bins[region]
        )

        SCALE = 30

        # calculate average BST per region
        region_avg = {}

        for entry in entries:

            if entry["availability"] != Availability.AVAILABLE:
                continue

            region = entry["region"]
            species = entry["species"]

            if self._is_special_species(species, pbs):
                continue

            data = pbs.get(species)
            if not data:
                continue

            stats = data.get("BaseStats")
            if not stats:
                continue

            bst = sum(int(x) for x in stats.split(","))

            region_avg.setdefault(region, []).append(bst)

        region_avg = {
            r: sum(v)/len(v)
            for r, v in region_avg.items()
        }

        sorted_regions = sorted(region_avg, key=region_avg.get)

        for i, (label, _, _) in enumerate(bins):

            f.write(f"{label}\n")

            for region in sorted_regions:

                count = region_bins[region][i]

                bar_len = int((count / max_value) * SCALE)

                bar = "█" * bar_len

                f.write(f"R{region} {bar} {count}\n")

            f.write("\n")

    def _write_habitat_distribution(self, entries, pbs, f):

        f.write("\nHabitat Distribution\n")
        f.write("--------------------\n\n")

        habitat_counts = {}

        for e in entries:

            if e["availability"] != Availability.AVAILABLE:
                continue

            species = e["species"]

            if self._is_special_species(species, pbs):
                continue

            region = e["region"]
            habitats = e.get("habitats", [])

            for h in habitats:

                habitat_counts.setdefault(h, {0:0,1:0,2:0,3:0})

                habitat_counts[h][region] += 1

        for habitat in sorted(habitat_counts):

            f.write(f"{habitat.name}\n")

            for r in sorted(habitat_counts[habitat]):
                f.write(f"R{r}: {habitat_counts[habitat][r]}\n")

            f.write("\n")

    def write_spawn_tables(self, spawn_tables, path="ProjectLSync/PBS/spawn_tables_report.txt"):

      with open(path, "w", encoding="utf8") as f:

            f.write("Spawn Tables\n")
            f.write("------------\n\n")

            for region in sorted(spawn_tables.keys()):

                f.write(f"Region {region}\n")
                f.write("-" * 40 + "\n")

                habitats = spawn_tables[region]

                for habitat in sorted(habitats.keys()):

                    table = habitats[habitat]

                    species = table["species"]
                    weights = table["weights"]

                    f.write(f"\n{habitat.upper()}\n")

                    prev = 0

                    for i, (name, form) in enumerate(species):

                        weight = weights[i]
                        tickets = weight - prev
                        prev = weight

                        label = f"{name}" if form == 0 else f"{name}({form})"

                        f.write(f"{label:<18} {tickets:>4}\n")

                f.write("\n\n")